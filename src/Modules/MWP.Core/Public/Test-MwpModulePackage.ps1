function Test-MwpModulePackage {
    <#
    .SYNOPSIS
        Sprawdza paczkę modułu .mwpmod bez instalowania jej (D-031).

    .DESCRIPTION
        Operacja klasy Odczyt. Rozpakowuje paczkę do katalogu tymczasowego, waliduje ją i usuwa
        katalog tymczasowy. Sprawdza: dokładnie jeden folder główny MWP.<Nazwa>, brak ścieżek
        wychodzących poza folder docelowy, manifest i plik .psm1, pola kontraktu, MinimumHostVersion,
        zależności oraz kolizję Id i nazwy folderu z modułem wbudowanym lub zainstalowanym.
        Zwraca dane do okna potwierdzenia: nazwę, wersję, RequiredPermissions i sumę SHA-256 paczki
        (integralność potwierdza użytkownik, porównując sumę; paczki nie są podpisywane, D-015).

    .PARAMETER Path
        Ścieżka do pliku .mwpmod.

    .PARAMETER HostVersion
        Wersja hosta do sprawdzenia MinimumHostVersion; domyślnie wersja MWP.Core.

    .EXAMPLE
        Test-MwpModulePackage -Path .\MWP.Przyklad.mwpmod | Select-Object IsValid, Name, Version, Sha256, Errors
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Path,

        [version] $HostVersion
    )

    $staging = [IO.Path]::Combine([IO.Path]::GetTempPath(), ('mwp-package-{0}' -f [guid]::NewGuid().ToString('N')))
    $arguments = @{ Path = $Path; StagingRoot = $staging }
    if ($PSBoundParameters.ContainsKey('HostVersion')) {
        $arguments['HostVersion'] = $HostVersion
    }
    try {
        $package = Read-MwpModulePackage @arguments
        $package.ExtractedPath = $null
        $package
    }
    finally {
        if ([IO.Directory]::Exists($staging)) {
            [IO.Directory]::Delete($staging, $true)
        }
    }
}
