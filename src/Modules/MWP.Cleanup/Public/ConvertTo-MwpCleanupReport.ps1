function ConvertTo-MwpCleanupReport {
    <#
    .SYNOPSIS
        Składa raport po czyszczeniu z wyników Clear-MwpCleanupCategory: ile zwolniono, ile pominięto i dlaczego.

    .DESCRIPTION
        Czysta funkcja (bez wywołań systemowych). Pomija wyniki podglądu (-WhatIf). Zwraca
        MWP.CleanupReport: FreedBytes/FreedText, DeletedCount, DirectoriesRemoved, SkippedCount,
        SkippedBytes, Reasons (powody pominięcia z opisem po polsku), Categories (wiersz na kategorię
        z komunikatem), Failed (kategorie z błędem) i Text — raport tekstowy do okna i CLI.

    .PARAMETER Result
        Wyniki MWP.Result z Clear-MwpCleanupCategory (także z potoku).

    .PARAMETER Cancelled
        Czyszczenie przerwane przez użytkownika (dopisek w raporcie).

    .EXAMPLE
        (Clear-MwpCleanupCategory -Category UserTemp -Confirm:$false | ConvertTo-MwpCleanupReport).Text
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [AllowEmptyCollection()]
        [AllowNull()]
        [object[]] $Result,

        [switch] $Cancelled
    )

    begin {
        $all = New-Object -TypeName System.Collections.Generic.List[object]
    }
    process {
        foreach ($item in @($Result | Where-Object { $null -ne $_ -and $_.PSObject.TypeNames -contains 'MWP.Result' -and -not $_.IsPreview })) {
            $all.Add($item)
        }
    }
    end {
        $reasons = @{}
        $rows = New-Object -TypeName System.Collections.Generic.List[object]
        $freed = [long]0
        $deleted = [long]0
        $directories = [long]0
        $skippedCount = [long]0
        $skippedBytes = [long]0
        $failed = 0
        $wasCancelled = [bool]$Cancelled
        $computerName = ''
        foreach ($item in $all) {
            if (-not $computerName) {
                $computerName = [string]$item.ComputerName
            }
            $data = $item.Data
            $isCategory = $null -ne $data -and $data.PSObject.TypeNames -contains 'MWP.CleanupCategoryResult'
            if (-not $item.Success) {
                $failed++
            }
            if ($isCategory -and $data.Mode -eq 'Delete') {
                $freed += [long]$data.DeletedBytes
                $deleted += [long]$data.DeletedCount
                $directories += [long]$data.DirectoriesRemoved
                if ($data.Cancelled) {
                    $wasCancelled = $true
                }
            }
            if ($isCategory) {
                $skippedCount += [long]$data.SkippedCount
                $skippedBytes += [long]$data.SkippedBytes
                foreach ($skip in @($data.Skipped)) {
                    if (-not $reasons.ContainsKey($skip.Reason)) {
                        $reasons[$skip.Reason] = @([long]0, [long]0)
                    }
                    $reasons[$skip.Reason] = @(($reasons[$skip.Reason][0] + [long]$skip.Count), ($reasons[$skip.Reason][1] + [long]$skip.Bytes))
                }
            }
            $rows.Add([pscustomobject]@{
                    Id           = $(if ($isCategory) { $data.Id } else { [string]$item.Target })
                    Name         = $(if ($isCategory) { $data.Name } else { [string]$item.Target })
                    Success      = [bool]$item.Success
                    Changed      = [bool]$item.Changed
                    DeletedCount = $(if ($isCategory -and $data.Mode -eq 'Delete') { [long]$data.DeletedCount } else { [long]0 })
                    DeletedText  = Format-MwpCleanupSize -Bytes $(if ($isCategory -and $data.Mode -eq 'Delete') { $data.DeletedBytes } else { 0 })
                    SkippedCount = $(if ($isCategory) { [long]$data.SkippedCount } else { [long]0 })
                    SkippedText  = Format-MwpCleanupSize -Bytes $(if ($isCategory) { $data.SkippedBytes } else { 0 })
                    Message      = [string]$item.Message
                })
        }
        $reasonRows = @(foreach ($reason in @($reasons.Keys | Sort-Object)) {
                [pscustomobject]@{
                    Reason     = $reason
                    ReasonText = Get-MwpCleanupText -Reason $reason
                    Count      = $reasons[$reason][0]
                    Bytes      = $reasons[$reason][1]
                    SizeText   = Format-MwpCleanupSize -Bytes $reasons[$reason][1]
                }
            })

        $createdAt = Get-Date
        $lines = New-Object -TypeName System.Collections.Generic.List[string]
        $lines.Add(('Raport czyszczenia — komputer {0}, {1}' -f $(if ($computerName) { $computerName } else { '?' }), $createdAt.ToString('yyyy-MM-dd HH:mm')))
        if ($wasCancelled) {
            $lines.Add('Czyszczenie przerwane przez użytkownika — raport obejmuje pliki usunięte do chwili przerwania.')
        }
        $lines.Add(('Zwolniono: {0} (usunięte pliki: {1}, puste foldery: {2}).' -f (Format-MwpCleanupSize -Bytes $freed), $deleted, $directories))
        if ($skippedCount -gt 0) {
            $lines.Add(('Pominięto: {0} plików ({1}):' -f $skippedCount, (Format-MwpCleanupSize -Bytes $skippedBytes)))
            foreach ($row in $reasonRows) {
                $lines.Add(('  • {0}: {1} ({2})' -f $row.ReasonText, $row.Count, $row.SizeText))
            }
        }
        else {
            $lines.Add('Pominięto: 0 plików.')
        }
        if ($rows.Count -gt 0) {
            $lines.Add('Kategorie:')
            foreach ($row in $rows) {
                $state = if (-not $row.Success) { 'BŁĄD' } elseif ($row.Changed) { 'OK' } else { 'bez zmian' }
                $lines.Add(('  • [{0}] {1}' -f $state, $row.Message))
            }
        }
        $lines.Add('Usuniętych plików nie można przywrócić z aplikacji.')

        [pscustomobject]@{
            PSTypeName         = 'MWP.CleanupReport'
            ComputerName       = $computerName
            CreatedAt          = $createdAt
            Cancelled          = $wasCancelled
            FreedBytes         = $freed
            FreedText          = Format-MwpCleanupSize -Bytes $freed
            DeletedCount       = $deleted
            DirectoriesRemoved = $directories
            SkippedCount       = $skippedCount
            SkippedBytes       = $skippedBytes
            SkippedText        = Format-MwpCleanupSize -Bytes $skippedBytes
            Reasons            = $reasonRows
            Categories         = $rows.ToArray()
            Failed             = $failed
            Text               = $lines -join [Environment]::NewLine
        }
    }
}
