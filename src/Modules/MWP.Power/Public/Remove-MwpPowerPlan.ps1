function Remove-MwpPowerPlan {
    <#
    .SYNOPSIS
        Usuwa plan zasilania z komputera docelowego (powercfg /delete), z ochroną planu aktywnego i planów wbudowanych.

    .DESCRIPTION
        Operacja klasy Destrukcyjna (D-027, ConfirmImpact High — potwierdzenie z nazwą planu
        i komputera). Odmawia usunięcia planu aktywnego (najpierw trzeba aktywować inny) i planów
        z listy ochronnej (kategoria PowerPlan: Zrównoważony, Wysoka wydajność, Oszczędzanie energii,
        D-029). Przed usunięciem eksportuje plan (powercfg /export na komputerze docelowym, treść
        w Base64) — eksport jest warunkiem usunięcia, bo z niego cofnięcie (Import-MwpPowerPlan)
        odtwarza plan z tym samym GUID-em i ustawieniami.

    .PARAMETER Guid
        GUID planu do usunięcia.

    .EXAMPLE
        Remove-MwpPowerPlan -Guid $guid -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
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
    $common = @{ Operation = 'Power.RemovePlan'; Target = $Guid; ComputerName = $computerName }

    if (Test-MwpProtectedItem -Category 'PowerPlan' -Name $Guid) {
        $reason = (Get-MwpProtectedItem -Category 'PowerPlan' -Name $Guid).Reason
        return New-MwpResult @common -Success $false -Message ("Plan {0} jest na liście ochronnej: {1}" -f $Guid, $reason)
    }
    $state = Read-MwpPowerState -Context $Context -Operation $common.Operation
    if (-not $state.Success) {
        return New-MwpResult @common -Success $false -Message $state.Result.Message -ErrorMessage $state.Result.ErrorMessage
    }
    $plan = @($state.Status.Plans | Where-Object { $_.Guid -eq $Guid }) | Select-Object -First 1
    if ($null -eq $plan) {
        return New-MwpResult @common -Success $false -Message ("Na komputerze '{0}' nie ma planu zasilania {1}." -f $computerName, $Guid)
    }
    $name = Format-MwpPowerPlanName -Plan $plan
    if ($plan.IsActive) {
        return New-MwpResult @common -Success $false -Before $name -Message ("Plan {0} jest aktywny na komputerze '{1}'; najpierw aktywuj inny plan." -f $name, $computerName)
    }

    $target = Format-MwpOperationTarget -Target ('plan zasilania {0}' -f $name) -ComputerName $computerName
    if (-not $PSCmdlet.ShouldProcess($target, 'Usunięcie planu (z kopią do cofnięcia)')) {
        return New-MwpResult @common -Success $true -IsPreview -Before $name -After '(usunięty)' -Message ("Podgląd: usunięcie planu zasilania {0}." -f $name)
    }

    $export = Invoke-MwpOnTarget -Context $Context -Operation 'Power.ExportPlan' -ScriptBlock (Get-MwpPowerScript -Name ExportPlan) -ArgumentList @($Guid)
    $file = if ($export.Success) { ConvertFrom-MwpPowerJson -Data $export -Kind 'MWP.PowerFile' }
    if ($null -eq $file -or [int]$file.ExitCode -ne 0 -or [string]::IsNullOrEmpty([string]$file.Content)) {
        $reason = if (-not $export.Success) { $export.Message } elseif ($null -eq $file) { 'brak wyniku eksportu.' } else { 'powercfg /export zakończył się kodem {0}: {1}' -f $file.ExitCode, (@($file.Output) -join ' ') }
        $message = "Nie usunięto planu {0}: nie udało się zapisać kopii do cofnięcia ({1})" -f $name, $reason
        Write-MwpLog -Level Error -Source 'MWP.Power' -Operation $common.Operation -ComputerName $computerName -Message $message
        return New-MwpResult @common -Success $false -Before $name -Message $message -ErrorMessage $export.ErrorMessage
    }

    $change = Invoke-MwpPowerChange -Context $Context -Operation $common.Operation -Command @(@{ Id = 'delete'; Arguments = @('/delete', $Guid) })
    if (-not $change.Success) {
        $message = "Nie udało się usunąć planu {0} na komputerze '{1}': {2}" -f $name, $computerName, $change.Message
        Write-MwpLog -Level Error -Source 'MWP.Power' -Operation $common.Operation -ComputerName $computerName -Message $message
        return New-MwpResult @common -Success $false -Before $name -Message $message -ErrorMessage $change.ErrorMessage
    }
    $undo = Save-MwpUndoEntry -Module 'MWP.Power' -Operation $common.Operation -Target $Guid -ComputerName $computerName `
        -Description ('Usunięty plan {0}' -f $name) -Before $name -After '(usunięty)' `
        -UndoCommand 'Import-MwpPowerPlan' -UndoParameters @{ Guid = $Guid; Content = [string]$file.Content }
    $message = "Usunięto plan zasilania {0} z komputera '{1}' (kopia w rejestrze cofnięć)." -f $name, $computerName
    Write-MwpLog -Level Info -Source 'MWP.Power' -Operation $common.Operation -ComputerName $computerName -Message $message
    New-MwpResult @common -Success $true -Changed $true -Before $name -After '(usunięty)' -UndoId $undo.Id -Message $message
}
