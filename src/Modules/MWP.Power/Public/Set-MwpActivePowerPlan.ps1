function Set-MwpActivePowerPlan {
    <#
    .SYNOPSIS
        Ustawia aktywny plan zasilania na komputerze docelowym (powercfg /setactive).

    .DESCRIPTION
        Operacja klasy Zmiana (D-027): odczyt planów, podgląd (-WhatIf) i potwierdzenie z nazwą
        komputera, zmiana, wpis cofnięcia (poprzedni plan aktywny) i log. Plan wskazuje się GUID-em
        (niezależnie od języka systemu). Nie wymaga uprawnień administratora.

    .PARAMETER Guid
        GUID planu do aktywowania.

    .EXAMPLE
        Set-MwpActivePowerPlan -Guid 381b4222-f694-41f0-9685-ff5bb260df2e -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidatePattern('^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$')]
        [string] $Guid,

        [PSTypeName('MWP.ExecutionContext')]
        [object] $Context = (New-MwpExecutionContext)
    )

    $Guid = $Guid.ToLowerInvariant()
    $computerName = $Context.ComputerName
    $common = @{ Operation = 'Power.SetActivePlan'; Target = $Guid; ComputerName = $computerName }

    $state = Read-MwpPowerState -Context $Context -Operation $common.Operation
    if (-not $state.Success) {
        return New-MwpResult @common -Success $false -Message $state.Result.Message -ErrorMessage $state.Result.ErrorMessage
    }
    $plan = @($state.Status.Plans | Where-Object { $_.Guid -eq $Guid }) | Select-Object -First 1
    if ($null -eq $plan) {
        return New-MwpResult @common -Success $false -Message ("Na komputerze '{0}' nie ma planu zasilania {1}." -f $computerName, $Guid)
    }
    $active = $state.Status.ActivePlan
    $before = Format-MwpPowerPlanName -Plan $active
    $after = Format-MwpPowerPlanName -Plan $plan
    if ($null -ne $active -and $active.Guid -eq $Guid) {
        return New-MwpResult @common -Success $true -Before $after -After $after -Message ("Plan {0} jest już aktywny." -f $after)
    }

    $target = Format-MwpOperationTarget -Target ('plan zasilania {0}' -f $after) -ComputerName $computerName
    if (-not $PSCmdlet.ShouldProcess($target, ('Aktywacja planu (teraz: {0})' -f $before))) {
        return New-MwpResult @common -Success $true -IsPreview -Before $before -After $after -Message ("Podgląd: aktywny plan zasilania {0} → {1}." -f $before, $after)
    }

    $change = Invoke-MwpPowerChange -Context $Context -Operation $common.Operation -Command @(@{ Id = 'setactive'; Arguments = @('/setactive', $Guid) })
    if (-not $change.Success) {
        $message = "Nie udało się aktywować planu {0} na komputerze '{1}': {2}" -f $after, $computerName, $change.Message
        Write-MwpLog -Level Error -Source 'MWP.Power' -Operation $common.Operation -ComputerName $computerName -Message $message
        return New-MwpResult @common -Success $false -Before $before -Message $message -ErrorMessage $change.ErrorMessage
    }
    $undoId = $null
    if ($null -ne $active) {
        $undo = Save-MwpUndoEntry -Module 'MWP.Power' -Operation $common.Operation -Target $Guid -ComputerName $computerName `
            -Description ('Aktywny plan: {0} → {1}' -f $before, $after) -Before $before -After $after `
            -UndoCommand 'Set-MwpActivePowerPlan' -UndoParameters @{ Guid = $active.Guid }
        $undoId = $undo.Id
    }
    $message = "Aktywowano plan zasilania {0} (poprzednio {1})." -f $after, $before
    Write-MwpLog -Level Info -Source 'MWP.Power' -Operation $common.Operation -ComputerName $computerName -Message $message -Data @{ Before = $before; After = $after }
    New-MwpResult @common -Success $true -Changed $true -Before $before -After $after -UndoId $undoId -Message $message
}
