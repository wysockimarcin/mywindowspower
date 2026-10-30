function Test-MwpIPv4Address {
    <#
    .SYNOPSIS
        Sprawdza, czy tekst jest adresem IPv4 w zapisie dziesiętnym z kropkami (np. 192.0.2.10).
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [string] $Value
    )

    -not [string]::IsNullOrEmpty($Value) -and $Value -match '^(?:(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)\.){3}(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)$'
}
