@{
    RootModule           = 'MWP.Dashboard.psm1'
    ModuleVersion        = '0.5.1'
    GUID                 = '97ba3923-8081-42ea-971d-f45bd0a2a0ac'
    Author               = 'wysockimarcin'
    CompanyName          = 'wysockimarcin'
    Copyright            = '(c) wysockimarcin. Projekt osobisty.'
    Description          = 'Informacje o systemie i sprzęcie (dashboard).'
    PowerShellVersion    = '5.1'
    CompatiblePSEditions = @('Desktop', 'Core')
    FunctionsToExport    = @(
        'ConvertTo-MwpSystemInfoView'
        'ConvertTo-MwpSystemReport'
        'Export-MwpSystemReport'
        'Get-MwpDashboardModuleInfo'
        'Get-MwpSystemInfo'
    )
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()
    PrivateData          = @{
        # Kontrakt modułu MyWindowsPower (ARCHITEKTURA.md, „Kontrakt modułu"; D-024).
        # Widgets: widgety Dashboardu (opcjonalne pole kontraktu, D-043).
        MWP    = @{
            ContractVersion            = 1
            Id                         = 'Dashboard'
            Name                       = 'Informacje o systemie'
            EntryPoint                 = 'Get-MwpDashboardModuleInfo'
            MinimumHostVersion         = '0.5.0'
            Dependencies               = @(
                @{ Id = 'Core'; MinimumVersion = '0.5.0' }
                @{ Id = 'Remote'; MinimumVersion = '0.5.0' }
            )
            Capabilities               = @('Read', 'RemoteTarget')
            SupportedPresentationModes = @('Embedded', 'SeparateWindow', 'DashboardWidget')
            RequiredPermissions        = @('User')
            ConfigurationSchema        = @{}
            Widgets                    = @(
                @{
                    Id                    = 'SystemInfo'
                    Name                  = 'Informacje o systemie'
                    Description           = 'System, czas pracy, procesor, pamięć, grafika, dyski, płyta główna, bateria i sieć.'
                    DataCommand           = 'Get-MwpSystemInfo'
                    ViewCommand           = 'ConvertTo-MwpSystemInfoView'
                    ExportCommand         = 'Export-MwpSystemReport'
                    DefaultRefreshSeconds = 60
                    Parameters            = @{
                        Sections = @{
                            Type    = 'StringArray'
                            # D-053: domyślnie minimum; PreviousDefault — dla widgetów zapisanych bez parametru Sections.
                            Default = @('System', 'Memory', 'Disks')
                            PreviousDefault = @('System', 'Cpu', 'Memory', 'Disks')
                            Values  = @('System', 'Cpu', 'Memory', 'Gpu', 'Disks', 'Board', 'Battery', 'Network')
                            Label   = 'Sekcje'
                            ValueLabels = @{
                                System  = 'System'
                                Cpu     = 'Procesor'
                                Memory  = 'Pamięć RAM'
                                Gpu     = 'Grafika'
                                Disks   = 'Dyski'
                                Board   = 'Płyta główna i BIOS'
                                Battery = 'Bateria'
                                Network = 'Sieć'
                            }
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