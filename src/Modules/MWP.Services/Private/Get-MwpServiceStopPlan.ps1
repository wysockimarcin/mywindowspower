function Get-MwpServiceStopPlan {
    <#
    .SYNOPSIS
        Wspólne sprawdzenia przed zatrzymaniem i ponownym uruchomieniem usługi: odczyt z grafem zależności, lista ochronna, uprawnienia.

    .DESCRIPTION
        Wynik: Success, Result (MWP.Result odmowy albo błędu, gotowy do zwrócenia), Service
        i Dependents — działające usługi zależne w kolejności zatrzymania (Get-MwpServiceDependent).
        Odmowa (D-045): usługa albo którakolwiek z działających usług zależnych jest na liście
        ochronnej; usługa działa, ale nie przyjmuje polecenia zatrzymania; brak administratora.
        Usługa zatrzymana nie jest błędem (wywołujący decyduje).

    .PARAMETER Verb
        Czasownik do komunikatów („zatrzymać”, „uruchomić ponownie”).
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
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Verb
    )

    $computerName = $Context.ComputerName
    $deny = {
        param([string] $Message, $Service)
        $result = New-MwpResult -Operation $Operation -Target $Name -ComputerName $computerName -Success $false -Message $Message `
            -Before $(if ($null -ne $Service) { $Service.StatusText } else { $null })
        [pscustomobject]@{ Success = $false; Result = $result; Service = $Service; Dependents = @() }
    }

    $state = Read-MwpServiceState -Context $Context -Operation $Operation -Target $Name -IncludeGraph
    if (-not $state.Success) {
        return [pscustomobject]@{ Success = $false; Result = $state.Result; Service = $null; Dependents = @() }
    }
    $service = $state.Service
    if ($service.IsProtected) {
        return & $deny ("Usługa '{0}' ({1}) jest na liście ochronnej — nie można jej {2}. Powód: {3}" -f $service.DisplayName, $service.Name, $Verb, $service.ProtectionReason) $service
    }
    if ($service.Status -eq 'Stopped') {
        return [pscustomobject]@{ Success = $true; Result = $null; Service = $service; Dependents = @() }
    }
    if (-not $service.CanStop) {
        return & $deny ("Usługa '{0}' nie przyjmuje teraz polecenia zatrzymania (stan: {1})." -f $service.DisplayName, $service.StatusText) $service
    }
    if (-not $state.List.HasGraph) {
        return & $deny ("Nie udało się odczytać zależności usługi '{0}', więc nie można jej bezpiecznie {1}." -f $service.DisplayName, $Verb) $service
    }
    $byName = @{}
    foreach ($item in @($state.List.Services)) {
        $byName[$item.Name.ToLowerInvariant()] = $item
    }
    $running = New-Object -TypeName System.Collections.Generic.List[string]
    foreach ($dependentName in @(Get-MwpServiceDependent -Dependencies @($state.List.Dependencies) -Name $service.Name)) {
        $dependent = $byName[$dependentName.ToLowerInvariant()]
        if ($null -eq $dependent -or $dependent.Status -eq 'Stopped') {
            continue
        }
        if ($dependent.IsProtected) {
            return & $deny ("Nie można {0} usługi '{1}': zależy od niej działająca usługa chroniona '{2}' ({3}). Powód ochrony: {4}" -f $Verb, $service.DisplayName, $dependent.DisplayName, $dependent.Name, $dependent.ProtectionReason) $service
        }
        $running.Add($dependent.Name)
    }

    $admin = Test-MwpServiceAdmin -Context $Context
    if (-not $admin.Success) {
        $result = New-MwpResult -Operation $Operation -Target $Name -ComputerName $computerName -Success $false -Message $admin.Result.Message -ErrorMessage $admin.Result.ErrorMessage
        return [pscustomobject]@{ Success = $false; Result = $result; Service = $service; Dependents = @() }
    }
    if (-not $admin.IsAdministrator) {
        return & $deny ("Zatrzymywanie usług wymaga uprawnień administratora na komputerze '{0}'." -f $computerName) $service
    }
    [pscustomobject]@{ Success = $true; Result = $null; Service = $service; Dependents = $running.ToArray() }
}
