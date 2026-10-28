function Get-MwpUpdateSearchFilter {
    <#
    .SYNOPSIS
        Zwraca stałe kryteria IUpdateSearcher.Search dla rodzaju aktualizacji (oczekujące, nieukryte).

    .DESCRIPTION
        Kryteria nie są sklejane z danych użytkownika (D-015): trzy stałe teksty.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [ValidateSet('All', 'Software', 'Driver')]
        [string] $Type = 'All'
    )

    switch ($Type) {
        'Software' { "IsInstalled=0 and IsHidden=0 and Type='Software'" }
        'Driver' { "IsInstalled=0 and IsHidden=0 and Type='Driver'" }
        default { 'IsInstalled=0 and IsHidden=0' }
    }
}
