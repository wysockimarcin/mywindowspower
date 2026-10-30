function Get-MwpRemoteIdentity {
    <#
    .SYNOPSIS
        Adapter transportu: odczytuje w otwartej sesji WinRM tożsamość komputera (nazwa, nazwa hosta, karty sieciowe).

    .DESCRIPTION
        D-054: jedno tanie wywołanie w tej samej sesji zaraz po połączeniu (Connect-MwpTarget,
        Get-MwpTargetComputerName). Zwraca słownik z kluczem MwpIdentity (ComputerName, HostName,
        Network) albo zgłasza wyjątek (np. limit czasu). Testy podmieniają tę funkcję mockiem.
    #>
    [CmdletBinding()]
    [OutputType([Collections.IDictionary])]
    param(
        [Parameter(Mandatory)]
        [object] $Session,

        [Parameter(Mandatory)]
        [int] $TimeoutSeconds
    )

    $networkScript = (Get-MwpNetworkDataScript).ToString()
    $job = Invoke-Command -Session $Session -ScriptBlock (Get-MwpRemoteIdentityScript) -ArgumentList $networkScript -AsJob
    try {
        if ($null -eq (Wait-Job -Job $job -Timeout $TimeoutSeconds)) {
            Stop-Job -Job $job
            throw (New-Object -TypeName TimeoutException -ArgumentList ("Przekroczono limit czasu odczytu nazwy komputera ({0} s)." -f $TimeoutSeconds))
        }
        $output = @(Receive-Job -Job $job -ErrorAction Stop)
    }
    finally {
        Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
    }
    @($output | Where-Object { $_ -is [Collections.IDictionary] -and $_.Contains('MwpIdentity') }) | Select-Object -First 1
}
