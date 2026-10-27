function Get-MwpWidgetDue {
    <#
    .SYNOPSIS
        Wybiera widgety do odświeżenia teraz, z limitem równoczesnych odświeżeń Dashboardu.

    .DESCRIPTION
        Harmonogram Dashboardu (D-043), bez WPF. Widget jest do odświeżenia, gdy: czeka na odświeżenie
        ręczne albo pierwsze (Pending), albo — przy włączonym odświeżaniu automatycznym — ma częstotliwość
        większą od zera i minął jego termin (NextRefresh). Pomijane są widgety usunięte, bez instancji,
        w trakcie odświeżania (Task) i czekające na poświadczenia (NeedsCredential: odświeżenie
        automatyczne nie otwiera okna poświadczeń). Liczba wybranych nie przekracza
        MaxParallel minus liczba trwających odświeżeń; najpierw Pending, potem najdawniejszy termin.

    .PARAMETER Widget
        Widgety Dashboardu (tabele z New-MwpWidgetRuntime).

    .PARAMETER MaxParallel
        Limit równoczesnych odświeżeń (ustawienie dashboardMaxParallelRefresh).

    .PARAMETER AutoRefresh
        Czy działa odświeżanie automatyczne.

    .PARAMETER Now
        Bieżący czas (testy).
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [AllowEmptyCollection()]
        [object[]] $Widget = @(),

        [ValidateRange(1, 64)]
        [int] $MaxParallel = 2,

        [bool] $AutoRefresh = $true,

        [datetime] $Now = (Get-Date)
    )

    $active = @($Widget | Where-Object { $null -ne $_ -and -not $_.Removed })
    $running = @($active | Where-Object { $null -ne $_.Task }).Count
    $slots = $MaxParallel - $running
    if ($slots -le 0) {
        return
    }
    $candidates = @(foreach ($item in $active) {
            if ($null -ne $item.Task -or $null -eq $item.Instance) {
                continue
            }
            if ($item.Status -eq 'NeedsCredential' -and -not $item.Pending) {
                continue
            }
            $refresh = [int]$item.Config['refreshSeconds']
            $due = $item.Pending -or ($AutoRefresh -and $refresh -gt 0 -and $item.NextRefresh -le $Now)
            if ($due) {
                [pscustomobject]@{ Widget = $item; Automatic = -not $item.Pending; NextRefresh = $item.NextRefresh }
            }
        })
    $candidates |
        Sort-Object -Property Automatic, NextRefresh |
        Select-Object -First $slots |
        ForEach-Object { $_.Widget }
}
