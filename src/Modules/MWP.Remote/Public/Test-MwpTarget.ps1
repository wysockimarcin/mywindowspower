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
        Wynik: MWP.Result, szczegóły w Data (MWP.TargetTest); Success = wszystkie trzy kroki.

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
            Mode            = $Context.Mode
            Reachable       = $false
            Authenticated   = $false
            Authorized      = $false
            IsAdministrator = $false
            RemotePSVersion = $null
            ErrorKind       = $null
            Errors          = @()
        }
        $finish = {
            $test.Errors = $errors.ToArray()
            $ok = $test.Reachable -and $test.Authenticated -and $test.Authorized
            $message = if ($ok) {
                "Komputer '{0}': dostępny, uwierzytelniony, autoryzowany (administrator: {1})." -f $Context.ComputerName, $(if ($test.IsAdministrator) { 'tak' } else { 'nie' })
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
            Test-MwpWsMan -ComputerName $Context.ComputerName -Port $Context.Port -UseSsl $Context.UseSsl
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

        if ($null -eq $Credential) {
            $Credential = $connection.Credential
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
                        ComputerName            = $Context.ComputerName
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
                    $errors.Add((Get-MwpRemoteErrorMessage -Kind $test.ErrorKind -Context $Context -Detail $_.Exception.Message))
                    return & $finish
                }
            }
            $test.Authenticated = $true

            try {
                $probe = {
                    $principal = New-Object -TypeName Security.Principal.WindowsPrincipal -ArgumentList ([Security.Principal.WindowsIdentity]::GetCurrent())
                    @{
                        IsAdministrator = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
                        PSVersion       = $PSVersionTable.PSVersion.ToString()
                    }
                }
                $answer = Invoke-MwpSessionCommand -Session $session -ScriptBlock $probe -TimeoutSeconds $Context.Policy.ConnectTimeoutSeconds
                $data = @($answer.Output | Where-Object { $_ -is [Collections.IDictionary] }) | Select-Object -First 1
                $test.Authorized = $true
                if ($null -ne $data) {
                    $test.IsAdministrator = [bool]$data['IsAdministrator']
                    $test.RemotePSVersion = [string]$data['PSVersion']
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
