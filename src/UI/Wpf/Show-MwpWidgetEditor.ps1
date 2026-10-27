function Show-MwpWidgetEditor {
    <#
    .SYNOPSIS
        Okno dodawania i edycji widgetu Dashboardu; zwraca wpis konfiguracji albo $null (anulowano).

    .DESCRIPTION
        Rodzaj widgetu z katalogu (Get-MwpWidgetDefinition), komputer z rejestru (Get-MwpTarget;
        komputery zdalne tylko dla modułów z RemoteTarget), nazwa, częstotliwość odświeżania, rozmiar
        kafelka i parametry ze schematu widgetu (StringArray z listą Values — pola wyboru, Bool — pole
        wyboru, pozostałe — pole tekstowe). Przy edycji rodzaju widgetu nie można zmienić.

    .PARAMETER Widget
        Edytowany widget (tabela z New-MwpWidgetRuntime) albo $null dla nowego.

    .PARAMETER Catalog
        Definicje widgetów.
    #>
    [CmdletBinding()]
    [OutputType([Collections.Specialized.OrderedDictionary])]
    param(
        [AllowNull()]
        [hashtable] $Widget,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]] $Catalog,

        [AllowNull()]
        [object] $Owner
    )

    $dialog = Import-MwpXaml -Path (Join-Path -Path $script:MwpUi.UiRoot -ChildPath 'Dialogs\WidgetEditor.xaml')
    $window = $dialog.Root
    $c = $dialog.Controls
    if ($null -eq $Owner) {
        $Owner = $script:MwpUi.Window
    }
    if ($null -ne $Owner -and $Owner.IsVisible) {
        $window.Owner = $Owner
    }
    $config = $(if ($null -ne $Widget) { $Widget.Config } else { $null })
    $c['HeaderText'].Text = $(if ($null -ne $config) { 'Ustawienia widgetu' } else { 'Nowy widget' })

    $widgetRows = @(foreach ($definition in $Catalog) {
            [pscustomobject]@{ Title = '{0} ({1})' -f $definition.Name, $definition.ModuleTitle; Definition = $definition }
        })
    $c['WidgetCombo'].ItemsSource = $widgetRows
    $refreshRows = @(
        [pscustomobject]@{ Title = 'Tylko ręcznie'; Value = 0 }
        [pscustomobject]@{ Title = 'Co 30 sekund'; Value = 30 }
        [pscustomobject]@{ Title = 'Co minutę'; Value = 60 }
        [pscustomobject]@{ Title = 'Co 5 minut'; Value = 300 }
        [pscustomobject]@{ Title = 'Co 15 minut'; Value = 900 }
    )
    $c['RefreshCombo'].ItemsSource = $refreshRows
    $sizeRows = @(
        [pscustomobject]@{ Title = 'Normalny'; Value = 'Normal' }
        [pscustomobject]@{ Title = 'Szeroki'; Value = 'Wide' }
    )
    $c['SizeCombo'].ItemsSource = $sizeRows
    $state = @{ Result = $null; Inputs = @{} }

    $fillTargets = {
        $selected = $c['WidgetCombo'].SelectedItem
        $current = $(if ($null -ne $c['TargetCombo'].SelectedItem) { $c['TargetCombo'].SelectedItem.Name } elseif ($null -ne $config) { [string]$config['computerName'] } else { 'localhost' })
        $rows = @(foreach ($target in @(Get-MwpTarget)) {
                if (-not $target.IsLocal -and ($null -eq $selected -or -not $selected.Definition.SupportsRemote)) {
                    continue
                }
                [pscustomobject]@{
                    Title = $(if ($target.DisplayName -like ('*{0}*' -f $target.Name)) { $target.DisplayName } else { '{0} ({1})' -f $target.DisplayName, $target.Name })
                    Name  = $target.Name
                }
            })
        $c['TargetCombo'].ItemsSource = $rows
        $c['TargetCombo'].SelectedItem = @($rows | Where-Object { $_.Name -eq $current }) + @($rows) | Select-Object -First 1
    }
    $fillParameters = {
        $panel = $c['ParametersPanel']
        $panel.Children.Clear()
        $state.Inputs = @{}
        $selected = $c['WidgetCombo'].SelectedItem
        $c['ParametersHeader'].Visibility = 'Collapsed'
        if ($null -eq $selected) {
            return
        }
        $c['WidgetDescription'].Text = $selected.Definition.Description
        $saved = $(if ($null -ne $config -and $config['parameters'] -is [Collections.IDictionary]) { $config['parameters'] } else { @{} })
        foreach ($key in @($selected.Definition.Parameters.Keys)) {
            $schema = $selected.Definition.Parameters[$key]
            $value = $(if ($saved.Contains($key)) { $saved[$key] } else { $schema['Default'] })
            $label = New-Object -TypeName System.Windows.Controls.TextBlock
            $label.Text = $(if ($schema.Contains('Label')) { [string]$schema['Label'] } else { [string]$key })
            $label.Margin = '0,6,0,2'
            $null = $panel.Children.Add($label)
            $c['ParametersHeader'].Visibility = 'Visible'
            if ($schema['Type'] -eq 'StringArray' -and $schema.Contains('Values')) {
                $wrap = New-Object -TypeName System.Windows.Controls.WrapPanel
                $boxes = @{}
                foreach ($option in @($schema['Values'])) {
                    $box = New-Object -TypeName System.Windows.Controls.CheckBox
                    $box.Content = $(if ($schema.Contains('ValueLabels') -and $schema['ValueLabels'].Contains($option)) { $schema['ValueLabels'][$option] } else { $option })
                    $box.IsChecked = @($value) -contains $option
                    $box.Margin = '0,2,16,2'
                    $null = $wrap.Children.Add($box)
                    $boxes[[string]$option] = $box
                }
                $null = $panel.Children.Add($wrap)
                $state.Inputs[$key] = @{ Type = 'Choices'; Boxes = $boxes; Order = @($schema['Values']) }
            }
            elseif ($schema['Type'] -eq 'Bool') {
                $box = New-Object -TypeName System.Windows.Controls.CheckBox
                $box.Content = 'Włączone'
                $box.IsChecked = [bool]$value
                $null = $panel.Children.Add($box)
                $state.Inputs[$key] = @{ Type = 'Bool'; Control = $box }
            }
            else {
                $box = New-Object -TypeName System.Windows.Controls.TextBox
                $box.Text = $(if ($schema['Type'] -eq 'StringArray') { @($value) -join ', ' } else { [string]$value })
                $null = $panel.Children.Add($box)
                $state.Inputs[$key] = @{ Type = [string]$schema['Type']; Control = $box }
            }
        }
    }

    $initial = $null
    if ($null -ne $config) {
        $initial = @($widgetRows | Where-Object { $_.Definition.ModuleId -eq $config['moduleId'] -and $_.Definition.WidgetId -eq $config['widgetId'] }) | Select-Object -First 1
        $c['WidgetCombo'].IsEnabled = $false
        $c['TitleBox'].Text = [string]$config['title']
    }
    if ($null -eq $initial) {
        $initial = $widgetRows | Select-Object -First 1
    }
    $c['WidgetCombo'].SelectedItem = $initial
    $refreshValue = $(if ($null -ne $config) { [int]$config['refreshSeconds'] } elseif ($null -ne $initial) { $initial.Definition.DefaultRefreshSeconds } else { 60 })
    $c['RefreshCombo'].SelectedItem = @($refreshRows | Where-Object { $_.Value -eq $refreshValue }) + @($refreshRows[2]) | Select-Object -First 1
    $sizeValue = $(if ($null -ne $config) { [string]$config['size'] } else { 'Normal' })
    $c['SizeCombo'].SelectedItem = @($sizeRows | Where-Object { $_.Value -eq $sizeValue }) + @($sizeRows[0]) | Select-Object -First 1
    & $fillTargets
    & $fillParameters
    $c['WidgetCombo'].Add_SelectionChanged({
            & $fillTargets
            & $fillParameters
        })

    $c['OkButton'].Add_Click({
            $selected = $c['WidgetCombo'].SelectedItem
            $target = $c['TargetCombo'].SelectedItem
            $problem = $null
            if ($null -eq $selected) {
                $problem = 'Wybierz rodzaj widgetu.'
            }
            elseif ($null -eq $target) {
                $problem = 'Wybierz komputer docelowy.'
            }
            $parameters = [ordered]@{}
            foreach ($key in @($state.Inputs.Keys | Sort-Object)) {
                $field = $state.Inputs[$key]
                switch ($field.Type) {
                    'Choices' {
                        $chosen = @($field.Order | Where-Object { $field.Boxes[[string]$_].IsChecked })
                        if ($chosen.Count -eq 0) {
                            $problem = 'Wybierz co najmniej jedną wartość parametru „{0}”.' -f $key
                        }
                        $parameters[$key] = $chosen
                    }
                    'Bool' { $parameters[$key] = [bool]$field.Control.IsChecked }
                    'Int' {
                        $number = 0
                        if (-not [int]::TryParse($field.Control.Text, [ref]$number)) {
                            $problem = 'Parametr „{0}” musi być liczbą całkowitą.' -f $key
                        }
                        $parameters[$key] = $number
                    }
                    'StringArray' { $parameters[$key] = @($field.Control.Text -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
                    default { $parameters[$key] = $field.Control.Text }
                }
            }
            if ($problem) {
                $c['ErrorText'].Text = $problem
                $c['ErrorText'].Visibility = 'Visible'
                return
            }
            $state.Result = [ordered]@{
                id             = $(if ($null -ne $config) { [string]$config['id'] } else { [guid]::NewGuid().ToString() })
                moduleId       = $selected.Definition.ModuleId
                widgetId       = $selected.Definition.WidgetId
                computerName   = $target.Name
                title          = $c['TitleBox'].Text.Trim()
                refreshSeconds = [int]$c['RefreshCombo'].SelectedItem.Value
                size           = [string]$c['SizeCombo'].SelectedItem.Value
                parameters     = $parameters
            }
            $window.Close()
        })
    $c['CancelButton'].Add_Click({ $window.Close() })

    $null = $window.ShowDialog()
    $state.Result
}
