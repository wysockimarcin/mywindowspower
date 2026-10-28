function Get-MwpNetAdapterStatusText {
    <#
    .SYNOPSIS
        Zwraca polski opis stanu adaptera sieciowego (Up, Disconnected, Disabled, Not Present).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [string] $Status
    )

    switch ([string]$Status) {
        'Up' { 'Połączony' }
        'Disconnected' { 'Rozłączony' }
        'Disabled' { 'Wyłączony' }
        'Not Present' { 'Brak urządzenia' }
        default { [string]$Status }
    }
}
