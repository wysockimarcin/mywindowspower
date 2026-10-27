function Set-MwpHibernation {
    <#
    .SYNOPSIS
        Włącza albo wyłącza hibernację na komputerze docelowym (powercfg /hibernate on|off).

    .DESCRIPTION
        Operacja klasy Zmiana (D-027). Wymaga uprawnień administratora na komputerze docelowym
        (sprawdzane przed zmianą, uprawnienia nie są podnoszone). Stan przed zmianą z rejestru
        (HibernateEnabled, a gdy go brak — HibernateEnabledDefault). Podgląd (-WhatIf) z nazwą
        komputera, wpis cofnięcia (stan przeciwny) i log. Wyłączenie hibernacji usuwa plik
        hiberfil.sys i wyłącza też działanie szybkiego uruchamiania oraz „Hibernuj po”.

    .PARAMETER Enabled
        $true — włącz, $false — wyłącz.

    .EXAMPLE
        Set-MwpHibernation -Enabled $false -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [bool] $Enabled,

        [PSTypeName('MWP.ExecutionContext')]
        [object] $Context = (New-MwpExecutionContext)
    )

    $computerName = $Context.ComputerName
    $common = @{ Operation = 'Power.SetHibernation'; Target = 'Hibernacja'; ComputerName = $computerName }
    $text = { param($State) if ($null -eq $State) { 'nieznany' } elseif ($State) { 'włączona' } else { 'wyłączona' } }

    $admin = Test-MwpPowerAdmin -Context $Context
    if (-not $admin.Success) {
        return New-MwpResult @common -Success $false -Message $admin.Result.Message -ErrorMessage $admin.Result.ErrorMessage
    }
    if (-not $admin.IsAdministrator) {
        return New-MwpResult @common -Success $false -Message ("Zmiana hibernacji wymaga uprawnień administratora na komputerze '{0}'." -f $computerName)
    }
    $read = Invoke-MwpPowercfg -Context $Context -Operation $common.Operation -IncludeSystem
    if (-not $read.Success) {
        return New-MwpResult @common -Success $false -Message $read.Result.Message -ErrorMessage $read.Result.ErrorMessage
    }
    $before = $read.Raw.System.Hibernate
    $beforeText = & $text $before
    $afterText = & $text $Enabled
    if ($null -ne $before -and [bool]$before -eq $Enabled) {
        return New-MwpResult @common -Success $true -Before $beforeText -After $afterText -Message ("Hibernacja jest już {0}." -f $afterText)
    }

    $target = Format-MwpOperationTarget -Target 'hibernacja' -ComputerName $computerName
    if (-not $PSCmdlet.ShouldProcess($target, ("Zmiana z '{0}' na '{1}'" -f $beforeText, $afterText))) {
        $note = if ($Enabled) { '' } else { ' Szybkie uruchamianie i „Hibernuj po” przestaną działać.' }
        return New-MwpResult @common -Success $true -IsPreview -Before $beforeText -After $afterText -Message ("Podgląd: hibernacja {0} → {1}.{2}" -f $beforeText, $afterText, $note)
    }

    $change = Invoke-MwpPowerChange -Context $Context -Operation $common.Operation -Command @(@{ Id = 'hibernate'; Arguments = @('/hibernate', $(if ($Enabled) { 'on' } else { 'off' })) })
    if (-not $change.Success) {
        $message = "Nie udało się zmienić hibernacji na komputerze '{0}': {1}" -f $computerName, $change.Message
        Write-MwpLog -Level Error -Source 'MWP.Power' -Operation $common.Operation -ComputerName $computerName -Message $message
        return New-MwpResult @common -Success $false -Before $beforeText -Message $message -ErrorMessage $change.ErrorMessage
    }
    $undo = Save-MwpUndoEntry -Module 'MWP.Power' -Operation $common.Operation -Target $common.Target -ComputerName $computerName `
        -Description ('Hibernacja: {0} → {1}' -f $beforeText, $afterText) -Before $beforeText -After $afterText `
        -UndoCommand 'Set-MwpHibernation' -UndoParameters @{ Enabled = (-not $Enabled) }
    $message = "Hibernacja na komputerze '{0}': {1} → {2}." -f $computerName, $beforeText, $afterText
    Write-MwpLog -Level Info -Source 'MWP.Power' -Operation $common.Operation -ComputerName $computerName -Message $message
    New-MwpResult @common -Success $true -Changed $true -Before $beforeText -After $afterText -UndoId $undo.Id -Message $message
}
