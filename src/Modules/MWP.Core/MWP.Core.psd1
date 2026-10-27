@{
    RootModule           = 'MWP.Core.psm1'
    ModuleVersion        = '0.8.0'
    GUID                 = '49bd0d67-5058-467d-a21e-ef40a9d9710a'
    Author               = 'wysockimarcin'
    CompanyName          = 'wysockimarcin'
    Copyright            = '(c) wysockimarcin. Projekt osobisty.'
    Description          = 'Rdzeń: logowanie, konfiguracja, środowisko i elewacja, punkt przywracania, rejestr cofnięć, obiekt wyniku, lista ochronna, kontrakt i odkrywanie modułów, instalacja i odinstalowanie modułów z paczek, katalog danych aplikacji.'
    PowerShellVersion    = '5.1'
    CompatiblePSEditions = @('Desktop', 'Core')
    FunctionsToExport    = @(
        'Format-MwpOperationTarget'
        'Get-MwpCoreModuleInfo'
        'Get-MwpDashboardConfiguration'
        'Get-MwpDataLocation'
        'Get-MwpEnvironment'
        'Get-MwpInstalledModule'
        'Get-MwpModuleDefinition'
        'Get-MwpProtectedItem'
        'Get-MwpSetting'
        'Get-MwpUndoEntry'
        'Get-MwpWidgetDefinition'
        'Install-MwpModulePackage'
        'Invoke-MwpUndo'
        'Move-MwpDataDirectory'
        'Move-MwpInstalledModule'
        'New-MwpRestorePoint'
        'New-MwpResult'
        'Remove-MwpDashboardWidget'
        'Repair-MwpDashboardConfiguration'
        'Request-MwpElevation'
        'Save-MwpUndoEntry'
        'Set-MwpDashboardConfiguration'
        'Set-MwpSetting'
        'Test-MwpAdmin'
        'Test-MwpModuleDefinition'
        'Test-MwpModulePackage'
        'Test-MwpProtectedItem'
        'Uninstall-MwpModulePackage'
        'Write-MwpLog'
    )
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()
    PrivateData          = @{
        # Kontrakt modułu MyWindowsPower (ARCHITEKTURA.md, „Kontrakt modułu"; D-024).
        # Wersja hosta = ModuleVersion modułu MWP.Core.
        MWP    = @{
            ContractVersion            = 1
            Id                         = 'Core'
            Name                       = 'Rdzeń'
            EntryPoint                 = 'Get-MwpCoreModuleInfo'
            MinimumHostVersion         = '0.2.0'
            Dependencies               = @()
            Capabilities               = @('HostServices', 'Undo', 'RestorePoint')
            SupportedPresentationModes = @()
            RequiredPermissions        = @('User', 'Administrator')
            ConfigurationSchema        = @{}
        }
        PSData = @{
            ProjectUri = 'https://github.com/wysockimarcin/mywindowspower'
        }
    }
}
