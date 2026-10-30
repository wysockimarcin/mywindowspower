@{
    RootModule           = 'MWP.Core.psm1'
    ModuleVersion        = '0.12.2'
    GUID                 = '49bd0d67-5058-467d-a21e-ef40a9d9710a'
    Author               = 'wysockimarcin'
    CompanyName          = 'wysockimarcin'
    Copyright            = '(c) wysockimarcin. Projekt osobisty.'
    Description          = 'Rdzeń: logowanie, konfiguracja, środowisko i elewacja, punkt przywracania, rejestr cofnięć, obiekt wyniku, lista ochronna, kontrakt i odkrywanie modułów, instalacja i odinstalowanie modułów z paczek, katalog danych aplikacji.'
    PowerShellVersion    = '5.1'
    CompatiblePSEditions = @('Desktop', 'Core')
    FunctionsToExport    = @(
        'ConvertTo-MwpLogSummaryView'
        'Format-MwpOperationTarget'
        'Get-MwpCoreModuleInfo'
        'Get-MwpDashboardConfiguration'
        'Get-MwpDataLocation'
        'Get-MwpEnvironment'
        'Get-MwpInstalledModule'
        'Get-MwpLogSummary'
        'Get-MwpModuleDefinition'
        'Get-MwpProtectedItem'
        'Get-MwpSetting'
        'Get-MwpUndoEntry'
        'Get-MwpWidgetDefinition'
        'Get-MwpWidgetSetting'
        'Install-MwpModulePackage'
        'Invoke-MwpUndo'
        'Move-MwpDataDirectory'
        'Move-MwpInstalledModule'
        'New-MwpRestorePoint'
        'New-MwpResult'
        'Remove-MwpDashboardWidget'
        'Rename-MwpUndoComputer'
        'Repair-MwpDashboardConfiguration'
        'Request-MwpElevation'
        'Resolve-MwpLogSummary'
        'Save-MwpUndoEntry'
        'Set-MwpDashboardConfiguration'
        'Set-MwpSetting'
        'Set-MwpWidgetSetting'
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
        # Widget „Dziennik operacji” (D-053): tylko komputer lokalny (LocalOnly) — dziennik leży w katalogu danych aplikacji.
        MWP    = @{
            ContractVersion            = 1
            Id                         = 'Core'
            Name                       = 'Rdzeń'
            EntryPoint                 = 'Get-MwpCoreModuleInfo'
            MinimumHostVersion         = '0.2.0'
            Dependencies               = @()
            Capabilities               = @('HostServices', 'Undo', 'RestorePoint')
            SupportedPresentationModes = @('DashboardWidget')
            RequiredPermissions        = @('User', 'Administrator')
            ConfigurationSchema        = @{}
            Widgets                    = @(
                @{
                    Id                    = 'OperationLog'
                    Name                  = 'Dziennik operacji'
                    Description           = 'Dzisiejsze błędy i ostrzeżenia aplikacji, ostatnie wpisy i liczba zmian do cofnięcia (komputer lokalny).'
                    DataCommand           = 'Get-MwpLogSummary'
                    ViewCommand           = 'ConvertTo-MwpLogSummaryView'
                    DefaultRefreshSeconds = 60
                    LocalOnly             = $true
                    Parameters            = @{
                        Levels = @{
                            Type        = 'StringArray'
                            Default     = @('Error')
                            Values      = @('Error', 'Warning', 'Info')
                            Label       = 'Ostatnie wpisy z poziomów'
                            ValueLabels = @{ Error = 'Błędy'; Warning = 'Ostrzeżenia'; Info = 'Informacje' }
                        }
                        Top    = @{
                            Type    = 'Int'
                            Default = 5
                            Label   = 'Liczba ostatnich wpisów (1–50)'
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
