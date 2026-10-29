function Clear-MwpTargetCredentialCache {
    <#
    .SYNOPSIS
        Czyści pamięć podręczną poświadczeń procesu (wszystkie komputery); Menedżer poświadczeń bez zmian.

    .DESCRIPTION
        Wywoływana przy zamknięciu okna aplikacji (D-052): gdy okno działało w otwartej konsoli
        PowerShella, hasła nie zostają w pamięci tej konsoli. Otwarte połączenia z sesją działają dalej
        do rozłączenia; nowe połączenia zapytają o hasło albo użyją wpisu z magazynu po „Połącz”.
        Zwraca $true, gdy pamięć nie była pusta.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Czyści tylko pamięć procesu; nie zmienia systemu ani konfiguracji.')]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Remove-MwpCachedCredential
}
