function Get-MwpModuleDefinition {
    <#
    .SYNOPSIS
        Odkrywa moduły wbudowane (src\Modules) i zainstalowane z paczek (<katalog danych>\modules,
        dawniej src\Modules\Installed) i zwraca ich definicje (kontrakt z manifestu) z wynikiem walidacji.

    .DESCRIPTION
        Czyta manifesty MWP.*\MWP.*.psd1 bez importu modułów. Kontrakt jest w PrivateData.MWP
        (pola w ARCHITEKTURA.md, „Kontrakt modułu"). Każda definicja ma pola IsValid i Errors:
        zgodność wersji hosta, brakujące lub zbyt stare zależności, cykle, niedozwolone wartości.
        Pole Source mówi, skąd pochodzi moduł: BuiltIn (repozytorium) albo Installed (paczka .mwpmod,
        D-031); IsBase oznacza moduł bazowy (Core, Remote). Definicja modułu nie jest jego instancją
        (instancje: New-MwpModuleInstance w MWP.Remote).

    .PARAMETER Name
        Filtr po Id albo nazwie modułu (symbole wieloznaczne dozwolone).

    .PARAMETER ModulesRoot
        Lista katalogów modułów; domyślnie src\Modules, <katalog danych>\modules i dawny
        src\Modules\Installed (dwa ostatnie pomijane, dopóki nie istnieją; Get-MwpModuleRoot).
        Podany jawnie katalog musi istnieć. Katalog o nazwie Installed daje moduły z Source = Installed,
        pozostałe — BuiltIn. Pojedyncza ścieżka działa jak dotąd.

    .PARAMETER HostVersion
        Wersja hosta do walidacji MinimumHostVersion; domyślnie wersja MWP.Core.

    .EXAMPLE
        Get-MwpModuleDefinition | Where-Object { -not $_.IsValid } | Select-Object ModuleName, Errors
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Name = '*',

        [ValidateNotNullOrEmpty()]
        [string[]] $ModulesRoot,

        [version] $HostVersion
    )

    if (-not $PSBoundParameters.ContainsKey('HostVersion')) {
        $HostVersion = $MyInvocation.MyCommand.Module.Version
    }
    $roots = @()
    $installedRoots = @()
    if ($PSBoundParameters.ContainsKey('ModulesRoot')) {
        foreach ($directory in $ModulesRoot) {
            if (-not (Test-Path -LiteralPath $directory -PathType Container)) {
                throw ("Nie znaleziono katalogu modułów {0}." -f $directory)
            }
            $roots += $directory
        }
    }
    else {
        $moduleRoot = Get-MwpModuleRoot
        if (-not (Test-Path -LiteralPath $moduleRoot.BuiltIn -PathType Container)) {
            throw ("Nie znaleziono katalogu modułów {0}." -f $moduleRoot.BuiltIn)
        }
        $roots += $moduleRoot.BuiltIn
        # Katalog danych (D-038) i dawny src\Modules\Installed (do przeniesienia przez Move-MwpInstalledModule).
        $candidates = @($moduleRoot.Installed)
        if ($null -ne $moduleRoot.PSObject.Properties['Legacy']) {
            $candidates += $moduleRoot.Legacy
        }
        foreach ($candidate in $candidates) {
            if (-not [string]::IsNullOrEmpty($candidate) -and (Test-Path -LiteralPath $candidate -PathType Container)) {
                $roots += $candidate
                $installedRoots += [IO.Path]::GetFullPath($candidate).TrimEnd([char]92)
            }
        }
    }

    # Foldery robocze instalacji (.mwp-*) nie pasują do filtra MWP.*, więc nie są odkrywane.
    $definitions = @(foreach ($directoryRoot in $roots) {
            $fullRoot = [IO.Path]::GetFullPath($directoryRoot).TrimEnd([char]92)
            $source = if ($installedRoots -contains $fullRoot -or (Split-Path -Leaf $fullRoot) -eq 'Installed') { 'Installed' } else { 'BuiltIn' }
            foreach ($directory in Get-ChildItem -LiteralPath $directoryRoot -Directory -Filter 'MWP.*' | Sort-Object -Property Name) {
                $manifest = Join-Path -Path $directory.FullName -ChildPath ($directory.Name + '.psd1')
                ConvertTo-MwpModuleDefinition -ManifestPath $manifest -ModuleName $directory.Name -Source $source
            }
        })

    foreach ($definition in $definitions) {
        $validation = Test-MwpModuleDefinition -Definition $definition -AvailableDefinition $definitions -HostVersion $HostVersion
        $definition.IsValid = $validation.IsValid
        $definition.Errors = $validation.Errors
    }

    $definitions | Where-Object { $_.Id -like $Name -or $_.ModuleName -like $Name }
}
