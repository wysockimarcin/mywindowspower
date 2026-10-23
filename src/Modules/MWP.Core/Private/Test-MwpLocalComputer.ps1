function Test-MwpLocalComputer {
    <#
    .SYNOPSIS
        Sprawdza, czy nazwa komputera oznacza komputer lokalny.

    .DESCRIPTION
        Rozwiązanie przejściowe FAZY 2: rdzeń przyjmuje nazwę komputera, ale wykonuje operacje
        systemowe tylko lokalnie. W FAZIE 3 zastąpi to kontekst wykonania (tryb Local/Remote).
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $ComputerName
    )

    $ComputerName -in @('localhost', '.', '127.0.0.1', '::1', $env:COMPUTERNAME)
}
