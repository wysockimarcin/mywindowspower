function Update-MwpNavigation {
    <#
    .SYNOPSIS
        Buduje na nowo listy nawigacji: Pulpit, obszary, moduły z paczek, otwarte instancje i pozycje dolne.

    .DESCRIPTION
        Pozycje pochodzą z Get-MwpNavigationItem (definicje modułów w $script:MwpUi.Definitions);
        sekcja „Otwarte instancje" pokazuje instancje z ich komputerem (D-019). Tag pozycji to klucz
        widoku (Show-MwpView). Zaznaczenie bieżącego widoku jest odtwarzane bez ponownej nawigacji.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Zmienia tylko kontrolki okna.')]
    [CmdletBinding()]
    param()

    $ui = $script:MwpUi
    $c = $ui.Controls
    $iconStyle = $ui.Window.FindResource('Mwp.Text.Glyph')
    $itemStyle = $ui.Window.FindResource('Mwp.NavItem')

    $newItem = {
        param($Key, $Title, $Glyph, $Note, $Muted)
        $panel = New-Object -TypeName System.Windows.Controls.StackPanel
        $panel.Orientation = 'Horizontal'
        $icon = New-Object -TypeName System.Windows.Controls.TextBlock
        $icon.Style = $iconStyle
        $icon.Text = $Glyph
        $icon.Width = 28
        $label = New-Object -TypeName System.Windows.Controls.TextBlock
        $label.Text = $Title
        $label.VerticalAlignment = 'Center'
        $label.TextTrimming = 'CharacterEllipsis'
        $label.MaxWidth = 170
        $null = $panel.Children.Add($icon)
        $null = $panel.Children.Add($label)
        if ($Note) {
            $noteBlock = New-Object -TypeName System.Windows.Controls.TextBlock
            $noteBlock.Text = $Note
            $noteBlock.FontSize = 11
            $noteBlock.Margin = '8,0,0,0'
            $noteBlock.VerticalAlignment = 'Center'
            $noteBlock.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, 'Mwp.Brush.TextMuted')
            $null = $panel.Children.Add($noteBlock)
        }
        if ($Muted) {
            $label.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, 'Mwp.Brush.TextMuted')
        }
        $item = New-Object -TypeName System.Windows.Controls.ListBoxItem
        $item.Style = $itemStyle
        $item.Content = $panel
        $item.Tag = $Key
        $item.ToolTip = $Title
        $item
    }
    $newHeader = {
        param($Title)
        $text = New-Object -TypeName System.Windows.Controls.TextBlock
        $text.Text = $Title
        $text.FontSize = 12
        $text.Margin = '0,10,0,0'
        $item = New-Object -TypeName System.Windows.Controls.ListBoxItem
        $item.Style = $itemStyle
        $item.Content = $text
        $item.IsEnabled = $false
        $item.Focusable = $false
        $item.Tag = 'header:' + $Title
        $item
    }

    $ui.Navigating = $true
    try {
        $c['NavList'].Items.Clear()
        $c['NavBottomList'].Items.Clear()
        foreach ($navigation in @(Get-MwpNavigationItem -Definition $ui.Definitions)) {
            if ($navigation.Kind -eq 'Header') {
                $null = $c['NavList'].Items.Add((& $newHeader $navigation.Title))
                continue
            }
            $note = $null
            if ($navigation.Key.StartsWith('area:') -or $navigation.Key -eq 'dashboard') {
                if (-not $navigation.IsAvailable) {
                    $note = 'FAZA {0}' -f $navigation.Phase
                }
                else {
                    $count = @($ui.Instances.Values | Where-Object { $_.Instance.ModuleId -eq $navigation.ModuleId }).Count
                    if ($count -gt 0 -and $navigation.Key -ne 'dashboard') {
                        $note = '({0})' -f $count
                    }
                }
            }
            $list = if ($navigation.Section -eq 'Bottom') { $c['NavBottomList'] } else { $c['NavList'] }
            $null = $list.Items.Add((& $newItem $navigation.Key $navigation.Title $navigation.Glyph $note (-not $navigation.IsAvailable)))
        }

        $entries = @($ui.Instances.Values | Sort-Object -Property { $_.Instance.CreatedAt })
        if ($entries.Count -gt 0) {
            $null = $c['NavList'].Items.Add((& $newHeader 'Otwarte instancje'))
            foreach ($entry in $entries) {
                $glyph = if ($entry.Placement -eq 'SeparateWindow') { [string][char]0xE8A7 } else { [string][char]0xE737 }
                $null = $c['NavList'].Items.Add((& $newItem ('instance:' + $entry.Id) $entry.Instance.Name $glyph $null $false))
            }
        }
        Select-MwpNavigationItem -Key $ui.CurrentKey
    }
    finally {
        $ui.Navigating = $false
    }
    if ($c['SearchBox'].Text -ne '') {
        # Ponowne zastosowanie filtra wyszukiwania do nowych pozycji.
        $text = $c['SearchBox'].Text
        $c['SearchBox'].Text = ''
        $c['SearchBox'].Text = $text
    }
}
