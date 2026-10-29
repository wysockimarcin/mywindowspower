function Invoke-MwpOnTarget {
    <#
    .SYNOPSIS
        Wykonuje blok skryptu na komputerze docelowym kontekstu: lokalnie bezpośrednio, zdalnie przez sesję WinRM.

    .DESCRIPTION
        Jeden interfejs dla localhost i komputera zdalnego (D-019). Blok skryptu musi być
        samowystarczalny: dane przekazuje się przez -ArgumentList (bez $using: i bez zmiennych
        wywołującego), a kod musi działać w Windows PowerShell 5.1 bez modułów MWP (komputer zdalny
        ma tylko 5.1). Lokalnie blok jest wykonywany tak samo (odtworzony z tekstu), więc błąd
        założeń widać już na localhost.
        Zdalnie: przy braku połączenia i Policy.AutoConnect funkcja łączy się sama
        (Connect-MwpTarget); limit czasu z -TimeoutSeconds albo Policy.OperationTimeoutSeconds.
        Błędy nie są zgłaszane wyjątkiem, tylko jako MWP.Result z Success = $false; utrata
        połączenia zmienia stan kontekstu na Disconnected i nie wpływa na inne konteksty.
        Operacja nie jest ponawiana automatycznie (mogłaby zmienić system dwa razy); kolejne
        wywołanie połączy się ponownie. Wyjście bloku trafia do pola Data (tablica).
        Podgląd (-WhatIf), potwierdzenie i wpis cofnięcia należą do funkcji obszaru, która
        wywołuje Invoke-MwpOnTarget (wzorzec w ARCHITEKTURA.md).

    .PARAMETER Operation
        Nazwa operacji do wyniku i logu (np. 'Services.Get').

    .EXAMPLE
        (Invoke-MwpOnTarget -Context $remote -ScriptBlock { param($Name) Get-Service -Name $Name } -ArgumentList 'Spooler').Data
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [PSTypeName('MWP.ExecutionContext')]
        [object] $Context,

        [Parameter(Mandatory, Position = 1)]
        [scriptblock] $ScriptBlock,

        [AllowEmptyCollection()]
        [object[]] $ArgumentList = @(),

        [ValidateNotNullOrEmpty()]
        [string] $Operation = 'Remote.Invoke',

        [ValidateRange(1, 86400)]
        [int] $TimeoutSeconds
    )

    $common = @{ Operation = $Operation; Target = $Context.ComputerName; ComputerName = $Context.ComputerName }
    $connection = $Context.Connection
    if (-not $PSBoundParameters.ContainsKey('TimeoutSeconds')) {
        $TimeoutSeconds = $Context.Policy.OperationTimeoutSeconds
    }
    $stopOnError = $Context.Policy.ErrorPolicy -eq 'Stop'
    # Blok odtworzony z tekstu nie widzi zmiennych wywołującego — tak jak na komputerze zdalnym.
    $code = [scriptblock]::Create($ScriptBlock.ToString())
    $fail = {
        param($Message, $ErrorMessage, $Level)
        Write-MwpLog -Level $Level -Source 'MWP.Remote' -Operation $Operation -ComputerName $Context.ComputerName -Message $Message
        New-MwpResult @common -Success $false -Message $Message -ErrorMessage $ErrorMessage
    }
    $succeed = {
        param($Output, $Errors)
        $errorText = @($Errors | ForEach-Object { $_.ToString() }) -join ' '
        $message = "Wykonano operację {0} na komputerze '{1}'." -f $Operation, $Context.ComputerName
        if ($errorText -ne '') {
            $message = "Wykonano operację {0} na komputerze '{1}' z błędami: {2}" -f $Operation, $Context.ComputerName, $errorText
        }
        Write-MwpLog -Level Debug -Source 'MWP.Remote' -Operation $Operation -ComputerName $Context.ComputerName -Message $message
        New-MwpResult @common -Success $true -Message $message -ErrorMessage $errorText -Data $Output
    }

    if ($Context.Mode -eq 'Local') {
        try {
            $preference = if ($stopOnError) { 'Stop' } else { 'Continue' }
            # Jak w sesji zdalnej: bez trybu ścisłego modułu, z preferencją błędów z polityki kontekstu.
            $all = @(& {
                    Set-StrictMode -Off
                    $ErrorActionPreference = $preference
                    & $code @ArgumentList
                } 2>&1)
            $localErrors = @($all | Where-Object { $_ -is [Management.Automation.ErrorRecord] })
            $output = @($all | Where-Object { $_ -isnot [Management.Automation.ErrorRecord] })
            return & $succeed $output $localErrors
        }
        catch {
            return & $fail ("Operacja {0} na komputerze '{1}' nie powiodła się: {2}" -f $Operation, $Context.ComputerName, $_.Exception.Message) $_.Exception.Message 'Warning'
        }
    }

    $opened = $connection.State -eq 'Connected' -and $null -ne $connection.Session -and [string]$connection.Session.State -eq 'Opened'
    if (-not $opened) {
        if (-not $Context.Policy.AutoConnect) {
            return & $fail ("Brak połączenia z komputerem '{0}' (stan: {1}); użyj Connect-MwpTarget." -f $Context.ComputerName, $connection.State) $connection.LastError 'Warning'
        }
        $connect = Connect-MwpTarget -Context $Context
        if (-not $connect.Success) {
            return New-MwpResult @common -Success $false -Message $connect.Message -ErrorMessage $connect.ErrorMessage
        }
    }

    try {
        $answer = Invoke-MwpSessionCommand -Session $connection.Session -ScriptBlock $code -ArgumentList $ArgumentList -TimeoutSeconds $TimeoutSeconds
        $remoteErrors = @($answer.Errors)
        if ($stopOnError -and $remoteErrors.Count -gt 0) {
            $text = @($remoteErrors | ForEach-Object { $_.ToString() }) -join ' '
            return & $fail ("Operacja {0} na komputerze '{1}' zgłosiła błąd: {2}" -f $Operation, $Context.ComputerName, $text) $text 'Warning'
        }
        & $succeed @($answer.Output) $remoteErrors
    }
    catch {
        $exception = $_.Exception
        $kind = Get-MwpRemoteErrorKind -Exception $exception
        $sessionBroken = $null -eq $connection.Session -or [string]$connection.Session.State -ne 'Opened'
        if ($exception -is [Management.Automation.Remoting.PSRemotingTransportException] -or $sessionBroken) {
            # Utrata połączenia dotyczy tylko tego kontekstu; następne wywołanie połączy się ponownie.
            Remove-MwpPSSession -Session $connection.Session
            $connection.Session = $null
            $state = if ($kind -eq 'Unauthorized') { 'Unauthorized' } else { 'Disconnected' }
            if ($kind -eq 'Unauthorized') {
                # D-052: odrzucone hasło znika z połączenia; wspólne — unieważnione dla wszystkich kontekstów komputera.
                if ($null -ne $connection.PSObject.Properties['CredentialShared'] -and $connection.CredentialShared) {
                    $null = Set-MwpCachedCredentialInvalid -ComputerName $Context.ComputerName -Generation ([int]$connection.CredentialGeneration)
                }
                Set-MwpConnectionCredential -Connection $connection -Credential $null
            }
            Set-MwpConnectionState -Connection $connection -State $state -ErrorKind 'ConnectionLost' -ErrorMessage $exception.Message
            $message = Get-MwpRemoteErrorMessage -Kind 'ConnectionLost' -Context $Context -Detail $exception.Message
            return & $fail $message $exception.Message 'Warning'
        }
        if ($kind -eq 'Timeout') {
            $message = "Operacja {0} na komputerze '{1}' przekroczyła limit czasu ({2} s) i została przerwana." -f $Operation, $Context.ComputerName, $TimeoutSeconds
            return & $fail $message $exception.Message 'Warning'
        }
        & $fail ("Operacja {0} na komputerze '{1}' nie powiodła się: {2}" -f $Operation, $Context.ComputerName, $exception.Message) $exception.Message 'Warning'
    }
}
