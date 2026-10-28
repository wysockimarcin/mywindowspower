function ConvertFrom-MwpNetworkJson {
    <#
    .SYNOPSIS
        Zamienia dane bloku MWP.Network (tekst JSON, MWP.Result albo obiekt) na obiekt o podanym rodzaju (Kind).

    .DESCRIPTION
        Bloki komputera docelowego zwracają tekst JSON (Get-MwpNetworkScript). Wynik Invoke-MwpOnTarget
        i operacji w tle ma go w polu Data (tablica). Zwraca ostatni pasujący obiekt albo $null.

    .PARAMETER Kind
        Oczekiwane pole Kind (np. 'MWP.NetworkStatusRaw').
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [AllowNull()]
        [object] $Data,

        [Parameter(Mandatory)]
        [string[]] $Kind
    )

    if ($null -ne $Data -and $Data.PSObject.TypeNames -contains 'MWP.Result') {
        $Data = $Data.Data
    }
    $item = @($Data | Where-Object { $null -ne $_ }) | Select-Object -Last 1
    if ($item -is [string]) {
        if ([string]::IsNullOrWhiteSpace($item)) {
            return $null
        }
        try {
            $item = ConvertFrom-Json -InputObject $item -ErrorAction Stop
        }
        catch {
            return $null
        }
    }
    if ($null -eq $item -or $null -eq $item.PSObject.Properties['Kind'] -or $Kind -notcontains $item.Kind) {
        return $null
    }
    $item
}
