@{
    RootModule           = 'MWP.Apps.psm1'
    ModuleVersion        = '0.12.2'
    GUID                 = '4c98673e-01c8-4b33-84f6-94d3122f4e0c'
    Author               = 'wysockimarcin'
    CompanyName          = 'wysockimarcin'
    Copyright            = '(c) wysockimarcin. Projekt osobisty.'
    Description          = 'Aplikacje: lista programów (rejestr, Appx), winget — aktualizacje, wyszukiwanie, instalacja — i odinstalowanie z listą ochronną.'
    PowerShellVersion    = '5.1'
    CompatiblePSEditions = @('Desktop', 'Core')
    FunctionsToExport    = @(
        'ConvertFrom-MwpWingetOutput'
        'ConvertTo-MwpAppsSummaryView'
        'ConvertTo-MwpAppsUpdatesView'
        'Find-MwpWingetPackage'
        'Get-MwpAppsModuleInfo'
        'Get-MwpInstalledApp'
        'Get-MwpWingetInfo'
        'Get-MwpWingetPackage'
        'Get-MwpWingetUpgrade'
        'Install-MwpWingetPackage'
        'Join-MwpAppWinget'
        'Resolve-MwpInstalledApp'
        'Resolve-MwpWingetPackage'
        'Select-MwpInstalledApp'
        'Uninstall-MwpApp'
        'Update-MwpWingetPackage'
    )
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()
    PrivateData          = @{
        # Kontrakt modułu MyWindowsPower (ARCHITEKTURA.md, „Kontrakt modułu"; D-024).
        # Widok w oknie hosta: src\UI\Views\Apps.xaml (widok modułu wbudowanego, D-044, D-050).
        # 0.12.1 (korekta D-051): winget na komputerze zdalnym przez jednorazowe zadania harmonogramu (SYSTEM i sesja zalogowanego użytkownika).
        MWP    = @{
            ContractVersion            = 1
            Id                         = 'Apps'
            Name                       = 'Aplikacje'
            EntryPoint                 = 'Get-MwpAppsModuleInfo'
            MinimumHostVersion         = '0.12.0'
            Dependencies               = @(
                @{ Id = 'Core'; MinimumVersion = '0.12.0' }
                @{ Id = 'Remote'; MinimumVersion = '0.5.0' }
            )
            Capabilities               = @('Read', 'Change', 'Destructive', 'Undo', 'RemoteTarget')
            SupportedPresentationModes = @('Embedded', 'SeparateWindow', 'DashboardWidget')
            RequiredPermissions        = @('User', 'Administrator')
            ConfigurationSchema        = @{}
            Widgets                    = @(
                @{
                    Id                    = 'AppsSummary'
                    Name                  = 'Programy'
                    Description           = 'Liczba zainstalowanych programów i aplikacji Appx; do wyboru największe i ostatnio zainstalowane (bez winget).'
                    DataCommand           = 'Get-MwpInstalledApp'
                    ViewCommand           = 'ConvertTo-MwpAppsSummaryView'
                    DefaultRefreshSeconds = 900
                    Parameters            = @{
                        Sections = @{
                            Type        = 'StringArray'
                            Default     = @('Summary')
                            Values      = @('Summary', 'Largest', 'Recent')
                            Label       = 'Sekcje'
                            ValueLabels = @{ Summary = 'Podsumowanie'; Largest = 'Największe'; Recent = 'Ostatnio zainstalowane' }
                        }
                        Top      = @{
                            Type    = 'Int'
                            Default = 5
                            Label   = 'Liczba pozycji na listach'
                        }
                    }
                }
                @{
                    Id                    = 'AppsUpdates'
                    Name                  = 'Aktualizacje programów'
                    Description           = 'Pakiety winget z dostępną aktualizacją. Odczyt trwa kilka–kilkanaście sekund; na komputerze zdalnym wymaga konta administratora.'
                    DataCommand           = 'Get-MwpWingetUpgrade'
                    ViewCommand           = 'ConvertTo-MwpAppsUpdatesView'
                    DefaultRefreshSeconds = 0
                    Parameters            = @{
                        Top = @{
                            Type    = 'Int'
                            Default = 5
                            Label   = 'Liczba pakietów na liście'
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