function Get-MwpOperationPool {
    <#
    .SYNOPSIS
        Zwraca otwartą pulę runspace'ów dla operacji asynchronicznych (tworzy ją przy pierwszym użyciu).

    .DESCRIPTION
        Model wykonywania D-023: długie i zdalne operacje działają w puli runspace'ów procesu hosta.
        Limit równoległości pochodzi z ustawienia remoteMaxParallelOperations (1–64, domyślnie 4);
        nadmiarowe operacje czekają w kolejce puli. Zmiana ustawienia działa po ponownym
        uruchomieniu aplikacji (albo po zamknięciu puli, gdy nie ma operacji w toku).
    #>
    [CmdletBinding()]
    [OutputType([Management.Automation.Runspaces.RunspacePool])]
    param()

    $pool = $script:MwpOperationPool
    if ($null -ne $pool -and $pool.RunspacePoolStateInfo.State -eq [Management.Automation.Runspaces.RunspacePoolState]::Opened) {
        return $pool
    }
    $maximum = Get-MwpRemoteSetting -Name 'remoteMaxParallelOperations' -Default 4 -Minimum 1 -Maximum 64
    $pool = [runspacefactory]::CreateRunspacePool(1, $maximum)
    $pool.Open()
    $script:MwpOperationPool = $pool
    $pool
}
