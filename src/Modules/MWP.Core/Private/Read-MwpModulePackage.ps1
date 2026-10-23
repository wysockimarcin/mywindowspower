function Read-MwpModulePackage {
    <#
    .SYNOPSIS
        Rozpakowuje paczkę .mwpmod do katalogu roboczego i waliduje moduł (D-031).

    .DESCRIPTION
        Wspólna część Test-MwpModulePackage i Install-MwpModulePackage. Sprawdza: plik i rozszerzenie,
        budowę archiwum (Expand-MwpModulePackage), obecność manifestu i pliku .psm1, kontrakt modułu
        (Test-MwpModuleDefinition: pola, MinimumHostVersion, zależności) oraz kolizję Id i nazwy folderu
        z modułami wbudowanymi i zainstalowanymi. Zwraca sumę SHA-256 paczki i dane do potwierdzenia.
        Katalogu roboczego nie usuwa (robi to wywołujący, także po błędzie).

    .OUTPUTS
        MWP.ModulePackage: IsValid, Errors, PackagePath, Sha256, ModuleName, Id, Name, Version,
        Description, RequiredPermissions, Dependencies, ExtractedPath.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Path,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $StagingRoot,

        [version] $HostVersion
    )

    $errors = New-Object -TypeName System.Collections.Generic.List[string]
    $package = [pscustomobject]@{
        PSTypeName          = 'MWP.ModulePackage'
        IsValid             = $false
        Errors              = @()
        PackagePath         = $Path
        Sha256              = $null
        ModuleName          = $null
        Id                  = $null
        Name                = $null
        Version             = $null
        Description         = $null
        RequiredPermissions = @()
        Dependencies        = @()
        ExtractedPath       = $null
    }

    $finish = {
        $package.Errors = $errors.ToArray()
        $package.IsValid = $errors.Count -eq 0
        $package
    }

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        $errors.Add(("Nie znaleziono pliku paczki {0}." -f $Path))
        return & $finish
    }
    $package.PackagePath = (Resolve-Path -LiteralPath $Path).ProviderPath
    if ([IO.Path]::GetExtension($package.PackagePath) -ne '.mwpmod') {
        $errors.Add('Paczka modułu musi mieć rozszerzenie .mwpmod.')
        return & $finish
    }
    $package.Sha256 = (Get-FileHash -LiteralPath $package.PackagePath -Algorithm SHA256).Hash

    $expanded = Expand-MwpModulePackage -Path $package.PackagePath -Destination $StagingRoot
    $package.ModuleName = $expanded.ModuleName
    foreach ($message in $expanded.Errors) {
        $errors.Add($message)
    }
    if ($errors.Count -gt 0) {
        return & $finish
    }
    $package.ExtractedPath = $expanded.ModulePath

    $manifest = Join-Path -Path $expanded.ModulePath -ChildPath ($expanded.ModuleName + '.psd1')
    if (-not (Test-Path -LiteralPath $manifest -PathType Leaf)) {
        $errors.Add(("Brak manifestu {0}.psd1 w folderze głównym paczki." -f $expanded.ModuleName))
        return & $finish
    }
    if (-not (Test-Path -LiteralPath (Join-Path -Path $expanded.ModulePath -ChildPath ($expanded.ModuleName + '.psm1')) -PathType Leaf)) {
        $errors.Add(("Brak pliku {0}.psm1 w folderze głównym paczki." -f $expanded.ModuleName))
    }

    $definition = ConvertTo-MwpModuleDefinition -ManifestPath $manifest -ModuleName $expanded.ModuleName -Source Installed
    $package.Id = $definition.Id
    $package.Name = $definition.Name
    $package.Version = $definition.Version
    $package.Description = $definition.Description
    $package.RequiredPermissions = @($definition.RequiredPermissions)
    $package.Dependencies = @($definition.Dependencies)

    $existing = @(Get-MwpModuleDefinition)
    $sourceNames = @{ BuiltIn = 'wbudowany'; Installed = 'zainstalowany' }
    foreach ($other in $existing) {
        if (-not [string]::IsNullOrEmpty($definition.Id) -and $other.Id -eq $definition.Id) {
            $errors.Add(("Moduł o Id '{0}' już istnieje ({1}: {2}, wersja {3}). Nową wersję instaluje się po odinstalowaniu starej." -f
                    $definition.Id, $sourceNames[$other.Source], $other.ModuleName, $other.Version))
        }
        elseif ($other.ModuleName -eq $definition.ModuleName) {
            $errors.Add(("Folder modułu '{0}' już istnieje ({1})." -f $definition.ModuleName, $sourceNames[$other.Source]))
        }
    }

    # Kolizje są zgłoszone wyżej, więc do walidacji kontraktu trafiają tylko pozostałe moduły.
    $available = @($existing | Where-Object { $_.Id -ne $definition.Id -and $_.ModuleName -ne $definition.ModuleName }) + $definition
    $validationArguments = @{ Definition = $definition; AvailableDefinition = $available }
    if ($PSBoundParameters.ContainsKey('HostVersion')) {
        $validationArguments['HostVersion'] = $HostVersion
    }
    $validation = Test-MwpModuleDefinition @validationArguments
    foreach ($message in $validation.Errors) {
        $errors.Add($message)
    }

    & $finish
}
