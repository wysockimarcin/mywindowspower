function Update-MwpLogPanel {
    <#
    .SYNOPSIS
        Wczytuje do panelu logu ostatnie wpisy dzisiejszego pliku logu (<katalog danych>\logs).

    .DESCRIPTION
        Bez wpisów Debug; z „Tylko ostrzeżenia i błędy" — od poziomu Warning. Odczyt pliku jest krótki
        (najwyżej 300 ostatnich wpisów), więc działa w wątku okna.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Zmienia tylko kontrolki okna.')]
    [CmdletBinding()]
    param()

    $ui = $script:MwpUi
    $c = $ui.Controls
    $location = Get-MwpDataLocation
    $path = Join-Path -Path $location.Logs -ChildPath ('mwp-{0}.log' -f (Get-Date).ToString('yyyy-MM-dd'))
    $minimum = if ($c['LogWarningsOnly'].IsChecked) { 'Warning' } else { 'Info' }
    $c['LogPathText'].Text = $path
    $c['LogGrid'].ItemsSource = @(Read-MwpLogEntry -Path $path -Last 300 -MinimumLevel $minimum)
    $ui.LastLogRead = Get-Date
}
