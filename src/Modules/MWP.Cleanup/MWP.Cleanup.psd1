@{
    RootModule           = 'MWP.Cleanup.psm1'
    ModuleVersion        = '0.9.1'
    GUID                 = 'a5b52230-b7e3-41a6-bfbb-aee0820a704a'
    Author               = 'wysockimarcin'
    CompanyName          = 'wysockimarcin'
    Copyright            = '(c) wysockimarcin. Projekt osobisty.'
    Description          = 'Czyszczenie dysku i plików tymczasowych.'
    PowerShellVersion    = '5.1'
    CompatiblePSEditions = @('Desktop', 'Core')
    FunctionsToExport    = @(
        'Clear-MwpCleanupCategory'
        'ConvertTo-MwpCleanupEstimateView'
        'ConvertTo-MwpCleanupReport'
        'Format-MwpCleanupSize'
        'Get-MwpCleanupCategory'
        'Get-MwpCleanupModuleInfo'
        'Get-MwpComponentStoreAnalysis'
        'Measure-MwpCleanupCategory'
        'Resolve-MwpCleanupScan'
        'Resolve-MwpComponentStoreAnalysis'
    )
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()
    PrivateData          = @{
        # Kontrakt modułu MyWindowsPower (ARCHITEKTURA.md, „Kontrakt modułu"; D-024).
        # Widok w oknie hosta: src\UI\Views\Cleanup.xaml (widok modułu wbudowanego, D-044, D-047).
        # Kategorie czyszczenia: Data\cleanup-categories.json (dane, nie kod; D-047).
        MWP    = @{
            ContractVersion            = 1
            Id                         = 'Cleanup'
            Name                       = 'Czyszczenie dysku'
            EntryPoint                 = 'Get-MwpCleanupModuleInfo'
            MinimumHostVersion         = '0.9.0'
            Dependencies               = @(
                @{ Id = 'Core'; MinimumVersion = '0.9.0' }
                @{ Id = 'Remote'; MinimumVersion = '0.5.0' }
            )
            Capabilities               = @('Read', 'Destructive', 'RemoteTarget')
            SupportedPresentationModes = @('Embedded', 'SeparateWindow', 'DashboardWidget')
            RequiredPermissions        = @('User', 'Administrator')
            ConfigurationSchema        = @{}
            Widgets                    = @(
                @{
                    Id                    = 'CleanupEstimate'
                    Name                  = 'Miejsce do odzyskania'
                    Description           = 'Ile miejsca zwolni czyszczenie (tylko skan, bez usuwania); do wyboru rozmiary kategorii. Skan trwa dłużej — domyślnie odświeżanie ręczne.'
                    DataCommand           = 'Measure-MwpCleanupCategory'
                    ViewCommand           = 'ConvertTo-MwpCleanupEstimateView'
                    DefaultRefreshSeconds = 0
                    Parameters            = @{
                        Categories     = @{
                            Type        = 'StringArray'
                            Default     = @('UserTemp', 'WindowsTemp', 'RecycleBin', 'ThumbnailCache', 'ErrorReports', 'WindowsUpdateDownload', 'DeliveryOptimization', 'Logs')
                            Values      = @('UserTemp', 'WindowsTemp', 'RecycleBin', 'ThumbnailCache', 'ErrorReports', 'WindowsUpdateDownload', 'DeliveryOptimization', 'Logs')
                            Label       = 'Skanowane kategorie'
                            ValueLabels = @{
                                UserTemp              = 'Pliki tymczasowe użytkownika'
                                WindowsTemp           = 'Pliki tymczasowe Windows'
                                RecycleBin            = 'Kosz'
                                ThumbnailCache        = 'Miniatury'
                                ErrorReports          = 'Raporty błędów (WER)'
                                WindowsUpdateDownload = 'Pobrane pliki Windows Update'
                                DeliveryOptimization  = 'Optymalizacja dostarczania'
                                Logs                  = 'Logi CBS i DISM'
                            }
                        }
                        ShowCategories = @{
                            Type    = 'Bool'
                            Default = $false
                            Label   = 'Pokazuj rozmiary kategorii'
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
