function Invoke-MwpScheduledTaskControl {
    <#
    .SYNOPSIS
        Wykonuje akcję na jednym zadaniu na komputerze docelowym (blok TaskControl) i ocenia wynik (krok 5 wzorca zmiany).

    .DESCRIPTION
        Wynik: Success, Message (powód błędu po polsku: połączenie albo zadanie), ErrorMessage,
        Exists i State (stan zadania po akcji) oraz Xml (dla Export).

    .PARAMETER Action
        Enable, Disable, Start, Export, Remove albo Register (z -Xml).
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
        [string] $TaskPath,

        [Parameter(Mandatory)]
        [string] $TaskName,

        [Parameter(Mandatory)]
        [ValidateSet('Enable', 'Disable', 'Start', 'Export', 'Remove', 'Register')]
        [string] $Action,

        [AllowEmptyString()]
        [string] $Xml = ''
    )

    $request = ConvertTo-Json -Compress -InputObject ([pscustomobject]@{
            TaskPath = $TaskPath
            TaskName = $TaskName
            Action   = $Action
            Xml      = $Xml
        })
    $result = Invoke-MwpOnTarget -Context $Context -ScriptBlock (Get-MwpStartupScript -Name TaskControl) -ArgumentList @($request) -Operation $Operation
    if (-not $result.Success) {
        return [pscustomobject]@{ Success = $false; Message = $result.Message; ErrorMessage = $result.ErrorMessage; Exists = $null; State = $null; Xml = $null }
    }
    $raw = ConvertFrom-MwpStartupJson -Data $result -Kind 'MWP.ScheduledTaskControl'
    if ($null -eq $raw) {
        return [pscustomobject]@{ Success = $false; Message = ("Komputer '{0}' nie zwrócił wyniku operacji na zadaniu." -f $Context.ComputerName); ErrorMessage = $result.ErrorMessage; Exists = $null; State = $null; Xml = $null }
    }
    if ($raw.Error) {
        $reason = if ([int64]$raw.ErrorCode -eq -2147024891) { 'odmowa dostępu (wymagane uprawnienia administratora)' } else { [string]$raw.Error }
        return [pscustomobject]@{ Success = $false; Message = $reason; ErrorMessage = [string]$raw.Error; Exists = [bool]$raw.Exists; State = $raw.State; Xml = $null }
    }
    [pscustomobject]@{ Success = $true; Message = ''; ErrorMessage = $null; Exists = [bool]$raw.Exists; State = $raw.State; Xml = $raw.Xml }
}
