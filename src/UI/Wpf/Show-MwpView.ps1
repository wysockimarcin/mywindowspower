function Show-MwpView {
    <#
    .SYNOPSIS
        Nawigacja hosta: pokazuje widok o podanym kluczu w kontenerze okna głównego.

    .DESCRIPTION
        Klucze: dashboard, area:<Id modułu>, instance:<Id instancji>, modules, settings, about oraz
        log (przełącza panel logu bez zmiany widoku). Widoki są tworzone przy pierwszym użyciu
        i zapamiętywane (stan widoku zostaje przy przełączaniu); przy każdym pokazaniu są odświeżane.
        Instancja w osobnym oknie jest aktywowana zamiast pokazywania w oknie głównym.

    .PARAMETER Key
        Klucz widoku.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Key
    )

    $ui = $script:MwpUi
    $c = $ui.Controls

    if ($Key -eq 'log') {
        Switch-MwpLogPanel -Visible (-not $ui.LogVisible)
        Select-MwpNavigationItem -Key $ui.CurrentKey
        return
    }

    if ($Key.StartsWith('instance:')) {
        $entry = $ui.Instances[$Key.Substring(9)]
        if ($null -eq $entry) {
            Select-MwpNavigationItem -Key $ui.CurrentKey
            return
        }
        if ($entry.Placement -eq 'SeparateWindow' -and $null -ne $entry.Window) {
            $entry.Window.Activate()
            if ($entry.Window.WindowState -eq 'Minimized') {
                $entry.Window.WindowState = 'Normal'
            }
            Select-MwpNavigationItem -Key $ui.CurrentKey
            return
        }
        Update-MwpInstanceView -Entry $entry
        $c['ViewHost'].Content = $entry.View.Root
    }
    else {
        $view = $ui.Views[$Key]
        if ($null -eq $view) {
            $view = New-MwpUiView -Key $Key
            if ($null -eq $view) {
                Select-MwpNavigationItem -Key $ui.CurrentKey
                return
            }
            $ui.Views[$Key] = $view
        }
        $ui.CurrentKey = $Key
        Update-MwpCurrentView
        $c['ViewHost'].Content = $view.Root
    }

    $ui.CurrentKey = $Key
    Select-MwpNavigationItem -Key $Key
    Update-MwpStatusInstance
}
