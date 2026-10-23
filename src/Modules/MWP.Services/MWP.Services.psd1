@{
    RootModule           = 'MWP.Services.psm1'
    ModuleVersion        = '0.1.0'
    GUID                 = '1bb3180e-664a-4926-87f6-9b9ff8ebd1fa'
    Author               = 'wysockimarcin'
    CompanyName          = 'wysockimarcin'
    Copyright            = '(c) wysockimarcin. Projekt osobisty.'
    Description          = 'Usługi Windows.'
    PowerShellVersion    = '5.1'
    CompatiblePSEditions = @('Desktop', 'Core')
    FunctionsToExport    = @('Get-MwpServicesModuleInfo')
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()
    PrivateData          = @{
        # Kontrakt modułu MyWindowsPower (ARCHITEKTURA.md, „Kontrakt modułu"; D-024).
        # Capabilities i SupportedPresentationModes uzupełnia faza obszaru.
        MWP    = @{
            ContractVersion            = 1
            Id                         = 'Services'
            Name                       = 'Usługi Windows'
            EntryPoint                 = 'Get-MwpServicesModuleInfo'
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