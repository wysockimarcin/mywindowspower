function Invoke-MwpUpdateViewAction {
    <#
    .SYNOPSIS
        Obsługa przycisków widoku Windows Update: odczyt stanu, wyszukiwanie, instalacja z potwierdzeniem, Ustawienia, anulowanie, pauza, wznowienie, reset składników, historia, cofnięcie.

    .DESCRIPTION
        Instalacja (D-048): okno potwierdzenia operacji destrukcyjnej z listą aktualizacji (tytuł, KB,
        rozmiar, restart) i pominiętymi z powodem, potem zadanie w tle (Start-MwpUiUpdateInstall).
        Pauza, wznowienie, reset i cofnięcie idą przez Invoke-MwpUiInstanceChange z krokami — funkcjami
        MWP.Update z kontekstem instancji (podgląd -WhatIf w tle, okno potwierdzenia z komputerem
        docelowym; reset jako operacja destrukcyjna z wpisaniem nazwy komputera i podglądem kroków).

    .PARAMETER Action
        Nazwa przycisku (x:Name) z Views\Update.xaml.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Zmiany przechodzą przez podgląd i okno potwierdzenia (Invoke-MwpUiInstanceChange, Show-MwpConfirmDialog).')]
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
    $view = $Entry.Update
    $context = $Entry.Instance.Context
    $after = 'Start-MwpUiUpdateRefresh'

    switch ($Action) {
        'UpdateRefreshButton' {
            Start-MwpUiUpdateRefresh -Entry $Entry -Kind Status
        }
        'UpdateSearchButton' {
            $type = $p['UpdateTypeBox'].SelectedItem
            Start-MwpUiUpdateRefresh -Entry $Entry -Kind Search -Type $(if ($null -ne $type) { [string]$type.Value } else { 'All' })
        }
        'UpdateHistoryButton' {
            Start-MwpUiUpdateRefresh -Entry $Entry -Kind History
        }
        'UpdateSettingsButton' {
            $result = Open-MwpUpdatePage -Context $context
            if (-not $result.Success) {
                Show-MwpMessage -Text $result.Message -Kind Warning -Owner $Owner
            }
        }
        'UpdateInstallButton' {
            $selectedId = @(@($p['UpdatesGrid'].SelectedItems) | ForEach-Object { [string]$_.UpdateId })
            $state = Get-MwpUpdateActionState -Status $view.Status -Search $view.Search -SelectedId $selectedId -IsLocal ($context.Mode -eq 'Local') -Ready ($null -eq $view.Task)
            if (-not $state.CanInstall) {
                if ($state.InstallBlocked) {
                    Show-MwpMessage -Text $state.InstallBlocked -Kind Warning -Owner $Owner
                }
                return
            }
            $confirmed = Show-MwpConfirmDialog -Header 'Instalacja aktualizacji Windows' -Target ('{0} aktualizacji do pobrania i instalacji.' -f $state.Installable.Count) `
                -ComputerName $context.ComputerName -PreviewLine $state.PreviewLine -Class Destructive -ConfirmText 'Zainstaluj' `
                -Warning 'Instalacja może trwać od kilku minut do godziny i nie da się jej cofnąć z aplikacji (odinstalowanie: Ustawienia → Windows Update → Historia aktualizacji). Komputer nie zostanie uruchomiony ponownie automatycznie. Anulowanie działa po bieżącej aktualizacji.' `
                -Owner $Owner
            if ($confirmed) {
                Start-MwpUiUpdateInstall -Entry $Entry -UpdateId @($state.Installable | ForEach-Object { [string]$_.UpdateId })
            }
        }
        'UpdateCancelButton' {
            if ($null -ne $view.Task) {
                $view.Task.Progress['CancelRequested'] = $true
                Update-MwpUpdateView -Entry $Entry -StateOnly
            }
        }
        'UpdatePauseButton' {
            $weeks = $p['UpdatePauseWeeksBox'].SelectedItem
            if ($null -eq $weeks) { return }
            Invoke-MwpUiInstanceChange -Entry $Entry -Header 'Wstrzymanie aktualizacji Windows' -Target ('Pauza: {0}' -f $weeks.Label) -AfterCommand $after -Owner $Owner `
                -Steps @(@{ Command = 'Suspend-MwpUpdate'; Parameters = @{ Weeks = [int]$weeks.Value }; Label = ('Pauza: {0}' -f $weeks.Label) })
        }
        'UpdateResumeButton' {
            Invoke-MwpUiInstanceChange -Entry $Entry -Header 'Wznowienie aktualizacji Windows' -Target 'Usunięcie pauzy' -AfterCommand $after -Owner $Owner `
                -Steps @(@{ Command = 'Resume-MwpUpdate'; Parameters = @{}; Label = 'Wznowienie' })
        }
        'UpdateResetButton' {
            Invoke-MwpUiInstanceChange -Entry $Entry -Header 'Reset składników Windows Update' -Class Destructive -RequireText $context.ComputerName -ConfirmText 'Resetuj' `
                -Target 'Usługi Windows Update, SoftwareDistribution i catroot2 (stare foldery zostają)' -AfterCommand $after -Owner $Owner `
                -Steps @(@{ Command = 'Reset-MwpUpdateComponent'; Parameters = @{}; Label = 'Reset składników' })
        }
        'UpdateUndoButton' {
            $undo = $p['UpdateUndoGrid'].SelectedItem
            if ($null -eq $undo) { return }
            Invoke-MwpUiInstanceChange -Entry $Entry -Header 'Cofnięcie zmiany Windows Update' -Target $undo.Description -AfterCommand $after -Owner $Owner `
                -Steps @(@{ Command = 'Invoke-MwpUndo'; Parameters = @{ Id = $undo.Id }; Label = 'Cofnięcie' })
        }
    }
}
