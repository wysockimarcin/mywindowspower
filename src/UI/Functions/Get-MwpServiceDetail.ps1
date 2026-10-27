function Get-MwpServiceDetail {
    <#
    .SYNOPSIS
        Zwraca tytuł i tekst panelu szczegółów wybranej usługi w widoku Usługi (stan, typ, konto, ścieżka, opis, zależności).

    .DESCRIPTION
        Logika prezentacji bez WPF (testy Pester). Zależności pokazane, gdy odczyt je zawierał.

    .PARAMETER Service
        Usługa (MWP.Service) albo $null.

    .PARAMETER HasGraph
        Odczyt zawierał graf zależności.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [AllowNull()]
        [object] $Service,

        [bool] $HasGraph
    )

    if ($null -eq $Service) {
        return [pscustomobject]@{ Title = 'Wybierz usługę z listy.'; Text = '' }
    }
    $lines = New-Object -TypeName System.Collections.Generic.List[string]
    $lines.Add(('Stan: {0} · typ uruchomienia: {1} · konto: {2}{3}' -f $Service.StatusText, $Service.StartupTypeText,
            $(if ($Service.Account) { $Service.Account } else { '—' }), $(if ($Service.ProcessId -gt 0) { ' · PID {0}' -f $Service.ProcessId } else { '' })))
    if ($Service.Path) {
        $lines.Add(('Ścieżka: {0}' -f $Service.Path))
    }
    if ($Service.Description) {
        $lines.Add(('Opis: {0}' -f $Service.Description))
    }
    if ($HasGraph) {
        $lines.Add(('Wymaga usług: {0}' -f $(if (@($Service.DependsOn).Count -gt 0) { @($Service.DependsOn) -join ', ' } else { 'brak' })))
        $lines.Add(('Usługi zależne: {0}' -f $(if (@($Service.Dependents).Count -gt 0) { @($Service.Dependents) -join ', ' } else { 'brak' })))
    }
    [pscustomobject]@{
        Title = '{0} ({1})' -f $Service.DisplayName, $Service.Name
        Text  = $lines -join [Environment]::NewLine
    }
}
