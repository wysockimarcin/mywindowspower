function Invoke-MwpWinget {
    <#
    .SYNOPSIS
        Uruchamia winget na komputerze docelowym (blok Winget) i zwraca surowy wynik z opisem błędu.

    .DESCRIPTION
        Argumenty jako tablica (każdy osobno, D-015); zawsze z --disable-interactivity. Wynik:
        Success (winget znaleziony, zakończony w limicie, kod 0 albo kod z -AllowedExitCode), Found,
        ExitCode, Lines, Message (po polsku), Result (MWP.Result błędu połączenia). Z -AsOperation zwraca
        uchwyt Start-MwpOperation (wynik czyta Resolve-MwpWingetPackage).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [PSTypeName('MWP.ExecutionContext')]
        [object] $Context,

        [Parameter(Mandatory)]
        [string[]] $Argument,

        [Parameter(Mandatory)]
        [string] $Operation,

        [int] $TimeoutSeconds = 0,

        [long[]] $AllowedExitCode = @(),

        [switch] $AsOperation
    )

    $config = Get-MwpAppsTargetConfig
    if ($TimeoutSeconds -le 0) {
        $TimeoutSeconds = $config.ReadTimeoutSeconds
    }
    $arguments = @($Argument)
    if ($arguments -notcontains '--disable-interactivity') {
        $arguments += '--disable-interactivity'
    }
    $request = ConvertTo-Json -Compress -InputObject ([pscustomobject]@{
            Arguments      = $arguments
            WingetPath     = [string]$config.WingetPath
            TimeoutSeconds = $TimeoutSeconds
        })
    $block = Get-MwpAppsScript -Name Winget
    if ($AsOperation) {
        return Start-MwpOperation -Context $Context -ScriptBlock $block -ArgumentList @($request) -Operation $Operation -TimeoutSeconds ($TimeoutSeconds + 60)
    }
    $result = Invoke-MwpOnTarget -Context $Context -ScriptBlock $block -ArgumentList @($request) -Operation $Operation -TimeoutSeconds ($TimeoutSeconds + 60)
    if (-not $result.Success) {
        return [pscustomobject]@{ Success = $false; Found = $false; ExitCode = $null; Lines = @(); Message = $result.Message; ErrorMessage = $result.ErrorMessage; Result = $result }
    }
    ConvertTo-MwpWingetCall -Data $result -AllowedExitCode $AllowedExitCode -ComputerName $Context.ComputerName
}
