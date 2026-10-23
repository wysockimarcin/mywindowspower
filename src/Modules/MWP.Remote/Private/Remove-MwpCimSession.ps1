function Remove-MwpCimSession {
    <#
    .SYNOPSIS
        Adapter transportu: zamyka sesję CIM; błąd zamykania nie jest zgłaszany dalej.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Zamyka połączenie; nie zmienia stanu systemu.')]
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object] $CimSession
    )

    if ($null -ne $CimSession) {
        Remove-CimSession -CimSession $CimSession -ErrorAction SilentlyContinue
    }
}
