function ConvertTo-MwpServiceStatusView {
    <#
    .SYNOPSIS
        Zamienia listę usług na widok widgetu „Status usług” (MWP.WidgetView): podsumowanie, obserwowane usługi, zatrzymane usługi automatyczne.

    .DESCRIPTION
        Funkcja widoku z kontraktu widgetu (D-043): czysta, bez WPF i bez wywołań systemowych.
        Przyjmuje wynik Get-MwpService (także surowy wynik operacji w tle). Parametr widgetu Names —
        obserwowane usługi (nazwy usług). Tony: działa — Success, zatrzymana automatyczna — Warning,
        brak usługi — Danger. Zwraca $null, gdy danych nie ma.

    .PARAMETER WidgetParameters
        Parametry widgetu: Names (lista nazw usług).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [AllowNull()]
        [object] $Data,

        [AllowNull()]
        [Collections.IDictionary] $WidgetParameters
    )

    if ($null -ne $Data -and $Data.PSObject.TypeNames -contains 'MWP.Result') {
        $Data = $Data.Data
    }
    $list = Resolve-MwpServiceList -Data $Data
    if ($null -eq $list) {
        return $null
    }
    $names = @()
    if ($null -ne $WidgetParameters -and $WidgetParameters.Contains('Names')) {
        $names = @($WidgetParameters['Names'] | Where-Object { $_ } | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_ })
    }
    $services = @($list.Services)
    $byName = @{}
    foreach ($service in $services) {
        $byName[$service.Name.ToLowerInvariant()] = $service
    }
    $row = {
        param([string] $Label, [string] $Value, [string] $Tone = 'Neutral')
        [pscustomobject]@{ Label = $Label; Value = $Value; Percent = -1; Tone = $Tone }
    }
    $running = @($services | Where-Object { $_.Status -eq 'Running' }).Count
    $stopped = @($services | Where-Object { $_.Status -eq 'Stopped' }).Count
    $autoStopped = @($services | Where-Object { $_.StartupType -eq 'Automatic' -and $_.Status -eq 'Stopped' })

    $summaryItems = @(
        & $row 'Działające' ([string]$running) 'Success'
        & $row 'Zatrzymane' ([string]$stopped)
        & $row 'Automatyczne zatrzymane' ([string]$autoStopped.Count) $(if ($autoStopped.Count -gt 0) { 'Warning' } else { 'Neutral' })
        & $row 'Wyłączone' ([string]@($services | Where-Object { $_.StartupType -eq 'Disabled' }).Count)
    )
    $watchItems = @(foreach ($name in $names) {
            $service = $byName[$name.ToLowerInvariant()]
            if ($null -eq $service) {
                & $row $name 'brak usługi' 'Danger'
                continue
            }
            $tone = if ($service.Status -eq 'Running') { 'Success' } elseif ($service.StartupType -in @('Automatic', 'AutomaticDelayedStart')) { 'Warning' } else { 'Neutral' }
            & $row $service.DisplayName ('{0} · {1}' -f $service.StatusText, $service.StartupTypeText) $tone
        })
    $sections = @()
    if ($watchItems.Count -gt 0) {
        $sections += [pscustomobject]@{ Title = 'Obserwowane'; Items = $watchItems }
    }
    $sections += [pscustomobject]@{ Title = 'Podsumowanie'; Items = $summaryItems }
    if ($autoStopped.Count -gt 0) {
        $items = @($autoStopped | Select-Object -First 8 | ForEach-Object { & $row $_.DisplayName $_.Name 'Warning' })
        if ($autoStopped.Count -gt 8) {
            $items += & $row ('… i {0} innych' -f ($autoStopped.Count - 8)) ''
        }
        $sections += [pscustomobject]@{ Title = 'Automatyczne, zatrzymane'; Items = $items }
    }
    [pscustomobject]@{
        PSTypeName  = 'MWP.WidgetView'
        Summary     = '{0} · działa {1} z {2} usług' -f $list.ComputerName, $running, $services.Count
        CollectedAt = $list.CollectedAt
        Sections    = $sections
        Warnings    = @($list.Warnings)
    }
}
