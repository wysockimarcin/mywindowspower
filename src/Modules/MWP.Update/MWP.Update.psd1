@{
    RootModule           = 'MWP.Update.psm1'
    ModuleVersion        = '0.10.1'
    GUID                 = '98134e45-6a27-4337-8c76-31d3c8b7f17b'
    Author               = 'wysockimarcin'
    CompanyName          = 'wysockimarcin'
    Copyright            = '(c) wysockimarcin. Projekt osobisty.'
    Description          = 'Windows Update.'
    PowerShellVersion    = '5.1'
    CompatiblePSEditions = @('Desktop', 'Core')
    FunctionsToExport    = @(
        'ConvertTo-MwpUpdateStatusView'
        'Find-MwpUpdate'
        'Format-MwpUpdateSize'
        'Get-MwpUpdateHistory'
        'Get-MwpUpdateModuleInfo'
        'Get-MwpUpdateResetStep'
        'Get-MwpUpdateStatus'
        'Install-MwpUpdate'
        'Open-MwpUpdatePage'
        'Reset-MwpUpdateComponent'
        'Resolve-MwpUpdateHistory'
        'Resolve-MwpUpdateSearch'
        'Resolve-MwpUpdateStatus'
        'Restore-MwpUpdateComponent'
        'Restore-MwpUpdatePause'
        'Resume-MwpUpdate'
        'Suspend-MwpUpdate'
    )
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()
    PrivateData          = @{
        # Kontrakt modułu MyWindowsPower (ARCHITEKTURA.md, „Kontrakt modułu"; D-024).
        # Widok w oknie hosta: src\UI\Views\Update.xaml (widok modułu wbudowanego, D-044, D-048).
        MWP    = @{
            ContractVersion            = 1
            Id                         = 'Update'
            Name                       = 'Windows Update'
            EntryPoint                 = 'Get-MwpUpdateModuleInfo'
            MinimumHostVersion         = '0.10.0'
            Dependencies               = @(
                @{ Id = 'Core'; MinimumVersion = '0.10.0' }
                @{ Id = 'Remote'; MinimumVersion = '0.5.0' }
            )
            Capabilities               = @('Read', 'Change', 'Destructive', 'Undo', 'RemoteTarget')
            SupportedPresentationModes = @('Embedded', 'SeparateWindow', 'DashboardWidget')
            RequiredPermissions        = @('User', 'Administrator')
            ConfigurationSchema        = @{}
            Widgets                    = @(
                @{
                    Id                    = 'UpdateStatus'
                    Name                  = 'Windows Update'
                    Description           = 'Wymagany restart, pauza aktualizacji, ostatnie wyszukiwanie i instalacja, usługi Windows Update.'
                    DataCommand           = 'Get-MwpUpdateStatus'
                    ViewCommand           = 'ConvertTo-MwpUpdateStatusView'
                    DefaultRefreshSeconds = 300
                    Parameters            = @{
                        Sections = @{
                            Type        = 'StringArray'
                            Default     = @('Restart', 'Pause')
                            Values      = @('Restart', 'Pause', 'LastActivity', 'Services')
                            Label       = 'Sekcje'
                            ValueLabels = @{ Restart = 'Restart'; Pause = 'Pauza'; LastActivity = 'Ostatnie wyszukiwanie i instalacja'; Services = 'Usługi' }
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
