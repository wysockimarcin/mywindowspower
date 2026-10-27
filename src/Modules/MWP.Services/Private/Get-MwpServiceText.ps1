function Get-MwpServiceText {
    <#
    .SYNOPSIS
        Zwraca polską nazwę stanu usługi albo typu uruchomienia.

    .PARAMETER Status
        Stan usługi (Running, Stopped, StartPending… — także z odstępem, jak w Win32_Service).

    .PARAMETER StartupType
        Typ uruchomienia (Automatic, AutomaticDelayedStart, Manual, Disabled, Unknown).
    #>
    [CmdletBinding(DefaultParameterSetName = 'Status')]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Status')]
        [AllowEmptyString()]
        [string] $Status,

        [Parameter(Mandatory, ParameterSetName = 'StartupType')]
        [AllowEmptyString()]
        [string] $StartupType
    )

    if ($PSCmdlet.ParameterSetName -eq 'StartupType') {
        $item = @(Get-MwpServiceStartupTypeList | Where-Object { $_.Id -eq $StartupType }) | Select-Object -First 1
        if ($null -ne $item) {
            return $item.Label
        }
        return 'Nieznany'
    }
    switch ($Status -replace '\s', '') {
        'Running' { 'Działa' }
        'Stopped' { 'Zatrzymana' }
        'StartPending' { 'Uruchamianie' }
        'StopPending' { 'Zatrzymywanie' }
        'Paused' { 'Wstrzymana' }
        'PausePending' { 'Wstrzymywanie' }
        'ContinuePending' { 'Wznawianie' }
        default { 'Nieznany' }
    }
}
