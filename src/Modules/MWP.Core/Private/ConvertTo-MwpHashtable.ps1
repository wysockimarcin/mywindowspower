function ConvertTo-MwpHashtable {
    <#
    .SYNOPSIS
        Zamienia obiekty z ConvertFrom-Json (PSCustomObject) rekurencyjnie na uporządkowane słowniki.

    .DESCRIPTION
        Windows PowerShell 5.1 nie ma ConvertFrom-Json -AsHashtable, dlatego konwersja jest ręczna
        i działa tak samo w 5.1 i 7.x. Tablice zostają tablicami, wartości proste bez zmian.
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]
        [AllowNull()]
        [object] $InputObject
    )

    process {
        if ($null -eq $InputObject) {
            return $null
        }

        if ($InputObject -is [Collections.IDictionary]) {
            $table = [ordered]@{}
            foreach ($key in $InputObject.Keys) {
                $table[[string]$key] = ConvertTo-MwpHashtable -InputObject $InputObject[$key]
            }
            return $table
        }

        if ($InputObject -is [Management.Automation.PSCustomObject]) {
            $table = [ordered]@{}
            foreach ($property in $InputObject.PSObject.Properties) {
                $table[$property.Name] = ConvertTo-MwpHashtable -InputObject $property.Value
            }
            return $table
        }

        if ($InputObject -is [Collections.IEnumerable] -and $InputObject -isnot [string]) {
            # Przecinek chroni tablicę przed rozwinięciem w potoku.
            return , @(foreach ($item in $InputObject) {
                    ConvertTo-MwpHashtable -InputObject $item
                })
        }

        $InputObject
    }
}
