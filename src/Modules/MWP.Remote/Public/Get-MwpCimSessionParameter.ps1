function Get-MwpCimSessionParameter {
    <#
    .SYNOPSIS
        Zwraca parametry do rozwinięcia w poleceniach CIM (odczyt) dla komputera docelowego kontekstu.

    .DESCRIPTION
        Transport odczytu (ADR transportu): dla komputera lokalnego pusty słownik (polecenia CIM działają
        lokalnie), dla zdalnego @{ CimSession = <sesja> } — sesja CIM (WSMan) tworzona przy pierwszym
        użyciu, z tymi samymi poświadczeniami co połączenie, i zamykana przez Disconnect-MwpTarget.
        Brak poświadczeń albo błąd połączenia kończy się wyjątkiem z komunikatem po polsku (nigdy
        cichym przejściem na komputer lokalny) i zmianą stanu połączenia kontekstu.

    .EXAMPLE
        $cim = Get-MwpCimSessionParameter -Context $remote
        Get-CimInstance -ClassName Win32_OperatingSystem @cim
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [PSTypeName('MWP.ExecutionContext')]
        [object] $Context
    )

    if ($Context.Mode -eq 'Local') {
        return @{}
    }
    $connection = $Context.Connection
    if ($null -ne $connection.CimSession) {
        return @{ CimSession = $connection.CimSession }
    }
    if ($Context.Identity.Authentication -eq 'Credential' -and $null -eq $connection.Credential) {
        $message = Get-MwpRemoteErrorMessage -Kind 'CredentialRequired' -Context $Context
        Set-MwpConnectionState -Connection $connection -State Unauthorized -ErrorKind 'CredentialRequired' -ErrorMessage $message
        throw $message
    }

    try {
        $cimArguments = @{
            ComputerName            = $Context.ComputerName
            Port                    = $Context.Port
            UseSsl                  = $Context.UseSsl
            Credential              = $connection.Credential
            OperationTimeoutSeconds = $Context.Policy.OperationTimeoutSeconds
        }
        $connection.CimSession = New-MwpCimSession @cimArguments
    }
    catch {
        $kind = Get-MwpRemoteErrorKind -Exception $_.Exception
        $state = if ($kind -eq 'Unauthorized') { 'Unauthorized' } else { 'Error' }
        $message = Get-MwpRemoteErrorMessage -Kind $kind -Context $Context -Detail $_.Exception.Message
        Set-MwpConnectionState -Connection $connection -State $state -ErrorKind $kind -ErrorMessage $_.Exception.Message
        Write-MwpLog -Level Warning -Source 'MWP.Remote' -Operation 'Remote.CimSession' -ComputerName $Context.ComputerName -Message $message
        throw $message
    }
    @{ CimSession = $connection.CimSession }
}
