function Get-MwpUpdateActionState {
    <#
    .SYNOPSIS
        Wylicza dostępność przycisków widoku Windows Update i treść okna potwierdzenia instalacji.

    .DESCRIPTION
        Czysta funkcja (bez WPF). Instalacja (D-048): tylko komputer lokalny, administrator, zaznaczone
        aktualizacje, które aplikacja może zainstalować (IsInstallable); pozostałe zaznaczone są
        wymienione jako pominięte. Pauza, wznowienie i reset: administrator na komputerze docelowym
        (ostatni odczyt stanu), brak trwającego zadania. Reguły i tak egzekwują funkcje MWP.Update.

    .PARAMETER Status
        MWP.UpdateStatus (ostatni odczyt) albo $null.

    .PARAMETER Search
        MWP.UpdateSearch (ostatnie wyszukiwanie) albo $null.

    .PARAMETER SelectedId
        UpdateId zaznaczonych wierszy.

    .PARAMETER IsLocal
        Instancja dotyczy komputera lokalnego.

    .PARAMETER Ready
        Połączono i nie trwa żadne zadanie widoku ani zmiana.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [AllowNull()]
        [object] $Status,

        [AllowNull()]
        [object] $Search,

        [AllowEmptyCollection()]
        [string[]] $SelectedId = @(),

        [bool] $IsLocal = $true,

        [bool] $Ready = $true
    )

    $administrator = $null -ne $Status -and $false -ne $Status.IsAdministrator
    $byId = @{}
    if ($null -ne $Search) {
        foreach ($update in @($Search.Updates)) {
            $byId[[string]$update.UpdateId] = $update
        }
    }
    $selected = @(foreach ($id in $SelectedId) { if ($byId.ContainsKey($id)) { $byId[$id] } })
    $installable = @($selected | Where-Object { $_.IsInstallable })
    $skipped = @($selected | Where-Object { -not $_.IsInstallable })

    $blocked = if (-not $IsLocal) {
        'Instalacja na komputerze zdalnym jest niedostępna (Windows Update Agent blokuje ją w sesji zdalnej, D-048) — zainstaluj aktualizacje w Ustawieniach na tamtym komputerze.'
    }
    elseif ($null -ne $Status -and $false -eq $Status.IsAdministrator) {
        'Instalacja wymaga uprawnień administratora (uruchom aplikację jako administrator).'
    }
    else {
        ''
    }

    $selectionText = if ($selected.Count -eq 0) {
        $(if ($null -ne $Search -and $Search.Count -gt 0) { 'Zaznacz aktualizacje do instalacji.' } else { '' })
    }
    else {
        $size = 0
        foreach ($update in $installable) { $size += [double]$update.SizeBytes }
        'Zaznaczono {0} (do instalacji: {1}{2}).' -f $selected.Count, $installable.Count, $(if ($size -gt 0) { ', do ' + (Format-MwpUpdateSize -Bytes $size) } else { '' })
    }
    if ($blocked) {
        $selectionText = (@($selectionText, $blocked) | Where-Object { $_ }) -join ' '
    }

    $lines = New-Object -TypeName System.Collections.Generic.List[string]
    foreach ($update in $installable) {
        $parts = @($update.KBText, $update.SizeText, $(if ($update.RebootBehavior -ge 1) { 'może wymagać restartu' } else { '' })) | Where-Object { $_ }
        $lines.Add(('{0}{1}' -f $update.Title, $(if (@($parts).Count -gt 0) { ' (' + (@($parts) -join ', ') + ')' } else { '' })))
    }
    foreach ($update in $skipped) {
        $lines.Add(('Pominięta: {0} — {1}' -f $update.Title, $update.NotInstallableReason))
    }

    [pscustomobject]@{
        PSTypeName       = 'MWP.UpdateActionState'
        IsAdministrator  = $administrator
        CanRefresh       = $Ready
        CanSearch        = $Ready
        CanInstall       = $Ready -and $IsLocal -and $administrator -and $installable.Count -gt 0
        CanOpenSettings  = $IsLocal
        CanPause         = $Ready -and $administrator
        CanResume        = $Ready -and $administrator -and $null -ne $Status -and [bool]$Status.Pause.HasValues
        CanReset         = $Ready -and $administrator
        Selected         = $selected
        Installable      = $installable
        Skipped          = $skipped
        SelectionText    = $selectionText
        InstallBlocked   = $blocked
        PreviewLine      = $lines.ToArray()
    }
}
