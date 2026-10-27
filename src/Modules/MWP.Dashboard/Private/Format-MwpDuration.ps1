function Format-MwpDuration {
    <#
    .SYNOPSIS
        Formatuje czas w sekundach jako tekst „2 d 3 h 15 min” (uptime).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowNull()]
        [object] $Seconds
    )

    if ($null -eq $Seconds) {
        return 'brak danych'
    }
    $span = [TimeSpan]::FromSeconds([double]$Seconds)
    if ($span.TotalMinutes -lt 1) {
        return 'poniżej minuty'
    }
    $parts = @()
    if ($span.Days -gt 0) {
        $parts += '{0} d' -f $span.Days
    }
    if ($span.Hours -gt 0 -or $span.Days -gt 0) {
        $parts += '{0} h' -f $span.Hours
    }
    $parts += '{0} min' -f $span.Minutes
    $parts -join ' '
}
