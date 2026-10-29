#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
    Testy konfiguracji widgetów modułu (korekta D-053): pola Enabled, LocalOnly i PreviousDefault kontraktu
    widgetu, ustawienia użytkownika modules.<Id>.widgets.<Id> (Get-/Set-MwpWidgetSetting), katalog pełny
    i katalog do dodawania (Get-MwpWidgetDefinition -Addable), domyślne parametry nowych widgetów,
    odtwarzanie Dashboardu z widgetem ukrytego typu, widget „Dziennik operacji” modułu MWP.Core.
    Ustawienia i dziennik na TestDrive; system bez zmian.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Zmienne z bloków BeforeDiscovery/BeforeAll są używane w blokach It (zakresy Pestera).')]
param()

Describe 'Konfiguracja widgetów modułu (D-053)' {
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

        function Add-TestModule {
            param([string] $Name, [string] $Widgets)
            $directory = Join-Path -Path $fixtures -ChildPath "MWP.$Name"
            $null = New-Item -ItemType Directory -Path $directory -Force
            $text = @(
                '@{'
                "    RootModule = 'MWP.$Name.psm1'"
                "    ModuleVersion = '1.0.0'"
                "    FunctionsToExport = @('Get-MwpTestModuleInfo', 'Get-MwpTestData', 'ConvertTo-MwpTestView')"
                "    PrivateData = @{ MWP = @{ ContractVersion = 1; Id = '$Name'; Name = 'Test $Name'; EntryPoint = 'Get-MwpTestModuleInfo'; MinimumHostVersion = '0.2.0';"
                "        Dependencies = @(); Capabilities = @('Read', 'RemoteTarget'); SupportedPresentationModes = @('DashboardWidget'); RequiredPermissions = @('User'); ConfigurationSchema = @{}; Widgets = $Widgets } }"
                '}'
            ) -join [Environment]::NewLine
            Set-Content -LiteralPath (Join-Path -Path $directory -ChildPath "MWP.$Name.psd1") -Value $text -Encoding UTF8
            Get-MwpModuleDefinition -ModulesRoot $fixtures -HostVersion '0.12.1' -Name $Name
        }
        function Get-LocalSetting {
            Get-Content -LiteralPath $localPath -Raw -Encoding UTF8 | ConvertFrom-Json
        }
        $widgets = "@(" +
        "@{ Id = 'Stan'; Name = 'Stan'; DataCommand = 'Get-MwpTestData'; ViewCommand = 'ConvertTo-MwpTestView'; Parameters = @{ Tryb = @{ Type = 'StringArray'; Default = @('a'); PreviousDefault = @('a', 'b'); Values = @('a', 'b', 'c') }; Limit = @{ Type = 'Int'; Default = 5 }; Pelny = @{ Type = 'Bool'; Default = `$false } } }; " +
        "@{ Id = 'Ukryty'; Name = 'Ukryty'; DataCommand = 'Get-MwpTestData'; ViewCommand = 'ConvertTo-MwpTestView'; Enabled = `$false }; " +
        "@{ Id = 'Lokalny'; Name = 'Lokalny'; DataCommand = 'Get-MwpTestData'; ViewCommand = 'ConvertTo-MwpTestView'; LocalOnly = `$true }" +
        ")"
    }

    AfterAll {
        Remove-Module -Name MWP.Core -Force -ErrorAction SilentlyContinue
    }

    BeforeEach {
        Get-ChildItem -LiteralPath $configDirectory -Filter 'settings.local.json*' | Remove-Item -Force
        Remove-Item -LiteralPath $fixtures -Recurse -Force -ErrorAction SilentlyContinue
        $null = New-Item -ItemType Directory -Path $fixtures -Force
        $module = Add-TestModule -Name 'Proba' -Widgets $widgets
    }

    Context 'kontrakt: Enabled, LocalOnly, PreviousDefault' {
        It 'manifest bez Enabled ma Enabled = $true; Enabled = $false jest w katalogu pełnym, ale nie w katalogu do dodawania' {
            $module.IsValid | Should -BeTrue -Because ($module.Errors -join ' ')
            $full = @(Get-MwpWidgetDefinition -Definition @($module) -WidgetSetting @())
            @($full.WidgetId) | Should -Be @('Stan', 'Ukryty', 'Lokalny')
            ($full | Where-Object WidgetId -eq 'Stan').Enabled | Should -BeTrue
            ($full | Where-Object WidgetId -eq 'Ukryty').Enabled | Should -BeFalse
            ($full | Where-Object WidgetId -eq 'Ukryty').Visible | Should -BeFalse
            @((Get-MwpWidgetDefinition -Definition @($module) -WidgetSetting @() -Addable).WidgetId) | Should -Be @('Stan', 'Lokalny')
        }

        It 'LocalOnly wyłącza komputery zdalne mimo RemoteTarget modułu' {
            $full = @(Get-MwpWidgetDefinition -Definition @($module) -WidgetSetting @())
            ($full | Where-Object WidgetId -eq 'Lokalny').SupportsRemote | Should -BeFalse
            ($full | Where-Object WidgetId -eq 'Lokalny').LocalOnly | Should -BeTrue
            ($full | Where-Object WidgetId -eq 'Stan').SupportsRemote | Should -BeTrue
        }

        It 'odrzuca Enabled i LocalOnly niebędące wartością logiczną oraz PreviousDefault spoza Values' {
            $bad = Add-TestModule -Name 'Zly' -Widgets "@(@{ Id = 'A'; Name = 'A'; DataCommand = 'Get-MwpTestData'; ViewCommand = 'ConvertTo-MwpTestView'; Enabled = 'tak'; LocalOnly = 1; Parameters = @{ P = @{ Type = 'StringArray'; Default = @('a'); PreviousDefault = @('z'); Values = @('a') } } })"
            $bad.IsValid | Should -BeFalse
            ($bad.Errors -join ' ') | Should -Match 'Enabled'
            ($bad.Errors -join ' ') | Should -Match 'LocalOnly'
            ($bad.Errors -join ' ') | Should -Match 'PreviousDefault'
        }

        It 'DefaultParameters bez ustawień użytkownika to Default ze schematu (nie PreviousDefault)' {
            $definition = Get-MwpWidgetDefinition -Definition @($module) -WidgetSetting @() | Where-Object WidgetId -eq 'Stan'
            @($definition.DefaultParameters['Tryb']) | Should -Be @('a')
            $definition.DefaultParameters['Limit'] | Should -Be 5
        }
    }

    Context 'ustawienia użytkownika i katalog' {
        It 'stary settings.local.json bez kluczy widgetów działa bez migracji (brak ustawień)' {
            Set-Content -LiteralPath $localPath -Value '{ "schemaVersion": 2, "theme": "Dark", "modules": { "Proba": { "filtr": "x" } } }' -Encoding UTF8
            @(Get-MwpWidgetSetting) | Should -BeNullOrEmpty
            @((Get-MwpWidgetDefinition -Definition @($module) -Addable).WidgetId) | Should -Be @('Stan', 'Lokalny')
        }

        It 'visible z ustawień ma pierwszeństwo przed manifestem; ukryty typ zostaje w katalogu pełnym' {
            (Set-MwpWidgetSetting -ModuleId Proba -WidgetId Stan -Visible $false -Definition @($module) -Confirm:$false).Success | Should -BeTrue
            (Set-MwpWidgetSetting -ModuleId Proba -WidgetId Ukryty -Visible $true -Definition @($module) -Confirm:$false).Success | Should -BeTrue
            @((Get-MwpWidgetDefinition -Definition @($module) -Addable).WidgetId) | Should -Be @('Ukryty', 'Lokalny')
            @((Get-MwpWidgetDefinition -Definition @($module)).WidgetId) | Should -Be @('Stan', 'Ukryty', 'Lokalny')
            $saved = Get-LocalSetting
            $saved.modules.Proba.widgets.Stan.visible | Should -BeFalse
            $saved.modules.Proba.widgets.Ukryty.visible | Should -BeTrue
        }

        It 'skrót „ukryj wszystkie widżety modułu” ustawia visible = false dla każdego typu; inne ustawienia modułu zostają' {
            Set-Content -LiteralPath $localPath -Value '{ "schemaVersion": 2, "modules": { "Proba": { "filtr": "x" }, "Inny": { "a": 1 } } }' -Encoding UTF8
            $result = Set-MwpWidgetSetting -ModuleId Proba -WidgetId Stan, Ukryty, Lokalny -Visible $false -Definition @($module) -Confirm:$false
            $result.Success | Should -BeTrue
            @(Get-MwpWidgetDefinition -Definition @($module) -Addable) | Should -BeNullOrEmpty
            $saved = Get-LocalSetting
            $saved.modules.Proba.filtr | Should -Be 'x'
            $saved.modules.Inny.a | Should -Be 1
            @($saved.modules.Proba.widgets.PSObject.Properties.Name) | Should -Be @('Stan', 'Ukryty', 'Lokalny')
        }

        It 'domyślne parametry: poprawne zapisują się i trafiają do DefaultParameters; niepoprawne są odrzucane bez zapisu' {
            $ok = Set-MwpWidgetSetting -ModuleId Proba -WidgetId Stan -DefaultParameters @{ Tryb = @('b', 'c'); Limit = '3'; Pelny = 'true' } -Definition @($module) -Confirm:$false
            $ok.Success | Should -BeTrue -Because $ok.Message
            $definition = Get-MwpWidgetDefinition -Definition @($module) | Where-Object WidgetId -eq 'Stan'
            @($definition.DefaultParameters['Tryb']) | Should -Be @('b', 'c')
            $definition.DefaultParameters['Limit'] | Should -Be 3
            $definition.DefaultParameters['Pelny'] | Should -BeTrue
            $before = Get-Content -LiteralPath $localPath -Raw
            foreach ($bad in @(@{ Tryb = @('z') }, @{ Limit = 'pięć' }, @{ Nieznany = 1 }, @{ Tryb = @() })) {
                $result = Set-MwpWidgetSetting -ModuleId Proba -WidgetId Stan -DefaultParameters $bad -Definition @($module) -Confirm:$false
                $result.Success | Should -BeFalse
                $result.Message | Should -Match 'Niepoprawne domyślne parametry'
            }
            Get-Content -LiteralPath $localPath -Raw | Should -Be $before
        }

        It 'niepoprawne defaultParameters w pliku są zastępowane wartością z manifestu z ostrzeżeniem w logu' {
            Set-Content -LiteralPath $localPath -Value '{ "schemaVersion": 2, "modules": { "Proba": { "widgets": { "Stan": { "defaultParameters": { "Tryb": ["z"], "Limit": 7, "Obcy": 1 } } } } } }' -Encoding UTF8
            $definition = Get-MwpWidgetDefinition -Definition @($module) | Where-Object WidgetId -eq 'Stan'
            @($definition.DefaultParameters['Tryb']) | Should -Be @('a')
            $definition.DefaultParameters['Limit'] | Should -Be 7
            $definition.DefaultParameters.Contains('Obcy') | Should -BeFalse
            (Get-ChildItem -LiteralPath (Join-Path $TestDrive 'Logs') -Filter '*.log' | Get-Content -Raw -Encoding UTF8) | Should -Match 'Pominięto domyślny parametr'
        }

        It '-Reset przywraca wartości z manifestu; -WhatIf niczego nie zapisuje; brak wpisu w rejestrze cofnięć' {
            $null = Set-MwpWidgetSetting -ModuleId Proba -WidgetId Stan -Visible $false -Definition @($module) -Confirm:$false
            $before = Get-Content -LiteralPath $localPath -Raw
            $preview = Set-MwpWidgetSetting -ModuleId Proba -WidgetId Stan -Visible $true -Definition @($module) -WhatIf
            $preview.IsPreview | Should -BeTrue
            Get-Content -LiteralPath $localPath -Raw | Should -Be $before
            (Set-MwpWidgetSetting -ModuleId Proba -WidgetId Stan -Reset -Definition @($module) -Confirm:$false).Success | Should -BeTrue
            @((Get-LocalSetting).modules.PSObject.Properties | ForEach-Object Name) | Should -Not -Contain 'Proba'
            Test-Path -LiteralPath (Join-Path $TestDrive 'Undo') | Should -BeFalse
            @(Get-ChildItem -LiteralPath $TestDrive -Recurse -Filter '*.json' | Where-Object { $_.DirectoryName -match 'undo' }) | Should -BeNullOrEmpty
        }

        It 'odrzuca nieznany widget, łączenie -Reset z -Visible i parametry dla kilku typów' {
            (Set-MwpWidgetSetting -ModuleId Proba -WidgetId Brak -Visible $false -Definition @($module) -Confirm:$false).Message | Should -Match 'nie ma widgetu'
            (Set-MwpWidgetSetting -ModuleId Proba -WidgetId Stan -Reset -Visible $true -Definition @($module) -Confirm:$false).Success | Should -BeFalse
            (Set-MwpWidgetSetting -ModuleId Proba -WidgetId Stan, Lokalny -DefaultParameters @{} -Definition @($module) -Confirm:$false).Success | Should -BeFalse
            Test-Path -LiteralPath $localPath | Should -BeFalse
        }
    }

    Context 'Dashboard i ukryty typ widgetu' {
        It 'Repair-MwpDashboardConfiguration odtwarza widget ukrytego typu i niczego nie usuwa' {
            $entry = [ordered]@{ id = 'w1'; moduleId = 'Proba'; widgetId = 'Stan'; computerName = 'localhost'; title = ''; refreshSeconds = 60; size = 'Normal'; parameters = [ordered]@{} }
            (Set-MwpDashboardConfiguration -Widget @($entry) -Confirm:$false).Success | Should -BeTrue
            $null = Set-MwpWidgetSetting -ModuleId Proba -WidgetId Stan -Visible $false -Definition @($module) -Confirm:$false
            $repair = Repair-MwpDashboardConfiguration -Definition @($module) -Confirm:$false
            @($repair.Data.Widgets).Count | Should -Be 1
            @($repair.Data.Removed) | Should -BeNullOrEmpty
            @((Get-MwpDashboardConfiguration).Widgets.id) | Should -Be @('w1')
        }
    }

    Context 'widget „Dziennik operacji” (MWP.Core)' {
        It 'liczy wpisy wg poziomu z dzisiejszego dziennika, pokazuje ostatnie z wybranych poziomów i liczbę zmian do cofnięcia' {
            Write-MwpLog -Level Error -Source 'Test' -Operation 'Test.Blad' -Message 'pierwszy błąd'
            Write-MwpLog -Level Warning -Source 'Test' -Operation 'Test.Ostrzezenie' -Message 'ostrzeżenie'
            Write-MwpLog -Level Error -Source 'Test' -Operation 'Test.Blad2' -Message 'drugi błąd'
            $result = Get-MwpLogSummary -WidgetParameters @{ Levels = @('Error'); Top = 1 }
            $result.Success | Should -BeTrue
            $result.Data.Counts.Error | Should -Be 2
            $result.Data.Counts.Warning | Should -Be 1
            @($result.Data.Entries).Count | Should -Be 1
            $result.Data.Entries[0].Message | Should -Be 'drugi błąd'
            $view = ConvertTo-MwpLogSummaryView -Data $result.Data
            $view.PSObject.TypeNames | Should -Contain 'MWP.WidgetView'
            $view.Sections[0].Items[0].Tone | Should -Be 'Danger'
            ConvertTo-MwpLogSummaryView -Data $null | Should -BeNullOrEmpty
            ConvertTo-MwpLogSummaryView -Data 'to nie jest JSON' | Should -BeNullOrEmpty
        }

        It 'odmawia komputera zdalnego (widget LocalOnly)' {
            $remote = [pscustomobject]@{ PSTypeName = 'MWP.ExecutionContext'; ComputerName = 'PC-TEST1'; Mode = 'Remote' }
            (Get-MwpLogSummary -Context $remote).Success | Should -BeFalse
            { Get-MwpLogSummary -Context $remote -AsOperation } | Should -Throw '*tylko dla komputera lokalnego*'
        }
    }
}
