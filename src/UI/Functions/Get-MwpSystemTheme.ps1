function Get-MwpSystemTheme {
    <#
    .SYNOPSIS
        Zwraca motyw aplikacji ustawiony w systemie Windows: Light albo Dark.

    .DESCRIPTION
        Czyta wartość AppsUseLightTheme z HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize
        (0 = ciemny, 1 = jasny). Brak wartości lub błąd odczytu oznacza motyw jasny. Operacja klasy
        Odczyt; dotyczy komputera, na którym działa host (wygląd okna, nie komputer docelowy).

    .PARAMETER RegistryPath
        Ścieżka klucza (do testów).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [ValidateNotNullOrEmpty()]
        [string] $RegistryPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
    )

    try {
        $value = Get-ItemPropertyValue -LiteralPath $RegistryPath -Name 'AppsUseLightTheme' -ErrorAction Stop
        if ([int]$value -eq 0) {
            return 'Dark'
        }
    }
    catch {
        Write-Verbose ("Brak ustawienia motywu systemu: {0}" -f $_.Exception.Message)
    }
    'Light'
}
