function Start-MwpUiUpdateInstall {
    <#
    .SYNOPSIS
        Instaluje w tle potwierdzone aktualizacje na komputerze lokalnym, potem pokazuje wynik i odświeża stan, listę oczekujących i historię.

    .DESCRIPTION
        Wywoływana dopiero po oknie potwierdzenia (Invoke-MwpUpdateViewAction). Zadanie GUI wywołuje
        Install-MwpUpdate -Confirm:$false z kontekstem instancji i tabelą postępu; log zapisuje funkcja
        logiki. Anulowanie z widoku ustawia CancelRequested — praca kończy się po bieżącej aktualizacji
        (przerwanie instalacji w połowie mogłoby zostawić system w stanie niespójnym). Zadanie nie jest
        anulowane przyciskiem paska stanu. Restart nie jest wykonywany (informacja w wyniku).

    .PARAMETER UpdateId
        Identyfikatory aktualizacji do instalacji.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Wywoływana po oknie potwierdzenia; podgląd i potwierdzenie zapewnia widok i Install-MwpUpdate.')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable] $Entry,

        [Parameter(Mandatory)]
        [string[]] $UpdateId
    )

    $ui = $script:MwpUi
    $context = $Entry.Instance.Context
    $view = $Entry.Update
    if ($null -ne $view.Task) {
        return
    }
    $module = @(Get-Module -Name $Entry.Instance.ModuleName) | Select-Object -First 1
    $view.Task = Start-MwpUiTask -Registry $ui.Tasks -Pool $ui.Pool -Name ('Instalacja aktualizacji ({0})' -f $context.ComputerName) -State @{ InstanceId = $Entry.Id } `
        -ArgumentList $(if ($null -ne $module) { $module.Path } else { '' }), $context, $UpdateId -ScriptBlock (Get-MwpUiUpdateScript) -OnCompleted {
        param($Task)
        $entry = $script:MwpUi.Instances[[string]$Task.State.InstanceId]
        if ($null -eq $entry) {
            return
        }
        $entry.Update.Task = $null
        $result = @($Task.Output | Where-Object { $null -ne $_ -and $_.PSObject.TypeNames -contains 'MWP.Result' }) | Select-Object -Last 1
        $text = if ($null -ne $result) {
            $lines = @($result.Message)
            if ($null -ne $result.Data) {
                $lines += @($result.Data.Items | ForEach-Object { '{0}: {1}{2}' -f $_.Title, $_.StatusText, $(if ($_.Reason) { ' (' + $_.Reason + ')' } else { '' }) })
            }
            $lines -join [Environment]::NewLine
        }
        else {
            'Zadanie instalacji zakończyło się bez wyniku ({0}): {1}' -f $Task.Status, $Task.Error
        }
        $entry.Update.Report = $text
        Start-MwpUiUpdateRefresh -Entry $entry -Kind Status
        Start-MwpUiUpdateRefresh -Entry $entry -Kind Search -Type $(if ($null -ne $entry.Update.Search) { [string]$entry.Update.Search.Type } else { 'All' })
        Start-MwpUiUpdateRefresh -Entry $entry -Kind History
        Update-MwpInstanceView -Entry $entry
        if ($null -ne $result -and $result.RestartRequired) {
            Show-MwpMessage -Text ('{0}{1}Uruchom komputer ponownie w dogodnym momencie — aplikacja nie robi tego sama.' -f $result.Message, [Environment]::NewLine)
        }
    }
    Update-MwpUpdateView -Entry $Entry
}
