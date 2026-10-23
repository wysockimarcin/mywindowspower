#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
    Testy Get-MwpSetting / Set-MwpSetting: wartości domyślne, nadpisania, uszkodzony plik,
    wersja schematu, zapis atomowy, -WhatIf, walidacja typów i cofnięcie zmiany.
    Pliki konfiguracji i dane są na TestDrive (mocki ścieżek).
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Zmienne z bloków BeforeDiscovery/BeforeAll są używane w blokach It (zakresy Pestera).')]
param()

Describe 'Ustawienia aplikacji' {
    BeforeAll {
        $root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
        Import-Module -Name (Join-Path -Path $root -ChildPath 'src\Modules\MWP.Core\MWP.Core.psd1') -Force
        $configDirectory = Join-Path -Path $TestDrive -ChildPath 'config'
        $null = New-Item -ItemType Directory -Path $configDirectory -Force
        Copy-Item -LiteralPath (Join-Path -Path $root -ChildPath 'config\settings.example.json') -Destination (Join-Path -Path $configDirectory -ChildPath 'settings.example.json')
        Mock -ModuleName MWP.Core Get-MwpDataPath { Join-Path -Path $TestDrive -ChildPath $Kind }
        Mock -ModuleName MWP.Core Get-MwpConfigPath {
            [pscustomobject]@{
                Example = Join-Path -Path $TestDrive -ChildPath 'config\settings.example.json'
                Local   = Join-Path -Path $TestDrive -ChildPath 'config\settings.local.json'
            }
        }

        $localPath = Join-Path -Path $configDirectory -ChildPath 'settings.local.json'
        $defaults = Get-Content -LiteralPath (Join-Path -Path $configDirectory -ChildPath 'settings.example.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    }

    AfterAll {
        Remove-Module -Name MWP.Core -Force -ErrorAction SilentlyContinue
    }

    BeforeEach {
        Get-ChildItem -LiteralPath $configDirectory -Filter 'settings.local.json*' | Remove-Item -Force
        Remove-Item -LiteralPath (Join-Path -Path $TestDrive -ChildPath 'Undo') -Recurse -Force -ErrorAction SilentlyContinue
    }

    Context 'odczyt' {
        It 'bez pliku lokalnego zwraca wartości domyślne z szablonu' {
            $settings = Get-MwpSetting
            $settings.logLevel | Should -Be $defaults.logLevel
            $settings.theme | Should -Be $defaults.theme
            Get-MwpSetting -Name dryRunByDefault | Should -Be $defaults.dryRunByDefault
        }

        It 'plik lokalny nadpisuje wartości domyślne' {
            Set-Content -LiteralPath $localPath -Value '{ "schemaVersion": 1, "logLevel": "Debug" }' -Encoding UTF8

            Get-MwpSetting -Name logLevel | Should -Be 'Debug'
            Get-MwpSetting -Name theme | Should -Be $defaults.theme
        }

        It 'pusty plik lokalny oznacza brak nadpisań' {
            Set-Content -LiteralPath $localPath -Value '' -Encoding UTF8

            Get-MwpSetting -Name logLevel -WarningVariable warnings | Should -Be $defaults.logLevel
            $warnings | Should -BeNullOrEmpty
        }

        It 'nieznana nazwa ustawienia daje czytelny błąd' {
            { Get-MwpSetting -Name 'brakUstawienia' } | Should -Throw '*Nieznane ustawienie*'
        }

        It 'uszkodzony plik lokalny: wartości domyślne, ostrzeżenie i kopia pliku pod inną nazwą' {
            Set-Content -LiteralPath $localPath -Value '{ to nie jest JSON' -Encoding UTF8

            $value = Get-MwpSetting -Name logLevel -WarningVariable warnings -WarningAction SilentlyContinue

            $value | Should -Be $defaults.logLevel
            $warnings | Should -Not -BeNullOrEmpty
            $localPath | Should -Not -Exist
            @(Get-ChildItem -LiteralPath $configDirectory -Filter 'settings.local.json.corrupt-*').Count | Should -Be 1
        }

        It 'nowsza wersja schematu: wartości domyślne, plik bez zmian' {
            Set-Content -LiteralPath $localPath -Value '{ "schemaVersion": 99, "logLevel": "Debug" }' -Encoding UTF8

            Get-MwpSetting -Name logLevel -WarningAction SilentlyContinue | Should -Be $defaults.logLevel
            $localPath | Should -Exist
        }

        It 'nieznany klucz w pliku lokalnym jest pomijany z ostrzeżeniem' {
            Set-Content -LiteralPath $localPath -Value '{ "schemaVersion": 1, "nieznany": true }' -Encoding UTF8

            $settings = Get-MwpSetting -WarningVariable warnings -WarningAction SilentlyContinue
            $settings.PSObject.Properties.Name | Should -Not -Contain 'nieznany'
            ($warnings -join ' ') | Should -Match 'nieznany'
        }
    }

    Context 'zapis' {
        It 'zapisuje wartość atomowo i zwraca wynik z wpisem cofnięcia' {
            $result = Set-MwpSetting -Name logLevel -Value 'Debug'

            $result.Success | Should -BeTrue
            $result.Changed | Should -BeTrue
            $result.ComputerName | Should -Be 'localhost'
            $result.Before | Should -Be $defaults.logLevel
            $result.After | Should -Be 'Debug'
            $result.UndoId | Should -Not -BeNullOrEmpty
            Get-MwpSetting -Name logLevel | Should -Be 'Debug'
            (Get-Content -LiteralPath $localPath -Raw -Encoding UTF8 | ConvertFrom-Json).schemaVersion | Should -Be 1
            @(Get-ChildItem -LiteralPath $configDirectory -Filter '*.tmp').Count | Should -Be 0
            (Get-MwpUndoEntry -Id $result.UndoId).UndoCommand | Should -Be 'Set-MwpSetting'
        }

        It '-WhatIf nie zapisuje pliku i zwraca podgląd' {
            $result = Set-MwpSetting -Name logLevel -Value 'Debug' -WhatIf

            $result.Success | Should -BeTrue
            $result.IsPreview | Should -BeTrue
            $result.Changed | Should -BeFalse
            $localPath | Should -Not -Exist
            Get-MwpUndoEntry | Should -BeNullOrEmpty
        }

        It 'odrzuca wartość niezgodnego typu' {
            $result = Set-MwpSetting -Name dryRunByDefault -Value 'tak'

            $result.Success | Should -BeFalse
            $result.Message | Should -Match 'Niepoprawny typ'
            $localPath | Should -Not -Exist
        }

        It 'przyjmuje liczbę całkowitą niezależnie od typu w szablonie ([int] w 5.1, [long] w 7.x)' {
            (Set-MwpSetting -Name logRetentionDays -Value 14).Success | Should -BeTrue
            Get-MwpSetting -Name logRetentionDays | Should -Be 14
        }

        It 'odrzuca nieznane ustawienie' {
            (Set-MwpSetting -Name 'brakUstawienia' -Value 1).Success | Should -BeFalse
            $localPath | Should -Not -Exist
        }

        It 'nie pozwala zmienić schemaVersion' {
            (Set-MwpSetting -Name schemaVersion -Value 2).Success | Should -BeFalse
        }

        It 'zachowuje pozostałe nadpisania z pliku lokalnego' {
            Set-Content -LiteralPath $localPath -Value '{ "schemaVersion": 1, "theme": "Dark" }' -Encoding UTF8

            $null = Set-MwpSetting -Name logLevel -Value 'Debug'

            Get-MwpSetting -Name theme | Should -Be 'Dark'
            Get-MwpSetting -Name logLevel | Should -Be 'Debug'
        }

        It 'zmianę można cofnąć przez Invoke-MwpUndo' {
            $change = Set-MwpSetting -Name logLevel -Value 'Debug'

            $undo = Invoke-MwpUndo -Id $change.UndoId

            $undo.Success | Should -BeTrue
            Get-MwpSetting -Name logLevel | Should -Be $defaults.logLevel
            (Get-MwpUndoEntry -Id $change.UndoId).Status | Should -Be 'Undone'
        }

        It 'zapisuje zmianę w logu' {
            $null = Set-MwpSetting -Name theme -Value 'Light'

            $log = Join-Path -Path $TestDrive -ChildPath ('Logs\mwp-{0:yyyy-MM-dd}.log' -f (Get-Date))
            $log | Should -FileContentMatch 'Settings\.Set'
        }
    }
}
