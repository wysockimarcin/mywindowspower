function Get-MwpCachedCredential {
    <#
    .SYNOPSIS
        Zwraca kopię wpisu pamięci podręcznej poświadczeń dla komputera albo $null.

    .DESCRIPTION
        Pola: Credential (PSCredential albo $null przy stanie Invalid), State (Verified — przeszło
        uwierzytelnienie w tym uruchomieniu; Invalid — odrzucone, automatyczne ponowienia wstrzymane),
        Generation, UserName, Source (Dialog | Store | Context), ChangedAt.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $ComputerName
    )

    $entry = (Get-MwpCredentialCache).Entries[$ComputerName]
    if ($null -eq $entry) {
        return $null
    }
    $entry.Clone()
}
