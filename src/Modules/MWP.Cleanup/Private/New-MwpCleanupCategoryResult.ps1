function New-MwpCleanupCategoryResult {
    <#
    .SYNOPSIS
        Składa wynik kategorii (MWP.CleanupCategoryResult) z definicji, rozwiniętych lokalizacji i surowego wyniku bloku Process.

    .DESCRIPTION
        Czysta funkcja. Liczby: FileCount/SizeBytes — pliki pasujące do kategorii (skan albo przed
        usunięciem), DeletedCount/DeletedBytes — usunięte, Skipped — pominięcia według powodu
        (z opisem po polsku), Samples — przykładowe pominięte ścieżki, Notes — lokalizacje niedostępne
        (administrator, odrzucone, profile niewybrane) i błędy lokalizacji.

    .PARAMETER RawRoot
        Pole Roots wyniku MWP.CleanupProcess (może być puste, gdy nic nie przetwarzano).

    .PARAMETER Mode
        Scan albo Delete (opis w Notes i pole Mode).
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Tworzy obiekt w pamięci (bez zmian systemu).')]
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [object] $Category,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]] $Root,

        [AllowEmptyCollection()]
        [object[]] $RawRoot = @(),

        [ValidateSet('Scan', 'Delete')]
        [string] $Mode = 'Scan'
    )

    $rawByKey = @{}
    foreach ($item in @($RawRoot | Where-Object { $null -ne $_ })) {
        $rawByKey[[string]$item.Key] = $item
    }
    $skipped = @{}
    $samples = New-Object -TypeName System.Collections.Generic.List[object]
    $notes = New-Object -TypeName System.Collections.Generic.List[string]
    $files = [long]0
    $bytes = [long]0
    $deleted = [long]0
    $deletedBytes = [long]0
    $directories = [long]0
    $cancelled = $false
    $rows = @()
    $unavailable = @{}

    foreach ($root in $Root) {
        $raw = if ($rawByKey.ContainsKey([string]$root.Key)) { $rawByKey[[string]$root.Key] } else { $null }
        $rootError = $null
        if (-not $root.Available) {
            if ($root.Reason -eq 'Rejected') {
                $notes.Add(('Odrzucono lokalizację: {0}' -f $root.ReasonText))
            }
            else {
                if (-not $unavailable.ContainsKey($root.Reason)) {
                    $unavailable[$root.Reason] = 0
                }
                $unavailable[$root.Reason]++
            }
        }
        elseif ($null -ne $raw) {
            $files += [long]$raw.Files
            $bytes += [long]$raw.Bytes
            $deleted += [long]$raw.Deleted
            $deletedBytes += [long]$raw.DeletedBytes
            $directories += [long]$raw.Directories
            if ($raw.Cancelled) {
                $cancelled = $true
            }
            if ($raw.Error) {
                $rootError = [string]$raw.Error
                $notes.Add(('{0}: {1}' -f $root.Path, $rootError))
            }
            foreach ($skip in @($raw.Skipped | Where-Object { $null -ne $_ })) {
                $reason = [string]$skip.Reason
                if (-not $skipped.ContainsKey($reason)) {
                    $skipped[$reason] = @([long]0, [long]0)
                }
                $skipped[$reason] = @(($skipped[$reason][0] + [long]$skip.Count), ($skipped[$reason][1] + [long]$skip.Bytes))
            }
            foreach ($sample in @($raw.Samples | Where-Object { $null -ne $_ })) {
                if ($samples.Count -lt 20) {
                    $samples.Add([pscustomobject]@{ Path = [string]$sample.Path; Reason = [string]$sample.Reason; ReasonText = Get-MwpCleanupText -Reason ([string]$sample.Reason) })
                }
            }
        }
        $rows += [pscustomobject]@{
            Path         = $root.Path
            Scope        = $root.Scope
            UserName     = $root.UserName
            Available    = [bool]$root.Available
            Reason       = $root.Reason
            ReasonText   = $root.ReasonText
            Exists       = $(if ($null -ne $raw) { [bool]$raw.Exists } else { $null })
            FileCount    = $(if ($null -ne $raw) { [long]$raw.Files } else { [long]0 })
            SizeBytes    = $(if ($null -ne $raw) { [long]$raw.Bytes } else { [long]0 })
            DeletedCount = $(if ($null -ne $raw) { [long]$raw.Deleted } else { [long]0 })
            DeletedBytes = $(if ($null -ne $raw) { [long]$raw.DeletedBytes } else { [long]0 })
            Error        = $rootError
        }
    }
    foreach ($reason in @($unavailable.Keys | Sort-Object)) {
        $notes.Add(('Pominięte lokalizacje ({0}): {1}.' -f $unavailable[$reason], (Get-MwpCleanupText -Reason $reason)))
    }
    $skippedRows = @(foreach ($reason in @($skipped.Keys | Sort-Object)) {
            [pscustomobject]@{
                Reason     = $reason
                ReasonText = Get-MwpCleanupText -Reason $reason
                Count      = $skipped[$reason][0]
                Bytes      = $skipped[$reason][1]
                SizeText   = Format-MwpCleanupSize -Bytes $skipped[$reason][1]
            }
        })
    $skippedCount = [long]0
    $skippedBytes = [long]0
    foreach ($row in $skippedRows) {
        $skippedCount += $row.Count
        $skippedBytes += $row.Bytes
    }
    # W trybie Delete pliki pasujące, których nie usunięto (w użyciu, brak dostępu, inny błąd), są w Skipped.
    [pscustomobject]@{
        PSTypeName         = 'MWP.CleanupCategoryResult'
        Id                 = $Category.Id
        Name               = $Category.Name
        Description        = $Category.Description
        Scope              = $Category.Scope
        Mode               = $Mode
        Available          = @($Root | Where-Object { $_.Available }).Count -gt 0
        FileCount          = $files
        SizeBytes          = $bytes
        SizeText           = Format-MwpCleanupSize -Bytes $bytes
        DeletedCount       = $deleted
        DeletedBytes       = $deletedBytes
        DeletedText        = Format-MwpCleanupSize -Bytes $deletedBytes
        DirectoriesRemoved = $directories
        SkippedCount       = $skippedCount
        SkippedBytes       = $skippedBytes
        SkippedText        = Format-MwpCleanupSize -Bytes $skippedBytes
        Skipped            = $skippedRows
        Samples            = $samples.ToArray()
        Notes              = $notes.ToArray()
        Roots              = $rows
        Cancelled          = $cancelled
    }
}
