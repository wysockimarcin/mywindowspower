#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
    Testy New-MwpRestorePoint. CIM i sprawdzenie administratora są mockowane:
    testy nie tworzą prawdziwego punktu przywracania.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Zmienne z bloków BeforeDiscovery/BeforeAll są używane w blokach It (zakresy Pestera).')]
param()

Describe 'New-MwpRestorePoint' {
    BeforeAll {
        $root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
        Import-Module -Name (Join-Path -Path $root -ChildPath 'src\Modules\MWP.Core\MWP.Core.psd1') -Force
        $null = New-Item -ItemType Directory -Path (Join-Path -Path $TestDrive -ChildPath 'config') -Force
        Copy-Item -LiteralPath (Join-Path -Path $root -ChildPath 'config\settings.example.json') -Destination (Join-Path -Path $TestDrive -ChildPath 'config\settings.example.json')
        Mock -ModuleName MWP.Core Get-MwpDataPath {
            $path = Join-Path -Path $TestDrive -ChildPath $Kind
            if (Get-Variable -Name Detailed -ValueOnly -ErrorAction SilentlyContinue) { [pscustomobject]@{ Path = $path; Root = $TestDrive; Configured = ''; IsFallback = $false; Warning = $null } } else { $path }
        }
        Mock -ModuleName MWP.Core Get-MwpConfigPath {
            [pscustomobject]@{
                Example = Join-Path -Path $TestDrive -ChildPath 'config\settings.example.json'
                Local   = Join-Path -Path $TestDrive -ChildPath 'config\settings.local.json'
            }
        }
        $remoteComputer = 'PC-ZDALNY'
        Mock -ModuleName MWP.Core Test-MwpAdmin { $true }
        Mock -ModuleName MWP.Core Invoke-CimMethod { [pscustomobject]@{ ReturnValue = 0 } }
        Mock -ModuleName MWP.Core Get-CimInstance { throw 'Get-CimInstance nie powinien być wywołany bez mocka punktu.' }
    }

    AfterAll {
        Remove-Module -Name MWP.Core -Force -ErrorAction SilentlyContinue
    }

    It 'bez uprawnień administratora zwraca błąd i nie wywołuje CIM' {
        Mock -ModuleName MWP.Core Test-MwpAdmin { $false }

        $result = New-MwpRestorePoint -Description 'Test'

        $result.Success | Should -BeFalse
        $result.Message | Should -Match 'administratora'
        Should -Invoke Invoke-CimMethod -ModuleName MWP.Core -Times 0 -Exactly
    }

    It '-WhatIf zwraca podgląd i nie tworzy punktu' {
        Mock -ModuleName MWP.Core Get-MwpLatestRestorePoint { }

        $result = New-MwpRestorePoint -Description 'Test' -WhatIf

        $result.IsPreview | Should -BeTrue
        $result.ComputerName | Should -Be 'localhost'
        Should -Invoke Invoke-CimMethod -ModuleName MWP.Core -Times 0 -Exactly
    }

    It 'tworzy punkt przez CIM i zwraca jego numer' {
        $script:sequence = 0
        Mock -ModuleName MWP.Core Get-MwpLatestRestorePoint {
            $script:sequence++
            [pscustomobject]@{ SequenceNumber = 100 + $script:sequence; Description = 'x'; CreationTime = '' }
        }

        $result = New-MwpRestorePoint -Description 'Przed zmianą'

        $result.Success | Should -BeTrue
        $result.Changed | Should -BeTrue
        $result.After.SequenceNumber | Should -Be 102
        Should -Invoke Invoke-CimMethod -ModuleName MWP.Core -Times 1 -Exactly -ParameterFilter {
            $Namespace -eq 'root/default' -and $ClassName -eq 'SystemRestore' -and $MethodName -eq 'CreateRestorePoint' -and
            $Arguments.Description -eq 'Przed zmianą' -and $Arguments.RestorePointType -eq 12 -and $Arguments.EventType -eq 100
        }
    }

    It 'limit częstotliwości: sukces bez nowego punktu, z wyjaśnieniem' {
        Mock -ModuleName MWP.Core Get-MwpLatestRestorePoint { [pscustomobject]@{ SequenceNumber = 7; Description = 'x'; CreationTime = '' } }

        $result = New-MwpRestorePoint -Description 'Test'

        $result.Success | Should -BeTrue
        $result.Changed | Should -BeFalse
        $result.Message | Should -Match '24 godziny'
    }

    It 'ochrona systemu wyłączona (kod 1058) daje czytelny błąd' {
        Mock -ModuleName MWP.Core Get-MwpLatestRestorePoint { }
        Mock -ModuleName MWP.Core Invoke-CimMethod { [pscustomobject]@{ ReturnValue = 1058 } }

        $result = New-MwpRestorePoint -Description 'Test'

        $result.Success | Should -BeFalse
        $result.Message | Should -Match 'Ochrona systemu jest wyłączona'
    }

    It 'wyjątek CIM daje wynik z błędem, bez wyjątku' {
        Mock -ModuleName MWP.Core Get-MwpLatestRestorePoint { }
        Mock -ModuleName MWP.Core Invoke-CimMethod { throw 'Brak dostępu' }

        $result = New-MwpRestorePoint -Description 'Test'

        $result.Success | Should -BeFalse
        $result.ErrorMessage | Should -Match 'Brak dostępu'
    }

    It 'komputer zdalny podany samą nazwą (bez kontekstu) jest odrzucany, z jego nazwą w wyniku' {
        $result = New-MwpRestorePoint -Description 'Test' -ComputerName $remoteComputer

        $result.Success | Should -BeFalse
        $result.ComputerName | Should -Be 'PC-ZDALNY'
        $result.Message | Should -Match 'PC-ZDALNY'
        $result.Message | Should -Match '-Context'
        Should -Invoke Invoke-CimMethod -ModuleName MWP.Core -Times 0 -Exactly
    }

    It 'zapisuje operację w logu z nazwą komputera' {
        Mock -ModuleName MWP.Core Get-MwpLatestRestorePoint { }
        $null = New-MwpRestorePoint -Description 'Test logu'

        $log = Join-Path -Path $TestDrive -ChildPath ('Logs\mwp-{0:yyyy-MM-dd}.log' -f (Get-Date))
        $entry = Get-Content -LiteralPath $log -Encoding UTF8 | ForEach-Object { $_ | ConvertFrom-Json } |
            Where-Object { $_.operation -eq 'Core.RestorePoint' } | Select-Object -Last 1
        $entry.computer | Should -Be 'localhost'
    }

    It 'Get-MwpLatestRestorePoint wybiera punkt o najwyższym numerze' {
        Mock -ModuleName MWP.Core Get-CimInstance {
            [pscustomobject]@{ SequenceNumber = 3; Description = 'starszy'; CreationTime = '1' }
            [pscustomobject]@{ SequenceNumber = 9; Description = 'najnowszy'; CreationTime = '2' }
            [pscustomobject]@{ SequenceNumber = 5; Description = 'środkowy'; CreationTime = '3' }
        }

        $latest = InModuleScope -ModuleName MWP.Core { Get-MwpLatestRestorePoint }

        $latest.SequenceNumber | Should -Be 9
        $latest.Description | Should -Be 'najnowszy'
    }
}
