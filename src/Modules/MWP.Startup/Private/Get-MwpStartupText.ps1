function Get-MwpStartupText {
    <#
    .SYNOPSIS
        Zwraca polski opis miejsca autostartu, stanu zadania albo rodzaju wyzwalacza.

    .PARAMETER Location
        Miejsce autostartu (MachineRun, MachineRun32, MachineRunOnce, MachineRunOnce32,
        MachineStartupFolder, UserRun, UserRunOnce, UserStartupFolder).

    .PARAMETER TaskState
        Stan zadania harmonogramu (Ready, Running, Disabled, Queued, Unknown).

    .PARAMETER Trigger
        Nazwa klasy CIM wyzwalacza (np. MSFT_TaskLogonTrigger).
    #>
    [CmdletBinding(DefaultParameterSetName = 'Location')]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Location')]
        [AllowEmptyString()]
        [string] $Location,

        [Parameter(Mandatory, ParameterSetName = 'TaskState')]
        [AllowEmptyString()]
        [string] $TaskState,

        [Parameter(Mandatory, ParameterSetName = 'Trigger')]
        [AllowEmptyString()]
        [string] $Trigger
    )

    switch ($PSCmdlet.ParameterSetName) {
        'Location' {
            switch ($Location) {
                'MachineRun' { 'HKLM …\Run' }
                'MachineRun32' { 'HKLM …\WOW6432Node\…\Run (32-bit)' }
                'MachineRunOnce' { 'HKLM …\RunOnce' }
                'MachineRunOnce32' { 'HKLM …\WOW6432Node\…\RunOnce (32-bit)' }
                'MachineStartupFolder' { 'Folder Autostart (wspólny)' }
                'UserRun' { 'Rejestr użytkownika …\Run' }
                'UserRunOnce' { 'Rejestr użytkownika …\RunOnce' }
                'UserStartupFolder' { 'Folder Autostart użytkownika' }
                default { 'Nieznane miejsce' }
            }
        }
        'TaskState' {
            switch ($TaskState) {
                'Ready' { 'Gotowe' }
                'Running' { 'Uruchomione' }
                'Disabled' { 'Wyłączone' }
                'Queued' { 'W kolejce' }
                default { 'Nieznany' }
            }
        }
        'Trigger' {
            switch ($Trigger -replace '^MSFT_Task', '' -replace 'Trigger$', '') {
                'Logon' { 'przy logowaniu' }
                'Boot' { 'przy uruchomieniu systemu' }
                'Daily' { 'codziennie' }
                'Weekly' { 'co tydzień' }
                'Monthly' { 'co miesiąc' }
                'MonthlyDOW' { 'co miesiąc' }
                'Time' { 'o określonej godzinie' }
                'Idle' { 'przy bezczynności' }
                'Event' { 'przy zdarzeniu' }
                'Registration' { 'po rejestracji' }
                'SessionStateChange' { 'przy zmianie sesji' }
                default { 'inny wyzwalacz' }
            }
        }
    }
}
