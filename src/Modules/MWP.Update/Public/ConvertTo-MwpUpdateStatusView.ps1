function ConvertTo-MwpUpdateStatusView {
    <#
    .SYNOPSIS
        Zamienia stan Windows Update na widok widgetu „Windows Update” (MWP.WidgetView): restart, pauza, ostatnie wyszukiwanie i instalacja, usługi.

    .DESCRIPTION
        Funkcja widoku z kontraktu widgetu (D-043, D-053): czysta, bez WPF i bez wywołań systemowych.
        Przyjmuje wynik Get-MwpUpdateStatus (także surowy wynik operacji w tle). Parametr widgetu
        Sections wybiera sekcje: Restart, Pause, LastActivity, Services (domyślnie Restart i Pause —
        minimum miejsca). Zwraca $null, gdy danych nie ma.

    .PARAMETER WidgetParameters
        Parametry widgetu: Sections (lista sekcji).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [AllowNull()]
        [object] $Data,

        [AllowNull()]
        [Collections.IDictionary] $WidgetParameters
    )

    $status = Resolve-MwpUpdateStatus -Data $Data
    if ($null -eq $status) {
        return $null
    }
    $all = @('Restart', 'Pause', 'LastActivity', 'Services')
    $chosen = @('Restart', 'Pause')
    if ($null -ne $WidgetParameters -and $WidgetParameters.Contains('Sections')) {
        $chosen = @(@($WidgetParameters['Sections']) | Where-Object { $all -contains $_ })
    }
    $row = {
        param([string] $Label, [string] $Value, [string] $Tone = 'Neutral')
        [pscustomobject]@{ Label = $Label; Value = $(if ($Value) { $Value } else { 'brak danych' }); Percent = -1; Tone = $Tone }
    }

    $sections = @()
    if ($chosen -contains 'Restart') {
        $value = if ($true -eq $status.RebootRequired) { 'wymagany' } elseif ($false -eq $status.RebootRequired) { 'niewymagany' } else { $null }
        $tone = if ($true -eq $status.RebootRequired) { 'Warning' } elseif ($false -eq $status.RebootRequired) { 'Success' } else { 'Neutral' }
        $items = @(& $row 'Ponowne uruchomienie' $value $tone)
        foreach ($source in @($status.RebootSources)) {
            $items += & $row 'Powód' $source 'Warning'
        }
        $sections += [pscustomobject]@{ Title = 'Restart'; Items = $items }
    }
    if ($chosen -contains 'Pause') {
        $paused = $null -ne $status.Pause -and $status.Pause.IsPaused
        $sections += [pscustomobject]@{ Title = 'Pauza'; Items = @(& $row 'Aktualizacje' $(if ($null -ne $status.Pause) { $status.Pause.Text } else { $null }) $(if ($paused) { 'Warning' } else { 'Neutral' })) }
    }
    if ($chosen -contains 'LastActivity') {
        $sections += [pscustomobject]@{
            Title = 'Ostatnio'
            Items = @(
                & $row 'Wyszukiwanie' $status.LastSearchText
                & $row 'Instalacja' $status.LastInstallText
            )
        }
    }
    if ($chosen -contains 'Services') {
        $items = @(foreach ($service in @($status.Services)) {
                $tone = if ($service.Status -eq 'Missing') { 'Danger' } elseif ($service.StartupType -eq 'Disabled') { 'Warning' } elseif ($service.Status -eq 'Running') { 'Success' } else { 'Neutral' }
                $value = if ($service.StartupTypeText) { '{0} · {1}' -f $service.StatusText, $service.StartupTypeText } else { $service.StatusText }
                & $row $(if ($service.DisplayName) { $service.DisplayName } else { $service.Name }) $value $tone
            })
        $sections += [pscustomobject]@{ Title = 'Usługi'; Items = $items }
    }
    $restartText = if ($true -eq $status.RebootRequired) { 'wymaga restartu' } elseif ($null -ne $status.Pause -and $status.Pause.IsPaused) { 'aktualizacje wstrzymane' } else { 'bez restartu' }
    [pscustomobject]@{
        PSTypeName  = 'MWP.WidgetView'
        Summary     = '{0} · {1}' -f $status.ComputerName, $restartText
        CollectedAt = $status.CollectedAt
        Sections    = $sections
        Warnings    = @($status.Warnings)
    }
}
