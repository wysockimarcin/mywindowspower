function Set-MwpFastStartup {
    <#
    .SYNOPSIS
        Włącza albo wyłącza szybkie uruchamianie (HiberbootEnabled) na komputerze docelowym.

    .DESCRIPTION
        Operacja klasy Zmiana (D-027). Wymaga uprawnień administratora na komputerze docelowym
        (zapis w HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power, wartość DWORD
        HiberbootEnabled). Podgląd (-WhatIf) z nazwą komputera, wpis cofnięcia (stan poprzedni) i log.
        Gdy wartości nie było, Windows traktuje szybkie uruchamianie jako włączone — cofnięcie
        przywraca wtedy wartość 1. Szybkie uruchamianie działa tylko przy włączonej hibernacji
        (komunikat ostrzega, gdy jest wyłączona). Zmiana działa od następnego zamknięcia systemu.

    .PARAMETER Enabled
        $true — włącz, $false — wyłącz.

    .EXAMPLE
        Set-MwpFastStartup -Enabled $false -WhatIf
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
    $common = @{ Operation = 'Power.SetFastStartup'; Target = 'HiberbootEnabled'; ComputerName = $computerName }
    $text = { param($State) if ($null -eq $State) { 'brak wartości (domyślnie włączone)' } elseif ($State) { 'włączone' } else { 'wyłączone' } }

    $admin = Test-MwpPowerAdmin -Context $Context
    if (-not $admin.Success) {
        return New-MwpResult @common -Success $false -Message $admin.Result.Message -ErrorMessage $admin.Result.ErrorMessage
    }
    if (-not $admin.IsAdministrator) {
        return New-MwpResult @common -Success $false -Message ("Zmiana szybkiego uruchamiania wymaga uprawnień administratora na komputerze '{0}'." -f $computerName)
    }
    $read = Invoke-MwpPowercfg -Context $Context -Operation $common.Operation -IncludeSystem
    if (-not $read.Success) {
        return New-MwpResult @common -Success $false -Message $read.Result.Message -ErrorMessage $read.Result.ErrorMessage
    }
    $before = $read.Raw.System.FastStartup
    $hibernate = $read.Raw.System.Hibernate
    $beforeText = & $text $before
    $afterText = & $text $Enabled
    $note = if ($Enabled -and $false -eq $hibernate) { ' Uwaga: hibernacja jest wyłączona, więc szybkie uruchamianie nie zadziała, dopóki jej nie włączysz.' } else { '' }
    if ($null -ne $before -and [bool]$before -eq $Enabled) {
        return New-MwpResult @common -Success $true -Before $beforeText -After $afterText -Message ("Szybkie uruchamianie jest już {0}.{1}" -f $afterText, $note)
    }

    $target = Format-MwpOperationTarget -Target 'szybkie uruchamianie (HiberbootEnabled)' -ComputerName $computerName
    if (-not $PSCmdlet.ShouldProcess($target, ("Zmiana z '{0}' na '{1}'" -f $beforeText, $afterText))) {
        return New-MwpResult @common -Success $true -IsPreview -Before $beforeText -After $afterText -Message ("Podgląd: szybkie uruchamianie {0} → {1}.{2}" -f $beforeText, $afterText, $note)
    }

    $change = Invoke-MwpOnTarget -Context $Context -Operation $common.Operation -ScriptBlock (Get-MwpPowerScript -Name FastStartup) -ArgumentList @([int]$Enabled)
    $confirmed = if ($change.Success) { ConvertFrom-MwpPowerJson -Data $change -Kind 'MWP.PowerChange' }
    if ($null -eq $confirmed) {
        $message = "Nie udało się zmienić szybkiego uruchamiania na komputerze '{0}': {1}" -f $computerName, $(if ($change.Success) { 'brak potwierdzenia zapisu.' } else { $change.Message })
        Write-MwpLog -Level Error -Source 'MWP.Power' -Operation $common.Operation -ComputerName $computerName -Message $message
        return New-MwpResult @common -Success $false -Before $beforeText -Message $message -ErrorMessage $change.ErrorMessage
    }
    $restore = if ($null -eq $before) { $true } else { [bool]$before }
    $undo = Save-MwpUndoEntry -Module 'MWP.Power' -Operation $common.Operation -Target $common.Target -ComputerName $computerName `
        -Description ('Szybkie uruchamianie: {0} → {1}' -f $beforeText, $afterText) -Before $beforeText -After $afterText `
        -UndoCommand 'Set-MwpFastStartup' -UndoParameters @{ Enabled = $restore }
    $message = "Szybkie uruchamianie na komputerze '{0}': {1} → {2} (działa od następnego zamknięcia systemu).{3}" -f $computerName, $beforeText, $afterText, $note
    Write-MwpLog -Level Info -Source 'MWP.Power' -Operation $common.Operation -ComputerName $computerName -Message $message
    New-MwpResult @common -Success $true -Changed $true -Before $beforeText -After $afterText -UndoId $undo.Id -Message $message
}
