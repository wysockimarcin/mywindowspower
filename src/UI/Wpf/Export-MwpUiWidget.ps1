function Export-MwpUiWidget {
    <#
    .SYNOPSIS
        Eksportuje ostatnie dane widgetu do pliku JSON albo tekstowego (funkcja eksportu modułu).

    .DESCRIPTION
        Okno zapisu pliku (format z rozszerzenia: .txt — tekst, .json — JSON), potem ExportCommand
        z kontraktu widgetu (D-043; dla „Informacje o systemie” — Export-MwpSystemReport). Eksportowane
        są dane z ostatniego udanego odświeżenia (bez ponownego odczytu z komputera).

    .PARAMETER Id
        Identyfikator widgetu.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Id,

        [AllowNull()]
        [object] $Owner
    )

    $widget = @($script:MwpUi.Dashboard.Widgets | Where-Object { $_.Id -eq $Id -and -not $_.Removed }) | Select-Object -First 1
    if ($null -eq $widget -or $null -eq $widget.Definition.ExportCommand) {
        return
    }
    if ($null -eq $widget.Data) {
        Show-MwpMessage -Text 'Widget nie ma jeszcze danych do eksportu. Odśwież go i spróbuj ponownie.' -Kind Warning -Owner $Owner
        return
    }
    $dialog = New-Object -TypeName Microsoft.Win32.SaveFileDialog
    $dialog.Title = 'Eksport raportu'
    $dialog.Filter = 'Raport tekstowy (*.txt)|*.txt|Raport JSON (*.json)|*.json'
    $dialog.FileName = 'raport-{0}-{1:yyyyMMdd-HHmm}' -f ([string]$widget.Config['computerName'] -replace '[^A-Za-z0-9_.-]', '_'), (Get-Date)
    $dialog.OverwritePrompt = $true
    $accepted = if ($null -ne $Owner) { $dialog.ShowDialog($Owner) } else { $dialog.ShowDialog() }
    if (-not $accepted) {
        return
    }
    $format = if ($dialog.FilterIndex -eq 2 -or [IO.Path]::GetExtension($dialog.FileName) -eq '.json') { 'Json' } else { 'Text' }
    $command = $widget.Definition.ExportCommand
    $result = & $command -Data $widget.Data -Path $dialog.FileName -Format $format -Confirm:$false
    Show-MwpMessage -Text $result.Message -Kind $(if ($result.Success) { 'Info' } else { 'Warning' }) -Owner $Owner
}
