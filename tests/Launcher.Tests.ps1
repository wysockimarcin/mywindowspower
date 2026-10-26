#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
    Testy launchera Start-MyWindowsPower.ps1. Launcher jest uruchamiany w osobnym procesie
    tej samej wersji PowerShella, w której działają testy (5.1 albo 7.x).
    Launcher niczego nie zmienia w systemie, więc testy są bezpieczne. Testy używają -NoGui
    (bez okna WPF, FAZA 4); okno sprawdza się ręcznie na Windows 11.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Zmienne z bloków BeforeDiscovery/BeforeAll są używane w blokach It (zakresy Pestera).')]
param()

BeforeAll {
    $launcher = Join-Path -Path (Split-Path -Parent $PSScriptRoot) -ChildPath 'Start-MyWindowsPower.ps1'
    $hostPath = (Get-Process -Id $PID).Path

    function Invoke-Launcher {
        param([string[]] $HostArguments = @())

        $output = & $hostPath -NoProfile @HostArguments -File $launcher -NoGui 2>&1 | ForEach-Object { "$_" }
        [pscustomobject]@{
            ExitCode = $LASTEXITCODE
            Text     = $output -join [Environment]::NewLine
        }
    }
}

Describe 'Start-MyWindowsPower.ps1' {
    It 'parsuje się bez błędów składni' {
        $errors = $null
        $null = [Management.Automation.Language.Parser]::ParseFile($launcher, [ref]$null, [ref]$errors)
        $errors | Should -BeNullOrEmpty
    }

    Context 'uruchomienie w trybie STA' {
        BeforeAll {
            $result = Invoke-Launcher -HostArguments @('-STA')
        }

        It 'kończy się kodem 0' {
            $result.ExitCode | Should -Be 0
        }

        It 'wypisuje wersję PowerShella' {
            $result.Text | Should -Match ([regex]::Escape("PowerShell: $($PSVersionTable.PSVersion)"))
        }

        It 'wypisuje status administratora' {
            $result.Text | Should -Match 'Administrator: (tak|nie)'
        }

        It 'importuje wszystkie moduły wbudowane i z paczek bez błędów' {
            $modules = Join-Path -Path (Split-Path -Parent $launcher) -ChildPath 'src\Modules'
            $builtIn = @(Get-ChildItem -Path $modules -Directory -Filter 'MWP.*').Count
            # Moduły z paczek zależą od katalogu danych użytkownika, więc liczba [OK] musi zgadzać się z podsumowaniem.
            $ok = @([regex]::Matches($result.Text, '\[OK\]')).Count
            $result.Text | Should -Not -Match '\[BŁĄD\]'
            $ok | Should -BeGreaterOrEqual $builtIn
            $result.Text | Should -Match ("Zaimportowano moduły: {0}\." -f $ok)
        }

        It 'w trybie -NoGui nie otwiera okna' {
            $result.Text | Should -Match 'Tryb bez okna \(-NoGui\)'
        }
    }

    Context 'uruchomienie w trybie MTA' {
        BeforeAll {
            $result = Invoke-Launcher -HostArguments @('-MTA')
        }

        It 'uruchamia się ponownie z -STA i kończy kodem 0' {
            $result.Text | Should -Match 'Ponowne uruchomienie z parametrem -STA'
            $result.Text | Should -Match 'Tryb wątku: STA'
            $result.ExitCode | Should -Be 0
        }
    }

    Context 'moduł zainstalowany z paczki (src\Modules\Installed, D-031)' {
        BeforeAll {
            # Kopia aplikacji na TestDrive: instalacja nie dotyka folderu repozytorium.
            $repository = Split-Path -Parent $launcher
            $app = Join-Path -Path $TestDrive -ChildPath 'Aplikacja'
            $null = New-Item -ItemType Directory -Path (Join-Path -Path $app -ChildPath 'src') -Force
            $null = New-Item -ItemType Directory -Path (Join-Path -Path $app -ChildPath 'config') -Force
            Copy-Item -LiteralPath $launcher -Destination $app
            Copy-Item -LiteralPath (Join-Path -Path $repository -ChildPath 'src\Modules') -Destination (Join-Path -Path $app -ChildPath 'src') -Recurse
            Remove-Item -LiteralPath (Join-Path -Path $app -ChildPath 'src\Modules\Installed') -Recurse -Force -ErrorAction SilentlyContinue
            Copy-Item -LiteralPath (Join-Path -Path $repository -ChildPath 'config\settings.example.json') -Destination (Join-Path -Path $app -ChildPath 'config')
            $builtInCount = @(Get-ChildItem -LiteralPath (Join-Path -Path $app -ChildPath 'src\Modules') -Directory -Filter 'MWP.*').Count

            $probe = Join-Path -Path $app -ChildPath 'src\Modules\Installed\MWP.Probe'
            $null = New-Item -ItemType Directory -Path $probe -Force
            $manifest = @(
                '@{'
                "    RootModule = 'MWP.Probe.psm1'"
                "    ModuleVersion = '1.0.0'"
                "    Description = 'Moduł testowy z paczki'"
                "    PowerShellVersion = '5.1'"
                "    FunctionsToExport = @('Get-MwpProbeModuleInfo')"
                "    PrivateData = @{ MWP = @{ ContractVersion = 1; Id = 'Probe'; Name = 'Sonda'; EntryPoint = 'Get-MwpProbeModuleInfo'; MinimumHostVersion = '0.3.0';"
                "        Dependencies = @(@{ Id = 'Core'; MinimumVersion = '0.3.0' }); Capabilities = @('Read'); SupportedPresentationModes = @('CLI');"
                "        RequiredPermissions = @('User'); ConfigurationSchema = @{} } }"
                '}'
            ) -join "`r`n"
            Set-Content -LiteralPath (Join-Path -Path $probe -ChildPath 'MWP.Probe.psd1') -Value $manifest -Encoding UTF8
            Set-Content -LiteralPath (Join-Path -Path $probe -ChildPath 'MWP.Probe.psm1') -Encoding UTF8 `
                -Value "function Get-MwpProbeModuleInfo { 'MWP.Probe' }`r`nExport-ModuleMember -Function Get-MwpProbeModuleInfo"

            $output = & $hostPath -NoProfile -STA -File (Join-Path -Path $app -ChildPath 'Start-MyWindowsPower.ps1') -NoGui 2>&1 | ForEach-Object { "$_" }
            $installedResult = [pscustomobject]@{ ExitCode = $LASTEXITCODE; Text = $output -join [Environment]::NewLine }

            # Ten sam moduł pod inną nazwą w katalogu danych aplikacji (<app>\data\modules, D-038).
            $dataProbe = Join-Path -Path $app -ChildPath 'data\modules\MWP.DataProbe'
            $null = New-Item -ItemType Directory -Path $dataProbe -Force
            Set-Content -LiteralPath (Join-Path -Path $dataProbe -ChildPath 'MWP.DataProbe.psd1') -Encoding UTF8 `
                -Value ($manifest -replace 'MWP\.Probe', 'MWP.DataProbe' -replace "Id = 'Probe'", "Id = 'DataProbe'" -replace 'Get-MwpProbeModuleInfo', 'Get-MwpDataProbeModuleInfo')
            Set-Content -LiteralPath (Join-Path -Path $dataProbe -ChildPath 'MWP.DataProbe.psm1') -Encoding UTF8 `
                -Value "function Get-MwpDataProbeModuleInfo { 'MWP.DataProbe' }`r`nExport-ModuleMember -Function Get-MwpDataProbeModuleInfo"
            $output = & $hostPath -NoProfile -STA -File (Join-Path -Path $app -ChildPath 'Start-MyWindowsPower.ps1') -NoGui 2>&1 | ForEach-Object { "$_" }
            $dataResult = [pscustomobject]@{ ExitCode = $LASTEXITCODE; Text = $output -join [Environment]::NewLine }
        }

        It 'importuje moduł zainstalowany po wbudowanych i kończy się kodem 0' {
            $installedResult.ExitCode | Should -Be 0 -Because $installedResult.Text
            $installedResult.Text | Should -Match 'MWP\.Probe \(z paczki\)'
            $installedResult.Text | Should -Match ("Zaimportowano moduły: {0}\." -f ($builtInCount + 1))
        }

        It 'importuje też moduł z katalogu danych (<app>\data\modules, D-038)' {
            $dataResult.ExitCode | Should -Be 0 -Because $dataResult.Text
            $dataResult.Text | Should -Match 'MWP\.DataProbe \(z paczki\)'
            $dataResult.Text | Should -Match 'MWP\.Probe \(z paczki\)'
            $dataResult.Text | Should -Match ("Zaimportowano moduły: {0}\." -f ($builtInCount + 2))
        }
    }
}
