function ConvertTo-MwpPowerStatusView {
    <#
    .SYNOPSIS
        Zamienia stan zasilania na widok widgetu Dashboardu (MWP.WidgetView): plan aktywny, czasy AC/DC, hibernacja, szybkie uruchamianie.

    .DESCRIPTION
        Funkcja widoku z kontraktu widgetu (D-043): czysta, bez WPF i bez wywołań systemowych.
        Przyjmuje wynik Get-MwpPowerStatus (także surowy wynik operacji w tle). Parametr Sections
        (D-053) wybiera sekcje: Plan, Timeouts (ekran i uśpienie), Hibernate (hibernacja, szybkie
        uruchamianie, bateria); bez parametru — wszystkie (widgety sprzed D-053). Zwraca $null, gdy
        danych nie ma.

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

    $chosen = @('Plan', 'Timeouts', 'Hibernate')
    if ($null -ne $WidgetParameters -and $WidgetParameters.Contains('Sections')) {
        $chosen = @(@($WidgetParameters['Sections']) | Where-Object { @('Plan', 'Timeouts', 'Hibernate') -contains $_ })
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
            if ($chosen -contains 'Plan') { [pscustomobject]@{ Title = 'Plan zasilania'; Items = $planItems } }
            if ($chosen -contains 'Timeouts') { [pscustomobject]@{ Title = 'Ekran i uśpienie'; Items = $settingItems } }
            if ($chosen -contains 'Hibernate') { [pscustomobject]@{ Title = 'Hibernacja'; Items = $systemItems } }
        )
        Warnings    = @($status.Warnings)
    }
}
