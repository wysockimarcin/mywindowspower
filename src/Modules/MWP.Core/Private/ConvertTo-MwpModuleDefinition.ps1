function ConvertTo-MwpModuleDefinition {
    <#
    .SYNOPSIS
        Czyta manifest modułu (bez importu modułu) i buduje obiekt MWP.ModuleDefinition.

    .DESCRIPTION
        Błąd odczytu manifestu nie przerywa odkrywania pozostałych modułów: trafia do pola
        LoadError, a Test-MwpModuleDefinition zgłasza go jako błąd walidacji.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $ManifestPath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $ModuleName
    )

    $manifest = $null
    $loadError = $null
    try {
        if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
            throw ("Nie znaleziono manifestu {0}." -f $ManifestPath)
        }
        $manifest = Import-PowerShellDataFile -LiteralPath $ManifestPath -ErrorAction Stop
    }
    catch {
        $loadError = $_.Exception.Message
    }

    $contract = $null
    if ($null -ne $manifest -and $manifest['PrivateData'] -is [Collections.IDictionary]) {
        $candidate = $manifest['PrivateData']['MWP']
        if ($candidate -is [Collections.IDictionary]) {
            $contract = $candidate
        }
    }

    $get = {
        param($Key)
        if ($null -ne $contract -and $contract.Contains($Key)) {
            $contract[$Key]
        }
    }

    $version = $null
    if ($null -ne $manifest) {
        $parsed = $null
        if ([version]::TryParse([string]$manifest['ModuleVersion'], [ref]$parsed)) {
            $version = $parsed
        }
    }

    $dependencies = @(foreach ($dependency in @(& $get 'Dependencies')) {
            if ($dependency -is [Collections.IDictionary]) {
                [pscustomobject]@{
                    Id             = [string]$dependency['Id']
                    MinimumVersion = [string]$dependency['MinimumVersion']
                }
            }
            elseif ($null -ne $dependency) {
                [pscustomobject]@{ Id = [string]$dependency; MinimumVersion = '' }
            }
        })

    [pscustomobject]@{
        PSTypeName                 = 'MWP.ModuleDefinition'
        Id                         = [string](& $get 'Id')
        Name                       = [string](& $get 'Name')
        ModuleName                 = $ModuleName
        Version                    = $version
        Description                = $(if ($null -ne $manifest) { [string]$manifest['Description'] } else { '' })
        ContractVersion            = & $get 'ContractVersion'
        EntryPoint                 = [string](& $get 'EntryPoint')
        MinimumHostVersion         = [string](& $get 'MinimumHostVersion')
        Dependencies               = $dependencies
        Capabilities               = @(& $get 'Capabilities')
        SupportedPresentationModes = @(& $get 'SupportedPresentationModes')
        RequiredPermissions        = @(& $get 'RequiredPermissions')
        ConfigurationSchema        = & $get 'ConfigurationSchema'
        ExportedFunctions          = $(if ($null -ne $manifest) { @($manifest['FunctionsToExport']) } else { @() })
        ManifestPath               = $ManifestPath
        ModuleBase                 = Split-Path -Parent $ManifestPath
        Contract                   = $contract
        LoadError                  = $loadError
        IsValid                    = $false
        Errors                     = @()
    }
}
