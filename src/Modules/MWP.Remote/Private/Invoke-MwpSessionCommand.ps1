function Invoke-MwpSessionCommand {
    <#
    .SYNOPSIS
        Adapter transportu: wykonuje blok skryptu w sesji WinRM z limitem czasu.

    .DESCRIPTION
        Wywołanie działa jako zadanie (Invoke-Command -AsJob), więc limit czasu jest egzekwowany
        po stronie hosta: po jego przekroczeniu zadanie jest zatrzymywane i zgłaszany jest
        TimeoutException. Błąd przerywający (w skrypcie albo transportu) jest zgłaszany jako
        wyjątek; błędy nieprzerywające wracają w polu Errors. Testy podmieniają tę funkcję mockiem.

    .OUTPUTS
        Obiekt z polami Output (tablica) i Errors (tablica ErrorRecord).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [object] $Session,

        [Parameter(Mandatory)]
        [scriptblock] $ScriptBlock,

        [object[]] $ArgumentList = @(),

        [Parameter(Mandatory)]
        [int] $TimeoutSeconds
    )

    $job = Invoke-Command -Session $Session -ScriptBlock $ScriptBlock -ArgumentList $ArgumentList -AsJob
    try {
        if ($null -eq (Wait-Job -Job $job -Timeout $TimeoutSeconds)) {
            Stop-Job -Job $job
            throw (New-Object -TypeName TimeoutException -ArgumentList ("Przekroczono limit czasu operacji ({0} s)." -f $TimeoutSeconds))
        }
        $jobErrors = $null
        $output = @(Receive-Job -Job $job -ErrorVariable jobErrors -ErrorAction SilentlyContinue)
        if ($job.State -eq 'Failed') {
            $reason = @($job.ChildJobs | ForEach-Object { $_.JobStateInfo.Reason } | Where-Object { $null -ne $_ }) | Select-Object -First 1
            if ($null -ne $reason) {
                throw $reason
            }
            if (@($jobErrors).Count -gt 0) {
                throw @($jobErrors)[0].Exception
            }
            throw 'Zdalne wykonanie zakończyło się błędem.'
        }
        [pscustomobject]@{
            Output = $output
            Errors = @($jobErrors | Where-Object { $null -ne $_ })
        }
    }
    finally {
        Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
    }
}
