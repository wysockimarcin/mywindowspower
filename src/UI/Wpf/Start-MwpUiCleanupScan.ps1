function Start-MwpUiCleanupScan {
    <#
    .SYNOPSIS
        Skanuje w tle kategorie czyszczenia komputera instancji (tylko odczyt) i odświeża widok po zakończeniu.

    .DESCRIPTION
        Zadanie GUI (Start-MwpUiTask, pula okna) wywołuje Measure-MwpCleanupCategory z kontekstem
        instancji i tabelą postępu (procent i nazwa kategorii w widoku i na pasku stanu; anulowanie
        z widoku albo paska stanu). Profile użytkowników — według pola „Uwzględnij profile wszystkich
        użytkowników” (komputer zdalny: bez zaznaczenia tylko lokalizacje systemowe, D-019, D-047).
        Błąd lub utrata połączenia zmienia tylko ten widok. Gdy trwa inne zadanie widoku — nic nie robi.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Uruchamia odczyt (bez zmian systemu).')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable] $Entry
    )

    $ui = $script:MwpUi
    $context = $Entry.Instance.Context
    $view = $Entry.Cleanup
    if ($null -ne $view.Task) {
        return
    }
    if ((Get-MwpConnectionStateInfo -Context $context).NeedsCredential) {
        $view.ScanError = 'Połącz instancję z komputerem {0} (przycisk „Połącz”), żeby przeskanować kategorie czyszczenia.' -f $context.ComputerName
        Update-MwpCleanupView -Entry $Entry
        return
    }
    $module = @(Get-Module -Name $Entry.Instance.ModuleName) | Select-Object -First 1
    $includeProfiles = [bool]$Entry.ModuleView.Controls['CleanupProfilesCheck'].IsChecked
    $view.TaskKind = 'Scan'
    $view.Task = Start-MwpUiTask -Registry $ui.Tasks -Pool $ui.Pool -Name ('Czyszczenie: skan ({0})' -f $context.ComputerName) -State @{ InstanceId = $Entry.Id } -Cancellable `
        -ArgumentList $(if ($null -ne $module) { $module.Path } else { '' }), $context, $includeProfiles -ScriptBlock (Get-MwpUiCleanupScript -Name Scan) -OnCompleted {
        param($Task)
        $entry = $script:MwpUi.Instances[[string]$Task.State.InstanceId]
        if ($null -eq $entry) {
            return
        }
        $entry.Cleanup.Task = $null
        $entry.Cleanup.TaskKind = $null
        $result = @($Task.Output | Where-Object { $null -ne $_ -and $_.PSObject.TypeNames -contains 'MWP.Result' }) | Select-Object -Last 1
        if ($Task.Status -eq 'Completed' -and $null -ne $result -and $result.Success) {
            $entry.Cleanup.Scan = $result.Data
            $byId = @{}
            foreach ($category in @($result.Data.Categories)) {
                $byId[$category.Id] = $category
            }
            $entry.Cleanup.CategoryById = $byId
            $entry.Cleanup.ScanError = $null
        }
        elseif ($Task.Status -eq 'Cancelled') {
            $entry.Cleanup.ScanError = 'Skan anulowany — tabela pokazuje wynik poprzedniego skanu (jeśli był).'
        }
        else {
            $entry.Cleanup.ScanError = 'Skan nie powiódł się ({0}): {1}' -f $Task.Status, $(if ($null -ne $result) { $result.Message } else { $Task.Error })
        }
        Update-MwpInstanceView -Entry $entry
    }
    Update-MwpCleanupView -Entry $Entry
}
