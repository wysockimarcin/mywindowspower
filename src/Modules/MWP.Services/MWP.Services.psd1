@{
    RootModule           = 'MWP.Services.psm1'
    ModuleVersion        = '0.7.0'
    GUID                 = '1bb3180e-664a-4926-87f6-9b9ff8ebd1fa'
    Author               = 'wysockimarcin'
    CompanyName          = 'wysockimarcin'
    Copyright            = '(c) wysockimarcin. Projekt osobisty.'
    Description          = 'Usługi Windows.'
    PowerShellVersion    = '5.1'
    CompatiblePSEditions = @('Desktop', 'Core')
    FunctionsToExport    = @(
        'Compare-MwpServiceProfile'
        'ConvertTo-MwpServiceStatusView'
        'Export-MwpServiceProfile'
        'Get-MwpService'
        'Get-MwpServicesModuleInfo'
        'Get-MwpServiceStartupTypeList'
        'Import-MwpServiceProfile'
        'Read-MwpServiceProfile'
        'Resolve-MwpServiceList'
        'Restart-MwpService'
        'Select-MwpService'
        'Set-MwpServiceStartupType'
        'Start-MwpService'
        'Stop-MwpService'
        'Test-MwpServiceName'
    )
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()
    PrivateData          = @{
        # Kontrakt modułu MyWindowsPower (ARCHITEKTURA.md, „Kontrakt modułu"; D-024).
        # Widok w oknie hosta: src\UI\Views\Services.xaml (widok modułu wbudowanego, D-044, D-045).
        MWP    = @{
            ContractVersion            = 1
            Id                         = 'Services'
            Name                       = 'Usługi Windows'
            EntryPoint                 = 'Get-MwpServicesModuleInfo'
            MinimumHostVersion         = '0.7.0'
            Dependencies               = @(
                @{ Id = 'Core'; MinimumVersion = '0.7.0' }
                @{ Id = 'Remote'; MinimumVersion = '0.5.0' }
            )
            Capabilities               = @('Read', 'Change', 'Undo', 'RemoteTarget')
            SupportedPresentationModes = @('Embedded', 'SeparateWindow', 'DashboardWidget')
            RequiredPermissions        = @('User', 'Administrator')
            ConfigurationSchema        = @{}
            Widgets                    = @(
                @{
                    Id                    = 'ServiceStatus'
                    Name                  = 'Status usług'
                    Description           = 'Liczba działających i zatrzymanych usług, obserwowane usługi i zatrzymane usługi automatyczne.'
                    DataCommand           = 'Get-MwpService'
                    ViewCommand           = 'ConvertTo-MwpServiceStatusView'
                    DefaultRefreshSeconds = 60
                    Parameters            = @{
                        Names = @{
                            Type    = 'StringArray'
                            Default = @('WinRM', 'WinDefend', 'mpssvc', 'wuauserv', 'BITS', 'Spooler')
                            Label   = 'Obserwowane usługi (nazwy usług, po przecinku)'
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
