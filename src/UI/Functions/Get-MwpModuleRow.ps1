function Get-MwpModuleRow {
    <#
    .SYNOPSIS
        Buduje wiersze tabeli widoku „Moduły" z definicji modułów, rejestru instalacji i instancji.

    .DESCRIPTION
        Widok „Moduły" (D-031): nazwa, Id, wersja, pochodzenie (bazowy, wbudowany, z paczki), stan
        walidacji, tryby prezentacji, wymagane uprawnienia, liczba otwartych instancji, data
        instalacji i SHA-256 (moduły z paczek). CanUninstall jest prawdą tylko dla modułu
        zainstalowanego z paczki, który nie jest bazowy (reguły Uninstall-MwpModulePackage).

    .PARAMETER Definition
        Definicje modułów (Get-MwpModuleDefinition).

    .PARAMETER InstalledModule
        Rejestr instalacji (Get-MwpInstalledModule).

    .PARAMETER Instance
        Otwarte instancje (Get-MwpModuleInstance).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [AllowEmptyCollection()]
        [object[]] $Definition = @(),

        [AllowEmptyCollection()]
        [object[]] $InstalledModule = @(),

        [AllowEmptyCollection()]
        [object[]] $Instance = @()
    )

    $order = { if ($_.IsBase) { 0 } elseif ($_.Source -eq 'BuiltIn') { 1 } else { 2 } }
    foreach ($module in @($Definition | Sort-Object -Property @{ Expression = $order }, Name)) {
        $installed = @($InstalledModule | Where-Object { $_.Id -eq $module.Id }) | Select-Object -First 1
        $source = if ($module.IsBase) { 'Bazowy' } elseif ($module.Source -eq 'Installed') { 'Z paczki' } else { 'Wbudowany' }
        $modes = @($module.SupportedPresentationModes | Where-Object { $_ })
        [pscustomobject]@{
            PSTypeName    = 'MWP.UiModuleRow'
            Name          = $(if ($module.Name) { $module.Name } else { $module.ModuleName })
            Id            = $module.Id
            ModuleName    = $module.ModuleName
            Version       = [string]$module.Version
            Source        = $source
            State         = $(if ($module.IsValid) { 'Poprawny' } else { 'Błędy: ' + (@($module.Errors) -join ' ') })
            IsValid       = [bool]$module.IsValid
            Modes         = $(if ($modes.Count -gt 0) { $modes -join ', ' } else { '(zaślepka)' })
            Permissions   = @($module.RequiredPermissions) -join ', '
            Capabilities  = @($module.Capabilities) -join ', '
            Instances     = @($Instance | Where-Object { $_.ModuleId -eq $module.Id }).Count
            InstalledAt   = $(if ($null -ne $installed -and $null -ne $installed.InstalledAt) { ([datetime]$installed.InstalledAt).ToString('yyyy-MM-dd HH:mm') } else { '' })
            Sha256        = $(if ($null -ne $installed) { $installed.Sha256 } else { '' })
            Path          = $module.ModuleBase
            CanUninstall  = $module.Source -eq 'Installed' -and -not $module.IsBase
            Definition    = $module
        }
    }
}
