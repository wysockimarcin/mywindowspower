@{
    RootModule           = 'MWP.Network.psm1'
    ModuleVersion        = '0.1.0'
    GUID                 = 'becc87cb-4307-4830-8002-f9f842a4b22e'
    Author               = 'wysockimarcin'
    CompanyName          = 'wysockimarcin'
    Copyright            = '(c) wysockimarcin. Projekt osobisty.'
    Description          = 'Sieć: adaptery, DNS, reset.'
    PowerShellVersion    = '5.1'
    CompatiblePSEditions = @('Desktop', 'Core')
    FunctionsToExport    = @('Get-MwpNetworkModuleInfo')
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()
    PrivateData          = @{
        # Kontrakt modułu MyWindowsPower (ARCHITEKTURA.md, „Kontrakt modułu"; D-024).
        # Capabilities i SupportedPresentationModes uzupełnia faza obszaru.
        MWP    = @{
            ContractVersion            = 1
            Id                         = 'Network'
            Name                       = 'Sieć'
            EntryPoint                 = 'Get-MwpNetworkModuleInfo'
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