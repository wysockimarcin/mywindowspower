function New-MwpCimSession {
    <#
    .SYNOPSIS
        Adapter transportu: otwiera sesję CIM (protokół WSMan) do odczytu danych z komputera docelowego.

    .DESCRIPTION
        Ten sam port, szyfrowanie i poświadczenia co sesja WinRM. Testy podmieniają tę funkcję mockiem.
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

    $option = New-CimSessionOption -Protocol Wsman -UseSsl:$UseSsl
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
