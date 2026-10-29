function ConvertTo-MwpStartupSummaryView {
    <#
    .SYNOPSIS
        Zamienia listę pozycji autostartu na widok widgetu „Autostart” (MWP.WidgetView): liczby, włączone programy, pozycje ryzykowne.

    .DESCRIPTION
        Funkcja widoku z kontraktu widgetu (D-043, D-053): czysta, bez WPF i bez wywołań systemowych.
        Przyjmuje wynik Get-MwpStartupItem (także surowy wynik operacji w tle). Parametr Sections:
        Summary (liczby włączonych, wyłączonych i jednorazowych), Enabled (włączone programy),
        Risky (niepodpisane, z nieprawidłowym podpisem albo bez pliku — wymaga sprawdzenia podpisów);
        domyślnie tylko Summary. Top — liczba pozycji na listach. Zwraca $null, gdy danych nie ma.

    .PARAMETER WidgetParameters
        Parametry widgetu: Sections (lista sekcji), Top (liczba pozycji).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [AllowNull()]
        [object] $Data,

        [AllowNull()]
        [Collections.IDictionary] $WidgetParameters
    )

    $list = Resolve-MwpStartupItemList -Data $Data
    if ($null -eq $list) {
        return $null
    }
    $chosen = @('Summary')
    $top = 5
    if ($null -ne $WidgetParameters) {
        if ($WidgetParameters.Contains('Sections')) {
            $chosen = @(@($WidgetParameters['Sections']) | Where-Object { @('Summary', 'Enabled', 'Risky') -contains $_ })
        }
        $number = 0
        if ($WidgetParameters.Contains('Top') -and [int]::TryParse([string]$WidgetParameters['Top'], [ref]$number) -and $number -gt 0) {
            $top = [Math]::Min(50, $number)
        }
    }
    $row = {
        param([string] $Label, [string] $Value, [string] $Tone = 'Neutral')
        [pscustomobject]@{ Label = $Label; Value = $(if ($Value) { $Value } else { 'brak danych' }); Percent = -1; Tone = $Tone }
    }
    $limit = {
        param([object[]] $Items, [scriptblock] $Convert)
        $result = @($Items | Select-Object -First $top | ForEach-Object $Convert)
        if (@($Items).Count -gt $top) {
            $result += & $row ('… i {0} innych' -f (@($Items).Count - $top)) ' '
        }
        $result
    }
    $items = @($list.Items)
    $enabled = @($items | Where-Object { $_.CanToggle -and $_.Enabled })
    $disabled = @($items | Where-Object { $_.CanToggle -and -not $_.Enabled })
    $runOnce = @($items | Where-Object { -not $_.CanToggle })
    $risky = @($items | Where-Object { $_.Risk -in @('Unsigned', 'Invalid', 'Missing') })
    $checked = @($items | Where-Object { $_.Risk -ne 'NotChecked' }).Count -gt 0

    $sections = @()
    if ($chosen -contains 'Summary') {
        $sections += [pscustomobject]@{
            Title = 'Autostart'
            Items = @(
                & $row 'Włączone' ([string]$enabled.Count) 'Success'
                & $row 'Wyłączone' ([string]$disabled.Count)
                & $row 'Jednorazowe (RunOnce)' ([string]$runOnce.Count)
            )
        }
    }
    if ($chosen -contains 'Enabled') {
        $rows = @(& $limit $enabled { & $row $_.Name $_.LocationText })
        if ($rows.Count -eq 0) {
            $rows = @(& $row 'Włączone programy' 'brak')
        }
        $sections += [pscustomobject]@{ Title = 'Włączone programy'; Items = $rows }
    }
    if ($chosen -contains 'Risky') {
        $rows = if (-not $checked -and $items.Count -gt 0) {
            @(& $row 'Podpisy' 'nie sprawdzano')
        }
        else {
            @(& $limit $risky { & $row $_.Name $_.RiskText $(if ($_.Risk -eq 'Invalid') { 'Danger' } else { 'Warning' }) })
        }
        if ($rows.Count -eq 0) {
            $rows = @(& $row 'Ryzykowne pozycje' 'brak' 'Success')
        }
        $sections += [pscustomobject]@{ Title = 'Do sprawdzenia'; Items = $rows }
    }
    [pscustomobject]@{
        PSTypeName  = 'MWP.WidgetView'
        Summary     = '{0} · włączone {1} z {2}' -f $list.ComputerName, $enabled.Count, $items.Count
        CollectedAt = $(if ($list.CollectedAt) { [datetime]$list.CollectedAt } else { $null })
        Sections    = $sections
        Warnings    = @($list.Warnings)
    }
}
