#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
    Testy logiki prezentacji MWP.UI (src\UI\Functions): motyw, nawigacja, stan połączenia, tryby
    prezentacji, zadania w tle (pula runspace'ów, postęp, anulowanie, wynik w wątku wywołującym),
    panel logu, podgląd zmian i wiersze widoku „Moduły". Bez okien WPF (te sprawdza Xaml.Tests.ps1
    i ręczna weryfikacja na Windows 11). Dane i ustawienia na TestDrive.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Zmienne z bloków BeforeDiscovery/BeforeAll są używane w blokach It (zakresy Pestera).')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '',
    Justification = 'Bloki zadań w tle muszą przyjmować tabelę Progress jako pierwszy parametr, także gdy jej nie używają.')]
param()

Describe 'MWP.UI — logika prezentacji' {
    BeforeAll {
        $root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        Import-Module -Name (Join-Path -Path $root -ChildPath 'src\Modules\MWP.Core\MWP.Core.psd1') -Force
        Import-Module -Name (Join-Path -Path $root -ChildPath 'src\Modules\MWP.Remote\MWP.Remote.psd1') -Force
        # D-052: testy nie dotykają prawdziwego Menedżera poświadczeń; pamięć poświadczeń jest wspólna dla procesu.
        Mock -ModuleName MWP.Remote Invoke-MwpCredentialApi { throw 'Testy nie mogą używać prawdziwego Menedżera poświadczeń Windows.' }
        Clear-MwpTargetCredentialCache
        Import-Module -Name (Join-Path -Path $root -ChildPath 'src\UI\MWP.UI.psm1') -Force
        Mock -ModuleName MWP.Core Get-MwpDataPath {
            $path = Join-Path -Path $TestDrive -ChildPath $Kind
            if (Get-Variable -Name Detailed -ValueOnly -ErrorAction SilentlyContinue) { [pscustomobject]@{ Path = $path; Root = $TestDrive; Configured = ''; IsFallback = $false; Warning = $null } } else { $path }
        }
        $configDirectory = Join-Path -Path $TestDrive -ChildPath 'config'
        $null = New-Item -ItemType Directory -Path $configDirectory -Force
        Copy-Item -LiteralPath (Join-Path -Path $root -ChildPath 'config\settings.example.json') -Destination (Join-Path -Path $configDirectory -ChildPath 'settings.example.json')
        Mock -ModuleName MWP.Core Get-MwpConfigPath {
            [pscustomobject]@{
                Example    = Join-Path -Path $TestDrive -ChildPath 'config\settings.example.json'
                Local      = Join-Path -Path $TestDrive -ChildPath 'config\settings.local.json'
                IsFallback = $false
            }
        }

        function Get-TestDefinition {
            param([string] $Id, [string[]] $Capabilities = @(), [string[]] $Modes = @(), [bool] $IsValid = $true, [bool] $IsBase = $false, [string] $Source = 'BuiltIn')
            [pscustomobject]@{
                Id = $Id; Name = "Moduł $Id"; ModuleName = "MWP.$Id"; Version = [version]'1.0.0'; Description = "Opis $Id"
                Capabilities = $Capabilities; SupportedPresentationModes = $Modes; RequiredPermissions = @('User')
                IsValid = $IsValid; IsBase = $IsBase; Source = $Source; Errors = @(); ModuleBase = "C:\Moduly\MWP.$Id"
            }
        }
        function Get-TestContext {
            param([string] $Mode = 'Remote', [string] $State = 'Disconnected', [string] $ErrorKind, [System.Management.Automation.PSCredential] $Credential, [string] $Authentication = 'Credential')
            [pscustomobject]@{
                PSTypeName   = 'MWP.ExecutionContext'
                ComputerName = 'PC-TEST1'
                Mode         = $Mode
                Identity     = [pscustomobject]@{ Authentication = $Authentication; UserName = 'PC-TEST1\admin' }
                Connection   = [pscustomobject]@{ State = $State; ErrorKind = $ErrorKind; LastError = 'opis błędu'; StateChangedAt = Get-Date; Credential = $Credential }
            }
        }
    }

    AfterAll {
        Remove-Module -Name MWP.UI, MWP.Remote, MWP.Core -Force -ErrorAction SilentlyContinue
    }

    Context 'motyw (D-004)' {
        It 'AppsUseLightTheme = 0 oznacza motyw ciemny, 1 — jasny, brak wartości — jasny' {
            $key = 'TestRegistry:\Personalize'
            $null = New-Item -Path $key -Force
            $null = New-ItemProperty -Path $key -Name 'AppsUseLightTheme' -Value 0 -PropertyType DWord -Force
            Get-MwpSystemTheme -RegistryPath $key | Should -Be 'Dark'
            $null = Set-ItemProperty -Path $key -Name 'AppsUseLightTheme' -Value 1
            Get-MwpSystemTheme -RegistryPath $key | Should -Be 'Light'
            Get-MwpSystemTheme -RegistryPath 'TestRegistry:\Brak' | Should -Be 'Light'
        }

        It 'ustawienie theme: System zależy od motywu systemu, Light i Dark — nie' {
            Resolve-MwpThemeName -Setting 'System' -SystemTheme Dark | Should -Be 'Dark'
            Resolve-MwpThemeName -Setting 'Light' -SystemTheme Dark | Should -Be 'Light'
            Resolve-MwpThemeName -Setting 'Dark' -SystemTheme Light | Should -Be 'Dark'
            Resolve-MwpThemeName -Setting 'cokolwiek' -SystemTheme Light | Should -Be 'Light'
        }
    }

    Context 'nawigacja hosta' {
        It 'katalog obszarów ma unikalne Id, numer fazy i znak ikony' {
            $areas = @(Get-MwpAreaCatalog)
            $areas.Count | Should -BeGreaterOrEqual 14
            @($areas.Id | Sort-Object -Unique).Count | Should -Be $areas.Count
            foreach ($area in $areas) {
                $area.Phase | Should -BeGreaterThan 4
                $area.Glyph.Length | Should -Be 1
            }
        }

        It 'Pulpit jest pierwszy, pozycje dolne to Moduły, Dziennik, Ustawienia, O programie; moduły bazowe pominięte' {
            $definitions = @(
                Get-TestDefinition -Id 'Core' -IsBase $true
                Get-TestDefinition -Id 'Remote' -IsBase $true
                Get-TestDefinition -Id 'Services'
                Get-TestDefinition -Id 'Dashboard'
            )
            $items = @(Get-MwpNavigationItem -Definition $definitions)

            $items[0].Key | Should -Be 'dashboard'
            $items[0].IsAvailable | Should -BeTrue
            @($items | Where-Object { $_.Section -eq 'Bottom' }).Key | Should -Be @('modules', 'log', 'settings', 'about')
            @($items | Where-Object { $_.ModuleId -in @('Core', 'Remote') }).Count | Should -Be 0
        }

        It 'obszar z modułem jest dostępny, obszar bez modułu ma numer fazy (zaślepka)' {
            $items = @(Get-MwpNavigationItem -Definition @(Get-TestDefinition -Id 'Services'))

            ($items | Where-Object { $_.Key -eq 'area:Services' }).IsAvailable | Should -BeTrue
            $disks = $items | Where-Object { $_.Key -eq 'area:Disks' }
            $disks.IsAvailable | Should -BeFalse
            $disks.Phase | Should -Be 15
        }

        It 'moduł z paczki spoza katalogu trafia do grupy „Moduły z paczek"; niepoprawny jest pomijany' {
            $definitions = @(
                Get-TestDefinition -Id 'Przyklad' -Source 'Installed'
                Get-TestDefinition -Id 'Zepsuty' -Source 'Installed' -IsValid $false
            )
            $items = @(Get-MwpNavigationItem -Definition $definitions)

            ($items | Where-Object { $_.Kind -eq 'Header' -and $_.Title -eq 'Moduły z paczek' }) | Should -Not -BeNullOrEmpty
            ($items | Where-Object { $_.Key -eq 'area:Przyklad' }).Group | Should -Be 'Moduły z paczek'
            ($items | Where-Object { $_.Key -eq 'area:Zepsuty' }) | Should -BeNullOrEmpty
        }
    }

    Context 'instancje: komputer docelowy i tryby prezentacji' {
        It 'komputer zdalny wymaga RemoteTarget; lokalny nie' {
            $local = [pscustomobject]@{ Name = 'localhost'; IsLocal = $true }
            $remote = [pscustomobject]@{ Name = 'PC-TEST1'; IsLocal = $false }

            (Test-MwpInstanceTarget -Definition (Get-TestDefinition -Id 'Services') -Target $local).Allowed | Should -BeTrue
            $denied = Test-MwpInstanceTarget -Definition (Get-TestDefinition -Id 'Services') -Target $remote
            $denied.Allowed | Should -BeFalse
            $denied.Reason | Should -Match 'RemoteTarget'
            (Test-MwpInstanceTarget -Definition (Get-TestDefinition -Id 'Przyklad' -Capabilities @('RemoteTarget')) -Target $remote).Allowed | Should -BeTrue
            (Test-MwpInstanceTarget -Definition (Get-TestDefinition -Id 'Core' -IsBase $true) -Target $local).Allowed | Should -BeFalse
        }

        It 'pusta lista trybów pozwala na zaślepkę w oknie głównym i osobnym; zadeklarowane tryby są przestrzegane' {
            Test-MwpPresentationMode -Definition (Get-TestDefinition -Id 'A') -Mode Embedded | Should -BeTrue
            Test-MwpPresentationMode -Definition (Get-TestDefinition -Id 'A') -Mode SeparateWindow | Should -BeTrue
            $cliOnly = Get-TestDefinition -Id 'B' -Modes @('CLI')
            Test-MwpPresentationMode -Definition $cliOnly -Mode Embedded | Should -BeFalse
            Test-MwpPresentationMode -Definition (Get-TestDefinition -Id 'C' -Modes @('Embedded')) -Mode SeparateWindow | Should -BeFalse
        }
    }

    Context 'stan połączenia w widoku instancji' {
        It 'komputer lokalny: „Lokalnie", bez poświadczeń' {
            $info = Get-MwpConnectionStateInfo -Context (Get-TestContext -Mode Local -State Connected)
            $info.Label | Should -Be 'Lokalnie'
            $info.Tone | Should -Be 'Success'
            $info.NeedsCredential | Should -BeFalse
        }

        It 'komputer zdalny bez hasła w pamięci wymaga poświadczeń; CurrentUser — nie' {
            (Get-MwpConnectionStateInfo -Context (Get-TestContext)).NeedsCredential | Should -BeTrue
            (Get-MwpConnectionStateInfo -Context (Get-TestContext -Authentication CurrentUser)).NeedsCredential | Should -BeFalse
        }

        It 'błędy połączenia mają ton ostrzeżenia lub błędu i szczegóły z kontekstu tej instancji' {
            $credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'u', (New-Object -TypeName System.Security.SecureString)
            $error1 = Get-MwpConnectionStateInfo -Context (Get-TestContext -State Error -ErrorKind Network -Credential $credential)
            $error1.Tone | Should -Be 'Danger'
            $error1.Detail | Should -Be 'opis błędu'
            $error1.NeedsCredential | Should -BeFalse
            $unauthorized = Get-MwpConnectionStateInfo -Context (Get-TestContext -State Unauthorized -ErrorKind CredentialRequired -Credential $credential)
            $unauthorized.Label | Should -Be 'Wymaga poświadczeń'
            $unauthorized.Tone | Should -Be 'Warning'
            $unauthorized.NeedsCredential | Should -BeTrue
            (Get-MwpConnectionStateInfo -Context (Get-TestContext -State Connected -Credential $credential)).Label | Should -Be 'Połączono'
        }
    }

    Context 'zadania w tle (pula runspace''ów, postęp, anulowanie)' {
        BeforeAll {
            $pool = New-MwpUiTaskPool -ModulePath @((Join-Path -Path $root -ChildPath 'src\Modules\MWP.Core\MWP.Core.psd1'))

            function Wait-TestTask {
                param($Registry, [int] $Seconds = 30)
                $completed = @()
                $deadline = (Get-Date).AddSeconds($Seconds)
                while ($Registry.Count -gt 0 -and (Get-Date) -lt $deadline) {
                    $completed += @((Update-MwpUiTask -Registry $Registry).Completed)
                    Start-Sleep -Milliseconds 50
                }
                $completed
            }
        }

        AfterAll {
            Close-MwpUiTaskPool -Pool $pool
        }

        It 'zadanie wraca od razu, wynik i OnCompleted przychodzą w wątku wywołującego, z danymi State' {
            $registry = New-Object -TypeName System.Collections.Generic.List[object]
            $capture = @{ Thread = $null; State = $null }
            $started = Get-Date
            $task = Start-MwpUiTask -Registry $registry -Pool $pool -Name 'Test' -ArgumentList 2, 3 -State 'stan' -ScriptBlock {
                param($Progress, $A, $B)
                $Progress.Percent = 50
                Start-Sleep -Milliseconds 300
                [Threading.Thread]::CurrentThread.ManagedThreadId
                $A + $B
            } -OnCompleted {
                param($Task)
                $capture.Thread = [Threading.Thread]::CurrentThread.ManagedThreadId
                $capture.State = $Task.State
            }
            ((Get-Date) - $started).TotalMilliseconds | Should -BeLessThan 2000
            $task.Status | Should -Be 'Running'

            $done = @(Wait-TestTask -Registry $registry)

            $done.Count | Should -Be 1
            $task.Status | Should -Be 'Completed'
            $task.Output[1] | Should -Be 5
            $task.Output[0] | Should -Not -Be ([Threading.Thread]::CurrentThread.ManagedThreadId)
            $capture.Thread | Should -Be ([Threading.Thread]::CurrentThread.ManagedThreadId)
            $capture.State | Should -Be 'stan'
            $registry.Count | Should -Be 0
        }

        It 'raportuje postęp do podsumowania paska stanu' {
            $registry = New-Object -TypeName System.Collections.Generic.List[object]
            $null = Start-MwpUiTask -Registry $registry -Pool $pool -Name 'Postęp' -Cancellable -ScriptBlock {
                param($Progress)
                $Progress.Percent = 42
                $Progress.Message = 'krok'
                while (-not $Progress.CancelRequested) { Start-Sleep -Milliseconds 20 }
            }
            Start-Sleep -Milliseconds 400

            $summary = Update-MwpUiTask -Registry $registry

            $summary.Running | Should -Be 1
            $summary.Percent | Should -Be 42
            $summary.Message | Should -Be 'Postęp: krok'
            $summary.CanCancel | Should -BeTrue
            Stop-MwpUiTask -Registry $registry -Confirm:$false
            $null = Wait-TestTask -Registry $registry
        }

        It 'anulowanie zatrzymuje długie zadanie (status Cancelled) bez czekania na jego koniec' {
            $registry = New-Object -TypeName System.Collections.Generic.List[object]
            $task = Start-MwpUiTask -Registry $registry -Pool $pool -Name 'Długie' -Cancellable -ScriptBlock {
                param($Progress)
                Start-Sleep -Seconds 60
            }
            Start-Sleep -Milliseconds 300
            $stopped = Get-Date

            Stop-MwpUiTask -Task $task -Confirm:$false
            $null = Wait-TestTask -Registry $registry -Seconds 20

            ((Get-Date) - $stopped).TotalSeconds | Should -BeLessThan 15
            $task.Status | Should -Be 'Cancelled'
        }

        It 'błąd przerywający daje status Failed z komunikatem; błąd w OnCompleted nie przerywa obsługi' {
            $WarningPreference = 'SilentlyContinue'
            $registry = New-Object -TypeName System.Collections.Generic.List[object]
            $failing = Start-MwpUiTask -Registry $registry -Pool $pool -Name 'Błąd' -ScriptBlock {
                param($Progress)
                throw 'błąd zadania'
            }
            $badCallback = Start-MwpUiTask -Registry $registry -Pool $pool -Name 'Callback' -ScriptBlock { param($Progress) 1 } -OnCompleted { throw 'błąd obsługi' }

            $null = Wait-TestTask -Registry $registry

            $failing.Status | Should -Be 'Failed'
            $failing.Error | Should -Match 'błąd zadania'
            $badCallback.Status | Should -Be 'Completed'
            $badCallback.Error | Should -Match 'błąd obsługi'
        }

        It 'zadanie w puli ma dostęp do funkcji MWP.Core' {
            $registry = New-Object -TypeName System.Collections.Generic.List[object]
            $task = Start-MwpUiTask -Registry $registry -Pool $pool -Name 'Core' -ScriptBlock {
                param($Progress)
                (New-MwpResult -Success $true -Message 'z puli').Message
            }

            $null = Wait-TestTask -Registry $registry

            $task.Output | Should -Be 'z puli'
        }

        It 'operacja MWP.Remote zarejestrowana w oknie oddaje wynik przez Update-MwpUiTask' {
            $registry = New-Object -TypeName System.Collections.Generic.List[object]
            $operation = Start-MwpOperation -Context (New-MwpExecutionContext) -ScriptBlock { 40 + 2 } -Operation 'Test.UiOperation'
            $task = Register-MwpUiOperation -Registry $registry -Operation $operation -State 'op'

            $null = Wait-TestTask -Registry $registry

            $task.Status | Should -Be 'Completed'
            $task.Output[0].Success | Should -BeTrue
            $task.Output[0].Data | Should -Be 42
        }
    }

    Context 'panel logu i podgląd zmian' {
        It 'czyta ostatnie wpisy JSON Lines jako UTF-8, pomija uszkodzone linie i filtruje poziom' {
            $log = Join-Path -Path $TestDrive -ChildPath 'test.log'
            $lines = @(
                '{"timestamp":"2026-10-26T10:00:00.0000000+01:00","level":"Info","computer":"localhost","source":"MWP.Core","operation":"A","message":"zażółć gęślą"}'
                'to nie jest JSON'
                '{"timestamp":"2026-10-26T10:01:00.0000000+01:00","level":"Debug","computer":"localhost","source":"MWP.Core","operation":"B","message":"debug"}'
                '{"timestamp":"2026-10-26T10:02:00.0000000+01:00","level":"Warning","computer":"PC-TEST1","source":"MWP.Remote","operation":"C","message":"ostrzeżenie"}'
            )
            [IO.File]::WriteAllText($log, ($lines -join "`n"), (New-Object -TypeName System.Text.UTF8Encoding -ArgumentList $false))

            $all = @(Read-MwpLogEntry -Path $log)
            $all.Count | Should -Be 3
            $all[0].Operation | Should -Be 'C'
            $all[2].Message | Should -Be 'zażółć gęślą'
            @(Read-MwpLogEntry -Path $log -MinimumLevel Info).Count | Should -Be 2
            @(Read-MwpLogEntry -Path $log -MinimumLevel Warning).Computer | Should -Be 'PC-TEST1'
            @(Read-MwpLogEntry -Path $log -Last 1).Count | Should -Be 1
            @(Read-MwpLogEntry -Path (Join-Path -Path $TestDrive -ChildPath 'brak.log')).Count | Should -Be 0
        }

        It 'podgląd zmian zawiera komunikat, komputer i stan przed i po' {
            $computer = 'PC-TEST1'
            $preview = New-MwpResult -Success $true -IsPreview -Operation 'X' -ComputerName $computer -Message 'Podgląd: zmiana.' -Before 'a' -After ([ordered]@{ Klucz = 'b' })

            $lines = @(ConvertTo-MwpPreviewLine -Result $preview)

            $lines | Should -Contain 'Podgląd: zmiana.'
            $lines | Should -Contain 'Komputer: PC-TEST1'
            $lines | Should -Contain 'Przed: a'
            $lines | Should -Contain 'Po: Klucz: b'
            @(ConvertTo-MwpPreviewLine -Result (New-MwpResult -Success $false -Message 'odmowa'))[0] | Should -Match 'Nie można wykonać: odmowa'
        }
    }

    Context 'widok „Moduły"' {
        It 'odinstalować można tylko moduł z paczki; bazowe są pierwsze; liczba instancji per moduł' {
            $definitions = @(
                Get-TestDefinition -Id 'Przyklad' -Source 'Installed' -Modes @('Embedded')
                Get-TestDefinition -Id 'Services'
                Get-TestDefinition -Id 'Core' -IsBase $true
            )
            $installed = @([pscustomobject]@{ Id = 'Przyklad'; InstalledAt = [datetime]'2026-10-26T10:00:00'; Sha256 = 'ABC' })
            $instances = @([pscustomobject]@{ ModuleId = 'Przyklad' }, [pscustomobject]@{ ModuleId = 'Przyklad' })

            $rows = @(Get-MwpModuleRow -Definition $definitions -InstalledModule $installed -Instance $instances)

            $rows[0].Id | Should -Be 'Core'
            $rows[0].Source | Should -Be 'Bazowy'
            ($rows | Where-Object { $_.CanUninstall }).Id | Should -Be 'Przyklad'
            ($rows | Where-Object { $_.Id -eq 'Przyklad' }).Instances | Should -Be 2
            ($rows | Where-Object { $_.Id -eq 'Przyklad' }).Sha256 | Should -Be 'ABC'
            ($rows | Where-Object { $_.Id -eq 'Services' }).Modes | Should -Be '(zaślepka)'
        }
    }
}
