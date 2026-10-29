function Get-MwpAppsHostSid {
    <#
    .SYNOPSIS
        Zwraca SID konta, na którym działa aplikacja (winget bezpośrednio na localhost działa w jego profilu).

    .DESCRIPTION
        Osobna funkcja, żeby testy mogły wskazać konto „bieżące” zgodne z atrapą inwentarza.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    [string][Security.Principal.WindowsIdentity]::GetCurrent().User.Value
}
