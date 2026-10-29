#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
    Testy modułu MWP.Update (FAZA 10, D-048) z symulatorem Windows Update Agent: mock New-Object -ComObject
    (Microsoft.Update.Session z wyszukiwaniem, historią, pobieraniem i instalacją, SystemInfo, AutoUpdate,
    UpdateColl) w zakresie MWP.Remote (tam Invoke-MwpOnTarget wykonuje bloki), w MWP.Update i w zakresie
    pliku; pozostałe wywołania New-Object przechodzą do oryginału. Usługi: mocki Get-CimInstance
    (Win32_Service) i Get-Service (kontroler z Stop/Start/WaitForStatus/Refresh). Klucze pauzy, zasad
    i restartu leżą w TestRegistry, a „katalog Windows” z SoftwareDistribution i catroot2 — w TestDrive
    (mock Get-MwpUpdateTargetConfig), więc testy nie dotykają prawdziwego rejestru, folderów ani usług.
    Sprawdzają: stan, wyszukiwanie, historię, pauzę z cofaniem, reset z podglądem kroków, wycofaniem
    i cofnięciem, instalację (pominięcia, postęp, anulowanie, restart, błędy), -WhatIf, log, uprawnienia
    administratora i komputer zdalny (mock transportu WinRM): odczyt i reset zdalnie, instalacja odrzucona,
    utrata połączenia.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Zmienne z bloków BeforeDiscovery/BeforeAll są używane w blokach It (zakresy Pestera).')]
param()

Describe 'MWP.Update — Windows Update' {
    BeforeAll {
        $root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
        foreach ($name in 'MWP.Core', 'MWP.Remote', 'MWP.Update') {
            Import-Module -Name (Join-Path -Path $root -ChildPath "src\Modules\$name\$name.psd1") -Force
        }
        $configDirectory = Join-Path -Path $TestDrive -ChildPath 'config'
        $null = New-Item -ItemType Directory -Path $configDirectory -Force
        Copy-Item -LiteralPath (Join-Path -Path $root -ChildPath 'config\settings.example.json') -Destination (Join-Path -Path $configDirectory -ChildPath 'settings.example.json')
        Mock -ModuleName MWP.Core Get-MwpDataPath {
            $name = Get-Variable -Name Kind -ValueOnly -ErrorAction SilentlyContinue
            $path = if ($name -and $name -ne 'Root') { Join-Path -Path $TestDrive -ChildPath $name } else { [string]$TestDrive }
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
        $local = [ordered]@{ schemaVersion = 2; targets = @(@{ name = $remoteName; authentication = 'CurrentUser' }) }
        ConvertTo-Json -InputObject $local -Depth 5 | Set-Content -LiteralPath (Join-Path -Path $configDirectory -ChildPath 'settings.local.json') -Encoding UTF8

        # Miejsca Windows Update w TestRegistry i TestDrive (zamiast HKLM i %SystemRoot%).
        $script:WindowsRoot = Join-Path -Path $TestDrive -ChildPath 'Windows'
        $script:PauseKey = 'TestRegistry:\WindowsUpdate\UX\Settings'
        $script:PolicyKey = 'TestRegistry:\Policies\WindowsUpdate'
        $script:RebootKey = 'TestRegistry:\Auto Update\RebootRequired'
        $script:PendingKey = 'TestRegistry:\Component Based Servicing\RebootPending'
        Mock -ModuleName MWP.Update Get-MwpUpdateTargetConfig {
            [pscustomobject]@{
                PauseKey         = $script:PauseKey
                PauseValues      = @('PauseUpdatesStartTime', 'PauseUpdatesExpiryTime', 'PauseFeatureUpdatesStartTime', 'PauseFeatureUpdatesEndTime', 'PauseQualityUpdatesStartTime', 'PauseQualityUpdatesEndTime')
                PolicyKey        = $script:PolicyKey
                PolicyValues     = @('SetDisablePauseUXAccess', 'PauseQualityUpdates', 'PauseQualityUpdatesStartTime', 'PauseFeatureUpdates', 'PauseFeatureUpdatesStartTime')
                RebootKeys       = @($script:RebootKey, $script:PendingKey)
                WindowsRoot      = $script:WindowsRoot
                Services         = @('wuauserv', 'bits', 'cryptsvc', 'usosvc')
                ResetServices    = @('usosvc', 'wuauserv', 'bits', 'cryptsvc')
                OptionalServices = @('usosvc')
                ResetFolders     = @(
                    [pscustomobject]@{ Name = 'SoftwareDistribution'; RelativePath = 'SoftwareDistribution' }
                    [pscustomobject]@{ Name = 'catroot2'; RelativePath = 'System32\catroot2' }
                )
            }
        }

        function Get-FakeUpdate {
            param([string] $Id, [string] $Title, [string] $Kb, [int] $Type = 1, [double] $Size = 10MB, [bool] $Downloaded = $false,
                [bool] $UserInput = $false, [bool] $Eula = $true, [int] $Reboot = 1)
            [pscustomobject]@{
                Title                    = $Title
                Description              = 'Opis ' + $Title
                Identity                 = [pscustomobject]@{ UpdateID = $Id; RevisionNumber = 200 }
                KBArticleIDs             = @($(if ($Kb) { $Kb }))
                Categories               = @([pscustomobject]@{ Name = $(if ($Type -eq 2) { 'Sterowniki' } else { 'Aktualizacje zabezpieczeń' }) })
                Type                     = $Type
                MsrcSeverity             = $(if ($Type -eq 1) { 'Important' } else { '' })
                MaxDownloadSize          = [decimal]$Size
                IsDownloaded             = $Downloaded
                IsMandatory              = $false
                EulaAccepted             = $Eula
                InstallationBehavior     = [pscustomobject]@{ RebootBehavior = $Reboot; CanRequestUserInput = $UserInput }
                LastDeploymentChangeTime = [datetime]'2026-10-14'
                SupportUrl               = 'https://support.microsoft.com/help/' + $Kb
            }
        }

        $script:IdA = '11111111-1111-1111-1111-111111111111'
        $script:IdB = '22222222-2222-2222-2222-222222222222'
        $script:IdC = '33333333-3333-3333-3333-333333333333'
        $script:IdD = '44444444-4444-4444-4444-444444444444'
        function Initialize-FakeUpdate {
            $script:Fake = @{
                Updates       = @(
                    (Get-FakeUpdate -Id $script:IdA -Title '2026-10 Aktualizacja zbiorcza (KB5000001)' -Kb '5000001' -Size 500MB)
                    (Get-FakeUpdate -Id $script:IdB -Title 'Aktualizacja analizy zabezpieczeń (KB2267602)' -Kb '2267602' -Size 30MB -Downloaded $true -Reboot 0)
                    (Get-FakeUpdate -Id $script:IdC -Title 'Sterownik testowy 1.2.3' -Kb '' -Type 2 -Size 2MB -UserInput $true)
                    (Get-FakeUpdate -Id $script:IdD -Title 'Narzędzie z licencją' -Kb '5000004' -Eula $false)
                )
                History       = @(
                    [pscustomobject]@{ Date = [datetime]'2026-10-20T08:00:00'; Operation = 1; ResultCode = 2; HResult = 0; Title = 'Aktualizacja (KB5000010)'; Description = 'Opis'; ClientApplicationID = 'UpdateOrchestrator'; SupportUrl = ''; UpdateIdentity = [pscustomobject]@{ UpdateID = 'aaaa' } }
                    [pscustomobject]@{ Date = [datetime]'2026-10-22T09:30:00'; Operation = 1; ResultCode = 4; HResult = -2145124330; Title = 'Aktualizacja nieudana (KB5000011)'; Description = ''; ClientApplicationID = 'MyWindowsPower'; SupportUrl = ''; UpdateIdentity = [pscustomobject]@{ UpdateID = 'bbbb' } }
                    [pscustomobject]@{ Date = [datetime]'2026-10-21T10:00:00'; Operation = 2; ResultCode = 2; HResult = 0; Title = 'Odinstalowanie (KB5000012)'; Description = ''; ClientApplicationID = 'wusa'; SupportUrl = ''; UpdateIdentity = $null }
                )
                Reboot        = $false
                InstallReboot = $false
                SearchError   = 0
                InstallCode   = @{}
                DownloadCode  = 2
                InstallerBusy = $false
                Admin         = $true
                Services      = @{
                    usosvc   = @{ Name = 'UsoSvc'; State = 'Running'; StartMode = 'Auto'; Delayed = $true; DisplayName = 'Usługa koordynatora aktualizacji'; FailStop = $false }
                    wuauserv = @{ Name = 'wuauserv'; State = 'Running'; StartMode = 'Manual'; Delayed = $false; DisplayName = 'Windows Update'; FailStop = $false }
                    bits     = @{ Name = 'BITS'; State = 'Running'; StartMode = 'Auto'; Delayed = $true; DisplayName = 'Usługa inteligentnego transferu w tle'; FailStop = $false }
                    cryptsvc = @{ Name = 'CryptSvc'; State = 'Stopped'; StartMode = 'Auto'; Delayed = $false; DisplayName = 'Usługi kryptograficzne'; FailStop = $false }
                }
            }
            $script:Calls = New-Object -TypeName System.Collections.Generic.List[string]
        }
        Initialize-FakeUpdate

        $fakeCom = {
            switch ($ComObject) {
                'Microsoft.Update.SystemInfo' { return [pscustomobject]@{ RebootRequired = $script:Fake.Reboot } }
                'Microsoft.Update.AutoUpdate' { return [pscustomobject]@{ Results = [pscustomobject]@{ LastSearchSuccessDate = [datetime]'2026-10-28T06:37:00'; LastInstallationSuccessDate = [datetime]'2026-10-24T15:54:00' } } }
                'Microsoft.Update.UpdateColl' {
                    $collection = [pscustomobject]@{ Items = (New-Object -TypeName System.Collections.Generic.List[object]) }
                    $collection | Add-Member -MemberType ScriptMethod -Name Add -Value { param($Item) $this.Items.Add($Item); $this.Items.Count - 1 }
                    return $collection
                }
                'Microsoft.Update.Session' {
                    $script:Calls.Add('Session')
                    $session = [pscustomobject]@{ ClientApplicationID = '' }
                    $session | Add-Member -MemberType ScriptMethod -Name CreateUpdateSearcher -Value {
                        $searcher = [pscustomobject]@{}
                        $searcher | Add-Member -MemberType ScriptMethod -Name Search -Value {
                            param($Criteria)
                            $script:Calls.Add('Search ' + $Criteria)
                            if ($script:Fake.SearchError -ne 0) {
                                throw [Runtime.InteropServices.COMException]::new('Wyszukiwanie odrzucone.', [int]$script:Fake.SearchError)
                            }
                            $updates = @($script:Fake.Updates | Where-Object {
                                    ($Criteria -notmatch "Type='Software'" -or $_.Type -eq 1) -and ($Criteria -notmatch "Type='Driver'" -or $_.Type -eq 2)
                                })
                            [pscustomobject]@{ ResultCode = 2; Updates = $updates }
                        }
                        $searcher | Add-Member -MemberType ScriptMethod -Name GetTotalHistoryCount -Value { @($script:Fake.History).Count }
                        $searcher | Add-Member -MemberType ScriptMethod -Name QueryHistory -Value {
                            param($Start, $Count)
                            $script:Calls.Add(('QueryHistory {0} {1}' -f $Start, $Count))
                            @($script:Fake.History)[$Start..($Start + $Count - 1)]
                        }
                        $searcher
                    }
                    $session | Add-Member -MemberType ScriptMethod -Name CreateUpdateDownloader -Value {
                        $downloader = [pscustomobject]@{ Updates = $null }
                        $downloader | Add-Member -MemberType ScriptMethod -Name Download -Value {
                            foreach ($update in $this.Updates.Items) {
                                $script:Calls.Add('Download ' + $update.Identity.UpdateID)
                                if ($script:Fake.DownloadCode -eq 2) { $update.IsDownloaded = $true }
                            }
                            [pscustomobject]@{ ResultCode = $script:Fake.DownloadCode; HResult = $(if ($script:Fake.DownloadCode -eq 2) { 0 } else { -2145107924 }) }
                        }
                        $downloader
                    }
                    $session | Add-Member -MemberType ScriptMethod -Name CreateUpdateInstaller -Value {
                        $installer = [pscustomobject]@{ Updates = $null; AllowSourcePrompts = $true; IsBusy = $script:Fake.InstallerBusy }
                        $installer | Add-Member -MemberType ScriptMethod -Name Install -Value {
                            $results = @(foreach ($update in $this.Updates.Items) {
                                    $id = [string]$update.Identity.UpdateID
                                    $script:Calls.Add('Install ' + $id)
                                    $code = if ($script:Fake.InstallCode.ContainsKey($id)) { $script:Fake.InstallCode[$id] } else { 2 }
                                    [pscustomobject]@{ ResultCode = $code; HResult = $(if ($code -eq 2) { 0 } else { -2146498530 }); RebootRequired = $script:Fake.InstallReboot -and $code -eq 2 }
                                })
                            $install = [pscustomobject]@{ RebootRequired = $script:Fake.InstallReboot; Results = $results }
                            $install | Add-Member -MemberType ScriptMethod -Name GetUpdateResult -Value { param($Index) $this.Results[$Index] }
                            $install
                        }
                        $installer
                    }
                    return $session
                }
            }
        }
        $fakeCim = {
            foreach ($key in $script:Fake.Services.Keys) {
                $service = $script:Fake.Services[$key]
                [pscustomobject]@{ Name = $service.Name; DisplayName = $service.DisplayName; State = $service.State; StartMode = $service.StartMode; DelayedAutoStart = $service.Delayed }
            }
            [pscustomobject]@{ Name = 'Spooler'; DisplayName = 'Bufor wydruku'; State = 'Running'; StartMode = 'Auto'; DelayedAutoStart = $false }
        }
        $fakeGetService = {
            $serviceName = ([string]@($Name)[0]).ToLowerInvariant()
            if (-not $script:Fake.Services.ContainsKey($serviceName)) {
                throw ("Nie można odnaleźć usługi '{0}'." -f $serviceName)
            }
            $controller = [pscustomobject]@{ Key = $serviceName }
            $controller | Add-Member -MemberType ScriptProperty -Name Status -Value { $script:Fake.Services[$this.Key].State }
            $controller | Add-Member -MemberType ScriptMethod -Name Refresh -Value { }
            $controller | Add-Member -MemberType ScriptMethod -Name Stop -Value {
                $script:Calls.Add('Stop ' + $this.Key)
                if ($script:Fake.Services[$this.Key].FailStop) { throw 'Usługa nie odpowiedziała na żądanie zatrzymania.' }
                $script:Fake.Services[$this.Key].State = 'Stopped'
            }
            $controller | Add-Member -MemberType ScriptMethod -Name Start -Value {
                $script:Calls.Add('Start ' + $this.Key)
                $script:Fake.Services[$this.Key].State = 'Running'
            }
            $controller | Add-Member -MemberType ScriptMethod -Name WaitForStatus -Value { }
            $controller
        }
        foreach ($scope in 'MWP.Remote', 'MWP.Update') {
            Mock -ModuleName $scope New-Object { Microsoft.PowerShell.Utility\New-Object @PesterBoundParameters }
            Mock -ModuleName $scope New-Object -ParameterFilter { $ComObject -like 'Microsoft.Update.*' } $fakeCom
            Mock -ModuleName $scope Get-CimInstance { Microsoft.PowerShell.Utility\Write-Output $null }
            Mock -ModuleName $scope Get-CimInstance -ParameterFilter { $ClassName -eq 'Win32_Service' } $fakeCim
            Mock -ModuleName $scope Get-Service $fakeGetService
            Mock -ModuleName $scope Start-Sleep { }
        }
        Mock Get-Service $fakeGetService
        Mock -ModuleName MWP.Update Test-MwpAdmin { $script:Fake.Admin }
        Mock -ModuleName MWP.Update Start-Process { $script:Calls.Add('Start-Process ' + $FilePath) }

        $context = New-MwpExecutionContext
        function Get-Call {
            param([string] $Prefix)
            @($script:Calls | Where-Object { $_ -like "$Prefix*" })
        }
        function Get-Log {
            $logs = Join-Path -Path $TestDrive -ChildPath 'Logs'
            if (Test-Path -LiteralPath $logs) { Get-ChildItem -LiteralPath $logs -Filter '*.log' | Get-Content -Raw -Encoding UTF8 }
        }
        function Get-PauseValue {
            param([string] $Name)
            if (-not (Test-Path -LiteralPath $script:PauseKey)) { return $null }
            $item = Get-ItemProperty -LiteralPath $script:PauseKey
            if ($null -ne $item.PSObject.Properties[$Name]) { [string]$item.$Name } else { $null }
        }
        function Initialize-FakeFolder {
            foreach ($path in @((Join-Path -Path $script:WindowsRoot -ChildPath 'SoftwareDistribution'), (Join-Path -Path $script:WindowsRoot -ChildPath 'System32\catroot2'))) {
                $parent = Split-Path -Parent $path
                if (Test-Path -LiteralPath $parent) {
                    Get-ChildItem -LiteralPath $parent -Force | Where-Object { $_.Name -like ((Split-Path -Leaf $path) + '*') } | ForEach-Object {
                        if ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) { [IO.Directory]::Delete($_.FullName) } else { Remove-Item -LiteralPath $_.FullName -Recurse -Force }
                    }
                }
                $null = New-Item -ItemType Directory -Path $path -Force
                Set-Content -LiteralPath (Join-Path -Path $path -ChildPath 'dane.txt') -Value 'stare dane' -Encoding UTF8
            }
        }
    }

    AfterAll {
        Remove-Module -Name MWP.Update, MWP.Remote, MWP.Core -Force -ErrorAction SilentlyContinue
    }

    BeforeEach {
        Initialize-FakeUpdate
        Initialize-FakeFolder
        foreach ($key in $script:PauseKey, $script:PolicyKey, $script:RebootKey, $script:PendingKey) {
            if (Test-Path -LiteralPath $key) { Remove-Item -LiteralPath $key -Recurse -Force }
        }
        $null = New-Item -Path $script:PauseKey -Force
    }

    Context 'stan Windows Update' {
        It 'usługi, restart, daty, pauza i brak ostrzeżeń' {
            $result = Get-MwpUpdateStatus -Context $context
            $result.Success | Should -BeTrue -Because $result.Message
            $status = $result.Data
            $status.PSObject.TypeNames | Should -Contain 'MWP.UpdateStatus'
            @($status.Services).Count | Should -Be 4
            ($status.Services | Where-Object Name -eq 'BITS').StartupTypeText | Should -Be 'Automatyczny (opóźniony start)'
            ($status.Services | Where-Object Name -eq 'CryptSvc').StatusText | Should -Be 'Zatrzymana'
            $status.RebootRequired | Should -BeFalse
            $status.RebootText | Should -Be 'Restart nie jest wymagany.'
            $status.LastSearch | Should -Not -BeNullOrEmpty
            $status.Pause.IsPaused | Should -BeFalse
            $status.PauseText | Should -Be 'Aktualizacje nie są wstrzymane.'
            @($status.Warnings).Count | Should -Be 0
            @($status.Backups).Count | Should -Be 0
            $result.RestartRequired | Should -BeFalse
        }

        It 'wymagany restart z Windows Update Agent i z kluczy rejestru' {
            $script:Fake.Reboot = $true
            $null = New-Item -Path $script:PendingKey -Force
            $status = (Get-MwpUpdateStatus -Context $context).Data
            $status.RebootRequired | Should -BeTrue
            @($status.RebootSources).Count | Should -Be 2
            $status.RebootText | Should -Match 'RebootPending'
        }

        It 'aktywna pauza, wygasła pauza i zasady grupy (ostrzeżenie)' {
            $end = (Get-Date).ToUniversalTime().AddDays(10).ToString("yyyy-MM-dd'T'HH:mm:ss'Z'")
            Set-ItemProperty -LiteralPath $script:PauseKey -Name 'PauseUpdatesExpiryTime' -Value $end
            $status = (Get-MwpUpdateStatus -Context $context).Data
            $status.Pause.IsPaused | Should -BeTrue
            $status.Pause.Values['PauseUpdatesExpiryTime'] | Should -Be $end
            $status.PauseText | Should -Match 'wstrzymane do'
            Set-ItemProperty -LiteralPath $script:PauseKey -Name 'PauseUpdatesExpiryTime' -Value '2020-01-01T00:00:00Z'
            (Get-MwpUpdateStatus -Context $context).Data.PauseText | Should -Match 'wygasła'
            $null = New-Item -Path $script:PolicyKey -Force
            Set-ItemProperty -LiteralPath $script:PolicyKey -Name 'SetDisablePauseUXAccess' -Value 1
            $status = (Get-MwpUpdateStatus -Context $context).Data
            @($status.Policies) | Should -Be @('SetDisablePauseUXAccess = 1')
            ($status.Warnings -join ' ') | Should -Match 'Zasady grupy'
        }

        It 'usługa wyłączona i brak usługi dają ostrzeżenia' {
            $script:Fake.Services['wuauserv'].StartMode = 'Disabled'
            $script:Fake.Services.Remove('usosvc')
            $status = (Get-MwpUpdateStatus -Context $context).Data
            ($status.Services | Where-Object Name -eq 'usosvc').StatusText | Should -Be 'Brak usługi'
            ($status.Warnings -join ' ') | Should -Match 'wyłączona'
            ($status.Warnings -join ' ') | Should -Match 'Brak usługi usosvc'
        }

        It '-AsOperation startuje operację z blokiem Status, a Resolve-MwpUpdateStatus parsuje surowy wynik' {
            Mock -ModuleName MWP.Update Start-MwpOperation { [pscustomobject]@{ PSTypeName = 'MWP.Operation'; Operation = $Operation; Arguments = $ArgumentList } }
            $operation = Get-MwpUpdateStatus -Context $context -AsOperation
            $operation.Operation | Should -Be 'Update.Status'
            $json = InModuleScope MWP.Remote -Parameters @{ Request = [string]$operation.Arguments[0] } {
                param($Request)
                $text = (& (Get-Module -Name MWP.Update) { Get-MwpUpdateScript -Name Status }).ToString()
                & ((Get-Module -Name MWP.Remote).NewBoundScriptBlock([scriptblock]::Create($text))) $Request
            }
            $status = Resolve-MwpUpdateStatus -Data $json
            @($status.Services).Count | Should -Be 4
            Resolve-MwpUpdateStatus -Data $null | Should -BeNullOrEmpty
            Resolve-MwpUpdateStatus -Data $status | Should -Be $status
        }
    }

    Context 'widget Dashboardu (D-053)' {
        It 'widok „Windows Update”: domyślnie restart i pauza, sekcje z parametru, brak danych bez wyjątku' {
            $script:Fake.Reboot = $true
            $data = (Get-MwpUpdateStatus -Context $context).Data
            $view = ConvertTo-MwpUpdateStatusView -Data $data
            $view.PSObject.TypeNames | Should -Contain 'MWP.WidgetView'
            @($view.Sections | ForEach-Object Title) | Should -Be @('Restart', 'Pauza')
            $view.Sections[0].Items[0].Value | Should -Be 'wymagany'
            $view.Sections[0].Items[0].Tone | Should -Be 'Warning'
            $view.Summary | Should -Match 'wymaga restartu'
            $all = ConvertTo-MwpUpdateStatusView -Data $data -WidgetParameters @{ Sections = @('LastActivity', 'Services') }
            @($all.Sections | ForEach-Object Title) | Should -Be @('Ostatnio', 'Usługi')
            @($all.Sections[1].Items).Count | Should -Be 4
            ConvertTo-MwpUpdateStatusView -Data $null | Should -BeNullOrEmpty
            ConvertTo-MwpUpdateStatusView -Data 'to nie jest JSON' | Should -BeNullOrEmpty
        }

        It 'funkcja danych przyjmuje -WidgetParameters i z -AsOperation tylko odczytuje (blok Status)' {
            Mock -ModuleName MWP.Update Start-MwpOperation { [pscustomobject]@{ PSTypeName = 'MWP.Operation'; Operation = $Operation } }
            (Get-MwpUpdateStatus -Context $context -AsOperation -WidgetParameters @{ Sections = @('Restart') }).Operation | Should -Be 'Update.Status'
        }
    }

    Context 'wyszukiwanie aktualizacji (COM)' {
        It 'zwraca oczekujące aktualizacje ze stałymi kryteriami, KB, rozmiarem, restartem i instalowalnością' {
            $result = Find-MwpUpdate -Context $context
            $result.Success | Should -BeTrue -Because $result.Message
            Get-Call 'Search' | Should -Be @('Search IsInstalled=0 and IsHidden=0')
            $search = $result.Data
            $search.Count | Should -Be 4
            $byId = @{}
            foreach ($update in $search.Updates) { $byId[$update.UpdateId] = $update }
            $byId[$script:IdA].KBText | Should -Be 'KB5000001'
            $byId[$script:IdA].SizeText | Should -Be '500 MB'
            $byId[$script:IdA].RebootText | Should -Be 'Tak'
            $byId[$script:IdA].SeverityText | Should -Be 'Ważna'
            $byId[$script:IdA].IsInstallable | Should -BeTrue
            $byId[$script:IdB].RebootText | Should -Be 'Nie'
            $byId[$script:IdC].TypeText | Should -Be 'Sterownik'
            $byId[$script:IdC].IsInstallable | Should -BeFalse
            $byId[$script:IdC].NotInstallableReason | Should -Match 'interakcji'
            $byId[$script:IdD].NotInstallableReason | Should -Match 'licencyjnych'
            $result.Message | Should -Match "4 oczekujących aktualizacji na komputerze 'localhost'"
        }

        It 'rodzaj wyszukiwania wybiera stałe kryteria (bez sklejania danych wejściowych)' {
            @((Find-MwpUpdate -Context $context -Type Driver).Data.Updates).Count | Should -Be 1
            @((Find-MwpUpdate -Context $context -Type Software).Data.Updates).Count | Should -Be 3
            Get-Call 'Search' | Should -Be @("Search IsInstalled=0 and IsHidden=0 and Type='Driver'", "Search IsInstalled=0 and IsHidden=0 and Type='Software'")
            { Find-MwpUpdate -Context $context -Type "x' or 1=1" } | Should -Throw
        }

        It 'błąd Windows Update Agent: wynik z błędem, kodem HRESULT i opisem po polsku' {
            $script:Fake.SearchError = -2145107924
            $result = Find-MwpUpdate -Context $context
            $result.Success | Should -BeFalse
            $result.Message | Should -Match '0x8024402C'
            $result.Message | Should -Match 'brak połączenia z serwerem'
            $script:Fake.Updates = @()
            $script:Fake.SearchError = 0
            (Find-MwpUpdate -Context $context).Message | Should -Match 'Brak oczekujących aktualizacji'
        }
    }

    Context 'historia aktualizacji' {
        It 'wpisy od najnowszego, operacje i wyniki po polsku, KB z tytułu, kod błędu z opisem' {
            $result = Get-MwpUpdateHistory -Context $context -First 10
            $result.Success | Should -BeTrue -Because $result.Message
            $history = $result.Data
            $history.TotalCount | Should -Be 3
            $history.FailedCount | Should -Be 1
            $entries = @($history.Entries)
            $entries[0].KBText | Should -Be 'KB5000011'
            $entries[0].ResultText | Should -Be 'Niepowodzenie'
            $entries[0].HResult | Should -Be '0x80240016'
            $entries[0].HResultText | Should -Match 'inna instalacja'
            $entries[1].OperationText | Should -Be 'Odinstalowanie'
            $entries[2].ResultText | Should -Be 'Powodzenie'
            $entries[2].HResult | Should -Be ''
            Get-Call 'QueryHistory' | Should -Be @('QueryHistory 0 3')
            (Get-MwpUpdateHistory -Context $context -First 2).Data.TotalCount | Should -Be 3
            Get-Call 'QueryHistory' | Should -Contain 'QueryHistory 0 2'
        }
    }

    Context 'pauza aktualizacji' {
        It '-WhatIf: podgląd z nazwą komputera i datą końca, rejestr bez zmian, bez logu zmiany' {
            $result = Suspend-MwpUpdate -Weeks 2 -Context $context -WhatIf
            $result.IsPreview | Should -BeTrue -Because $result.Message
            $result.Changed | Should -BeFalse
            $result.Message | Should -Match '2 tydz'
            Get-PauseValue 'PauseUpdatesExpiryTime' | Should -BeNullOrEmpty
            Get-Log | Should -Not -Match '"operation":"Update.Pause"'
        }

        It 'wstrzymuje na N tygodni (wszystkie wartości jak Ustawienia), loguje i cofa' {
            $result = Suspend-MwpUpdate -Weeks 3 -Context $context -Confirm:$false
            $result.Success | Should -BeTrue -Because $result.Message
            $result.Changed | Should -BeTrue
            $end = [datetime]::Parse((Get-PauseValue 'PauseUpdatesExpiryTime'), [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AdjustToUniversal)
            ($end - (Get-Date).ToUniversalTime()).TotalDays | Should -BeGreaterThan 20.9
            ($end - (Get-Date).ToUniversalTime()).TotalDays | Should -BeLessThan 21.1
            foreach ($name in 'PauseUpdatesStartTime', 'PauseFeatureUpdatesStartTime', 'PauseFeatureUpdatesEndTime', 'PauseQualityUpdatesStartTime', 'PauseQualityUpdatesEndTime') {
                Get-PauseValue $name | Should -Match '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$' -Because $name
            }
            (Get-ItemProperty -LiteralPath $script:PauseKey).PSObject.Properties['PauseUpdatesExpiryTime'].TypeNameOfValue | Should -Be 'System.String'
            (Get-MwpUpdateStatus -Context $context).Data.Pause.IsPaused | Should -BeTrue
            Get-Log | Should -Match '"computer":"localhost","source":"MWP.Update","operation":"Update.Pause"'
            $undo = Invoke-MwpUndo -Id $result.UndoId -Context $context -Confirm:$false
            $undo.Success | Should -BeTrue -Because $undo.Message
            Get-PauseValue 'PauseUpdatesExpiryTime' | Should -BeNullOrEmpty
            (Get-MwpUpdateStatus -Context $context).Data.Pause.HasValues | Should -BeFalse
        }

        It 'wznowienie usuwa wartości pauzy, a cofnięcie przywraca je dokładnie' {
            $start = '2026-10-20T08:00:00Z'
            $end = (Get-Date).ToUniversalTime().AddDays(5).ToString("yyyy-MM-dd'T'HH:mm:ss'Z'")
            Set-ItemProperty -LiteralPath $script:PauseKey -Name 'PauseUpdatesStartTime' -Value $start
            Set-ItemProperty -LiteralPath $script:PauseKey -Name 'PauseUpdatesExpiryTime' -Value $end
            $result = Resume-MwpUpdate -Context $context -Confirm:$false
            $result.Success | Should -BeTrue -Because $result.Message
            Get-PauseValue 'PauseUpdatesExpiryTime' | Should -BeNullOrEmpty
            (Invoke-MwpUndo -Id $result.UndoId -Context $context -Confirm:$false).Success | Should -BeTrue
            Get-PauseValue 'PauseUpdatesStartTime' | Should -Be $start
            Get-PauseValue 'PauseUpdatesExpiryTime' | Should -Be $end
            Get-PauseValue 'PauseQualityUpdatesEndTime' | Should -BeNullOrEmpty
        }

        It 'wznowienie bez pauzy: bez zmian i bez wpisu cofnięcia' {
            $result = Resume-MwpUpdate -Context $context -Confirm:$false
            $result.Success | Should -BeTrue
            $result.Changed | Should -BeFalse
            $result.UndoId | Should -BeNullOrEmpty
        }

        It 'brak administratora: odmowa przed podglądem; limit 1–5 tygodni; przywrócenie odrzuca obce nazwy i wartości' {
            $script:Fake.Admin = $false
            $result = Suspend-MwpUpdate -Weeks 1 -Context $context -WhatIf
            $result.Success | Should -BeFalse
            $result.Message | Should -Match 'administratora'
            $script:Fake.Admin = $true
            { Suspend-MwpUpdate -Weeks 6 -Context $context -WhatIf } | Should -Throw
            (Restore-MwpUpdatePause -StateJson '{"FlightSettingsMaxPauseDays":"9999"}' -Context $context -Confirm:$false).Message | Should -Match 'Nieznana wartość'
            (Restore-MwpUpdatePause -StateJson '{"PauseUpdatesExpiryTime":"nie-data"}' -Context $context -Confirm:$false).Message | Should -Match 'nie jest datą'
            Get-PauseValue 'PauseUpdatesExpiryTime' | Should -BeNullOrEmpty
        }
    }

    Context 'reset składników Windows Update' {
        It 'kroki podglądu: usługi, obie zmiany nazw, ponowne uruchomienie i cofnięcie' {
            $steps = @(Get-MwpUpdateResetStep -Suffix 'mwp-20261028-120000')
            $steps.Count | Should -Be 5
            $steps[0].Text | Should -Match 'usosvc \(opcjonalnie\), wuauserv, bits, cryptsvc'
            $steps[1].Text | Should -Match 'SoftwareDistribution → %SystemRoot%\\SoftwareDistribution\.mwp-20261028-120000'
            $steps[2].Text | Should -Match 'System32\\catroot2'
            $steps[4].Text | Should -Match 'Restore-MwpUpdateComponent -Suffix mwp-20261028-120000'
            { Get-MwpUpdateResetStep -Suffix '..\x' } | Should -Throw
        }

        It '-WhatIf: podgląd kroków z nazwą komputera, foldery i usługi bez zmian' {
            $result = Reset-MwpUpdateComponent -Context $context -WhatIf
            $result.IsPreview | Should -BeTrue -Because $result.Message
            $result.Message | Should -Match "komputerze 'localhost'"
            $result.Message | Should -Match '1\. Zatrzymanie usług'
            @($result.Data).Count | Should -Be 5
            Test-Path -LiteralPath (Join-Path -Path $script:WindowsRoot -ChildPath 'SoftwareDistribution\dane.txt') | Should -BeTrue
            Get-Call 'Stop' | Should -BeNullOrEmpty
        }

        It 'zatrzymuje usługi, zmienia nazwy folderów (stare zostają), uruchamia działające usługi, loguje; cofnięcie przywraca foldery' {
            $result = Reset-MwpUpdateComponent -Context $context -Confirm:$false
            $result.Success | Should -BeTrue -Because $result.Message
            $result.Changed | Should -BeTrue
            Get-Call 'Stop' | Should -Be @('Stop usosvc', 'Stop wuauserv', 'Stop bits')
            Get-Call 'Start' | Should -Be @('Start bits', 'Start wuauserv', 'Start usosvc')
            $script:Fake.Services['cryptsvc'].State | Should -Be 'Stopped'
            $backup = @(Get-ChildItem -LiteralPath $script:WindowsRoot -Directory | Where-Object { $_.Name -like 'SoftwareDistribution.mwp-*' })
            $backup.Count | Should -Be 1
            Test-Path -LiteralPath (Join-Path -Path $backup[0].FullName -ChildPath 'dane.txt') | Should -BeTrue
            Test-Path -LiteralPath (Join-Path -Path $script:WindowsRoot -ChildPath 'SoftwareDistribution') | Should -BeFalse
            @(Get-ChildItem -LiteralPath (Join-Path -Path $script:WindowsRoot -ChildPath 'System32') -Directory | Where-Object { $_.Name -like 'catroot2.mwp-*' }).Count | Should -Be 1
            Get-Log | Should -Match '"operation":"Update.ResetComponents"'
            $status = (Get-MwpUpdateStatus -Context $context).Data
            @($status.Backups).Count | Should -Be 1
            @($status.Backups[0].Folders | Sort-Object) | Should -Be @('catroot2', 'SoftwareDistribution')

            # Windows Update odtwarza folder; cofnięcie przenosi go pod nazwę *.mwp-replaced-* i przywraca kopię.
            $null = New-Item -ItemType Directory -Path (Join-Path -Path $script:WindowsRoot -ChildPath 'SoftwareDistribution\Nowy') -Force
            $undo = Invoke-MwpUndo -Id $result.UndoId -Context $context -Confirm:$false
            $undo.Success | Should -BeTrue -Because $undo.Message
            Test-Path -LiteralPath (Join-Path -Path $script:WindowsRoot -ChildPath 'SoftwareDistribution\dane.txt') | Should -BeTrue
            Test-Path -LiteralPath (Join-Path -Path $script:WindowsRoot -ChildPath 'System32\catroot2\dane.txt') | Should -BeTrue
            @(Get-ChildItem -LiteralPath $script:WindowsRoot -Directory | Where-Object { $_.Name -like 'SoftwareDistribution.mwp-replaced-*' }).Count | Should -Be 1
            @((Get-MwpUpdateStatus -Context $context).Data.Backups).Count | Should -Be 0
        }

        It 'błąd zatrzymania usługi wymaganej: reset przerwany przed folderami, usługi uruchomione ponownie, bez wpisu cofnięcia' {
            $script:Fake.Services['bits'].FailStop = $true
            $result = Reset-MwpUpdateComponent -Context $context -Confirm:$false
            $result.Success | Should -BeFalse
            $result.Message | Should -Match 'bits'
            $result.Message | Should -Match 'Foldery nie zostały zmienione'
            $result.UndoId | Should -BeNullOrEmpty
            Test-Path -LiteralPath (Join-Path -Path $script:WindowsRoot -ChildPath 'SoftwareDistribution\dane.txt') | Should -BeTrue
            $script:Fake.Services['wuauserv'].State | Should -Be 'Running'
            $script:Fake.Services['usosvc'].State | Should -Be 'Running'
            Get-Log | Should -Match '"level":"Error"'
        }

        It 'usługa opcjonalna (usosvc), której nie da się zatrzymać, nie przerywa resetu' {
            $script:Fake.Services['usosvc'].FailStop = $true
            $result = Reset-MwpUpdateComponent -Context $context -Confirm:$false
            $result.Success | Should -BeTrue -Because $result.Message
            ($result.Data.Steps | Where-Object { $_.Target -eq 'usosvc' -and $_.Step -eq 'Stop' }).Message | Should -Match 'opcjonalna'
        }

        It 'błąd zmiany nazwy catroot2 wycofuje zmianę nazwy SoftwareDistribution' {
            $locked = [IO.File]::Open((Join-Path -Path $script:WindowsRoot -ChildPath 'System32\catroot2\dane.txt'), 'Open', 'Read', 'None')
            try {
                $result = Reset-MwpUpdateComponent -Context $context -Confirm:$false
            }
            finally {
                $locked.Dispose()
            }
            $result.Success | Should -BeFalse
            $result.UndoId | Should -BeNullOrEmpty
            Test-Path -LiteralPath (Join-Path -Path $script:WindowsRoot -ChildPath 'SoftwareDistribution\dane.txt') | Should -BeTrue
            @(Get-ChildItem -LiteralPath $script:WindowsRoot -Directory | Where-Object { $_.Name -like 'SoftwareDistribution.mwp-*' }).Count | Should -Be 0
            ($result.Data.Steps | Where-Object Step -eq 'Rollback').Success | Should -BeTrue
            $script:Fake.Services['wuauserv'].State | Should -Be 'Running'
        }

        It 'folder będący dowiązaniem (junction) nie jest przenoszony' {
            $sd = Join-Path -Path $script:WindowsRoot -ChildPath 'SoftwareDistribution'
            Remove-Item -LiteralPath $sd -Recurse -Force
            $outside = Join-Path -Path $TestDrive -ChildPath 'poza'
            $null = New-Item -ItemType Directory -Path $outside -Force
            $null = New-Item -ItemType Junction -Path $sd -Target $outside
            $result = Reset-MwpUpdateComponent -Context $context -Confirm:$false
            $result.Success | Should -BeFalse
            $result.Message | Should -Match 'dowiązaniem'
            (Get-Item -LiteralPath $sd -Force).Attributes -band [IO.FileAttributes]::ReparsePoint | Should -BeTrue
        }

        It 'brak administratora: odmowa przed podglądem; przywrócenie bez kopii nic nie zmienia' {
            $script:Fake.Admin = $false
            $result = Reset-MwpUpdateComponent -Context $context -WhatIf
            $result.Success | Should -BeFalse
            $result.Message | Should -Match 'administratora'
            $script:Fake.Admin = $true
            $restore = Restore-MwpUpdateComponent -Suffix 'mwp-20200101-000000' -Context $context -Confirm:$false
            $restore.Success | Should -BeFalse
            $restore.Message | Should -Match 'nie ma kopii'
            Test-Path -LiteralPath (Join-Path -Path $script:WindowsRoot -ChildPath 'SoftwareDistribution\dane.txt') | Should -BeTrue
        }
    }

    Context 'instalacja aktualizacji (tylko lokalnie)' {
        It '-WhatIf: podgląd z tytułami, bez sesji Windows Update Agent' {
            $update = (Find-MwpUpdate -Context $context).Data.Updates | Where-Object UpdateId -eq $script:IdA
            $script:Calls.Clear()
            $result = Install-MwpUpdate -Update $update -Context $context -WhatIf
            $result.IsPreview | Should -BeTrue -Because $result.Message
            $result.Message | Should -Match 'Aktualizacja zbiorcza'
            Get-Call 'Session' | Should -BeNullOrEmpty
        }

        It 'pobiera brakujące, instaluje po jednej, pomija wymagające interakcji i licencji, zgłasza restart; log' {
            $script:Fake.InstallReboot = $true
            $progress = [hashtable]::Synchronized(@{ Percent = -1; Message = ''; CancelRequested = $false })
            $result = Install-MwpUpdate -UpdateId $script:IdA, $script:IdB, $script:IdC, $script:IdD -Context $context -Progress $progress -Confirm:$false
            $result.Success | Should -BeTrue -Because $result.Message
            $result.Changed | Should -BeTrue
            $result.RestartRequired | Should -BeTrue
            Get-Call 'Download' | Should -Be @("Download $($script:IdA)")
            Get-Call 'Install' | Should -Be @("Install $($script:IdA)", "Install $($script:IdB)")
            $items = @{}
            foreach ($item in $result.Data.Items) { $items[$item.UpdateId] = $item }
            $items[$script:IdA].Status | Should -Be 'Installed'
            $items[$script:IdC].Status | Should -Be 'Skipped'
            $items[$script:IdD].Reason | Should -Match 'licencyjnych'
            $progress.Percent | Should -Be 100
            $result.Message | Should -Match 'zainstalowano 2, niepowodzenia 0, pominięto 2'
            $result.Message | Should -Match 'Wymagany restart'
            Get-Log | Should -Match '"operation":"Update.Install"'
        }

        It 'niepowodzenie instalacji, nieznana aktualizacja i zajęty instalator dają wynik z błędem' {
            $script:Fake.InstallCode[$script:IdA] = 4
            $missing = '99999999-9999-9999-9999-999999999999'
            $result = Install-MwpUpdate -UpdateId $script:IdA, $missing -Context $context -Confirm:$false
            $result.Success | Should -BeFalse
            ($result.Data.Items | Where-Object UpdateId -eq $script:IdA).Status | Should -Be 'Failed'
            ($result.Data.Items | Where-Object UpdateId -eq $missing).Status | Should -Be 'NotFound'
            $script:Fake.InstallCode.Clear()
            $script:Fake.InstallerBusy = $true
            $busy = Install-MwpUpdate -UpdateId $script:IdB -Context $context -Confirm:$false
            $busy.Success | Should -BeFalse
            ($busy.Data.Items[0].Reason) | Should -Match 'zajęty'
        }

        It 'anulowanie z tabeli postępu: nic nie jest instalowane' {
            $progress = [hashtable]::Synchronized(@{ Percent = -1; Message = ''; CancelRequested = $true })
            $result = Install-MwpUpdate -UpdateId $script:IdA, $script:IdB -Context $context -Progress $progress -Confirm:$false
            Get-Call 'Install' | Should -BeNullOrEmpty
            @($result.Data.Items | Where-Object Status -eq 'Cancelled').Count | Should -Be 2
            $result.Data.Cancelled | Should -BeTrue
        }

        It 'brak administratora i niepoprawny identyfikator: odmowa przed zmianą' {
            $script:Fake.Admin = $false
            (Install-MwpUpdate -UpdateId $script:IdA -Context $context -Confirm:$false).Message | Should -Match 'administratora'
            Get-Call 'Session' | Should -BeNullOrEmpty
            { Install-MwpUpdate -UpdateId 'nie-guid' -Context $context -WhatIf } | Should -Throw
        }

        It 'Open-MwpUpdatePage otwiera Ustawienia lokalnie' {
            (Open-MwpUpdatePage -Context $context).Success | Should -BeTrue
            Get-Call 'Start-Process' | Should -Be @('Start-Process ms-settings:windowsupdate')
        }
    }

    Context 'komputer zdalny (D-019, D-048)' {
        BeforeEach {
            Mock -ModuleName MWP.Remote Remove-MwpPSSession { }
            Mock -ModuleName MWP.Remote New-MwpPSSession { [pscustomobject]@{ ComputerName = $ComputerName; State = 'Opened' } }
            Mock -ModuleName MWP.Remote Invoke-MwpSessionCommand {
                $bound = (Get-Module -Name MWP.Remote).NewBoundScriptBlock($ScriptBlock)
                [pscustomobject]@{ Output = @(& $bound @ArgumentList); Errors = @() }
            }
            # Sprawdzenie administratora w sesji (Test-MwpUpdateAdmin): krótki blok bez żądania JSON.
            Mock -ModuleName MWP.Remote Invoke-MwpSessionCommand -ParameterFilter { $ScriptBlock.ToString() -match 'IsInRole' -and $ScriptBlock.ToString() -notmatch 'RequestJson' } {
                [pscustomobject]@{ Output = @($script:Fake.Admin); Errors = @() }
            }
            $remote = New-MwpExecutionContext -ComputerName $remoteName
        }

        It 'stan, wyszukiwanie i historia przez sesję komputera zdalnego' {
            (Get-MwpUpdateStatus -Context $remote).Success | Should -BeTrue
            $search = Find-MwpUpdate -Context $remote
            $search.Success | Should -BeTrue -Because $search.Message
            $search.ComputerName | Should -Be $remoteName
            $search.Message | Should -Match $remoteName
            (Get-MwpUpdateHistory -Context $remote).Data.TotalCount | Should -Be 3
        }

        It 'odmowa Windows Update Agent w sesji zdalnej (0x80070005) jest opisana' {
            $script:Fake.SearchError = -2147024891
            $result = Find-MwpUpdate -Context $remote
            $result.Success | Should -BeFalse
            $result.Message | Should -Match '0x80070005'
            $result.Message | Should -Match 'sesji zdalnej'
        }

        It 'instalacja zdalna jest odrzucona przed jakimkolwiek wywołaniem COM' {
            $result = Install-MwpUpdate -UpdateId $script:IdA -Context $remote -Confirm:$false
            $result.Success | Should -BeFalse
            $result.Message | Should -Match 'D-048'
            $result.ComputerName | Should -Be $remoteName
            Get-Call 'Session' | Should -BeNullOrEmpty
            (Open-MwpUpdatePage -Context $remote).Success | Should -BeFalse
        }

        It 'pauza i reset zdalnie: administrator sprawdzany w sesji; log, wpis cofnięcia i wynik z nazwą komputera' {
            $pause = Suspend-MwpUpdate -Weeks 1 -Context $remote -Confirm:$false
            $pause.Success | Should -BeTrue -Because $pause.Message
            (Get-MwpUndoEntry -Id $pause.UndoId).ComputerName | Should -Be $remoteName
            Should -Invoke Test-MwpAdmin -ModuleName MWP.Update -Times 0 -Exactly
            $reset = Reset-MwpUpdateComponent -Context $remote -Confirm:$false
            $reset.Success | Should -BeTrue -Because $reset.Message
            $reset.ComputerName | Should -Be $remoteName
            Get-Log | Should -Match ('"computer":"{0}","source":"MWP.Update","operation":"Update.ResetComponents"' -f $remoteName)
            (Invoke-MwpUndo -Id $reset.UndoId -Context $context -Confirm:$false).Success | Should -BeFalse
            (Invoke-MwpUndo -Id $reset.UndoId -Context $remote -Confirm:$false).Success | Should -BeTrue
        }

        It 'brak administratora na komputerze zdalnym: odmowa przed podglądem' {
            $script:Fake.Admin = $false
            (Reset-MwpUpdateComponent -Context $remote -WhatIf).Message | Should -Match ("administratora na komputerze '{0}'" -f $remoteName)
            (Suspend-MwpUpdate -Context $remote -WhatIf).Success | Should -BeFalse
        }

        It 'utrata połączenia: wynik z błędem dla tej instancji, bez wyjątku i bez zmiany; localhost działa dalej' {
            Mock -ModuleName MWP.Remote Invoke-MwpSessionCommand { throw (New-Object -TypeName Management.Automation.Remoting.PSRemotingTransportException -ArgumentList 'Połączenie zerwane') }
            $result = Reset-MwpUpdateComponent -Context $remote -Confirm:$false
            $result.Success | Should -BeFalse
            $result.ComputerName | Should -Be $remoteName
            $remote.Connection.State | Should -Be 'Disconnected'
            Test-Path -LiteralPath (Join-Path -Path $script:WindowsRoot -ChildPath 'SoftwareDistribution\dane.txt') | Should -BeTrue
            (Get-MwpUpdateStatus -Context $context).Success | Should -BeTrue
        }
    }

    Context 'kontrakt modułu i bloki komputera docelowego' {
        It 'kontrakt jest poprawny: RemoteTarget, Destructive, Undo i tryby widoku' {
            $definition = Get-MwpModuleDefinition -Name 'MWP.Update'
            $definition.IsValid | Should -BeTrue -Because ($definition.Errors -join ' ')
            $definition.Capabilities | Should -Contain 'RemoteTarget'
            $definition.Capabilities | Should -Contain 'Destructive'
            $definition.SupportedPresentationModes | Should -Contain 'Embedded'
        }

        It 'bloki nie używają funkcji MWP, Invoke-Expression ani $using:, a kryteria wyszukiwania są stałe' {
            foreach ($name in 'Status', 'Search', 'History', 'PauseWrite', 'Install', 'Reset') {
                $block = InModuleScope MWP.Update -Parameters @{ Name = $name } { param($Name) Get-MwpUpdateScript -Name $Name }
                $commands = @($block.Ast.FindAll({ param($node) $node -is [Management.Automation.Language.CommandAst] }, $true) | ForEach-Object { $_.GetCommandName() } | Where-Object { $_ })
                @($commands | Where-Object { $_ -match '-Mwp' }) | Should -BeNullOrEmpty -Because $name
                $block.ToString() | Should -Not -Match 'Invoke-Expression|\$using:|Remove-Item\s' -Because $name
            }
            InModuleScope MWP.Update { @('All', 'Software', 'Driver' | ForEach-Object { Get-MwpUpdateSearchFilter -Type $_ }) } |
                Should -Be @('IsInstalled=0 and IsHidden=0', "IsInstalled=0 and IsHidden=0 and Type='Software'", "IsInstalled=0 and IsHidden=0 and Type='Driver'")
        }

        It 'prawdziwa konfiguracja wskazuje klucze HKLM z Ustawień Windows 11 i stałe foldery resetu' {
            $config = InModuleScope MWP.Update { & (Get-Command -Name Get-MwpUpdateTargetConfig -CommandType Function).ScriptBlock }
            $config.PauseKey | Should -Be 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings'
            $config.WindowsRoot | Should -Be ''
            @($config.ResetFolders.RelativePath) | Should -Be @('SoftwareDistribution', 'System32\catroot2')
        }
    }
}
