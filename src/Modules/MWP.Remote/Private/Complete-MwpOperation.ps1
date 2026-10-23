function Complete-MwpOperation {
    <#
    .SYNOPSIS
        Kończy operację asynchroniczną: zapisuje status i wynik, zwalnia PowerShell i wyrejestrowuje ją.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [PSTypeName('MWP.Operation')]
        [object] $Operation,

        [Parameter(Mandatory)]
        [ValidateSet('Completed', 'Failed', 'Cancelled', 'TimedOut')]
        [string] $Status,

        [Parameter(Mandatory)]
        [PSTypeName('MWP.Result')]
        [object] $Result
    )

    $Operation.Status = $Status
    $Operation.Result = $Result
    $Operation.CompletedAt = Get-Date
    if ($null -ne $Operation.PowerShell) {
        $Operation.PowerShell.Dispose()
        $Operation.PowerShell = $null
    }
    $Operation.AsyncResult = $null
    $script:MwpOperationRegistry.Remove($Operation.Id)

    $level = if ($Status -eq 'Completed') { 'Debug' } else { 'Warning' }
    Write-MwpLog -Level $level -Source 'MWP.Remote' -Operation $Operation.Operation -ComputerName $Operation.ComputerName -Message $Result.Message `
        -Data @{ OperationId = $Operation.Id; Status = $Status; InstanceId = $Operation.InstanceId }
    $Result
}
