function Move-MwpDirectory {
    <#
    .SYNOPSIS
        Przenosi katalog jedną operacją systemu plików (atomowo w obrębie jednego woluminu).

    .DESCRIPTION
        Metoda .NET zamiast Move-Item: brak wzorców w ścieżkach i jeden krok, który albo się udaje,
        albo nic nie zmienia. Instalacja i odinstalowanie modułów (D-031) przenoszą katalogi tylko
        w obrębie src\Modules\Installed, więc źródło i cel są na tym samym woluminie.
        Testy podmieniają tę funkcję, żeby zasymulować błąd w trakcie instalacji.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Funkcja wewnętrzna; potwierdzenie i podgląd obsługuje funkcja publiczna, która ją wywołuje.')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Path,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Destination
    )

    [IO.Directory]::Move($Path, $Destination)
}
