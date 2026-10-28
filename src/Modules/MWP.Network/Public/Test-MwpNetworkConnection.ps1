function Test-MwpNetworkConnection {
    <#
    .SYNOPSIS
        Testy łączności wykonywane na komputerze docelowym: ping do bramy domyślnej i hosta zewnętrznego, rozwiązanie nazwy DNS i opcjonalnie port TCP.

    .DESCRIPTION
        Operacja klasy Odczyt (nic nie zmienia, D-049). Testy wykonuje komputer kontekstu (z jego punktu
        widzenia sieci): Net.NetworkInformation.Ping (ICMP, limit 3 s), Resolve-DnsName -DnsOnly
        -QuickTimeout, Net.Sockets.TcpClient z limitem czasu. Nazwy hostów i porty są sprawdzane przed
        wysłaniem (adres IP albo nazwa DNS, port 1–65535; D-015). Bez -AsOperation zwraca MWP.Result
        z MWP.NetworkTest w Data; z -AsOperation — uchwyt MWP.Operation (wynik: Resolve-MwpNetworkTest).
        Brak odpowiedzi na ping nie musi oznaczać braku łączności (zapora może blokować ICMP).

    .PARAMETER ExternalHost
        Host zewnętrzny do pingu (domyślnie 1.1.1.1); pusty = bez testu.

    .PARAMETER DnsName
        Nazwa do rozwiązania (domyślnie www.microsoft.com); pusta = bez testu.

    .PARAMETER PortHost
        Host testu portu TCP (razem z -Port).

    .PARAMETER Port
        Port TCP (1–65535).

    .EXAMPLE
        (Test-MwpNetworkConnection -PortHost 'example.com' -Port 443).Data.Tests | Format-Table
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [AllowEmptyString()]
        [string] $ExternalHost = '1.1.1.1',

        [AllowEmptyString()]
        [string] $DnsName = 'www.microsoft.com',

        [AllowEmptyString()]
        [string] $PortHost = '',

        [ValidateRange(0, 65535)]
        [int] $Port = 0,

        [PSTypeName('MWP.ExecutionContext')]
        [object] $Context = (New-MwpExecutionContext),

        [switch] $AsOperation
    )

    $operation = 'Network.Test'
    $common = @{ Operation = $operation; Target = $Context.ComputerName; ComputerName = $Context.ComputerName }
    foreach ($pair in @(@('host zewnętrzny', $ExternalHost), @('nazwa DNS', $DnsName), @('host portu', $PortHost))) {
        if ($pair[1] -and -not (Test-MwpNetworkHostName -Name $pair[1])) {
            $message = "Niepoprawna wartość — {0}: '{1}' (wymagany adres IP albo nazwa DNS)." -f $pair[0], $pair[1]
            if ($AsOperation) {
                throw $message
            }
            return New-MwpResult @common -Success $false -Message $message
        }
    }
    if (($PortHost -and $Port -eq 0) -or ($Port -gt 0 -and -not $PortHost)) {
        $message = 'Test portu wymaga hosta i portu (1–65535).'
        if ($AsOperation) {
            throw $message
        }
        return New-MwpResult @common -Success $false -Message $message
    }
    $request = ConvertTo-Json -Compress -InputObject ([pscustomobject]@{
            ExternalHost = $ExternalHost
            DnsName      = $DnsName
            PortHost     = $PortHost
            Port         = $Port
            TimeoutMs    = (Get-MwpNetworkTargetConfig).TestTimeoutMs
        })
    $block = Get-MwpNetworkScript -Name Test
    if ($AsOperation) {
        return Start-MwpOperation -Context $Context -ScriptBlock $block -ArgumentList @($request) -Operation $operation
    }
    $result = Invoke-MwpOnTarget -Context $Context -ScriptBlock $block -ArgumentList @($request) -Operation $operation
    if (-not $result.Success) {
        return New-MwpResult @common -Success $false -Message $result.Message -ErrorMessage $result.ErrorMessage
    }
    $test = Resolve-MwpNetworkTest -Data $result
    if ($null -eq $test) {
        return New-MwpResult @common -Success $false -Message ("Komputer '{0}' nie zwrócił wyników testów łączności." -f $Context.ComputerName) -ErrorMessage $result.ErrorMessage
    }
    New-MwpResult @common -Success $true -Message ("Testy łączności komputera '{0}': {1}" -f $Context.ComputerName, $test.Summary) -Data $test
}
