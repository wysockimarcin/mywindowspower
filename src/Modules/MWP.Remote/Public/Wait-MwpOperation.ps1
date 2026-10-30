function Wait-MwpOperation {
    <#
    .SYNOPSIS
        Czeka na zakończenie operacji asynchronicznej i zwraca jej wynik (MWP.Result).

    .DESCRIPTION
        Czeka najdłużej do upływu limitu czasu operacji (TimeoutSeconds od startu); po jego
        przekroczeniu przerywa operację (status TimedOut). Wynik: Success, Data (wyjście bloku),
        ErrorMessage (błędy nieprzerywające przy ErrorPolicy Continue). Błąd przerywający albo
        błąd połączenia daje status Failed; wtedy Data.ErrorKind klasyfikuje błąd (NameMismatch — D-054,
        Unauthorized, Configuration, Timeout, Network, Other; po limicie czasu — Timeout), co pozwala widgetom
        odróżnić utratę połączenia od błędu danych (D-043). Kolejne wywołanie dla zakończonej operacji zwraca
        zapamiętany wynik.

    .PARAMETER WaitSeconds
        Najdłuższy czas oczekiwania w tym wywołaniu (bez przerywania operacji); po jego upływie,
        gdy operacja trwa dalej, funkcja zwraca $null.

    .EXAMPLE
        Start-MwpOperation -Context $remote -ScriptBlock { Get-Service } | Wait-MwpOperation
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [PSTypeName('MWP.Operation')]
        [object] $Operation,

        [ValidateRange(0, 86400)]
        [int] $WaitSeconds
    )

    process {
        if ($Operation.Status -ne 'Running') {
            return $Operation.Result
        }
        $common = @{ Operation = $Operation.Operation; Target = $Operation.ComputerName; ComputerName = $Operation.ComputerName }

        $remaining = $Operation.StartedAt.AddSeconds($Operation.TimeoutSeconds) - (Get-Date)
        if ($remaining -lt [TimeSpan]::Zero) {
            $remaining = [TimeSpan]::Zero
        }
        $limited = $PSBoundParameters.ContainsKey('WaitSeconds') -and [TimeSpan]::FromSeconds($WaitSeconds) -lt $remaining
        if ($limited) {
            $remaining = [TimeSpan]::FromSeconds($WaitSeconds)
        }

        $finished = $Operation.AsyncResult.AsyncWaitHandle.WaitOne($remaining)
        if (-not $finished) {
            if ($limited) {
                return $null
            }
            try {
                $Operation.PowerShell.Stop()
            }
            catch {
                Write-Verbose ("Zatrzymanie operacji {0}: {1}" -f $Operation.Id, $_.Exception.Message)
            }
            $message = "Operacja {0} na komputerze '{1}' przekroczyła limit czasu ({2} s) i została przerwana." -f $Operation.Operation, $Operation.ComputerName, $Operation.TimeoutSeconds
            return Complete-MwpOperation -Operation $Operation -Status TimedOut -Result (New-MwpResult @common -Success $false -Message $message -Data ([ordered]@{ ErrorKind = 'Timeout' }))
        }

        $powerShell = $Operation.PowerShell
        try {
            $output = @($powerShell.EndInvoke($Operation.AsyncResult))
            $streamErrors = @($powerShell.Streams.Error | ForEach-Object { $_.ToString() })
            $errorText = $streamErrors -join ' '
            if ($errorText -match 'MWP-NAMEMISMATCH:(\S*)') {
                # ErrorPolicy Continue: zdalny wyjątek blokady nazwy trafia do strumienia błędów, nie do wyjątku.
                throw $errorText
            }
            $message = "Wykonano operację {0} na komputerze '{1}'." -f $Operation.Operation, $Operation.ComputerName
            if ($errorText -ne '') {
                $message = "Wykonano operację {0} na komputerze '{1}' z błędami: {2}" -f $Operation.Operation, $Operation.ComputerName, $errorText
            }
            Complete-MwpOperation -Operation $Operation -Status Completed `
                -Result (New-MwpResult @common -Success $true -Message $message -ErrorMessage $errorText -Data $output)
        }
        catch {
            $exception = $_.Exception
            while ($exception -is [Management.Automation.MethodInvocationException] -and $null -ne $exception.InnerException) {
                $exception = $exception.InnerException
            }
            $kind = Get-MwpRemoteErrorKind -Exception $exception
            $detail = $exception.Message
            # D-052: odmowa dostępu dla hasła ze wspólnej pamięci wstrzymuje ponowienia wszystkich kontekstów komputera.
            $generationProperty = $Operation.PSObject.Properties['CredentialGeneration']
            if ($kind -eq 'Unauthorized' -and $null -ne $generationProperty -and [int]$generationProperty.Value -ge 0) {
                $null = Set-MwpCachedCredentialInvalid -ComputerName $Operation.ComputerName -Generation ([int]$generationProperty.Value)
            }
            $message = if ($kind -in @('NameMismatch', 'Unauthorized', 'Configuration', 'Network', 'Timeout')) {
                $address = if ($null -ne $Operation.PSObject.Properties['Address'] -and -not [string]::IsNullOrEmpty([string]$Operation.Address)) { [string]$Operation.Address } else { $Operation.ComputerName }
                $context = [pscustomobject]@{ PSTypeName = 'MWP.ExecutionContext'; ComputerName = $Operation.ComputerName; Address = $address; Port = $Operation.Port }
                if ($kind -eq 'NameMismatch') {
                    $remoteName = if ($detail -match 'MWP-NAMEMISMATCH:([^\s''"]*)') { $Matches[1] } else { '' }
                    Get-MwpRemoteErrorMessage -Kind $kind -Context $context -RemoteName $remoteName
                }
                else {
                    Get-MwpRemoteErrorMessage -Kind $kind -Context $context -Detail $detail
                }
            }
            else {
                "Operacja {0} na komputerze '{1}' nie powiodła się: {2}" -f $Operation.Operation, $Operation.ComputerName, $detail
            }
            Complete-MwpOperation -Operation $Operation -Status Failed -Result (New-MwpResult @common -Success $false -Message $message -ErrorMessage $detail -Data ([ordered]@{ ErrorKind = $kind }))
        }
    }
}
