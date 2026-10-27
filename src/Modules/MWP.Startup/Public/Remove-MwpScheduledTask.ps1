function Remove-MwpScheduledTask {
    <#
    .SYNOPSIS
        Usuwa zadanie harmonogramu na komputerze docelowym po zapisaniu jego definicji (eksport XML) na komputerze z aplikacją.

    .DESCRIPTION
        Operacja klasy Destrukcyjna (D-027, ConfirmImpact High): odczyt zadania, lista ochronna
        (zadań krytycznych i z folderu \Microsoft\ nie wolno usuwać, D-046), uprawnienia
        administratora na komputerze docelowym, podgląd (-WhatIf) i potwierdzenie z nazwą komputera.
        Przed usunięciem definicja jest eksportowana (Export-ScheduledTask) i zapisywana lokalnie
        w <katalog danych>\exports\tasks (albo -ExportDirectory, UTF-16 jak eksport Harmonogramu
        zadań); nieudany zapis przerywa operację. Wpis cofnięcia: Restore-MwpScheduledTask z tym
        plikiem. Zadania z zapisanym hasłem konta nie da się odtworzyć bez hasła — podgląd o tym
        ostrzega (plik XML można zaimportować ręcznie w Harmonogramie zadań).

    .PARAMETER ExportDirectory
        Folder eksportu XML (domyślnie <katalog danych>\exports\tasks).

    .EXAMPLE
        Remove-MwpScheduledTask -TaskPath '\' -TaskName 'Stare zadanie' -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string] $TaskPath,

        [Parameter(Mandatory, Position = 1)]
        [string] $TaskName,

        [ValidateNotNullOrEmpty()]
        [string] $ExportDirectory,

        [PSTypeName('MWP.ExecutionContext')]
        [object] $Context = (New-MwpExecutionContext)
    )

    $computerName = $Context.ComputerName
    $operation = 'Startup.RemoveTask'
    $common = @{ Operation = $operation; Target = ($TaskPath + $TaskName); ComputerName = $computerName }
    if (-not (Test-MwpScheduledTaskName -TaskPath $TaskPath -TaskName $TaskName)) {
        return New-MwpResult @common -Success $false -Message ("Niepoprawny folder lub nazwa zadania: '{0}{1}'." -f $TaskPath, $TaskName)
    }
    $state = Read-MwpScheduledTaskState -Context $Context -Operation $operation -TaskPath $TaskPath -TaskName $TaskName
    if ($null -ne $state.Task -and -not $state.Task.CanRemove) {
        $reason = if ($state.Task.IsProtected) { $state.Task.ProtectionReason } else { $state.Task.RemovalReason }
        return New-MwpResult @common -Success $false -Before $state.Task.StateText `
            -Message ("Zadanie '{0}' jest na liście ochronnej — nie można go usunąć (można je wyłączyć, jeśli nie jest krytyczne). Powód: {1}" -f $state.Task.Path, $reason)
    }
    if (-not $state.Success) {
        return $state.Result
    }
    $task = $state.Task

    if (-not $PSBoundParameters.ContainsKey('ExportDirectory')) {
        $ExportDirectory = Join-Path -Path (Get-MwpDataLocation).Root -ChildPath 'exports\tasks'
    }
    $safe = ('{0}_{1}' -f $computerName, $task.Path.Trim('\')) -replace '[\\/:*?"<>|\s\[\]]+', '_'
    $file = Join-Path -Path $ExportDirectory -ChildPath ('{0}_{1:yyyyMMdd-HHmmss}.xml' -f $safe, (Get-Date))
    $passwordNote = if ($task.HasStoredPassword) { ' Uwaga: zadanie ma zapisane hasło konta — cofnięcie (odtworzenie) wymaga ręcznego importu pliku XML z podaniem hasła.' } else { '' }

    $target = Format-MwpOperationTarget -Target ("zadanie harmonogramu '{0}'" -f $task.Path) -ComputerName $computerName
    if (-not $PSCmdlet.ShouldProcess($target, ('Usunięcie zadania po eksporcie definicji do {0}' -f $file))) {
        return New-MwpResult @common -Success $true -IsPreview -Before $task.StateText -After 'Usunięte' `
            -Message ("Podgląd: usunięcie zadania '{0}' ({1}). Definicja zostanie najpierw zapisana do {2}.{3}" -f $task.Path, $task.ActionText, $file, $passwordNote)
    }

    $export = Invoke-MwpScheduledTaskControl -Context $Context -Operation $operation -TaskPath $TaskPath -TaskName $TaskName -Action Export
    if (-not $export.Success -or -not $export.Xml) {
        $message = "Nie usunięto zadania '{0}': eksport definicji (XML) się nie udał: {1}" -f $task.Path, $(if ($export.Message) { $export.Message } else { 'pusta definicja' })
        Write-MwpLog -Level Error -Source 'MWP.Startup' -Operation $operation -ComputerName $computerName -Message $message -Data @{ Task = $task.Path }
        return New-MwpResult @common -Success $false -Before $task.StateText -Message $message -ErrorMessage $export.ErrorMessage
    }
    try {
        $null = [IO.Directory]::CreateDirectory($ExportDirectory)
        [IO.File]::WriteAllText($file, [string]$export.Xml, [Text.Encoding]::Unicode)
        if ([IO.File]::ReadAllText($file) -ne [string]$export.Xml) {
            throw 'zapisany plik różni się od eksportu'
        }
    }
    catch {
        $message = "Nie usunięto zadania '{0}': nie udało się zapisać definicji do {1}: {2}" -f $task.Path, $file, $_.Exception.Message
        Write-MwpLog -Level Error -Source 'MWP.Startup' -Operation $operation -ComputerName $computerName -Message $message -Data @{ Task = $task.Path; File = $file }
        return New-MwpResult @common -Success $false -Before $task.StateText -Message $message -ErrorMessage $_.Exception.Message
    }

    $control = Invoke-MwpScheduledTaskControl -Context $Context -Operation $operation -TaskPath $TaskPath -TaskName $TaskName -Action Remove
    $removed = $control.Exists -eq $false
    $undoId = $null
    if ($removed) {
        $undo = Save-MwpUndoEntry -Module 'MWP.Startup' -Operation $operation -Target $task.Path -ComputerName $computerName `
            -Description ("Usunięcie zadania '{0}' (definicja: {1})" -f $task.Path, $file) -Before $task.StateText -After 'Usunięte' `
            -UndoCommand 'Restore-MwpScheduledTask' -UndoParameters @{ XmlPath = $file; TaskPath = $TaskPath; TaskName = $TaskName }
        $undoId = $undo.Id
    }
    if (-not $control.Success -or -not $removed) {
        $reason = if (-not $control.Success) { $control.Message } else { 'zadanie nadal istnieje' }
        $message = "Nie udało się usunąć zadania '{0}' na komputerze '{1}': {2} Definicja zapisana w {3}." -f $task.Path, $computerName, $reason, $file
        Write-MwpLog -Level Error -Source 'MWP.Startup' -Operation $operation -ComputerName $computerName -Message $message -Data @{ Task = $task.Path; File = $file }
        return New-MwpResult @common -Success $false -Changed $removed -Before $task.StateText -UndoId $undoId -Message $message -ErrorMessage $control.ErrorMessage
    }
    $message = "Usunięto zadanie '{0}' na komputerze '{1}'. Definicja zapisana w {2}.{3}" -f $task.Path, $computerName, $file, $passwordNote
    Write-MwpLog -Level Info -Source 'MWP.Startup' -Operation $operation -ComputerName $computerName -Message $message -Data @{ Task = $task.Path; File = $file }
    New-MwpResult @common -Success $true -Changed $true -Before $task.StateText -After 'Usunięte' -UndoId $undoId -Message $message -Data ([pscustomobject]@{ ExportPath = $file })
}
