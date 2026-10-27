function Invoke-MwpPowerChange {
    <#
    .SYNOPSIS
        Wykonuje sekwencję poleceń powercfg zmieniających system i ocenia wynik (krok 5 wzorca zmiany).

    .DESCRIPTION
        Polecenia wykonują się w jednym wywołaniu na komputerze docelowym i zatrzymują na pierwszym
        błędzie. Wynik: Success, Message (powód błędu po polsku: połączenie albo kod powercfg),
        ErrorMessage, Raw (surowe wyniki, np. wyjście /duplicatescheme).
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
        [object[]] $Command
    )

    $change = Invoke-MwpPowercfg -Context $Context -Operation $Operation -Command $Command -StopOnError
    if (-not $change.Success) {
        return [pscustomobject]@{ Success = $false; Message = $change.Result.Message; ErrorMessage = $change.Result.ErrorMessage; Raw = $null }
    }
    foreach ($entry in $Command) {
        $result = Get-MwpPowercfgCommand -Raw $change.Raw -Id ([string]$entry.Id)
        if (-not $result.Success) {
            return [pscustomobject]@{ Success = $false; Message = $result.Message; ErrorMessage = ($result.Output -join ' '); Raw = $change.Raw }
        }
    }
    [pscustomobject]@{ Success = $true; Message = ''; ErrorMessage = $null; Raw = $change.Raw }
}
