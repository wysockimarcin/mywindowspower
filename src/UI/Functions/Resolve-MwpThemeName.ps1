function Resolve-MwpThemeName {
    <#
    .SYNOPSIS
        Wyznacza motyw okna (Light albo Dark) z ustawienia theme i motywu systemu.

    .DESCRIPTION
        Ustawienie theme (D-004): System (domyślnie, zgodnie z Windows), Light, Dark. Nieznana wartość
        działa jak System.

    .PARAMETER Setting
        Wartość ustawienia theme.

    .PARAMETER SystemTheme
        Motyw systemu (Get-MwpSystemTheme).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [string] $Setting,

        [ValidateSet('Light', 'Dark')]
        [string] $SystemTheme = 'Light'
    )

    switch ($Setting) {
        'Light' { return 'Light' }
        'Dark' { return 'Dark' }
        default { return $SystemTheme }
    }
}
