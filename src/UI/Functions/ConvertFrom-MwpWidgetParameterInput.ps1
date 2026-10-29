function ConvertFrom-MwpWidgetParameterInput {
    <#
    .SYNOPSIS
        Zamienia wartości wpisane w polach parametrów widgetu na parametry (bez WPF); zwraca Parameters i Problem.

    .DESCRIPTION
        Para do Get-MwpWidgetParameterField. Wejście dla każdego pola: Choices — lista wybranych wartości
        (co najmniej jedna), Bool — wartość logiczna, Int — tekst liczby całkowitej, StringArray — tekst
        po przecinku, String — tekst. Problem to komunikat po polsku dla pierwszego błędu albo $null.

    .PARAMETER Field
        Pola z Get-MwpWidgetParameterField.

    .PARAMETER Entry
        Wartości z kontrolek: klucz parametru → wartość.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [AllowEmptyCollection()]
        [object[]] $Field = @(),

        [Parameter(Mandatory)]
        [Collections.IDictionary] $Entry
    )

    $parameters = [ordered]@{}
    $problem = $null
    foreach ($item in @($Field | Where-Object { $null -ne $_ } | Sort-Object -Property Key)) {
        $raw = $Entry[$item.Key]
        switch ($item.Kind) {
            'Choices' {
                $chosen = @($item.Options | Where-Object { @($raw) -contains $_.Value } | ForEach-Object { $_.Value })
                if ($chosen.Count -eq 0 -and $null -eq $problem) {
                    $problem = 'Wybierz co najmniej jedną wartość parametru „{0}”.' -f $item.Label
                }
                $parameters[$item.Key] = [string[]]$chosen
            }
            'Bool' { $parameters[$item.Key] = $true -eq $raw }
            'Int' {
                $number = 0
                if (-not [int]::TryParse([string]$raw, [ref]$number) -and $null -eq $problem) {
                    $problem = 'Parametr „{0}” musi być liczbą całkowitą.' -f $item.Label
                }
                $parameters[$item.Key] = $number
            }
            'StringArray' { $parameters[$item.Key] = [string[]]@(([string]$raw) -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
            default { $parameters[$item.Key] = [string]$raw }
        }
    }
    [pscustomobject]@{ Parameters = $parameters; Problem = $problem }
}
