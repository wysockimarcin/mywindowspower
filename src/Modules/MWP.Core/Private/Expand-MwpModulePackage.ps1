function Expand-MwpModulePackage {
    <#
    .SYNOPSIS
        Sprawdza budowę archiwum paczki .mwpmod i rozpakowuje je do katalogu roboczego.

    .DESCRIPTION
        Najpierw sprawdzane są wszystkie wpisy archiwum, dopiero potem cokolwiek trafia na dysk
        (D-031): żadna ścieżka nie może być bezwzględna, zawierać '..' ani wychodzić poza katalog
        docelowy; archiwum ma dokładnie jeden folder główny MWP.<Nazwa> i żadnych plików poza nim.
        Rozpakowanie odbywa się wpis po wpisie metodami .NET (bez wzorców w ścieżkach).
        Funkcja nie usuwa katalogu docelowego; sprząta wywołujący.

    .OUTPUTS
        Obiekt z polami Errors (lista komunikatów), ModuleName, ModulePath (rozpakowany folder modułu).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Path,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Destination
    )

    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem

    $errors = New-Object -TypeName System.Collections.Generic.List[string]
    $result = [pscustomobject]@{ Errors = $errors; ModuleName = $null; ModulePath = $null }

    $destinationRoot = [IO.Path]::GetFullPath($Destination).TrimEnd('\')
    $archive = $null
    try {
        $archive = [IO.Compression.ZipFile]::OpenRead($Path)
    }
    catch {
        $errors.Add(("Plik nie jest poprawnym archiwum ZIP: {0}" -f $_.Exception.Message))
        return $result
    }

    try {
        $entries = @($archive.Entries)
        if ($entries.Count -eq 0) {
            $errors.Add('Archiwum jest puste.')
            return $result
        }

        $rootNames = New-Object -TypeName 'System.Collections.Generic.HashSet[string]' -ArgumentList ([StringComparer]::OrdinalIgnoreCase)
        $planned = New-Object -TypeName System.Collections.Generic.List[object]
        foreach ($entry in $entries) {
            $name = $entry.FullName.Replace('\', '/')
            $segments = @($name.Split('/') | Where-Object { $_ -ne '' })
            if ($name -match '^(?:[A-Za-z]:|/)') {
                $errors.Add(("Wpis '{0}' ma ścieżkę bezwzględną." -f $entry.FullName))
                continue
            }
            if ($segments -contains '..' -or $segments.Count -eq 0) {
                $errors.Add(("Wpis '{0}' wychodzi poza folder docelowy." -f $entry.FullName))
                continue
            }
            $target = [IO.Path]::GetFullPath([IO.Path]::Combine($destinationRoot, ($segments -join '\')))
            if (-not $target.StartsWith($destinationRoot + '\', [StringComparison]::OrdinalIgnoreCase)) {
                $errors.Add(("Wpis '{0}' wychodzi poza folder docelowy." -f $entry.FullName))
                continue
            }
            $isDirectory = $name.EndsWith('/')
            if ($segments.Count -eq 1 -and -not $isDirectory) {
                $errors.Add(("Plik '{0}' leży poza folderem głównym modułu." -f $entry.FullName))
                continue
            }
            $null = $rootNames.Add($segments[0])
            $planned.Add([pscustomobject]@{ Entry = $entry; Target = $target; IsDirectory = $isDirectory })
        }

        if ($rootNames.Count -ne 1) {
            $errors.Add(("Archiwum musi mieć dokładnie jeden folder główny MWP.<Nazwa>; znaleziono {0}: {1}." -f
                    $rootNames.Count, (@($rootNames) -join ', ')))
        }
        else {
            $rootName = @($rootNames)[0]
            if ($rootName -notmatch '^MWP\.[A-Za-z][A-Za-z0-9]*$') {
                $errors.Add(("Folder główny '{0}' nie ma nazwy MWP.<Nazwa> (litery i cyfry)." -f $rootName))
            }
            $result.ModuleName = $rootName
        }
        if ($errors.Count -gt 0) {
            return $result
        }

        $null = [IO.Directory]::CreateDirectory($destinationRoot)
        foreach ($item in $planned) {
            if ($item.IsDirectory) {
                $null = [IO.Directory]::CreateDirectory($item.Target)
                continue
            }
            $null = [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($item.Target))
            [IO.Compression.ZipFileExtensions]::ExtractToFile($item.Entry, $item.Target, $false)
        }
        $result.ModulePath = [IO.Path]::Combine($destinationRoot, $result.ModuleName)
        $result
    }
    finally {
        $archive.Dispose()
    }
}
