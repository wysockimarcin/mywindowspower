function Get-MwpUpdateViewOption {
    <#
    .SYNOPSIS
        Zwraca pozycje list widoku Windows Update: rodzaj wyszukiwania (SearchType) albo czas pauzy w tygodniach (PauseWeeks).

    .DESCRIPTION
        Pozycje { Value; Label }. Pauza: 1–5 tygodni (limit Ustawień Windows 11, D-048).

    .PARAMETER Kind
        SearchType albo PauseWeeks.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('SearchType', 'PauseWeeks')]
        [string] $Kind
    )

    if ($Kind -eq 'SearchType') {
        [pscustomobject]@{ Value = 'All'; Label = 'Wszystkie aktualizacje' }
        [pscustomobject]@{ Value = 'Software'; Label = 'Bez sterowników' }
        [pscustomobject]@{ Value = 'Driver'; Label = 'Tylko sterowniki' }
        return
    }
    foreach ($weeks in 1..5) {
        [pscustomobject]@{ Value = $weeks; Label = $(if ($weeks -eq 1) { '1 tydzień' } else { '{0} tygodnie' -f $weeks }) }
    }
}
