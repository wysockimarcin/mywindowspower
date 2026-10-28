function Resolve-MwpUpdatePause {
    <#
    .SYNOPSIS
        Zwraca stan pauzy (MWP.UpdatePause) z wartości rejestru pauzy: aktywna, od, do, opis po polsku.

    .DESCRIPTION
        Pauza jest aktywna, gdy PauseUpdatesExpiryTime (a bez niej PauseQualityUpdatesEndTime) jest
        późniejszy niż -Now. Wartości pozostają w postaci tekstowej (Values) — do zapisu we wpisie
        cofnięcia.

    .PARAMETER Values
        Nazwa wartości → tekst ISO 8601 albo $null.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [hashtable] $Values,

        [datetime] $Now = (Get-Date)
    )

    $until = ConvertFrom-MwpUpdateDate -Value $Values['PauseUpdatesExpiryTime']
    if ($null -eq $until) {
        $until = ConvertFrom-MwpUpdateDate -Value $Values['PauseQualityUpdatesEndTime']
    }
    $from = ConvertFrom-MwpUpdateDate -Value $Values['PauseUpdatesStartTime']
    if ($null -eq $from) {
        $from = ConvertFrom-MwpUpdateDate -Value $Values['PauseQualityUpdatesStartTime']
    }
    $isPaused = $null -ne $until -and $until -gt $Now
    $hasValues = @($Values.Values | Where-Object { $null -ne $_ }).Count -gt 0
    $text = if ($isPaused) {
        'Aktualizacje wstrzymane do {0:yyyy-MM-dd HH:mm}.' -f $until
    }
    elseif ($hasValues -and $null -ne $until) {
        'Pauza wygasła {0:yyyy-MM-dd HH:mm} — aktualizacje są wznowione.' -f $until
    }
    else {
        'Aktualizacje nie są wstrzymane.'
    }
    [pscustomobject]@{
        PSTypeName  = 'MWP.UpdatePause'
        IsPaused    = $isPaused
        PausedFrom  = $from
        PausedUntil = $until
        HasValues   = $hasValues
        Values      = $Values
        Text        = $text
    }
}
