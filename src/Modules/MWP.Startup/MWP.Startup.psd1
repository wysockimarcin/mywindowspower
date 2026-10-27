@{
    RootModule           = 'MWP.Startup.psm1'
    ModuleVersion        = '0.8.0'
    GUID                 = '3f086f85-a2b1-49c1-9e22-870c45c11274'
    Author               = 'wysockimarcin'
    CompanyName          = 'wysockimarcin'
    Copyright            = '(c) wysockimarcin. Projekt osobisty.'
    Description          = 'Programy w autostarcie i zadania harmonogramu.'
    PowerShellVersion    = '5.1'
    CompatiblePSEditions = @('Desktop', 'Core')
    FunctionsToExport    = @(
        'Get-MwpScheduledTask'
        'Get-MwpSignatureRisk'
        'Get-MwpStartupItem'
        'Get-MwpStartupModuleInfo'
        'Remove-MwpScheduledTask'
        'Resolve-MwpScheduledTaskList'
        'Resolve-MwpStartupItemList'
        'Restore-MwpScheduledTask'
        'Select-MwpScheduledTask'
        'Select-MwpStartupItem'
        'Set-MwpScheduledTaskState'
        'Set-MwpStartupItemState'
        'Start-MwpScheduledTask'
        'Test-MwpScheduledTaskName'
    )
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()
    PrivateData          = @{
        # Kontrakt modułu MyWindowsPower (ARCHITEKTURA.md, „Kontrakt modułu"; D-024).
        # Widok w oknie hosta: src\UI\Views\Startup.xaml (widok modułu wbudowanego, D-044, D-046).
        MWP    = @{
            ContractVersion            = 1
            Id                         = 'Startup'
            Name                       = 'Autostart i harmonogram'
            EntryPoint                 = 'Get-MwpStartupModuleInfo'
            MinimumHostVersion         = '0.8.0'
            Dependencies               = @(
                @{ Id = 'Core'; MinimumVersion = '0.8.0' }
                @{ Id = 'Remote'; MinimumVersion = '0.5.0' }
            )
            Capabilities               = @('Read', 'Change', 'Undo', 'RemoteTarget')
            SupportedPresentationModes = @('Embedded', 'SeparateWindow')
            RequiredPermissions        = @('User', 'Administrator')
            ConfigurationSchema        = @{}
        }
        PSData = @{
            ProjectUri = 'https://github.com/wysockimarcin/mywindowspower'
        }
    }
}
