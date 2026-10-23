@{
    RootModule           = 'MWP.Tweaks.psm1'
    ModuleVersion        = '0.1.0'
    GUID                 = '8604797c-765b-4ef5-b91a-a2bceb777f19'
    Author               = 'wysockimarcin'
    CompanyName          = 'wysockimarcin'
    Copyright            = '(c) wysockimarcin. Projekt osobisty.'
    Description          = 'Prywatność i ustawienia systemu (tweaki rejestru).'
    PowerShellVersion    = '5.1'
    CompatiblePSEditions = @('Desktop', 'Core')
    FunctionsToExport    = @('Get-MwpTweaksModuleInfo')
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()
    PrivateData          = @{
        PSData = @{
            ProjectUri = 'https://github.com/wysockimarcin/mywindowspower'
        }
    }
}