function Update-MwpAboutDemo {
    <#
    .SYNOPSIS
        Pokazuje postęp zadania testowego w widoku „O programie" (wywołanie z zegara okna).
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Zmienia tylko kontrolki okna.')]
    [CmdletBinding()]
    param()

    $ui = $script:MwpUi
    $task = $ui.DemoTask
    $view = $ui.Views['about']
    if ($null -eq $task -or $null -eq $view) {
        return
    }
    $percent = [int]$task.Progress.Percent
    $view.Controls['DemoProgress'].Value = [Math]::Max(0, $percent)
    $view.Controls['DemoStatusText'].Text = 'W toku: {0}' -f $task.Progress.Message
}
