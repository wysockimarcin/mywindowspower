function Stop-MwpService {
    <#
    .SYNOPSIS
        Zatrzymuje usługę na komputerze docelowym razem z działającymi usługami zależnymi.

    .DESCRIPTION
        Operacja klasy Zmiana (D-027): odczyt usług i grafu zależności, lista ochronna (odmowa, gdy
        usługa albo którakolwiek z działających usług zależnych jest chroniona, D-045), uprawnienia
        administratora na komputerze docelowym, podgląd (-WhatIf) z listą usług zależnych
        i potwierdzenie z nazwą komputera. Usługi zależne są zatrzymywane najpierw (od najdalszych
        w łańcuchu); gdy któryś krok się nie uda, zatrzymane usługi zależne są uruchamiane ponownie.
        Wpis cofnięcia: Start-MwpService z tymi samymi usługami zależnymi.

    .PARAMETER Name
        Nazwa usługi (nie nazwa wyświetlana).

    .EXAMPLE
        Stop-MwpService -Name Spooler -WhatIf
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
    $common = @{ Operation = 'Services.Stop'; Target = $Name; ComputerName = $computerName }

    $plan = Get-MwpServiceStopPlan -Context $Context -Operation $common.Operation -Name $Name -Verb 'zatrzymać'
    if (-not $plan.Success) {
        return $plan.Result
    }
    $service = $plan.Service
    $common.Target = $service.Name
    if ($service.Status -eq 'Stopped') {
        return New-MwpResult @common -Success $true -Before $service.StatusText -After $service.StatusText -Message ("Usługa '{0}' jest już zatrzymana." -f $service.DisplayName)
    }
    $dependents = @($plan.Dependents)
    $startOrder = @(for ($index = $dependents.Count - 1; $index -ge 0; $index--) { $dependents[$index] })
    $dependentText = if ($dependents.Count -gt 0) { ' Zostaną też zatrzymane usługi zależne: {0}.' -f ($dependents -join ', ') } else { '' }

    $target = Format-MwpOperationTarget -Target ("usługa '{0}' ({1})" -f $service.DisplayName, $service.Name) -ComputerName $computerName
    if (-not $PSCmdlet.ShouldProcess($target, ('Zatrzymanie{0}' -f $dependentText))) {
        return New-MwpResult @common -Success $true -IsPreview -Before $service.StatusText -After 'Zatrzymana' `
            -Message ("Podgląd: zatrzymanie usługi '{0}'.{1}" -f $service.DisplayName, $dependentText) -Data ([ordered]@{ Dependents = $dependents })
    }

    $steps = @(foreach ($item in @($dependents + $service.Name)) { @{ Name = $item; Action = 'Stop' } })
    $change = Invoke-MwpServiceControl -Context $Context -Operation $common.Operation -Step $steps -Recover $startOrder
    if (-not $change.Success) {
        $message = "Nie udało się zatrzymać usługi '{0}' na komputerze '{1}': {2}" -f $service.DisplayName, $computerName, $change.Message
        Write-MwpLog -Level Error -Source 'MWP.Services' -Operation $common.Operation -ComputerName $computerName -Message $message -Data @{ Dependents = $dependents }
        return New-MwpResult @common -Success $false -Before $service.StatusText -Message $message -ErrorMessage $change.ErrorMessage
    }
    $undoParameters = @{ Name = $service.Name }
    if ($startOrder.Count -gt 0) {
        $undoParameters['DependentService'] = $startOrder
    }
    $undo = Save-MwpUndoEntry -Module 'MWP.Services' -Operation $common.Operation -Target $service.Name -ComputerName $computerName `
        -Description ("Zatrzymanie usługi '{0}'{1}" -f $service.DisplayName, $(if ($dependents.Count -gt 0) { ' (i zależnych: {0})' -f ($dependents -join ', ') } else { '' })) `
        -Before $service.StatusText -After 'Zatrzymana' -UndoCommand 'Start-MwpService' -UndoParameters $undoParameters
    $message = "Zatrzymano usługę '{0}' na komputerze '{1}'.{2}" -f $service.DisplayName, $computerName, $(if ($dependents.Count -gt 0) { ' Zatrzymano też: {0}.' -f ($dependents -join ', ') } else { '' })
    Write-MwpLog -Level Info -Source 'MWP.Services' -Operation $common.Operation -ComputerName $computerName -Message $message -Data @{ Dependents = $dependents }
    New-MwpResult @common -Success $true -Changed $true -Before $service.StatusText -After 'Zatrzymana' -UndoId $undo.Id -Message $message -Data ([ordered]@{ Dependents = $dependents })
}
