@{
    RootModule           = 'MWP.Core.psm1'
    ModuleVersion        = '0.1.0'
    GUID                 = '49bd0d67-5058-467d-a21e-ef40a9d9710a'
    Author               = 'wysockimarcin'
    CompanyName          = 'wysockimarcin'
    Copyright            = '(c) wysockimarcin. Projekt osobisty.'
    Description          = 'Rdzeń: logowanie, konfiguracja, dry-run, cofanie zmian, punkt przywracania, elewacja.'
    PowerShellVersion    = '5.1'
    CompatiblePSEditions = @('Desktop', 'Core')
    FunctionsToExport    = @('Get-MwpCoreModuleInfo')
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()
    PrivateData          = @{
        PSData = @{
            ProjectUri = 'https://github.com/wysockimarcin/mywindowspower'
        }
    }
}