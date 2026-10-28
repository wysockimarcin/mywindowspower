function Restore-MwpUpdatePause {
    <#
    .SYNOPSIS
        Przywraca zapisane wartości pauzy Windows Update na komputerze docelowym (polecenie cofające Suspend-MwpUpdate i Resume-MwpUpdate).

    .DESCRIPTION
        Operacja klasy Zmiana: zapisuje wartości z -StateJson (nazwy z listy wartości pauzy, wartość =
        data ISO 8601 albo null — null usuwa wartość). Wpisy rejestru cofnięć wywołują ją przez
        Invoke-MwpUndo -Context. Inne nazwy i wartości, które nie są datą, są odrzucane przed zmianą
        (D-015). Wymaga administratora na komputerze docelowym; podgląd (-WhatIf) i potwierdzenie
        z nazwą komputera. Nie tworzy nowego wpisu cofnięcia.

    .PARAMETER StateJson
        Obiekt JSON: nazwa wartości → data albo null.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $StateJson,

        [PSTypeName('MWP.ExecutionContext')]
        [object] $Context = (New-MwpExecutionContext)
    )

    $operation = 'Update.RestorePause'
    $common = @{ Operation = $operation; Target = 'Windows Update'; ComputerName = $Context.ComputerName }
    try {
        $state = ConvertFrom-Json -InputObject $StateJson -ErrorAction Stop
    }
    catch {
        return New-MwpResult @common -Success $false -Message ('Niepoprawny zapis stanu pauzy: {0}' -f $_.Exception.Message)
    }
    $names = @((Get-MwpUpdateTargetConfig).PauseValues)
    $values = @{}
    foreach ($property in @($state.PSObject.Properties)) {
        if ($names -notcontains $property.Name) {
            return New-MwpResult @common -Success $false -Message ("Nieznana wartość pauzy '{0}' — przywrócenie odrzucone." -f $property.Name)
        }
        $text = ConvertTo-MwpUpdatePauseText -Value $property.Value
        if ($null -ne $text -and $null -eq (ConvertFrom-MwpUpdateDate -Value $text)) {
            return New-MwpResult @common -Success $false -Message ("Wartość pauzy '{0}' nie jest datą ('{1}') — przywrócenie odrzucone." -f $property.Name, $text)
        }
        $values[$property.Name] = $text
    }
    if ($values.Count -eq 0) {
        return New-MwpResult @common -Success $false -Message 'Zapis stanu pauzy jest pusty.'
    }
    $status = Get-MwpUpdateStatus -Context $Context
    if (-not $status.Success) {
        return New-MwpResult @common -Success $false -Message $status.Message -ErrorMessage $status.ErrorMessage
    }
    $pause = $status.Data.Pause
    $preview = Resolve-MwpUpdatePause -Values $values
    $denied = Test-MwpUpdatePauseAccess -Context $Context -Operation $operation -BeforeText $pause.Text
    if ($null -ne $denied) {
        return $denied
    }
    $action = 'Przywrócenie pauzy: {0}' -f $preview.Text
    $target = Format-MwpOperationTarget -Target 'pauza Windows Update' -ComputerName $Context.ComputerName
    if (-not $PSCmdlet.ShouldProcess($target, $action)) {
        return New-MwpResult @common -Success $true -IsPreview -Before $pause.Text -After $preview.Text -Message ('Podgląd: {0}.' -f $action)
    }
    Invoke-MwpUpdatePauseChange -Context $Context -Operation $operation -Before $pause.Values -Values $values -BeforeText $pause.Text -AfterText $preview.Text
}
