function Get-MwpTargetStatusScript {
    <#
    .SYNOPSIS
        Zwraca samowystarczalny blok skryptu sprawdzający dostępność portów WinRM komputerów z rejestru (widget „Komputery”, D-053).

    .DESCRIPTION
        Tylko próba połączenia TCP (TcpClient.BeginConnect z limitem 1 s), bez logowania i bez wysyłania
        danych. Argument: żądanie JSON (Probe, Targets: Name, Address — adres połączenia D-054, DisplayName, Port,
        Credential). Wynik: JSON
        z Kind = 'MWP.TargetStatusRaw'. Zgodny z 5.1.
    #>
    [CmdletBinding()]
    [OutputType([scriptblock])]
    param()

    {
        param([string] $RequestJson)

        $request = ConvertFrom-Json -InputObject $RequestJson
        $results = @(foreach ($target in @($request.Targets | Where-Object { $null -ne $_ })) {
                $reachable = $null
                $latency = $null
                $errorText = $null
                if ($request.Probe) {
                    $client = New-Object -TypeName System.Net.Sockets.TcpClient
                    $watch = [Diagnostics.Stopwatch]::StartNew()
                    try {
                        $probeAddress = if ($null -ne $target.PSObject.Properties['Address'] -and [string]$target.Address -ne '') { [string]$target.Address } else { [string]$target.Name }
                        $async = $client.BeginConnect($probeAddress, [int]$target.Port, $null, $null)
                        if ($async.AsyncWaitHandle.WaitOne(1000) -and $client.Connected) {
                            $client.EndConnect($async)
                            $reachable = $true
                            $latency = [int]$watch.ElapsedMilliseconds
                        }
                        else {
                            $reachable = $false
                            $errorText = 'brak odpowiedzi w 1 s'
                        }
                    }
                    catch {
                        $reachable = $false
                        $errorText = $_.Exception.InnerException.Message
                        if (-not $errorText) {
                            $errorText = $_.Exception.Message
                        }
                    }
                    finally {
                        $client.Close()
                    }
                }
                [pscustomobject]@{
                    Name        = [string]$target.Name
                    DisplayName = [string]$target.DisplayName
                    Port        = [int]$target.Port
                    Credential  = [string]$target.Credential
                    Reachable   = $reachable
                    LatencyMs   = $latency
                    Error       = $errorText
                }
            })
        ConvertTo-Json -Compress -Depth 4 -InputObject ([pscustomobject]@{
                Kind        = 'MWP.TargetStatusRaw'
                CollectedAt = (Get-Date).ToString('o')
                Probe       = [bool]$request.Probe
                Targets     = @($results)
            })
    }
}
