function Get-MwpConnectionStateInfo {
    <#
    .SYNOPSIS
        Zwraca opis stanu połączenia kontekstu wykonania do wyświetlenia (etykieta, ton, szczegóły).

    .DESCRIPTION
        Prezentacja stanu z Context.Connection (D-035): Connected, Connecting, Disconnected,
        Unauthorized, Error; komputer lokalny zawsze „Lokalnie". Ton (Success, Info, Warning, Danger,
        Neutral) wybiera kolor plakietki w widoku. NeedsCredential mówi, że przed połączeniem trzeba
        zapytać o poświadczenia (uwierzytelnienie Credential bez hasła w pamięci albo
        ErrorKind = CredentialRequired). Funkcja tylko czyta kontekst.

    .PARAMETER Context
        Kontekst wykonania instancji (MWP.ExecutionContext).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [PSTypeName('MWP.ExecutionContext')]
        [object] $Context
    )

    $connection = $Context.Connection
    $state = [string]$connection.State
    $errorKind = [string]$connection.ErrorKind
    $label, $tone = switch ($state) {
        'Connected' { 'Połączono', 'Success' }
        'Connecting' { 'Łączenie…', 'Info' }
        'Disconnected' { 'Rozłączono', 'Neutral' }
        'Unauthorized' { 'Brak dostępu', 'Warning' }
        'Error' { 'Błąd połączenia', 'Danger' }
        default { $state, 'Neutral' }
    }
    if ($Context.Mode -eq 'Local') {
        $label = 'Lokalnie'
        $tone = 'Success'
    }
    elseif ($errorKind -eq 'CredentialRequired') {
        $label = 'Wymaga poświadczeń'
    }

    $hasCredential = $false
    if ($null -ne $connection.PSObject.Properties['Credential']) {
        $hasCredential = $null -ne $connection.Credential
    }
    $missingCredential = -not $hasCredential -or $errorKind -eq 'CredentialRequired'
    $needsCredential = $Context.Mode -eq 'Remote' -and $Context.Identity.Authentication -eq 'Credential' -and $missingCredential

    [pscustomobject]@{
        PSTypeName      = 'MWP.UiConnectionState'
        State           = $state
        Label           = $label
        Tone            = $tone
        ErrorKind       = $(if ($errorKind) { $errorKind } else { $null })
        Detail          = $(if ($state -in @('Unauthorized', 'Error', 'Disconnected') -and $connection.LastError) { [string]$connection.LastError } else { $null })
        ChangedAt       = $connection.StateChangedAt
        IsRemote        = $Context.Mode -eq 'Remote'
        NeedsCredential = $needsCredential
    }
}
