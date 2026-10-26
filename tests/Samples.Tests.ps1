#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
    Test paczki przykładowej samples\MWP.Przyklad (FAZA 4): po spakowaniu do .mwpmod przechodzi
    walidację Test-MwpModulePackage (kontrakt, zależności, RemoteTarget, tryby Embedded/SeparateWindow).
    Paczka powstaje na TestDrive; katalog modułów zainstalowanych wskazuje na TestDrive (mock).
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Zmienne z bloków BeforeDiscovery/BeforeAll są używane w blokach It (zakresy Pestera).')]
param()

Describe 'Paczka przykładowa MWP.Przyklad' {
    BeforeAll {
        $root = Split-Path -Parent $PSScriptRoot
        Import-Module -Name (Join-Path -Path $root -ChildPath 'src\Modules\MWP.Core\MWP.Core.psd1') -Force
        $builtIn = Join-Path -Path $root -ChildPath 'src\Modules'
        Mock -ModuleName MWP.Core Get-MwpModuleRoot {
            [pscustomobject]@{ BuiltIn = $builtIn; Installed = Join-Path -Path $TestDrive -ChildPath 'modules'; Legacy = Join-Path -Path $TestDrive -ChildPath 'legacy' }
        }
        Mock -ModuleName MWP.Core Get-MwpDataPath {
            $path = Join-Path -Path $TestDrive -ChildPath $Kind
            if (Get-Variable -Name Detailed -ValueOnly -ErrorAction SilentlyContinue) { [pscustomobject]@{ Path = $path; Root = $TestDrive; Configured = ''; IsFallback = $false; Warning = $null } } else { $path }
        }
        $zip = Join-Path -Path $TestDrive -ChildPath 'MWP.Przyklad.zip'
        Compress-Archive -Path (Join-Path -Path $root -ChildPath 'samples\MWP.Przyklad') -DestinationPath $zip
        $package = Join-Path -Path $TestDrive -ChildPath 'MWP.Przyklad.mwpmod'
        Move-Item -LiteralPath $zip -Destination $package
        $result = Test-MwpModulePackage -Path $package
    }

    AfterAll {
        Remove-Module -Name MWP.Core -Force -ErrorAction SilentlyContinue
    }

    It 'przechodzi walidację paczki' {
        $result.IsValid | Should -BeTrue -Because (@($result.Errors) -join ' ')
        $result.ModuleName | Should -Be 'MWP.Przyklad'
        $result.Id | Should -Be 'Przyklad'
        $result.Sha256 | Should -Match '^[0-9A-F]{64}$'
    }

    It 'deklaruje komputery zdalne i oba tryby okna hosta' {
        $manifest = Import-PowerShellDataFile -LiteralPath (Join-Path -Path $root -ChildPath 'samples\MWP.Przyklad\MWP.Przyklad.psd1')
        $manifest.PrivateData.MWP.Capabilities | Should -Contain 'RemoteTarget'
        $manifest.PrivateData.MWP.SupportedPresentationModes | Should -Be @('Embedded', 'SeparateWindow')
    }
}
