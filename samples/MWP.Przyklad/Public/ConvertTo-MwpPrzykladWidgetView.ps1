function ConvertTo-MwpPrzykladWidgetView {
    <#
    .SYNOPSIS
        Funkcja widoku widgetu przykładowego (kontrakt widgetu, D-043): dane z Get-MwpTargetInfo jako jedna sekcja.

    .EXAMPLE
        ConvertTo-MwpPrzykladWidgetView -Data (Get-MwpTargetInfo -Context (New-MwpExecutionContext)).Data
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '',
        Justification = 'Sygnatura kontraktu widgetu: -WidgetParameters jest wymagany, choć przykład go nie używa.')]
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [AllowNull()]
        [object] $Data,

        [AllowNull()]
        [Collections.IDictionary] $WidgetParameters
    )

    $info = @($Data | Where-Object { $null -ne $_ }) | Select-Object -First 1
    if ($null -eq $info) {
        return $null
    }
    $items = foreach ($name in 'ComputerName', 'System', 'PowerShell', 'Time') {
        [pscustomobject]@{ Label = $name; Value = [string]$info.$name; Percent = -1; Tone = 'Neutral' }
    }
    [pscustomobject]@{
        PSTypeName = 'MWP.WidgetView'
        Summary    = [string]$info.ComputerName
        Sections   = @([pscustomobject]@{ Title = 'Komputer'; Items = @($items) })
        Warnings   = @()
    }
}
