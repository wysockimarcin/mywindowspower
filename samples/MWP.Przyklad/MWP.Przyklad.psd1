@{
    RootModule           = 'MWP.Przyklad.psm1'
    ModuleVersion        = '1.0.0'
    GUID                 = '6f0b1a52-3e1c-4f0e-9a7d-2b8e5c4d9f10'
    Author               = 'wysockimarcin'
    CompanyName          = 'wysockimarcin'
    Copyright            = '(c) wysockimarcin. Projekt osobisty.'
    Description          = 'Moduł przykładowy do paczki .mwpmod: test instalacji z widoku Moduły i dwóch instancji dla dwóch komputerów (FAZA 4).'
    PowerShellVersion    = '5.1'
    CompatiblePSEditions = @('Desktop', 'Core')
    FunctionsToExport    = @(
        'Get-MwpPrzykladInfo'
        'Get-MwpPrzykladModuleInfo'
    )
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()
    PrivateData          = @{
        # Kontrakt modułu MyWindowsPower (ARCHITEKTURA.md, „Kontrakt modułu"; D-024).
        MWP    = @{
            ContractVersion            = 1
            Id                         = 'Przyklad'
            Name                       = 'Moduł przykładowy'
            EntryPoint                 = 'Get-MwpPrzykladModuleInfo'
            MinimumHostVersion         = '0.4.0'
            Dependencies               = @(
                @{ Id = 'Core'; MinimumVersion = '0.4.0' }
                @{ Id = 'Remote'; MinimumVersion = '0.4.0' }
            )
            Capabilities               = @('Read', 'RemoteTarget')
            SupportedPresentationModes = @('Embedded', 'SeparateWindow')
            RequiredPermissions        = @('User')
            ConfigurationSchema        = @{}
        }
        PSData = @{
            ProjectUri = 'https://github.com/wysockimarcin/mywindowspower'
        }
    }
}
