function ConvertTo-MwpAppsUpdatesView {
    <#
    .SYNOPSIS
        Zamienia listę pakietów winget z aktualizacją na widok widgetu „Aktualizacje programów” (MWP.WidgetView).

    .DESCRIPTION
        Funkcja widoku z kontraktu widgetu (D-043, D-053): czysta, bez WPF i bez uruchamiania winget.
        Przyjmuje wynik Get-MwpWingetUpgrade (także surowy wynik operacji w tle). Pokazuje liczbę
        dostępnych aktualizacji i pierwsze Top pakietów (wersja zainstalowana → dostępna). Gdy winget
        nie zadziałał (brak winget, brak administratora na komputerze zdalnym), widok ma sekcję
        z komunikatem i ostrzeżenie zamiast wyjątku. Zwraca $null, gdy danych nie ma.

    .PARAMETER WidgetParameters
        Parametry widgetu: Top (liczba pakietów na liście).
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
    $list = Resolve-MwpWingetPackage -Kind List -Data $Data
    if ($null -eq $list) {
        return $null
    }
    $top = 5
    $number = 0
    if ($null -ne $WidgetParameters -and $WidgetParameters.Contains('Top') -and [int]::TryParse([string]$WidgetParameters['Top'], [ref]$number) -and $number -gt 0) {
        $top = [Math]::Min(50, $number)
    }
    $row = {
        param([string] $Label, [string] $Value, [string] $Tone = 'Neutral')
        [pscustomobject]@{ Label = $Label; Value = $(if ($Value) { $Value } else { 'brak danych' }); Percent = -1; Tone = $Tone }
    }
    $computerName = $(if ($list.PSObject.Properties['ComputerName'] -and $list.ComputerName) { [string]$list.ComputerName } else { '' })
    $prefix = $(if ($computerName) { '{0} · ' -f $computerName } else { '' })
    $warnings = @($list.Warnings)
    if (-not $list.Success) {
        $message = $(if ($list.Message) { [string]$list.Message } else { 'winget nie zwrócił listy aktualizacji.' })
        $warnings += $message
        return [pscustomobject]@{
            PSTypeName  = 'MWP.WidgetView'
            Summary     = '{0}winget niedostępny' -f $prefix
            CollectedAt = Get-Date
            Sections    = @([pscustomobject]@{ Title = 'winget'; Items = @(& $row 'Stan' $message 'Warning') })
            Warnings    = $warnings
        }
    }
    $packages = @($list.Packages | Where-Object { $_.HasUpgrade } | Sort-Object -Property Name)
    $items = @($packages | Select-Object -First $top | ForEach-Object {
            & $row $_.Name ('{0} → {1}' -f $_.Version, $_.Available) 'Warning'
        })
    if ($packages.Count -gt $top) {
        $items += & $row ('… i {0} innych' -f ($packages.Count - $top)) ' '
    }
    if ($items.Count -eq 0) {
        $items = @(& $row 'Aktualizacje' 'wszystkie programy są aktualne' 'Success')
    }
    [pscustomobject]@{
        PSTypeName  = 'MWP.WidgetView'
        Summary     = '{0}aktualizacji: {1}' -f $prefix, $packages.Count
        CollectedAt = Get-Date
        Sections    = @([pscustomobject]@{ Title = 'Dostępne aktualizacje'; Items = $items })
        Warnings    = $warnings
    }
}
