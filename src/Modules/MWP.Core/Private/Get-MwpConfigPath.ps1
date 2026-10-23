function Get-MwpConfigPath {
    <#
    .SYNOPSIS
        Zwraca ścieżki szablonu ustawień (repozytorium) i ustawień lokalnych (poza repozytorium).

    .DESCRIPTION
        Ustawienia lokalne leżą w <folder aplikacji>\config\settings.local.json. Tryb zapasowy (D-032):
        gdy tego pliku nie ma, a istnieje %LOCALAPPDATA%\MyWindowsPower\settings.local.json, używany
        jest ten drugi; z -ForWrite także wtedy, gdy katalog config jest niezapisywalny. Odczyt nie
        sprawdza zapisywalności (nie tworzy plików próbnych w folderze aplikacji).

    .PARAMETER ForWrite
        Ścieżka do zapisu: sprawdza zapisywalność katalogu config, gdy pliku lokalnego jeszcze nie ma.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [switch] $ForWrite
    )

    $configDirectory = Join-Path -Path (Get-MwpProjectRoot) -ChildPath 'config'
    $local = Join-Path -Path $configDirectory -ChildPath 'settings.local.json'
    $isFallback = $false
    if (-not (Test-Path -LiteralPath $local)) {
        $fallbackLocal = $null
        try {
            $fallbackLocal = [IO.Path]::Combine((Get-MwpDataPath -Kind Fallback), 'settings.local.json')
        }
        catch {
            Write-Verbose ("Brak katalogu zapasowego ustawień: {0}" -f $_.Exception.Message)
        }
        if ($null -ne $fallbackLocal -and
            ((Test-Path -LiteralPath $fallbackLocal) -or ($ForWrite -and -not (Test-MwpDirectoryWritable -Path $configDirectory)))) {
            $local = $fallbackLocal
            $isFallback = $true
        }
    }

    [pscustomobject]@{
        Example    = Join-Path -Path $configDirectory -ChildPath 'settings.example.json'
        Local      = $local
        IsFallback = $isFallback
    }
}
