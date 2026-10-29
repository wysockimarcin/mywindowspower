function Show-MwpWidgetEditor {
    <#
    .SYNOPSIS
        Okno dodawania i edycji widgetu Dashboardu; zwraca wpis konfiguracji albo $null (anulowano).

    .DESCRIPTION
        Rodzaj widgetu z katalogu (Get-MwpWidgetDefinition), komputer z rejestru (Get-MwpTarget;
        komputery zdalne tylko dla modułów z RemoteTarget), nazwa, częstotliwość odświeżania, rozmiar
        kafelka i parametry ze schematu widgetu (StringArray z listą Values — pola wyboru, Bool — pole
        wyboru, pozostałe — pole tekstowe; wspólne kontrolki New-MwpUiWidgetParameterPanel). Przy edycji
        rodzaju widgetu nie można zmienić. Nowy widget dostaje wartości początkowe z DefaultParameters
        definicji (domyślne parametry ustawione przez użytkownika w widoku „Moduły”, D-053).

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

    $widgetRows = @(foreach ($definition in @($Catalog | Sort-Object -Property ModuleTitle, Name)) {
            $suffix = $(if ($definition.SupportsRemote) { '' } else { ' · tylko ten komputer' })
            [pscustomobject]@{ Title = '{0} ({1}){2}' -f $definition.Name, $definition.ModuleTitle, $suffix; Definition = $definition }
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
    $state = @{ Result = $null; Parameters = $null }

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
        $selected = $c['WidgetCombo'].SelectedItem
        $state.Parameters = $null
        $c['ParametersPanel'].Children.Clear()
        $c['ParametersHeader'].Visibility = 'Collapsed'
        if ($null -eq $selected) {
            return
        }
        $c['WidgetDescription'].Text = $selected.Definition.Description
        # Edycja: parametry, którymi widget działa (z PreviousDefault dla kluczy sprzed D-053); nowy: domyślne użytkownika.
        $values = $(if ($null -ne $Widget -and $Widget.Parameters -is [Collections.IDictionary]) {
                $Widget.Parameters
            }
            elseif ($null -ne $config -and $config['parameters'] -is [Collections.IDictionary]) {
                $config['parameters']
            }
            elseif ($null -ne $selected.Definition.PSObject.Properties['DefaultParameters']) {
                $selected.Definition.DefaultParameters
            }
            else {
                @{}
            })
        $fields = @(Get-MwpWidgetParameterField -Schema $selected.Definition.Parameters -Value $values)
        $state.Parameters = New-MwpUiWidgetParameterPanel -Panel $c['ParametersPanel'] -Field $fields
        if ($fields.Count -gt 0) {
            $c['ParametersHeader'].Visibility = 'Visible'
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
            # Nowy widget: domyślna częstotliwość wybranego typu (widgety kosztowne — tylko ręcznie, D-053).
            $selected = $c['WidgetCombo'].SelectedItem
            if ($null -eq $config -and $null -ne $selected) {
                $c['RefreshCombo'].SelectedItem = @($refreshRows | Where-Object { $_.Value -eq $selected.Definition.DefaultRefreshSeconds }) + @($refreshRows[2]) | Select-Object -First 1
            }
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
            if ($null -ne $state.Parameters) {
                $read = & $state.Parameters.Read
                $parameters = $read.Parameters
                if ($read.Problem -and -not $problem) {
                    $problem = $read.Problem
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
