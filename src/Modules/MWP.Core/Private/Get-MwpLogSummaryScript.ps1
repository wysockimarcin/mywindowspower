function Get-MwpLogSummaryScript {
    <#
    .SYNOPSIS
        Zwraca samowystarczalny blok skryptu podsumowania dziennika operacji (widget „Dziennik operacji”, D-053).

    .DESCRIPTION
        Blok tylko czyta: dzisiejszy plik logu (JSON Lines) i pliki rejestru cofnięć. Zgodny z 5.1.
        Argument: żądanie JSON (LogPath, UndoPath, Levels, Top). Wynik: JSON z polem Kind = 'MWP.LogSummaryRaw'
        (liczby wpisów wg poziomu, ostatnie wpisy z wybranych poziomów, liczba zmian do cofnięcia, Warnings).
    #>
    [CmdletBinding()]
    [OutputType([scriptblock])]
    param()

    {
        param([string] $RequestJson)

        $request = ConvertFrom-Json -InputObject $RequestJson
        $warnings = New-Object -TypeName System.Collections.Generic.List[string]
        $counts = [ordered]@{ Info = 0; Warning = 0; Error = 0 }
        $entries = New-Object -TypeName System.Collections.Generic.List[object]
        $levels = @($request.Levels)
        $exists = Test-Path -LiteralPath $request.LogPath
        if ($exists) {
            try {
                $stream = New-Object -TypeName System.IO.FileStream -ArgumentList $request.LogPath, 'Open', 'Read', 'ReadWrite'
                $reader = New-Object -TypeName System.IO.StreamReader -ArgumentList $stream, ([Text.Encoding]::UTF8)
                try {
                    while ($null -ne ($line = $reader.ReadLine())) {
                        if ([string]::IsNullOrWhiteSpace($line)) { continue }
                        try { $entry = ConvertFrom-Json -InputObject $line -ErrorAction Stop } catch { continue }
                        $level = [string]$entry.level
                        if ($counts.Contains($level)) { $counts[$level]++ }
                        if ($levels -contains $level) {
                            $entries.Add([pscustomobject]@{
                                    Timestamp = [string]$entry.timestamp
                                    Level     = $level
                                    Computer  = [string]$entry.computer
                                    Operation = [string]$entry.operation
                                    Message   = [string]$entry.message
                                })
                        }
                    }
                }
                finally {
                    $reader.Dispose()
                }
            }
            catch {
                $warnings.Add(('Nie udało się odczytać dziennika: {0}' -f $_.Exception.Message))
            }
        }
        $pending = $null
        if ($request.UndoPath -and (Test-Path -LiteralPath $request.UndoPath)) {
            $pending = 0
            foreach ($file in @(Get-ChildItem -LiteralPath $request.UndoPath -Filter '*.json' -File -ErrorAction SilentlyContinue)) {
                try {
                    $undo = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
                    if ([string]$undo.status -eq 'Pending') { $pending++ }
                }
                catch {
                    continue
                }
            }
        }
        $top = [Math]::Max(1, [int]$request.Top)
        $recent = @($entries.ToArray() | Select-Object -Last $top)
        [array]::Reverse($recent)
        ConvertTo-Json -Compress -Depth 5 -InputObject ([pscustomobject]@{
                Kind         = 'MWP.LogSummaryRaw'
                ComputerName = $env:COMPUTERNAME
                CollectedAt  = (Get-Date).ToString('o')
                LogPath      = $request.LogPath
                LogExists    = $exists
                Counts       = [pscustomobject]$counts
                Entries      = $recent
                MatchCount   = $entries.Count
                PendingUndo  = $pending
                Warnings     = @($warnings)
            })
    }
}
