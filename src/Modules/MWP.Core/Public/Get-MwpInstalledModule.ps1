function Get-MwpInstalledModule {
    <#
    .SYNOPSIS
        Zwraca rejestr modułów zainstalowanych z paczek .mwpmod (D-031).

    .DESCRIPTION
        Rejestr jest w ustawieniach lokalnych (klucz installedModules w settings.local.json):
        Id, nazwa folderu, wersja, data instalacji i suma SHA-256 paczki. Pole Present mówi,
        czy folder modułu nadal istnieje (w katalogu danych albo w dawnym src\Modules\Installed, D-038).

    .PARAMETER Id
        Filtr po Id modułu (symbole wieloznaczne dozwolone).

    .EXAMPLE
        Get-MwpInstalledModule | Format-Table Id, Version, InstalledAt, Present
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Id = '*'
    )

    $moduleRoot = Get-MwpModuleRoot
    $roots = @($moduleRoot.Installed)
    if ($null -ne $moduleRoot.PSObject.Properties['Legacy']) {
        $roots += $moduleRoot.Legacy
    }
    foreach ($entry in @(Get-MwpInstalledModuleEntry)) {
        if ([string]$entry['id'] -notlike $Id) {
            continue
        }
        $moduleName = [string]$entry['moduleName']
        # Moduł z katalogu danych albo jeszcze nieprzeniesiony z dawnego src\Modules\Installed (D-038).
        $installedRoot = $roots[0]
        foreach ($root in $roots) {
            if (-not [string]::IsNullOrEmpty($moduleName) -and (Test-Path -LiteralPath (Join-Path -Path $root -ChildPath $moduleName) -PathType Container)) {
                $installedRoot = $root
                break
            }
        }
        [pscustomobject]@{
            PSTypeName  = 'MWP.InstalledModule'
            Id          = [string]$entry['id']
            ModuleName  = $moduleName
            Version     = [string]$entry['version']
            InstalledAt = ConvertTo-MwpDateTime -Value $entry['installedAt']
            Sha256      = [string]$entry['sha256']
            Path        = Join-Path -Path $installedRoot -ChildPath $moduleName
            Present     = -not [string]::IsNullOrEmpty($moduleName) -and (Test-Path -LiteralPath (Join-Path -Path $installedRoot -ChildPath $moduleName) -PathType Container)
        }
    }
}
