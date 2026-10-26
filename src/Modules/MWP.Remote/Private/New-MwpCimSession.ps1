function New-MwpCimSession {
    <#
    .SYNOPSIS
        Adapter transportu: otwiera sesję CIM (protokół WSMan) do odczytu danych z komputera docelowego.

    .DESCRIPTION
        Ten sam port, szyfrowanie i poświadczenia co sesja WinRM. New-CimSessionOption nie łączy -Protocol
        z -UseSsl (różne zestawy parametrów), dlatego HTTPS i HTTP mają osobne wywołania. Testy połączeń
        podmieniają tę funkcję mockiem; opcje sesji sprawdza osobny test bez mocka (Connection.Tests.ps1).
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Otwiera połączenie; nie zmienia stanu systemu.')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $ComputerName,

        [Parameter(Mandatory)]
        [int] $Port,

        [bool] $UseSsl,

        [AllowNull()]
        [pscredential] $Credential,

        [Parameter(Mandatory)]
        [int] $OperationTimeoutSeconds
    )

    $option = if ($UseSsl) { New-CimSessionOption -UseSsl } else { New-CimSessionOption -Protocol Wsman }
    $parameters = @{
        ComputerName        = $ComputerName
        Port                = $Port
        SessionOption       = $option
        OperationTimeoutSec = $OperationTimeoutSeconds
        ErrorAction         = 'Stop'
    }
    if ($null -ne $Credential) {
        $parameters['Credential'] = $Credential
    }
    New-CimSession @parameters
}
