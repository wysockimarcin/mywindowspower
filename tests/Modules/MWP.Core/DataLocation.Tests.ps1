#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
    Testy katalogu danych w FAZIE 4 (D-032, D-038): Get-MwpDataLocation (stan i podgląd),
    Move-MwpDataDirectory („Przenieś dane"), moduły z paczek w katalogu danych
    (Get-MwpModuleRoot, Get-MwpModuleDefinition, Install-MwpModulePackage) i Move-MwpInstalledModule.
    Folder aplikacji (Get-MwpProjectRoot) i LOCALAPPDATA wskazują na TestDrive; ostatni test sprawdza,
    że nic nie trafiło do folderu repozytorium ani do prawdziwego profilu.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Zmienne z bloków BeforeDiscovery/BeforeAll są używane w blokach It (zakresy Pestera).')]
param()

Describe 'Katalog danych i moduły z paczek (FAZA 4)' {
    BeforeAll {
        $root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
        Import-Module -Name (Join-Path -Path $root -ChildPath 'src\Modules\MWP.Core\MWP.Core.psd1') -Force

        function Get-DirectorySnapshot {
            param([string] $Path)
            if (-not (Test-Path -LiteralPath $Path)) {
                return '<brak>'
            }
            $lines = foreach ($item in @(Get-ChildItem -LiteralPath $Path -Recurse -Force)) {
                '{0}|{1:o}' -f $item.FullName, $item.LastWriteTimeUtc
            }
            (@($lines) | Sort-Object) -join "`n"
        }
        $realLocalAppData = $env:LOCALAPPDATA
        $realFallbackSnapshot = Get-DirectorySnapshot -Path (Join-Path -Path $realLocalAppData -ChildPath 'MyWindowsPower')
        $repoDataSnapshot = Get-DirectorySnapshot -Path (Join-Path -Path $root -ChildPath 'data')
        $repoInstalledSnapshot = Get-DirectorySnapshot -Path (Join-Path -Path $root -ChildPath 'src\Modules\Installed')

        $appRoot = Join-Path -Path $TestDrive -ChildPath 'Aplikacja [test] zażółć'
        $configDirectory = Join-Path -Path $appRoot -ChildPath 'config'
        $localSettings = Join-Path -Path $configDirectory -ChildPath 'settings.local.json'
        $builtInRoot = Join-Path -Path $appRoot -ChildPath 'src\Modules'
        $testLocalAppData = Join-Path -Path $TestDrive -ChildPath 'Profil\AppData\Local'
        $null = New-Item -ItemType Directory -Path $configDirectory -Force
        $null = New-Item -ItemType Directory -Path $testLocalAppData -Force
        Copy-Item -LiteralPath (Join-Path -Path $root -ChildPath 'config\settings.example.json') -Destination (Join-Path -Path $configDirectory -ChildPath 'settings.example.json')
        # Moduły wbudowane w kopii aplikacji: tylko bazowe (Core, Remote).
        $null = New-Item -ItemType Directory -Path $builtInRoot -Force
        Copy-Item -LiteralPath (Join-Path -Path $root -ChildPath 'src\Modules\MWP.Core') -Destination $builtInRoot -Recurse
        Copy-Item -LiteralPath (Join-Path -Path $root -ChildPath 'src\Modules\MWP.Remote') -Destination $builtInRoot -Recurse
        $env:LOCALAPPDATA = $testLocalAppData

        Mock -ModuleName MWP.Core Get-MwpProjectRoot { $appRoot }

        function Write-LocalSetting {
            param([hashtable] $Values)
            $json = ConvertTo-Json -InputObject $Values -Depth 5
            [IO.File]::WriteAllText($localSettings, $json, (New-Object -TypeName System.Text.UTF8Encoding -ArgumentList $false))
        }
        function Add-TestModuleFolder {
            param([string] $Parent, [string] $Name, [string] $Id)
            $folder = Join-Path -Path $Parent -ChildPath $Name
            $null = New-Item -ItemType Directory -Path (Join-Path -Path $folder -ChildPath 'Public') -Force
            $manifest = @(
                '@{'
                "    RootModule = '$Name.psm1'"
                "    ModuleVersion = '1.0.0'"
                "    PowerShellVersion = '5.1'"
                "    FunctionsToExport = @('Get-Mwp$($Id)ModuleInfo')"
                "    PrivateData = @{ MWP = @{ ContractVersion = 1; Id = '$Id'; Name = 'Test $Id'; EntryPoint = 'Get-Mwp$($Id)ModuleInfo'; MinimumHostVersion = '0.4.0';"
                "        Dependencies = @(@{ Id = 'Core'; MinimumVersion = '0.4.0' }); Capabilities = @('Read'); SupportedPresentationModes = @();"
                "        RequiredPermissions = @('User'); ConfigurationSchema = @{} } }"
                '}'
            ) -join "`r`n"
            Set-Content -LiteralPath (Join-Path -Path $folder -ChildPath "$Name.psd1") -Value $manifest -Encoding UTF8
            Set-Content -LiteralPath (Join-Path -Path $folder -ChildPath "$Name.psm1") -Value "function Get-Mwp$($Id)ModuleInfo { '$Name' }" -Encoding UTF8
            $folder
        }
        function Clear-TestState {
            Remove-Item -LiteralPath $localSettings -Force -ErrorAction SilentlyContinue
            foreach ($path in @((Join-Path -Path $appRoot -ChildPath 'data'), (Join-Path -Path $appRoot -ChildPath 'nowe dane'),
                    (Join-Path -Path $builtInRoot -ChildPath 'Installed'), (Join-Path -Path $TestDrive -ChildPath 'Inny dysk'))) {
                if (Test-Path -LiteralPath $path) {
                    Remove-Item -LiteralPath $path -Recurse -Force
                }
            }
            InModuleScope MWP.Core { $script:MwpWritableDirectoryCache.Clear() }
        }
    }

    AfterAll {
        $env:LOCALAPPDATA = $realLocalAppData
        Remove-Module -Name MWP.Core -Force -ErrorAction SilentlyContinue
    }

    BeforeEach {
        Clear-TestState
    }

    Context 'Get-MwpDataLocation' {
        It 'opisuje bieżący katalog danych: data obok aplikacji, logs, undo i modules' {
            $location = Get-MwpDataLocation

            $location.Root | Should -Be (Join-Path -Path $appRoot -ChildPath 'data')
            $location.Modules | Should -Be (Join-Path -Path $appRoot -ChildPath 'data\modules')
            $location.Logs | Should -Be (Join-Path -Path $appRoot -ChildPath 'data\logs')
            $location.IsFallback | Should -BeFalse
            $location.IsPreview | Should -BeFalse
            @($location.LegacyModules).Count | Should -Be 0
        }

        It 'podgląd nowej wartości niczego nie tworzy i rozwija ścieżkę względną od folderu aplikacji' {
            $preview = Get-MwpDataLocation -DataPath 'nowe dane'

            $preview.IsPreview | Should -BeTrue
            $preview.IsValid | Should -BeTrue
            $preview.Root | Should -Be (Join-Path -Path $appRoot -ChildPath 'nowe dane')
            $preview.Exists | Should -BeFalse
            $preview.Writable | Should -BeTrue
            $preview.IsCurrent | Should -BeFalse
            Test-Path -LiteralPath (Join-Path -Path $appRoot -ChildPath 'nowe dane') | Should -BeFalse
        }

        It 'podgląd niepoprawnej wartości zwraca błąd zamiast wyjątku' {
            $preview = Get-MwpDataLocation -DataPath '%NIEISTNIEJACA_ZMIENNA_MWP%\dane'

            $preview.IsValid | Should -BeFalse
            $preview.Error | Should -Match 'nieznana zmienna'
            (Get-MwpDataLocation -DataPath 'C:dane').IsValid | Should -BeFalse
        }

        It 'pusta wartość oznacza bieżący katalog domyślny' {
            (Get-MwpDataLocation -DataPath '').IsCurrent | Should -BeTrue
        }

        It 'zgłasza moduły w dawnym katalogu src\Modules\Installed' {
            $null = Add-TestModuleFolder -Parent (Join-Path -Path $builtInRoot -ChildPath 'Installed') -Name 'MWP.Stary' -Id 'Stary'

            (Get-MwpDataLocation).LegacyModules | Should -Be @('MWP.Stary')
        }
    }

    Context 'moduły z paczek w katalogu danych (D-038)' {
        It 'Get-MwpModuleDefinition odkrywa moduły z katalogu danych (modules) i z dawnego katalogu jako Installed' {
            $null = Add-TestModuleFolder -Parent (Join-Path -Path $appRoot -ChildPath 'data\modules') -Name 'MWP.Nowy' -Id 'Nowy'
            $null = Add-TestModuleFolder -Parent (Join-Path -Path $builtInRoot -ChildPath 'Installed') -Name 'MWP.Stary' -Id 'Stary'

            $definitions = @(Get-MwpModuleDefinition)

            ($definitions | Where-Object { $_.Id -eq 'Nowy' }).Source | Should -Be 'Installed'
            ($definitions | Where-Object { $_.Id -eq 'Stary' }).Source | Should -Be 'Installed'
            ($definitions | Where-Object { $_.Id -eq 'Core' }).Source | Should -Be 'BuiltIn'
            ($definitions | Where-Object { $_.Id -eq 'Nowy' }).IsValid | Should -BeTrue
        }

        It 'Install-MwpModulePackage instaluje do katalogu danych' {
            $source = Add-TestModuleFolder -Parent (Join-Path -Path $TestDrive -ChildPath 'paczka') -Name 'MWP.Paczka' -Id 'Paczka'
            $zip = Join-Path -Path $TestDrive -ChildPath 'MWP.Paczka.zip'
            $package = Join-Path -Path $TestDrive -ChildPath 'MWP.Paczka.mwpmod'
            Remove-Item -LiteralPath $zip, $package -Force -ErrorAction SilentlyContinue
            Compress-Archive -Path $source -DestinationPath $zip
            Move-Item -LiteralPath $zip -Destination $package

            $result = Install-MwpModulePackage -Path $package -Confirm:$false

            $result.Success | Should -BeTrue -Because $result.Message
            Test-Path -LiteralPath (Join-Path -Path $appRoot -ChildPath 'data\modules\MWP.Paczka\MWP.Paczka.psd1') | Should -BeTrue
            (Get-MwpInstalledModule -Id 'Paczka').Present | Should -BeTrue
            Test-Path -LiteralPath (Join-Path -Path $builtInRoot -ChildPath 'Installed') | Should -BeFalse
        }

        It 'Move-MwpInstalledModule -WhatIf niczego nie przenosi' {
            $null = Add-TestModuleFolder -Parent (Join-Path -Path $builtInRoot -ChildPath 'Installed') -Name 'MWP.Stary' -Id 'Stary'

            $preview = Move-MwpInstalledModule -WhatIf

            $preview.IsPreview | Should -BeTrue
            $preview.Data | Should -Be @('MWP.Stary')
            Test-Path -LiteralPath (Join-Path -Path $builtInRoot -ChildPath 'Installed\MWP.Stary') | Should -BeTrue
        }

        It 'Move-MwpInstalledModule przenosi moduły do katalogu danych i usuwa pusty dawny katalog' {
            $null = Add-TestModuleFolder -Parent (Join-Path -Path $builtInRoot -ChildPath 'Installed') -Name 'MWP.Stary' -Id 'Stary'

            $result = Move-MwpInstalledModule -Confirm:$false

            $result.Success | Should -BeTrue -Because $result.Message
            $result.Changed | Should -BeTrue
            Test-Path -LiteralPath (Join-Path -Path $appRoot -ChildPath 'data\modules\MWP.Stary\MWP.Stary.psd1') | Should -BeTrue
            Test-Path -LiteralPath (Join-Path -Path $builtInRoot -ChildPath 'Installed') | Should -BeFalse
            (Get-MwpModuleDefinition -Name 'Stary').Source | Should -Be 'Installed'
        }

        It 'Move-MwpInstalledModule pomija moduł, którego folder już jest w katalogu danych' {
            $null = Add-TestModuleFolder -Parent (Join-Path -Path $builtInRoot -ChildPath 'Installed') -Name 'MWP.Stary' -Id 'Stary'
            $null = New-Item -ItemType Directory -Path (Join-Path -Path $appRoot -ChildPath 'data\modules\MWP.Stary') -Force

            $result = Move-MwpInstalledModule -Confirm:$false

            $result.Success | Should -BeFalse
            $result.Message | Should -Match 'już istnieje'
            Test-Path -LiteralPath (Join-Path -Path $builtInRoot -ChildPath 'Installed\MWP.Stary\MWP.Stary.psd1') | Should -BeTrue
        }

        It 'błąd kopiowania nie zostawia modułu w połowie' {
            $null = Add-TestModuleFolder -Parent (Join-Path -Path $builtInRoot -ChildPath 'Installed') -Name 'MWP.Stary' -Id 'Stary'
            Mock -ModuleName MWP.Core Copy-MwpDirectory { $null = [IO.Directory]::CreateDirectory($Destination); throw 'symulowany błąd kopiowania' }

            $result = Move-MwpInstalledModule -Confirm:$false

            $result.Success | Should -BeFalse
            @(Get-ChildItem -LiteralPath (Join-Path -Path $appRoot -ChildPath 'data\modules') -Force).Count | Should -Be 0
            Test-Path -LiteralPath (Join-Path -Path $builtInRoot -ChildPath 'Installed\MWP.Stary\MWP.Stary.psd1') | Should -BeTrue
        }
    }

    Context 'Move-MwpDataDirectory („Przenieś dane")' {
        BeforeEach {
            # Dane w bieżącym katalogu: log, wpis cofnięcia i moduł z paczki.
            $data = Join-Path -Path $appRoot -ChildPath 'data'
            $null = New-Item -ItemType Directory -Path (Join-Path -Path $data -ChildPath 'logs') -Force
            $null = New-Item -ItemType Directory -Path (Join-Path -Path $data -ChildPath 'undo') -Force
            Set-Content -LiteralPath (Join-Path -Path $data -ChildPath 'logs\mwp-2026-10-26.log') -Value '{"message":"zażółć"}' -Encoding UTF8
            Set-Content -LiteralPath (Join-Path -Path $data -ChildPath 'undo\11111111-1111-1111-1111-111111111111.json') -Value '{}' -Encoding UTF8
            $null = Add-TestModuleFolder -Parent (Join-Path -Path $data -ChildPath 'modules') -Name 'MWP.Nowy' -Id 'Nowy'
            $target = Join-Path -Path $TestDrive -ChildPath 'Inny dysk\Dane MWP'
        }

        It '-WhatIf pokazuje podgląd z liczbą plików i niczego nie zmienia' {
            $preview = Move-MwpDataDirectory -DataPath $target -WhatIf

            $preview.IsPreview | Should -BeTrue
            $preview.Message | Should -Match 'logs \(1 plików\)'
            $preview.Message | Should -Match 'modules \(2 plików\)'
            Test-Path -LiteralPath $target | Should -BeFalse
            Test-Path -LiteralPath $localSettings | Should -BeFalse
        }

        It 'przenosi logs, undo i modules, zapisuje dataPath i usuwa stare dane' {
            $result = Move-MwpDataDirectory -DataPath $target -Confirm:$false

            $result.Success | Should -BeTrue -Because $result.Message
            $result.Changed | Should -BeTrue
            Get-Content -LiteralPath (Join-Path -Path $target -ChildPath 'logs\mwp-2026-10-26.log') -Raw -Encoding UTF8 | Should -Match 'zażółć'
            Test-Path -LiteralPath (Join-Path -Path $target -ChildPath 'undo\11111111-1111-1111-1111-111111111111.json') | Should -BeTrue
            Test-Path -LiteralPath (Join-Path -Path $target -ChildPath 'modules\MWP.Nowy\MWP.Nowy.psd1') | Should -BeTrue
            Test-Path -LiteralPath (Join-Path -Path $appRoot -ChildPath 'data\logs') | Should -BeFalse
            Get-MwpSetting -Name 'dataPath' | Should -Be $target
            (Get-MwpDataLocation).Root | Should -Be $target
            @(Get-ChildItem -LiteralPath $target -Force -Filter '.mwp-move-*').Count | Should -Be 0
            $result.UndoId | Should -BeNullOrEmpty
            (Get-MwpModuleDefinition -Name 'Nowy').ModuleBase | Should -Be (Join-Path -Path $target -ChildPath 'modules\MWP.Nowy')
        }

        It 'ponowne przeniesienie z poprzednią wartością dataPath przywraca dane na miejsce' {
            $result = Move-MwpDataDirectory -DataPath $target -Confirm:$false
            $result.Message | Should -Match 'poprzedni'

            $back = Move-MwpDataDirectory -DataPath '' -Confirm:$false

            $back.Success | Should -BeTrue -Because $back.Message
            (Get-MwpDataLocation).Root | Should -Be (Join-Path -Path $appRoot -ChildPath 'data')
            Test-Path -LiteralPath (Join-Path -Path $appRoot -ChildPath 'data\logs\mwp-2026-10-26.log') | Should -BeTrue
        }

        It 'błąd kopiowania zostawia dane w starym miejscu i nie zmienia ustawienia' {
            Mock -ModuleName MWP.Core Copy-MwpDirectory { $null = [IO.Directory]::CreateDirectory($Destination); throw 'symulowany błąd kopiowania' }

            $result = Move-MwpDataDirectory -DataPath $target -Confirm:$false

            $result.Success | Should -BeFalse
            $result.Message | Should -Match 'symulowany błąd'
            Test-Path -LiteralPath (Join-Path -Path $appRoot -ChildPath 'data\logs\mwp-2026-10-26.log') | Should -BeTrue
            @(Get-ChildItem -LiteralPath $target -Force -ErrorAction SilentlyContinue).Count | Should -Be 0
            Get-MwpSetting -Name 'dataPath' | Should -Be ''
        }

        It 'odrzuca katalog docelowy z danymi aplikacji' {
            $null = New-Item -ItemType Directory -Path (Join-Path -Path $target -ChildPath 'logs') -Force
            Set-Content -LiteralPath (Join-Path -Path $target -ChildPath 'logs\inny.log') -Value 'x'

            $result = Move-MwpDataDirectory -DataPath $target -Confirm:$false

            $result.Success | Should -BeFalse
            $result.Message | Should -Match 'są już dane'
        }

        It 'odrzuca katalog wewnątrz danych bieżącego katalogu i niepoprawną ścieżkę' {
            (Move-MwpDataDirectory -DataPath 'data\logs\x' -Confirm:$false).Success | Should -BeFalse
            (Move-MwpDataDirectory -DataPath '%NIEISTNIEJACA_ZMIENNA_MWP%' -Confirm:$false).Success | Should -BeFalse
        }

        It 'ta sama lokalizacja daje wynik bez zmian' {
            $result = Move-MwpDataDirectory -DataPath '' -Confirm:$false

            $result.Success | Should -BeTrue
            $result.Changed | Should -BeFalse
        }
    }

    It 'testy nie zapisały niczego w folderze repozytorium ani w prawdziwym profilu' {
        Get-DirectorySnapshot -Path (Join-Path -Path $realLocalAppData -ChildPath 'MyWindowsPower') | Should -Be $realFallbackSnapshot
        Get-DirectorySnapshot -Path (Join-Path -Path $root -ChildPath 'data') | Should -Be $repoDataSnapshot
        Get-DirectorySnapshot -Path (Join-Path -Path $root -ChildPath 'src\Modules\Installed') | Should -Be $repoInstalledSnapshot
    }
}
