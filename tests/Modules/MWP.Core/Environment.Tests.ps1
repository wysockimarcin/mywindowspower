#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
    Testy środowiska i elewacji: Get-MwpEnvironment, Test-MwpAdmin, Request-MwpElevation.
    Start-Process jest mockowany: testy nigdy nie wywołują monitu UAC.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Zmienne z bloków BeforeDiscovery/BeforeAll są używane w blokach It (zakresy Pestera).')]
param()

Describe 'Środowisko i elewacja' {
    BeforeAll {
        $root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
        Import-Module -Name (Join-Path -Path $root -ChildPath 'src\Modules\MWP.Core\MWP.Core.psd1') -Force
        $null = New-Item -ItemType Directory -Path (Join-Path -Path $TestDrive -ChildPath 'config') -Force
        Copy-Item -LiteralPath (Join-Path -Path $root -ChildPath 'config\settings.example.json') -Destination (Join-Path -Path $TestDrive -ChildPath 'config\settings.example.json')
        Mock -ModuleName MWP.Core Get-MwpDataPath {
            $path = Join-Path -Path $TestDrive -ChildPath $Kind
            if (Get-Variable -Name Detailed -ValueOnly -ErrorAction SilentlyContinue) { [pscustomobject]@{ Path = $path; Root = $TestDrive; Configured = ''; IsFallback = $false; Warning = $null } } else { $path }
        }
        Mock -ModuleName MWP.Core Get-MwpConfigPath {
            [pscustomobject]@{
                Example = Join-Path -Path $TestDrive -ChildPath 'config\settings.example.json'
                Local   = Join-Path -Path $TestDrive -ChildPath 'config\settings.local.json'
            }
        }
    }

    AfterAll {
        Remove-Module -Name MWP.Core -Force -ErrorAction SilentlyContinue
    }

    Context 'Get-MwpEnvironment' {
        BeforeAll {
            $environment = Get-MwpEnvironment
        }

        It 'dotyczy komputera localhost' {
            $environment.ComputerName | Should -Be 'localhost'
        }

        It 'zwraca wersję i edycję bieżącego PowerShella' {
            $environment.PSVersion | Should -Be $PSVersionTable.PSVersion
            $environment.PSEdition | Should -Be $PSVersionTable.PSEdition
            $environment.IsCore | Should -Be ($PSVersionTable.PSEdition -eq 'Core')
        }

        It 'rozpoznaje Windows i Windows 11 po numerze kompilacji' {
            $environment.IsWindows | Should -BeTrue
            $environment.OSBuild | Should -Be ([Environment]::OSVersion.Version.Build)
            $environment.IsWindows11 | Should -Be ($environment.OSBuild -ge 22000)
        }

        It 'zwraca wersję hosta równą wersji MWP.Core' {
            $environment.HostVersion | Should -Be (Get-Module -Name MWP.Core).Version
        }

        It 'zwraca status administratora, tryb wątku i ścieżkę programu' {
            $environment.IsAdmin | Should -BeOfType ([bool])
            $environment.ApartmentState | Should -Not -BeNullOrEmpty
            $environment.HostPath | Should -Exist
        }
    }

    Context 'Test-MwpAdmin' {
        It 'zwraca wartość logiczną' {
            Test-MwpAdmin | Should -BeOfType ([bool])
        }
    }

    Context 'Request-MwpElevation' {
        BeforeAll {
            Mock -ModuleName MWP.Core Start-Process { }
            $script = Join-Path -Path $TestDrive -ChildPath 'Skrypt testowy.ps1'
            Set-Content -LiteralPath $script -Value '# skrypt testowy'
        }

        It 'nic nie robi, gdy proces ma już uprawnienia administratora' {
            Mock -ModuleName MWP.Core Test-MwpAdmin { $true }

            $result = Request-MwpElevation -FilePath $script

            $result.Success | Should -BeTrue
            $result.Changed | Should -BeFalse
            Should -Invoke Start-Process -ModuleName MWP.Core -Times 0 -Exactly
        }

        It 'uruchamia ten sam PowerShell przez -Verb RunAs ze ścieżką i argumentami w cudzysłowach' {
            Mock -ModuleName MWP.Core Test-MwpAdmin { $false }

            $result = Request-MwpElevation -FilePath $script -ArgumentList @('-Tryb', 'z odstępem')

            $result.Success | Should -BeTrue
            $result.Changed | Should -BeTrue
            Should -Invoke Start-Process -ModuleName MWP.Core -Times 1 -Exactly -ParameterFilter {
                $Verb -eq 'RunAs' -and
                $FilePath -eq (Get-Process -Id $PID).Path -and
                ($ArgumentList -join ' ') -like '-NoProfile -File "*Skrypt testowy.ps1" -Tryb "z odstępem"'
            }
        }

        It '-WhatIf nie uruchamia procesu' {
            Mock -ModuleName MWP.Core Test-MwpAdmin { $false }

            $result = Request-MwpElevation -FilePath $script -WhatIf

            $result.IsPreview | Should -BeTrue
            Should -Invoke Start-Process -ModuleName MWP.Core -Times 0 -Exactly
        }

        It 'anulowanie monitu UAC daje czytelny komunikat' {
            Mock -ModuleName MWP.Core Test-MwpAdmin { $false }
            Mock -ModuleName MWP.Core Start-Process { throw (New-Object -TypeName System.ComponentModel.Win32Exception -ArgumentList 1223) }

            $result = Request-MwpElevation -FilePath $script

            $result.Success | Should -BeFalse
            $result.Message | Should -Match 'anulował'
        }

        It 'brak skryptu daje błąd bez uruchamiania procesu' {
            Mock -ModuleName MWP.Core Test-MwpAdmin { $false }

            $result = Request-MwpElevation -FilePath (Join-Path -Path $TestDrive -ChildPath 'brak.ps1')

            $result.Success | Should -BeFalse
            Should -Invoke Start-Process -ModuleName MWP.Core -Times 0 -Exactly
        }
    }

    Context 'Cytowanie argumentów procesu' {
        It 'zamienia <Value> na <Expected>' -ForEach @(
            @{ Value = 'abc'; Expected = 'abc' }
            @{ Value = 'a b'; Expected = '"a b"' }
            @{ Value = ''; Expected = '""' }
            @{ Value = 'a"b'; Expected = '"a\"b"' }
            @{ Value = 'C:\a b\'; Expected = '"C:\a b\\"' }
        ) {
            InModuleScope -ModuleName MWP.Core -Parameters @{ Value = $Value } {
                param($Value)
                ConvertTo-MwpProcessArgument -Value $Value
            } | Should -Be $Expected
        }
    }
}
