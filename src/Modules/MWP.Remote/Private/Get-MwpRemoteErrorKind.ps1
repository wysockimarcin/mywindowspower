function Get-MwpRemoteErrorKind {
    <#
    .SYNOPSIS
        Klasyfikuje błąd połączenia zdalnego: NameMismatch, Unauthorized, Configuration, Timeout, Network albo Other.

    .DESCRIPTION
        Rozdziela uwierzytelnienie i autoryzację (Unauthorized) od dostępności (Network, Timeout)
        i konfiguracji klienta WinRM (Configuration, np. brak komputera w TrustedHosts w grupie
        roboczej). Najpierw kody błędów (niezależne od języka systemu), potem treść komunikatu
        (angielska i polska).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [Exception] $Exception
    )

    if ($null -eq $Exception) {
        return 'Other'
    }

    $messages = New-Object -TypeName System.Collections.Generic.List[string]
    $codes = New-Object -TypeName System.Collections.Generic.List[long]
    $isTransport = $false
    $isTimeout = $false
    $current = $Exception
    while ($null -ne $current) {
        $messages.Add($current.Message)
        if ($current -is [Management.Automation.Remoting.PSRemotingTransportException]) {
            $isTransport = $true
            $codes.Add([long]$current.ErrorCode)
        }
        elseif ($current -is [ComponentModel.Win32Exception]) {
            $codes.Add([long]$current.NativeErrorCode)
        }
        if ($current -is [TimeoutException]) {
            $isTimeout = $true
        }
        $current = $current.InnerException
    }
    $text = $messages -join ' '

    # D-054: znacznik zgłaszany przez blok operacji w tle, gdy komputer pod adresem ma inną nazwę.
    if ($text -match 'MWP-NAMEMISMATCH:') {
        return 'NameMismatch'
    }
    $accessDenied = @(5, 1326, 1327, 1330, 1331, 1909, -2147024891)
    if (@($codes | Where-Object { $accessDenied -contains $_ }).Count -gt 0 -or
        $text -match 'Access is denied|Odmowa dostępu|user name or password is incorrect|nazwa użytkownika lub hasło|logon failure|unknown user name') {
        return 'Unauthorized'
    }
    if ($text -match 'TrustedHosts') {
        return 'Configuration'
    }
    if ($isTimeout -or @($codes | Where-Object { @(121, 1460, -2144108250) -contains $_ }).Count -gt 0 -or $text -match 'timed out|limit czasu|timeout') {
        return 'Timeout'
    }
    if ($isTransport -or @($codes | Where-Object { @(53, 1722, -2144108526) -contains $_ }).Count -gt 0) {
        return 'Network'
    }
    'Other'
}
