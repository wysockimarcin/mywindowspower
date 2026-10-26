function Copy-MwpDirectory {
    <#
    .SYNOPSIS
        Kopiuje katalog rekurencyjnie (także między woluminami) metodami .NET.

    .DESCRIPTION
        Bez wzorców w ścieżkach (nawiasy [ ], spacje, polskie znaki, UNC). Katalog docelowy nie może
        istnieć. Zwraca liczbę skopiowanych plików. Używają jej Move-MwpDataDirectory
        i Move-MwpInstalledModule (D-038): kopia powstaje w katalogu roboczym, a dopiero po udanym
        skopiowaniu całości jest przenoszona na miejsce, więc błąd nie zostawia danych w połowie.
        Testy podmieniają tę funkcję, żeby zasymulować błąd w trakcie kopiowania.
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Path,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Destination
    )

    if ([IO.Directory]::Exists($Destination)) {
        throw ("Katalog docelowy '{0}' już istnieje." -f $Destination)
    }
    $count = 0
    $null = [IO.Directory]::CreateDirectory($Destination)
    foreach ($directory in [IO.Directory]::GetDirectories($Path, '*', [IO.SearchOption]::AllDirectories)) {
        $relative = $directory.Substring($Path.TrimEnd([char]92).Length + 1)
        $null = [IO.Directory]::CreateDirectory([IO.Path]::Combine($Destination, $relative))
    }
    foreach ($file in [IO.Directory]::GetFiles($Path, '*', [IO.SearchOption]::AllDirectories)) {
        $relative = $file.Substring($Path.TrimEnd([char]92).Length + 1)
        [IO.File]::Copy($file, [IO.Path]::Combine($Destination, $relative), $false)
        $count++
    }
    $count
}
