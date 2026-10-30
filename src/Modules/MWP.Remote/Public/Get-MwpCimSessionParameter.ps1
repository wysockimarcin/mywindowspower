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
        D-054: sesja CIM idzie pod adres połączenia (Context.Address); gdy kontekst nie przeszedł
        weryfikacji nazwy w Connect-MwpTarget, nazwa komputera jest sprawdzana przez CIM (CSName),
        a niezgodność kończy się wyjątkiem NameMismatch.

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
            ComputerName            = $Context.Address
            Port                    = $Context.Port
            UseSsl                  = $Context.UseSsl
            Credential              = $connection.Credential
            OperationTimeoutSeconds = $Context.Policy.OperationTimeoutSeconds
        }
        $cimSession = New-MwpCimSession @cimArguments
    }
    catch {
        $kind = Get-MwpRemoteErrorKind -Exception $_.Exception
        $state = if ($kind -eq 'Unauthorized') { 'Unauthorized' } else { 'Error' }
        $message = Get-MwpRemoteErrorMessage -Kind $kind -Context $Context -Detail $_.Exception.Message
        Set-MwpConnectionState -Connection $connection -State $state -ErrorKind $kind -ErrorMessage $_.Exception.Message
        Write-MwpLog -Level Warning -Source 'MWP.Remote' -Operation 'Remote.CimSession' -ComputerName $Context.ComputerName -Message $message
        throw $message
    }

    # D-054: odczyt CIM bez wcześniej zweryfikowanego Connect-MwpTarget sprawdza nazwę komputera pod adresem.
    $alreadyVerified = $null -ne $connection.PSObject.Properties['NameVerified'] -and $connection.NameVerified -eq $true
    if (-not $alreadyVerified -and (Get-MwpExpectedComputerName -Name $Context.ComputerName) -ne '') {
        $remoteName = ''
        try {
            $remoteName = Get-MwpCimComputerName -CimSession $cimSession -TimeoutSeconds $Context.Policy.ConnectTimeoutSeconds
        }
        catch {
            Write-MwpLog -Level Debug -Source 'MWP.Remote' -Operation 'Remote.CimSession' -ComputerName $Context.ComputerName `
                -Message ("Nie udało się odczytać nazwy komputera pod adresem '{0}' przez CIM: {1}" -f $Context.Address, $_.Exception.Message)
        }
        if ((Update-MwpConnectionIdentity -Context $Context -Identity $null -RemoteName $remoteName) -eq $false) {
            Remove-MwpCimSession -CimSession $cimSession
            $message = Get-MwpRemoteErrorMessage -Kind 'NameMismatch' -Context $Context -RemoteName $remoteName
            Set-MwpConnectionState -Connection $connection -State Error -ErrorKind 'NameMismatch' -ErrorMessage $message
            Write-MwpLog -Level Warning -Source 'MWP.Remote' -Operation 'Remote.CimSession' -ComputerName $Context.ComputerName -Message $message
            throw $message
        }
    }
    $connection.CimSession = $cimSession
    @{ CimSession = $connection.CimSession }
}
