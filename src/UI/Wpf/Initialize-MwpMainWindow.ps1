function Initialize-MwpMainWindow {
    <#
    .SYNOPSIS
        Podpina zdarzenia okna głównego: nawigację, wyszukiwanie, motyw, panel logu, pasek stanu i zegar.

    .DESCRIPTION
        Obsługa zdarzeń korzysta wyłącznie ze stanu powłoki ($script:MwpUi) i danych kontrolek
        (Tag), bo wywołuje się po zakończeniu tej funkcji. Każda obsługa jest opakowana
        w Invoke-MwpUiSafe. Zegar okna (DispatcherTimer, 250 ms) działa w wątku okna: odbiera wyniki
        zadań w tle (Update-MwpUiTask), odświeża pasek stanu, stan połączeń instancji i panel logu.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '',
        Justification = 'Parametry obsługi zdarzeń WPF są używane w zagnieżdżonych blokach (Invoke-MwpUiSafe -Action), czego reguła nie widzi.')]
    [CmdletBinding()]
    param()

    $ui = $script:MwpUi
    $c = $ui.Controls
    $environment = $ui.Environment

    $c['StatusAdmin'].Text = 'Administrator: {0}' -f $(if ($environment.IsAdmin) { 'tak' } else { 'nie' })
    $c['StatusPowerShell'].Text = 'PowerShell {0} ({1})' -f $environment.PSVersion, $environment.PSEdition
    $c['StatusWindows'].Text = 'Windows {0}{1}' -f $environment.OSVersion, $(if ($environment.IsWindows11) { '' } else { ' (nie Windows 11)' })
    Update-MwpStatusData

    Update-MwpNavigation
    foreach ($list in @($c['NavList'], $c['NavBottomList'])) {
        $list.Add_SelectionChanged({
                param($control, $eventData)
                Invoke-MwpUiSafe -Name 'UI.Navigate' -Action {
                    $ui = $script:MwpUi
                    if ($ui.Navigating -or $null -eq $control.SelectedItem) {
                        return
                    }
                    Show-MwpView -Key ([string]$control.SelectedItem.Tag)
                }
            })
    }

    # Wyszukiwanie w nawigacji (Ctrl+K): filtr po nazwie pozycji.
    $c['SearchBox'].Add_TextChanged({
            Invoke-MwpUiSafe -Name 'UI.Search' -Action {
                $controls = $script:MwpUi.Controls
                $text = $controls['SearchBox'].Text.Trim()
                $controls['SearchHint'].Visibility = $(if ($text -eq '') { 'Visible' } else { 'Collapsed' })
                foreach ($item in @($controls['NavList'].Items) + @($controls['NavBottomList'].Items)) {
                    $isHeader = -not $item.IsEnabled
                    if ($text -eq '') {
                        $item.Visibility = 'Visible'
                    }
                    elseif ($isHeader) {
                        $item.Visibility = 'Collapsed'
                    }
                    else {
                        $item.Visibility = $(if ([string]$item.ToolTip -like ('*{0}*' -f $text)) { 'Visible' } else { 'Collapsed' })
                    }
                }
            }
        })
    $c['SearchBox'].Add_KeyDown({
            param($control, $eventData)
            Invoke-MwpUiSafe -Name 'UI.Search' -Action {
                $controls = $script:MwpUi.Controls
                if ($eventData.Key -eq 'Escape') {
                    $control.Text = ''
                }
                elseif ($eventData.Key -eq 'Return') {
                    $first = @(@($controls['NavList'].Items) + @($controls['NavBottomList'].Items) |
                            Where-Object { $_.IsEnabled -and $_.Visibility -eq 'Visible' }) | Select-Object -First 1
                    if ($null -ne $first) {
                        Show-MwpView -Key ([string]$first.Tag)
                        $control.Text = ''
                    }
                }
            }
        })
    $ui.Window.Add_PreviewKeyDown({
            param($control, $eventData)
            if ($eventData.Key -eq 'K' -and ([System.Windows.Input.Keyboard]::Modifiers -band [System.Windows.Input.ModifierKeys]::Control)) {
                $null = $script:MwpUi.Controls['SearchBox'].Focus()
                $script:MwpUi.Controls['SearchBox'].SelectAll()
                $eventData.Handled = $true
            }
        })

    # Przełącznik motywu: zapamiętany w ustawieniu theme (Light/Dark); „System" wybiera się w Ustawieniach.
    $c['ThemeButton'].Add_Click({
            Invoke-MwpUiSafe -Name 'UI.Theme' -Action {
                $ui = $script:MwpUi
                $next = $(if ($ui.Theme -eq 'Dark') { 'Light' } else { 'Dark' })
                Set-MwpUiThemeSetting -Setting $next
            }
        })

    # Panel logu.
    $c['LogCloseButton'].Add_Click({ Invoke-MwpUiSafe -Name 'UI.Log' -Action { Switch-MwpLogPanel -Visible $false } })
    $c['LogRefreshButton'].Add_Click({ Invoke-MwpUiSafe -Name 'UI.Log' -Action { Update-MwpLogPanel } })
    $c['LogWarningsOnly'].Add_Click({ Invoke-MwpUiSafe -Name 'UI.Log' -Action { Update-MwpLogPanel } })

    # Pasek stanu: anulowanie zadań w tle.
    $c['StatusCancelButton'].Add_Click({
            Invoke-MwpUiSafe -Name 'UI.Cancel' -Action { Stop-MwpUiTask -Registry $script:MwpUi.Tasks -Confirm:$false }
        })

    # Zamykanie okna: zadania w tle i otwarte instancje.
    $ui.Window.Add_Closing({
            param($control, $eventData)
            $ui = $script:MwpUi
            # Zadania ciche (odświeżenia widgetów, tylko odczyt) nie wstrzymują zamknięcia (FAZA 5).
            $pending = @($ui.Tasks.ToArray() | Where-Object { -not ($null -ne $_.PSObject.Properties['Quiet'] -and $_.Quiet) })
            if ($pending.Count -gt 0) {
                $answer = [System.Windows.MessageBox]::Show($control, ("Trwają zadania w tle ({0}). Zamknąć aplikację i przerwać je?" -f $pending.Count),
                    'My Windows Power', [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Warning)
                if ($answer -ne [System.Windows.MessageBoxResult]::Yes) {
                    $eventData.Cancel = $true
                }
            }
        })

    $timer = New-Object -TypeName System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromMilliseconds(250)
    $timer.Add_Tick({ Invoke-MwpUiTick })
    $ui.Timer = $timer
    $timer.Start()
}
