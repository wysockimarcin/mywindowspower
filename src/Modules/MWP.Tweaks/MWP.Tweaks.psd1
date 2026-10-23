@{
    RootModule           = 'MWP.Tweaks.psm1'
    ModuleVersion        = '0.1.0'
    GUID                 = '8604797c-765b-4ef5-b91a-a2bceb777f19'
    Author               = 'wysockimarcin'
    CompanyName          = 'wysockimarcin'
    Copyright            = '(c) wysockimarcin. Projekt osobisty.'
    Description          = 'Prywatność i ustawienia systemu (tweaki rejestru).'
    PowerShellVersion    = '5.1'
    CompatiblePSEditions = @('Desktop', 'Core')
    FunctionsToExport    = @('Get-MwpTweaksModuleInfo')
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()
    PrivateData          = @{
        # Kontrakt modułu MyWindowsPower (ARCHITEKTURA.md, „Kontrakt modułu"; D-024).
        # Capabilities i SupportedPresentationModes uzupełnia faza obszaru.
        MWP    = @{
            ContractVersion            = 1
            Id                         = 'Tweaks'
            Name                       = 'Prywatność i tweaki'
            EntryPoint                 = 'Get-MwpTweaksModuleInfo'
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