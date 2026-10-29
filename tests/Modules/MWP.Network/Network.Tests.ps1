#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
    Testy modułu MWP.Network (FAZA 11, D-049) z symulatorem sieci: mocki poleceń NetAdapter, NetTCPIP, DnsClient,
    ScheduledTasks, rejestru (NameServer w Tcpip/Tcpip6) i CIM w zakresie MWP.Remote (tam Invoke-MwpOnTarget wykonuje
    bloki). Zadanie wycofania jest „rejestrowane” w symulatorze, a jego blok (zakodowany w argumentach zadania)
    test wykonuje sam — tak sprawdzamy, że bez zatwierdzenia stan wraca. netsh to atrapa .cmd w TestDrive
    (mock Get-MwpNetworkTargetConfig), ping idzie na 127.0.0.1, a test portu — na lokalny TcpListener. Testy nie
    zmieniają prawdziwej sieci, rejestru ani harmonogramu. Sprawdzają: stan, DNS z presetami, cofaniem
    i automatycznym wycofaniem, zatwierdzenie, adaptery (adapter połączenia), flush DNS, DHCP, resety, testy
    łączności, -WhatIf, uprawnienia administratora i komputer zdalny (mock transportu WinRM, utrata połączenia).
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Zmienne z bloków BeforeDiscovery/BeforeAll są używane w blokach It (zakresy Pestera).')]
param()

Describe 'MWP.Network — sieć' {
    BeforeAll {
        $root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
        foreach ($name in 'MWP.Core', 'MWP.Remote', 'MWP.Network') {
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

        # Atrapa netsh: zapisuje argumenty i kończy się kodem z nazwy pliku.
        $script:NetshArgs = Join-Path -Path $TestDrive -ChildPath 'netsh-args.txt'
        $script:NetshOk = Join-Path -Path $TestDrive -ChildPath 'netsh-ok.cmd'
        $script:NetshFail = Join-Path -Path $TestDrive -ChildPath 'netsh-fail.cmd'
        Set-Content -LiteralPath $script:NetshOk -Value @('@echo off', ('echo %*> "{0}"' -f $script:NetshArgs), 'echo Pomyslnie zresetowano.', 'exit /b 0') -Encoding Ascii
        Set-Content -LiteralPath $script:NetshFail -Value @('@echo off', 'echo Odmowa dostepu.', 'exit /b 1') -Encoding Ascii
        $script:NetshPath = $script:NetshOk
        Mock -ModuleName MWP.Network Get-MwpNetworkTargetConfig {
            [pscustomobject]@{ TaskPath = '\MyWindowsPower\'; TaskPrefix = 'MWP-NetworkRollback-'; DefaultRollbackSeconds = 120; TestTimeoutMs = 2000; NetshPath = $script:NetshPath }
        }

        $script:Guid11 = '{3AFF3E1C-0B7C-47F2-BAE1-C15EF560CCE3}'
        $script:Guid2 = '{017DB546-23F0-4526-8225-DE26189CF4E9}'
        $script:Guid21 = '{E54E2A63-0E58-4493-8A11-B6624093F6FC}'
        function Initialize-FakeNetwork {
            $script:Fake = @{
                Admin        = $true
                FailDns      = $false
                FailRegister = $false
                RenewCode    = 0
                Tcp          = @()
                Tasks        = [System.Collections.Generic.List[object]]::new()
                Adapters     = @{
                    11 = @{ Index = 11; Guid = $script:Guid11; Name = 'Ethernet'; Description = 'Karta testowa USB'; Status = 'Up'; Virtual = $false; IPv4 = '192.168.10.17'; Gateway = '192.168.10.1'; Dhcp = $true; HasIPv6 = $true; DhcpDns = @('192.168.10.1'); Static4 = @(); Static6 = @() }
                    2  = @{ Index = 2; Guid = $script:Guid2; Name = 'Wi-Fi'; Description = 'Karta bezprzewodowa'; Status = 'Up'; Virtual = $false; IPv4 = '192.168.50.15'; Gateway = '192.168.50.1'; Dhcp = $false; HasIPv6 = $false; DhcpDns = @(); Static4 = @('192.168.50.1'); Static6 = @() }
                    21 = @{ Index = 21; Guid = $script:Guid21; Name = 'Ethernet 2'; Description = 'Karta wyłączona'; Status = 'Disabled'; Virtual = $false; IPv4 = ''; Gateway = ''; Dhcp = $true; HasIPv6 = $true; DhcpDns = @(); Static4 = @(); Static6 = @() }
                }
            }
            $script:Calls = [System.Collections.Generic.List[string]]::new()
        }
        Initialize-FakeNetwork
        function Get-Call {
            param([string] $Pattern)
            @($script:Calls | Where-Object { $_ -like $Pattern })
        }
        function Get-FakeAdapter {
            param($Index)
            $script:Fake.Adapters[[int]@($Index)[0]]
        }

        Mock -ModuleName MWP.Network Test-MwpAdmin { $script:Fake.Admin }
        Mock -ModuleName MWP.Remote Get-NetAdapter {
            $index = $PesterBoundParameters['InterfaceIndex']
            $list = foreach ($key in @($script:Fake.Adapters.Keys | Sort-Object)) {
                $a = $script:Fake.Adapters[$key]
                [pscustomobject]@{
                    InterfaceIndex = $a.Index; InterfaceGuid = $a.Guid; Name = $a.Name; InterfaceDescription = $a.Description; Status = $a.Status
                    MacAddress = '00-11-22-33-44-55'; LinkSpeed = '1 Gbps'; MediaType = '802.3'; Virtual = $a.Virtual; HardwareInterface = -not $a.Virtual
                }
            }
            if ($null -ne $index) {
                $found = @($list | Where-Object { @($index) -contains $_.InterfaceIndex })
                if ($found.Count -eq 0) { throw ('No MSFT_NetAdapter objects found with InterfaceIndex {0}.' -f @($index)[0]) }
                return $found
            }
            $list
        }
        Mock -ModuleName MWP.Remote Get-NetIPAddress {
            $index = $PesterBoundParameters['InterfaceIndex']
            $family = $PesterBoundParameters['AddressFamily']
            foreach ($a in $script:Fake.Adapters.Values) {
                if ($a.Status -eq 'Disabled' -or ($null -ne $index -and @($index) -notcontains $a.Index)) { continue }
                if ($a.IPv4 -and ($null -eq $family -or [string]@($family)[0] -eq 'IPv4')) {
                    [pscustomobject]@{ InterfaceIndex = $a.Index; IPAddress = $a.IPv4; PrefixLength = 24; AddressFamily = 'IPv4' }
                }
                if ($a.HasIPv6 -and ($null -eq $family -or [string]@($family)[0] -eq 'IPv6')) {
                    [pscustomobject]@{ InterfaceIndex = $a.Index; IPAddress = ('fe80::{0}' -f $a.Index); PrefixLength = 64; AddressFamily = 'IPv6' }
                }
            }
        }
        Mock -ModuleName MWP.Remote Get-NetRoute {
            foreach ($a in $script:Fake.Adapters.Values) {
                if ($a.Gateway -and $a.Status -ne 'Disabled') {
                    [pscustomobject]@{ InterfaceIndex = $a.Index; NextHop = $a.Gateway; RouteMetric = $a.Index; DestinationPrefix = '0.0.0.0/0' }
                }
            }
        }
        Mock -ModuleName MWP.Remote Get-DnsClientServerAddress {
            foreach ($a in $script:Fake.Adapters.Values) {
                $v4 = if (@($a.Static4).Count -gt 0) { @($a.Static4) } else { @($a.DhcpDns) }
                [pscustomobject]@{ InterfaceIndex = $a.Index; AddressFamily = 2; ServerAddresses = $v4 }
                if ($a.HasIPv6) { [pscustomobject]@{ InterfaceIndex = $a.Index; AddressFamily = 23; ServerAddresses = @($a.Static6) } }
            }
        }
        Mock -ModuleName MWP.Remote Get-NetIPInterface {
            $index = $PesterBoundParameters['InterfaceIndex']
            foreach ($a in $script:Fake.Adapters.Values) {
                if ($null -ne $index -and @($index) -notcontains $a.Index) { continue }
                [pscustomobject]@{ InterfaceIndex = $a.Index; AddressFamily = 'IPv4'; Dhcp = $(if ($a.Dhcp) { 'Enabled' } else { 'Disabled' }) }
                if ($a.HasIPv6) { [pscustomobject]@{ InterfaceIndex = $a.Index; AddressFamily = 'IPv6'; Dhcp = 'Enabled' } }
            }
        }
        Mock -ModuleName MWP.Remote Get-NetConnectionProfile {
            foreach ($a in $script:Fake.Adapters.Values) {
                if ($a.Status -eq 'Up') { [pscustomobject]@{ InterfaceIndex = $a.Index; Name = 'Sieć testowa'; NetworkCategory = 'Private'; IPv4Connectivity = 'Internet' } }
            }
        }
        Mock -ModuleName MWP.Remote Get-CimInstance {
            foreach ($a in $script:Fake.Adapters.Values) {
                [pscustomobject]@{
                    InterfaceIndex = $a.Index; DHCPEnabled = $a.Dhcp; DHCPServer = $(if ($a.Dhcp) { $a.Gateway } else { '' })
                    DHCPLeaseObtained = $(if ($a.Dhcp) { [datetime]'2026-10-28T08:00:00' } else { $null }); DHCPLeaseExpires = $(if ($a.Dhcp) { [datetime]'2026-10-28T20:00:00' } else { $null })
                }
            }
        }
        Mock -ModuleName MWP.Remote Get-NetTCPConnection { @($script:Fake.Tcp) }
        Mock -ModuleName MWP.Remote Get-ItemProperty {
            $path = [string]$PesterBoundParameters['LiteralPath']
            if ($path -notmatch 'Services\\(Tcpip6?)\\Parameters\\Interfaces\\(\{[^}]+\})') { throw ('Nieoczekiwana ścieżka: ' + $path) }
            $service = $Matches[1]
            $guid = $Matches[2]
            $a = @($script:Fake.Adapters.Values | Where-Object { $_.Guid -eq $guid }) | Select-Object -First 1
            if ($null -eq $a) { throw 'Brak klucza.' }
            [pscustomobject]@{ NameServer = $(if ($service -eq 'Tcpip') { @($a.Static4) -join ',' } else { @($a.Static6) -join ',' }) }
        }
        Mock -ModuleName MWP.Remote Set-DnsClientServerAddress {
            $a = Get-FakeAdapter $PesterBoundParameters['InterfaceIndex']
            if ($PesterBoundParameters['ResetServerAddresses']) {
                $script:Calls.Add(('ResetDns {0}' -f $a.Index))
                $a.Static4 = @()
                $a.Static6 = @()
                return
            }
            if ($script:Fake.FailDns) { $script:Fake.FailDns = $false; throw 'Błąd testowy zapisu DNS.' }
            $servers = @($PesterBoundParameters['ServerAddresses'])
            $script:Calls.Add(('SetDns {0} {1}' -f $a.Index, ($servers -join ',')))
            $a.Static4 = @($servers | Where-Object { $_ -notmatch ':' })
            $a.Static6 = @($servers | Where-Object { $_ -match ':' })
        }
        Mock -ModuleName MWP.Remote Clear-DnsClientCache { $script:Calls.Add('Flush') }
        Mock -ModuleName MWP.Remote Disable-NetAdapter {
            foreach ($item in @($PesterBoundParameters['InputObject'])) {
                $script:Calls.Add(('Disable {0}' -f $item.InterfaceIndex))
                (Get-FakeAdapter $item.InterfaceIndex).Status = 'Disabled'
            }
        } -RemoveParameterType InputObject
        Mock -ModuleName MWP.Remote Enable-NetAdapter {
            foreach ($item in @($PesterBoundParameters['InputObject'])) {
                $script:Calls.Add(('Enable {0}' -f $item.InterfaceIndex))
                (Get-FakeAdapter $item.InterfaceIndex).Status = 'Up'
            }
        } -RemoveParameterType InputObject
        Mock -ModuleName MWP.Remote Invoke-CimMethod {
            $script:Calls.Add(('Renew {0}' -f $PesterBoundParameters['InputObject'].InterfaceIndex))
            [pscustomobject]@{ ReturnValue = $script:Fake.RenewCode }
        } -RemoveParameterType InputObject
        Mock -ModuleName MWP.Remote Resolve-DnsName {
            $name = [string]$PesterBoundParameters['Name']
            if ($name -like '*.invalid') { throw ('{0} : nie znaleziono nazwy DNS' -f $name) }
            @([pscustomobject]@{ Name = $name; IPAddress = '93.184.216.34' })
        }
        Mock -ModuleName MWP.Remote New-ScheduledTaskAction { [pscustomobject]@{ Execute = $PesterBoundParameters['Execute']; Arguments = $PesterBoundParameters['Argument'] } }
        Mock -ModuleName MWP.Remote New-ScheduledTaskTrigger { [pscustomobject]@{ StartBoundary = ([datetime]$PesterBoundParameters['At']).ToString('s') } }
        Mock -ModuleName MWP.Remote New-ScheduledTaskPrincipal { [pscustomobject]@{ UserId = $PesterBoundParameters['UserId']; RunLevel = [string]$PesterBoundParameters['RunLevel'] } }
        Mock -ModuleName MWP.Remote New-ScheduledTaskSettingsSet { [pscustomobject]@{ StartWhenAvailable = [bool]$PesterBoundParameters['StartWhenAvailable'] } }
        Mock -ModuleName MWP.Remote New-ScheduledTask {
            [pscustomobject]@{ Actions = @($PesterBoundParameters['Action']); Triggers = @($PesterBoundParameters['Trigger']); Principal = $PesterBoundParameters['Principal']; Description = $PesterBoundParameters['Description'] }
        } -RemoveParameterType Action, Trigger, Principal, Settings
        Mock -ModuleName MWP.Remote Register-ScheduledTask {
            if ($script:Fake.FailRegister) { throw 'Odmowa dostępu (harmonogram).' }
            $definition = $PesterBoundParameters['InputObject']
            $script:Calls.Add(('Register {0}' -f $PesterBoundParameters['TaskName']))
            $script:Fake.Tasks.Add([pscustomobject]@{
                    TaskName = [string]$PesterBoundParameters['TaskName']; TaskPath = [string]$PesterBoundParameters['TaskPath']; State = 'Ready'
                    Description = $definition.Description; Actions = $definition.Actions; Triggers = $definition.Triggers; Principal = $definition.Principal
                })
        } -RemoveParameterType InputObject
        Mock -ModuleName MWP.Remote Get-ScheduledTask {
            $path = [string]$PesterBoundParameters['TaskPath']
            $name = [string]$PesterBoundParameters['TaskName']
            @($script:Fake.Tasks | Where-Object { $_.TaskPath -eq $path -and (-not $name -or $_.TaskName -eq $name) })
        }
        Mock -ModuleName MWP.Remote Unregister-ScheduledTask {
            $name = [string]$PesterBoundParameters['TaskName']
            $script:Calls.Add(('Unregister {0}' -f $name))
            $task = @($script:Fake.Tasks | Where-Object { $_.TaskName -eq $name }) | Select-Object -First 1
            if ($null -ne $task) { $null = $script:Fake.Tasks.Remove($task) }
        }

        # Blok wycofania z argumentów zarejestrowanego zadania (jak uruchomiłby go harmonogram po limicie czasu).
        function Invoke-FakeRollback {
            param([string] $ChangeId)
            $task = @($script:Fake.Tasks | Where-Object { $_.TaskName -like ('*' + $ChangeId) }) | Select-Object -First 1
            $null = ([string]@($task.Actions)[0].Arguments) -match '-EncodedCommand\s+([A-Za-z0-9+/=]+)'
            $text = [Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($Matches[1]))
            & ((Get-Module -Name MWP.Remote).NewBoundScriptBlock([scriptblock]::Create($text)))
        }
        function Get-NetworkUndo {
            param([string] $ComputerName = 'localhost')
            @(Get-MwpUndoEntry -ComputerName $ComputerName -Status Pending | Where-Object { $_.Module -eq 'MWP.Network' } | Sort-Object -Property CreatedAt -Descending)
        }
    }

    BeforeEach {
        Initialize-FakeNetwork
        $script:NetshPath = $script:NetshOk
        Remove-Item -Path (Join-Path -Path $TestDrive -ChildPath 'Undo\*') -Force -ErrorAction SilentlyContinue
    }

    AfterAll {
        Remove-Module -Name MWP.Network, MWP.Remote, MWP.Core -Force -ErrorAction SilentlyContinue
    }

    Context 'stan sieci' {
        It 'adaptery z adresami, bramą, DNS (statyczny albo DHCP), dzierżawą i profilem; połączone na początku' {
            $result = Get-MwpNetworkStatus
            $result.Success | Should -BeTrue -Because $result.Message
            $status = $result.Data
            $status.PSObject.TypeNames | Should -Contain 'MWP.NetworkStatus'
            @($status.Adapters).Count | Should -Be 3
            $status.Adapters[-1].Name | Should -Be 'Ethernet 2'
            $ethernet = @($status.Adapters | Where-Object { $_.InterfaceIndex -eq 11 })[0]
            $ethernet.StatusText | Should -Be 'Połączony'
            $ethernet.IPv4Text | Should -Be '192.168.10.17/24'
            $ethernet.GatewayText | Should -Be '192.168.10.1'
            $ethernet.DnsMode | Should -Be 'Dhcp'
            $ethernet.DnsText | Should -Be 'automatycznie (DHCP)'
            $ethernet.DnsServersText | Should -Match '192\.168\.10\.1'
            $ethernet.DhcpEnabled | Should -BeTrue
            $ethernet.LeaseExpires | Should -BeOfType [datetime]
            $ethernet.CategoryText | Should -Be 'Prywatna'
            $ethernet.IsConnectionAdapter | Should -BeFalse
            $wifi = @($status.Adapters | Where-Object { $_.InterfaceIndex -eq 2 })[0]
            $wifi.DnsMode | Should -Be 'Static'
            $wifi.DnsText | Should -Be '192.168.50.1'
            $wifi.HasIPv6 | Should -BeFalse
            @($status.Adapters | Where-Object { $_.InterfaceIndex -eq 21 })[0].IsEnabled | Should -BeFalse
            @($status.Pending).Count | Should -Be 0
        }

        It '-AsOperation zwraca operację w tle; Resolve-MwpNetworkStatus czyta surowy JSON i przepuszcza gotowy stan' {
            $operation = Get-MwpNetworkStatus -AsOperation
            $operation.PSObject.TypeNames | Should -Contain 'MWP.Operation'
            $null = Stop-MwpOperation -Operation $operation
            $raw = InModuleScope MWP.Remote -Parameters @{ Block = (InModuleScope MWP.Network { Get-MwpNetworkScript -Name Status }) } {
                param($Block)
                & ((Get-Module -Name MWP.Remote).NewBoundScriptBlock($Block)) '{"ConnectionPort":0,"TaskPath":"\\MyWindowsPower\\","TaskPrefix":"MWP-NetworkRollback-"}'
            }
            $status = Resolve-MwpNetworkStatus -Data $raw
            @($status.Adapters).Count | Should -Be 3
            Resolve-MwpNetworkStatus -Data $status | Should -Be $status
            Resolve-MwpNetworkStatus -Data 'to nie jest JSON' | Should -BeNullOrEmpty
        }

        It 'presety DNS: DHCP bez serwerów, Cloudflare, Google i Quad9 z IPv4 i IPv6' {
            $presets = @(Get-MwpDnsPreset)
            @($presets.Name) | Should -Be @('Dhcp', 'Cloudflare', 'Google', 'Quad9')
            (Get-MwpDnsPreset -Name Dhcp).ServersText | Should -Be 'automatycznie (DHCP)'
            (Get-MwpDnsPreset -Name Cloudflare).Servers | Should -Contain '1.1.1.1'
            (Get-MwpDnsPreset -Name Google).Servers | Should -Contain '8.8.8.8'
            (Get-MwpDnsPreset -Name Quad9).Servers | Should -Contain '2620:fe::fe'
        }
    }

    Context 'widget Dashboardu (D-053)' {
        It 'widok „Sieć”: domyślnie tylko połączone adaptery z IPv4; szczegóły i wszystkie adaptery z parametrów' {
            $data = (Get-MwpNetworkStatus).Data
            $connected = @($data.Adapters | Where-Object { $_.Status -eq 'Up' })
            $view = ConvertTo-MwpNetworkStatusView -Data $data
            $view.PSObject.TypeNames | Should -Contain 'MWP.WidgetView'
            @($view.Sections).Count | Should -Be $connected.Count
            @($view.Sections[0].Items | ForEach-Object Label) | Should -Be @('Stan', 'IPv4')
            $full = ConvertTo-MwpNetworkStatusView -Data $data -WidgetParameters @{ OnlyConnected = $false; Details = @('IPv4', 'Gateway', 'Dns', 'Dhcp', 'IPv6') }
            @($full.Sections).Count | Should -Be @($data.Adapters).Count
            @($full.Sections[0].Items | ForEach-Object Label) | Should -Be @('Stan', 'IPv4', 'Brama', 'DNS', 'Adres IP', 'IPv6')
            ConvertTo-MwpNetworkStatusView -Data $null | Should -BeNullOrEmpty
            ConvertTo-MwpNetworkStatusView -Data 'to nie jest JSON' | Should -BeNullOrEmpty
        }

        It 'funkcja danych przyjmuje -WidgetParameters (kontrakt widgetu)' {
            Mock -ModuleName MWP.Network Start-MwpOperation { [pscustomobject]@{ PSTypeName = 'MWP.Operation'; Operation = $Operation } }
            (Get-MwpNetworkStatus -AsOperation -WidgetParameters @{ OnlyConnected = $true }).Operation | Should -Be 'Network.Status'
        }
    }

    Context 'zmiana DNS z cofaniem i automatycznym wycofaniem' {
        It '-WhatIf: podgląd przed i po z informacją o wycofaniu; nic nie zmienia i nie rejestruje zadania' {
            $result = Set-MwpDnsServer -InterfaceIndex 11 -Preset Cloudflare -WhatIf
            $result.Success | Should -BeTrue -Because $result.Message
            $result.IsPreview | Should -BeTrue
            $result.Changed | Should -BeFalse
            $result.Before | Should -Be 'automatycznie (DHCP)'
            $result.After | Should -Be '1.1.1.1, 1.0.0.1, 2606:4700:4700::1111, 2606:4700:4700::1001'
            $result.Message | Should -Match '120 s'
            Get-Call 'SetDns*' | Should -BeNullOrEmpty
            Get-Call 'Register*' | Should -BeNullOrEmpty
            @(Get-NetworkUndo).Count | Should -Be 0
        }

        It 'brak administratora na komputerze docelowym: odmowa przed podglądem (12)' {
            $script:Fake.Admin = $false
            $result = Set-MwpDnsServer -InterfaceIndex 11 -Preset Google -WhatIf
            $result.Success | Should -BeFalse
            $result.IsPreview | Should -BeFalse
            $result.Message | Should -Match 'administratora'
            Get-Call 'SetDns*' | Should -BeNullOrEmpty
        }

        It 'niepoprawne adresy i nieistniejący adapter są odrzucane' {
            (Set-MwpDnsServer -InterfaceIndex 11 -ServerAddress '1.1.1', '8.8.8.8' -WhatIf).Message | Should -Match 'nie jest adresem IP'
            (Set-MwpDnsServer -InterfaceIndex 11 -ServerAddress '255.255.255.255' -WhatIf).Message | Should -Match 'nie może być serwerem DNS'
            (Set-MwpDnsServer -InterfaceIndex 11 -ServerAddress '0.0.0.0' -WhatIf).Success | Should -BeFalse
            { Set-MwpDnsServer -InterfaceIndex 11 -ServerAddress ('1.1.1.1;calc' -split ' ') -RollbackSeconds 10 -WhatIf } | Should -Throw
            (Set-MwpDnsServer -InterfaceIndex 99 -Preset Google -WhatIf).Message | Should -Match 'indeksie 99'
            (Set-MwpDnsServer -InterfaceIndex 11 -InterfaceGuid $script:Guid2 -Preset Google -WhatIf).Message | Should -Match 'inny identyfikator'
        }

        It 'zmiana: najpierw zadanie wycofania, potem reset i lista; wynik z ChangeId i terminem, wpis cofnięcia (DHCP) i log' {
            $result = Set-MwpDnsServer -InterfaceIndex 11 -Preset Quad9 -Confirm:$false
            $result.Success | Should -BeTrue -Because $result.Message
            $result.Changed | Should -BeTrue
            $result.After | Should -Be '9.9.9.9, 149.112.112.112, 2620:fe::fe, 2620:fe::9'
            $result.Data.RollbackPending | Should -BeTrue
            $result.Data.ChangeId | Should -Match '^[0-9a-f-]{36}$'
            $result.Data.Deadline | Should -BeOfType [datetime]
            $result.Data.RemainingSeconds | Should -BeGreaterThan 100
            $result.Message | Should -Match 'Approve-MwpNetworkChange'
            $script:Calls.IndexOf(@(Get-Call 'Register*')[0]) | Should -BeLessThan $script:Calls.IndexOf(@(Get-Call 'ResetDns 11')[0])
            Get-Call 'Flush' | Should -Not -BeNullOrEmpty
            $task = $script:Fake.Tasks[0]
            $task.TaskPath | Should -Be '\MyWindowsPower\'
            $task.TaskName | Should -Be ('MWP-NetworkRollback-' + $result.Data.ChangeId)
            $task.Principal.UserId | Should -Be 'SYSTEM'
            @($task.Actions)[0].Execute | Should -Match 'WindowsPowerShell\\v1\.0\\powershell\.exe$'
            @($task.Actions)[0].Arguments | Should -Match '^-NoProfile -NonInteractive -EncodedCommand [A-Za-z0-9+/=]+$'
            $undo = @(Get-NetworkUndo)[0]
            $undo.UndoCommand | Should -Be 'Set-MwpDnsServer'
            $undo.UndoParameters['Preset'] | Should -Be 'Dhcp'
            $undo.UndoParameters['RollbackSeconds'] | Should -Be 0
            $undo.UndoParameters['InterfaceGuid'] | Should -Be $script:Guid11
            $result.UndoId | Should -Be $undo.Id
            $log = Get-Content -Raw -Encoding UTF8 -Path (Join-Path -Path $TestDrive -ChildPath 'Logs\*.log')
            $log | Should -Match 'Network\.SetDns'
        }

        It 'stan oczekujący widać w odczycie; druga zmiana na tym adapterze jest odrzucona do zatwierdzenia' {
            $first = Set-MwpDnsServer -InterfaceIndex 11 -Preset Google -Confirm:$false
            $pending = @((Get-MwpNetworkStatus).Data.Pending)
            $pending.Count | Should -Be 1
            $pending[0].ChangeId | Should -Be $first.Data.ChangeId
            $pending[0].Kind | Should -Be 'Dns'
            $pending[0].InterfaceIndex | Should -Be 11
            $pending[0].AdapterName | Should -Be 'Ethernet'
            $pending[0].RemainingSeconds | Should -BeGreaterThan 100
            $second = Set-MwpDnsServer -InterfaceIndex 11 -Preset Quad9 -Confirm:$false
            $second.Success | Should -BeFalse
            $second.Message | Should -Match 'czeka na zatwierdzenie'
            (Set-MwpDnsServer -InterfaceIndex 2 -Preset Quad9 -WhatIf).Success | Should -BeTrue
        }

        It 'zatwierdzenie usuwa zadanie; ponowne zatwierdzenie — bez zmian z wyjaśnieniem' {
            $change = Set-MwpDnsServer -InterfaceIndex 11 -Preset Google -Confirm:$false
            (Approve-MwpNetworkChange -ChangeId $change.Data.ChangeId -WhatIf).IsPreview | Should -BeTrue
            $script:Fake.Tasks.Count | Should -Be 1
            $approve = Approve-MwpNetworkChange -ChangeId $change.Data.ChangeId -Confirm:$false
            $approve.Success | Should -BeTrue -Because $approve.Message
            $approve.Changed | Should -BeTrue
            $script:Fake.Tasks.Count | Should -Be 0
            (Get-FakeAdapter 11).Static4 | Should -Contain '8.8.8.8'
            $again = Approve-MwpNetworkChange -ChangeId $change.Data.ChangeId -Confirm:$false
            $again.Success | Should -BeTrue
            $again.Changed | Should -BeFalse
            $again.Message | Should -Match 'nie czeka na zatwierdzenie'
        }

        It 'kryterium bezpieczeństwa: bez zatwierdzenia zadanie przywraca poprzednie DNS (statyczne) i samo się usuwa' {
            $wifi = Get-FakeAdapter 2
            $change = Set-MwpDnsServer -InterfaceIndex 2 -ServerAddress '1.1.1.1', '2606:4700:4700::1111' -Confirm:$false
            $change.Success | Should -BeTrue -Because $change.Message
            $change.After | Should -Be '1.1.1.1'
            $wifi.Static4 | Should -Be @('1.1.1.1')
            Invoke-FakeRollback -ChangeId $change.Data.ChangeId
            $wifi.Static4 | Should -Be @('192.168.50.1')
            $script:Fake.Tasks.Count | Should -Be 0
            Get-Call 'Unregister*' | Should -Not -BeNullOrEmpty
        }

        It 'cofnięcie jednym wywołaniem (Invoke-MwpUndo) przywraca DHCP bez nowego zadania wycofania' {
            $change = Set-MwpDnsServer -InterfaceIndex 11 -Preset Cloudflare -Confirm:$false
            $null = Approve-MwpNetworkChange -ChangeId $change.Data.ChangeId -Confirm:$false
            $script:Calls.Clear()
            $undo = Invoke-MwpUndo -Id $change.UndoId -Confirm:$false
            $undo.Success | Should -BeTrue -Because $undo.Message
            (Get-FakeAdapter 11).Static4 | Should -BeNullOrEmpty
            (Get-FakeAdapter 11).Static6 | Should -BeNullOrEmpty
            Get-Call 'Register*' | Should -BeNullOrEmpty
            (Get-MwpUndoEntry -Id $change.UndoId).Status | Should -Be 'Undone'
        }

        It 'błąd zapisu DNS: zmiana wycofana od razu tym samym blokiem, zadanie usunięte, bez wpisu cofnięcia' {
            $script:Fake.FailDns = $true
            $result = Set-MwpDnsServer -InterfaceIndex 2 -Preset Google -Confirm:$false
            $result.Success | Should -BeFalse
            $result.Message | Should -Match 'Błąd testowy'
            $result.Message | Should -Match 'przywrócony'
            (Get-FakeAdapter 2).Static4 | Should -Be @('192.168.50.1')
            $script:Fake.Tasks.Count | Should -Be 0
            @(Get-NetworkUndo).Count | Should -Be 0
        }

        It 'błąd rejestracji zadania wycofania: zmiana nie jest wykonywana' {
            $script:Fake.FailRegister = $true
            $result = Set-MwpDnsServer -InterfaceIndex 11 -Preset Google -Confirm:$false
            $result.Success | Should -BeFalse
            $result.Message | Should -Match 'harmonogram'
            Get-Call 'ResetDns*' | Should -BeNullOrEmpty
        }

        It 'adresy IPv6 pomijane na adapterze bez IPv6; ten sam stan = bez zmiany; -RollbackSeconds 0 bez zadania' {
            (Set-MwpDnsServer -InterfaceIndex 2 -ServerAddress '2620:fe::fe' -WhatIf).Message | Should -Match 'IPv6'
            $same = Set-MwpDnsServer -InterfaceIndex 2 -ServerAddress '192.168.50.1' -Confirm:$false
            $same.Success | Should -BeTrue
            $same.Changed | Should -BeFalse
            Get-Call 'ResetDns*' | Should -BeNullOrEmpty
            $result = Set-MwpDnsServer -InterfaceIndex 11 -ServerAddress '9.9.9.9' -RollbackSeconds 0 -Confirm:$false
            $result.Success | Should -BeTrue -Because $result.Message
            $result.Data.RollbackPending | Should -BeFalse
            $script:Fake.Tasks.Count | Should -Be 0
        }
    }

    Context 'adaptery: wyłączenie i włączenie' {
        It 'wyłączenie: ConfirmImpact High, podgląd, zadanie włączenia, wpis cofnięcia; bez zatwierdzenia adapter wraca' {
            (Get-Command -Name Disable-MwpNetAdapter).ScriptBlock.Attributes.Where({ $_ -is [System.Management.Automation.CmdletBindingAttribute] })[0].ConfirmImpact | Should -Be 'High'
            $preview = Disable-MwpNetAdapter -InterfaceIndex 2 -WhatIf
            $preview.IsPreview | Should -BeTrue
            $preview.Message | Should -Match 'włączy adapter ponownie'
            Get-Call 'Disable*' | Should -BeNullOrEmpty
            $result = Disable-MwpNetAdapter -InterfaceIndex 2 -Confirm:$false
            $result.Success | Should -BeTrue -Because $result.Message
            $result.Before | Should -Be 'Połączony'
            $result.After | Should -Be 'Wyłączony'
            (Get-FakeAdapter 2).Status | Should -Be 'Disabled'
            @(Get-NetworkUndo)[0].UndoCommand | Should -Be 'Enable-MwpNetAdapter'
            Invoke-FakeRollback -ChangeId $result.Data.ChangeId
            (Get-FakeAdapter 2).Status | Should -Be 'Up'
            $script:Fake.Tasks.Count | Should -Be 0
        }

        It 'włączenie: już włączony — bez zmian; wyłączony — włączenie bez zadania wycofania, cofnięcie = wyłączenie' {
            (Enable-MwpNetAdapter -InterfaceIndex 11 -Confirm:$false).Changed | Should -BeFalse
            $result = Enable-MwpNetAdapter -InterfaceIndex 21 -Confirm:$false
            $result.Success | Should -BeTrue -Because $result.Message
            $result.Changed | Should -BeTrue
            (Get-FakeAdapter 21).Status | Should -Be 'Up'
            Get-Call 'Register*' | Should -BeNullOrEmpty
            $undo = @(Get-NetworkUndo)[0]
            $undo.UndoCommand | Should -Be 'Disable-MwpNetAdapter'
            $undo.UndoParameters['RollbackSeconds'] | Should -Be 0
            (Disable-MwpNetAdapter -InterfaceIndex 21 -WhatIf).IsPreview | Should -BeTrue
            (Disable-MwpNetAdapter -InterfaceIndex 11 -RollbackSeconds 0 -Confirm:$false).Success | Should -BeTrue
            (Disable-MwpNetAdapter -InterfaceIndex 11 -Confirm:$false).Message | Should -Match 'już jest wyłączony'
        }
    }

    Context 'pamięć DNS, DHCP i resety' {
        It 'flush DNS: podgląd bez wywołania, potem Clear-DnsClientCache i log' {
            (Clear-MwpDnsCache -WhatIf).IsPreview | Should -BeTrue
            Get-Call 'Flush' | Should -BeNullOrEmpty
            $result = Clear-MwpDnsCache -Confirm:$false
            $result.Success | Should -BeTrue
            $result.Changed | Should -BeTrue
            Get-Call 'Flush' | Should -Not -BeNullOrEmpty
        }

        It 'odnowienie DHCP: adapter statyczny odrzucony, DHCP odnowiony, błąd kodu wyniku zgłoszony' {
            (Update-MwpDhcpLease -InterfaceIndex 2 -WhatIf).Message | Should -Match 'statyczny'
            (Update-MwpDhcpLease -InterfaceIndex 21 -WhatIf).Message | Should -Match 'nie jest połączony'
            (Update-MwpDhcpLease -InterfaceIndex 11 -WhatIf).IsPreview | Should -BeTrue
            Get-Call 'Renew*' | Should -BeNullOrEmpty
            $result = Update-MwpDhcpLease -InterfaceIndex 11 -Confirm:$false
            $result.Success | Should -BeTrue -Because $result.Message
            $result.After | Should -Be '192.168.10.17/24'
            Get-Call 'Renew 11' | Should -Not -BeNullOrEmpty
            $script:Fake.RenewCode = 2147786788
            (Update-MwpDhcpLease -InterfaceIndex 11 -Confirm:$false).Message | Should -Match 'kod wyniku 2147786788'
        }

        It 'resety: ConfirmImpact High, podgląd z restartem i statycznymi adresami, administrator, netsh ze stałymi argumentami' {
            foreach ($command in 'Reset-MwpNetworkStack') {
                (Get-Command -Name $command).ScriptBlock.Attributes.Where({ $_ -is [System.Management.Automation.CmdletBindingAttribute] })[0].ConfirmImpact | Should -Be 'High'
            }
            $preview = Reset-MwpNetworkStack -Component IP -WhatIf
            $preview.IsPreview | Should -BeTrue
            $preview.RestartRequired | Should -BeTrue
            $preview.Message | Should -Match 'Wi-Fi \(192\.168\.50\.15/24\)'
            Test-Path -LiteralPath $script:NetshArgs | Should -BeFalse
            $result = Reset-MwpNetworkStack -Component Winsock -Confirm:$false
            $result.Success | Should -BeTrue -Because $result.Message
            $result.RestartRequired | Should -BeTrue
            (Get-Content -LiteralPath $script:NetshArgs -Raw).Trim() | Should -Be 'winsock reset'
            $null = Reset-MwpNetworkStack -Component IP -Confirm:$false
            (Get-Content -LiteralPath $script:NetshArgs -Raw).Trim() | Should -Be 'int ip reset'
            $script:NetshPath = $script:NetshFail
            $failed = Reset-MwpNetworkStack -Component Winsock -Confirm:$false
            $failed.Success | Should -BeFalse
            $failed.Message | Should -Match 'kod wyjścia netsh 1'
            $script:Fake.Admin = $false
            (Reset-MwpNetworkStack -Component Winsock -WhatIf).Message | Should -Match 'administratora'
        }
    }

    Context 'testy łączności' {
        BeforeEach {
            (Get-FakeAdapter 11).Gateway = '127.0.0.1'
            (Get-FakeAdapter 2).Gateway = ''
        }

        It 'ping bramy, nazwa DNS i otwarty port; zamknięty port i nieznana nazwa jako błąd' {
            $listener = New-Object -TypeName Net.Sockets.TcpListener -ArgumentList ([Net.IPAddress]::Loopback, 0)
            $listener.Start()
            $closed = New-Object -TypeName Net.Sockets.TcpListener -ArgumentList ([Net.IPAddress]::Loopback, 0)
            $closed.Start()
            $closedPort = $closed.LocalEndpoint.Port
            $closed.Stop()
            try {
                $port = $listener.LocalEndpoint.Port
                $result = Test-MwpNetworkConnection -ExternalHost '127.0.0.1' -DnsName 'example.org' -PortHost '127.0.0.1' -Port $port
                $result.Success | Should -BeTrue -Because $result.Message
                $tests = @($result.Data.Tests)
                @($tests.Name) | Should -Be @('Gateway', 'External', 'Dns', 'Port')
                ($tests | Where-Object Name -EQ 'Gateway').Target | Should -Be '127.0.0.1'
                @($tests | Where-Object { -not $_.Success }).Count | Should -Be 0 -Because (($tests | ForEach-Object { '{0}: {1}' -f $_.Name, $_.Detail }) -join '; ')
                $result.Data.Summary | Should -Be '4 z 4 testów zaliczonych.'
                $bad = Test-MwpNetworkConnection -ExternalHost '' -DnsName 'brak.invalid' -PortHost '127.0.0.1' -Port $closedPort
                $bad.Data.Success | Should -BeFalse
                ($bad.Data.Tests | Where-Object Name -EQ 'Dns').ResultText | Should -Be 'Błąd'
                ($bad.Data.Tests | Where-Object Name -EQ 'Port').Success | Should -BeFalse
            }
            finally {
                $listener.Stop()
            }
        }

        It 'niepoprawne nazwy i port bez hosta są odrzucane przed wysłaniem; -AsOperation daje operację' {
            (Test-MwpNetworkConnection -DnsName 'a b;calc').Message | Should -Match 'Niepoprawna wartość'
            (Test-MwpNetworkConnection -PortHost 'host' -Port 0).Message | Should -Match 'hosta i portu'
            { Test-MwpNetworkConnection -Port 70000 } | Should -Throw
            $operation = Test-MwpNetworkConnection -ExternalHost '' -DnsName '' -AsOperation
            $operation.PSObject.TypeNames | Should -Contain 'MWP.Operation'
            $null = Stop-MwpOperation -Operation $operation
            Resolve-MwpNetworkTest -Data '{"Kind":"MWP.NetworkTestRaw","ComputerName":"PC","CollectedAt":"2026-10-28T10:00:00Z","Tests":[{"Name":"Dns","Target":"a","Success":false,"Detail":"x","DurationMs":5}]}' |
                ForEach-Object { $_.Summary } | Should -Be '0 z 1 testów zaliczonych.'
        }
    }

    Context 'komputer zdalny (D-019, D-049)' {
        BeforeEach {
            Mock -ModuleName MWP.Remote Remove-MwpPSSession { }
            Mock -ModuleName MWP.Remote New-MwpPSSession { [pscustomobject]@{ ComputerName = $ComputerName; State = 'Opened' } }
            Mock -ModuleName MWP.Remote Invoke-MwpSessionCommand {
                $bound = (Get-Module -Name MWP.Remote).NewBoundScriptBlock($ScriptBlock)
                [pscustomobject]@{ Output = @(& $bound @ArgumentList); Errors = @() }
            }
            Mock -ModuleName MWP.Remote Invoke-MwpSessionCommand -ParameterFilter { $ScriptBlock.ToString() -match 'IsInRole' -and $ScriptBlock.ToString() -notmatch 'RequestJson' } {
                [pscustomobject]@{ Output = @($script:Fake.Admin); Errors = @() }
            }
            # Połączenie WinRM idzie adapterem 11.
            $script:Fake.Tcp = @([pscustomobject]@{ LocalAddress = '192.168.10.17'; LocalPort = 5985; RemoteAddress = '192.168.10.5'; State = 'Established' })
            $remote = New-MwpExecutionContext -ComputerName $remoteName
        }

        It 'stan przez sesję: adapter połączenia rozpoznany po połączeniu TCP na porcie WinRM' {
            $result = Get-MwpNetworkStatus -Context $remote
            $result.Success | Should -BeTrue -Because $result.Message
            $result.ComputerName | Should -Be $remoteName
            @($result.Data.Adapters | Where-Object { $_.IsConnectionAdapter }).InterfaceIndex | Should -Be 11
            $result.Data.ConnectionAddresses | Should -Contain '192.168.10.17'
        }

        It 'brak administratora w sesji zdalnej: odmowa przed podglądem (12)' {
            $script:Fake.Admin = $false
            $result = Set-MwpDnsServer -InterfaceIndex 11 -Preset Google -Context $remote -WhatIf
            $result.Success | Should -BeFalse
            $result.Message | Should -Match $remoteName
        }

        It 'zmiana DNS adaptera połączenia: ostrzeżenie w podglądzie, zmiana z zadaniem i wpis cofnięcia z nazwą komputera' {
            $preview = Set-MwpDnsServer -InterfaceIndex 11 -Preset Google -Context $remote -WhatIf
            $preview.Message | Should -Match 'połączenie aplikacji'
            $result = Set-MwpDnsServer -InterfaceIndex 11 -Preset Google -Context $remote -Confirm:$false
            $result.Success | Should -BeTrue -Because $result.Message
            $result.ComputerName | Should -Be $remoteName
            @(Get-NetworkUndo -ComputerName $remoteName)[0].Id | Should -Be $result.UndoId
            (Approve-MwpNetworkChange -ChangeId $result.Data.ChangeId -Context $remote -Confirm:$false).Changed | Should -BeTrue
        }

        It 'wyłączenie adaptera połączenia wymaga -AllowConnectionAdapter; utrata połączenia = błąd tej instancji z terminem automatycznego włączenia' {
            $denied = Disable-MwpNetAdapter -InterfaceIndex 11 -Context $remote -WhatIf
            $denied.Success | Should -BeFalse
            $denied.Message | Should -Match 'AllowConnectionAdapter'
            (Disable-MwpNetAdapter -InterfaceIndex 11 -AllowConnectionAdapter -Context $remote -WhatIf).Message | Should -Match 'zostanie przerwane'
            # Blok wykonuje się (zadanie i wyłączenie), ale odpowiedź nie wraca — połączenie zerwane.
            Mock -ModuleName MWP.Remote Invoke-MwpSessionCommand -ParameterFilter { $ScriptBlock.ToString() -match 'RollbackTemplate' } {
                $bound = (Get-Module -Name MWP.Remote).NewBoundScriptBlock($ScriptBlock)
                $null = & $bound @ArgumentList
                throw (New-Object -TypeName Management.Automation.Remoting.PSRemotingTransportException -ArgumentList 'Połączenie zerwane')
            }
            $other = New-MwpExecutionContext
            $undoBefore = @(Get-NetworkUndo -ComputerName $remoteName).Count
            $result = Disable-MwpNetAdapter -InterfaceIndex 11 -AllowConnectionAdapter -Context $remote -Confirm:$false
            $result.Success | Should -BeFalse
            $result.Message | Should -Match 'wycofa ją sam'
            $result.Data.RollbackPending | Should -BeTrue
            $remote.Connection.State | Should -Be 'Disconnected'
            (Get-FakeAdapter 11).Status | Should -Be 'Disabled'
            @(Get-NetworkUndo -ComputerName $remoteName).Count | Should -Be $undoBefore
            $task = $script:Fake.Tasks[0]
            Invoke-FakeRollback -ChangeId ($task.TaskName -replace '^MWP-NetworkRollback-', '')
            (Get-FakeAdapter 11).Status | Should -Be 'Up'
            (Get-MwpNetworkStatus -Context $other).Success | Should -BeTrue
        }

        It 'resety są dostępne zdalnie z ostrzeżeniem o utracie łączności po restarcie' {
            $preview = Reset-MwpNetworkStack -Component IP -Context $remote -WhatIf
            $preview.IsPreview | Should -BeTrue
            $preview.Message | Should -Match 'Komputer zdalny może po restarcie stracić łączność'
            $preview.ComputerName | Should -Be $remoteName
        }
    }

    Context 'kontrakt modułu i bloki komputera docelowego' {
        It 'manifest deklaruje komputer zdalny, tryby widoku i zgodny kontrakt' {
            $definition = @(Get-MwpModuleDefinition | Where-Object { $_.Id -eq 'Network' })[0]
            $definition.IsValid | Should -BeTrue -Because ($definition.Errors -join '; ')
            $definition.Capabilities | Should -Contain 'RemoteTarget'
            $definition.Capabilities | Should -Contain 'Undo'
            $definition.SupportedPresentationModes | Should -Contain 'Embedded'
        }

        It 'bloki parsują się bez błędów i nie używają składni tylko z 7.x' {
            foreach ($name in 'Status', 'Change', 'Approve', 'FlushDns', 'RenewDhcp', 'ResetStack', 'Test') {
                $block = InModuleScope MWP.Network -Parameters @{ Name = $name } { param($Name) Get-MwpNetworkScript -Name $Name }
                $errors = $null
                $null = [Management.Automation.Language.Parser]::ParseInput($block.ToString(), [ref]$null, [ref]$errors)
                $errors | Should -BeNullOrEmpty -Because $name
                $block.ToString() | Should -Not -Match '\?\?|\?\.'
            }
        }

        It 'blok wycofania ze stanem parsuje się, a zakodowane polecenie mieści się w limicie argumentów zadania' {
            $template = InModuleScope MWP.Network { Get-MwpNetworkRollbackScript }
            $template | Should -Match '__MWP_STATE__'
            $state = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('{"Kind":"Dns","InterfaceIndex":11,"InterfaceGuid":"{A}","ServerAddresses":["1.1.1.1","2606:4700:4700::1111"],"TaskPath":"\\MyWindowsPower\\","TaskName":"MWP-NetworkRollback-x"}'))
            $text = $template.Replace('__MWP_STATE__', $state)
            $errors = $null
            $null = [Management.Automation.Language.Parser]::ParseInput($text, [ref]$null, [ref]$errors)
            $errors | Should -BeNullOrEmpty
            ('-NoProfile -NonInteractive -EncodedCommand ' + [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($text))).Length | Should -BeLessThan 8000
        }
    }
}
