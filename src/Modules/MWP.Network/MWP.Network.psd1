@{
    RootModule           = 'MWP.Network.psm1'
    ModuleVersion        = '0.11.1'
    GUID                 = 'becc87cb-4307-4830-8002-f9f842a4b22e'
    Author               = 'wysockimarcin'
    CompanyName          = 'wysockimarcin'
    Copyright            = '(c) wysockimarcin. Projekt osobisty.'
    Description          = 'Sieć: adaptery, konfiguracja IP, DNS z cofaniem, DHCP, resety i testy łączności.'
    PowerShellVersion    = '5.1'
    CompatiblePSEditions = @('Desktop', 'Core')
    FunctionsToExport    = @(
        'Approve-MwpNetworkChange'
        'Clear-MwpDnsCache'
        'ConvertTo-MwpNetworkStatusView'
        'Disable-MwpNetAdapter'
        'Enable-MwpNetAdapter'
        'Get-MwpDnsPreset'
        'Get-MwpNetworkModuleInfo'
        'Get-MwpNetworkStatus'
        'Reset-MwpNetworkStack'
        'Resolve-MwpNetworkStatus'
        'Resolve-MwpNetworkTest'
        'Set-MwpDnsServer'
        'Test-MwpNetworkConnection'
        'Update-MwpDhcpLease'
    )
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()
    PrivateData          = @{
        # Kontrakt modułu MyWindowsPower (ARCHITEKTURA.md, „Kontrakt modułu"; D-024).
        # Widok w oknie hosta: src\UI\Views\Network.xaml (widok modułu wbudowanego, D-044, D-049).
        MWP    = @{
            ContractVersion            = 1
            Id                         = 'Network'
            Name                       = 'Sieć'
            EntryPoint                 = 'Get-MwpNetworkModuleInfo'
            MinimumHostVersion         = '0.11.0'
            Dependencies               = @(
                @{ Id = 'Core'; MinimumVersion = '0.11.0' }
                @{ Id = 'Remote'; MinimumVersion = '0.5.0' }
            )
            Capabilities               = @('Read', 'Change', 'Destructive', 'Undo', 'RemoteTarget')
            SupportedPresentationModes = @('Embedded', 'SeparateWindow', 'DashboardWidget')
            RequiredPermissions        = @('User', 'Administrator')
            ConfigurationSchema        = @{}
            Widgets                    = @(
                @{
                    Id                    = 'NetworkStatus'
                    Name                  = 'Sieć'
                    Description           = 'Adaptery sieciowe ze stanem i adresami; do wyboru brama, DNS, tryb DHCP i IPv6.'
                    DataCommand           = 'Get-MwpNetworkStatus'
                    ViewCommand           = 'ConvertTo-MwpNetworkStatusView'
                    DefaultRefreshSeconds = 60
                    Parameters            = @{
                        OnlyConnected = @{
                            Type    = 'Bool'
                            Default = $true
                            Label   = 'Tylko połączone adaptery'
                        }
                        Details       = @{
                            Type        = 'StringArray'
                            Default     = @('IPv4')
                            Values      = @('IPv4', 'Gateway', 'Dns', 'Dhcp', 'IPv6')
                            Label       = 'Szczegóły adaptera'
                            ValueLabels = @{ IPv4 = 'Adres IPv4'; Gateway = 'Brama'; Dns = 'Serwery DNS'; Dhcp = 'DHCP czy statyczny'; IPv6 = 'Adresy IPv6' }
                        }
                    }
                }
            )
        }
        PSData = @{
            ProjectUri = 'https://github.com/wysockimarcin/mywindowspower'
        }
    }
}
