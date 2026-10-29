@{
    RootModule           = 'MWP.Security.psm1'
    ModuleVersion        = '0.1.1'
    GUID                 = '08f1e303-6767-4601-8f53-e038c5e6ac05'
    Author               = 'wysockimarcin'
    CompanyName          = 'wysockimarcin'
    Copyright            = '(c) wysockimarcin. Projekt osobisty.'
    Description          = 'Microsoft Defender i zapora (firewall).'
    PowerShellVersion    = '5.1'
    CompatiblePSEditions = @('Desktop', 'Core')
    FunctionsToExport    = @(
        'ConvertTo-MwpSecurityWidgetView'
        'Get-MwpSecurityModuleInfo'
        'Get-MwpSecurityWidgetData'
    )
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()
    PrivateData          = @{
        # Kontrakt modułu MyWindowsPower (ARCHITEKTURA.md, „Kontrakt modułu"; D-024).
        # Capabilities uzupełnia faza obszaru. Tryby jawnie (dotąd pusta lista = zalążek z oboma trybami okna) oraz
        # widget-zalążek z Enabled = $false (D-053: każdy moduł deklaruje widget); FAZA 14 zastąpi go widgetem z danymi.
        MWP    = @{
            ContractVersion            = 1
            Id                         = 'Security'
            Name                       = 'Defender i zapora'
            EntryPoint                 = 'Get-MwpSecurityModuleInfo'
            MinimumHostVersion         = '0.2.0'
            Dependencies               = @(
                @{ Id = 'Core'; MinimumVersion = '0.2.0' }
                @{ Id = 'Remote'; MinimumVersion = '0.5.0' }
            )
            Capabilities               = @()
            SupportedPresentationModes = @('Embedded', 'SeparateWindow', 'DashboardWidget')
            RequiredPermissions        = @('User')
            ConfigurationSchema        = @{}
            Widgets                    = @(
                @{
                    Id                    = 'ModuleStatus'
                    Name                  = 'Defender i zapora (zalążek)'
                    Description           = 'Zalążek widgetu: wersja modułu i informacja, że dane obszaru pojawią się w FAZIE 14. Domyślnie ukryty — włącz w widoku „Moduły”.'
                    DataCommand           = 'Get-MwpSecurityWidgetData'
                    ViewCommand           = 'ConvertTo-MwpSecurityWidgetView'
                    DefaultRefreshSeconds = 0
                    Enabled               = $false
                    Parameters            = @{}
                }
            )
        }
        PSData = @{
            ProjectUri = 'https://github.com/wysockimarcin/mywindowspower'
        }
    }
}