function ConvertTo-MwpAppsSummaryView {
    <#
    .SYNOPSIS
        Zamienia inwentarz programów na widok widgetu „Programy” (MWP.WidgetView): liczby, największe i ostatnio zainstalowane.

    .DESCRIPTION
        Funkcja widoku z kontraktu widgetu (D-043, D-053): czysta, bez WPF, bez winget i bez wywołań
        systemowych. Przyjmuje wynik Get-MwpInstalledApp (także surowy wynik operacji w tle). Parametr
        Sections: Summary (programy z rejestru, pakiety Appx, składniki systemu i aktualizacje),
        Largest (największe wg rozmiaru z rejestru), Recent (ostatnio zainstalowane); domyślnie tylko
        Summary. Top — liczba pozycji na listach. Składniki systemu, struktury i pakiety zasobów nie
        trafiają na listy. Zwraca $null, gdy danych nie ma.

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

    $inventory = Resolve-MwpInstalledApp -Data $Data
    if ($null -eq $inventory) {
        return $null
    }
    $chosen = @('Summary')
    $top = 5
    if ($null -ne $WidgetParameters) {
        if ($WidgetParameters.Contains('Sections')) {
            $chosen = @(@($WidgetParameters['Sections']) | Where-Object { @('Summary', 'Largest', 'Recent') -contains $_ })
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
    $apps = @($inventory.Apps)
    $visible = @($apps | Where-Object { -not $_.IsSystem -and -not $_.IsFramework -and -not $_.IsResourcePackage })
    $registry = @($visible | Where-Object { $_.Source -eq 'Registry' })
    $appx = @($visible | Where-Object { $_.Source -eq 'Appx' })

    $sections = @()
    if ($chosen -contains 'Summary') {
        $sections += [pscustomobject]@{
            Title = 'Zainstalowane'
            Items = @(
                & $row 'Programy (rejestr)' ([string]$registry.Count)
                & $row 'Aplikacje (Appx)' ([string]$appx.Count)
                & $row 'Składniki systemu i aktualizacje' ([string]($apps.Count - $visible.Count))
            )
        }
    }
    if ($chosen -contains 'Largest') {
        $largest = @($registry | Where-Object { $_.SizeBytes -gt 0 } | Sort-Object -Property SizeBytes -Descending | Select-Object -First $top)
        $items = @($largest | ForEach-Object { & $row $_.Name $_.SizeText })
        if ($items.Count -eq 0) {
            $items = @(& $row 'Rozmiary' 'programy nie podają rozmiaru')
        }
        $sections += [pscustomobject]@{ Title = 'Największe'; Items = $items }
    }
    if ($chosen -contains 'Recent') {
        $recent = @($registry | Where-Object { $null -ne $_.InstallDate } | Sort-Object -Property InstallDate -Descending | Select-Object -First $top)
        $items = @($recent | ForEach-Object { & $row $_.Name ([datetime]$_.InstallDate).ToString('yyyy-MM-dd') })
        if ($items.Count -eq 0) {
            $items = @(& $row 'Daty instalacji' 'programy nie podają daty')
        }
        $sections += [pscustomobject]@{ Title = 'Ostatnio zainstalowane'; Items = $items }
    }
    $warnings = @($inventory.Warnings)
    if ($inventory.Error) {
        $warnings += [string]$inventory.Error
    }
    [pscustomobject]@{
        PSTypeName  = 'MWP.WidgetView'
        Summary     = '{0} · programów: {1}' -f $inventory.ComputerName, $visible.Count
        CollectedAt = $inventory.CollectedAt
        Sections    = $sections
        Warnings    = $warnings
    }
}
