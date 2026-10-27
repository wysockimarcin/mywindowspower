function Read-MwpScheduledTaskState {
    <#
    .SYNOPSIS
        Odczyt zadania przed zmianą (wzorzec funkcji zmieniającej system, krok 3) z listą ochronną i sprawdzeniem administratora.

    .DESCRIPTION
        Wynik: Success, Result (MWP.Result odmowy albo błędu, gotowy do zwrócenia), Task
        (MWP.ScheduledTask albo $null) i List. Nieczytelna lista ochronna jest błędem — bez niej
        żadna zmiana nie jest dozwolona. Z -AllowMissing brak zadania nie jest błędem (odtwarzanie).
        Wszystkie zmiany zadań wymagają administratora na komputerze docelowym (D-046); sprawdzenie
        jest wykonywane po odczycie, przed podglądem.
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

        [switch] $AllowMissing
    )

    $computerName = $Context.ComputerName
    $common = @{ Operation = $Operation; Target = ($TaskPath + $TaskName); ComputerName = $computerName }
    try {
        $protected = @(Get-MwpProtectedItem -Category Task) + @(Get-MwpProtectedItem -Category TaskRemoval)
    }
    catch {
        $result = New-MwpResult @common -Success $false -Message ('Nie można odczytać listy ochronnej zadań, więc zmiana jest zablokowana: {0}' -f $_.Exception.Message) -ErrorMessage $_.Exception.Message
        return [pscustomobject]@{ Success = $false; Result = $result; Task = $null; List = $null }
    }
    $read = Invoke-MwpStartupRead -Context $Context -Operation $Operation -Kind Task -TaskPath $TaskPath -TaskName $TaskName -NoSignature
    if (-not $read.Success) {
        $result = New-MwpResult @common -Success $false -Message $read.Result.Message -ErrorMessage $read.Result.ErrorMessage
        return [pscustomobject]@{ Success = $false; Result = $result; Task = $null; List = $null }
    }
    $list = Resolve-MwpScheduledTaskList -Data $read.Raw -ProtectedItem $protected
    $task = @($list.Tasks | Where-Object { $_.TaskPath -eq $TaskPath -and $_.TaskName -eq $TaskName }) | Select-Object -First 1
    if ($null -eq $task -and -not $AllowMissing) {
        $result = New-MwpResult @common -Success $false -Message ("Na komputerze '{0}' nie ma zadania '{1}{2}' (albo brak uprawnień do jego odczytu)." -f $computerName, $TaskPath, $TaskName)
        return [pscustomobject]@{ Success = $false; Result = $result; Task = $null; List = $list }
    }
    $admin = Test-MwpStartupAdmin -Context $Context
    if (-not $admin.Success) {
        $result = New-MwpResult @common -Success $false -Message $admin.Result.Message -ErrorMessage $admin.Result.ErrorMessage
        return [pscustomobject]@{ Success = $false; Result = $result; Task = $task; List = $list }
    }
    if (-not $admin.IsAdministrator) {
        $result = New-MwpResult @common -Success $false -Before $(if ($null -ne $task) { $task.StateText } else { $null }) `
            -Message ("Zmiany zadań harmonogramu wymagają uprawnień administratora na komputerze '{0}'." -f $computerName)
        return [pscustomobject]@{ Success = $false; Result = $result; Task = $task; List = $list }
    }
    [pscustomobject]@{ Success = $true; Result = $null; Task = $task; List = $list }
}
