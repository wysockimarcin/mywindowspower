#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
    Testy Write-MwpLog: plik dzienny, nazwa komputera, poziomy, ukrywanie sekretów, rotacja.
    Katalog danych i konfiguracja są podmienione mockami na TestDrive (bez zapisu w profilu).
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Zmienne z bloków BeforeDiscovery/BeforeAll są używane w blokach It (zakresy Pestera).')]
param()

Describe 'Write-MwpLog' {
    BeforeAll {
        $root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
        Import-Module -Name (Join-Path -Path $root -ChildPath 'src\Modules\MWP.Core\MWP.Core.psd1') -Force
        $null = New-Item -ItemType Directory -Path (Join-Path -Path $TestDrive -ChildPath 'config') -Force
        Copy-Item -LiteralPath (Join-Path -Path $root -ChildPath 'config\settings.example.json') -Destination (Join-Path -Path $TestDrive -ChildPath 'config\settings.example.json')
        Mock -ModuleName MWP.Core Get-MwpDataPath { Join-Path -Path $TestDrive -ChildPath $Kind }
        Mock -ModuleName MWP.Core Get-MwpConfigPath {
            [pscustomobject]@{
                Example = Join-Path -Path $TestDrive -ChildPath 'config\settings.example.json'
                Local   = Join-Path -Path $TestDrive -ChildPath 'config\settings.local.json'
            }
        }

        $remoteComputer = 'PC-ZDALNY'
        $logDirectory = Join-Path -Path $TestDrive -ChildPath 'Logs'
        $localSettings = Join-Path -Path $TestDrive -ChildPath 'config\settings.local.json'
        function Get-TodayLogPath {
            Join-Path -Path $logDirectory -ChildPath ('mwp-{0:yyyy-MM-dd}.log' -f (Get-Date))
        }
        function Get-TodayLog {
            @(Get-Content -LiteralPath (Get-TodayLogPath) -Encoding UTF8 | ForEach-Object { $_ | ConvertFrom-Json })
        }
    }

    AfterAll {
        Remove-Module -Name MWP.Core -Force -ErrorAction SilentlyContinue
    }

    BeforeEach {
        Remove-Item -LiteralPath $logDirectory -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $localSettings -Force -ErrorAction SilentlyContinue
    }

    It 'tworzy dzienny plik logu z wpisem JSON i komputerem localhost' {
        Write-MwpLog -Message 'Test zażółć gęślą jaźń' -Source 'Testy' -Operation 'Test.Log'

        # @() jest potrzebne: w 5.1 pojedynczy PSCustomObject nie ma właściwości Count.
        $entries = @(Get-TodayLog)
        $entries.Count | Should -Be 1
        $entries[0].computer | Should -Be 'localhost'
        $entries[0].level | Should -Be 'Info'
        $entries[0].source | Should -Be 'Testy'
        $entries[0].operation | Should -Be 'Test.Log'
        $entries[0].message | Should -Be 'Test zażółć gęślą jaźń'
        $entries[0].processId | Should -Be $PID
    }

    It 'zapisuje podaną nazwę komputera docelowego' {
        Write-MwpLog -Message 'Operacja zdalna' -ComputerName $remoteComputer

        (Get-TodayLog)[0].computer | Should -Be 'PC-ZDALNY'
    }

    It 'dopisuje kolejne wpisy do tego samego pliku' {
        1..5 | ForEach-Object { Write-MwpLog -Message "Wpis $_" }

        @(Get-TodayLog).Count | Should -Be 5
    }

    It 'pomija wpisy Debug przy domyślnym poziomie Info' {
        Write-MwpLog -Message 'Szczegóły' -Level Debug

        Get-TodayLogPath | Should -Not -Exist
    }

    It 'zapisuje wpisy Debug, gdy logLevel = Debug' {
        Set-Content -LiteralPath $localSettings -Value '{ "schemaVersion": 1, "logLevel": "Debug" }' -Encoding UTF8
        Write-MwpLog -Message 'Szczegóły' -Level Debug

        (Get-TodayLog)[0].level | Should -Be 'Debug'
    }

    It 'ukrywa sekrety w danych wpisu' {
        $credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'uzytkownik', (New-Object -TypeName System.Security.SecureString)
        Write-MwpLog -Message 'Dane' -Data @{
            Name       = 'Spooler'
            Password   = 'tajne-haslo'
            Token      = 'tajny-token'
            Credential = $credential
            Nested     = @{ apiKey = 'tajny-klucz'; Value = 5 }
        }

        $data = (Get-TodayLog)[0].data
        $data.Name | Should -Be 'Spooler'
        $data.Password | Should -Be '[UKRYTE]'
        $data.Token | Should -Be '[UKRYTE]'
        $data.Credential | Should -Be '[UKRYTE]'
        $data.Nested.apiKey | Should -Be '[UKRYTE]'
        $data.Nested.Value | Should -Be 5
        Get-TodayLogPath | Should -Not -FileContentMatch 'tajn'
    }

    It 'przy tworzeniu pliku nowego dnia usuwa logi starsze niż logRetentionDays' {
        Set-Content -LiteralPath $localSettings -Value '{ "schemaVersion": 1, "logRetentionDays": 7 }' -Encoding UTF8
        $null = New-Item -ItemType Directory -Path $logDirectory -Force
        $today = (Get-Date).Date
        $old = Join-Path -Path $logDirectory -ChildPath ('mwp-{0:yyyy-MM-dd}.log' -f $today.AddDays(-30))
        $recent = Join-Path -Path $logDirectory -ChildPath ('mwp-{0:yyyy-MM-dd}.log' -f $today.AddDays(-3))
        $other = Join-Path -Path $logDirectory -ChildPath 'notatki.txt'
        $unmatched = Join-Path -Path $logDirectory -ChildPath 'mwp-inny.log'
        foreach ($file in $old, $recent, $other, $unmatched) {
            Set-Content -LiteralPath $file -Value 'x'
        }

        Write-MwpLog -Message 'Nowy dzień'

        $old | Should -Not -Exist
        $recent | Should -Exist
        $other | Should -Exist
        $unmatched | Should -Exist
        Get-TodayLogPath | Should -Exist
    }

    It 'nie przerywa działania, gdy zapis się nie udaje (tylko ostrzeżenie)' {
        # Plik w miejscu katalogu logów uniemożliwia zapis.
        Set-Content -LiteralPath $logDirectory -Value 'to nie jest katalog'

        { Write-MwpLog -Message 'Wpis' -WarningAction SilentlyContinue } | Should -Not -Throw
        Write-MwpLog -Message 'Wpis' -WarningVariable warnings -WarningAction SilentlyContinue
        $warnings | Should -Not -BeNullOrEmpty
    }
}
