function Get-MwpDataLocation {
    <#
    .SYNOPSIS
        Zwraca stan katalogu danych aplikacji (logi, rejestr cofnięć, moduły z paczek) albo podgląd nowej wartości dataPath.

    .DESCRIPTION
        Publiczny odczyt stanu katalogu danych (D-032, D-038) dla GUI (Ustawienia, O programie, pasek
        stanu) i CLI; Get-MwpDataPath pozostaje wewnętrzna. Bez -DataPath opisuje bieżący katalog:
        ścieżki podkatalogów, tryb zapasowy (%LOCALAPPDATA%\MyWindowsPower) z ostrzeżeniem
        i moduły z paczek, które leżą jeszcze w dawnym src\Modules\Installed (do przeniesienia przez
        Move-MwpInstalledModule).
        Z -DataPath pokazuje, czym byłaby nowa wartość ustawienia, niczego nie tworząc i nie zapisując:
        ścieżkę wynikową, poprawność, istnienie, zapisywalność (najbliższego istniejącego katalogu)
        i to, czy w miejscu docelowym są już dane. Operacja klasy Odczyt; dotyczy tylko komputera,
        na którym działa host.

    .PARAMETER DataPath
        Proponowana wartość ustawienia dataPath (pusta = <folder aplikacji>\data, względna albo
        bezwzględna, ze zmiennymi środowiskowymi).

    .EXAMPLE
        Get-MwpDataLocation | Format-List

    .EXAMPLE
        Get-MwpDataLocation -DataPath '%USERPROFILE%\Dane MWP'
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [AllowEmptyString()]
        [AllowNull()]
        [string] $DataPath
    )

    $subdirectories = @('logs', 'undo', 'modules')
    $current = Get-MwpDataPath -Detailed
    $location = [ordered]@{
        PSTypeName     = 'MWP.DataLocation'
        IsPreview      = $PSBoundParameters.ContainsKey('DataPath')
        Configured     = $current.Configured
        Root           = $current.Root
        Logs           = $null
        Undo           = $null
        Modules        = $null
        IsValid        = $true
        Exists         = $true
        Writable       = -not $current.IsFallback
        IsFallback     = $current.IsFallback
        IsCurrent      = $true
        HasData        = $false
        Warning        = $current.Warning
        Error          = $null
        CurrentRoot    = $current.Root
        LegacyModules  = @()
        LegacyPath     = $null
    }

    if ($location.IsPreview) {
        $location.Configured = $(if ($null -eq $DataPath) { '' } else { $DataPath.Trim() })
        $location.IsFallback = $false
        $location.Warning = $null
        try {
            $location.Root = Resolve-MwpDataPath -Value $DataPath
            $location.Exists = [IO.Directory]::Exists($location.Root)
            $location.Writable = Test-MwpDirectoryWritable -Path $location.Root -NoCreate
            $location.IsCurrent = [string]::Equals($location.Root.TrimEnd([char]92), [string]$current.Root.TrimEnd([char]92), [StringComparison]::OrdinalIgnoreCase)
            if (-not $location.Writable) {
                $location.Warning = "Katalog '{0}' jest niezapisywalny; aplikacja użyłaby katalogu zapasowego." -f $location.Root
            }
        }
        catch {
            $location.Root = $null
            $location.IsValid = $false
            $location.Exists = $false
            $location.Writable = $false
            $location.IsCurrent = $false
            $location.Error = "Niepoprawny katalog danych: {0}." -f $_.Exception.Message
        }
    }

    if ($null -ne $location.Root) {
        $location.Logs = [IO.Path]::Combine($location.Root, 'logs')
        $location.Undo = [IO.Path]::Combine($location.Root, 'undo')
        $location.Modules = [IO.Path]::Combine($location.Root, 'modules')
        foreach ($name in $subdirectories) {
            $directory = [IO.Path]::Combine($location.Root, $name)
            if ([IO.Directory]::Exists($directory) -and @([IO.Directory]::GetFileSystemEntries($directory)).Count -gt 0) {
                $location.HasData = $true
            }
        }
    }

    $moduleRoot = Get-MwpModuleRoot
    $legacy = $null
    if ($null -ne $moduleRoot.PSObject.Properties['Legacy']) {
        $legacy = $moduleRoot.Legacy
    }
    $location.LegacyPath = $legacy
    if (-not [string]::IsNullOrEmpty($legacy) -and [IO.Directory]::Exists($legacy)) {
        $location.LegacyModules = @([IO.Directory]::GetDirectories($legacy, 'MWP.*') | ForEach-Object { [IO.Path]::GetFileName($_) } | Sort-Object)
    }
    [pscustomobject]$location
}
