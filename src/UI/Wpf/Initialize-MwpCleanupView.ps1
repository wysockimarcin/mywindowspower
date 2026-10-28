function Initialize-MwpCleanupView {
    <#
    .SYNOPSIS
        Podpina widok Czyszczenie dysku (Views\Cleanup.xaml) w instancji modułu Cleanup i uruchamia pierwszy skan w tle.

    .DESCRIPTION
        Stan widoku jest w wpisie instancji ($Entry.Cleanup), więc dwie instancje (np. localhost
        i komputer zdalny) mają niezależne widoki, zadania i raporty. Przyciski mają w Tag identyfikator
        instancji, a jedna obsługa (Invoke-MwpCleanupViewAction) rozpoznaje akcję po nazwie kontrolki.
        Widok nie wywołuje poleceń systemowych — tylko funkcje MWP.Cleanup i MWP.Core (D-015, D-044, D-047).
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '',
        Justification = 'Parametry obsługi zdarzeń WPF są używane w zagnieżdżonych blokach (Invoke-MwpUiSafe -Action), czego reguła nie widzi.')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable] $Entry
    )

    $p = $Entry.ModuleView.Controls
    $Entry.Cleanup = @{
        Scan         = $null
        ScanError    = $null
        CategoryById = @{}
        Task         = $null
        TaskKind     = $null
        Report       = $null
        Store        = $null
        StoreError   = $null
        StoreLoading = $false
    }
    $handler = {
        param($control)
        Invoke-MwpUiSafe -Name ('UI.Cleanup.' + $control.Name) -Action {
            $entry = $script:MwpUi.Instances[[string]$control.Tag]
            if ($null -ne $entry) {
                Invoke-MwpCleanupViewAction -Entry $entry -Action $control.Name -Owner (Get-MwpOwnerWindow -Element $control)
            }
        }
    }
    foreach ($name in 'CleanupScanButton', 'CleanupSelectAllButton', 'CleanupRunButton', 'CleanupCancelButton', 'ComponentStoreButton', 'CleanupProfilesCheck') {
        $p[$name].Tag = $Entry.Id
        $p[$name].Add_Click($handler)
    }
    $p['CleanupGrid'].Tag = $Entry.Id
    $p['CleanupGrid'].Add_SelectionChanged({
            param($control)
            Invoke-MwpUiSafe -Name 'UI.Cleanup.Selection' -Action {
                $entry = $script:MwpUi.Instances[[string]$control.Tag]
                if ($null -ne $entry) {
                    Update-MwpCleanupView -Entry $entry -Selection
                }
            }
        })
    Start-MwpUiCleanupScan -Entry $Entry
}
