#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
    Testy paczek modułów .mwpmod (D-031): Test-, Install-, Uninstall-MwpModulePackage,
    Get-MwpInstalledModule i odkrywanie modułów zainstalowanych. Paczki są tworzone na TestDrive,
    katalog modułów zainstalowanych i ustawienia też (mocki Get-MwpModuleRoot i ścieżek konfiguracji);
    moduły wbudowane są czytane z repozytorium tylko do odczytu.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Zmienne z bloków BeforeDiscovery/BeforeAll są używane w blokach It (zakresy Pestera).')]
param()

Describe 'Paczki modułów' {
    BeforeAll {
        $root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
        Import-Module -Name (Join-Path -Path $root -ChildPath 'src\Modules\MWP.Core\MWP.Core.psd1') -Force
        Import-Module -Name (Join-Path -Path $root -ChildPath 'src\Modules\MWP.Remote\MWP.Remote.psd1') -Force
        $configDirectory = Join-Path -Path $TestDrive -ChildPath 'config'
        $null = New-Item -ItemType Directory -Path $configDirectory -Force
        Copy-Item -LiteralPath (Join-Path -Path $root -ChildPath 'config\settings.example.json') -Destination (Join-Path -Path $configDirectory -ChildPath 'settings.example.json')
        $localPath = Join-Path -Path $configDirectory -ChildPath 'settings.local.json'
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
        $builtIn = Join-Path -Path $root -ChildPath 'src\Modules'
        $installedRoot = Join-Path -Path $TestDrive -ChildPath 'Modules\Installed'
        Mock -ModuleName MWP.Core Get-MwpModuleRoot { [pscustomobject]@{ BuiltIn = $builtIn; Installed = $installedRoot } }
        $packages = Join-Path -Path $TestDrive -ChildPath 'Packages'
        $null = New-Item -ItemType Directory -Path $packages -Force
        Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem

        function Get-ModuleFile {
            param(
                [string] $Name = 'Probe',
                [string] $Id = $Name,
                [string] $Folder = "MWP.$Name",
                [string] $Dependencies = "@(@{ Id = 'Core'; MinimumVersion = '0.3.0' })",
                [string] $MinimumHostVersion = '0.3.0',
                [string] $Version = '1.2.0'
            )
            $manifest = @(
                '@{'
                "    RootModule = '$Folder.psm1'"
                "    ModuleVersion = '$Version'"
                "    Description = 'Moduł testowy z paczki'"
                "    PowerShellVersion = '5.1'"
                "    FunctionsToExport = @('Get-Mwp${Name}ModuleInfo')"
                "    PrivateData = @{ MWP = @{ ContractVersion = 1; Id = '$Id'; Name = 'Sonda $Name'; EntryPoint = 'Get-Mwp${Name}ModuleInfo';"
                "        MinimumHostVersion = '$MinimumHostVersion'; Dependencies = $Dependencies; Capabilities = @('Read', 'RemoteTarget');"
                "        SupportedPresentationModes = @('CLI'); RequiredPermissions = @('User', 'Administrator'); ConfigurationSchema = @{} } }"
                '}'
            ) -join "`r`n"
            [ordered]@{
                "$Folder/"                 = $null
                "$Folder/$Folder.psd1"     = $manifest
                "$Folder/$Folder.psm1"     = "function Get-Mwp${Name}ModuleInfo { 'MWP.$Name' }`r`nExport-ModuleMember -Function Get-Mwp${Name}ModuleInfo"
                "$Folder/Public/"          = $null
                "$Folder/Private/Info.txt" = 'plik pomocniczy'
            }
        }

        function Write-TestPackage {
            param(
                [string] $FileName,
                [Collections.IDictionary] $Entries
            )
            $path = Join-Path -Path $packages -ChildPath $FileName
            Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
            $stream = [IO.File]::Open($path, [IO.FileMode]::CreateNew)
            $archive = New-Object -TypeName IO.Compression.ZipArchive -ArgumentList $stream, ([IO.Compression.ZipArchiveMode]::Create)
            try {
                foreach ($key in $Entries.Keys) {
                    $entry = $archive.CreateEntry($key)
                    if ($null -ne $Entries[$key]) {
                        $writer = New-Object -TypeName IO.StreamWriter -ArgumentList $entry.Open(), (New-Object -TypeName Text.UTF8Encoding -ArgumentList $true)
                        $writer.Write($Entries[$key])
                        $writer.Dispose()
                    }
                }
            }
            finally {
                $archive.Dispose()
                $stream.Dispose()
            }
            $path
        }

        function Get-Leftover {
            @(Get-ChildItem -LiteralPath $TestDrive -Recurse -Force | Where-Object { $_.Name -like '.mwp-*' -or $_.Name -eq 'evil.txt' })
        }
    }

    AfterAll {
        Get-MwpModuleInstance | Close-MwpModuleInstance | Out-Null
        Remove-Module -Name MWP.Probe, MWP.Remote, MWP.Core -Force -ErrorAction SilentlyContinue
    }

    BeforeEach {
        Get-MwpModuleInstance | Close-MwpModuleInstance | Out-Null
        Remove-Module -Name MWP.Probe, MWP.Second -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath (Join-Path -Path $TestDrive -ChildPath 'Modules') -Recurse -Force -ErrorAction SilentlyContinue
        Get-ChildItem -LiteralPath $configDirectory -Filter 'settings.local.json*' | Remove-Item -Force
        $validPackage = Write-TestPackage -FileName 'MWP.Probe.mwpmod' -Entries (Get-ModuleFile)
    }

    Context 'Test-MwpModulePackage' {
        It 'poprawna paczka: dane do potwierdzenia i suma SHA-256, bez śladów w katalogu tymczasowym' {
            $before = @(Get-ChildItem -LiteralPath ([IO.Path]::GetTempPath()) -Directory -Filter 'mwp-package-*' -ErrorAction SilentlyContinue).Count

            $package = Test-MwpModulePackage -Path $validPackage

            $package.IsValid | Should -BeTrue -Because ($package.Errors -join ' ')
            $package.Id | Should -Be 'Probe'
            $package.ModuleName | Should -Be 'MWP.Probe'
            $package.Name | Should -Be 'Sonda Probe'
            $package.Version | Should -Be ([version]'1.2.0')
            $package.RequiredPermissions | Should -Be @('User', 'Administrator')
            $package.Sha256 | Should -Be (Get-FileHash -LiteralPath $validPackage -Algorithm SHA256).Hash
            $package.ExtractedPath | Should -BeNullOrEmpty
            @(Get-ChildItem -LiteralPath ([IO.Path]::GetTempPath()) -Directory -Filter 'mwp-package-*' -ErrorAction SilentlyContinue).Count | Should -Be $before
            $installedRoot | Should -Not -Exist
        }

        It 'odrzuca ścieżkę wychodzącą poza folder docelowy (..\) i nic nie rozpakowuje' {
            $entries = Get-ModuleFile
            $entries['MWP.Probe/../../evil.txt'] = 'zło'
            $path = Write-TestPackage -FileName 'wyjscie.mwpmod' -Entries $entries

            $package = Test-MwpModulePackage -Path $path

            $package.IsValid | Should -BeFalse
            $package.Errors -join ' ' | Should -Match 'wychodzi poza folder'
            Get-Leftover | Should -BeNullOrEmpty
        }

        It 'odrzuca ścieżkę bezwzględną w archiwum' {
            $entries = Get-ModuleFile
            $entries['C:/evil.txt'] = 'zło'
            $path = Write-TestPackage -FileName 'bezwzgledna.mwpmod' -Entries $entries

            (Test-MwpModulePackage -Path $path).Errors -join ' ' | Should -Match 'bezwzględn'
        }

        It 'odrzuca dwa foldery główne' {
            $entries = Get-ModuleFile
            foreach ($pair in @((Get-ModuleFile -Name 'Second').GetEnumerator())) {
                $entries[$pair.Key] = $pair.Value
            }
            $path = Write-TestPackage -FileName 'dwa.mwpmod' -Entries $entries

            $package = Test-MwpModulePackage -Path $path

            $package.IsValid | Should -BeFalse
            $package.Errors -join ' ' | Should -Match 'dokładnie jeden folder główny'
        }

        It 'odrzuca plik poza folderem głównym i folder główny bez prefiksu MWP.' {
            $entries = Get-ModuleFile
            $entries['README.txt'] = 'opis'
            (Test-MwpModulePackage -Path (Write-TestPackage -FileName 'plik.mwpmod' -Entries $entries)).Errors -join ' ' | Should -Match 'poza folderem głównym'

            $other = Get-ModuleFile -Folder 'Sonda'
            (Test-MwpModulePackage -Path (Write-TestPackage -FileName 'nazwa.mwpmod' -Entries $other)).Errors -join ' ' | Should -Match 'MWP\.<Nazwa>'
        }

        It 'odrzuca brak manifestu, plik niebędący ZIP-em i złe rozszerzenie' {
            $entries = Get-ModuleFile
            $entries.Remove('MWP.Probe/MWP.Probe.psd1')
            (Test-MwpModulePackage -Path (Write-TestPackage -FileName 'bez.mwpmod' -Entries $entries)).Errors -join ' ' | Should -Match 'Brak manifestu'

            $fake = Join-Path -Path $packages -ChildPath 'tekst.mwpmod'
            Set-Content -LiteralPath $fake -Value 'to nie jest zip' -Encoding UTF8
            (Test-MwpModulePackage -Path $fake).Errors -join ' ' | Should -Match 'ZIP'

            $zip = Join-Path -Path $packages -ChildPath 'MWP.Probe.zip'
            Copy-Item -LiteralPath $validPackage -Destination $zip
            (Test-MwpModulePackage -Path $zip).Errors -join ' ' | Should -Match '\.mwpmod'
        }

        It 'odrzuca kolizję Id z modułem wbudowanym i nazwy folderu z modułem wbudowanym' {
            $sameId = Write-TestPackage -FileName 'id.mwpmod' -Entries (Get-ModuleFile -Name 'Probe' -Id 'Services')
            (Test-MwpModulePackage -Path $sameId).Errors -join ' ' | Should -Match "Id 'Services' już istnieje \(wbudowany"

            $sameFolder = Write-TestPackage -FileName 'folder.mwpmod' -Entries (Get-ModuleFile -Name 'Power' -Id 'InnyPower')
            (Test-MwpModulePackage -Path $sameFolder).Errors -join ' ' | Should -Match "Folder modułu 'MWP.Power' już istnieje"
        }

        It 'odrzuca brakującą zależność i zbyt nową wymaganą wersję hosta' {
            $missing = Write-TestPackage -FileName 'zal.mwpmod' -Entries (Get-ModuleFile -Dependencies "@(@{ Id = 'BrakModulu'; MinimumVersion = '1.0.0' })")
            (Test-MwpModulePackage -Path $missing).Errors -join ' ' | Should -Match "Brakująca zależność.*BrakModulu"

            $newer = Write-TestPackage -FileName 'host.mwpmod' -Entries (Get-ModuleFile -MinimumHostVersion '99.0.0')
            (Test-MwpModulePackage -Path $newer).Errors -join ' ' | Should -Match 'wymaga hosta'
        }
    }

    Context 'Install-MwpModulePackage' {
        It 'instaluje moduł w src\Modules\Installed z wpisem w rejestrze; moduł jest odkrywany jako Installed' {
            $result = Install-MwpModulePackage -Path $validPackage

            $result.Success | Should -BeTrue -Because $result.Message
            $result.Changed | Should -BeTrue
            $result.ComputerName | Should -Be 'localhost'
            Join-Path -Path $installedRoot -ChildPath 'MWP.Probe\MWP.Probe.psd1' | Should -Exist
            Join-Path -Path $installedRoot -ChildPath 'MWP.Probe\Private\Info.txt' | Should -Exist

            $registry = @(Get-MwpInstalledModule)
            $registry.Count | Should -Be 1
            $registry[0].Id | Should -Be 'Probe'
            $registry[0].Version | Should -Be '1.2.0'
            $registry[0].Sha256 | Should -Be (Get-FileHash -LiteralPath $validPackage -Algorithm SHA256).Hash
            $registry[0].InstalledAt | Should -BeOfType [datetime]
            $registry[0].Present | Should -BeTrue

            $definition = Get-MwpModuleDefinition -Name 'Probe'
            $definition.Source | Should -Be 'Installed'
            $definition.IsValid | Should -BeTrue -Because ($definition.Errors -join ' ')
            Get-Leftover | Should -BeNullOrEmpty
        }

        It 'zainstalowany moduł da się zaimportować' {
            $null = Install-MwpModulePackage -Path $validPackage

            Import-Module -Name (Join-Path -Path $installedRoot -ChildPath 'MWP.Probe\MWP.Probe.psd1') -Force
            Get-MwpProbeModuleInfo | Should -Be 'MWP.Probe'
        }

        It '-WhatIf niczego nie instaluje i nie zapisuje rejestru' {
            $result = Install-MwpModulePackage -Path $validPackage -WhatIf

            $result.IsPreview | Should -BeTrue
            $result.Changed | Should -BeFalse
            $result.Message | Should -Match $result.Data.Sha256
            $installedRoot | Should -Not -Exist
            $localPath | Should -Not -Exist
            Get-Leftover | Should -BeNullOrEmpty
        }

        It 'odrzuca paczkę z Id już zainstalowanego modułu' {
            $null = Install-MwpModulePackage -Path $validPackage
            $again = Write-TestPackage -FileName 'druga.mwpmod' -Entries (Get-ModuleFile -Name 'Second' -Id 'Probe')

            $result = Install-MwpModulePackage -Path $again

            $result.Success | Should -BeFalse
            $result.Message | Should -Match "Id 'Probe' już istnieje \(zainstalowany"
            Join-Path -Path $installedRoot -ChildPath 'MWP.Second' | Should -Not -Exist
            @(Get-MwpInstalledModule).Count | Should -Be 1
        }

        It 'błędna paczka niczego nie zostawia' {
            $entries = Get-ModuleFile
            $entries['../evil.txt'] = 'zło'
            $result = Install-MwpModulePackage -Path (Write-TestPackage -FileName 'zla.mwpmod' -Entries $entries)

            $result.Success | Should -BeFalse
            $installedRoot | Should -Not -Exist
            $localPath | Should -Not -Exist
            Get-Leftover | Should -BeNullOrEmpty
        }

        It 'błąd zapisu rejestru w trakcie instalacji wycofuje przeniesiony folder' {
            Mock -ModuleName MWP.Core Write-MwpLocalSetting { throw 'awaria dysku (test)' }

            $result = Install-MwpModulePackage -Path $validPackage

            $result.Success | Should -BeFalse
            $result.ErrorMessage | Should -Match 'awaria dysku'
            $installedRoot | Should -Not -Exist
            @(Get-MwpInstalledModule).Count | Should -Be 0
            Get-Leftover | Should -BeNullOrEmpty
        }

        It 'błąd przeniesienia folderu w trakcie instalacji niczego nie zostawia' {
            Mock -ModuleName MWP.Core Move-MwpDirectory { throw 'folder zablokowany (test)' }

            $result = Install-MwpModulePackage -Path $validPackage

            $result.Success | Should -BeFalse
            $installedRoot | Should -Not -Exist
            $localPath | Should -Not -Exist
            Get-Leftover | Should -BeNullOrEmpty
        }
    }

    Context 'Uninstall-MwpModulePackage' {
        It 'odrzuca odinstalowanie modułów bazowych Core i Remote' {
            foreach ($id in 'Core', 'Remote') {
                $result = Uninstall-MwpModulePackage -Id $id -Confirm:$false
                $result.Success | Should -BeFalse
                $result.Message | Should -Match 'bazowy'
            }
            Join-Path -Path $builtIn -ChildPath 'MWP.Remote\MWP.Remote.psd1' | Should -Exist
        }

        It 'odrzuca odinstalowanie modułu wbudowanego i nieznanego' {
            $result = Uninstall-MwpModulePackage -Id 'Services' -Confirm:$false
            $result.Success | Should -BeFalse
            $result.Message | Should -Match 'wbudowany'
            Join-Path -Path $builtIn -ChildPath 'MWP.Services\MWP.Services.psd1' | Should -Exist

            (Uninstall-MwpModulePackage -Id 'BrakModulu' -Confirm:$false).Success | Should -BeFalse
        }

        It 'jest operacją destrukcyjną (ConfirmImpact High)' {
            $attribute = (Get-Command -Name Uninstall-MwpModulePackage).ScriptBlock.Attributes |
                Where-Object { $_ -is [Management.Automation.CmdletBindingAttribute] }
            [string]$attribute.ConfirmImpact | Should -Be 'High'
        }

        It '-WhatIf niczego nie usuwa' {
            $null = Install-MwpModulePackage -Path $validPackage

            $result = Uninstall-MwpModulePackage -Id 'Probe' -WhatIf

            $result.IsPreview | Should -BeTrue
            Join-Path -Path $installedRoot -ChildPath 'MWP.Probe' | Should -Exist
            @(Get-MwpInstalledModule).Count | Should -Be 1
        }

        It 'zamyka instancje modułu, usuwa folder, konfigurację modułu i wpis w rejestrze; logi zostają' {
            $null = Install-MwpModulePackage -Path $validPackage
            $data = Get-Content -LiteralPath $localPath -Raw -Encoding UTF8 | ConvertFrom-Json
            $data | Add-Member -NotePropertyName modules -NotePropertyValue ([pscustomobject]@{ Probe = [pscustomobject]@{ filtr = 'x' }; Inny = [pscustomobject]@{ a = 1 } }) -Force
            $data | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $localPath -Encoding UTF8
            $instance = New-MwpModuleInstance -ModuleId 'Probe'
            $other = New-MwpModuleInstance -ModuleId 'Services'
            $null = Initialize-MwpModuleInstance -Instance $instance

            $result = Uninstall-MwpModulePackage -Id 'Probe' -Confirm:$false

            $result.Success | Should -BeTrue -Because $result.Message
            $result.Data.ClosedInstances | Should -Be 1
            $instance.Status | Should -Be 'Closed'
            $other.Status | Should -Be 'Created'
            Get-Module -Name MWP.Probe | Should -BeNullOrEmpty
            Join-Path -Path $installedRoot -ChildPath 'MWP.Probe' | Should -Not -Exist
            @(Get-MwpInstalledModule).Count | Should -Be 0
            $modules = Get-MwpSetting -Name modules
            @($modules.Keys) | Should -Be @('Inny')
            Get-MwpModuleDefinition -Name 'Probe' | Should -BeNullOrEmpty
            @(Get-ChildItem -LiteralPath (Join-Path -Path $TestDrive -ChildPath 'Logs') -Filter '*.log').Count | Should -BeGreaterThan 0
            Get-Leftover | Should -BeNullOrEmpty
        }

        It 'usuwa widgety modułu z zapisanej konfiguracji Dashboardu, a widgety innych modułów zostają (D-031)' {
            $null = Install-MwpModulePackage -Path $validPackage
            $widgets = @(
                [ordered]@{ id = 'w-probe-1'; moduleId = 'Probe'; widgetId = 'Stan'; computerName = 'localhost'; refreshSeconds = 60; size = 'Normal' }
                [ordered]@{ id = 'w-system'; moduleId = 'Dashboard'; widgetId = 'SystemInfo'; computerName = 'localhost'; refreshSeconds = 0; size = 'Wide' }
                [ordered]@{ id = 'w-probe-2'; moduleId = 'Probe'; widgetId = 'Stan'; computerName = 'PC-ZDALNY'; refreshSeconds = 300; size = 'Normal' }
            )
            (Set-MwpDashboardConfiguration -Widget $widgets -Confirm:$false).Success | Should -BeTrue

            $result = Uninstall-MwpModulePackage -Id 'Probe' -Confirm:$false

            $result.Success | Should -BeTrue -Because $result.Message
            $result.Data.RemovedWidgets | Should -Be 2
            $result.Message | Should -Match 'usunięte widgety Dashboardu: 2'
            @((Get-MwpDashboardConfiguration).Widgets | ForEach-Object { $_.id }) | Should -Be @('w-system')
        }

        It 'bez widgetów modułu nie zapisuje listy widgetów (zostaje szablon)' {
            $null = Install-MwpModulePackage -Path $validPackage

            $result = Uninstall-MwpModulePackage -Id 'Probe' -Confirm:$false

            $result.Data.RemovedWidgets | Should -Be 0
            (Get-MwpDashboardConfiguration).IsDefault | Should -BeTrue
        }

        It 'po odinstalowaniu ten sam moduł można zainstalować ponownie' {
            $null = Install-MwpModulePackage -Path $validPackage
            $null = Uninstall-MwpModulePackage -Id 'Probe' -Confirm:$false

            (Install-MwpModulePackage -Path $validPackage).Success | Should -BeTrue
        }

        It 'błąd zapisu rejestru przy odinstalowaniu przywraca folder modułu' {
            $null = Install-MwpModulePackage -Path $validPackage
            Mock -ModuleName MWP.Core Write-MwpLocalSetting { throw 'awaria dysku (test)' }

            $result = Uninstall-MwpModulePackage -Id 'Probe' -Confirm:$false

            $result.Success | Should -BeFalse
            Join-Path -Path $installedRoot -ChildPath 'MWP.Probe\MWP.Probe.psd1' | Should -Exist
            @(Get-MwpInstalledModule).Count | Should -Be 1
            Get-Leftover | Should -BeNullOrEmpty
        }

        It 'odrzuca odinstalowanie modułu wymaganego przez inny zainstalowany moduł' {
            $null = Install-MwpModulePackage -Path $validPackage
            $dependent = Write-TestPackage -FileName 'zalezny.mwpmod' -Entries (Get-ModuleFile -Name 'Second' -Dependencies "@(@{ Id = 'Probe'; MinimumVersion = '1.0.0' })")
            (Install-MwpModulePackage -Path $dependent).Success | Should -BeTrue

            $result = Uninstall-MwpModulePackage -Id 'Probe' -Confirm:$false

            $result.Success | Should -BeFalse
            $result.Message | Should -Match 'MWP.Second'
        }
    }
}
