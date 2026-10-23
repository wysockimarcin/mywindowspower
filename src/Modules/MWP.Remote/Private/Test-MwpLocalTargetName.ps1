function Test-MwpLocalTargetName {
    <#
    .SYNOPSIS
        Sprawdza, czy nazwa komputera oznacza komputer lokalny (localhost, '.', adres pętli, nazwa tego komputera).

    .DESCRIPTION
        Używane tylko przy tworzeniu kontekstu i rejestrze komputerów; dalej o trybie decyduje
        pole Mode kontekstu wykonania (Local/Remote), a nie nazwa (D-019).
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name
    )

    $Name -in @('localhost', '.', '127.0.0.1', '::1', $env:COMPUTERNAME)
}
