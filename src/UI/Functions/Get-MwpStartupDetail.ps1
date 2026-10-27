function Get-MwpStartupDetail {
    <#
    .SYNOPSIS
        Składa tytuł i opis szczegółów wybranej pozycji autostartu albo zadania harmonogramu (widok Autostart i harmonogram).

    .DESCRIPTION
        Logika prezentacji bez WPF (testy Pester). Wynik: Title i Text (kilka wierszy: miejsce,
        polecenie, plik, podpis i wydawca, stan; dla zadania także konto, wyzwalacze, ostatnie
        i następne uruchomienie, wynik).
    #>
    [CmdletBinding(DefaultParameterSetName = 'Item')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(ParameterSetName = 'Item')]
        [AllowNull()]
        [object] $Item,

        [Parameter(ParameterSetName = 'Task')]
        [AllowNull()]
        [object] $Task
    )

    $lines = New-Object -TypeName System.Collections.Generic.List[string]
    $signature = {
        param($Entry)
        $text = 'Podpis: {0}' -f $Entry.RiskText
        if ($Entry.Publisher) {
            $text = '{0} — wydawca: {1}' -f $text, $Entry.Publisher
        }
        $text
    }
    $date = { param($Value) if ($null -ne $Value) { ([datetime]$Value).ToString('yyyy-MM-dd HH:mm') } else { 'brak' } }

    if ($PSCmdlet.ParameterSetName -eq 'Item') {
        if ($null -eq $Item) {
            return [pscustomobject]@{ Title = 'Wybierz pozycję autostartu z listy.'; Text = '' }
        }
        $lines.Add(('Miejsce: {0} — {1}' -f $Item.LocationText, $Item.Source))
        $lines.Add(('Dotyczy: {0}' -f $Item.UserName))
        $lines.Add(('Polecenie: {0}' -f $Item.Command))
        $lines.Add(('Plik: {0}{1}' -f $(if ($Item.FilePath) { $Item.FilePath } else { 'nie ustalono' }), $(if ($Item.FilePath -and -not $Item.FileExists) { ' (pliku nie ma)' } else { '' })))
        $lines.Add((& $signature $Item))
        $state = 'Stan: {0}' -f $Item.StateText
        if ($null -ne $Item.DisabledAt) {
            $state = '{0} (od {1})' -f $state, (& $date $Item.DisabledAt)
        }
        $lines.Add($state)
        return [pscustomobject]@{ Title = $Item.Name; Text = $lines -join [Environment]::NewLine }
    }

    if ($null -eq $Task) {
        return [pscustomobject]@{ Title = 'Wybierz zadanie z listy.'; Text = '' }
    }
    if ($Task.Description) {
        $lines.Add($Task.Description)
    }
    $lines.Add(('Stan: {0}' -f $Task.StateText))
    $lines.Add(('Akcje: {0}' -f $(if ($Task.ActionText) { $Task.ActionText } else { 'brak' })))
    $lines.Add((& $signature $Task))
    $lines.Add(('Wyzwalacze: {0}' -f $(if ($Task.TriggerText) { $Task.TriggerText } else { 'brak (tylko na żądanie)' })))
    $lines.Add(('Konto: {0}{1}' -f $(if ($Task.Account) { $Task.Account } else { 'nieznane' }), $(if ($Task.RunLevel -eq 'Highest') { ', najwyższe uprawnienia' } else { '' })))
    if ($Task.HasStoredPassword) {
        $lines.Add('Zadanie ma zapisane hasło konta — po usunięciu odtworzenie wymaga ręcznego importu XML z hasłem.')
    }
    $lines.Add(('Ostatnie uruchomienie: {0}{1}' -f (& $date $Task.LastRunTime), $(if ($Task.LastResultText) { ' — wynik: ' + $Task.LastResultText } else { '' })))
    $lines.Add(('Następne uruchomienie: {0}' -f (& $date $Task.NextRunTime)))
    if ($Task.Author) {
        $lines.Add(('Autor: {0}' -f $Task.Author))
    }
    [pscustomobject]@{ Title = $Task.Path; Text = $lines -join [Environment]::NewLine }
}
