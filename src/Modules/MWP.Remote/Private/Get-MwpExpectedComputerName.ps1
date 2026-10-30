function Get-MwpExpectedComputerName {
    <#
    .SYNOPSIS
        Zwraca nazwę, którą musi zgłosić komputer zdalny po połączeniu (pierwszy człon nazwy), albo '' bez weryfikacji.

    .DESCRIPTION
        D-054: nazwa komputera w rejestrze (Name) jest porównywana bez rozróżniania wielkości liter
        z nazwą zgłoszoną przez komputer — pierwszy człon przed kropką, więc FQDN (pc.firma.local)
        i nazwa krótka są zgodne. Gdy Name jest adresem IPv4 (wpisy sprzed D-054), nie ma z czym
        porównać: zwraca '' (bez weryfikacji, jak przed korektą).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [string] $Name
    )

    if ([string]::IsNullOrEmpty($Name) -or (Test-MwpIPv4Address -Value $Name)) {
        return ''
    }
    $Name.Split('.')[0]
}
