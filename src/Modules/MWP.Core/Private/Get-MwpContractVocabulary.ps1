function Get-MwpContractVocabulary {
    <#
    .SYNOPSIS
        Zwraca dozwolone wartości pól kontraktu modułu (PrivateData.MWP w manifeście).

    .DESCRIPTION
        Jedno źródło słownika kontraktu; opis znaczenia wartości jest w ARCHITEKTURA.md
        (sekcja „Kontrakt modułu"). Zmiana słownika wymaga wpisu w DECYZJE.md.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    @{
        ContractVersions    = @(1)
        RequiredFields      = @(
            'ContractVersion', 'Id', 'Name', 'EntryPoint', 'MinimumHostVersion', 'Dependencies',
            'Capabilities', 'SupportedPresentationModes', 'RequiredPermissions', 'ConfigurationSchema'
        )
        Capabilities        = @('HostServices', 'Read', 'Change', 'Destructive', 'Undo', 'RestorePoint', 'RemoteTarget')
        PresentationModes   = @('Embedded', 'SeparateWindow', 'DashboardWidget', 'Standalone', 'CLI')
        Permissions         = @('User', 'Administrator')
        ConfigurationTypes  = @('String', 'Int', 'Bool', 'StringArray')
        # Widgety Dashboardu (opcjonalne pole Widgets, D-043): odświeżanie w sekundach (0 = tylko ręcznie) i rozmiar kafelka.
        WidgetRefreshSeconds = @(0, 30, 60, 300, 900)
        WidgetSizes          = @('Normal', 'Wide')
    }
}
