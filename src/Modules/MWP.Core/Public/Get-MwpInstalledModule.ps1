function Get-MwpInstalledModule {
    <#
    .SYNOPSIS
        Zwraca rejestr modułów zainstalowanych z paczek .mwpmod (D-031).

    .DESCRIPTION
        Rejestr jest w ustawieniach lokalnych (klucz installedModules w settings.local.json):
        Id, nazwa folderu, wersja, data instalacji i suma SHA-256 paczki. Pole Present mówi,
        czy folder modułu nadal istnieje w src\Modules\Installed.

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

    $installedRoot = (Get-MwpModuleRoot).Installed
    foreach ($entry in @(Get-MwpInstalledModuleEntry)) {
        if ([string]$entry['id'] -notlike $Id) {
            continue
        }
        $moduleName = [string]$entry['moduleName']
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
