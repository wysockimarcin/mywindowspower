function Start-MwpUiComponentStoreAnalysis {
    <#
    .SYNOPSIS
        Uruchamia w tle analizę magazynu składników (DISM, tylko odczyt) na komputerze instancji i pokazuje wynik w widoku.

    .DESCRIPTION
        Operacja w puli MWP.Remote (Get-MwpComponentStoreAnalysis -AsOperation; limit czasu 1 h,
        anulowanie z paska stanu, zamknięcie instancji ją anuluje). Brak administratora i błędy DISM
        są pokazywane w widoku tej instancji (Resolve-MwpComponentStoreAnalysis).
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Uruchamia odczyt (analiza DISM bez zmian systemu).')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable] $Entry
    )

    $context = $Entry.Instance.Context
    $view = $Entry.Cleanup
    if ($view.StoreLoading) {
        return
    }
    if ((Get-MwpConnectionStateInfo -Context $context).NeedsCredential) {
        $view.StoreError = 'Połącz instancję z komputerem {0} (przycisk „Połącz”), żeby wykonać analizę.' -f (Format-MwpTargetLabel -Context $context)
        Update-MwpCleanupView -Entry $Entry
        return
    }
    $view.StoreLoading = $true
    $view.StoreError = $null
    $null = Register-MwpUiOperation -Registry $script:MwpUi.Tasks -Operation (Get-MwpComponentStoreAnalysis -Context $context -AsOperation) `
        -Name ('DISM: analiza magazynu składników ({0})' -f (Format-MwpTargetLabel -Context $context)) -State @{ InstanceId = $Entry.Id } -OnCompleted {
        param($Task)
        $entry = $script:MwpUi.Instances[[string]$Task.State.InstanceId]
        if ($null -eq $entry) {
            return
        }
        $entry.Cleanup.StoreLoading = $false
        $result = @($Task.Output) | Select-Object -Last 1
        $analysis = if ($null -ne $result -and $result.Success) { Resolve-MwpComponentStoreAnalysis -Data $result -ComputerName $entry.Instance.Context.ComputerName } else { $null }
        if ($null -ne $analysis) {
            $entry.Cleanup.Store = $analysis
            $entry.Cleanup.StoreError = $null
        }
        elseif ($Task.Status -eq 'Cancelled') {
            $entry.Cleanup.StoreError = 'Analiza anulowana (uruchomiony już DISM kończy analizę w tle; niczego nie zmienia).'
        }
        else {
            $entry.Cleanup.StoreError = 'Analiza nie powiodła się ({0}): {1}' -f $Task.Status, $(if ($null -ne $result) { $result.Message } else { $Task.Error })
        }
        Update-MwpInstanceView -Entry $entry
    }
    Update-MwpCleanupView -Entry $Entry
}
