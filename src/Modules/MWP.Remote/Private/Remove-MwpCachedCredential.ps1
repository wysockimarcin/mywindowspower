function Remove-MwpCachedCredential {
    <#
    .SYNOPSIS
        Usuwa poświadczenie komputera (także stan Invalid) z pamięci podręcznej procesu; bez nazwy — wszystkie.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Zmienia tylko pamięć procesu; nie zmienia systemu.')]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [AllowEmptyString()]
        [string] $ComputerName
    )

    $cache = Get-MwpCredentialCache
    [Threading.Monitor]::Enter($cache.SyncRoot)
    try {
        if ([string]::IsNullOrEmpty($ComputerName)) {
            $had = $cache.Entries.Count -gt 0
            $cache.Entries.Clear()
            return $had
        }
        $had = $cache.Entries.ContainsKey($ComputerName)
        $cache.Entries.Remove($ComputerName)
        $had
    }
    finally {
        [Threading.Monitor]::Exit($cache.SyncRoot)
    }
}
