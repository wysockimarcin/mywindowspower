function Test-MwpAdmin {
    <#
    .SYNOPSIS
        Sprawdza, czy bieżący proces ma uprawnienia administratora (token podniesiony przez UAC).

    .DESCRIPTION
        Dotyczy procesu na komputerze lokalnym. Uprawnienia na komputerze zdalnym sprawdza
        kontekst wykonania w FAZIE 3. Poza Windows zwraca $false.

    .OUTPUTS
        [bool]

    .EXAMPLE
        if (-not (Test-MwpAdmin)) { 'Ta operacja wymaga administratora.' }
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (-not (Test-MwpIsWindows)) {
        return $false
    }

    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    try {
        $principal = New-Object -TypeName Security.Principal.WindowsPrincipal -ArgumentList $identity
        [bool]$principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    finally {
        $identity.Dispose()
    }
}
