function Move-MwpUiInstance {
    <#
    .SYNOPSIS
        Przenosi widok instancji między oknem głównym (Embedded) a osobnym oknem (SeparateWindow).

    .DESCRIPTION
        Ten sam widok i ta sama instancja (kontekst, połączenie, stan) — zmienia się tylko miejsce
        prezentacji; logika modułu nie zależy od niego (D-019, D-020). Zamknięcie osobnego okna
        przez użytkownika zamyka instancję (Close-MwpUiInstance).

    .PARAMETER Placement
        Embedded albo SeparateWindow.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '',
        Justification = 'Parametry obsługi zdarzeń WPF są używane w zagnieżdżonych blokach (Invoke-MwpUiSafe -Action), czego reguła nie widzi.')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable] $Entry,

        [Parameter(Mandatory)]
        [ValidateSet('Embedded', 'SeparateWindow')]
        [string] $Placement
    )

    $ui = $script:MwpUi
    $root = $Entry.View.Root
    $instanceKey = 'instance:' + $Entry.Id

    if ($Placement -eq 'SeparateWindow') {
        if ($null -ne $Entry.Window) {
            $Entry.Window.Activate()
            return
        }
        if ($ui.Controls['ViewHost'].Content -eq $root) {
            $ui.Controls['ViewHost'].Content = $null
        }
        $shell = Import-MwpXaml -Path (Join-Path -Path $ui.UiRoot -ChildPath 'Dialogs\InstanceWindow.xaml')
        $window = $shell.Root
        $window.Tag = $Entry.Id
        $window.Owner = $null
        $window.WindowStartupLocation = 'CenterScreen'
        $shell.Controls['Host'].Content = $root
        $window.Add_Closed({
                param($control)
                Invoke-MwpUiSafe -Name 'UI.Instance.WindowClosed' -Action {
                    $entry = $script:MwpUi.Instances[[string]$control.Tag]
                    if ($null -ne $entry -and -not $entry.Reattaching -and -not $script:MwpUi.Closing) {
                        $entry.Window = $null
                        Close-MwpUiInstance -Id $entry.Id
                    }
                }
            })
        $Entry.Window = $window
        $Entry.WindowHost = $shell.Controls['Host']
        $Entry.Placement = 'SeparateWindow'
        Update-MwpInstanceView -Entry $Entry
        $window.Show()
        if ($ui.CurrentKey -eq $instanceKey -or $null -eq $ui.CurrentKey) {
            Show-MwpView -Key ('area:' + $Entry.Instance.ModuleId)
        }
    }
    else {
        if ($null -ne $Entry.Window) {
            $Entry.Reattaching = $true
            $Entry.WindowHost.Content = $null
            $Entry.Window.Close()
            $Entry.Window = $null
            $Entry.Reattaching = $false
        }
        $Entry.Placement = 'Embedded'
        Update-MwpInstanceView -Entry $Entry
        Show-MwpView -Key $instanceKey
        $ui.Window.Activate()
    }
    Update-MwpNavigation
}
