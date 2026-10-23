@{
    RootModule           = 'MWP.Remote.psm1'
    ModuleVersion        = '0.3.0'
    GUID                 = 'c2b4ddbe-4c75-4db6-89d9-700ff0abe8b2'
    Author               = 'wysockimarcin'
    CompanyName          = 'wysockimarcin'
    Copyright            = '(c) wysockimarcin. Projekt osobisty.'
    Description          = 'Komputery docelowe, kontekst wykonania, połączenia zdalne (WinRM, CIM), operacje asynchroniczne i instancje modułów.'
    PowerShellVersion    = '5.1'
    CompatiblePSEditions = @('Desktop', 'Core')
    FunctionsToExport    = @(
        'Add-MwpTarget'
        'Close-MwpModuleInstance'
        'Connect-MwpTarget'
        'Disconnect-MwpTarget'
        'Get-MwpCimSessionParameter'
        'Get-MwpModuleInstance'
        'Get-MwpRemoteModuleInfo'
        'Get-MwpTarget'
        'Initialize-MwpModuleInstance'
        'Invoke-MwpOnTarget'
        'New-MwpExecutionContext'
        'New-MwpModuleInstance'
        'Remove-MwpTarget'
        'Start-MwpOperation'
        'Stop-MwpOperation'
        'Test-MwpTarget'
        'Wait-MwpOperation'
    )
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()
    PrivateData          = @{
        # Kontrakt modułu MyWindowsPower (ARCHITEKTURA.md, „Kontrakt modułu"; D-024).
        # Moduł bazowy (D-031): nie można go odinstalować.
        MWP    = @{
            ContractVersion            = 1
            Id                         = 'Remote'
            Name                       = 'Komputery docelowe i połączenia'
            EntryPoint                 = 'Get-MwpRemoteModuleInfo'
            MinimumHostVersion         = '0.3.0'
            Dependencies               = @(
                @{ Id = 'Core'; MinimumVersion = '0.3.0' }
            )
            Capabilities               = @('HostServices', 'RemoteTarget')
            SupportedPresentationModes = @()
            RequiredPermissions        = @('User')
            ConfigurationSchema        = @{}
        }
        PSData = @{
            ProjectUri = 'https://github.com/wysockimarcin/mywindowspower'
        }
    }
}
