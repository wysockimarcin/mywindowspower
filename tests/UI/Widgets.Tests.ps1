#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
    Testy widgetów Dashboardu w warstwie prezentacji (FAZA 5, D-043), bez okien WPF: cykl życia widgetu
    (własna instancja modułu), harmonogram odświeżania z limitem, stany (ładowanie, błąd, brak danych,
    utrata połączenia, wymaga poświadczeń), izolacja (awaria albo utrata połączenia jednego widgetu nie
    zatrzymuje pozostałych; usunięcie widgetu anuluje jego zadanie i zamyka instancję) oraz zapis
    i odtworzenie konfiguracji. Testy architektoniczne 5, 6, 7 i 10 z ARCHITEKTURA.md. Operacje działają
    na localhost i niczego nie zmieniają; komputer zdalny jest symulowany (uchwyt operacji z błędem).
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Zmienne z bloków BeforeDiscovery/BeforeAll są używane w blokach It (zakresy Pestera).')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalFunctions', '',
    Justification = 'Funkcje danych i widoku widgetu testowego muszą być widoczne z modułu MWP.UI (kontrakt widgetu wywołuje je po nazwie).')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '',
    Justification = 'Funkcje testowe mają sygnaturę kontraktu widgetu, także gdy nie używają wszystkich parametrów.')]
param()

Describe 'Widgety Dashboardu — izolacja i cykl życia' {
    BeforeAll {
        $root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        foreach ($name in 'MWP.Core', 'MWP.Remote', 'MWP.Dashboard') {
            Import-Module -Name (Join-Path -Path $root -ChildPath "src\Modules\$name\$name.psd1") -Force
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
        $remoteName = 'PC-TEST1'
        $passwordName = 'PC-HASLO'
        $unknownName = 'PC-NIEZNANY'
        $local = [ordered]@{ schemaVersion = 2; targets = @(@{ name = $remoteName; authentication = 'CurrentUser' }, @{ name = $passwordName; authentication = 'Credential' }) }
        ConvertTo-Json -InputObject $local -Depth 5 | Set-Content -LiteralPath (Join-Path -Path $configDirectory -ChildPath 'settings.local.json') -Encoding UTF8

        # Funkcja danych widgetu testowego (kontrakt: -Context -AsOperation -WidgetParameters → MWP.Operation).
        function global:Get-MwpTestWidgetData {
            param($Context, [switch] $AsOperation, $WidgetParameters)
            switch ([string]$WidgetParameters['Tryb']) {
                'Throw' { throw 'awaria funkcji danych' }
                'Lost' {
                    [pscustomobject]@{
                        PSTypeName = 'MWP.Operation'; Id = [guid]::NewGuid().ToString(); Operation = 'Test.Dane'; ComputerName = $Context.ComputerName
                        InstanceId = $Context.InstanceId; StartedAt = Get-Date; TimeoutSeconds = 60; Status = 'Failed'; AsyncResult = $null; PowerShell = $null
                        Result = New-MwpResult -Success $false -ComputerName $Context.ComputerName -Message "Komputer '$($Context.ComputerName)' nie odpowiada." -Data ([ordered]@{ ErrorKind = 'Network' })
                    }
                }
                'Slow' { Start-MwpOperation -Context $Context -ScriptBlock { Start-Sleep -Seconds 30; 'za późno' } -Operation 'Test.Wolno' }
                default { Start-MwpOperation -Context $Context -ScriptBlock { param($Value) "dane:$Value" } -ArgumentList ([string]$WidgetParameters['Tryb']) -Operation 'Test.Dane' }
            }
        }
        # Funkcja widoku widgetu testowego (kontrakt: -Data -WidgetParameters → MWP.WidgetView).
        function global:ConvertTo-MwpTestWidgetView {
            param($Data, $WidgetParameters)
            if (@($Data) -contains 'dane:pusty') {
                return $null
            }
            if (@($Data) -contains 'dane:zly-widok') {
                throw 'błąd widoku'
            }
            [pscustomobject]@{
                PSTypeName = 'MWP.WidgetView'; Summary = 'podsumowanie'; Warnings = @()
                Sections   = @([pscustomobject]@{ Title = 'Sekcja'; Items = @([pscustomobject]@{ Label = 'Wartość'; Value = (@($Data) -join ','); Percent = 50; Tone = 'Success' }) })
            }
        }
        $definition = [pscustomobject]@{
            PSTypeName = 'MWP.WidgetDefinition'; Key = 'Dashboard.Test'; ModuleId = 'Dashboard'; ModuleName = 'MWP.Dashboard'; ModuleTitle = 'Informacje o systemie'
            WidgetId = 'Test'; Name = 'Widget testowy'; Description = ''; DataCommand = 'Get-MwpTestWidgetData'; ViewCommand = 'ConvertTo-MwpTestWidgetView'
            ExportCommand = 'Export-MwpSystemReport'; DefaultRefreshSeconds = 60; Parameters = [ordered]@{ Tryb = @{ Type = 'String'; Default = 'ok' } }; SupportsRemote = $true
        }

        function Get-TestWidget {
            param([string] $Id, [string] $Mode = 'ok', [string] $ComputerName = 'localhost', [int] $Refresh = 60)
            $config = [ordered]@{ id = $Id; moduleId = 'Dashboard'; widgetId = 'Test'; computerName = $ComputerName; title = ''; refreshSeconds = $Refresh; size = 'Normal'; parameters = [ordered]@{ Tryb = $Mode } }
            New-MwpWidgetRuntime -Configuration $config -Definition $definition
        }
        function Invoke-TestRefresh {
            param([object[]] $Widget, [int] $MaxParallel = 4)
            foreach ($item in @(Get-MwpWidgetDue -Widget $Widget -MaxParallel $MaxParallel)) {
                $null = Start-MwpWidgetRefresh -Widget $item -Registry $registry
            }
        }
        function Wait-TestTask {
            for ($i = 0; $i -lt 150 -and $registry.Count -gt 0; $i++) {
                $null = Update-MwpUiTask -Registry $registry
                if ($registry.Count -gt 0) {
                    Start-Sleep -Milliseconds 100
                }
            }
        }
    }

    AfterAll {
        Get-MwpModuleInstance | Close-MwpModuleInstance | Out-Null
        Remove-Item -Path Function:\Get-MwpTestWidgetData, Function:\ConvertTo-MwpTestWidgetView -ErrorAction SilentlyContinue
        Remove-Module -Name MWP.UI, MWP.Dashboard, MWP.Remote, MWP.Core -Force -ErrorAction SilentlyContinue
    }

    BeforeEach {
        $registry = New-Object -TypeName System.Collections.Generic.List[object]
    }

    AfterEach {
        Get-MwpModuleInstance | Close-MwpModuleInstance | Out-Null
    }

    Context 'izolacja widgetów (D-019, D-043)' {
        It 'każdy widget ma własną instancję modułu i własny kontekst, także dla tego samego komputera' {
            $first = Get-TestWidget -Id 'a'
            $second = Get-TestWidget -Id 'b'

            $first.Instance.Id | Should -Not -Be $second.Instance.Id
            $first.Instance.Context.Id | Should -Not -Be $second.Instance.Context.Id
            # D-054: tytuł z etykietą komputera (localhost — nazwa hosta, Format-MwpTargetLabel).
            $first.Instance.Name | Should -Be ('Widget: Widget testowy — {0}' -f $env:COMPUTERNAME)
            $first.Status | Should -Be 'Idle'
            $first.Pending | Should -BeTrue -Because 'pierwsze odświeżenie po utworzeniu'
            $first.Parameters['Tryb'] | Should -Be 'ok'
        }

        It 'awaria funkcji danych jednego widgetu nie zatrzymuje drugiego' {
            $broken = Get-TestWidget -Id 'zly' -Mode 'Throw'
            $working = Get-TestWidget -Id 'dobry' -Mode 'ok'

            Invoke-TestRefresh -Widget @($broken, $working)
            $broken.Status | Should -Be 'Error'
            $broken.Message | Should -Match 'awaria funkcji danych'
            $working.Status | Should -Be 'Loading'
            $working.Task.Quiet | Should -BeTrue -Because 'odświeżenie widgetu nie wstrzymuje zamknięcia okna i nie zajmuje paska stanu'
            $working.Task.Cancellable | Should -BeFalse
            (Update-MwpUiTask -Registry $registry).Running | Should -Be 0
            Wait-TestTask

            $working.Status | Should -Be 'Ready'
            $working.View.Sections[0].Items[0].Value | Should -Be 'dane:ok'
            $working.LastRefresh | Should -Not -BeNullOrEmpty
            $working.NextRefresh | Should -BeGreaterThan (Get-Date).AddSeconds(50)
            $broken.Task | Should -BeNullOrEmpty
            $broken.NextRefresh | Should -BeGreaterThan (Get-Date) -Because 'widget z błędem próbuje ponownie dopiero w swoim terminie'
        }

        It 'utrata połączenia z jednym komputerem nie zatrzymuje widgetu innego komputera' {
            $remote = Get-TestWidget -Id 'zdalny' -Mode 'Lost' -ComputerName $remoteName
            $localWidget = Get-TestWidget -Id 'lokalny'

            Invoke-TestRefresh -Widget @($remote, $localWidget)
            Wait-TestTask

            $remote.Instance.Context.Mode | Should -Be 'Remote'
            $remote.Status | Should -Be 'ConnectionLost'
            $remote.Message | Should -Match 'nie odpowiada'
            $localWidget.Status | Should -Be 'Ready'
            $rows = @(Get-MwpWidgetRow -Widget @($remote, $localWidget))
            $rows[0].State.Label | Should -Be 'Utrata połączenia'
            $rows[0].ConnectVisibility | Should -Be 'Visible'
            $rows[0].Footer | Should -Match 'ostatnia próba'
            $rows[1].ConnectVisibility | Should -Be 'Collapsed'
            $remote.Message = 'x' * 500
            (Get-MwpWidgetRow -Widget @($remote)).Message.Length | Should -Be 298
            (Get-MwpWidgetRow -Widget @($remote)).MessageFull.Length | Should -Be 500
        }

        It 'usunięcie widgetu anuluje jego zadanie i zamyka jego instancję; pozostałe działają' {
            $slow = Get-TestWidget -Id 'wolny' -Mode 'Slow'
            $other = Get-TestWidget -Id 'inny'
            $instanceId = $slow.Instance.Id
            Invoke-TestRefresh -Widget @($slow, $other)
            $operation = $slow.Task.Operation

            Remove-MwpWidgetRuntime -Widget $slow -Confirm:$false
            Wait-TestTask

            $slow.Removed | Should -BeTrue
            $slow.Instance | Should -BeNullOrEmpty
            Get-MwpModuleInstance -Id $instanceId | Should -BeNullOrEmpty
            $operation.Status | Should -Be 'Cancelled'
            $slow.View | Should -BeNullOrEmpty -Because 'wynik anulowanego zadania jest pomijany'
            $other.Status | Should -Be 'Ready'
            $registry.Count | Should -Be 0
            @(Get-MwpWidgetRow -Widget @($slow, $other)).Count | Should -Be 1
        }

        It 'widget komputera spoza rejestru ma stan błędu bez wyjątku i nie jest odświeżany' {
            $unknown = Get-TestWidget -Id 'nieznany' -ComputerName $unknownName
            $working = Get-TestWidget -Id 'dobry'

            $unknown.Status | Should -Be 'Error'
            $unknown.Instance | Should -BeNullOrEmpty
            $unknown.Message | Should -Match 'PC-NIEZNANY'
            @(Get-MwpWidgetDue -Widget @($unknown, $working)) | ForEach-Object { $_.Id } | Should -Be @('dobry')
        }

        It 'komputer zdalny bez poświadczeń: stan NeedsCredential bez uruchamiania operacji i bez okna' {
            $widget = Get-TestWidget -Id 'haslo' -ComputerName $passwordName

            $started = Start-MwpWidgetRefresh -Widget $widget -Registry $registry

            $started | Should -BeFalse
            $widget.Status | Should -Be 'NeedsCredential'
            $registry.Count | Should -Be 0
            @(Get-MwpWidgetDue -Widget @($widget)).Count | Should -Be 0 -Because 'odświeżanie automatyczne nie pyta o poświadczenia'
            (Get-MwpWidgetRow -Widget @($widget)).ConnectVisibility | Should -Be 'Visible'
        }
    }

    Context 'stany widgetu' {
        It 'brak danych z funkcji widoku daje NoData, a błąd widoku — Error z zachowaniem poprzedniego widoku' {
            $empty = Get-TestWidget -Id 'pusty' -Mode 'pusty'
            $bad = Get-TestWidget -Id 'zly' -Mode 'zly-widok'
            $bad.View = [pscustomobject]@{ Summary = 'poprzedni'; Sections = @(); Warnings = @() }

            Invoke-TestRefresh -Widget @($empty, $bad)
            Wait-TestTask

            $empty.Status | Should -Be 'NoData'
            $bad.Status | Should -Be 'Error'
            $bad.Message | Should -Match 'błąd widoku'
            $bad.View.Summary | Should -Be 'poprzedni'
        }

        It 'mapowanie wyniku operacji na stan widgetu' {
            $ok = New-MwpResult -Success $true -Data @('x')
            (Get-MwpWidgetStatus -Result $ok).Status | Should -Be 'Ready'
            (Get-MwpWidgetStatus -Result (New-MwpResult -Success $true -Data @())).Status | Should -Be 'NoData'
            (Get-MwpWidgetStatus -Result (New-MwpResult -Success $true -Data @(''))).Status | Should -Be 'NoData'
            foreach ($kind in 'Network', 'Timeout', 'ConnectionLost') {
                (Get-MwpWidgetStatus -Result (New-MwpResult -Success $false -Data @{ ErrorKind = $kind })).Status | Should -Be 'ConnectionLost'
            }
            foreach ($kind in 'Unauthorized', 'CredentialRequired') {
                (Get-MwpWidgetStatus -Result (New-MwpResult -Success $false -Data @{ ErrorKind = $kind })).Status | Should -Be 'NeedsCredential'
            }
            (Get-MwpWidgetStatus -Result (New-MwpResult -Success $false -Message 'zły blok')).Status | Should -Be 'Error'
            (Get-MwpWidgetStatus -Result $null -TaskStatus 'Failed' -TaskError 'awaria').Message | Should -Be 'awaria'
            (Get-MwpWidgetStatus -Result $ok -TaskStatus 'Cancelled').Status | Should -Be 'Cancelled'
        }

        It 'etykiety stanów: ładowanie, błąd, brak danych, utrata połączenia, wymaga poświadczeń' {
            (Get-MwpWidgetStateInfo -Status 'Loading').Label | Should -Be 'Ładowanie…'
            (Get-MwpWidgetStateInfo -Status 'Error').Tone | Should -Be 'Danger'
            (Get-MwpWidgetStateInfo -Status 'NoData').Label | Should -Be 'Brak danych'
            (Get-MwpWidgetStateInfo -Status 'ConnectionLost').Label | Should -Be 'Utrata połączenia'
            (Get-MwpWidgetStateInfo -Status 'NeedsCredential').Tone | Should -Be 'Warning'
            (Get-MwpWidgetStateInfo -Status 'Ready').Tone | Should -Be 'Success'
        }
    }

    Context 'harmonogram odświeżania' {
        BeforeAll {
            function Get-FakeWidget {
                param([string] $Id, [bool] $Pending = $false, [int] $Refresh = 60, [datetime] $Next = [datetime]::MinValue, [bool] $Running = $false, [string] $Status = 'Ready')
                @{
                    Id = $Id; Pending = $Pending; Removed = $false; Instance = [pscustomobject]@{ Id = $Id }; Task = $(if ($Running) { 'zadanie' } else { $null })
                    Status = $Status; NextRefresh = $Next; Config = @{ refreshSeconds = $Refresh }
                }
            }
        }

        It 'limit równoczesnych odświeżeń uwzględnia trwające; najpierw ręczne, potem najstarszy termin' {
            $now = Get-Date
            $widgets = @(
                Get-FakeWidget -Id 'trwa' -Running $true
                Get-FakeWidget -Id 'stary' -Next $now.AddMinutes(-10)
                Get-FakeWidget -Id 'reczny' -Pending $true -Next $now.AddMinutes(5)
                Get-FakeWidget -Id 'nowszy' -Next $now.AddMinutes(-1)
                Get-FakeWidget -Id 'przyszly' -Next $now.AddMinutes(1)
            )

            @(Get-MwpWidgetDue -Widget $widgets -MaxParallel 3 -Now $now | ForEach-Object { $_.Id }) | Should -Be @('reczny', 'stary')
            @(Get-MwpWidgetDue -Widget $widgets -MaxParallel 1 -Now $now).Count | Should -Be 0
        }

        It 'działa na prawdziwych widgetach (tabele z instancją i definicją) w kolejności terminów' {
            $now = Get-Date
            $first = Get-TestWidget -Id 'pierwszy'
            $second = Get-TestWidget -Id 'drugi'
            $first.Pending = $false
            $first.NextRefresh = $now.AddMinutes(-1)
            $second.Pending = $false
            $second.NextRefresh = $now.AddMinutes(-5)

            @(Get-MwpWidgetDue -Widget @($first, $second) -Now $now | ForEach-Object { $_.Id }) | Should -Be @('drugi', 'pierwszy')
        }

        It 'bez odświeżania automatycznego i przy częstotliwości 0 odświeża tylko ręcznie' {
            $now = Get-Date
            $widgets = @(
                Get-FakeWidget -Id 'auto' -Next $now.AddMinutes(-1)
                Get-FakeWidget -Id 'reczny-tryb' -Refresh 0 -Next $now.AddMinutes(-1)
                Get-FakeWidget -Id 'klik' -Pending $true -Refresh 0
            )

            @(Get-MwpWidgetDue -Widget $widgets -AutoRefresh $false -Now $now | ForEach-Object { $_.Id }) | Should -Be @('klik')
            @(Get-MwpWidgetDue -Widget $widgets -AutoRefresh $true -Now $now | ForEach-Object { $_.Id }) | Should -Be @('klik', 'auto')
        }
    }

    Context 'wiersze kafelków' {
        It 'rozmiar, przesuwanie, eksport i komunikat ładowania' {
            $first = Get-TestWidget -Id 'a'
            $second = Get-TestWidget -Id 'b' -Refresh 0
            $second.Config['size'] = 'Wide'
            $second.Config['title'] = 'Mój widget'
            $second.Data = @('dane')
            $second.LastRefresh = Get-Date -Hour 12 -Minute 30 -Second 15

            $rows = @(Get-MwpWidgetRow -Widget @($first, $second))

            $rows[0].Width | Should -Be 420
            $rows[0].Width | Should -BeOfType [double]
            $rows[1].Width | Should -Be 864
            $rows[0].CanMoveLeft | Should -BeFalse
            $rows[0].CanMoveRight | Should -BeTrue
            $rows[1].CanMoveRight | Should -BeFalse
            $rows[0].ExportEnabled | Should -BeFalse
            $rows[1].ExportEnabled | Should -BeTrue
            $rows[0].Message | Should -Be 'Wczytywanie danych…'
            $rows[1].Title | Should -Be 'Mój widget'
            $rows[1].Subtitle | Should -Be 'localhost · Widget testowy · odświeżanie ręczne'
            $rows[1].Footer | Should -Be 'Odświeżono 12:30:15'
        }
    }

    Context 'zapis i odtworzenie konfiguracji (test architektoniczny 10)' {
        It 'okno odtwarza Dashboard z zapisu (bez widgetu odinstalowanego modułu), a zegar odświeża widgety z limitem' {
            $saved = @(
                [ordered]@{ id = 'sys-1'; moduleId = 'Dashboard'; widgetId = 'SystemInfo'; computerName = 'localhost'; refreshSeconds = 60; size = 'Wide'; parameters = @{ Sections = @('Memory') } }
                [ordered]@{ id = 'po-odinstalowaniu'; moduleId = 'Przyklad'; widgetId = 'Stan'; computerName = 'localhost'; refreshSeconds = 60; size = 'Normal' }
                [ordered]@{ id = 'sys-2'; moduleId = 'Dashboard'; widgetId = 'SystemInfo'; computerName = 'localhost'; refreshSeconds = 0; size = 'Normal'; parameters = @{ Sections = @('Cpu') } }
                [ordered]@{ id = 'sys-3'; moduleId = 'Dashboard'; widgetId = 'SystemInfo'; computerName = 'localhost'; refreshSeconds = 0; size = 'Normal'; parameters = @{ Sections = @('System') } }
            )
            (Set-MwpDashboardConfiguration -Widget $saved -Confirm:$false).Success | Should -BeTrue
            $tasks = New-Object -TypeName System.Collections.Generic.List[object]

            $state = InModuleScope MWP.UI -Parameters @{ Tasks = $tasks } {
                param($Tasks)
                $script:MwpUi = @{ Definitions = @(); Tasks = $Tasks; CurrentKey = 'dashboard'; Views = @{}; Dashboard = $null }
                Initialize-MwpUiDashboard
                $script:MwpUi.Dashboard.MaxParallel = 2
                Invoke-MwpUiDashboardTick
                $script:MwpUi.Dashboard
            }

            @($state.Widgets.ToArray() | ForEach-Object { $_.Id }) | Should -Be @('sys-1', 'sys-2', 'sys-3')
            $state.Banner | Should -Match 'Przyklad'
            @((Get-MwpDashboardConfiguration).Widgets | ForEach-Object { $_.id }) | Should -Not -Contain 'po-odinstalowaniu'
            @($state.Widgets.ToArray() | Where-Object { $_.Status -eq 'Loading' }).Count | Should -Be 2 -Because 'limit równoczesnych odświeżeń'
            for ($i = 0; $i -lt 300 -and @($state.Widgets.ToArray() | Where-Object { $_.Status -ne 'Ready' }).Count -gt 0; $i++) {
                $null = Update-MwpUiTask -Registry $tasks
                InModuleScope MWP.UI { Invoke-MwpUiDashboardTick }
                Start-Sleep -Milliseconds 100
            }
            @($state.Widgets.ToArray() | ForEach-Object { $_.Status }) | Should -Be @('Ready', 'Ready', 'Ready')
            $state.Widgets[0].View.Sections[0].Title | Should -Be 'Pamięć RAM'
            InModuleScope MWP.UI {
                foreach ($widget in $script:MwpUi.Dashboard.Widgets.ToArray()) {
                    Remove-MwpWidgetRuntime -Widget $widget -Confirm:$false
                }
                $script:MwpUi = $null
            }
        }

        It 'konfiguracja widgetów z okna zapisuje się i odtwarza w tej samej kolejności, z nowymi instancjami' {
            $widgets = @((Get-TestWidget -Id 'drugi' -Refresh 300), (Get-TestWidget -Id 'pierwszy' -Mode 'inny'))
            $entries = @(ConvertTo-MwpWidgetConfiguration -Widget $widgets)
            (Set-MwpDashboardConfiguration -Widget $entries -Confirm:$false).Success | Should -BeTrue
            $oldInstances = @($widgets | ForEach-Object { $_.Instance.Id })
            foreach ($widget in $widgets) {
                Remove-MwpWidgetRuntime -Widget $widget -Confirm:$false
            }

            $restored = @(foreach ($entry in @((Get-MwpDashboardConfiguration).Widgets)) {
                    New-MwpWidgetRuntime -Configuration $entry -Definition $definition
                })

            @($restored | ForEach-Object { $_.Id }) | Should -Be @('drugi', 'pierwszy')
            $restored[0].Config['refreshSeconds'] | Should -Be 300
            $restored[1].Parameters['Tryb'] | Should -Be 'inny'
            $oldInstances | Should -Not -Contain $restored[0].Instance.Id
            Invoke-TestRefresh -Widget $restored
            Wait-TestTask
            $restored[1].View.Sections[0].Items[0].Value | Should -Be 'dane:inny'
        }
    }
}
