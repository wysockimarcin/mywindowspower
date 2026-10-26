function Read-MwpLogEntry {
    <#
    .SYNOPSIS
        Czyta ostatnie wpisy pliku logu (JSON Lines) do panelu logu okna.

    .DESCRIPTION
        Plik czytany jawnie jako UTF-8 (log jest zapisywany bez BOM; odczyt bez kodowania w 5.1 psuje
        polskie znaki), z udostępnieniem do zapisu i usuwania, bo inne wątki mogą w tym czasie
        dopisywać wpisy (D-026). Uszkodzone linie są pomijane. Wpisy od najnowszego.
        Operacja klasy Odczyt.

    .PARAMETER Path
        Ścieżka pliku logu (np. <katalog danych>\logs\mwp-RRRR-MM-DD.log).

    .PARAMETER Last
        Najwyżej tyle ostatnich wpisów.

    .PARAMETER MinimumLevel
        Najniższy poziom (Debug, Info, Warning, Error).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Path,

        [ValidateRange(1, 10000)]
        [int] $Last = 200,

        [ValidateSet('Debug', 'Info', 'Warning', 'Error')]
        [string] $MinimumLevel = 'Debug'
    )

    if (-not [IO.File]::Exists($Path)) {
        return
    }
    $levels = @{ Debug = 0; Info = 1; Warning = 2; Error = 3 }
    $share = [IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete
    $stream = New-Object -TypeName System.IO.FileStream -ArgumentList $Path, ([IO.FileMode]::Open), ([IO.FileAccess]::Read), $share
    try {
        $reader = New-Object -TypeName System.IO.StreamReader -ArgumentList $stream, ([Text.Encoding]::UTF8)
        $lines = $reader.ReadToEnd() -split "`r?`n"
        $reader.Dispose()
    }
    finally {
        $stream.Dispose()
    }

    $entries = New-Object -TypeName System.Collections.Generic.List[object]
    for ($index = $lines.Count - 1; $index -ge 0 -and $entries.Count -lt $Last; $index--) {
        $line = $lines[$index].Trim()
        if ($line -eq '') {
            continue
        }
        try {
            $data = ConvertFrom-Json -InputObject $line -ErrorAction Stop
        }
        catch {
            continue
        }
        $level = [string]$data.level
        if ($levels.ContainsKey($level) -and $levels[$level] -lt $levels[$MinimumLevel]) {
            continue
        }
        $time = $data.timestamp
        if ($time -isnot [datetime]) {
            $parsed = [datetime]::MinValue
            if ([datetime]::TryParse([string]$time, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::RoundtripKind, [ref]$parsed)) {
                $time = $parsed
            }
        }
        $entries.Add([pscustomobject]@{
                PSTypeName = 'MWP.UiLogEntry'
                Time       = $time
                TimeText   = $(if ($time -is [datetime]) { $time.ToLocalTime().ToString('HH:mm:ss') } else { [string]$time })
                Level      = $level
                Computer   = [string]$data.computer
                Source     = [string]$data.source
                Operation  = [string]$data.operation
                Message    = [string]$data.message
            })
    }
    $entries.ToArray()
}
