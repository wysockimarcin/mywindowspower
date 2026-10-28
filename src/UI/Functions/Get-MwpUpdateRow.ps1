function Get-MwpUpdateRow {
    <#
    .SYNOPSIS
        Zwraca wiersze tabel widoku Windows Update: oczekujące aktualizacje (-Search) albo historia (-History).

    .DESCRIPTION
        Czysta funkcja (bez WPF). Wiersz aktualizacji ma UpdateId (zaznaczenie po odświeżeniu), tytuł,
        KB, rodzaj, ważność, rozmiar, „Pobrana”, restart i uwagi (powód, dla którego aplikacja nie
        zainstaluje aktualizacji, albo „obowiązkowa”). Wiersz historii ma datę, operację, wynik, KB,
        tytuł i kod błędu z opisem; -FailedOnly zostawia niepowodzenia i przerwane.

    .PARAMETER Search
        MWP.UpdateSearch (Resolve-MwpUpdateSearch).

    .PARAMETER History
        MWP.UpdateHistory (Resolve-MwpUpdateHistory).

    .PARAMETER FailedOnly
        Tylko wpisy historii zakończone niepowodzeniem albo przerwane.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Search')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(ParameterSetName = 'Search')]
        [AllowNull()]
        [object] $Search,

        [Parameter(Mandatory, ParameterSetName = 'History')]
        [AllowNull()]
        [object] $History,

        [Parameter(ParameterSetName = 'History')]
        [switch] $FailedOnly
    )

    if ($PSCmdlet.ParameterSetName -eq 'History') {
        if ($null -eq $History) {
            return
        }
        foreach ($entry in @($History.Entries)) {
            if ($FailedOnly -and -not $entry.IsFailure) {
                continue
            }
            [pscustomobject]@{
                DateText      = $entry.DateText
                OperationText = $entry.OperationText
                ResultText    = $entry.ResultText
                KBText        = $entry.KBText
                Title         = $entry.Title
                ErrorText     = $(if ($entry.HResult) { (@($entry.HResult, $entry.HResultText) | Where-Object { $_ }) -join ' — ' } else { '' })
            }
        }
        return
    }
    if ($null -eq $Search) {
        return
    }
    foreach ($update in @($Search.Updates)) {
        $notes = New-Object -TypeName System.Collections.Generic.List[string]
        if (-not $update.IsInstallable) {
            $notes.Add([string]$update.NotInstallableReason)
        }
        if ($update.IsMandatory) {
            $notes.Add('obowiązkowa')
        }
        [pscustomobject]@{
            UpdateId       = $update.UpdateId
            Title          = $update.Title
            KBText         = $update.KBText
            TypeText       = $update.TypeText
            SeverityText   = $update.SeverityText
            SizeText       = $update.SizeText
            DownloadedText = $(if ($update.IsDownloaded) { 'Tak' } else { 'Nie' })
            RebootText     = $update.RebootText
            Note           = ($notes -join '; ')
        }
    }
}
