function Set-MwpCachedCredential {
    <#
    .SYNOPSIS
        Zapisuje sprawdzone poświadczenie komputera w pamięci podręcznej procesu (stan Verified); zwraca numer generacji.

    .DESCRIPTION
        Wywoływana po udanym uwierzytelnieniu (Connect-MwpTarget), więc w pamięci jest tylko hasło,
        które komputer przyjął. Jedno poświadczenie na komputer (D-052): nowe zastępuje poprzednie
        i znosi stan Invalid; konteksty tego komputera używają go przy następnym połączeniu lub operacji.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Zmienia tylko pamięć procesu; nie zmienia systemu.')]
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $ComputerName,

        [Parameter(Mandatory)]
        [pscredential] $Credential,

        [ValidateSet('Dialog', 'Store', 'Context')]
        [string] $Source = 'Dialog'
    )

    $cache = Get-MwpCredentialCache
    [Threading.Monitor]::Enter($cache.SyncRoot)
    try {
        $generation = [int]$cache['Generation'] + 1
        $cache['Generation'] = $generation
        $cache.Entries[$ComputerName] = @{
            Credential = $Credential
            State      = 'Verified'
            Generation = $generation
            UserName   = $Credential.UserName
            Source     = $Source
            ChangedAt  = Get-Date
        }
    }
    finally {
        [Threading.Monitor]::Exit($cache.SyncRoot)
    }
    $generation
}
