function Exit-MwpCredentialLock {
    <#
    .SYNOPSIS
        Zwalnia blokadę poświadczeń komputera zajętą przez Enter-MwpCredentialLock.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $ComputerName
    )

    $semaphore = (Get-MwpCredentialCache).Locks[$ComputerName]
    if ($null -ne $semaphore) {
        $null = $semaphore.Release()
    }
}
