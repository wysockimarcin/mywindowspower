function Initialize-MwpAboutView {
    <#
    .SYNOPSIS
        Podpina widok „O programie": zadanie testowe w tle (postęp, anulowanie) do sprawdzenia, że okno się nie zawiesza.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '',
        Justification = 'Parametry obsługi zdarzeń WPF są używane w zagnieżdżonych blokach (Invoke-MwpUiSafe -Action), czego reguła nie widzi.')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $View
    )

    $View.Controls['DemoTaskButton'].Add_Click({
            Invoke-MwpUiSafe -Name 'UI.About.Demo' -Action {
                $ui = $script:MwpUi
                if ($null -ne $ui.DemoTask) {
                    return
                }
                $ui.DemoTask = Start-MwpUiTask -Registry $ui.Tasks -Pool $ui.Pool -Name 'Zadanie testowe' -Cancellable -ScriptBlock {
                    param($Progress)
                    for ($step = 1; $step -le 100; $step++) {
                        if ($Progress.CancelRequested) {
                            return 'Anulowano na kroku {0}.' -f $step
                        }
                        $Progress.Percent = $step
                        $Progress.Message = 'krok {0} ze 100' -f $step
                        Start-Sleep -Milliseconds 200
                    }
                    'Zakończono (20 s).'
                } -OnCompleted {
                    param($Task)
                    $script:MwpUi.DemoTask = $null
                    $controls = $script:MwpUi.Views['about'].Controls
                    $controls['DemoStatusText'].Text = 'Stan: {0}. {1}' -f $Task.Status, (@($Task.Output) -join ' ')
                    $controls['DemoTaskButton'].IsEnabled = $true
                    $controls['DemoCancelButton'].IsEnabled = $false
                }
                $controls = $ui.Views['about'].Controls
                $controls['DemoTaskButton'].IsEnabled = $false
                $controls['DemoCancelButton'].IsEnabled = $true
            }
        })
    $View.Controls['DemoCancelButton'].Add_Click({
            Invoke-MwpUiSafe -Name 'UI.About.Demo' -Action {
                $task = $script:MwpUi.DemoTask
                if ($null -ne $task) {
                    Stop-MwpUiTask -Task $task -Confirm:$false
                }
            }
        })
}
