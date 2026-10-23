#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
    Testy kontraktu modułu i odkrywania: Get-MwpModuleDefinition, Test-MwpModuleDefinition.
    Przypadki błędne korzystają z manifestów testowych tworzonych na TestDrive.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Zmienne z bloków BeforeDiscovery/BeforeAll są używane w blokach It (zakresy Pestera).')]
param()

Describe 'Kontrakt modułu i odkrywanie modułów' {
    BeforeAll {
        $root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
        Import-Module -Name (Join-Path -Path $root -ChildPath 'src\Modules\MWP.Core\MWP.Core.psd1') -Force
        $modulesRoot = Join-Path -Path $root -ChildPath 'src\Modules'
        $fixtures = Join-Path -Path $TestDrive -ChildPath 'Modules'

        function Get-TestContract {
            param(
                [string] $Id,
                [string] $Dependencies = '@()',
                [string] $MinimumHostVersion = '0.2.0',
                [string] $Modes = "@('Embedded')",
                [string] $EntryPoint = 'Get-MwpTestModuleInfo',
                [string] $Schema = '@{}'
            )
            "MWP = @{ ContractVersion = 1; Id = '$Id'; Name = 'Test $Id'; EntryPoint = '$EntryPoint'; MinimumHostVersion = '$MinimumHostVersion'; " +
            "Dependencies = $Dependencies; Capabilities = @('Read'); SupportedPresentationModes = $Modes; RequiredPermissions = @('User'); ConfigurationSchema = $Schema }"
        }

        function Add-TestModule {
            param(
                [string] $Name,
                [string] $PrivateData,
                [string] $Version = '1.0.0'
            )
            $directory = Join-Path -Path $fixtures -ChildPath "MWP.$Name"
            $null = New-Item -ItemType Directory -Path $directory -Force
            $text = @(
                '@{'
                "    RootModule = 'MWP.$Name.psm1'"
                "    ModuleVersion = '$Version'"
                "    Description = 'Modul testowy $Name'"
                "    FunctionsToExport = @('Get-MwpTestModuleInfo')"
                "    PrivateData = @{ $PrivateData }"
                '}'
            ) -join [Environment]::NewLine
            Set-Content -LiteralPath (Join-Path -Path $directory -ChildPath "MWP.$Name.psd1") -Value $text -Encoding UTF8
        }

        function Get-TestDefinition {
            param([string] $Name)
            Get-MwpModuleDefinition -ModulesRoot $fixtures -HostVersion '0.2.0' -Name $Name
        }
    }

    AfterAll {
        Remove-Module -Name MWP.Core -Force -ErrorAction SilentlyContinue
    }

    BeforeEach {
        Remove-Item -LiteralPath $fixtures -Recurse -Force -ErrorAction SilentlyContinue
        $null = New-Item -ItemType Directory -Path $fixtures -Force
    }

    Context 'moduły repozytorium' {
        It 'odkrywa wszystkie moduły z src\Modules' {
            $expected = @(Get-ChildItem -LiteralPath $modulesRoot -Directory -Filter 'MWP.*').Count
            @(Get-MwpModuleDefinition).Count | Should -Be $expected
        }

        It 'wszystkie moduły mają poprawny kontrakt' {
            $invalid = @(Get-MwpModuleDefinition | Where-Object { -not $_.IsValid })
            $details = ($invalid | ForEach-Object { '{0}: {1}' -f $_.ModuleName, ($_.Errors -join ' ') }) -join ' | '
            $invalid.Count | Should -Be 0 -Because $details
        }

        It 'MWP.Core ma Id Core i wersję równą wersji hosta' {
            $core = Get-MwpModuleDefinition -Name 'Core'
            $core.ModuleName | Should -Be 'MWP.Core'
            $core.Version | Should -Be (Get-Module -Name MWP.Core).Version
        }

        It 'filtruje po nazwie modułu' {
            @(Get-MwpModuleDefinition -Name 'MWP.Power').Count | Should -Be 1
        }

        It 'nie importuje modułów podczas odkrywania' {
            Remove-Module -Name MWP.Power -Force -ErrorAction SilentlyContinue
            $null = Get-MwpModuleDefinition
            Get-Module -Name MWP.Power | Should -BeNullOrEmpty
        }
    }

    Context 'walidacja' {
        It 'akceptuje poprawne moduły z zależnością' {
            Add-TestModule -Name 'Base' -PrivateData (Get-TestContract -Id 'Base')
            Add-TestModule -Name 'App' -PrivateData (Get-TestContract -Id 'App' -Dependencies "@(@{ Id = 'Base'; MinimumVersion = '1.0.0' })")

            $definitions = @(Get-TestDefinition -Name '*')
            $definitions.Count | Should -Be 2
            $definitions | ForEach-Object { $_.IsValid | Should -BeTrue -Because ($_.Errors -join ' ') }
            (Get-TestDefinition -Name 'App').Dependencies[0].Id | Should -Be 'Base'
        }

        It 'zgłasza brak kontraktu w manifeście' {
            Add-TestModule -Name 'NoContract' -PrivateData 'PSData = @{}'

            $definition = Get-TestDefinition -Name 'MWP.NoContract'
            $definition.IsValid | Should -BeFalse
            $definition.Errors -join ' ' | Should -BeLike '*PrivateData.MWP*'
        }

        It 'zgłasza brakujące pole kontraktu' {
            Add-TestModule -Name 'Partial' -PrivateData "MWP = @{ ContractVersion = 1; Id = 'Partial'; Name = 'Częściowy' }"

            (Get-TestDefinition -Name 'Partial').Errors -join ' ' | Should -BeLike "*Brak pola 'EntryPoint'*"
        }

        It 'zgłasza brakującą zależność' {
            Add-TestModule -Name 'App' -PrivateData (Get-TestContract -Id 'App' -Dependencies "@(@{ Id = 'Missing'; MinimumVersion = '1.0.0' })")

            (Get-TestDefinition -Name 'App').Errors -join ' ' | Should -BeLike "*Brakująca zależność*'Missing'*"
        }

        It 'zgłasza zbyt starą wersję zależności' {
            Add-TestModule -Name 'Base' -PrivateData (Get-TestContract -Id 'Base') -Version '1.0.0'
            Add-TestModule -Name 'App' -PrivateData (Get-TestContract -Id 'App' -Dependencies "@(@{ Id = 'Base'; MinimumVersion = '2.0.0' })")

            (Get-TestDefinition -Name 'App').Errors -join ' ' | Should -BeLike '*wymaga wersji co najmniej 2.0.0*1.0.0*'
        }

        It 'zgłasza zbyt starą wersję hosta' {
            Add-TestModule -Name 'Future' -PrivateData (Get-TestContract -Id 'Future' -MinimumHostVersion '9.0.0')

            (Get-TestDefinition -Name 'Future').Errors -join ' ' | Should -BeLike '*wymaga hosta w wersji co najmniej 9.0.0*'
        }

        It 'zgłasza niedozwolony tryb prezentacji' {
            Add-TestModule -Name 'Modes' -PrivateData (Get-TestContract -Id 'Modes' -Modes "@('Hologram')")

            (Get-TestDefinition -Name 'Modes').Errors -join ' ' | Should -BeLike "*Niedozwolona wartość 'Hologram'*"
        }

        It 'zgłasza EntryPoint spoza eksportowanych funkcji' {
            Add-TestModule -Name 'Entry' -PrivateData (Get-TestContract -Id 'Entry' -EntryPoint 'Get-MwpInnaFunkcja')

            (Get-TestDefinition -Name 'Entry').Errors -join ' ' | Should -BeLike '*EntryPoint*'
        }

        It 'zgłasza niepoprawny opis ustawień modułu (ConfigurationSchema)' {
            Add-TestModule -Name 'Schema' -PrivateData (Get-TestContract -Id 'Schema' -Schema "@{ opcja = @{ Type = 'Liczba'; Default = 1 } }")

            (Get-TestDefinition -Name 'Schema').Errors -join ' ' | Should -BeLike "*Niedozwolony typ 'Liczba'*"
        }

        It 'zgłasza zduplikowane Id w obu modułach' {
            Add-TestModule -Name 'First' -PrivateData (Get-TestContract -Id 'Dup')
            Add-TestModule -Name 'Second' -PrivateData (Get-TestContract -Id 'Dup')

            $definitions = @(Get-TestDefinition -Name 'Dup')
            $definitions.Count | Should -Be 2
            $definitions | ForEach-Object { $_.Errors -join ' ' | Should -BeLike '*używane także przez inny moduł*' }
        }

        It 'zgłasza cykl zależności' {
            Add-TestModule -Name 'A' -PrivateData (Get-TestContract -Id 'A' -Dependencies "@(@{ Id = 'B'; MinimumVersion = '1.0.0' })")
            Add-TestModule -Name 'B' -PrivateData (Get-TestContract -Id 'B' -Dependencies "@(@{ Id = 'A'; MinimumVersion = '1.0.0' })")

            (Get-TestDefinition -Name 'A').Errors -join ' ' | Should -BeLike '*Cykliczna zależność: A -> B -> A*'
        }

        It 'zgłasza zależność od samego siebie' {
            Add-TestModule -Name 'Self' -PrivateData (Get-TestContract -Id 'Self' -Dependencies "@(@{ Id = 'Self'; MinimumVersion = '1.0.0' })")

            (Get-TestDefinition -Name 'Self').Errors -join ' ' | Should -BeLike '*od samego siebie*'
        }

        It 'uszkodzony manifest nie przerywa odkrywania pozostałych modułów' {
            Add-TestModule -Name 'Good' -PrivateData (Get-TestContract -Id 'Good')
            $broken = Join-Path -Path $fixtures -ChildPath 'MWP.Broken'
            $null = New-Item -ItemType Directory -Path $broken -Force
            Set-Content -LiteralPath (Join-Path -Path $broken -ChildPath 'MWP.Broken.psd1') -Value 'to nie jest plik danych'

            $definitions = @(Get-TestDefinition -Name '*')
            $definitions.Count | Should -Be 2
            ($definitions | Where-Object { $_.ModuleName -eq 'MWP.Broken' }).Errors -join ' ' | Should -BeLike '*Nie udało się odczytać manifestu*'
            ($definitions | Where-Object { $_.ModuleName -eq 'MWP.Good' }).IsValid | Should -BeTrue
        }

        It 'Test-MwpModuleDefinition zwraca obiekt z IsValid i Errors' {
            Add-TestModule -Name 'Base' -PrivateData (Get-TestContract -Id 'Base')
            $definition = Get-TestDefinition -Name 'Base'

            $validation = Test-MwpModuleDefinition -Definition $definition -AvailableDefinition @($definition) -HostVersion '0.1.0'

            $validation.IsValid | Should -BeFalse
            $validation.Errors -join ' ' | Should -BeLike '*wymaga hosta*'
        }
    }
}
