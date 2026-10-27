function Invoke-MwpPowercfg {
    <#
    .SYNOPSIS
        Wykonuje polecenia powercfg na komputerze docelowym kontekstu i zwraca ich surowe wyniki.

    .DESCRIPTION
        Jedno wywołanie Invoke-MwpOnTarget (jedna podróż do komputera zdalnego) dla listy poleceń
        { Id; Arguments }. Zwraca obiekt: Success, Result (MWP.Result z Invoke-MwpOnTarget, przy błędzie
        z komunikatem), Raw (obiekt MWP.PowerRaw: Commands, System) i funkcję pomocniczą przez
        Get-MwpPowercfgCommand. Z -AsOperation zwraca uchwyt MWP.Operation (Start-MwpOperation).

    .PARAMETER Command
        Lista poleceń: @{ Id = 'list'; Arguments = @('/list') }.

    .PARAMETER IncludeSystem
        Dołącza stan hibernacji, szybkiego uruchamiania, baterii i uprawnień administratora.

    .PARAMETER StopOnError
        Przerywa po pierwszym poleceniu z niezerowym kodem wyjścia (sekwencje zmian).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [PSTypeName('MWP.ExecutionContext')]
        [object] $Context,

        [AllowEmptyCollection()]
        [object[]] $Command = @(),

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Operation,

        [switch] $IncludeSystem,

        [switch] $StopOnError,

        [switch] $AsOperation
    )

    $items = @(foreach ($entry in $Command) {
            [pscustomobject]@{ Id = [string]$entry.Id; Arguments = @(@($entry.Arguments) | ForEach-Object { [string]$_ }) }
        })
    $request = ConvertTo-Json -Depth 5 -Compress -InputObject ([pscustomobject]@{
            Commands      = $items
            IncludeSystem = [bool]$IncludeSystem
            StopOnError   = [bool]$StopOnError
        })
    $block = Get-MwpPowerScript -Name Powercfg
    if ($AsOperation) {
        return Start-MwpOperation -Context $Context -ScriptBlock $block -ArgumentList @($request) -Operation $Operation
    }

    $result = Invoke-MwpOnTarget -Context $Context -ScriptBlock $block -ArgumentList @($request) -Operation $Operation
    $raw = $null
    if ($result.Success) {
        $raw = ConvertFrom-MwpPowerJson -Data $result -Kind 'MWP.PowerRaw'
        if ($null -eq $raw) {
            $result = New-MwpResult -Success $false -Operation $Operation -Target $Context.ComputerName -ComputerName $Context.ComputerName `
                -Message ("Komputer '{0}' nie zwrócił wyniku powercfg." -f $Context.ComputerName) -ErrorMessage $result.ErrorMessage
        }
    }
    [pscustomobject]@{
        Success = $null -ne $raw
        Result  = $result
        Raw     = $raw
    }
}
