function ConvertTo-MwpTweaksWidgetView {
    <#
    .SYNOPSIS
        Widok widgetu-zalążka modułu MWP.Tweaks (MWP.WidgetView): wersja modułu i informacja o FAZIE 13.

    .DESCRIPTION
        Funkcja widoku z kontraktu widgetu (D-043, D-053): czysta, bez WPF i bez wywołań systemowych.
        Zwraca $null, gdy danych nie ma.

    .PARAMETER WidgetParameters
        Parametry widgetu (kontrakt D-043); widget-zalążek nie ma parametrów.
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

    if ($null -ne $Data -and $Data.PSObject.TypeNames -contains 'MWP.Result') {
        $Data = $Data.Data
    }
    $item = @($Data | Where-Object { $null -ne $_ }) | Select-Object -Last 1
    if ($item -is [string]) {
        try {
            $item = ConvertFrom-Json -InputObject $item -ErrorAction Stop
        }
        catch {
            return $null
        }
    }
    if ($null -eq $item -or $null -eq $item.PSObject.Properties['Kind'] -or $item.Kind -ne 'MWP.ModuleSeedWidgetRaw') {
        return $null
    }
    [pscustomobject]@{
        PSTypeName  = 'MWP.WidgetView'
        Summary     = '{0} · Prywatność i tweaki' -f $item.ComputerName
        CollectedAt = $(if ($item.CollectedAt) { [datetime]$item.CollectedAt } else { $null })
        Sections    = @(
            [pscustomobject]@{
                Title = 'Moduł'
                Items = @(
                    [pscustomobject]@{ Label = 'Wersja'; Value = ('{0} {1}' -f $item.Module, $item.Version); Percent = -1; Tone = 'Neutral' }
                    [pscustomobject]@{ Label = 'Stan'; Value = ('w przygotowaniu — dane obszaru w FAZIE {0}' -f $item.Phase); Percent = -1; Tone = 'Warning' }
                )
            }
        )
        Warnings    = @()
    }
}
