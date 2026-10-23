function Close-MwpOperationPool {
    <#
    .SYNOPSIS
        Anuluje operacje w toku i zamyka pulę runspace'ów (przy usuwaniu modułu z sesji).
    #>
    [CmdletBinding()]
    param()

    foreach ($operation in @($script:MwpOperationRegistry.Values)) {
        if ($operation.Status -eq 'Running') {
            try {
                $operation.PowerShell.Stop()
            }
            catch {
                Write-Verbose ("Nie udało się zatrzymać operacji {0}: {1}" -f $operation.Id, $_.Exception.Message)
            }
            $operation.Status = 'Cancelled'
        }
        if ($null -ne $operation.PowerShell) {
            $operation.PowerShell.Dispose()
            $operation.PowerShell = $null
        }
    }
    $script:MwpOperationRegistry.Clear()

    if ($null -ne $script:MwpOperationPool) {
        $script:MwpOperationPool.Close()
        $script:MwpOperationPool.Dispose()
        $script:MwpOperationPool = $null
    }
}
