function Resolve-MwpUpdateSearch {
    <#
    .SYNOPSIS
        Zamienia surowy wynik wyszukiwania aktualizacji (Find-MwpUpdate -AsOperation, blok Search) na obiekt MWP.UpdateSearch z listą MWP.UpdateItem.

    .DESCRIPTION
        Czysta funkcja: przyjmuje tekst JSON, MWP.Result z operacji w tle albo obiekt surowy; gotowy
        MWP.UpdateSearch jest zwracany bez zmian. Każda aktualizacja ma tytuł, numery KB, kategorie,
        rodzaj, ważność, rozmiar, informację o restarcie i o tym, czy aplikacja może ją zainstalować
        (IsInstallable: bez interakcji użytkownika i z zaakceptowaną licencją; inaczej
        NotInstallableReason i odesłanie do Ustawień). Błąd wyszukiwania: Success = $false,
        ErrorText z kodem HRESULT i opisem po polsku. Zwraca $null, gdy danych nie ma.

    .PARAMETER Type
        Rodzaj wyszukiwania (do opisu wyniku).

    .PARAMETER ComputerName
        Nazwa komputera w komunikacie (z kontekstu); domyślnie nazwa zwrócona przez komputer docelowy.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Position = 0)]
        [AllowNull()]
        [object] $Data,

        [ValidateSet('All', 'Software', 'Driver')]
        [string] $Type = 'All',

        [AllowEmptyString()]
        [string] $ComputerName = ''
    )

    if ($null -ne $Data -and $Data.PSObject.TypeNames -contains 'MWP.UpdateSearch') {
        return $Data
    }
    $raw = ConvertFrom-MwpUpdateJson -Data $Data -Kind 'MWP.UpdateSearchRaw'
    if ($null -eq $raw) {
        return $null
    }
    $updates = @(foreach ($item in @($raw.Updates | Where-Object { $null -ne $_ })) {
            $kb = @($item.KB | Where-Object { $_ } | ForEach-Object { [string]$_ })
            $categories = @($item.Categories | Where-Object { $_ } | ForEach-Object { [string]$_ })
            $reason = if ($item.CanRequestUserInput) {
                'wymaga interakcji użytkownika — zainstaluj w Ustawieniach Windows Update'
            }
            elseif (-not $item.EulaAccepted) {
                'wymaga akceptacji postanowień licencyjnych — zainstaluj w Ustawieniach Windows Update'
            }
            else {
                ''
            }
            [pscustomobject]@{
                PSTypeName           = 'MWP.UpdateItem'
                UpdateId             = [string]$item.UpdateId
                Revision             = [int]$item.Revision
                Title                = [string]$item.Title
                Description          = [string]$item.Description
                KB                   = $kb
                KBText               = ($kb -join ', ')
                Categories           = $categories
                CategoryText         = ($categories -join ', ')
                Type                 = [int]$item.Type
                TypeText             = Get-MwpUpdateText -Kind UpdateType -Value $item.Type
                Severity             = [string]$item.Severity
                SeverityText         = Get-MwpUpdateText -Kind Severity -Value $item.Severity
                SizeBytes            = [double]$item.MaxDownloadSize
                SizeText             = Format-MwpUpdateSize -Bytes $item.MaxDownloadSize
                IsDownloaded         = [bool]$item.IsDownloaded
                IsMandatory          = [bool]$item.IsMandatory
                EulaAccepted         = [bool]$item.EulaAccepted
                RebootBehavior       = [int]$item.RebootBehavior
                RebootText           = Get-MwpUpdateText -Kind RebootBehavior -Value $item.RebootBehavior
                CanRequestUserInput  = [bool]$item.CanRequestUserInput
                IsInstallable        = $reason -eq ''
                NotInstallableReason = $reason
                Published            = ConvertFrom-MwpUpdateDate -Value $item.Published
                SupportUrl           = [string]$item.SupportUrl
            }
        })

    $errorText = $null
    if ($raw.Error) {
        $hint = Get-MwpUpdateText -Kind HResult -Value $raw.HResult
        $errorText = if ($hint) { '{0} ({1}: {2})' -f $raw.Error, $raw.HResult, $hint } else { '{0} ({1})' -f $raw.Error, $raw.HResult }
    }
    $computer = if ($ComputerName) { $ComputerName } else { [string]$raw.ComputerName }
    $success = $null -eq $errorText
    $message = if (-not $success) {
        "Wyszukiwanie aktualizacji na komputerze '{0}' nie powiodło się: {1}" -f $computer, $errorText
    }
    elseif ($updates.Count -eq 0) {
        "Brak oczekujących aktualizacji na komputerze '{0}'." -f $computer
    }
    else {
        "Znaleziono {0} oczekujących aktualizacji na komputerze '{1}' (łącznie do {2})." -f $updates.Count, $computer, (Format-MwpUpdateSize -Bytes (($updates | Measure-Object -Property SizeBytes -Sum).Sum))
    }

    [pscustomobject]@{
        PSTypeName      = 'MWP.UpdateSearch'
        Kind            = 'MWP.UpdateSearch'
        ComputerName    = $computer
        CollectedAt     = ConvertFrom-MwpUpdateDate -Value $raw.CollectedAt
        IsAdministrator = $raw.IsAdministrator
        Type            = $Type
        Criteria        = [string]$raw.Criteria
        Success         = $success
        Updates         = @($updates | Sort-Object -Property @{ Expression = 'Type' }, @{ Expression = 'Title' })
        Count           = $updates.Count
        HResult         = [string]$raw.HResult
        ErrorText       = $errorText
        Message         = $message
    }
}
