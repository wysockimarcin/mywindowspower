function Get-MwpCleanupText {
    <#
    .SYNOPSIS
        Zwraca polski opis powodu pominięcia pliku albo niedostępności lokalizacji czyszczenia.

    .PARAMETER Reason
        Powód z bloku Process (InUse, AccessDenied, ReparsePoint, Protected, TooNew, OutsideRoot, Error)
        albo z ustalenia lokalizacji (RequiresAdmin, Rejected, NotFound, RootError, UserProfilesNotSelected).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Reason
    )

    switch ($Reason) {
        'InUse' { 'w użyciu (otwarte przez inny program)' }
        'AccessDenied' { 'brak dostępu' }
        'ReparsePoint' { 'dowiązanie (junction/symlink) — pominięte bez wchodzenia' }
        'Protected' { 'chroniona lokalizacja użytkownika (pulpit, dokumenty itp.)' }
        'TooNew' { 'nowsze niż próg wieku kategorii' }
        'OutsideRoot' { 'poza ścieżką kategorii' }
        'Error' { 'inny błąd' }
        'RequiresAdmin' { 'wymaga uprawnień administratora' }
        'Rejected' { 'ścieżka odrzucona przez zasady bezpieczeństwa' }
        'NotFound' { 'lokalizacja nie istnieje' }
        'RootError' { 'błąd lokalizacji' }
        'UserProfilesNotSelected' { 'profile użytkowników nie zostały wybrane' }
        default { $Reason }
    }
}
