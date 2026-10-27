function Invoke-MwpStartupRead {
    <#
    .SYNOPSIS
        Odczytuje pozycje autostartu albo zadania harmonogramu na komputerze docelowym kontekstu i zwraca surowy wynik.

    .DESCRIPTION
        Jedno wywołanie Invoke-MwpOnTarget (jedna podróż do komputera zdalnego). Wynik: Success,
        Result (MWP.Result błędu, gotowy do zwrócenia) i Raw (MWP.StartupItemRaw albo
        MWP.ScheduledTaskRaw). Z -AsOperation zwraca uchwyt MWP.Operation (Start-MwpOperation).
        Pozycje profili użytkowników (D-046): lokalnie HKCU bieżącego konta (UserMode Current),
        zdalnie profile użytkowników zalogowanych na komputerze docelowym (UserMode LoggedOn).

    .PARAMETER Kind
        Item (autostart) albo Task (harmonogram).

    .PARAMETER TaskPath
        Tylko zadania z tego folderu (z TaskName — jedno zadanie).

    .PARAMETER NoSignature
        Bez sprawdzania podpisów plików (szybszy odczyt przed zmianą).
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
        [ValidateSet('Item', 'Task')]
        [string] $Kind,

        [AllowEmptyString()]
        [string] $TaskPath = '',

        [AllowEmptyString()]
        [string] $TaskName = '',

        [switch] $NoSignature,

        [switch] $AsOperation
    )

    if ($Kind -eq 'Item') {
        $request = ConvertTo-Json -Compress -InputObject ([pscustomobject]@{
                UserMode         = $(if ($Context.Mode -eq 'Local') { 'Current' } else { 'LoggedOn' })
                IncludeSignature = -not $NoSignature
            })
        $block = Get-MwpStartupScript -Name ItemList
        $rawKind = 'MWP.StartupItemRaw'
        $what = 'pozycji autostartu'
    }
    else {
        $request = ConvertTo-Json -Compress -InputObject ([pscustomobject]@{
                TaskPath         = $TaskPath
                TaskName         = $TaskName
                IncludeSignature = -not $NoSignature
                SkipSignature    = @('\Microsoft\*')
            })
        $block = Get-MwpStartupScript -Name TaskList
        $rawKind = 'MWP.ScheduledTaskRaw'
        $what = 'zadań harmonogramu'
    }
    if ($AsOperation) {
        return Start-MwpOperation -Context $Context -ScriptBlock $block -ArgumentList @($request) -Operation $Operation
    }

    $common = @{ Operation = $Operation; Target = $Context.ComputerName; ComputerName = $Context.ComputerName }
    $result = Invoke-MwpOnTarget -Context $Context -ScriptBlock $block -ArgumentList @($request) -Operation $Operation
    if (-not $result.Success) {
        return [pscustomobject]@{ Success = $false; Result = $result; Raw = $null }
    }
    $raw = ConvertFrom-MwpStartupJson -Data $result -Kind $rawKind
    if ($null -eq $raw) {
        $failed = New-MwpResult @common -Success $false -Message ("Komputer '{0}' nie zwrócił listy {1}." -f $Context.ComputerName, $what) -ErrorMessage $result.ErrorMessage
        return [pscustomobject]@{ Success = $false; Result = $failed; Raw = $null }
    }
    if ($raw.Error) {
        $failed = New-MwpResult @common -Success $false -Message ("Nie udało się odczytać {0} na komputerze '{1}': {2}" -f $what, $Context.ComputerName, $raw.Error) -ErrorMessage $raw.Error
        return [pscustomobject]@{ Success = $false; Result = $failed; Raw = $raw }
    }
    [pscustomobject]@{ Success = $true; Result = $result; Raw = $raw }
}
