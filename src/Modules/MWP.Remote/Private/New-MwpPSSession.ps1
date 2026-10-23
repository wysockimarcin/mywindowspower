function New-MwpPSSession {
    <#
    .SYNOPSIS
        Adapter transportu: otwiera sesję PowerShell Remoting (WinRM) z komputerem docelowym.

    .DESCRIPTION
        Jedyne miejsce, które tworzy sesję WinRM (ADR transportu, DECYZJE.md). Uwierzytelnienie
        domyślne (Negotiate: Kerberos w domenie, NTLM w grupie roboczej), bez CredSSP i bez zmian
        konfiguracji klienta (TrustedHosts zmienia użytkownik ręcznie). Punkt końcowy domyślny
        (Microsoft.PowerShell = Windows PowerShell 5.1 na komputerze docelowym).
        Testy podmieniają tę funkcję mockiem (bez prawdziwych połączeń).
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
        [int] $OpenTimeoutSeconds,

        [Parameter(Mandatory)]
        [int] $OperationTimeoutSeconds
    )

    $option = New-PSSessionOption -OpenTimeout ($OpenTimeoutSeconds * 1000) -OperationTimeout ($OperationTimeoutSeconds * 1000)
    $parameters = @{
        ComputerName  = $ComputerName
        Port          = $Port
        SessionOption = $option
        ErrorAction   = 'Stop'
    }
    if ($UseSsl) {
        $parameters['UseSSL'] = $true
    }
    if ($null -ne $Credential) {
        $parameters['Credential'] = $Credential
    }
    New-PSSession @parameters
}
