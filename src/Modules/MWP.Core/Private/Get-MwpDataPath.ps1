function Get-MwpDataPath {
    <#
    .SYNOPSIS
        Zwraca katalog danych aplikacji w %LOCALAPPDATA%\MyWindowsPower (logi, rejestr cofnięć).

    .DESCRIPTION
        Jedyne miejsce, które zna położenie danych lokalnych. Testy podmieniają tę funkcję mockiem,
        żeby nie pisać do prawdziwego profilu użytkownika.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [ValidateSet('Root', 'Logs', 'Undo')]
        [string] $Kind = 'Root'
    )

    $base = $env:LOCALAPPDATA
    if ([string]::IsNullOrEmpty($base)) {
        throw 'Zmienna środowiskowa LOCALAPPDATA nie jest ustawiona.'
    }

    $root = Join-Path -Path $base -ChildPath 'MyWindowsPower'
    if ($Kind -eq 'Root') {
        return $root
    }
    Join-Path -Path $root -ChildPath $Kind.ToLowerInvariant()
}
