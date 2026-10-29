function Resolve-MwpLogSummary {
    <#
    .SYNOPSIS
        Zamienia surowy wynik bloku podsumowania dziennika (JSON albo MWP.Result) na obiekt MWP.LogSummary.

    .DESCRIPTION
        Czysta funkcja (bez odczytu plików): wspólna dla Get-MwpLogSummary i widoku widgetu. Zwraca
        $null, gdy danych nie ma albo są nieczytelne.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Position = 0)]
        [AllowNull()]
        [object] $Data
    )

    if ($null -ne $Data -and $Data.PSObject.TypeNames -contains 'MWP.Result') {
        $Data = $Data.Data
    }
    if ($null -ne $Data -and $Data.PSObject.TypeNames -contains 'MWP.LogSummary') {
        return $Data
    }
    $item = @($Data | Where-Object { $null -ne $_ }) | Select-Object -Last 1
    if ($item -is [string]) {
        try {
            $item = ConvertFrom-Json -InputObject $item -ErrorAction Stop
        }
        catch {
            return $null
        }
    }
    if ($null -eq $item -or $null -eq $item.PSObject.Properties['Kind'] -or $item.Kind -ne 'MWP.LogSummaryRaw') {
        return $null
    }
    $count = {
        param([string] $Name)
        if ($null -ne $item.Counts -and $null -ne $item.Counts.PSObject.Properties[$Name]) { [int]$item.Counts.$Name } else { 0 }
    }
    [pscustomobject]@{
        PSTypeName   = 'MWP.LogSummary'
        ComputerName = [string]$item.ComputerName
        CollectedAt  = $(if ($item.CollectedAt) { [datetime]$item.CollectedAt } else { $null })
        LogPath      = [string]$item.LogPath
        LogExists    = [bool]$item.LogExists
        Counts       = [pscustomobject]@{ Info = & $count 'Info'; Warning = & $count 'Warning'; Error = & $count 'Error' }
        Entries      = @($item.Entries | Where-Object { $null -ne $_ } | ForEach-Object {
                [pscustomobject]@{
                    Timestamp = $(if ($_.Timestamp) { [datetime]$_.Timestamp } else { $null })
                    Level     = [string]$_.Level
                    Computer  = [string]$_.Computer
                    Operation = [string]$_.Operation
                    Message   = [string]$_.Message
                }
            })
        MatchCount   = [int]$item.MatchCount
        PendingUndo  = $(if ($null -ne $item.PendingUndo) { [int]$item.PendingUndo } else { $null })
        Warnings     = @($item.Warnings | Where-Object { $_ } | ForEach-Object { [string]$_ })
    }
}
