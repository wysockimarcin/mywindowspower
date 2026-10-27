function Restart-MwpService {
    <#
    .SYNOPSIS
        Uruchamia ponownie działającą usługę na komputerze docelowym razem z działającymi usługami zależnymi.

    .DESCRIPTION
        Operacja klasy Zmiana (D-027) z tymi samymi sprawdzeniami co Stop-MwpService (lista ochronna
        usługi i usług zależnych — D-045, uprawnienia administratora, podgląd z listą usług
        zależnych, potwierdzenie z nazwą komputera). Kolejność: zatrzymanie usług zależnych i usługi,
        uruchomienie usługi i usług zależnych; po błędzie wszystkie są uruchamiane ponownie.
        Bez wpisu cofnięcia: po ponownym uruchomieniu stan jest taki sam jak przed (opis w wyniku).

    .PARAMETER Name
        Nazwa usługi (nie nazwa wyświetlana).

    .EXAMPLE
        Restart-MwpService -Name Spooler -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateScript({ Test-MwpServiceName -Name $_ })]
        [string] $Name,

        [PSTypeName('MWP.ExecutionContext')]
        [object] $Context = (New-MwpExecutionContext)
    )

    $computerName = $Context.ComputerName
    $common = @{ Operation = 'Services.Restart'; Target = $Name; ComputerName = $computerName }

    $plan = Get-MwpServiceStopPlan -Context $Context -Operation $common.Operation -Name $Name -Verb 'uruchomić ponownie'
    if (-not $plan.Success) {
        return $plan.Result
    }
    $service = $plan.Service
    $common.Target = $service.Name
    if ($service.Status -ne 'Running') {
        return New-MwpResult @common -Success $false -Before $service.StatusText -Message ("Usługa '{0}' nie działa (stan: {1}) — użyj uruchomienia." -f $service.DisplayName, $service.StatusText)
    }
    $dependents = @($plan.Dependents)
    $startOrder = @($service.Name) + @(for ($index = $dependents.Count - 1; $index -ge 0; $index--) { $dependents[$index] })
    $dependentText = if ($dependents.Count -gt 0) { ' Usługi zależne zostaną zatrzymane i uruchomione ponownie: {0}.' -f ($dependents -join ', ') } else { '' }

    $target = Format-MwpOperationTarget -Target ("usługa '{0}' ({1})" -f $service.DisplayName, $service.Name) -ComputerName $computerName
    if (-not $PSCmdlet.ShouldProcess($target, ('Ponowne uruchomienie{0}' -f $dependentText))) {
        return New-MwpResult @common -Success $true -IsPreview -Before $service.StatusText -After 'Działa' `
            -Message ("Podgląd: ponowne uruchomienie usługi '{0}'.{1}" -f $service.DisplayName, $dependentText) -Data ([ordered]@{ Dependents = $dependents })
    }

    $steps = @(foreach ($item in @($dependents + $service.Name)) { @{ Name = $item; Action = 'Stop' } }) +
    @(foreach ($item in $startOrder) { @{ Name = $item; Action = 'Start' } })
    $change = Invoke-MwpServiceControl -Context $Context -Operation $common.Operation -Step $steps -Recover $startOrder
    if (-not $change.Success) {
        $message = "Nie udało się uruchomić ponownie usługi '{0}' na komputerze '{1}': {2}" -f $service.DisplayName, $computerName, $change.Message
        Write-MwpLog -Level Error -Source 'MWP.Services' -Operation $common.Operation -ComputerName $computerName -Message $message -Data @{ Dependents = $dependents }
        return New-MwpResult @common -Success $false -Before $service.StatusText -Message $message -ErrorMessage $change.ErrorMessage
    }
    $message = "Uruchomiono ponownie usługę '{0}' na komputerze '{1}'.{2} Bez wpisu cofnięcia (stan po operacji jest taki jak przed)." -f $service.DisplayName, $computerName,
    $(if ($dependents.Count -gt 0) { ' Także usługi zależne: {0}.' -f ($dependents -join ', ') } else { '' })
    Write-MwpLog -Level Info -Source 'MWP.Services' -Operation $common.Operation -ComputerName $computerName -Message $message -Data @{ Dependents = $dependents }
    New-MwpResult @common -Success $true -Changed $true -Before $service.StatusText -After 'Działa' -Message $message -Data ([ordered]@{ Dependents = $dependents })
}
