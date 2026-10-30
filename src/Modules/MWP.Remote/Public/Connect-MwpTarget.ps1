function Connect-MwpTarget {
    <#
    .SYNOPSIS
        Nawiązuje połączenie kontekstu wykonania z komputerem docelowym (sesja WinRM).

    .DESCRIPTION
        Dla komputera lokalnego połączenie nie jest potrzebne (stan zawsze Connected). Dla zdalnego
        otwiera sesję WinRM i ustawia stan połączenia kontekstu: Connecting, potem Connected albo
        Unauthorized (odmowa dostępu, brak poświadczeń) lub Error (komputer niedostępny, limit czasu,
        konfiguracja klienta WinRM). Błąd dotyczy tylko tego kontekstu (izolacja, D-019): funkcja
        nie zgłasza wyjątku, zwraca MWP.Result z komunikatem po polsku i zapisuje log z nazwą
        komputera. Funkcja nie wyświetla okna poświadczeń (to zadanie warstwy UI, D-034).
        Poświadczenie (D-052), w kolejności: -Credential (podane przez użytkownika), własne
        poświadczenie kontekstu, sprawdzone hasło komputera z pamięci podręcznej procesu (wspólne dla
        instancji i widgetów), a z -UseStoredCredential — wpis z Menedżera poświadczeń Windows (pod
        blokadą komputera: jedno odczytanie i jedna próba naraz). Poświadczenie, które przeszło
        uwierzytelnienie, trafia do pamięci podręcznej. Po odmowie dostępu poświadczenie jest czyszczone
        z połączenia, a pochodzące z pamięci lub magazynu — unieważniane dla wszystkich kontekstów
        komputera (bez automatycznych ponowień); wpis w magazynie zostaje. Data wyniku: State, ErrorKind,
        CredentialSource (Parameter, Context, Cache, Store, None), CredentialSaved — nigdy hasło.
        D-054: sesja jest otwierana pod adres połączenia (Context.Address), a zaraz potem aplikacja
        odczytuje w niej nazwę komputera i jego adresy LAN (Get-MwpRemoteIdentity). Gdy komputer zgłasza
        inną nazwę niż Context.ComputerName (np. DHCP nadał adres innemu komputerowi), sesja jest
        zamykana, stan to Error z ErrorKind = NameMismatch, a poświadczenie nie trafia do pamięci
        podręcznej ani do magazynu — wszystkie operacje tego kontekstu są zablokowane. Gdy nazwy nie da
        się porównać (nazwa w rejestrze jest adresem IP) albo odczytać, połączenie działa jak przed D-054.

    .PARAMETER Credential
        Poświadczenia (np. Get-Credential); zastępują zapamiętane w połączeniu.

    .PARAMETER UseStoredCredential
        Jawna akcja użytkownika („Połącz”): przy braku poświadczenia w pamięci użyj wpisu MWP:<komputer>
        z Menedżera poświadczeń Windows (gdy zapamiętywanie jest włączone, a hasło nie zostało odrzucone
        w tym uruchomieniu).

    .PARAMETER SaveCredential
        Po udanym połączeniu z -Credential zapisz je w Menedżerze poświadczeń (Save-MwpTargetCredential).
        Złe hasło nigdy nie trafia do magazynu.

    .EXAMPLE
        Connect-MwpTarget -Context $remote -Credential (Get-Credential)

    .EXAMPLE
        Connect-MwpTarget -Context $remote -UseStoredCredential
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [PSTypeName('MWP.ExecutionContext')]
        [object] $Context,

        [AllowNull()]
        [pscredential] $Credential,

        [switch] $UseStoredCredential,

        [switch] $SaveCredential
    )

    process {
        $operation = 'Remote.Connect'
        $common = @{ Operation = $operation; Target = $Context.ComputerName; ComputerName = $Context.ComputerName }
        $connection = $Context.Connection
        $source = 'None'
        $saved = $false
        $snapshot = {
            [pscustomobject]@{ State = $connection.State; ErrorKind = $connection.ErrorKind; CredentialSource = $source; CredentialSaved = $saved }
        }

        if ($Context.Mode -eq 'Local') {
            return New-MwpResult @common -Success $true -Message 'Komputer lokalny: połączenie nie jest potrzebne.' -Data (& $snapshot)
        }
        $explicit = $null -ne $Credential
        if ($explicit -or $null -eq $connection.PSObject.Properties['CredentialShared']) {
            Set-MwpConnectionCredential -Connection $connection -Credential $(if ($explicit) { $Credential } else { $connection.Credential })
        }
        if ($connection.State -eq 'Connected' -and $null -ne $connection.Session -and [string]$connection.Session.State -eq 'Opened') {
            return New-MwpResult @common -Success $true -Message ("Połączenie z komputerem '{0}' jest już aktywne." -f $Context.ComputerName) -Data (& $snapshot)
        }

        $needsCredential = $Context.Identity.Authentication -eq 'Credential'
        $lockTaken = $false
        try {
            $active = $Credential
            if ($explicit) {
                $source = 'Parameter'
            }
            else {
                $active = Resolve-MwpConnectionCredential -Context $Context
                if ($null -ne $active) {
                    $source = $(if ($connection.CredentialShared) { 'Cache' } else { 'Context' })
                }
            }

            $storeKind = 'CredentialRequired'
            $storeDetail = ''
            if ($needsCredential -and $null -eq $active -and $UseStoredCredential) {
                if (-not (Test-MwpCredentialStoreEnabled)) {
                    $storeDetail = 'Zapamiętywanie haseł jest wyłączone w Ustawieniach.'
                }
                else {
                    $lockTaken = Enter-MwpCredentialLock -ComputerName $Context.ComputerName -TimeoutSeconds ($Context.Policy.ConnectTimeoutSeconds + 10)
                    # Inna instancja mogła w tym czasie sprawdzić hasło z magazynu: wynik jest w pamięci podręcznej.
                    $active = Resolve-MwpConnectionCredential -Context $Context
                    if ($null -ne $active) {
                        $source = 'Cache'
                    }
                    else {
                        $cached = Get-MwpCachedCredential -ComputerName $Context.ComputerName
                        if ($null -ne $cached -and $cached['State'] -eq 'Invalid') {
                            $storeKind = 'StoredCredentialRejected'
                        }
                        else {
                            $stored = Get-MwpStoredCredential -ComputerName $Context.ComputerName
                            if ($stored.Status -eq 'Found') {
                                $active = $stored.Credential
                                $source = 'Store'
                            }
                            elseif ($stored.Status -ne 'NotFound') {
                                $storeDetail = $stored.Message
                            }
                        }
                    }
                }
            }

            if ($needsCredential -and $null -eq $active) {
                if ($storeKind -eq 'CredentialRequired') {
                    $cached = Get-MwpCachedCredential -ComputerName $Context.ComputerName
                    if ($null -ne $cached -and $cached['State'] -eq 'Invalid') {
                        $storeKind = 'CredentialRejected'
                    }
                }
                $message = Get-MwpRemoteErrorMessage -Kind $storeKind -Context $Context -Detail $storeDetail
                Set-MwpConnectionState -Connection $connection -State Unauthorized -ErrorKind 'CredentialRequired' -ErrorMessage $message
                return New-MwpResult @common -Success $false -Message $message -Data (& $snapshot)
            }

            if ($null -ne $connection.Session) {
                Remove-MwpPSSession -Session $connection.Session
                $connection.Session = $null
            }
            Set-MwpConnectionState -Connection $connection -State Connecting
            try {
                $sessionArguments = @{
                    ComputerName            = $Context.Address
                    Port                    = $Context.Port
                    UseSsl                  = $Context.UseSsl
                    Credential              = $active
                    OpenTimeoutSeconds      = $Context.Policy.ConnectTimeoutSeconds
                    OperationTimeoutSeconds = $Context.Policy.OperationTimeoutSeconds
                }
                $connection.Session = New-MwpPSSession @sessionArguments
                # D-054: tożsamość przed zapamiętaniem hasła — przyjął je komputer pod adresem, nie koniecznie ten z nazwy.
                $identity = $null
                try {
                    $identity = Get-MwpRemoteIdentity -Session $connection.Session -TimeoutSeconds $Context.Policy.ConnectTimeoutSeconds
                }
                catch {
                    Write-MwpLog -Level Debug -Source 'MWP.Remote' -Operation $operation -ComputerName $Context.ComputerName `
                        -Message ("Nie udało się odczytać nazwy komputera pod adresem '{0}': {1}" -f $Context.Address, $_.Exception.Message)
                }
                $verified = Update-MwpConnectionIdentity -Context $Context -Identity $identity
                if ($verified -eq $false) {
                    Remove-MwpPSSession -Session $connection.Session
                    $connection.Session = $null
                    $message = Get-MwpRemoteErrorMessage -Kind 'NameMismatch' -Context $Context -RemoteName $connection.RemoteComputerName
                    Set-MwpConnectionState -Connection $connection -State Error -ErrorKind 'NameMismatch' -ErrorMessage $message
                    Write-MwpLog -Level Warning -Source 'MWP.Remote' -Operation $operation -ComputerName $Context.ComputerName -Message $message `
                        -Data @{ ErrorKind = 'NameMismatch'; Address = $Context.Address; RemoteComputerName = $connection.RemoteComputerName }
                    return New-MwpResult @common -Success $false -Message $message -Data (& $snapshot)
                }
                Set-MwpConnectionState -Connection $connection -State Connected
                if ($needsCredential -and $source -in @('Parameter', 'Context', 'Store')) {
                    $cacheSource = switch ($source) { 'Parameter' { 'Dialog' } 'Store' { 'Store' } default { 'Context' } }
                    $generation = Set-MwpCachedCredential -ComputerName $Context.ComputerName -Credential $active -Source $cacheSource
                    Set-MwpConnectionCredential -Connection $connection -Credential $active -Shared $true -Generation $generation
                }
                $user = if ($null -ne $active) { $active.UserName } else { $Context.Identity.UserName }
                $via = if ($Context.Address -ne $Context.ComputerName) { 'adres {0}, ' -f $Context.Address } else { '' }
                $message = "Połączono z komputerem '{0}' ({1}WinRM, port {2}, użytkownik: {3})." -f $Context.ComputerName, $via, $Context.Port, $user
                if (-not [string]::IsNullOrEmpty($connection.AddressWarning)) {
                    $message = '{0} Uwaga: {1}' -f $message, $connection.AddressWarning
                }
                if ($source -eq 'Store') {
                    $message = '{0} Użyto hasła z Menedżera poświadczeń Windows.' -f $message
                }
                if ($SaveCredential -and $explicit) {
                    $save = Save-MwpTargetCredential -Name $Context.ComputerName -Credential $active -Confirm:$false -WhatIf:$false
                    $saved = [bool]$save.Success
                    $message = '{0} {1}' -f $message, $save.Message
                }
                Write-MwpLog -Level Info -Source 'MWP.Remote' -Operation $operation -ComputerName $Context.ComputerName -Message $message -Data @{ CredentialSource = $source }
                New-MwpResult @common -Success $true -Changed $true -Message $message -Data (& $snapshot)
            }
            catch {
                $kind = Get-MwpRemoteErrorKind -Exception $_.Exception
                $state = if ($kind -eq 'Unauthorized') { 'Unauthorized' } else { 'Error' }
                $messageKind = $kind
                if ($kind -eq 'Unauthorized') {
                    $failedGeneration = $(if ($connection.CredentialShared) { [int]$connection.CredentialGeneration } else { -1 })
                    Set-MwpConnectionCredential -Connection $connection -Credential $null
                    if ($source -eq 'Store') {
                        $null = Set-MwpCachedCredentialInvalid -ComputerName $Context.ComputerName -Generation -1 -Source Store
                        $messageKind = 'StoredCredentialRejected'
                    }
                    elseif ($source -eq 'Cache') {
                        $null = Set-MwpCachedCredentialInvalid -ComputerName $Context.ComputerName -Generation $failedGeneration
                    }
                }
                $message = Get-MwpRemoteErrorMessage -Kind $messageKind -Context $Context -Detail $_.Exception.Message
                Set-MwpConnectionState -Connection $connection -State $state -ErrorKind $kind -ErrorMessage $_.Exception.Message
                Write-MwpLog -Level Warning -Source 'MWP.Remote' -Operation $operation -ComputerName $Context.ComputerName -Message $message -Data @{ ErrorKind = $kind; CredentialSource = $source }
                New-MwpResult @common -Success $false -Message $message -ErrorMessage $_.Exception.Message -Data (& $snapshot)
            }
        }
        finally {
            if ($lockTaken) {
                Exit-MwpCredentialLock -ComputerName $Context.ComputerName
            }
        }
    }
}
