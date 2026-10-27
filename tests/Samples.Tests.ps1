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

    It 'deklaruje komputery zdalne, oba tryby okna hosta i widget Dashboardu' {
        $manifest = Import-PowerShellDataFile -LiteralPath (Join-Path -Path $root -ChildPath 'samples\MWP.Przyklad\MWP.Przyklad.psd1')
        $manifest.PrivateData.MWP.Capabilities | Should -Contain 'RemoteTarget'
        $manifest.PrivateData.MWP.SupportedPresentationModes | Should -Be @('Embedded', 'SeparateWindow', 'DashboardWidget')
        $manifest.PrivateData.MWP.Widgets[0].Id | Should -Be 'Stan'
    }

    It 'widget przykładowy zwraca widok z danych Get-MwpTargetInfo' {
        Import-Module -Name (Join-Path -Path $root -ChildPath 'samples\MWP.Przyklad\MWP.Przyklad.psd1') -Force
        $data = [pscustomobject]@{ ComputerName = 'PC-PRZYKLAD'; System = 'Windows 11 Pro'; PowerShell = '5.1'; Time = '2026-10-27 12:00:00' }

        $view = ConvertTo-MwpPrzykladWidgetView -Data @($data)

        $view.Summary | Should -Be 'PC-PRZYKLAD'
        @($view.Sections[0].Items | ForEach-Object { $_.Label }) | Should -Be @('ComputerName', 'System', 'PowerShell', 'Time')
        ConvertTo-MwpPrzykladWidgetView -Data $null | Should -BeNullOrEmpty
        Remove-Module -Name MWP.Przyklad -Force
    }
}
