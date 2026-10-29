function Get-MwpWidgetParameterField {
    <#
    .SYNOPSIS
        Opisuje pola edycji parametrów widgetu (bez WPF): rodzaj kontrolki, etykieta, opcje i wartość początkowa.

    .DESCRIPTION
        Wspólne dla okna widgetu (Show-MwpWidgetEditor) i sekcji „Widżety” widoku „Moduły” (domyślne
        parametry typu widgetu, D-053), żeby obie miały te same kontrolki. Rodzaje: Choices (StringArray
        z listą Values — pola wyboru), Bool (pole wyboru), Int, StringArray (tekst po przecinku), String.
        Wartość z -Value ma pierwszeństwo przed Default ze schematu.

    .PARAMETER Schema
        Schemat parametrów widgetu (Parameters z definicji widgetu).

    .PARAMETER Value
        Bieżące wartości parametrów (np. zapisane parametry widgetu albo domyślne parametry użytkownika).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [AllowNull()]
        [Collections.IDictionary] $Schema,

        [AllowNull()]
        [Collections.IDictionary] $Value
    )

    if ($null -eq $Schema) {
        return
    }
    foreach ($key in @($Schema.Keys | Sort-Object)) {
        $parameter = $Schema[$key]
        if ($parameter -isnot [Collections.IDictionary]) {
            continue
        }
        $current = $(if ($null -ne $Value -and $Value.Contains($key)) { $Value[$key] } else { $parameter['Default'] })
        $type = [string]$parameter['Type']
        $kind = $(if ($type -eq 'StringArray' -and $parameter.Contains('Values')) { 'Choices' } elseif ($type -in @('Bool', 'Int', 'StringArray')) { $type } else { 'String' })
        $labels = $(if ($parameter['ValueLabels'] -is [Collections.IDictionary]) { $parameter['ValueLabels'] } else { @{} })
        [pscustomobject]@{
            PSTypeName = 'MWP.UiWidgetParameterField'
            Key        = [string]$key
            Label      = $(if ($parameter.Contains('Label')) { [string]$parameter['Label'] } else { [string]$key })
            Kind       = $kind
            Options    = @(if ($kind -eq 'Choices') {
                    foreach ($option in @($parameter['Values'])) {
                        [pscustomobject]@{
                            Value   = [string]$option
                            Text    = $(if ($labels.Contains($option)) { [string]$labels[$option] } else { [string]$option })
                            Checked = @($current) -contains $option
                        }
                    }
                })
            Checked    = $kind -eq 'Bool' -and $true -eq $current
            Text       = $(if ($kind -eq 'StringArray') { @($current) -join ', ' } elseif ($kind -in @('Int', 'String')) { [string]$current } else { '' })
        }
    }
}
