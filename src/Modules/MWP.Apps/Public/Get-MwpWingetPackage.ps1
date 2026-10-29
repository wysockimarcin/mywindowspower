function Get-MwpWingetPackage {
    <#
    .SYNOPSIS
        Lista zainstalowanych pakietów rozpoznanych przez winget w źródle 'winget' (winget list), opcjonalnie tylko z dostępną aktualizacją.

    .DESCRIPTION
        Operacja klasy Odczyt na komputerze kontekstu (D-019, D-050): winget list --source winget
        [--upgrade-available] [--id <Id> --exact] z --disable-interactivity, bez akceptacji umów.
        Wynik: MWP.Result z MWP.WingetList w Data (pakiety: nazwa i wersja zainstalowana, identyfikator
        źródła, wersja dostępna). Brak winget albo błąd — Success = $false z komunikatem. Z -AsOperation
        zwraca uchwyt operacji w tle; wynik zamienia Resolve-MwpWingetPackage -Kind List.

    .PARAMETER UpgradeAvailable
        Tylko pakiety z dostępną aktualizacją.

    .PARAMETER Id
        Tylko pakiet o tym identyfikatorze (dokładne dopasowanie).

    .EXAMPLE
        (Get-MwpWingetPackage -UpgradeAvailable).Data.Packages | Format-Table Name, Id, Version, Available
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Position = 0)]
        [PSTypeName('MWP.ExecutionContext')]
        [object] $Context = (New-MwpExecutionContext),

        [switch] $UpgradeAvailable,

        [ValidateNotNullOrEmpty()]
        [string] $Id,

        [switch] $AsOperation
    )

    $operation = if ($UpgradeAvailable) { 'Apps.WingetUpgradeList' } else { 'Apps.WingetList' }
    $common = @{ Operation = $operation; Target = $Context.ComputerName; ComputerName = $Context.ComputerName }
    $arguments = @('list', '--source', (Get-MwpAppsTargetConfig).Source)
    if ($UpgradeAvailable) {
        $arguments += '--upgrade-available'
    }
    if ($PSBoundParameters.ContainsKey('Id')) {
        if (-not (Test-MwpWingetId -Id $Id)) {
            throw ("Niepoprawny identyfikator pakietu winget: '{0}'." -f $Id)
        }
        $arguments += @('--id', $Id, '--exact')
    }
    if ($AsOperation) {
        return Invoke-MwpWinget -Context $Context -Argument $arguments -Operation $operation -AsOperation
    }
    $call = Invoke-MwpWinget -Context $Context -Argument $arguments -Operation $operation -AllowedExitCode 0x8A150014L
    if ($null -ne $call.Result) {
        return New-MwpResult @common -Success $false -Message $call.Message -ErrorMessage $call.ErrorMessage
    }
    $list = Resolve-MwpWingetPackage -Kind List -Data ([pscustomobject]@{
            Kind = 'MWP.WingetRaw'; Found = $call.Found; WingetPath = $call.WingetPath; ExitCode = $call.ExitCode; TimedOut = $false
            Lines = $call.Lines; Error = $null; DurationMs = $call.DurationMs
        })
    if (-not $call.Success) {
        return New-MwpResult @common -Success $false -Message $call.Message -ErrorMessage $call.ErrorMessage -Data $list
    }
    $count = @($list.Packages).Count
    $message = if ($UpgradeAvailable) { "Komputer '{0}': {1} pakietów z dostępną aktualizacją (winget)." -f $Context.ComputerName, $count } else { "Komputer '{0}': {1} pakietów rozpoznanych przez winget." -f $Context.ComputerName, $count }
    New-MwpResult @common -Success $true -Message $message -Data $list
}
