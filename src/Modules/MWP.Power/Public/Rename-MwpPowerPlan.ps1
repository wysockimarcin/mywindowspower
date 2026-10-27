function Rename-MwpPowerPlan {
    <#
    .SYNOPSIS
        Zmienia nazwę planu zasilania na komputerze docelowym (powercfg /changename).

    .DESCRIPTION
        Operacja klasy Zmiana (D-027): odczyt planów, podgląd (-WhatIf) z nazwą komputera, zmiana,
        wpis cofnięcia (poprzednia nazwa) i log. Uwaga: plan wbudowany po zmianie nazwy przestaje
        pokazywać nazwę tłumaczoną przez Windows; cofnięcie przywraca ją jako zwykły tekst.

    .PARAMETER Guid
        GUID planu.

    .PARAMETER Name
        Nowa nazwa (bez cudzysłowów i znaków sterujących, do 128 znaków).

    .EXAMPLE
        Rename-MwpPowerPlan -Guid $guid -Name 'Praca na baterii'
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidatePattern('^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$')]
        [string] $Guid,

        [Parameter(Mandatory, Position = 1)]
        [ValidatePattern('^[^"\p{Cc}]{1,128}$')]
        [string] $Name,

        [PSTypeName('MWP.ExecutionContext')]
        [object] $Context = (New-MwpExecutionContext)
    )

    $Guid = $Guid.ToLowerInvariant()
    $Name = $Name.Trim()
    $computerName = $Context.ComputerName
    $common = @{ Operation = 'Power.RenamePlan'; Target = $Guid; ComputerName = $computerName }

    $state = Read-MwpPowerState -Context $Context -Operation $common.Operation
    if (-not $state.Success) {
        return New-MwpResult @common -Success $false -Message $state.Result.Message -ErrorMessage $state.Result.ErrorMessage
    }
    $plan = @($state.Status.Plans | Where-Object { $_.Guid -eq $Guid }) | Select-Object -First 1
    if ($null -eq $plan) {
        return New-MwpResult @common -Success $false -Message ("Na komputerze '{0}' nie ma planu zasilania {1}." -f $computerName, $Guid)
    }
    if ($Name -eq '') {
        return New-MwpResult @common -Success $false -Message 'Nazwa planu nie może być pusta.'
    }
    $before = $plan.Name
    if ($before -ceq $Name) {
        return New-MwpResult @common -Success $true -Before $before -After $Name -Message ("Plan {0} ma już tę nazwę." -f $Guid)
    }

    $target = Format-MwpOperationTarget -Target ('plan zasilania {0}' -f (Format-MwpPowerPlanName -Plan $plan)) -ComputerName $computerName
    if (-not $PSCmdlet.ShouldProcess($target, ("Zmiana nazwy na '{0}'" -f $Name))) {
        return New-MwpResult @common -Success $true -IsPreview -Before $before -After $Name -Message ("Podgląd: nazwa planu {0}: '{1}' → '{2}'." -f $Guid, $before, $Name)
    }

    $change = Invoke-MwpPowerChange -Context $Context -Operation $common.Operation -Command @(@{ Id = 'rename'; Arguments = @('/changename', $Guid, $Name) })
    if (-not $change.Success) {
        $message = "Nie udało się zmienić nazwy planu {0} na komputerze '{1}': {2}" -f $Guid, $computerName, $change.Message
        Write-MwpLog -Level Error -Source 'MWP.Power' -Operation $common.Operation -ComputerName $computerName -Message $message
        return New-MwpResult @common -Success $false -Before $before -Message $message -ErrorMessage $change.ErrorMessage
    }
    $undo = Save-MwpUndoEntry -Module 'MWP.Power' -Operation $common.Operation -Target $Guid -ComputerName $computerName `
        -Description ("Nazwa planu {0}: '{1}' → '{2}'" -f $Guid, $before, $Name) -Before $before -After $Name `
        -UndoCommand 'Rename-MwpPowerPlan' -UndoParameters @{ Guid = $Guid; Name = $before }
    $message = "Zmieniono nazwę planu {0}: '{1}' → '{2}'." -f $Guid, $before, $Name
    Write-MwpLog -Level Info -Source 'MWP.Power' -Operation $common.Operation -ComputerName $computerName -Message $message
    New-MwpResult @common -Success $true -Changed $true -Before $before -After $Name -UndoId $undo.Id -Message $message
}
