function Restore-MwpScheduledTask {
    <#
    .SYNOPSIS
        Odtwarza usunięte zadanie harmonogramu z pliku XML (eksport Remove-MwpScheduledTask) na komputerze docelowym.

    .DESCRIPTION
        Polecenie cofające usunięcie zadania (Invoke-MwpUndo), dostępne też ręcznie. Nie tworzy
        nowych zadań — przywraca zapisaną definicję pod tą samą ścieżką (zakres FAZY 8). Klasa
        Zmiana (D-027): plik XML musi być poprawny, zadanie nie może już istnieć, wymagany
        administrator na komputerze docelowym, podgląd (-WhatIf) i potwierdzenie z nazwą komputera.
        Zadania z zapisanym hasłem konta (LogonType Password) nie da się odtworzyć bez hasła —
        funkcja odmawia z instrukcją ręcznego importu. Wpis cofnięcia: ponowne usunięcie.

    .PARAMETER XmlPath
        Plik XML z definicją zadania (na komputerze z aplikacją).

    .EXAMPLE
        Restore-MwpScheduledTask -XmlPath $result.Data.ExportPath -TaskPath '\' -TaskName 'Stare zadanie' -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $XmlPath,

        [Parameter(Mandatory, Position = 1)]
        [string] $TaskPath,

        [Parameter(Mandatory, Position = 2)]
        [string] $TaskName,

        [PSTypeName('MWP.ExecutionContext')]
        [object] $Context = (New-MwpExecutionContext)
    )

    $computerName = $Context.ComputerName
    $operation = 'Startup.RestoreTask'
    $fullPath = $TaskPath + $TaskName
    $common = @{ Operation = $operation; Target = $fullPath; ComputerName = $computerName }
    if (-not (Test-MwpScheduledTaskName -TaskPath $TaskPath -TaskName $TaskName)) {
        return New-MwpResult @common -Success $false -Message ("Niepoprawny folder lub nazwa zadania: '{0}'." -f $fullPath)
    }
    try {
        $xml = [IO.File]::ReadAllText($XmlPath)
        $document = New-Object -TypeName Xml.XmlDocument
        $document.LoadXml($xml)
    }
    catch {
        return New-MwpResult @common -Success $false -Message ("Nie można odczytać definicji zadania z pliku {0}: {1}" -f $XmlPath, $_.Exception.Message) -ErrorMessage $_.Exception.Message
    }
    $logon = @($document.GetElementsByTagName('LogonType') | ForEach-Object { $_.InnerText })
    if ($logon -contains 'Password') {
        return New-MwpResult @common -Success $false `
            -Message ("Zadanie '{0}' zapisuje hasło konta, więc nie można go odtworzyć automatycznie. Zaimportuj plik {1} w Harmonogramie zadań (Akcja → Importuj zadanie) i podaj hasło." -f $fullPath, $XmlPath)
    }

    $state = Read-MwpScheduledTaskState -Context $Context -Operation $operation -TaskPath $TaskPath -TaskName $TaskName -AllowMissing
    if ($null -ne $state.Task) {
        return New-MwpResult @common -Success $false -Before $state.Task.StateText -Message ("Zadanie '{0}' już istnieje na komputerze '{1}' — nie odtworzono." -f $fullPath, $computerName)
    }
    if (-not $state.Success) {
        return $state.Result
    }

    $target = Format-MwpOperationTarget -Target ("zadanie harmonogramu '{0}'" -f $fullPath) -ComputerName $computerName
    if (-not $PSCmdlet.ShouldProcess($target, ('Odtworzenie zadania z pliku {0}' -f $XmlPath))) {
        return New-MwpResult @common -Success $true -IsPreview -Before 'Brak' -After 'Odtworzone' -Message ("Podgląd: odtworzenie zadania '{0}' z pliku {1}." -f $fullPath, $XmlPath)
    }

    $control = Invoke-MwpScheduledTaskControl -Context $Context -Operation $operation -TaskPath $TaskPath -TaskName $TaskName -Action Register -Xml $xml
    if (-not $control.Success -or -not $control.Exists) {
        $reason = if (-not $control.Success) { $control.Message } else { 'zadanie nie pojawiło się po rejestracji' }
        $message = "Nie udało się odtworzyć zadania '{0}' na komputerze '{1}': {2}" -f $fullPath, $computerName, $reason
        Write-MwpLog -Level Error -Source 'MWP.Startup' -Operation $operation -ComputerName $computerName -Message $message -Data @{ Task = $fullPath; File = $XmlPath }
        return New-MwpResult @common -Success $false -Before 'Brak' -Message $message -ErrorMessage $control.ErrorMessage
    }
    $afterText = Get-MwpStartupText -TaskState ([string]$control.State)
    $undo = Save-MwpUndoEntry -Module 'MWP.Startup' -Operation $operation -Target $fullPath -ComputerName $computerName `
        -Description ("Odtworzenie zadania '{0}' z pliku {1}" -f $fullPath, $XmlPath) -Before 'Brak' -After $afterText `
        -UndoCommand 'Remove-MwpScheduledTask' -UndoParameters @{ TaskPath = $TaskPath; TaskName = $TaskName }
    $message = "Odtworzono zadanie '{0}' na komputerze '{1}' z pliku {2} (stan: {3})." -f $fullPath, $computerName, $XmlPath, $afterText
    Write-MwpLog -Level Info -Source 'MWP.Startup' -Operation $operation -ComputerName $computerName -Message $message -Data @{ Task = $fullPath; File = $XmlPath }
    New-MwpResult @common -Success $true -Changed $true -Before 'Brak' -After $afterText -UndoId $undo.Id -Message $message
}
