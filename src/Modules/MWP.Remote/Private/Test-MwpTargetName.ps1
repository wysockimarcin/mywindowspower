function Test-MwpTargetName {
    <#
    .SYNOPSIS
        Sprawdza, czy tekst jest poprawną nazwą komputera (nazwa NetBIOS/DNS albo adres IPv4).

    .DESCRIPTION
        Nazwa trafia do poleceń WinRM i CIM jako osobny parametr, nigdy przez sklejanie poleceń
        (D-015); walidacja odrzuca m.in. spacje, ukośniki, symbole wieloznaczne i średniki.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [AllowEmptyString()]
        [string] $Name
    )

    $Name.Length -le 253 -and $Name -match '^[A-Za-z0-9](?:[A-Za-z0-9-]{0,62})(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,62}))*$'
}
