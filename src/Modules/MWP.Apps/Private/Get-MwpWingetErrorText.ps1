function Get-MwpWingetErrorText {
    <#
    .SYNOPSIS
        Opis kodu wyjścia winget po polsku (kody HRESULT 0x8A15…) z ostatnimi liniami wyjścia.

    .DESCRIPTION
        Opisane są tylko kody sprawdzone na Windows 11 albo w dokumentacji winget (returnCodes);
        inne pokazujemy jako „kod 0x…” z ostatnią niepustą linią wyjścia (bez zgadywania znaczenia).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowNull()]
        [object] $ExitCode,

        [AllowEmptyCollection()]
        [AllowNull()]
        [string[]] $Line
    )

    $hex = if ($null -ne $ExitCode) { '0x{0:X8}' -f ([long]$ExitCode -band 0xFFFFFFFFL) } else { '' }
    $known = @{
        '0x8A150002' = 'niepoprawne argumenty wiersza poleceń winget'
        '0x8A150011' = 'skrót pobranego instalatora nie zgadza się z manifestem'
        '0x8A150014' = 'nie znaleziono pakietu pasującego do kryteriów'
        '0x8A150016' = 'kryteria pasują do wielu pakietów'
        '0x8A15002B' = 'brak aktualizacji do zainstalowania'
    }
    $last = @($Line | Where-Object { $_ -and $_.Trim() -and $_ -notmatch '^\s*[-\\|/]\s*$' }) | Select-Object -Last 1
    $text = if ($known.ContainsKey($hex)) { $known[$hex] } elseif ($hex) { 'kod {0}' -f $hex } else { 'brak kodu wyjścia' }
    if ($last) {
        '{0} ({1}): {2}' -f $text, $hex, ([string]$last).Trim()
    }
    else {
        $text
    }
}
