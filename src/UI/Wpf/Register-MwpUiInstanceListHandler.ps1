function Register-MwpUiInstanceListHandler {
    <#
    .SYNOPSIS
        Obsługuje przyciski „Pokaż" i „Zamknij" na liście instancji (szablon danych: Uid = akcja, Tag = Id instancji).
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '',
        Justification = 'Parametry obsługi zdarzeń WPF są używane w zagnieżdżonych blokach (Invoke-MwpUiSafe -Action), czego reguła nie widzi.')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $List
    )

    $handler = [System.Windows.RoutedEventHandler] {
        param($control, $eventData)
        $button = $eventData.OriginalSource
        if ($button -isnot [System.Windows.Controls.Button]) {
            return
        }
        Invoke-MwpUiSafe -Name 'UI.InstanceList' -Action {
            $id = [string]$button.Tag
            switch ($button.Uid) {
                'Show' { Show-MwpView -Key ('instance:' + $id) }
                'Close' { Close-MwpUiInstance -Id $id }
            }
        }
    }
    $List.AddHandler([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent, $handler)
}
