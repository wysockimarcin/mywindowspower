function Remove-MwpPSSession {
    <#
    .SYNOPSIS
        Adapter transportu: zamyka sesję WinRM; błąd zamykania nie jest zgłaszany dalej.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Zamyka połączenie; nie zmienia stanu systemu.')]
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object] $Session
    )

    if ($null -ne $Session) {
        Remove-PSSession -Session $Session -ErrorAction SilentlyContinue
    }
}
