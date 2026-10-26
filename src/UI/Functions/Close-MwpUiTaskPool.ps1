function Close-MwpUiTaskPool {
    <#
    .SYNOPSIS
        Zatrzymuje zadania GUI w tle i zamyka ich pulę runspace'ów (przy zamykaniu okna).
    #>
    [CmdletBinding()]
    param(
        [AllowEmptyCollection()]
        [Collections.Generic.List[object]] $Registry,

        [AllowNull()]
        [Management.Automation.Runspaces.RunspacePool] $Pool
    )

    if ($null -ne $Registry) {
        foreach ($task in @($Registry.ToArray())) {
            try {
                if ($task.Kind -eq 'Operation') {
                    $null = Stop-MwpOperation -Operation $task.Operation -Confirm:$false
                }
                elseif ($null -ne $task.PowerShell) {
                    $task.PowerShell.Stop()
                    $task.PowerShell.Dispose()
                }
            }
            catch {
                Write-Verbose ("Zatrzymanie zadania '{0}': {1}" -f $task.Name, $_.Exception.Message)
            }
        }
        $Registry.Clear()
    }
    if ($null -ne $Pool) {
        $Pool.Close()
        $Pool.Dispose()
    }
}
