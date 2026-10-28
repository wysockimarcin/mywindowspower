function Test-MwpNetworkHostName {
    <#
    .SYNOPSIS
        Sprawdza, czy tekst jest adresem IP albo poprawną nazwą hosta DNS (testy łączności).

    .DESCRIPTION
        Nazwa: etykiety z liter, cyfr i łącznika (bez łącznika na brzegach), rozdzielone kropkami,
        do 253 znaków. Bez spacji, ukośników i znaków poleceń (D-015).
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [AllowEmptyString()]
        [string] $Name
    )

    if ([string]::IsNullOrWhiteSpace($Name) -or $Name.Length -gt 253) {
        return $false
    }
    $address = $null
    if ([Net.IPAddress]::TryParse($Name, [ref]$address)) {
        return $true
    }
    $Name -match '^(?=.{1,253}$)([A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?)(\.[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?)*\.?$'
}
