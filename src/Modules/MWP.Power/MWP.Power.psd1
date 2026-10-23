@{
    RootModule           = 'MWP.Power.psm1'
    ModuleVersion        = '0.1.0'
    GUID                 = '11d47c40-6897-408f-ac88-edec49d70ecc'
    Author               = 'wysockimarcin'
    CompanyName          = 'wysockimarcin'
    Copyright            = '(c) wysockimarcin. Projekt osobisty.'
    Description          = 'Plany zasilania i ustawienia energii.'
    PowerShellVersion    = '5.1'
    CompatiblePSEditions = @('Desktop', 'Core')
    FunctionsToExport    = @('Get-MwpPowerModuleInfo')
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()
    PrivateData          = @{
        # Kontrakt modułu MyWindowsPower (ARCHITEKTURA.md, „Kontrakt modułu"; D-024).
        # Capabilities i SupportedPresentationModes uzupełnia faza obszaru.
        MWP    = @{
            ContractVersion            = 1
            Id                         = 'Power'
            Name                       = 'Zasilanie'
            EntryPoint                 = 'Get-MwpPowerModuleInfo'
            MinimumHostVersion         = '0.2.0'
            Dependencies               = @(
                @{ Id = 'Core'; MinimumVersion = '0.2.0' }
            )
            Capabilities               = @()
            SupportedPresentationModes = @()
            RequiredPermissions        = @('User')
            ConfigurationSchema        = @{}
        }
        PSData = @{
            ProjectUri = 'https://github.com/wysockimarcin/mywindowspower'
        }
    }
}