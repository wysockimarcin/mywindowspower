function ConvertTo-MwpPowerStatusView {
    <#
    .SYNOPSIS
        Zamienia stan zasilania na widok widgetu Dashboardu (MWP.WidgetView): plan aktywny, czasy AC/DC, hibernacja, szybkie uruchamianie.

    .DESCRIPTION
        Funkcja widoku z kontraktu widgetu (D-043): czysta, bez WPF i bez wywołań systemowych.
        Przyjmuje wynik Get-MwpPowerStatus (także surowy wynik operacji w tle). Zwraca $null, gdy
        danych nie ma.

    .PARAMETER WidgetParameters
        Parametry widgetu (kontrakt D-043); widget zasilania nie ma parametrów.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'WidgetParameters',
        Justification = 'Parametr wymagany przez kontrakt widgetu (D-043).')]
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [AllowNull()]
        [object] $Data,

        [AllowNull()]
        [Collections.IDictionary] $WidgetParameters
    )

    $status = Resolve-MwpPowerStatus -Data $Data
    if ($null -eq $status) {
        return $null
    }
    $row = {
        param([string] $Label, [string] $Value, [string] $Tone = 'Neutral')
        [pscustomobject]@{ Label = $Label; Value = $(if ($Value) { $Value } else { 'brak danych' }); Percent = -1; Tone = $Tone }
    }
    $flag = {
        param($State, [string] $On, [string] $Off)
        if ($null -eq $State) { 'brak danych' } elseif ($State) { $On } else { $Off }
    }

    $planItems = @(& $row 'Plan aktywny' $(if ($null -ne $status.ActivePlan) { $status.ActivePlan.Name } else { $null }) 'Success')
    $planItems += & $row 'Plany' ([string]@($status.Plans).Count)
    $settingItems = @(foreach ($setting in @($status.Settings | Where-Object { $_.Available -and $_.Kind -eq 'Timeout' -and $_.Id -ne 'HibernateTimeout' })) {
            $value = if ($status.HasBattery -eq $false) { $setting.AcText } else { 'sieć {0} · bateria {1}' -f $setting.AcText, $setting.DcText }
            & $row $setting.Label $value
        })
    $systemItems = @(
        & $row 'Hibernacja' (& $flag $status.Hibernate 'włączona' 'wyłączona')
        & $row 'Szybkie uruchamianie' (& $flag $status.FastStartup 'włączone' 'wyłączone')
        & $row 'Bateria' (& $flag $status.HasBattery 'jest' 'brak')
    )
    [pscustomobject]@{
        PSTypeName  = 'MWP.WidgetView'
        Summary     = '{0} · {1}' -f $status.ComputerName, $(if ($null -ne $status.ActivePlan) { $status.ActivePlan.Name } else { 'brak planu aktywnego' })
        CollectedAt = $status.CollectedAt
        Sections    = @(
            [pscustomobject]@{ Title = 'Plan zasilania'; Items = $planItems }
            [pscustomobject]@{ Title = 'Ekran i uśpienie'; Items = $settingItems }
            [pscustomobject]@{ Title = 'Hibernacja'; Items = $systemItems }
        )
        Warnings    = @($status.Warnings)
    }
}
