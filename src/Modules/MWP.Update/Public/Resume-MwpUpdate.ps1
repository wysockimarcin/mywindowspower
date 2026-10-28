function Resume-MwpUpdate {
    <#
    .SYNOPSIS
        Wznawia aktualizacje Windows na komputerze docelowym — usuwa wartości pauzy (jak „Wznów aktualizacje” w Ustawieniach).

    .DESCRIPTION
        Operacja klasy Zmiana (D-027, D-048): usuwa z HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings
        wartości Pause*StartTime/EndTime i PauseUpdatesExpiryTime. Bez wartości pauzy — wynik bez
        zmian. Wymaga administratora na komputerze docelowym; podgląd (-WhatIf) i potwierdzenie
        z nazwą komputera. Wpis cofnięcia przywraca wartości sprzed zmiany (Restore-MwpUpdatePause).

    .EXAMPLE
        Resume-MwpUpdate -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Position = 0)]
        [PSTypeName('MWP.ExecutionContext')]
        [object] $Context = (New-MwpExecutionContext)
    )

    $operation = 'Update.Resume'
    $common = @{ Operation = $operation; Target = 'Windows Update'; ComputerName = $Context.ComputerName }
    $status = Get-MwpUpdateStatus -Context $Context
    if (-not $status.Success) {
        return New-MwpResult @common -Success $false -Message $status.Message -ErrorMessage $status.ErrorMessage
    }
    $pause = $status.Data.Pause
    if (-not $pause.HasValues) {
        return New-MwpResult @common -Success $true -Before $pause.Text -After $pause.Text -Message ("Aktualizacje na komputerze '{0}' nie są wstrzymane." -f $Context.ComputerName)
    }
    $values = @{}
    foreach ($name in (Get-MwpUpdateTargetConfig).PauseValues) {
        $values[$name] = $null
    }
    $denied = Test-MwpUpdatePauseAccess -Context $Context -Operation $operation -BeforeText $pause.Text
    if ($null -ne $denied) {
        return $denied
    }
    $action = 'Wznowienie aktualizacji (usunięcie wartości pauzy)'
    $target = Format-MwpOperationTarget -Target 'pauza Windows Update' -ComputerName $Context.ComputerName
    if (-not $PSCmdlet.ShouldProcess($target, $action)) {
        return New-MwpResult @common -Success $true -IsPreview -Before $pause.Text -After 'Aktualizacje wznowione.' -Message ('Podgląd: {0}.' -f $action)
    }
    Invoke-MwpUpdatePauseChange -Context $Context -Operation $operation -Before $pause.Values -Values $values -SaveUndo -BeforeText $pause.Text -AfterText 'Aktualizacje wznowione.'
}
