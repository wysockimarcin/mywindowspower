function Test-MwpIsWindows {
    <#
    .SYNOPSIS
        Sprawdza, czy kod działa w systemie Windows (różnica 5.1 / 7.x obsłużona w jednym miejscu).
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    # W 5.1 zmienna $IsWindows nie istnieje, a edycja Desktop działa tylko na Windows.
    if ($PSVersionTable.PSEdition -eq 'Desktop') {
        return $true
    }
    if (Test-Path -LiteralPath 'Variable:IsWindows') {
        return [bool](Get-Variable -Name IsWindows -ValueOnly)
    }
    $false
}
