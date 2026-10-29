@{
    RootModule           = 'MWP.Power.psm1'
    ModuleVersion        = '0.6.1'
    GUID                 = '11d47c40-6897-408f-ac88-edec49d70ecc'
    Author               = 'wysockimarcin'
    CompanyName          = 'wysockimarcin'
    Copyright            = '(c) wysockimarcin. Projekt osobisty.'
    Description          = 'Plany zasilania i ustawienia energii.'
    PowerShellVersion    = '5.1'
    CompatiblePSEditions = @('Desktop', 'Core')
    FunctionsToExport    = @(
        'Add-MwpUltimatePowerPlan'
        'ConvertTo-MwpPowerStatusView'
        'Copy-MwpPowerPlan'
        'Get-MwpPowerModuleInfo'
        'Get-MwpPowerPlan'
        'Get-MwpPowerReportDirectory'
        'Get-MwpPowerStatus'
        'Import-MwpPowerPlan'
        'New-MwpPowerReport'
        'Open-MwpPowerReport'
        'Remove-MwpPowerPlan'
        'Rename-MwpPowerPlan'
        'Resolve-MwpPowerStatus'
        'Save-MwpPowerReport'
        'Set-MwpActivePowerPlan'
        'Set-MwpFastStartup'
        'Set-MwpHibernation'
        'Set-MwpPowerSetting'
    )
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()
    PrivateData          = @{
        # Kontrakt modułu MyWindowsPower (ARCHITEKTURA.md, „Kontrakt modułu"; D-024).
        # Widok w oknie hosta: src\UI\Views\Power.xaml (widok modułu wbudowanego, D-044).
        MWP    = @{
            ContractVersion            = 1
            Id                         = 'Power'
            Name                       = 'Zasilanie'
            EntryPoint                 = 'Get-MwpPowerModuleInfo'
            MinimumHostVersion         = '0.5.0'
            Dependencies               = @(
                @{ Id = 'Core'; MinimumVersion = '0.5.0' }
                @{ Id = 'Remote'; MinimumVersion = '0.5.0' }
            )
            Capabilities               = @('Read', 'Change', 'Destructive', 'Undo', 'RemoteTarget')
            SupportedPresentationModes = @('Embedded', 'SeparateWindow', 'DashboardWidget')
            RequiredPermissions        = @('User', 'Administrator')
            ConfigurationSchema        = @{}
            Widgets                    = @(
                @{
                    Id                    = 'PowerStatus'
                    Name                  = 'Zasilanie'
                    Description           = 'Plan aktywny, czasy wygaszania ekranu i uśpienia (sieć/bateria), hibernacja i szybkie uruchamianie.'
                    DataCommand           = 'Get-MwpPowerStatus'
                    ViewCommand           = 'ConvertTo-MwpPowerStatusView'
                    DefaultRefreshSeconds = 300
                    Parameters            = @{
                        # D-053: domyślnie minimum; PreviousDefault — dla widgetów zapisanych, zanim parametr istniał.
                        Sections = @{
                            Type            = 'StringArray'
                            Default         = @('Plan')
                            PreviousDefault = @('Plan', 'Timeouts', 'Hibernate')
                            Values          = @('Plan', 'Timeouts', 'Hibernate')
                            Label           = 'Sekcje'
                            ValueLabels     = @{ Plan = 'Plan zasilania'; Timeouts = 'Ekran i uśpienie'; Hibernate = 'Hibernacja i szybkie uruchamianie' }
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
