function Get-MwpTargetComputerName {
    <#
    .SYNOPSIS
        Odczytuje nazwę komputera spod podanego adresu (przycisk „Odczytaj nazwę z komputera” w edytorze komputera).

    .DESCRIPTION
        D-054: otwiera tymczasową sesję WinRM pod adres (IPv4 albo nazwa DNS), odczytuje w niej nazwę
        NetBIOS ($env:COMPUTERNAME), nazwę hosta i adresy LAN (Get-MwpRemoteIdentity) i zamyka sesję.
        Działa też dla komputera, którego nie ma jeszcze w rejestrze, dlatego przyjmuje adres zamiast
        kontekstu. Operacja klasy Odczyt; poświadczenie (z okna poświadczeń UI) jest używane tylko do tej
        sesji — nie trafia do pamięci podręcznej, magazynu, logu ani wyniku. Wynik: MWP.Result, w Data:
        ComputerName, HostName, SuggestedName (nazwa hosta, a gdy brak — NetBIOS), DetectedAddresses,
        ErrorKind. Funkcja nie zmienia konfiguracji WinRM ani TrustedHosts.
        -CachedTarget: bez -Credential użyj sprawdzonego hasła komputera z rejestru zapamiętanego
        w pamięci procesu (D-052), np. przy edycji komputera, z którym aplikacja już się połączyła.

    .PARAMETER CachedTarget
        Nazwa komputera z rejestru, którego sprawdzone hasło z pamięci procesu ma być użyte.

    .EXAMPLE
        (Get-MwpTargetComputerName -Address '192.0.2.10' -Credential (Get-Credential)).Data.SuggestedName
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Address,

        [ValidateRange(1, 65535)]
        [int] $Port,

        [switch] $UseSsl,

        [AllowNull()]
        [pscredential] $Credential,

        [AllowEmptyString()]
        [string] $CachedTarget = '',

        [ValidateRange(1, 3600)]
        [int] $TimeoutSeconds
    )

    $operation = 'Remote.ReadComputerName'
    $common = @{ Operation = $operation; Target = $Address; ComputerName = $Address }
    $data = [ordered]@{ ComputerName = $null; HostName = $null; SuggestedName = $null; DetectedAddresses = @(); ErrorKind = $null }
    if (-not (Test-MwpTargetName -Name $Address)) {
        $data.ErrorKind = 'Other'
        return New-MwpResult @common -Success $false -Message ("Niepoprawny adres '{0}' (dozwolone: nazwa NetBIOS/DNS albo adres IPv4)." -f $Address) -Data $data
    }
    if (-not $PSBoundParameters.ContainsKey('Port')) {
        $Port = if ($UseSsl) { 5986 } else { 5985 }
    }
    if (-not $PSBoundParameters.ContainsKey('TimeoutSeconds')) {
        $TimeoutSeconds = Get-MwpRemoteSetting -Name 'remoteConnectTimeoutSeconds' -Default 30 -Maximum 3600
    }
    $context = [pscustomobject]@{ PSTypeName = 'MWP.ExecutionContext'; ComputerName = $Address; Address = $Address; Port = $Port }
    if ($null -eq $Credential -and $CachedTarget -ne '') {
        $cached = Get-MwpCachedCredential -ComputerName $CachedTarget
        if ($null -ne $cached -and $cached['State'] -eq 'Verified') {
            $Credential = $cached['Credential']
        }
    }

    $session = $null
    try {
        $sessionArguments = @{
            ComputerName            = $Address
            Port                    = $Port
            UseSsl                  = [bool]$UseSsl
            Credential              = $Credential
            OpenTimeoutSeconds      = $TimeoutSeconds
            OperationTimeoutSeconds = $TimeoutSeconds
        }
        $session = New-MwpPSSession @sessionArguments
        $identity = Get-MwpRemoteIdentity -Session $session -TimeoutSeconds $TimeoutSeconds
        if ($null -eq $identity) {
            $data.ErrorKind = 'Other'
            return New-MwpResult @common -Success $false -Message ("Komputer pod adresem '{0}' nie zwrócił swojej nazwy." -f $Address) -Data $data
        }
        $data.ComputerName = [string]$identity['ComputerName']
        $data.HostName = [string]$identity['HostName']
        $data.SuggestedName = $(if (-not [string]::IsNullOrWhiteSpace($data.HostName)) { $data.HostName } else { $data.ComputerName })
        if ($identity['Network'] -is [Collections.IDictionary]) {
            $data.DetectedAddresses = @((Select-MwpNetworkAddress -Data $identity['Network']).AllAddresses)
        }
        $message = "Pod adresem '{0}' odpowiada komputer '{1}'." -f $Address, $data.SuggestedName
        Write-MwpLog -Level Info -Source 'MWP.Remote' -Operation $operation -ComputerName $Address -Message $message
        New-MwpResult @common -Success $true -Message $message -Data $data
    }
    catch {
        $data.ErrorKind = Get-MwpRemoteErrorKind -Exception $_.Exception
        $message = Get-MwpRemoteErrorMessage -Kind $data.ErrorKind -Context $context -Detail $_.Exception.Message
        Write-MwpLog -Level Warning -Source 'MWP.Remote' -Operation $operation -ComputerName $Address -Message $message
        New-MwpResult @common -Success $false -Message $message -ErrorMessage $_.Exception.Message -Data $data
    }
    finally {
        if ($null -ne $session) {
            Remove-MwpPSSession -Session $session
        }
    }
}
