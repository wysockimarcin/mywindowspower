function Get-MwpConnectionStateInfo {
    <#
    .SYNOPSIS
        Zwraca opis stanu połączenia kontekstu wykonania do wyświetlenia (etykieta, ton, szczegóły).

    .DESCRIPTION
        Prezentacja stanu z Context.Connection (D-035): Connected, Connecting, Disconnected,
        Unauthorized, Error; komputer lokalny zawsze „Lokalnie". Ton (Success, Info, Warning, Danger,
        Neutral) wybiera kolor plakietki w widoku. NeedsCredential mówi, że przed połączeniem trzeba
        zapytać o poświadczenia (uwierzytelnienie Credential bez hasła w kontekście ani sprawdzonego
        hasła komputera w pamięci procesu, albo ErrorKind = CredentialRequired; D-052). Funkcja tylko
        czyta kontekst i pamięć procesu (bez Menedżera poświadczeń i bez pliku ustawień).

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
    $shared = $null -ne $connection.PSObject.Properties['CredentialShared'] -and [bool]$connection.CredentialShared
    $usesCredential = $Context.Mode -eq 'Remote' -and $Context.Identity.Authentication -eq 'Credential'
    # D-052: sprawdzone hasło komputera w pamięci procesu wystarcza każdemu kontekstowi tego komputera,
    # a hasło wspólne po odrzuceniu (Invalid) już nie — wtedy dopiero użytkownik podaje nowe.
    $cached = $false
    if ($usesCredential) {
        $info = @(Get-MwpTargetCredentialInfo -Name $Context.ComputerName -SkipStore) | Select-Object -First 1
        $cached = $null -ne $info -and [bool]$info.Cached
    }
    $own = $hasCredential -and -not $shared
    $missingCredential = -not ($own -or $cached) -or ($errorKind -eq 'CredentialRequired' -and -not $cached)
    $needsCredential = $usesCredential -and $missingCredential

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
