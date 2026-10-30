@{
    RootModule           = 'MWP.Remote.psm1'
    ModuleVersion        = '0.12.3'
    GUID                 = 'c2b4ddbe-4c75-4db6-89d9-700ff0abe8b2'
    Author               = 'wysockimarcin'
    CompanyName          = 'wysockimarcin'
    Copyright            = '(c) wysockimarcin. Projekt osobisty.'
    Description          = 'Komputery docelowe, kontekst wykonania, połączenia zdalne (WinRM, CIM), zapamiętane poświadczenia (Menedżer poświadczeń Windows), operacje asynchroniczne i instancje modułów.'
    PowerShellVersion    = '5.1'
    CompatiblePSEditions = @('Desktop', 'Core')
    FunctionsToExport    = @(
        'Add-MwpTarget'
        'Clear-MwpTargetCredentialCache'
        'Close-MwpModuleInstance'
        'Connect-MwpTarget'
        'ConvertTo-MwpTargetStatusView'
        'Disconnect-MwpTarget'
        'Get-MwpCimSessionParameter'
        'Get-MwpLocalNetworkAddress'
        'Get-MwpModuleInstance'
        'Get-MwpRemoteModuleInfo'
        'Get-MwpTarget'
        'Get-MwpTargetComputerName'
        'Get-MwpTargetCredentialInfo'
        'Get-MwpTargetInfo'
        'Get-MwpTargetStatus'
        'Initialize-MwpModuleInstance'
        'Invoke-MwpOnTarget'
        'New-MwpExecutionContext'
        'New-MwpModuleInstance'
        'Remove-MwpTarget'
        'Remove-MwpTargetCredential'
        'Resolve-MwpTargetStatus'
        'Save-MwpTargetCredential'
        'Set-MwpTarget'
        'Start-MwpOperation'
        'Stop-MwpOperation'
        'Test-MwpTarget'
        'Test-MwpTargetIsLocalComputer'
        'Wait-MwpOperation'
    )
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()
    PrivateData          = @{
        # Kontrakt modułu MyWindowsPower (ARCHITEKTURA.md, „Kontrakt modułu"; D-024).
        # Moduł bazowy (D-031): nie można go odinstalować.
        # Widget „Komputery” (D-053): tylko komputer lokalny (LocalOnly) — próby połączenia wychodzą z komputera aplikacji.
        MWP    = @{
            ContractVersion            = 1
            Id                         = 'Remote'
            Name                       = 'Komputery docelowe i połączenia'
            EntryPoint                 = 'Get-MwpRemoteModuleInfo'
            MinimumHostVersion         = '0.4.0'
            Dependencies               = @(
                @{ Id = 'Core'; MinimumVersion = '0.4.0' }
            )
            Capabilities               = @('HostServices', 'RemoteTarget')
            SupportedPresentationModes = @('DashboardWidget')
            RequiredPermissions        = @('User')
            ConfigurationSchema        = @{}
            Widgets                    = @(
                @{
                    Id                    = 'TargetStatus'
                    Name                  = 'Komputery'
                    Description           = 'Komputery zdalne z rejestru: dostępność portu WinRM z tego komputera i stan hasła w pamięci aplikacji.'
                    DataCommand           = 'Get-MwpTargetStatus'
                    ViewCommand           = 'ConvertTo-MwpTargetStatusView'
                    DefaultRefreshSeconds = 300
                    LocalOnly             = $true
                    Parameters            = @{
                        Probe = @{
                            Type    = 'Bool'
                            Default = $true
                            Label   = 'Sprawdzaj dostępność (połączenie TCP z portem WinRM, bez logowania)'
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
