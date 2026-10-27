function Get-MwpStartupActionState {
    <#
    .SYNOPSIS
        Wylicza dostępność przycisków widoku Autostart i harmonogram dla wybranej pozycji autostartu albo zadania.

    .DESCRIPTION
        Logika prezentacji bez WPF (testy Pester). Pozycja autostartu: włącz/wyłącz tylko dla
        miejsc z StartupApproved (RunOnce — nie); pozycje komputera i profili innych użytkowników
        wymagają administratora. Zadanie (D-046): zmiany wymagają administratora; zadania z listy
        ochronnej (Task) nie można wyłączyć ani usunąć, zadań z folderu \Microsoft\ (TaskRemoval) —
        usunąć; zadania wyłączonego albo działającego nie można uruchomić. To blokada w GUI; funkcje
        MWP.Startup odmawiają tych zmian niezależnie (CLI, komputer zdalny). Wynik: CanEnable,
        CanDisable, CanRun, CanRemove i Note (tekst baneru albo $null).

    .PARAMETER Item
        Wybrana pozycja autostartu (MWP.StartupItem) albo $null.

    .PARAMETER Task
        Wybrane zadanie (MWP.ScheduledTask) albo $null.

    .PARAMETER Ready
        Instancja połączona, odczyt jest i nic nie trwa.

    .PARAMETER IsAdministrator
        Konto ma uprawnienia administratora na komputerze docelowym (z ostatniego odczytu).

    .PARAMETER CurrentUserSid
        SID konta, którym działa odczyt na komputerze docelowym (własny profil nie wymaga administratora).
    #>
    [CmdletBinding(DefaultParameterSetName = 'Item')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(ParameterSetName = 'Item')]
        [AllowNull()]
        [object] $Item,

        [Parameter(ParameterSetName = 'Task')]
        [AllowNull()]
        [object] $Task,

        [bool] $Ready,

        [bool] $IsAdministrator,

        [AllowNull()]
        [AllowEmptyString()]
        [string] $CurrentUserSid
    )

    $state = [ordered]@{ CanEnable = $false; CanDisable = $false; CanRun = $false; CanRemove = $false; Note = $null }
    if ($PSCmdlet.ParameterSetName -eq 'Item') {
        if ($null -eq $Item) {
            return [pscustomobject]$state
        }
        $needsAdmin = $Item.Scope -eq 'Machine' -or $Item.UserSid -ne $CurrentUserSid
        if (-not $Item.CanToggle) {
            $state.Note = 'Wpis RunOnce uruchamia się jednorazowo przy następnym logowaniu lub starcie; nie można go włączać ani wyłączać (Menedżer zadań go nie pokazuje).'
        }
        elseif ($needsAdmin -and -not $IsAdministrator) {
            $state.Note = 'Zmiana tej pozycji wymaga uprawnień administratora na tym komputerze.'
        }
        $allowed = $Ready -and $Item.CanToggle -and ($IsAdministrator -or -not $needsAdmin)
        $state.CanEnable = $allowed -and -not $Item.Enabled
        $state.CanDisable = $allowed -and $Item.Enabled
        return [pscustomobject]$state
    }

    if ($null -eq $Task) {
        return [pscustomobject]$state
    }
    $notes = New-Object -TypeName System.Collections.Generic.List[string]
    if ($Task.IsProtected) {
        $notes.Add(('Zadanie chronione — można je włączyć i uruchomić; wyłączenie i usunięcie są zablokowane. Powód: {0}' -f $Task.ProtectionReason))
    }
    elseif (-not $Task.CanRemove) {
        $notes.Add(('Usunięcie zablokowane (lista ochronna). Powód: {0}' -f $Task.RemovalReason))
    }
    if (-not $IsAdministrator) {
        $notes.Add('Zmiany zadań harmonogramu wymagają uprawnień administratora na tym komputerze.')
    }
    $allowed = $Ready -and $IsAdministrator
    $state.CanEnable = $allowed -and -not $Task.Enabled
    $state.CanDisable = $allowed -and $Task.Enabled -and -not $Task.IsProtected
    $state.CanRun = $allowed -and $Task.Enabled -and $Task.State -ne 'Running'
    $state.CanRemove = $allowed -and [bool]$Task.CanRemove
    $state.Note = $(if ($notes.Count -gt 0) { $notes -join ' ' } else { $null })
    [pscustomobject]$state
}
