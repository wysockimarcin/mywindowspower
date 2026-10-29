@{
    RootModule           = 'MWP.Tweaks.psm1'
    ModuleVersion        = '0.1.1'
    GUID                 = '8604797c-765b-4ef5-b91a-a2bceb777f19'
    Author               = 'wysockimarcin'
    CompanyName          = 'wysockimarcin'
    Copyright            = '(c) wysockimarcin. Projekt osobisty.'
    Description          = 'Prywatność i ustawienia systemu (tweaki rejestru).'
    PowerShellVersion    = '5.1'
    CompatiblePSEditions = @('Desktop', 'Core')
    FunctionsToExport    = @(
        'ConvertTo-MwpTweaksWidgetView'
        'Get-MwpTweaksModuleInfo'
        'Get-MwpTweaksWidgetData'
    )
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()
    PrivateData          = @{
        # Kontrakt modułu MyWindowsPower (ARCHITEKTURA.md, „Kontrakt modułu"; D-024).
        # Capabilities uzupełnia faza obszaru. Tryby jawnie (dotąd pusta lista = zalążek z oboma trybami okna) oraz
        # widget-zalążek z Enabled = $false (D-053: każdy moduł deklaruje widget); FAZA 13 zastąpi go widgetem z danymi.
        MWP    = @{
            ContractVersion            = 1
            Id                         = 'Tweaks'
            Name                       = 'Prywatność i tweaki'
            EntryPoint                 = 'Get-MwpTweaksModuleInfo'
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
                    Name                  = 'Prywatność i tweaki (zalążek)'
                    Description           = 'Zalążek widgetu: wersja modułu i informacja, że dane obszaru pojawią się w FAZIE 13. Domyślnie ukryty — włącz w widoku „Moduły”.'
                    DataCommand           = 'Get-MwpTweaksWidgetData'
                    ViewCommand           = 'ConvertTo-MwpTweaksWidgetView'
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