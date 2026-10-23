function Get-MwpModuleDefinition {
    <#
    .SYNOPSIS
        Odkrywa moduły w src\Modules i zwraca ich definicje (kontrakt z manifestu) z wynikiem walidacji.

    .DESCRIPTION
        Czyta manifesty MWP.*\MWP.*.psd1 bez importu modułów. Kontrakt jest w PrivateData.MWP
        (pola w ARCHITEKTURA.md, „Kontrakt modułu"). Każda definicja ma pola IsValid i Errors:
        zgodność wersji hosta, brakujące lub zbyt stare zależności, cykle, niedozwolone wartości.
        Definicja modułu nie jest jego instancją (instancje: FAZA 3).

    .PARAMETER Name
        Filtr po Id albo nazwie modułu (symbole wieloznaczne dozwolone).

    .PARAMETER ModulesRoot
        Katalog modułów; domyślnie src\Modules repozytorium. Tylko ten katalog jest przeszukiwany.

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
        [string] $ModulesRoot,

        [version] $HostVersion
    )

    if (-not $PSBoundParameters.ContainsKey('ModulesRoot')) {
        $ModulesRoot = Join-Path -Path (Get-MwpProjectRoot) -ChildPath 'src\Modules'
    }
    if (-not $PSBoundParameters.ContainsKey('HostVersion')) {
        $HostVersion = $MyInvocation.MyCommand.Module.Version
    }
    if (-not (Test-Path -LiteralPath $ModulesRoot -PathType Container)) {
        throw ("Nie znaleziono katalogu modułów {0}." -f $ModulesRoot)
    }

    $definitions = @(foreach ($directory in Get-ChildItem -LiteralPath $ModulesRoot -Directory -Filter 'MWP.*' | Sort-Object -Property Name) {
            $manifest = Join-Path -Path $directory.FullName -ChildPath ($directory.Name + '.psd1')
            ConvertTo-MwpModuleDefinition -ManifestPath $manifest -ModuleName $directory.Name
        })

    foreach ($definition in $definitions) {
        $validation = Test-MwpModuleDefinition -Definition $definition -AvailableDefinition $definitions -HostVersion $HostVersion
        $definition.IsValid = $validation.IsValid
        $definition.Errors = $validation.Errors
    }

    $definitions | Where-Object { $_.Id -like $Name -or $_.ModuleName -like $Name }
}
