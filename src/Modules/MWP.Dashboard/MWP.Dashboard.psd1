@{
    RootModule           = 'MWP.Dashboard.psm1'
    ModuleVersion        = '0.1.0'
    GUID                 = '97ba3923-8081-42ea-971d-f45bd0a2a0ac'
    Author               = 'wysockimarcin'
    CompanyName          = 'wysockimarcin'
    Copyright            = '(c) wysockimarcin. Projekt osobisty.'
    Description          = 'Informacje o systemie i sprzęcie (dashboard).'
    PowerShellVersion    = '5.1'
    CompatiblePSEditions = @('Desktop', 'Core')
    FunctionsToExport    = @('Get-MwpDashboardModuleInfo')
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()
    PrivateData          = @{
        # Kontrakt modułu MyWindowsPower (ARCHITEKTURA.md, „Kontrakt modułu"; D-024).
        # Capabilities i SupportedPresentationModes uzupełnia faza obszaru.
        MWP    = @{
            ContractVersion            = 1
            Id                         = 'Dashboard'
            Name                       = 'Informacje o systemie'
            EntryPoint                 = 'Get-MwpDashboardModuleInfo'
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