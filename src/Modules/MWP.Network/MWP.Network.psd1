@{
    RootModule           = 'MWP.Network.psm1'
    ModuleVersion        = '0.11.0'
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
            SupportedPresentationModes = @('Embedded', 'SeparateWindow')
            RequiredPermissions        = @('User', 'Administrator')
            ConfigurationSchema        = @{}
        }
        PSData = @{
            ProjectUri = 'https://github.com/wysockimarcin/mywindowspower'
        }
    }
}
