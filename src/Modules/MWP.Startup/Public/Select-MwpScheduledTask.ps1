function Select-MwpScheduledTask {
    <#
    .SYNOPSIS
        Filtruje zadania harmonogramu (MWP.ScheduledTask): stan, zadania Microsoft, tylko chronione, tekst.

    .DESCRIPTION
        Czysta funkcja (bez odczytu z komputera) — używają jej Get-MwpScheduledTask i widok
        Harmonogram (filtry ostatniego odczytu bez ponownego odczytu).

    .PARAMETER State
        All, Enabled (gotowe, uruchomione, w kolejce), Disabled albo Running.

    .PARAMETER HideMicrosoft
        Ukrywa zadania z folderu \Microsoft\.

    .PARAMETER Search
        Tekst szukany w ścieżce, opisie, autorze, akcjach i wydawcy (bez rozróżniania wielkości liter).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]] $Task,

        [ValidateSet('All', 'Enabled', 'Disabled', 'Running')]
        [string] $State = 'All',

        [switch] $HideMicrosoft,

        [switch] $ProtectedOnly,

        [AllowEmptyString()]
        [string] $Search = ''
    )

    $text = $Search.Trim()
    foreach ($entry in $Task) {
        if ($null -eq $entry) {
            continue
        }
        $matchesState = switch ($State) {
            'Enabled' { $entry.Enabled }
            'Disabled' { -not $entry.Enabled }
            'Running' { $entry.State -eq 'Running' }
            default { $true }
        }
        if (-not $matchesState) {
            continue
        }
        if ($HideMicrosoft -and $entry.IsMicrosoft) {
            continue
        }
        if ($ProtectedOnly -and -not $entry.IsProtected) {
            continue
        }
        if ($text) {
            $haystack = @($entry.Path, $entry.Description, $entry.Author, $entry.ActionText, $entry.Publisher) -join ' '
            if ($haystack.IndexOf($text, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
                continue
            }
        }
        $entry
    }
}
