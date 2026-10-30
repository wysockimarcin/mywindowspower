function New-MwpExecutionContext {
    <#
    .SYNOPSIS
        Tworzy niezmienny kontekst wykonania: komputer docelowy, tryb, tożsamość, połączenie, parametry i politykę.

    .DESCRIPTION
        Kontekst jest jawnym parametrem każdej funkcji logiki (-Context, D-019); nie istnieje globalny
        „bieżący komputer". Pola kontekstu są tylko do odczytu (próba przypisania kończy się błędem),
        więc zmiana komputera oznacza nowy kontekst (zwykle nową instancję modułu). Pola:
        - Id, InstanceId (instancja modułu, do której należy kontekst; może być pusty), CreatedAt,
        - ComputerName (nazwa komputera = identyfikator: log, wyniki, cofnięcia, poświadczenia, widgety),
          Address (adres połączenia WinRM/CIM — D-054: adres z rejestru, a gdy pusty — nazwa; dla
          localhost nieużywany), DisplayName, Mode (Local | Remote), Transport (Local | WinRM), Port, UseSsl,
        - Identity: Authentication (Credential | CurrentUser) i UserName — nigdy hasło,
        - Connection: obiekt połączenia (MWP.Connection) — jedyny zmienny element, zarządzany przez
          Connect-/Disconnect-MwpTarget i Invoke-MwpOnTarget; stan: Context.Connection.State
          (Connected, Connecting, Disconnected, Unauthorized, Error), ostatni błąd: LastError, rodzaj
          błędu: ErrorKind (m.in. NameMismatch — pod adresem odpowiada inny komputer, D-054); po
          połączeniu: RemoteComputerName, DetectedAddresses, NameVerified, AddressWarning,
        - ModuleParameters: parametry modułu (słownik tylko do odczytu),
        - Policy: ConnectTimeoutSeconds, OperationTimeoutSeconds, ErrorPolicy (Stop | Continue),
          AutoConnect.
        Komputer zdalny musi być w rejestrze (Get-MwpTarget). Poświadczenia (-Credential) trafiają
        tylko do obiektu połączenia w pamięci procesu; nie są zapisywane ani logowane (D-034). Bez
        -Credential kontekst użyje sprawdzonego hasła komputera ze wspólnej pamięci podręcznej procesu
        albo — po jawnym Connect-MwpTarget -UseStoredCredential — z Menedżera poświadczeń (D-052).

    .PARAMETER ComputerName
        Komputer docelowy; domyślnie 'localhost'.

    .PARAMETER Credential
        Poświadczenia dla komputera zdalnego (np. z Get-Credential). Dla localhost pomijane.

    .PARAMETER InstanceId
        Identyfikator instancji modułu, do której należy kontekst (ustawia New-MwpModuleInstance).

    .PARAMETER ErrorPolicy
        Stop (domyślnie): błąd nieprzerywający w zdalnym bloku kończy operację niepowodzeniem;
        Continue: operacja kończy się sukcesem, a błędy trafiają do ErrorMessage wyniku.

    .PARAMETER NoAutoConnect
        Invoke-MwpOnTarget nie łączy się sam; wymaga wcześniejszego Connect-MwpTarget.

    .EXAMPLE
        $local = New-MwpExecutionContext

    .EXAMPLE
        $remote = New-MwpExecutionContext -ComputerName 'PC-BIURO' -Credential (Get-Credential)
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Tworzy tylko obiekt w pamięci; nie zmienia stanu systemu ani konfiguracji.')]
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $ComputerName = 'localhost',

        [AllowNull()]
        [pscredential] $Credential,

        [AllowNull()]
        [AllowEmptyString()]
        [string] $InstanceId,

        [AllowNull()]
        [Collections.IDictionary] $ModuleParameters,

        [ValidateRange(1, 3600)]
        [int] $ConnectTimeoutSeconds,

        [ValidateRange(1, 86400)]
        [int] $OperationTimeoutSeconds,

        [ValidateSet('Stop', 'Continue')]
        [string] $ErrorPolicy = 'Stop',

        [switch] $NoAutoConnect
    )

    if (Test-MwpLocalTargetName -Name $ComputerName) {
        $target = ConvertTo-MwpTarget -Local
        if ($null -ne $Credential) {
            Write-Warning 'Poświadczenia są pomijane dla komputera lokalnego (operacje działają na koncie procesu aplikacji).'
            $Credential = $null
        }
    }
    else {
        $target = @(Get-MwpTarget | Where-Object { $_.Name -eq $ComputerName }) | Select-Object -First 1
        if ($null -eq $target) {
            throw ("Komputer '{0}' nie jest w rejestrze komputerów docelowych. Dodaj go: Add-MwpTarget -Name '{0}'." -f $ComputerName)
        }
    }

    if (-not $PSBoundParameters.ContainsKey('ConnectTimeoutSeconds')) {
        $ConnectTimeoutSeconds = Get-MwpRemoteSetting -Name 'remoteConnectTimeoutSeconds' -Default 30 -Maximum 3600
    }
    if (-not $PSBoundParameters.ContainsKey('OperationTimeoutSeconds')) {
        $OperationTimeoutSeconds = Get-MwpRemoteSetting -Name 'remoteOperationTimeoutSeconds' -Default 300 -Maximum 86400
    }

    $mode = if ($target.IsLocal) { 'Local' } else { 'Remote' }
    $userName = $target.UserName
    if ($null -ne $Credential) {
        $userName = $Credential.UserName
    }
    elseif ($target.Authentication -eq 'CurrentUser') {
        $userName = '{0}\{1}' -f $env:USERDOMAIN, $env:USERNAME
    }

    $connection = [pscustomobject]@{
        PSTypeName     = 'MWP.Connection'
        Id             = [guid]::NewGuid().ToString()
        ComputerName   = $target.Name
        Address        = $target.ConnectionAddress
        Mode           = $mode
        State          = $(if ($mode -eq 'Local') { 'Connected' } else { 'Disconnected' })
        ErrorKind      = $null
        LastError      = $null
        StateChangedAt = Get-Date
        Session        = $null
        CimSession     = $null
        Credential     = $Credential
        # D-052: czy poświadczenie pochodzi ze wspólnej pamięci podręcznej procesu (i jego generacja).
        CredentialShared     = $false
        CredentialGeneration = -1
        # D-054: tożsamość komputera odczytana po połączeniu (nazwa zgłoszona, adresy LAN, wynik porównania nazw).
        RemoteComputerName   = $null
        DetectedAddresses    = @()
        NameVerified         = $null
        AddressWarning       = $null
    }

    $parameters = New-Object -TypeName 'System.Collections.Generic.Dictionary[string,object]' -ArgumentList ([StringComparer]::OrdinalIgnoreCase)
    if ($null -ne $ModuleParameters) {
        foreach ($key in $ModuleParameters.Keys) {
            $parameters[[string]$key] = $ModuleParameters[$key]
        }
    }

    $identity = New-MwpReadOnlyObject -TypeName 'MWP.Identity' -Property ([ordered]@{
            Authentication = $target.Authentication
            UserName       = $userName
        })
    $policy = New-MwpReadOnlyObject -TypeName 'MWP.ExecutionPolicy' -Property ([ordered]@{
            ConnectTimeoutSeconds   = $ConnectTimeoutSeconds
            OperationTimeoutSeconds = $OperationTimeoutSeconds
            ErrorPolicy             = $ErrorPolicy
            AutoConnect             = -not $NoAutoConnect
        })

    New-MwpReadOnlyObject -TypeName 'MWP.ExecutionContext' -Property ([ordered]@{
            Id               = [guid]::NewGuid().ToString()
            InstanceId       = $(if ([string]::IsNullOrEmpty($InstanceId)) { $null } else { $InstanceId })
            ComputerName     = $target.Name
            Address          = $target.ConnectionAddress
            DisplayName      = $target.DisplayName
            Mode             = $mode
            Transport        = $target.Transport
            Port             = $target.Port
            UseSsl           = $target.UseSsl
            Identity         = $identity
            Connection       = $connection
            ModuleParameters = [Collections.ObjectModel.ReadOnlyDictionary[string, object]]::new($parameters)
            Policy           = $policy
            CreatedAt        = Get-Date
        })
}
