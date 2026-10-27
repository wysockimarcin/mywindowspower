function ConvertFrom-MwpPowercfgOutput {
    <#
    .SYNOPSIS
        Parsuje wynik powercfg niezależnie od języka systemu: listę planów, wartości ustawienia albo GUID-y.

    .DESCRIPTION
        Teksty powercfg (etykiety, nazwy planów) bywają przetłumaczone, więc parsowanie opiera się
        wyłącznie na strukturze, której język nie zmienia (D-044):
        - List: linie z GUID-em i nazwą w nawiasie, plan aktywny ma na końcu „*”
          („Power Scheme GUID: 381b…  (Zrównoważony) *” / „Identyfikator GUID schematu…”).
        - Query (/qh dla jednego ustawienia): dwie ostatnie linie zakończone wartością szesnastkową
          „: 0x…” to bieżące indeksy AC i DC (kolejność w powercfg jest stała; wcześniejsze linie
          z 0x to minimum, maksimum i krok). Brak takich linii = ustawienie niedostępne (np. pokrywa
          na komputerze stacjonarnym).
        - Guid: wszystkie GUID-y z tekstu (np. nowy plan z /duplicatescheme), małymi literami.

    .PARAMETER Line
        Linie wyjścia powercfg.

    .PARAMETER As
        List, Query albo Guid.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject], [string])]
    param(
        [AllowNull()]
        [AllowEmptyCollection()]
        [string[]] $Line,

        [Parameter(Mandatory)]
        [ValidateSet('List', 'Query', 'Guid')]
        [string] $As
    )

    $guidPattern = '[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}'
    $lines = @($Line | Where-Object { $null -ne $_ })
    switch ($As) {
        'List' {
            foreach ($text in $lines) {
                $match = [regex]::Match($text, ('({0})\s*(?:\((.*)\))?\s*(\*)?\s*$' -f $guidPattern))
                if (-not $match.Success) {
                    continue
                }
                [pscustomobject]@{
                    PSTypeName = 'MWP.PowerPlan'
                    Guid       = $match.Groups[1].Value.ToLowerInvariant()
                    Name       = $match.Groups[2].Value.Trim()
                    IsActive   = $match.Groups[3].Success
                }
            }
        }
        'Query' {
            $values = @(foreach ($text in $lines) {
                    $match = [regex]::Match($text, ':\s*0x([0-9A-Fa-f]{1,8})\s*$')
                    if ($match.Success) {
                        [Convert]::ToInt64($match.Groups[1].Value, 16)
                    }
                })
            if ($values.Count -lt 2) {
                [pscustomobject]@{ Available = $false; Ac = $null; Dc = $null }
            }
            else {
                [pscustomobject]@{ Available = $true; Ac = $values[$values.Count - 2]; Dc = $values[$values.Count - 1] }
            }
        }
        'Guid' {
            foreach ($text in $lines) {
                foreach ($match in [regex]::Matches($text, $guidPattern)) {
                    $match.Value.ToLowerInvariant()
                }
            }
        }
    }
}
