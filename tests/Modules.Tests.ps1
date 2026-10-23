#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
    Testy szkieletu modułów src/Modules/MWP.*: manifesty, import, eksport funkcji.
    Moduły są importowane w tej sesji; testy niczego nie zmieniają w systemie.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Zmienne z bloków BeforeDiscovery/BeforeAll są używane w blokach It (zakresy Pestera).')]
param()

BeforeDiscovery {
    $modulesRoot = Join-Path -Path (Split-Path -Parent $PSScriptRoot) -ChildPath 'src\Modules'

    # Obszary z docs/00_PROJEKT/ARCHITEKTURA.md (sekcja „Docelowa struktura repozytorium").
    $expectedModules = @(
        'MWP.Core', 'MWP.Remote', 'MWP.Dashboard', 'MWP.Power', 'MWP.Services', 'MWP.Startup', 'MWP.Cleanup',
        'MWP.Update', 'MWP.Network', 'MWP.Apps', 'MWP.Tweaks', 'MWP.Security'
    ) | ForEach-Object { @{ Name = $_ } }

    $modules = @(Get-ChildItem -LiteralPath $modulesRoot -Directory -Filter 'MWP.*' | ForEach-Object {
            @{
                Name      = $_.Name
                Directory = $_.FullName
                Manifest  = Join-Path -Path $_.FullName -ChildPath ($_.Name + '.psd1')
            }
        })
}

Describe 'Komplet modułów' {
    BeforeAll {
        $modulesRoot = Join-Path -Path (Split-Path -Parent $PSScriptRoot) -ChildPath 'src\Modules'
    }

    It 'istnieje moduł <Name>' -ForEach $expectedModules {
        Join-Path -Path $modulesRoot -ChildPath "$Name\$Name.psd1" | Should -Exist
    }
}

Describe 'Moduł <Name>' -ForEach $modules {
    BeforeAll {
        $data = Import-PowerShellDataFile -LiteralPath $Manifest
        $publicFunctions = @(Get-ChildItem -Path (Join-Path -Path $Directory -ChildPath 'Public') -Filter '*.ps1' -File |
                ForEach-Object { $_.BaseName })
    }

    AfterAll {
        Remove-Module -Name $Name -Force -ErrorAction SilentlyContinue
    }

    It 'ma poprawny manifest' {
        { Test-ModuleManifest -Path $Manifest -ErrorAction Stop } | Should -Not -Throw
    }

    It 'manifest wskazuje plik .psm1 o tej samej nazwie' {
        $data.RootModule | Should -Be "$Name.psm1"
        Join-Path -Path $Directory -ChildPath $data.RootModule | Should -Exist
    }

    It 'manifest deklaruje PowerShell 5.1 oraz edycje Desktop i Core' {
        $data.PowerShellVersion | Should -Be '5.1'
        $data.CompatiblePSEditions | Should -Contain 'Desktop'
        $data.CompatiblePSEditions | Should -Contain 'Core'
    }

    It 'FunctionsToExport odpowiada plikom w Public\' {
        @($data.FunctionsToExport | Sort-Object) | Should -Be @($publicFunctions | Sort-Object)
    }

    It 'importuje się bez błędów i eksportuje zadeklarowane funkcje' {
        $module = Import-Module -Name $Manifest -Force -PassThru -ErrorAction Stop
        @($module.ExportedFunctions.Keys | Sort-Object) | Should -Be @($data.FunctionsToExport | Sort-Object)
    }

    It 'funkcje publiczne używają prefiksu Mwp i zatwierdzonego czasownika' {
        $approved = (Get-Verb).Verb
        foreach ($function in $publicFunctions) {
            $verb, $noun = $function -split '-', 2
            $approved | Should -Contain $verb
            $noun | Should -Match '^Mwp'
        }
    }

    It 'manifest zawiera kontrakt modułu (PrivateData.MWP) z Id zgodnym z nazwą' {
        $data.PrivateData.MWP | Should -Not -BeNullOrEmpty
        $data.PrivateData.MWP.Id | Should -Be ($Name -replace '^MWP\.', '')
    }

    It 'kontrakt przechodzi walidację Get-MwpModuleDefinition' {
        Import-Module -Name (Join-Path -Path (Split-Path -Parent $Directory) -ChildPath 'MWP.Core\MWP.Core.psd1') -Force -ErrorAction Stop
        $definition = Get-MwpModuleDefinition -Name $Name
        $definition.IsValid | Should -BeTrue -Because ($definition.Errors -join ' ')
    }

    It 'zaślepka zwraca nazwę i wersję modułu' {
        Import-Module -Name $Manifest -Force -ErrorAction Stop
        $info = & ("Get-Mwp{0}ModuleInfo" -f ($Name -replace '^MWP\.', ''))
        $info.Name | Should -Be $Name
        $info.Version | Should -Be ([version]$data.ModuleVersion)
    }
}
