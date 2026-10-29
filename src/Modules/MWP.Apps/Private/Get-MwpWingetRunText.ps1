function Get-MwpWingetRunText {
    <#
    .SYNOPSIS
        Opis po polsku, w czyim kontekście winget wykona zmianę (podgląd, potwierdzenie i log, D-051).

    .DESCRIPTION
        Direct — konto aplikacji na tym komputerze; System — zadanie harmonogramu jako SYSTEM na
        komputerze docelowym; User — zadanie w sesji zalogowanego użytkownika (nazwa albo SID).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Direct', 'System', 'User')]
        [string] $RunAs,

        [AllowEmptyString()]
        [string] $UserName = '',

        [AllowEmptyString()]
        [string] $UserSid = ''
    )

    switch ($RunAs) {
        'Direct' { 'Kontekst: winget na koncie aplikacji ({0}).' -f [Environment]::UserName }
        'System' { 'Kontekst: winget jako SYSTEM (jednorazowe zadanie harmonogramu na komputerze docelowym).' }
        'User' { 'Kontekst: winget w sesji użytkownika {0} (jednorazowe zadanie harmonogramu, użytkownik musi być zalogowany).' -f $(if ($UserName) { $UserName } else { $UserSid }) }
    }
}
