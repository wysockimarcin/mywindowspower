function Select-MwpStartupItem {
    <#
    .SYNOPSIS
        Filtruje pozycje autostartu (MWP.StartupItem): zakres, stan, ocena podpisu, tekst.

    .DESCRIPTION
        Czysta funkcja (bez odczytu z komputera) — używają jej Get-MwpStartupItem i widok
        Autostart (filtry ostatniego odczytu bez ponownego odczytu).

    .PARAMETER State
        All, Enabled, Disabled albo RunOnce (pozycje jednorazowe).

    .PARAMETER Risk
        All albo NotSigned (wszystko poza podpisanymi: niepodpisane, nieprawidłowy podpis, brak pliku, nieznane).

    .PARAMETER Search
        Tekst szukany w nazwie, poleceniu, wydawcy i nazwie użytkownika (bez rozróżniania wielkości liter).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]] $Item,

        [ValidateSet('All', 'Machine', 'User')]
        [string] $Scope = 'All',

        [ValidateSet('All', 'Enabled', 'Disabled', 'RunOnce')]
        [string] $State = 'All',

        [ValidateSet('All', 'NotSigned')]
        [string] $Risk = 'All',

        [AllowEmptyString()]
        [string] $Search = ''
    )

    $text = $Search.Trim()
    foreach ($entry in $Item) {
        if ($null -eq $entry) {
            continue
        }
        if ($Scope -ne 'All' -and $entry.Scope -ne $Scope) {
            continue
        }
        $matchesState = switch ($State) {
            'Enabled' { $entry.CanToggle -and $entry.Enabled }
            'Disabled' { $entry.CanToggle -and -not $entry.Enabled }
            'RunOnce' { -not $entry.CanToggle }
            default { $true }
        }
        if (-not $matchesState) {
            continue
        }
        if ($Risk -eq 'NotSigned' -and $entry.Risk -eq 'Signed') {
            continue
        }
        if ($text) {
            $haystack = @($entry.Name, $entry.Command, $entry.Publisher, $entry.UserName) -join ' '
            if ($haystack.IndexOf($text, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
                continue
            }
        }
        $entry
    }
}
