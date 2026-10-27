#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
    Testy konfiguracji Dashboardu i kontraktu widgetu (FAZA 5, D-043): Get-/Set-MwpDashboardConfiguration,
    Remove-MwpDashboardWidget, Repair-MwpDashboardConfiguration (odtworzenie konfiguracji i usuwanie
    widgetów modułów, których nie ma — D-031), Get-MwpWidgetDefinition i walidacja pola Widgets
    w Test-MwpModuleDefinition. Ustawienia na TestDrive; system bez zmian.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Zmienne z bloków BeforeDiscovery/BeforeAll są używane w blokach It (zakresy Pestera).')]
param()

Describe 'Konfiguracja Dashboardu i kontrakt widgetu' {
    BeforeAll {
        $root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
        Import-Module -Name (Join-Path -Path $root -ChildPath 'src\Modules\MWP.Core\MWP.Core.psd1') -Force
        $configDirectory = Join-Path -Path $TestDrive -ChildPath 'config'
        $null = New-Item -ItemType Directory -Path $configDirectory -Force
        Copy-Item -LiteralPath (Join-Path -Path $root -ChildPath 'config\settings.example.json') -Destination (Join-Path -Path $configDirectory -ChildPath 'settings.example.json')
        $localPath = Join-Path -Path $configDirectory -ChildPath 'settings.local.json'
        Mock -ModuleName MWP.Core Get-MwpDataPath {
            $path = Join-Path -Path $TestDrive -ChildPath $Kind
            if (Get-Variable -Name Detailed -ValueOnly -ErrorAction SilentlyContinue) { [pscustomobject]@{ Path = $path; Root = $TestDrive; Configured = ''; IsFallback = $false; Warning = $null } } else { $path }
        }
        Mock -ModuleName MWP.Core Get-MwpConfigPath {
            [pscustomobject]@{
                Example    = Join-Path -Path $TestDrive -ChildPath 'config\settings.example.json'
                Local      = Join-Path -Path $TestDrive -ChildPath 'config\settings.local.json'
                IsFallback = $false
            }
        }
        $fixtures = Join-Path -Path $TestDrive -ChildPath 'Modules'
        $remoteName = 'PC-TEST1'

        function Get-TestWidgetEntry {
            param([string] $Id, [string] $ModuleId = 'Dashboard', [string] $WidgetId = 'SystemInfo', [string] $ComputerName = 'localhost', [object] $Refresh = 60, [string] $Size = 'Normal')
            [ordered]@{ id = $Id; moduleId = $ModuleId; widgetId = $WidgetId; computerName = $ComputerName; title = ''; refreshSeconds = $Refresh; size = $Size; parameters = [ordered]@{ Sections = @('Cpu') } }
        }
        function Get-TestModuleDefinition {
            param([string] $Id, [bool] $IsValid = $true, [object[]] $Widgets = @())
            [pscustomobject]@{
                PSTypeName = 'MWP.ModuleDefinition'; Id = $Id; Name = "Moduł $Id"; ModuleName = "MWP.$Id"; IsValid = $IsValid; Errors = @('błąd testowy')
                Capabilities = @('Read'); Widgets = $Widgets
            }
        }
        function Add-TestModule {
            param([string] $Name, [string] $Widgets, [string] $Modes = "@('DashboardWidget')", [string] $Exports = "@('Get-MwpTestModuleInfo', 'Get-MwpTestData', 'ConvertTo-MwpTestView')")
            $directory = Join-Path -Path $fixtures -ChildPath "MWP.$Name"
            $null = New-Item -ItemType Directory -Path $directory -Force
            $text = @(
                '@{'
                "    RootModule = 'MWP.$Name.psm1'"
                "    ModuleVersion = '1.0.0'"
                "    FunctionsToExport = $Exports"
                "    PrivateData = @{ MWP = @{ ContractVersion = 1; Id = '$Name'; Name = 'Test $Name'; EntryPoint = 'Get-MwpTestModuleInfo'; MinimumHostVersion = '0.2.0';"
                "        Dependencies = @(); Capabilities = @('Read'); SupportedPresentationModes = $Modes; RequiredPermissions = @('User'); ConfigurationSchema = @{}; Widgets = $Widgets } }"
                '}'
            ) -join [Environment]::NewLine
            Set-Content -LiteralPath (Join-Path -Path $directory -ChildPath "MWP.$Name.psd1") -Value $text -Encoding UTF8
            Get-MwpModuleDefinition -ModulesRoot $fixtures -HostVersion '0.5.0' -Name $Name
        }
        $goodWidget = "@(@{ Id = 'Stan'; Name = 'Stan'; DataCommand = 'Get-MwpTestData'; ViewCommand = 'ConvertTo-MwpTestView'; DefaultRefreshSeconds = 300; Parameters = @{ Tryb = @{ Type = 'String'; Default = 'a'; Values = @('a', 'b') } } })"
    }

    AfterAll {
        Remove-Module -Name MWP.Core -Force -ErrorAction SilentlyContinue
    }

    BeforeEach {
        Get-ChildItem -LiteralPath $configDirectory -Filter 'settings.local.json*' | Remove-Item -Force
        Remove-Item -LiteralPath $fixtures -Recurse -Force -ErrorAction SilentlyContinue
        $null = New-Item -ItemType Directory -Path $fixtures -Force
    }

    Context 'odczyt i zapis konfiguracji' {
        It 'bez wpisu lokalnego obowiązuje szablon: jeden widget „Informacje o systemie” dla localhost' {
            $configuration = Get-MwpDashboardConfiguration

            $configuration.IsDefault | Should -BeTrue
            $configuration.AutoRefresh | Should -BeTrue
            $configuration.MaxParallelRefresh | Should -Be 2
            @($configuration.Widgets).Count | Should -Be 1
            $configuration.Widgets[0].moduleId | Should -Be 'Dashboard'
            $configuration.Widgets[0].widgetId | Should -Be 'SystemInfo'
            $configuration.Widgets[0].computerName | Should -Be 'localhost'
        }

        It 'zapis i odtworzenie zachowuje widgety, kolejność, komputery i parametry' {
            $widgets = @((Get-TestWidgetEntry -Id 'b' -ComputerName $remoteName -Refresh 300 -Size 'Wide'), (Get-TestWidgetEntry -Id 'a' -Refresh 0))

            $result = Set-MwpDashboardConfiguration -Widget $widgets -Confirm:$false

            $result.Success | Should -BeTrue -Because $result.Message
            $result.UndoId | Should -BeNullOrEmpty -Because 'układ Dashboardu to stan aplikacji, bez rejestru cofnięć (D-043)'
            $configuration = Get-MwpDashboardConfiguration
            $configuration.IsDefault | Should -BeFalse
            @($configuration.Widgets | ForEach-Object { $_.id }) | Should -Be @('b', 'a')
            $configuration.Widgets[0].computerName | Should -Be $remoteName
            $configuration.Widgets[0].refreshSeconds | Should -Be 300
            $configuration.Widgets[0].size | Should -Be 'Wide'
            $configuration.Widgets[1].refreshSeconds | Should -Be 0
            @($configuration.Widgets[0].parameters['Sections']) | Should -Be @('Cpu')
        }

        It 'pusta lista widgetów jest zapisywana (użytkownik usunął wszystkie)' {
            (Set-MwpDashboardConfiguration -Widget @() -Confirm:$false).Success | Should -BeTrue

            $configuration = Get-MwpDashboardConfiguration
            $configuration.IsDefault | Should -BeFalse
            @($configuration.Widgets).Count | Should -Be 0
        }

        It 'przełącznik odświeżania automatycznego zapisuje się bez zmiany listy widgetów' {
            $null = Set-MwpDashboardConfiguration -Widget @((Get-TestWidgetEntry -Id 'x')) -Confirm:$false

            (Set-MwpDashboardConfiguration -AutoRefresh $false -Confirm:$false).Success | Should -BeTrue

            $configuration = Get-MwpDashboardConfiguration
            $configuration.AutoRefresh | Should -BeFalse
            @($configuration.Widgets | ForEach-Object { $_.id }) | Should -Be @('x')
        }

        It 'odrzuca niedozwoloną częstotliwość, rozmiar i powtórzony identyfikator; niczego nie zapisuje' {
            (Set-MwpDashboardConfiguration -Widget @((Get-TestWidgetEntry -Id 'x' -Refresh 5)) -Confirm:$false).Success | Should -BeFalse
            (Set-MwpDashboardConfiguration -Widget @((Get-TestWidgetEntry -Id 'x' -Size 'Ogromny')) -Confirm:$false).Success | Should -BeFalse
            (Set-MwpDashboardConfiguration -Widget @((Get-TestWidgetEntry -Id 'x'), (Get-TestWidgetEntry -Id 'x')) -Confirm:$false).Success | Should -BeFalse
            (Set-MwpDashboardConfiguration -Widget @([ordered]@{ id = 'y'; widgetId = 'SystemInfo' }) -Confirm:$false).Success | Should -BeFalse

            $localPath | Should -Not -Exist
        }

        It '-WhatIf niczego nie zapisuje' {
            $result = Set-MwpDashboardConfiguration -Widget @((Get-TestWidgetEntry -Id 'x')) -WhatIf

            $result.IsPreview | Should -BeTrue
            $localPath | Should -Not -Exist
        }

        It 'niepoprawny wpis w pliku jest pomijany z ostrzeżeniem, pozostałe widgety zostają' {
            $local = [ordered]@{ schemaVersion = 2; dashboardWidgets = @((Get-TestWidgetEntry -Id 'ok'), [ordered]@{ id = 'zly'; moduleId = 'Dashboard' }, (Get-TestWidgetEntry -Id 'ok')) }
            ConvertTo-Json -InputObject $local -Depth 6 | Set-Content -LiteralPath $localPath -Encoding UTF8

            $configuration = Get-MwpDashboardConfiguration

            @($configuration.Widgets | ForEach-Object { $_.id }) | Should -Be @('ok')
            @($configuration.Warnings).Count | Should -Be 2
        }

        It 'limit równoległych odświeżeń jest ograniczony do 1–8' {
            $local = [ordered]@{ schemaVersion = 2; dashboardMaxParallelRefresh = 50 }
            ConvertTo-Json -InputObject $local | Set-Content -LiteralPath $localPath -Encoding UTF8

            (Get-MwpDashboardConfiguration).MaxParallelRefresh | Should -Be 8
        }
    }

    Context 'Remove-MwpDashboardWidget' {
        It 'usuwa wszystkie widgety modułu albo wskazane identyfikatory' {
            $null = Set-MwpDashboardConfiguration -Widget @((Get-TestWidgetEntry -Id 'a' -ModuleId 'Probe'), (Get-TestWidgetEntry -Id 'b'), (Get-TestWidgetEntry -Id 'c' -ModuleId 'Probe')) -Confirm:$false

            $result = Remove-MwpDashboardWidget -ModuleId 'Probe' -Confirm:$false

            $result.Data.Removed | Should -Be 2
            @($result.Data.Ids) | Should -Be @('a', 'c')
            @((Get-MwpDashboardConfiguration).Widgets | ForEach-Object { $_.id }) | Should -Be @('b')
            (Remove-MwpDashboardWidget -Id 'b' -Confirm:$false).Data.Removed | Should -Be 1
            @((Get-MwpDashboardConfiguration).Widgets).Count | Should -Be 0
        }

        It 'bez pasujących widgetów i z -WhatIf niczego nie zapisuje' {
            (Remove-MwpDashboardWidget -ModuleId 'Brak' -Confirm:$false).Changed | Should -BeFalse
            (Remove-MwpDashboardWidget -ModuleId 'Dashboard' -WhatIf).IsPreview | Should -BeTrue
            $localPath | Should -Not -Exist
        }
    }

    Context 'odtworzenie konfiguracji (Repair-MwpDashboardConfiguration, D-031)' {
        BeforeEach {
            $catalogWidget = @{ Id = 'SystemInfo'; Name = 'Info'; DataCommand = 'Get-X'; ViewCommand = 'ConvertTo-X' }
            $definitions = @(
                Get-TestModuleDefinition -Id 'Dashboard' -Widgets @($catalogWidget)
                Get-TestModuleDefinition -Id 'Zepsuty' -IsValid $false -Widgets @(@{ Id = 'Stan'; Name = 'Stan' })
            )
            $widgets = @(
                Get-TestWidgetEntry -Id 'ok'
                Get-TestWidgetEntry -Id 'odinstalowany' -ModuleId 'Usuniety' -WidgetId 'Stan'
                Get-TestWidgetEntry -Id 'bez-typu' -WidgetId 'Nieistniejacy'
                Get-TestWidgetEntry -Id 'zepsuty' -ModuleId 'Zepsuty' -WidgetId 'Stan'
            )
            $null = Set-MwpDashboardConfiguration -Widget $widgets -Confirm:$false
        }

        It 'pomija widgety modułów, których nie ma, i usuwa je z zapisu; widget modułu z błędnym kontraktem zostaje w zapisie' {
            $result = Repair-MwpDashboardConfiguration -Definition $definitions -Confirm:$false

            $result.Success | Should -BeTrue
            $result.Changed | Should -BeTrue
            @($result.Data.Widgets | ForEach-Object { $_.Widget.id }) | Should -Be @('ok')
            $result.Data.Widgets[0].Definition.Key | Should -Be 'Dashboard.SystemInfo'
            @($result.Data.Removed | ForEach-Object { $_.Widget.id }) | Should -Be @('odinstalowany', 'bez-typu')
            @($result.Data.Unavailable | ForEach-Object { $_.Widget.id }) | Should -Be @('zepsuty')
            @((Get-MwpDashboardConfiguration).Widgets | ForEach-Object { $_.id }) | Should -Be @('ok', 'zepsuty')
        }

        It '-WhatIf pokazuje, co zostałoby usunięte, i niczego nie zapisuje' {
            $result = Repair-MwpDashboardConfiguration -Definition $definitions -WhatIf

            $result.IsPreview | Should -BeTrue
            @($result.Data.Removed).Count | Should -Be 2
            @((Get-MwpDashboardConfiguration).Widgets).Count | Should -Be 4
        }

        It 'bez widgetów do usunięcia niczego nie zapisuje' {
            $null = Set-MwpDashboardConfiguration -Widget @((Get-TestWidgetEntry -Id 'ok')) -Confirm:$false
            $before = (Get-Item -LiteralPath $localPath).LastWriteTimeUtc

            $result = Repair-MwpDashboardConfiguration -Definition $definitions -Confirm:$false

            $result.Changed | Should -BeFalse
            (Get-Item -LiteralPath $localPath).LastWriteTimeUtc | Should -Be $before
        }
    }

    Context 'kontrakt widgetu (pole Widgets, D-043)' {
        It 'moduł MWP.Dashboard deklaruje poprawny widget „Informacje o systemie” z obsługą komputerów zdalnych' {
            $widget = Get-MwpWidgetDefinition -ModuleId 'Dashboard'

            $widget.Key | Should -Be 'Dashboard.SystemInfo'
            $widget.DataCommand | Should -Be 'Get-MwpSystemInfo'
            $widget.ViewCommand | Should -Be 'ConvertTo-MwpSystemInfoView'
            $widget.ExportCommand | Should -Be 'Export-MwpSystemReport'
            $widget.SupportsRemote | Should -BeTrue
            @($widget.Parameters['Sections']['Values']) | Should -Contain 'Battery'
            (Get-MwpModuleDefinition -Name 'Dashboard').IsValid | Should -BeTrue
        }

        It 'poprawny widget przechodzi walidację, a manifest bez pola Widgets nadal jest poprawny' {
            (Add-TestModule -Name 'Dobry' -Widgets $goodWidget).IsValid | Should -BeTrue
            $plain = Add-TestModule -Name 'Bez' -Widgets '@()' -Modes "@('Embedded')"
            $plain.IsValid | Should -BeTrue
            @(Get-MwpWidgetDefinition -Definition @($plain)).Count | Should -Be 0
        }

        It 'odrzuca widget bez trybu DashboardWidget, z nieeksportowaną funkcją, złym Id i złą częstotliwością' {
            (Add-TestModule -Name 'Tryb' -Widgets $goodWidget -Modes "@('Embedded')").Errors -join ' ' | Should -Match 'DashboardWidget'
            $missing = "@(@{ Id = 'Stan'; Name = 'Stan'; DataCommand = 'Get-MwpBrak'; ViewCommand = 'ConvertTo-MwpTestView' })"
            (Add-TestModule -Name 'Funkcja' -Widgets $missing).Errors -join ' ' | Should -Match 'Get-MwpBrak'
            $badId = "@(@{ Id = '1-zly'; Name = 'Stan'; DataCommand = 'Get-MwpTestData'; ViewCommand = 'ConvertTo-MwpTestView' })"
            (Add-TestModule -Name 'Id' -Widgets $badId).Errors -join ' ' | Should -Match 'Id widgetu'
            $badRefresh = "@(@{ Id = 'Stan'; Name = 'Stan'; DataCommand = 'Get-MwpTestData'; ViewCommand = 'ConvertTo-MwpTestView'; DefaultRefreshSeconds = 7 })"
            (Add-TestModule -Name 'Czas' -Widgets $badRefresh).Errors -join ' ' | Should -Match 'DefaultRefreshSeconds'
            $badDefault = "@(@{ Id = 'Stan'; Name = 'Stan'; DataCommand = 'Get-MwpTestData'; ViewCommand = 'ConvertTo-MwpTestView'; Parameters = @{ Tryb = @{ Type = 'String'; Default = 'z'; Values = @('a') } } })"
            (Add-TestModule -Name 'Domyslna' -Widgets $badDefault).Errors -join ' ' | Should -Match 'spoza listy Values'
        }

        It 'katalog widgetów pomija moduły z błędnym kontraktem' {
            $definitions = @(
                Get-TestModuleDefinition -Id 'A' -Widgets @(@{ Id = 'W'; Name = 'W'; DataCommand = 'Get-A'; ViewCommand = 'ConvertTo-A'; DefaultRefreshSeconds = 30 })
                Get-TestModuleDefinition -Id 'B' -IsValid $false -Widgets @(@{ Id = 'W'; Name = 'W'; DataCommand = 'Get-B'; ViewCommand = 'ConvertTo-B' })
            )

            $catalog = @(Get-MwpWidgetDefinition -Definition $definitions)

            @($catalog | ForEach-Object { $_.Key }) | Should -Be @('A.W')
            $catalog[0].DefaultRefreshSeconds | Should -Be 30
            $catalog[0].SupportsRemote | Should -BeFalse
        }
    }
}
