function Invoke-MwpServiceControl {
    <#
    .SYNOPSIS
        Wykonuje kroki Start/Stop na komputerze docelowym (blok Control) i ocenia wynik (krok 5 wzorca zmiany).

    .DESCRIPTION
        Kroki wykonują się w jednym wywołaniu, po kolei, i zatrzymują na pierwszym błędzie; wtedy blok
        uruchamia ponownie usługi z -Recover (np. usługi zależne zatrzymane w tej operacji). Wynik:
        Success, Message (powód błędu po polsku: połączenie albo usługa), ErrorMessage, Final (stan
        końcowy usług operacji: Name, Status).

    .PARAMETER Step
        Lista kroków @{ Name = 'Spooler'; Action = 'Stop' } (Action: Start albo Stop).

    .PARAMETER Recover
        Usługi do ponownego uruchomienia po błędzie (w tej kolejności).

    .PARAMETER TimeoutSeconds
        Limit czasu oczekiwania na stan usługi w jednym kroku.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [PSTypeName('MWP.ExecutionContext')]
        [object] $Context,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Operation,

        [Parameter(Mandatory)]
        [object[]] $Step,

        [AllowEmptyCollection()]
        [string[]] $Recover = @(),

        [ValidateRange(1, 600)]
        [int] $TimeoutSeconds = 30
    )

    $request = ConvertTo-Json -Depth 4 -Compress -InputObject ([pscustomobject]@{
            Steps          = @(foreach ($entry in $Step) { [pscustomobject]@{ Name = [string]$entry.Name; Action = [string]$entry.Action } })
            Recover        = @($Recover)
            TimeoutSeconds = $TimeoutSeconds
        })
    $result = Invoke-MwpOnTarget -Context $Context -ScriptBlock (Get-MwpServiceScript -Name Control) -ArgumentList @($request) -Operation $Operation
    if (-not $result.Success) {
        return [pscustomobject]@{ Success = $false; Message = $result.Message; ErrorMessage = $result.ErrorMessage; Final = @() }
    }
    $raw = ConvertFrom-MwpServiceJson -Data $result -Kind 'MWP.ServiceControl'
    if ($null -eq $raw) {
        return [pscustomobject]@{ Success = $false; Message = ("Komputer '{0}' nie zwrócił wyniku operacji na usługach." -f $Context.ComputerName); ErrorMessage = $result.ErrorMessage; Final = @() }
    }
    $final = @($raw.Final | Where-Object { $null -ne $_ })
    if ($null -ne $raw.Failure) {
        $verb = if ($raw.Failure.Action -eq 'Stop') { 'zatrzymać' } else { 'uruchomić' }
        $message = "Nie udało się {0} usługi '{1}': {2}" -f $verb, $raw.Failure.Name, $raw.Failure.Message
        if (@($raw.Recovered).Count -gt 0) {
            $message = '{0} Ponownie uruchomiono: {1}.' -f $message, (@($raw.Recovered) -join ', ')
        }
        if ($final.Count -gt 0) {
            $message = '{0} Stan końcowy: {1}.' -f $message, (@($final | ForEach-Object { '{0} — {1}' -f $_.Name, (Get-MwpServiceText -Status $_.Status) }) -join ', ')
        }
        return [pscustomobject]@{ Success = $false; Message = $message; ErrorMessage = [string]$raw.Failure.Message; Final = $final }
    }
    [pscustomobject]@{ Success = $true; Message = ''; ErrorMessage = $null; Final = $final }
}
