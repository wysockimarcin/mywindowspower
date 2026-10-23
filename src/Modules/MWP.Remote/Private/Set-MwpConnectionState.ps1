function Set-MwpConnectionState {
    <#
    .SYNOPSIS
        Zmienia stan obiektu połączenia (MWP.Connection) kontekstu wykonania.

    .DESCRIPTION
        Stany (D-019): Connected, Connecting, Disconnected, Unauthorized, Error. Obiekt połączenia
        jest jedynym zmiennym elementem kontekstu i należy do jednej instancji; zmiana stanu nie
        wpływa na inne konteksty.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Zmienia tylko obiekt w pamięci; nie zmienia stanu systemu.')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSTypeName('MWP.Connection')]
        [object] $Connection,

        [Parameter(Mandatory)]
        [ValidateSet('Connected', 'Connecting', 'Disconnected', 'Unauthorized', 'Error')]
        [string] $State,

        [AllowNull()]
        [string] $ErrorKind,

        [AllowNull()]
        [string] $ErrorMessage
    )

    $Connection.State = $State
    $Connection.ErrorKind = $(if ([string]::IsNullOrEmpty($ErrorKind)) { $null } else { $ErrorKind })
    $Connection.LastError = $(if ([string]::IsNullOrEmpty($ErrorMessage)) { $null } else { $ErrorMessage })
    $Connection.StateChangedAt = Get-Date
}
