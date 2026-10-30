function Test-MwpTarget {
    <#
    .SYNOPSIS
        Diagnozuje połączenie z komputerem docelowym w trzech krokach: sieć, uwierzytelnienie, autoryzacja.

    .DESCRIPTION
        Operacja klasy Odczyt; nie zmienia stanu połączenia kontekstu. Kroki:
        1. Reachable — usługa WinRM odpowiada na zapytanie WS-Management bez uwierzytelnienia;
        2. Authenticated — da się otworzyć sesję z poświadczeniami (używa aktywnej sesji kontekstu,
           a gdy jej nie ma — sesji tymczasowej, zamykanej na końcu);
        3. Authorized — da się wykonać polecenie w sesji; dodatkowo IsAdministrator (konto w grupie
           Administratorzy komputera docelowego) i wersja PowerShella na komputerze docelowym.
        Dla komputera lokalnego kroki 1–3 są spełnione, a IsAdministrator pochodzi z Test-MwpAdmin.
        Wynik: MWP.Result, szczegóły w Data (MWP.TargetTest); Success = wszystkie trzy kroki i brak
        niezgodności nazwy.
        D-054: diagnostyka łączy się pod adres połączenia (Address) i pokazuje nazwę zgłoszoną przez
        komputer (RemoteComputerName), wynik porównania z nazwą z rejestru (NameMatches: $true, $false
        = NameMismatch, $null = bez porównania), adresy wykryte (DetectedAddresses) i wartość, którą
        trzeba mieć w TrustedHosts klienta przy grupie roboczej (TrustedHostsValue = adres połączenia;
        przy adresie IP działa tylko NTLM). Aplikacja nie zmienia TrustedHosts.

    .EXAMPLE
        (Test-MwpTarget -Context $remote -Credential (Get-Credential)).Data
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [PSTypeName('MWP.ExecutionContext')]
        [object] $Context,

        [AllowNull()]
        [pscredential] $Credential
    )

    process {
        $operation = 'Remote.Test'
        $common = @{ Operation = $operation; Target = $Context.ComputerName; ComputerName = $Context.ComputerName }
        $connection = $Context.Connection
        $errors = New-Object -TypeName System.Collections.Generic.List[string]
        $test = [pscustomobject]@{
            PSTypeName      = 'MWP.TargetTest'
            ComputerName    = $Context.ComputerName
            Address         = $(if ($Context.Mode -eq 'Local') { '' } else { $Context.Address })
            Mode            = $Context.Mode
            Reachable       = $false
            Authenticated   = $false
            Authorized      = $false
            IsAdministrator = $false
            RemotePSVersion = $null
            RemoteComputerName = $null
            NameMatches     = $null
            DetectedAddresses = @()
            TrustedHostsValue = $(if ($Context.Mode -eq 'Local') { '' } else { $Context.Address })
            ErrorKind       = $null
            Errors          = @()
        }
        $finish = {
            $test.Errors = $errors.ToArray()
            $ok = $test.Reachable -and $test.Authenticated -and $test.Authorized -and $test.NameMatches -ne $false
            $message = if ($ok) {
                $details = New-Object -TypeName System.Collections.Generic.List[string]
                if ($Context.Mode -eq 'Remote') {
                    $details.Add(('adres połączenia: {0}' -f $Context.Address))
                    if ($null -ne $test.RemoteComputerName) {
                        $details.Add(('nazwa zgłoszona: {0}{1}' -f $test.RemoteComputerName, $(if ($test.NameMatches -eq $true) { ', zgodna' } else { '' })))
                    }
                    if (@($test.DetectedAddresses).Count -gt 0) {
                        $details.Add(('adresy wykryte: {0}' -f (@($test.DetectedAddresses) -join ', ')))
                    }
                    $details.Add(("TrustedHosts (grupa robocza): '{0}'{1}" -f $test.TrustedHostsValue, $(if (Test-MwpIPv4Address -Value $test.TrustedHostsValue) { ', przy adresie IP tylko NTLM' } else { '' })))
                }
                $suffix = if ($details.Count -gt 0) { ' {0}.' -f ($details -join '; ') } else { '' }
                "Komputer '{0}': dostępny, uwierzytelniony, autoryzowany (administrator: {1}).{2}" -f $Context.ComputerName, $(if ($test.IsAdministrator) { 'tak' } else { 'nie' }), $suffix
            }
            else {
                "Komputer '{0}': {1}" -f $Context.ComputerName, ($errors -join ' ')
            }
            $level = if ($ok) { 'Info' } else { 'Warning' }
            Write-MwpLog -Level $level -Source 'MWP.Remote' -Operation $operation -ComputerName $Context.ComputerName -Message $message
            New-MwpResult @common -Success $ok -Message $message -Data $test
        }

        if ($Context.Mode -eq 'Local') {
            $test.Reachable = $true
            $test.Authenticated = $true
            $test.Authorized = $true
            $test.IsAdministrator = [bool](Test-MwpAdmin)
            $test.RemotePSVersion = $PSVersionTable.PSVersion.ToString()
            return & $finish
        }

        try {
            Test-MwpWsMan -ComputerName $Context.Address -Port $Context.Port -UseSsl $Context.UseSsl
            $test.Reachable = $true
        }
        catch {
            $test.ErrorKind = Get-MwpRemoteErrorKind -Exception $_.Exception
            if ($test.ErrorKind -eq 'Unauthorized') {
                $test.ErrorKind = 'Network'
            }
            $errors.Add((Get-MwpRemoteErrorMessage -Kind $test.ErrorKind -Context $Context -Detail $_.Exception.Message))
            return & $finish
        }

        $fromContext = $null -eq $Credential
        if ($fromContext) {
            $Credential = Resolve-MwpConnectionCredential -Context $Context
        }
        $session = $null
        $temporary = $false
        if ($connection.State -eq 'Connected' -and $null -ne $connection.Session -and [string]$connection.Session.State -eq 'Opened') {
            $session = $connection.Session
        }
        elseif ($Context.Identity.Authentication -eq 'Credential' -and $null -eq $Credential) {
            $test.ErrorKind = 'CredentialRequired'
            $errors.Add((Get-MwpRemoteErrorMessage -Kind 'CredentialRequired' -Context $Context))
            return & $finish
        }

        try {
            if ($null -eq $session) {
                try {
                    $sessionArguments = @{
                        ComputerName            = $Context.Address
                        Port                    = $Context.Port
                        UseSsl                  = $Context.UseSsl
                        Credential              = $Credential
                        OpenTimeoutSeconds      = $Context.Policy.ConnectTimeoutSeconds
                        OperationTimeoutSeconds = $Context.Policy.OperationTimeoutSeconds
                    }
                    $session = New-MwpPSSession @sessionArguments
                    $temporary = $true
                }
                catch {
                    $test.ErrorKind = Get-MwpRemoteErrorKind -Exception $_.Exception
                    $shared = $null -ne $connection.PSObject.Properties['CredentialShared'] -and $connection.CredentialShared
                    if ($test.ErrorKind -eq 'Unauthorized' -and $fromContext -and $shared) {
                        $null = Set-MwpCachedCredentialInvalid -ComputerName $Context.ComputerName -Generation ([int]$connection.CredentialGeneration)
                        Set-MwpConnectionCredential -Connection $connection -Credential $null
                    }
                    $errors.Add((Get-MwpRemoteErrorMessage -Kind $test.ErrorKind -Context $Context -Detail $_.Exception.Message))
                    return & $finish
                }
            }
            $test.Authenticated = $true

            try {
                $probe = {
                    param([string] $NetworkScript)
                    $principal = New-Object -TypeName Security.Principal.WindowsPrincipal -ArgumentList ([Security.Principal.WindowsIdentity]::GetCurrent())
                    $hostName = $null
                    try {
                        $hostName = [System.Net.Dns]::GetHostName()
                    }
                    catch {
                        $hostName = $null
                    }
                    $network = $null
                    if (-not [string]::IsNullOrEmpty($NetworkScript)) {
                        try {
                            $network = & ([scriptblock]::Create($NetworkScript))
                        }
                        catch {
                            $network = @{ Interfaces = @(); PreferredAddress = $null; Error = $_.Exception.Message }
                        }
                    }
                    @{
                        IsAdministrator = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
                        PSVersion       = $PSVersionTable.PSVersion.ToString()
                        ComputerName    = $env:COMPUTERNAME
                        HostName        = $hostName
                        Network         = $network
                    }
                }
                $answer = Invoke-MwpSessionCommand -Session $session -ScriptBlock $probe -ArgumentList @((Get-MwpNetworkDataScript).ToString()) -TimeoutSeconds $Context.Policy.ConnectTimeoutSeconds
                $data = @($answer.Output | Where-Object { $_ -is [Collections.IDictionary] }) | Select-Object -First 1
                $test.Authorized = $true
                if ($null -ne $data) {
                    $test.IsAdministrator = [bool]$data['IsAdministrator']
                    $test.RemotePSVersion = [string]$data['PSVersion']
                    # D-054: nazwa zgłoszona i adresy wykryte; niezgodność nazwy to błąd diagnostyki (bez zmiany stanu połączenia).
                    $names = @([string]$data['ComputerName'], [string]$data['HostName'])
                    $test.RemoteComputerName = @($names | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) | Select-Object -First 1
                    $test.NameMatches = Test-MwpRemoteNameMatch -Name $Context.ComputerName -RemoteNames $names
                    if ($data['Network'] -is [Collections.IDictionary]) {
                        $test.DetectedAddresses = @((Select-MwpNetworkAddress -Data $data['Network']).AllAddresses)
                    }
                    if ($test.NameMatches -eq $false) {
                        $test.ErrorKind = 'NameMismatch'
                        $errors.Add((Get-MwpRemoteErrorMessage -Kind 'NameMismatch' -Context $Context -RemoteName $test.RemoteComputerName))
                    }
                }
            }
            catch {
                $test.ErrorKind = Get-MwpRemoteErrorKind -Exception $_.Exception
                $errors.Add((Get-MwpRemoteErrorMessage -Kind $test.ErrorKind -Context $Context -Detail $_.Exception.Message))
            }
            & $finish
        }
        finally {
            if ($temporary) {
                Remove-MwpPSSession -Session $session
            }
        }
    }
}
