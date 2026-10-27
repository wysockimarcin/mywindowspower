function Read-MwpPowerState {
    <#
    .SYNOPSIS
        Odczyt stanu przed zmianą (wzorzec funkcji zmieniającej system, krok 3): plany i wybrane ustawienia planu.

    .DESCRIPTION
        Wynik: Success, Result (MWP.Result błędu, gotowy do zwrócenia) i Status (MWP.PowerStatus).
        Błąd połączenia albo powercfg /list jest błędem odczytu.

    .PARAMETER Plan
        GUID planu, którego ustawienia czytamy (domyślnie plan aktywny).

    .PARAMETER Setting
        Identyfikatory ustawień do odczytu (domyślnie żadne).
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

        [ValidateNotNullOrEmpty()]
        [string] $Plan = 'SCHEME_CURRENT',

        [string[]] $Setting = @(),

        [switch] $IncludeSystem
    )

    $read = Invoke-MwpPowercfg -Context $Context -Command @(Get-MwpPowerQueryCommand -Plan $Plan -Setting $Setting) -Operation $Operation -IncludeSystem:$IncludeSystem
    if (-not $read.Success) {
        return [pscustomobject]@{ Success = $false; Result = $read.Result; Status = $null }
    }
    $list = Get-MwpPowercfgCommand -Raw $read.Raw -Id 'list'
    if (-not $list.Success) {
        $result = New-MwpResult -Success $false -Operation $Operation -Target $Context.ComputerName -ComputerName $Context.ComputerName `
            -Message ("Nie udało się odczytać planów zasilania na komputerze '{0}': {1}" -f $Context.ComputerName, $list.Message)
        return [pscustomobject]@{ Success = $false; Result = $result; Status = $null }
    }
    [pscustomobject]@{ Success = $true; Result = $null; Status = (Resolve-MwpPowerStatus -Data $read.Raw) }
}
