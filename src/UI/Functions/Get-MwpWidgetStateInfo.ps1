function Get-MwpWidgetStateInfo {
    <#
    .SYNOPSIS
        Zwraca opis stanu widgetu do plakietki (etykieta i ton koloru).

    .PARAMETER Status
        Idle, Loading, Ready, NoData, Error, ConnectionLost, NeedsCredential.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [AllowEmptyString()]
        [string] $Status
    )

    $label, $tone = switch ($Status) {
        'Loading' { 'Ładowanie…', 'Info' }
        'Ready' { 'Aktualne', 'Success' }
        'NoData' { 'Brak danych', 'Neutral' }
        'Error' { 'Błąd', 'Danger' }
        'ConnectionLost' { 'Utrata połączenia', 'Warning' }
        'NeedsCredential' { 'Wymaga poświadczeń', 'Warning' }
        default { 'Oczekuje', 'Neutral' }
    }
    [pscustomobject]@{
        PSTypeName = 'MWP.UiWidgetState'
        Status     = $Status
        Label      = $label
        Tone       = $tone
    }
}
