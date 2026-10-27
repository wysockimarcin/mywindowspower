function Resolve-MwpSystemInfoData {
    <#
    .SYNOPSIS
        Zamienia dane informacji o systemie (tekst JSON z bloku odczytu, wynik MWP.Result albo obiekt) na obiekt.

    .DESCRIPTION
        Blok odczytu zwraca tekst JSON (Get-MwpSystemInfoScript); Get-MwpSystemInfo bez -AsOperation
        zwraca już obiekt, a operacja w tle (widget) — pole Data z tekstem. Funkcja przyjmuje każdą
        z tych postaci i zwraca obiekt z polem Kind = 'MWP.SystemInfo' albo $null, gdy danych nie ma
        lub nie są informacjami o systemie.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [AllowNull()]
        [object] $Data
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
    if ($null -eq $item -or $null -eq $item.PSObject.Properties['Kind'] -or $item.Kind -ne 'MWP.SystemInfo') {
        return $null
    }
    $item
}
