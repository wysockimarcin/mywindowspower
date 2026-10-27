function Get-MwpWidgetStatus {
    <#
    .SYNOPSIS
        Ustala stan widgetu po odświeżeniu na podstawie wyniku operacji (MWP.Result) i stanu zadania.

    .DESCRIPTION
        Stany widgetu (D-043): Ready (są dane), NoData (operacja się udała, ale nie zwróciła danych),
        Error (błąd danych lub programu), ConnectionLost (komputer niedostępny, utrata połączenia,
        brak odpowiedzi w limicie czasu), NeedsCredential (brak poświadczeń albo odmowa dostępu),
        Cancelled (anulowano odświeżanie). Klasyfikacja błędu pochodzi z Data.ErrorKind wyniku
        operacji (Wait-MwpOperation, Start-MwpOperation). Zwraca obiekt: Status, Message.

    .PARAMETER Result
        Wynik operacji (MWP.Result) albo $null.

    .PARAMETER TaskStatus
        Stan zadania GUI: Completed, Failed, Cancelled.

    .PARAMETER TaskError
        Komunikat błędu zadania (gdy brak wyniku).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [AllowNull()]
        [object] $Result,

        [AllowEmptyString()]
        [string] $TaskStatus = 'Completed',

        [AllowNull()]
        [AllowEmptyString()]
        [string] $TaskError
    )

    $status = {
        param([string] $Status, [string] $Message)
        [pscustomobject]@{ Status = $Status; Message = $Message }
    }
    if ($TaskStatus -eq 'Cancelled') {
        return & $status 'Cancelled' 'Anulowano odświeżanie.'
    }
    if ($null -eq $Result) {
        return & $status 'Error' $(if ($TaskError) { $TaskError } else { 'Odświeżanie nie zwróciło wyniku.' })
    }
    if ($Result.Success) {
        $data = @($Result.Data | Where-Object { $null -ne $_ -and -not ($_ -is [string] -and [string]::IsNullOrWhiteSpace($_)) })
        if ($data.Count -eq 0) {
            return & $status 'NoData' 'Komputer nie zwrócił danych.'
        }
        return & $status 'Ready' $null
    }

    $kind = $null
    if ($Result.Data -is [Collections.IDictionary] -and $Result.Data.Contains('ErrorKind')) {
        $kind = [string]$Result.Data['ErrorKind']
    }
    $message = [string]$Result.Message
    switch ($kind) {
        { $_ -in @('Unauthorized', 'CredentialRequired') } { return & $status 'NeedsCredential' $message }
        { $_ -in @('Network', 'Timeout', 'ConnectionLost') } { return & $status 'ConnectionLost' $message }
    }
    & $status 'Error' $message
}
