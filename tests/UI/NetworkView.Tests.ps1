#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
    Testy logiki prezentacji widoku sieci (FAZA 11, D-049) bez WPF: katalog widoków modułów, wiersze tabel
    (adaptery, zmiany oczekujące z odliczaniem, testy), dostępność przycisków (administrator, zmiana czekająca
    na zatwierdzenie, adapter połączenia), pozycje list i szczegóły adaptera. Dane z Resolve-MwpNetwork* na
    surowym JSON — bez wywołań systemowych.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Zmienne z bloków BeforeDiscovery/BeforeAll są używane w blokach It (zakresy Pestera).')]
param()

Describe 'MWP.UI — widok sieci (logika prezentacji)' {
    BeforeAll {
        $root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        foreach ($name in 'MWP.Core', 'MWP.Remote', 'MWP.Network') {
            Import-Module -Name (Join-Path -Path $root -ChildPath "src\Modules\$name\$name.psd1") -Force
        }
        Import-Module -Name (Join-Path -Path $root -ChildPath 'src\UI\MWP.UI.psm1') -Force

        function Get-TestStatus {
            param([bool] $Admin = $true, [bool] $WithPending = $false)
            $raw = [pscustomobject]@{
                Kind                = 'MWP.NetworkStatusRaw'
                ComputerName        = 'PC'
                CollectedAt         = '2026-10-28T10:00:00Z'
                IsAdministrator     = $Admin
                ConnectionAddresses = @('192.168.10.17')
                Warnings            = @()
                Adapters            = @(
                    [pscustomobject]@{ InterfaceIndex = 11; InterfaceGuid = '{A}'; Name = 'Ethernet'; Description = 'Karta'; Status = 'Up'; MacAddress = 'AA'; LinkSpeed = '1 Gbps'; MediaType = '802.3'; Virtual = $false; Hardware = $true
                        IPv4 = @('192.168.10.17/24'); IPv6 = @(); HasIPv6 = $true; Gateways = @('192.168.10.1'); DnsIPv4 = @('192.168.10.1'); DnsIPv6 = @(); DnsStaticIPv4 = @(); DnsStaticIPv6 = @()
                        DhcpEnabled = $true; DhcpServer = '192.168.10.1'; LeaseObtained = '2026-10-28T08:00:00Z'; LeaseExpires = '2026-10-28T20:00:00Z'; ProfileName = 'Dom'; NetworkCategory = 'Private'; IPv4Connectivity = 'Internet'; IsConnectionAdapter = $true
                    }
                    [pscustomobject]@{ InterfaceIndex = 2; InterfaceGuid = '{B}'; Name = 'Wi-Fi'; Description = 'WLAN'; Status = 'Disabled'; MacAddress = 'BB'; LinkSpeed = ''; MediaType = 'Native 802.11'; Virtual = $false; Hardware = $true
                        IPv4 = @(); IPv6 = @(); HasIPv6 = $false; Gateways = @(); DnsIPv4 = @(); DnsIPv6 = @(); DnsStaticIPv4 = @('9.9.9.9'); DnsStaticIPv6 = @()
                        DhcpEnabled = $false; DhcpServer = ''; LeaseObtained = $null; LeaseExpires = $null; ProfileName = ''; NetworkCategory = ''; IPv4Connectivity = ''; IsConnectionAdapter = $false
                    }
                )
                Pending             = @($(if ($WithPending) {
                            [pscustomobject]@{ ChangeId = '11111111-2222-3333-4444-555555555555'; TaskName = 'MWP-NetworkRollback-11111111-2222-3333-4444-555555555555'
                                Description = 'My Windows Power: automatyczne wycofanie zmiany sieci (Zmiana DNS adaptera ''Ethernet'' (Quad9)). Zatwierdzenie zmiany w aplikacji usuwa to zadanie.'
                                State = 'Ready'; Kind = 'Dns'; InterfaceIndex = 11; Deadline = '2026-10-28T10:02:00Z'; RemainingSeconds = 100
                            }
                        }))
            }
            Resolve-MwpNetworkStatus -Data (ConvertTo-Json -Depth 6 -Compress -InputObject $raw)
        }
    }

    AfterAll {
        Remove-Module -Name MWP.UI, MWP.Network, MWP.Remote, MWP.Core -Force -ErrorAction SilentlyContinue
    }

    It 'katalog widoków ma widok sieci z funkcjami okna' {
        $view = Get-MwpModuleViewCatalog -ModuleId Network
        $view.View | Should -Be 'Views\Network.xaml'
        Test-Path -LiteralPath (Join-Path -Path $root -ChildPath ('src\UI\' + $view.View)) | Should -BeTrue
        Get-Command -Name $view.Initialize -Module MWP.UI | Should -Not -BeNullOrEmpty
        Get-Command -Name $view.Update -Module MWP.UI | Should -Not -BeNullOrEmpty
    }

    It 'wiersze adapterów: DHCP, DNS i uwagi (połączenie, zmiana oczekująca)' {
        $rows = @(Get-MwpNetworkRow -Status (Get-TestStatus -WithPending $true))
        $rows.Count | Should -Be 2
        $rows[0].Name | Should -Be 'Ethernet'
        $rows[0].DhcpText | Should -Be 'Tak'
        $rows[0].Note | Should -Match 'połączenie aplikacji'
        $rows[0].Note | Should -Match 'czeka na zatwierdzenie'
        $rows[1].DnsText | Should -Be '9.9.9.9'
        $rows[1].StatusText | Should -Be 'Wyłączony'
        @(Get-MwpNetworkRow -Status $null).Count | Should -Be 0
    }

    It 'odliczanie zmiany oczekującej liczy czas od odczytu na hoście (bez porównywania zegarów)' {
        $status = Get-TestStatus -WithPending $true
        $read = [datetime]'2026-10-28 12:00:00'
        $row = @(Get-MwpNetworkRow -Status $status -Pending -ReadAt $read -Now $read.AddSeconds(30))[0]
        $row.RemainingSeconds | Should -Be 70
        $row.RemainingText | Should -Be '1:10'
        $row.Description | Should -Be "Zmiana DNS adaptera 'Ethernet' (Quad9)"
        (@(Get-MwpNetworkRow -Status $status -Pending -ReadAt $read -Now $read.AddSeconds(200))[0]).RemainingText | Should -Be 'wycofywanie…'
    }

    It 'przyciski: administrator, adapter, zmiana oczekująca i adapter połączenia' {
        $status = Get-TestStatus
        $state = Get-MwpNetworkActionState -Status $status -InterfaceIndex 11
        $state.CanSetDns | Should -BeTrue
        $state.CanDisable | Should -BeTrue
        $state.DisableNeedsExtra | Should -BeTrue
        $state.CanRenew | Should -BeTrue
        $state.CanEnable | Should -BeFalse
        $state.Hint | Should -Match 'połączenie aplikacji'
        $wifi = Get-MwpNetworkActionState -Status $status -InterfaceIndex 2
        $wifi.CanEnable | Should -BeTrue
        $wifi.CanRenew | Should -BeFalse
        $wifi.CanSetDns | Should -BeFalse
        $pending = Get-MwpNetworkActionState -Status (Get-TestStatus -WithPending $true) -InterfaceIndex 11
        $pending.CanSetDns | Should -BeFalse
        $pending.CanDisable | Should -BeFalse
        $pending.CanApprove | Should -BeTrue
        $noAdmin = Get-MwpNetworkActionState -Status (Get-TestStatus -Admin $false) -InterfaceIndex 11
        $noAdmin.CanSetDns | Should -BeFalse
        $noAdmin.CanReset | Should -BeFalse
        $noAdmin.CanTest | Should -BeTrue
        $noAdmin.Hint | Should -Match 'administratora'
        (Get-MwpNetworkActionState -Status $status -InterfaceIndex 11 -Ready $false).CanSetDns | Should -BeFalse
        (Get-MwpNetworkActionState -Status $null).CanApprove | Should -BeFalse
    }

    It 'pozycje list: presety DNS z „Własne adresy” i czas na zatwierdzenie (domyślnie 120 s)' {
        $presets = @(Get-MwpNetworkViewOption -Kind DnsPreset)
        @($presets.Value) | Should -Be @('Dhcp', 'Cloudflare', 'Google', 'Quad9', 'Custom')
        $presets[1].Label | Should -Match '1\.1\.1\.1'
        $rollback = @(Get-MwpNetworkViewOption -Kind Rollback)
        @($rollback.Value) | Should -Be @(60, 120, 300)
        $rollback[1].Label | Should -Be 'Zatwierdzenie w 2 min'
    }

    It 'szczegóły adaptera i wiersze testów' {
        $status = Get-TestStatus
        $detail = Get-MwpNetworkDetail -Adapter $status.Adapters[0]
        $detail.Title | Should -Be 'Ethernet — Karta'
        $detail.Text | Should -Match 'automatycznie \(DHCP\)'
        $detail.Text | Should -Match 'dzierżawa do'
        $detail.Text | Should -Match 'przerwie połączenie'
        (Get-MwpNetworkDetail -Adapter $status.Adapters[1]).Text | Should -Match 'IPv6: wyłączony'
        (Get-MwpNetworkDetail -Adapter $null).Title | Should -Be 'Wybierz adapter z listy.'
        $test = Resolve-MwpNetworkTest -Data '{"Kind":"MWP.NetworkTestRaw","ComputerName":"PC","CollectedAt":"2026-10-28T10:00:00Z","Tests":[{"Name":"Gateway","Target":"192.168.10.1","Success":true,"Detail":"odpowiedź 1 ms","DurationMs":3}]}'
        $row = @(Get-MwpNetworkRow -Test $test)[0]
        $row.Label | Should -Be 'Ping do bramy domyślnej'
        $row.DurationText | Should -Be '3 ms'
    }
}
