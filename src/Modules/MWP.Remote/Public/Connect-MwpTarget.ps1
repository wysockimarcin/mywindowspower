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
        komputera. Poświadczenia trzymane są tylko w pamięci, w obiekcie połączenia; po odmowie
        dostępu są czyszczone. Funkcja nie wyświetla okna poświadczeń (to zadanie warstwy UI).

    .PARAMETER Credential
        Poświadczenia (np. Get-Credential); zastępują zapamiętane w połączeniu.

    .EXAMPLE
        Connect-MwpTarget -Context $remote -Credential (Get-Credential)
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
        $operation = 'Remote.Connect'
        $common = @{ Operation = $operation; Target = $Context.ComputerName; ComputerName = $Context.ComputerName }
        $connection = $Context.Connection
        $snapshot = {
            [pscustomobject]@{ State = $connection.State; ErrorKind = $connection.ErrorKind }
        }

        if ($Context.Mode -eq 'Local') {
            return New-MwpResult @common -Success $true -Message 'Komputer lokalny: połączenie nie jest potrzebne.' -Data (& $snapshot)
        }
        if ($null -ne $Credential) {
            $connection.Credential = $Credential
        }
        if ($connection.State -eq 'Connected' -and $null -ne $connection.Session -and [string]$connection.Session.State -eq 'Opened') {
            return New-MwpResult @common -Success $true -Message ("Połączenie z komputerem '{0}' jest już aktywne." -f $Context.ComputerName) -Data (& $snapshot)
        }
        if ($Context.Identity.Authentication -eq 'Credential' -and $null -eq $connection.Credential) {
            $message = Get-MwpRemoteErrorMessage -Kind 'CredentialRequired' -Context $Context
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
                ComputerName            = $Context.ComputerName
                Port                    = $Context.Port
                UseSsl                  = $Context.UseSsl
                Credential              = $connection.Credential
                OpenTimeoutSeconds      = $Context.Policy.ConnectTimeoutSeconds
                OperationTimeoutSeconds = $Context.Policy.OperationTimeoutSeconds
            }
            $connection.Session = New-MwpPSSession @sessionArguments
            Set-MwpConnectionState -Connection $connection -State Connected
            $user = if ($null -ne $connection.Credential) { $connection.Credential.UserName } else { $Context.Identity.UserName }
            $message = "Połączono z komputerem '{0}' (WinRM, port {1}, użytkownik: {2})." -f $Context.ComputerName, $Context.Port, $user
            Write-MwpLog -Level Info -Source 'MWP.Remote' -Operation $operation -ComputerName $Context.ComputerName -Message $message
            New-MwpResult @common -Success $true -Changed $true -Message $message -Data (& $snapshot)
        }
        catch {
            $kind = Get-MwpRemoteErrorKind -Exception $_.Exception
            $state = if ($kind -eq 'Unauthorized') { 'Unauthorized' } else { 'Error' }
            if ($kind -eq 'Unauthorized') {
                $connection.Credential = $null
            }
            $message = Get-MwpRemoteErrorMessage -Kind $kind -Context $Context -Detail $_.Exception.Message
            Set-MwpConnectionState -Connection $connection -State $state -ErrorKind $kind -ErrorMessage $_.Exception.Message
            Write-MwpLog -Level Warning -Source 'MWP.Remote' -Operation $operation -ComputerName $Context.ComputerName -Message $message -Data @{ ErrorKind = $kind }
            New-MwpResult @common -Success $false -Message $message -ErrorMessage $_.Exception.Message -Data (& $snapshot)
        }
    }
}
