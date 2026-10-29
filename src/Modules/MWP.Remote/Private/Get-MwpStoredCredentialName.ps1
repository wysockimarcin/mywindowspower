function Get-MwpStoredCredentialName {
    <#
    .SYNOPSIS
        Zwraca nazwę wpisu Menedżera poświadczeń Windows dla komputera docelowego: MWP:<nazwa>.

    .DESCRIPTION
        Jeden wpis na komputer (decyzja użytkownika, D-052), niezależnie od modułu, instancji, portu
        i HTTPS: konto dotyczy komputera, a nazwa w rejestrze komputerów jest unikalna i nie zmienia
        się (D-041). Menedżer poświadczeń porównuje nazwy bez rozróżniania wielkości liter. Prefiks
        MWP: odróżnia wpisy aplikacji od wpisów RDP (TERMSRV/…), których aplikacja nie tworzy.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $ComputerName
    )

    'MWP:{0}' -f $ComputerName.Trim()
}
