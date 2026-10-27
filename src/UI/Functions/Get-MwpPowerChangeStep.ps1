function Get-MwpPowerChangeStep {
    <#
    .SYNOPSIS
        Zamienia wybory w widoku Zasilanie (listy AC/DC, hibernacja, szybkie uruchamianie) na kroki zmian dla funkcji MWP.Power.

    .DESCRIPTION
        Logika prezentacji bez WPF (testy Pester). Porównuje wybór z odczytanym stanem i zwraca
        tylko różnice, każdą jako krok { Command; Parameters; Label } — wykonywany najpierw
        z -WhatIf (podgląd w oknie potwierdzenia), potem naprawdę (Invoke-MwpUiInstanceChange).
        Zmiany ustawień dotyczą planu aktywnego z odczytu (jego GUID trafia do parametrów, żeby
        zmiana i cofnięcie dotyczyły tego samego planu).

    .PARAMETER Status
        Stan zasilania (MWP.PowerStatus).

    .PARAMETER Selection
        Tabela: '<Id ustawienia>|AC' i '<Id ustawienia>|DC' → wartość; 'Hibernate', 'FastStartup' → bool.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object] $Status,

        [Parameter(Mandatory)]
        [hashtable] $Selection
    )

    if ($null -eq $Status) {
        return
    }
    $planGuid = if ($null -ne $Status.ActivePlan) { [string]$Status.ActivePlan.Guid } else { $null }
    foreach ($setting in @($Status.Settings | Where-Object { $null -ne $_ -and $_.Available })) {
        foreach ($source in 'AC', 'DC') {
            $key = '{0}|{1}' -f $setting.Id, $source
            if (-not $Selection.ContainsKey($key) -or $null -eq $Selection[$key]) {
                continue
            }
            $current = if ($source -eq 'AC') { $setting.Ac } else { $setting.Dc }
            $wanted = [long]$Selection[$key]
            if ($null -ne $current -and [long]$current -eq $wanted) {
                continue
            }
            $parameters = @{ Setting = $setting.Id; PowerSource = $source; Value = [int]$wanted }
            if ($planGuid) {
                $parameters['PlanGuid'] = $planGuid
            }
            @{ Command = 'Set-MwpPowerSetting'; Parameters = $parameters; Label = '{0} ({1})' -f $setting.Label, $(if ($source -eq 'AC') { 'sieć' } else { 'bateria' }) }
        }
    }
    foreach ($item in @(
            @{ Key = 'Hibernate'; Command = 'Set-MwpHibernation'; Label = 'Hibernacja' }
            @{ Key = 'FastStartup'; Command = 'Set-MwpFastStartup'; Label = 'Szybkie uruchamianie' }
        )) {
        if (-not $Selection.ContainsKey($item.Key) -or $null -eq $Selection[$item.Key]) {
            continue
        }
        $current = $Status.($item.Key)
        $wanted = [bool]$Selection[$item.Key]
        if ($null -ne $current -and [bool]$current -eq $wanted) {
            continue
        }
        @{ Command = $item.Command; Parameters = @{ Enabled = $wanted }; Label = $item.Label }
    }
}
