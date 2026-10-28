function Invoke-MwpCleanupViewAction {
    <#
    .SYNOPSIS
        Obsługa kontrolek widoku Czyszczenie dysku: skan, profile użytkowników, zaznaczenie, czyszczenie z potwierdzeniem, anulowanie, analiza DISM.

    .DESCRIPTION
        Czyszczenie (D-047): okno potwierdzenia operacji destrukcyjnej z listą kategorii, liczbą plików
        i rozmiarem z ostatniego skanu oraz nazwą komputera docelowego, którą trzeba wpisać; dopiero
        potem zadanie w tle (Start-MwpUiCleanup). Domyślnie nic nie jest usuwane. Profile użytkowników
        przy czyszczeniu — tak jak w skanie, z którego pochodzi podgląd. Anulowanie: skan — natychmiast,
        czyszczenie — po bieżącym pliku albo kategorii (raport obejmuje to, co usunięto).

    .PARAMETER Action
        Nazwa kontrolki (x:Name) z Views\Cleanup.xaml.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Czyszczenie przechodzi przez okno potwierdzenia (Show-MwpConfirmDialog) i funkcje logiki.')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable] $Entry,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Action,

        [AllowNull()]
        [object] $Owner
    )

    $p = $Entry.ModuleView.Controls
    $view = $Entry.Cleanup
    $context = $Entry.Instance.Context
    $selectedIds = @(@($p['CleanupGrid'].SelectedItems) | ForEach-Object { [string]$_.Id })

    switch ($Action) {
        { $_ -in 'CleanupScanButton', 'CleanupProfilesCheck' } {
            Start-MwpUiCleanupScan -Entry $Entry
        }
        'CleanupSelectAllButton' {
            $state = Get-MwpCleanupActionState -Scan $view.Scan -SelectedId @($view.CategoryById.Keys)
            $ids = @($state.Categories | ForEach-Object { $_.Id })
            $grid = $p['CleanupGrid']
            $grid.SelectedItems.Clear()
            foreach ($row in @($grid.ItemsSource)) {
                if ($ids -contains [string]$row.Id) {
                    $null = $grid.SelectedItems.Add($row)
                }
            }
        }
        'CleanupRunButton' {
            $state = Get-MwpCleanupActionState -Scan $view.Scan -SelectedId $selectedIds -Ready ($null -eq $view.Task)
            if (-not $state.CanRun) {
                return
            }
            if ((Get-MwpConnectionStateInfo -Context $context).NeedsCredential) {
                Show-MwpMessage -Text ('Najpierw połącz instancję z komputerem {0} (przycisk „Połącz”).' -f $context.ComputerName) -Owner $Owner
                return
            }
            $names = @($state.Categories | ForEach-Object { $_.Name }) -join ', '
            $profiles = if ($view.Scan.IncludeUserProfiles) { 'profile wszystkich użytkowników' } elseif ($view.Scan.IsRemote) { 'tylko lokalizacje systemowe' } else { 'profil bieżącego konta' }
            $confirmed = Show-MwpConfirmDialog -Header 'Trwałe usunięcie plików (czyszczenie dysku)' -Target ('Kategorie: {0} ({1}).' -f $names, $profiles) `
                -ComputerName $context.ComputerName -PreviewLine $state.PreviewLine -Class Destructive -RequireText $context.ComputerName -ConfirmText 'Usuń' `
                -Warning 'Pliki zostaną usunięte trwale (bez przenoszenia do Kosza) i nie da się ich przywrócić z aplikacji. Usuwane są tylko pliki z lokalizacji kategorii; pliki w użyciu, dowiązania (junction/symlink) oraz dokumenty i pulpit użytkowników są pomijane.' `
                -Owner $Owner
            if ($confirmed) {
                Start-MwpUiCleanup -Entry $Entry -Category @($state.Categories | ForEach-Object { $_.Id }) -IncludeUserProfiles ([bool]$view.Scan.IncludeUserProfiles)
            }
        }
        'CleanupCancelButton' {
            if ($null -eq $view.Task) {
                return
            }
            if ($view.TaskKind -eq 'Scan') {
                Stop-MwpUiTask -Task $view.Task -Confirm:$false
            }
            else {
                $view.Task.Progress['CancelRequested'] = $true
            }
            Update-MwpCleanupView -Entry $Entry -StateOnly
        }
        'ComponentStoreButton' {
            Start-MwpUiComponentStoreAnalysis -Entry $Entry
        }
    }
}
