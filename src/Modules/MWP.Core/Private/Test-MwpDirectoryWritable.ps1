function Test-MwpDirectoryWritable {
    <#
    .SYNOPSIS
        Sprawdza, czy w katalogu da się zapisywać: tworzy go w razie potrzeby, potem tworzy i usuwa plik próbny.

    .DESCRIPTION
        Wynik jest pamiętany do końca procesu (osobno dla każdej ścieżki), żeby każdy wpis w logu
        nie tworzył pliku próbnego (np. w folderze synchronizowanym przez OneDrive). Zmiana uprawnień
        katalogu w trakcie działania wymaga ponownego uruchomienia aplikacji.

    .PARAMETER NoCreate
        Podgląd bez tworzenia katalogu i bez pamięci wyników (Get-MwpDataLocation -DataPath): gdy
        katalog nie istnieje, sprawdzany jest najbliższy istniejący katalog nadrzędny.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Path,

        [switch] $NoCreate
    )

    if ($NoCreate) {
        $existing = $Path
        while (-not [string]::IsNullOrEmpty($existing) -and -not [IO.Directory]::Exists($existing)) {
            $existing = [IO.Path]::GetDirectoryName($existing)
        }
        if ([string]::IsNullOrEmpty($existing)) {
            return $false
        }
        try {
            $probe = [IO.Path]::Combine($existing, ('.mwp-write-test-{0}.tmp' -f [guid]::NewGuid().ToString('N')))
            [IO.File]::WriteAllText($probe, '')
            [IO.File]::Delete($probe)
            return $true
        }
        catch {
            Write-Verbose ("Katalog '{0}' jest niezapisywalny: {1}" -f $existing, $_.Exception.Message)
            return $false
        }
    }

    if ($script:MwpWritableDirectoryCache.ContainsKey($Path)) {
        return $script:MwpWritableDirectoryCache[$Path]
    }

    $writable = $false
    try {
        $null = [IO.Directory]::CreateDirectory($Path)
        $probe = [IO.Path]::Combine($Path, ('.mwp-write-test-{0}.tmp' -f [guid]::NewGuid().ToString('N')))
        [IO.File]::WriteAllText($probe, '')
        [IO.File]::Delete($probe)
        $writable = $true
    }
    catch {
        Write-Verbose ("Katalog '{0}' jest niezapisywalny: {1}" -f $Path, $_.Exception.Message)
    }

    $script:MwpWritableDirectoryCache[$Path] = $writable
    $writable
}
