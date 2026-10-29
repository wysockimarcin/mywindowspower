#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
    Testy widgetów wszystkich modułów i ich konfiguracji w warstwie prezentacji (korekta D-053), bez okien
    WPF: reguła kompletności (każdy moduł wbudowany i paczka przykładowa deklarują widget), sygnatury
    funkcji danych i widoku z kontraktu, odporność funkcji widoku na brak danych, katalog okna „Dodaj
    widżet” (typy z Enabled = $false i ukryte przez użytkownika tylko w katalogu pełnym), dodanie widgetu
    każdego typu (wpis konfiguracji i instancja), PreviousDefault dla widgetów sprzed D-053, pola
    parametrów wspólne dla okna widgetu i widoku „Moduły”, wiersze sekcji „Widżety”. Test
    architektoniczny: funkcje danych i widoku widgetów nie wywołują poleceń zmieniających system.
    Ustawienia na TestDrive; operacje tylko tworzą instancje localhost i niczego nie zmieniają.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Zmienne z bloków BeforeDiscovery/BeforeAll są używane w blokach It (zakresy Pestera).')]
param()

BeforeDiscovery {
    $root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $moduleNames = @(Get-ChildItem -LiteralPath (Join-Path -Path $root -ChildPath 'src\Modules') -Directory -Filter 'MWP.*' | ForEach-Object Name)
}

Describe 'Widgety wszystkich modułów i ich konfiguracja (D-053)' {
    BeforeAll {
        $root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        $modulesRoot = Join-Path -Path $root -ChildPath 'src\Modules'
        foreach ($directory in @(Get-ChildItem -LiteralPath $modulesRoot -Directory -Filter 'MWP.*')) {
            Import-Module -Name (Join-Path -Path $directory.FullName -ChildPath ($directory.Name + '.psd1')) -Force -WarningAction SilentlyContinue
        }
        Import-Module -Name (Join-Path -Path $root -ChildPath 'src\UI\MWP.UI.psm1') -Force
        $configDirectory = Join-Path -Path $TestDrive -ChildPath 'config'
        $null = New-Item -ItemType Directory -Path $configDirectory -Force
        Copy-Item -LiteralPath (Join-Path -Path $root -ChildPath 'config\settings.example.json') -Destination (Join-Path -Path $configDirectory -ChildPath 'settings.example.json')
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
        $definitions = @(Get-MwpModuleDefinition -ModulesRoot $modulesRoot)
        $sample = @(Get-MwpModuleDefinition -ModulesRoot $modulesRoot, (Join-Path -Path $root -ChildPath 'samples') -Name 'Przyklad')
        $catalog = @(Get-MwpWidgetDefinition -Definition $definitions -WidgetSetting @())
        # Funkcje zmieniające system (czasowniki zmiany) — widget tylko odczytuje (zasada 5, D-043).
        $changePattern = '^(Set|Remove|Clear|Stop|Restart|Uninstall|Install|Enable|Disable|Suspend|Resume|Update|Approve|Import|Save|Invoke-MwpUndo|Rename|New-Mwp(Restore|Undo))-'
    }

    Context 'reguła kompletności: każdy moduł deklaruje widget' {
        It 'moduł <_> ma poprawny kontrakt i co najmniej jeden widget z trybem DashboardWidget' -ForEach $moduleNames {
            $definition = @($definitions | Where-Object ModuleName -eq $_)[0]
            $definition.IsValid | Should -BeTrue -Because ($definition.Errors -join ' ')
            @($definition.Widgets).Count | Should -BeGreaterThan 0 -Because 'każdy moduł deklaruje widget (D-053); użytkownik może go ukryć w widoku „Moduły”'
            @($definition.SupportedPresentationModes) | Should -Contain 'DashboardWidget'
        }

        It 'paczka przykładowa (wzorzec dla autorów modułów) też deklaruje widget' {
            $sample[0].IsValid | Should -BeTrue -Because ($sample[0].Errors -join ' ')
            @($sample[0].Widgets).Count | Should -BeGreaterThan 0
        }

        It 'katalog zawiera widget każdego modułu; klucze są unikalne; SupportsRemote = RemoteTarget i nie LocalOnly' {
            @($catalog.ModuleName | Select-Object -Unique).Count | Should -Be $definitions.Count
            @($catalog.Key | Select-Object -Unique).Count | Should -Be $catalog.Count
            @($catalog).Count | Should -Be (@($definitions | ForEach-Object { @($_.Widgets).Count }) | Measure-Object -Sum).Sum
            foreach ($widget in $catalog) {
                $module = @($definitions | Where-Object Id -eq $widget.ModuleId)[0]
                $widget.SupportsRemote | Should -Be (@($module.Capabilities) -contains 'RemoteTarget' -and -not $widget.LocalOnly) -Because $widget.Key
            }
            @($catalog | Where-Object { $_.Key -in @('Core.OperationLog', 'Remote.TargetStatus') -and $_.SupportsRemote }) | Should -BeNullOrEmpty
        }

        It 'funkcje danych mają sygnaturę kontraktu (-Context, -AsOperation, -WidgetParameters), a funkcje widoku (-Data, -WidgetParameters)' {
            foreach ($widget in @($catalog) + @(Get-MwpWidgetDefinition -Definition $sample -WidgetSetting @())) {
                $data = Get-Command -Name $widget.DataCommand -ErrorAction SilentlyContinue
                if ($widget.ModuleId -eq 'Przyklad') {
                    continue
                }
                $data | Should -Not -BeNullOrEmpty -Because $widget.Key
                foreach ($name in 'Context', 'AsOperation', 'WidgetParameters') {
                    $data.Parameters.Keys | Should -Contain $name -Because ('{0}: {1}' -f $widget.Key, $widget.DataCommand)
                }
                $view = Get-Command -Name $widget.ViewCommand
                foreach ($name in 'Data', 'WidgetParameters') {
                    $view.Parameters.Keys | Should -Contain $name -Because ('{0}: {1}' -f $widget.Key, $widget.ViewCommand)
                }
            }
        }

        It 'funkcje widoku zwracają $null bez wyjątku dla braku danych i danych nieczytelnych' {
            foreach ($widget in $catalog) {
                $command = $widget.ViewCommand
                { & $command -Data $null -WidgetParameters @{} } | Should -Not -Throw -Because $widget.Key
                & $command -Data $null -WidgetParameters @{} | Should -BeNullOrEmpty -Because $widget.Key
                & $command -Data 'to nie jest JSON' -WidgetParameters $widget.DefaultParameters | Should -BeNullOrEmpty -Because $widget.Key
            }
        }

        It 'domyślne parametry każdego widgetu spełniają jego schemat (minimum danych, D-053)' {
            foreach ($widget in $catalog) {
                foreach ($key in @($widget.Parameters.Keys)) {
                    $widget.DefaultParameters.Contains($key) | Should -BeTrue -Because ('{0}.{1}' -f $widget.Key, $key)
                }
            }
        }

        It 'test architektoniczny: funkcje danych i widoku widgetów nie wywołują poleceń zmieniających system' {
            foreach ($widget in $catalog) {
                foreach ($name in $widget.DataCommand, $widget.ViewCommand) {
                    $command = Get-Command -Name $name
                    $calls = @($command.ScriptBlock.Ast.FindAll({ param($node) $node -is [Management.Automation.Language.CommandAst] }, $true) |
                            ForEach-Object { $_.GetCommandName() } | Where-Object { $_ -and $_ -match $changePattern })
                    $calls | Should -BeNullOrEmpty -Because ('{0}: {1}' -f $widget.Key, $name)
                }
            }
        }
    }

    Context 'okno „Dodaj widżet” i dodawanie widgetów' {
        BeforeEach {
            Remove-Item -LiteralPath (Join-Path -Path $configDirectory -ChildPath 'settings.local.json') -Force -ErrorAction SilentlyContinue
        }

        It 'katalog do dodawania ma wszystkie typy oprócz domyślnie nieoferowanych (zalążki Security i Tweaks)' {
            $addable = @(Get-MwpWidgetDefinition -Definition $definitions -Addable)
            @($addable).Count | Should -Be (@($catalog | Where-Object Enabled).Count)
            @($catalog | Where-Object { -not $_.Enabled } | ForEach-Object ModuleId | Sort-Object) | Should -Be @('Security', 'Tweaks')
            foreach ($key in 'Update.UpdateStatus', 'Network.NetworkStatus', 'Startup.StartupSummary', 'Apps.AppsSummary', 'Apps.AppsUpdates', 'Cleanup.CleanupEstimate', 'Core.OperationLog', 'Remote.TargetStatus', 'Dashboard.SystemInfo', 'Power.PowerStatus', 'Services.ServiceStatus') {
                @($addable.Key) | Should -Contain $key
            }
        }

        It 'typ ukryty przez użytkownika znika z katalogu do dodawania, a domyślne parametry użytkownika są wartościami początkowymi' {
            $null = Set-MwpWidgetSetting -ModuleId Dashboard -WidgetId SystemInfo -Visible $false -Definition $definitions -Confirm:$false
            $null = Set-MwpWidgetSetting -ModuleId Power -WidgetId PowerStatus -DefaultParameters @{ Sections = @('Plan', 'Hibernate') } -Definition $definitions -Confirm:$false
            $addable = @(Get-MwpWidgetDefinition -Definition $definitions -Addable)
            @($addable.Key) | Should -Not -Contain 'Dashboard.SystemInfo'
            @((Get-MwpWidgetDefinition -Definition $definitions).Key) | Should -Contain 'Dashboard.SystemInfo'
            $power = @($addable | Where-Object Key -eq 'Power.PowerStatus')[0]
            $fields = @(Get-MwpWidgetParameterField -Schema $power.Parameters -Value $power.DefaultParameters)
            @($fields[0].Options | Where-Object Checked | ForEach-Object Value) | Should -Be @('Plan', 'Hibernate')
        }

        It 'dodanie widgetu każdego typu tworzy poprawny wpis konfiguracji i instancję modułu bez WPF' {
            foreach ($widget in @(Get-MwpWidgetDefinition -Definition $definitions -WidgetSetting @())) {
                $entry = [ordered]@{
                    id = [guid]::NewGuid().ToString(); moduleId = $widget.ModuleId; widgetId = $widget.WidgetId; computerName = 'localhost'; title = ''
                    refreshSeconds = $widget.DefaultRefreshSeconds; size = 'Normal'; parameters = $widget.DefaultParameters
                }
                $normalized = InModuleScope MWP.Core -Parameters @{ Entry = $entry } { param($Entry) ConvertTo-MwpDashboardWidget -InputObject $Entry }
                $runtime = New-MwpWidgetRuntime -Configuration $normalized -Definition $widget
                try {
                    $runtime.Instance | Should -Not -BeNullOrEmpty -Because $widget.Key
                    $runtime.Instance.Context.ComputerName | Should -Be 'localhost'
                    foreach ($key in @($widget.Parameters.Keys)) {
                        $runtime.Parameters.Contains($key) | Should -BeTrue -Because ('{0}.{1}' -f $widget.Key, $key)
                    }
                }
                finally {
                    Remove-MwpWidgetRuntime -Widget $runtime -Confirm:$false
                }
            }
        }

        It 'widget zapisany przed D-053 (bez nowego parametru) dostaje PreviousDefault, nowy — Default' {
            $power = @($catalog | Where-Object Key -eq 'Power.PowerStatus')[0]
            @((Get-MwpWidgetParameterSet -Configuration @{ parameters = @{} } -Definition $power)['Sections']) | Should -Be @('Plan', 'Timeouts', 'Hibernate')
            @((Get-MwpWidgetParameterSet -Configuration @{ parameters = @{ Sections = @('Plan') } } -Definition $power)['Sections']) | Should -Be @('Plan')
            @($power.DefaultParameters['Sections']) | Should -Be @('Plan')
            $system = @($catalog | Where-Object Key -eq 'Dashboard.SystemInfo')[0]
            @((Get-MwpWidgetParameterSet -Configuration @{ parameters = @{} } -Definition $system)['Sections']) | Should -Be @('System', 'Cpu', 'Memory', 'Disks')
        }
    }

    Context 'pola parametrów (wspólne dla okna widgetu i widoku „Moduły”)' {
        It 'rodzaje pól, etykiety wartości i wartości początkowe ze schematu albo z -Value' {
            $schema = [ordered]@{
                Sekcje = @{ Type = 'StringArray'; Default = @('A'); Values = @('A', 'B'); Label = 'Sekcje'; ValueLabels = @{ A = 'Pierwsza'; B = 'Druga' } }
                Flaga  = @{ Type = 'Bool'; Default = $true }
                Liczba = @{ Type = 'Int'; Default = 5; Label = 'Liczba' }
                Nazwy  = @{ Type = 'StringArray'; Default = @('x', 'y') }
            }
            $fields = @(Get-MwpWidgetParameterField -Schema $schema -Value @{ Liczba = 7 })
            @($fields.Key) | Should -Be @('Flaga', 'Liczba', 'Nazwy', 'Sekcje')
            @($fields.Kind) | Should -Be @('Bool', 'Int', 'StringArray', 'Choices')
            $fields[0].Checked | Should -BeTrue
            $fields[1].Text | Should -Be '7'
            $fields[2].Text | Should -Be 'x, y'
            @($fields[3].Options.Text) | Should -Be @('Pierwsza', 'Druga')
            @($fields[3].Options | Where-Object Checked | ForEach-Object Value) | Should -Be @('A')
        }

        It 'odczyt wartości: typy, pusta lista wyborów i zła liczba dają komunikat' {
            $schema = [ordered]@{ S = @{ Type = 'StringArray'; Default = @('A'); Values = @('A', 'B') }; N = @{ Type = 'Int'; Default = 1 }; T = @{ Type = 'StringArray'; Default = @() }; F = @{ Type = 'Bool'; Default = $false } }
            $fields = @(Get-MwpWidgetParameterField -Schema $schema)
            $ok = ConvertFrom-MwpWidgetParameterInput -Field $fields -Entry @{ S = @('B', 'A'); N = '3'; T = 'a, b ,'; F = $true }
            $ok.Problem | Should -BeNullOrEmpty
            @($ok.Parameters['S']) | Should -Be @('A', 'B')
            $ok.Parameters['N'] | Should -Be 3
            @($ok.Parameters['T']) | Should -Be @('a', 'b')
            $ok.Parameters['F'] | Should -BeTrue
            (ConvertFrom-MwpWidgetParameterInput -Field $fields -Entry @{ S = @(); N = '3' }).Problem | Should -Match 'co najmniej jedną'
            (ConvertFrom-MwpWidgetParameterInput -Field $fields -Entry @{ S = @('A'); N = 'pięć' }).Problem | Should -Match 'liczbą całkowitą'
        }

        It 'wiersze sekcji „Widżety”: widoczność, ustawienia użytkownika, opis z komputerami i odświeżaniem' {
            $settings = @([pscustomobject]@{ PSTypeName = 'MWP.WidgetSetting'; ModuleId = 'Apps'; WidgetId = 'AppsUpdates'; Visible = $false; DefaultParameters = [ordered]@{ Top = 3 } })
            $apps = @(Get-MwpWidgetDefinition -Definition $definitions -ModuleId Apps -WidgetSetting $settings)
            $rows = @(Get-MwpWidgetSettingRow -Definition $apps -ModuleId Apps -WidgetSetting $settings)
            @($rows.WidgetId) | Should -Be @('AppsUpdates', 'AppsSummary')
            $rows[0].Visible | Should -BeFalse
            $rows[0].Title | Should -Match 'ukryty'
            $rows[0].UserVisible | Should -BeFalse
            $rows[0].HasUserDefaults | Should -BeTrue
            $rows[0].DefaultParameters['Top'] | Should -Be 3
            $rows[0].Description | Should -Match 'tylko ręcznie'
            $rows[1].HasUserSetting | Should -BeFalse
            $rows[1].Description | Should -Match 'ten komputer i zdalne'
            $security = @(Get-MwpWidgetSettingRow -Definition $catalog -ModuleId Security)
            $security[0].Visible | Should -BeFalse
            $security[0].Description | Should -Match 'domyślnie nie oferuje'
        }
    }

    Context 'widget „Komputery” (MWP.Remote)' {
        It 'widok: dostępność z czasem i stanem hasła, bez prób — tylko stan hasła; pusty rejestr — podpowiedź' {
            $raw = ConvertTo-Json -Compress -Depth 4 -InputObject ([pscustomobject]@{
                    Kind = 'MWP.TargetStatusRaw'; CollectedAt = '2026-10-29T10:00:00Z'; Probe = $true
                    Targets = @(
                        [pscustomobject]@{ Name = 'PC-TEST1'; DisplayName = 'Serwer'; Port = 5985; Credential = 'Verified'; Reachable = $true; LatencyMs = 12; Error = $null }
                        [pscustomobject]@{ Name = 'PC-TEST2'; DisplayName = 'PC-TEST2'; Port = 5985; Credential = 'None'; Reachable = $false; LatencyMs = $null; Error = 'brak odpowiedzi w 1 s' }
                    )
                })
            $view = ConvertTo-MwpTargetStatusView -Data $raw
            $view.Summary | Should -Be 'Komputery zdalne: 2 · dostępne 1'
            $view.Sections[0].Items[0].Label | Should -Be 'Serwer (PC-TEST1)'
            $view.Sections[0].Items[0].Value | Should -Match '12 ms · hasło sprawdzone'
            $view.Sections[0].Items[1].Tone | Should -Be 'Danger'
            $empty = ConvertTo-MwpTargetStatusView -Data '{"Kind":"MWP.TargetStatusRaw","Probe":false,"Targets":[]}'
            $empty.Sections[0].Items[0].Value | Should -Match 'dodaj komputer'
        }

        It 'funkcja danych odmawia komputera zdalnego; -NoProbe nie próbuje połączeń' {
            $remote = [pscustomobject]@{ PSTypeName = 'MWP.ExecutionContext'; ComputerName = 'PC-TEST1'; Mode = 'Remote' }
            (Get-MwpTargetStatus -Context $remote).Success | Should -BeFalse
            $result = Get-MwpTargetStatus -NoProbe
            $result.Success | Should -BeTrue -Because $result.Message
            $result.Data.Probe | Should -BeFalse
        }
    }
}
