#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
    Testy launchera Start-MyWindowsPower.ps1. Launcher jest uruchamiany w osobnym procesie
    tej samej wersji PowerShella, w której działają testy (5.1 albo 7.x).
    Launcher niczego nie zmienia w systemie, więc testy są bezpieczne. Testy używają -NoGui
    (bez okna WPF, FAZA 4); okno sprawdza się ręcznie na Windows 11.
    Launcher zapisuje dziennik startu (D-042), dlatego każde uruchomienie dotyczy kopii aplikacji
    w TestDrive (log w <kopia>\data\logs), a LOCALAPPDATA procesu launchera wskazuje katalog
    tymczasowy testu: testy nie zapisują do data\ ani config\ repozytorium ani do prawdziwego
    %LOCALAPPDATA%\MyWindowsPower.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Zmienne z bloków BeforeDiscovery/BeforeAll są używane w blokach It (zakresy Pestera).')]
param()

BeforeAll {
    $repository = Split-Path -Parent $PSScriptRoot
    $launcher = Join-Path -Path $repository -ChildPath 'Start-MyWindowsPower.ps1'
    $hostPath = (Get-Process -Id $PID).Path
    . (Join-Path -Path $repository -ChildPath 'src\UI\Functions\Read-MwpLogEntry.ps1')
    $sensitiveName = '(?i)(password|passwd|pwd|haslo|hasło|secret|token|credential|apikey|api_key)'

    function Copy-LauncherApp {
        # Kopia aplikacji (launcher, src\Modules bez modułów z paczek, szablon ustawień) w TestDrive.
        param([Parameter(Mandatory)] [string] $Name)

        $app = Join-Path -Path $TestDrive -ChildPath $Name
        $null = New-Item -ItemType Directory -Path (Join-Path -Path $app -ChildPath 'src') -Force
        $null = New-Item -ItemType Directory -Path (Join-Path -Path $app -ChildPath 'config') -Force
        Copy-Item -LiteralPath $launcher -Destination $app
        Copy-Item -LiteralPath (Join-Path -Path $repository -ChildPath 'src\Modules') -Destination (Join-Path -Path $app -ChildPath 'src') -Recurse
        Remove-Item -LiteralPath (Join-Path -Path $app -ChildPath 'src\Modules\Installed') -Recurse -Force -ErrorAction SilentlyContinue
        Copy-Item -LiteralPath (Join-Path -Path $repository -ChildPath 'config\settings.example.json') -Destination (Join-Path -Path $app -ChildPath 'config')
        $app
    }

    function Invoke-Launcher {
        # Uruchamia launcher kopii aplikacji z -NoGui; LOCALAPPDATA procesu potomnego = <kopia>-LocalAppData.
        param(
            [Parameter(Mandatory)] [string] $App,
            [string[]] $HostArguments = @('-STA')
        )

        $localAppData = '{0}-LocalAppData' -f $App
        $null = New-Item -ItemType Directory -Path $localAppData -Force
        $original = $env:LOCALAPPDATA
        try {
            $env:LOCALAPPDATA = $localAppData
            $output = & $hostPath -NoProfile @HostArguments -File (Join-Path -Path $App -ChildPath 'Start-MyWindowsPower.ps1') -NoGui 2>&1 | ForEach-Object { "$_" }
            $exitCode = $LASTEXITCODE
        }
        finally {
            $env:LOCALAPPDATA = $original
        }
        [pscustomobject]@{
            ExitCode     = $exitCode
            Text         = $output -join [Environment]::NewLine
            LocalAppData = $localAppData
        }
    }

    function Get-LauncherLogPath {
        param([Parameter(Mandatory)] [string] $App)

        $logs = Join-Path -Path $App -ChildPath 'data\logs'
        if (-not (Test-Path -LiteralPath $logs)) {
            return $null
        }
        @(Get-ChildItem -LiteralPath $logs -Filter 'mwp-*.log' -File | Sort-Object -Property Name) | Select-Object -Last 1 -ExpandProperty FullName
    }

    function Get-StartupLogRecord {
        # Surowe wpisy Startup.* (z polem data) w kolejności zapisu.
        param([Parameter(Mandatory)] [string] $App)

        $path = Get-LauncherLogPath -App $App
        if ($null -eq $path) {
            return @()
        }
        $lines = [IO.File]::ReadAllLines($path, [Text.Encoding]::UTF8)
        @($lines | Where-Object { $_.Trim() -ne '' } | ForEach-Object { ConvertFrom-Json -InputObject $_ } |
                Where-Object { $_.operation -like 'Startup.*' })
    }

    function Get-PropertyName {
        # Nazwy wszystkich właściwości obiektu z ConvertFrom-Json (rekurencyjnie).
        param([AllowNull()] [object] $InputObject)

        if ($null -eq $InputObject -or $InputObject -is [string] -or $InputObject.GetType().IsValueType) {
            return
        }
        if ($InputObject -is [Collections.IEnumerable]) {
            foreach ($item in $InputObject) {
                Get-PropertyName -InputObject $item
            }
            return
        }
        foreach ($property in $InputObject.PSObject.Properties) {
            $property.Name
            Get-PropertyName -InputObject $property.Value
        }
    }

    function Add-ProbeModule {
        # Moduł testowy „z paczki” w <kopia>\src\Modules\Installed albo <kopia>\data\modules.
        param(
            [Parameter(Mandatory)] [string] $Directory,
            [Parameter(Mandatory)] [string] $Name,
            [string] $MinimumHostVersion = '0.3.0',
            [string] $Body = ''
        )

        $id = $Name -replace '^MWP\.', ''
        $function = 'Get-Mwp{0}ModuleInfo' -f $id
        $root = Join-Path -Path $Directory -ChildPath $Name
        $null = New-Item -ItemType Directory -Path $root -Force
        $manifest = @(
            '@{'
            "    RootModule = '$Name.psm1'"
            "    ModuleVersion = '1.0.0'"
            "    Description = 'Moduł testowy z paczki'"
            "    PowerShellVersion = '5.1'"
            "    FunctionsToExport = @('$function')"
            "    PrivateData = @{ MWP = @{ ContractVersion = 1; Id = '$id'; Name = 'Sonda'; EntryPoint = '$function'; MinimumHostVersion = '$MinimumHostVersion';"
            "        Dependencies = @(@{ Id = 'Core'; MinimumVersion = '0.3.0' }); Capabilities = @('Read'); SupportedPresentationModes = @('CLI');"
            "        RequiredPermissions = @('User'); ConfigurationSchema = @{} } }"
            '}'
        ) -join "`r`n"
        Set-Content -LiteralPath (Join-Path -Path $root -ChildPath "$Name.psd1") -Value $manifest -Encoding UTF8
        Set-Content -LiteralPath (Join-Path -Path $root -ChildPath "$Name.psm1") -Encoding UTF8 `
            -Value ("{0}function $function {{ '$Name' }}`r`nExport-ModuleMember -Function $function" -f $Body)
    }
}

Describe 'Start-MyWindowsPower.ps1' {
    It 'parsuje się bez błędów składni' {
        $errors = $null
        $null = [Management.Automation.Language.Parser]::ParseFile($launcher, [ref]$null, [ref]$errors)
        $errors | Should -BeNullOrEmpty
    }

    It 'pokazuje okno komunikatu tylko bez -NoGui (Show-LauncherError)' {
        $text = [IO.File]::ReadAllText($launcher, [Text.Encoding]::UTF8)
        $text | Should -Match 'if \(\$NoGui\) \{\s+return'
        @([regex]::Matches($text, 'Show-LauncherError -Message .+ -NoGui:\$NoGui')).Count | Should -BeGreaterOrEqual 4
        @([regex]::Matches($text, '\[System\.Windows\.MessageBox\]::Show')).Count | Should -Be 1
    }

    Context 'okno startowe (splash, D-042)' {
        BeforeAll {
            $splashScript = Join-Path -Path $repository -ChildPath 'src\UI\Splash.ps1'
            $splashXaml = Join-Path -Path $repository -ChildPath 'src\UI\Splash.xaml'
            $launcherText = [IO.File]::ReadAllText($launcher, [Text.Encoding]::UTF8)
        }

        It 'Splash.ps1 i Splash.xaml są w UTF-8 z BOM' {
            foreach ($path in @($splashScript, $splashXaml)) {
                $bytes = [IO.File]::ReadAllBytes($path)
                ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) | Should -BeTrue -Because $path
            }
        }

        It 'Splash.ps1 parsuje się, a Splash.xaml jest poprawnym XAML-em z nazwanymi kontrolkami' {
            $errors = $null
            $null = [Management.Automation.Language.Parser]::ParseFile($splashScript, [ref]$null, [ref]$errors)
            $errors | Should -BeNullOrEmpty
            [xml]$xml = [IO.File]::ReadAllText($splashXaml, [Text.Encoding]::UTF8)
            $xml.DocumentElement.LocalName | Should -Be 'Window'
            $xml.DocumentElement.WindowStyle | Should -Be 'None'
            foreach ($name in 'SplashVersion', 'SplashProgress', 'SplashStatus') {
                $launcherText + [IO.File]::ReadAllText($splashScript, [Text.Encoding]::UTF8) | Should -Match ([regex]::Escape("FindName('$name')"))
                $xml.OuterXml | Should -Match ('x:Name="{0}"' -f $name)
            }
        }

        It 'launcher pokazuje okno startowe tylko bez -NoGui i nie przerywa startu przy jego błędzie' {
            $launcherText | Should -Match '(?s)if \(-not \$NoGui\) \{\s+try \{.*?Splash\.ps1.*?Show-MwpSplash.*?\}\s+catch \{\s+\$script:launcherSplash = \$null\s+Add-LauncherSplashWarning'
            @([regex]::Matches($launcherText, 'Show-MwpSplash ')).Count | Should -Be 1
        }

        It 'przy -NoGui launcher nie ładuje WPF (brak okna startowego)' {
            $app = Copy-LauncherApp -Name 'BezOkna'
            Copy-Item -LiteralPath (Join-Path -Path $repository -ChildPath 'src\UI') -Destination (Join-Path -Path $app -ChildPath 'src') -Recurse
            # Zamiast Splash.ps1 — skrypt, który zostawia znacznik; przy -NoGui nie może się wykonać.
            $marker = Join-Path -Path $app -ChildPath 'splash-uruchomiony.txt'
            Set-Content -LiteralPath (Join-Path -Path $app -ChildPath 'src\UI\Splash.ps1') -Encoding UTF8 -Value ("Set-Content -LiteralPath '{0}' -Value 1" -f $marker)
            $run = Invoke-Launcher -App $app
            $run.ExitCode | Should -Be 0 -Because $run.Text
            $marker | Should -Not -Exist
        }

        It 'Get-MwpSplashTheme czyta theme z config\settings.local.json, a bez pliku używa motywu systemu' {
            . $splashScript
            $root = Join-Path -Path $TestDrive -ChildPath 'MotywSplash'
            $null = New-Item -ItemType Directory -Path (Join-Path -Path $root -ChildPath 'config') -Force
            $original = $env:LOCALAPPDATA
            try {
                $env:LOCALAPPDATA = Join-Path -Path $TestDrive -ChildPath 'MotywSplash-LocalAppData'
                Get-MwpSplashTheme -AppRoot $root | Should -Be (Get-MwpSystemTheme)
                Set-Content -LiteralPath (Join-Path -Path $root -ChildPath 'config\settings.local.json') -Value '{ "theme": "Dark" }' -Encoding UTF8
                Get-MwpSplashTheme -AppRoot $root | Should -Be 'Dark'
                Set-Content -LiteralPath (Join-Path -Path $root -ChildPath 'config\settings.local.json') -Value '{ uszkodzony' -Encoding UTF8
                Get-MwpSplashTheme -AppRoot $root | Should -Be (Get-MwpSystemTheme)
            }
            finally {
                $env:LOCALAPPDATA = $original
            }
        }
    }

    Context 'uruchomienie w trybie STA' {
        BeforeAll {
            $app = Copy-LauncherApp -Name 'Glowna'
            $result = Invoke-Launcher -App $app -HostArguments @('-STA')
            $records = @(Get-StartupLogRecord -App $app)
            $ok = @([regex]::Matches($result.Text, '\[OK\]')).Count
        }

        It 'kończy się kodem 0' {
            $result.ExitCode | Should -Be 0 -Because $result.Text
        }

        It 'wypisuje wersję PowerShella' {
            $result.Text | Should -Match ([regex]::Escape("PowerShell: $($PSVersionTable.PSVersion)"))
        }

        It 'wypisuje status administratora' {
            $result.Text | Should -Match 'Administrator: (tak|nie)'
        }

        It 'importuje wszystkie moduły wbudowane i z paczek bez błędów' {
            $builtIn = @(Get-ChildItem -Path (Join-Path -Path $repository -ChildPath 'src\Modules') -Directory -Filter 'MWP.*').Count
            $result.Text | Should -Not -Match '\[BŁĄD\]'
            $ok | Should -BeGreaterOrEqual $builtIn
            $result.Text | Should -Match ("Zaimportowano moduły: {0}\." -f $ok)
        }

        It 'w trybie -NoGui nie otwiera okna' {
            $result.Text | Should -Match 'Tryb bez okna \(-NoGui\)'
        }

        It 'zapisuje w logu kopii aplikacji dokładnie 2 wpisy Startup.* (Startup.Window dopiero przy oknie)' {
            $path = Get-LauncherLogPath -App $app
            $path | Should -Not -BeNullOrEmpty
            $entries = @(Read-MwpLogEntry -Path $path | Where-Object { $_.Operation -like 'Startup.*' })
            $entries.Count | Should -Be 2
            # Read-MwpLogEntry zwraca od najnowszego.
            $entries[0].Operation | Should -Be 'Startup.Modules'
            $entries[1].Operation | Should -Be 'Startup.Environment'
            $entries | ForEach-Object { $_.Source | Should -Be 'Launcher'; $_.Computer | Should -Be 'localhost' }
        }

        It 'Startup.Environment zawiera dane środowiska i parametry launchera' {
            $environment = @($records | Where-Object { $_.operation -eq 'Startup.Environment' })[0]
            $environment.level | Should -Be 'Info'
            $environment.message | Should -Match ([regex]::Escape("PowerShell $($PSVersionTable.PSVersion)"))
            $environment.data.PSVersion | Should -Be ([string]$PSVersionTable.PSVersion)
            $environment.data.PSEdition | Should -Be $PSVersionTable.PSEdition
            $environment.data.ApartmentState | Should -Be 'STA'
            $environment.data.IsWindows11 | Should -BeTrue
            $environment.data.IsAdmin | Should -BeOfType [bool]
            $environment.data.HostPath | Should -Be $hostPath
            $environment.data.AppRoot | Should -Be $app
            $environment.data.HostVersion | Should -Match '^\d+\.\d+\.\d+'
            $environment.data.Parameters.NoGui | Should -BeTrue
            $environment.data.Parameters.Elevate | Should -BeFalse
            $environment.data.Relaunched | Should -BeFalse
        }

        It 'Startup.Modules ma czytelne podsumowanie, a szczegóły modułów w Data' {
            $summary = @($records | Where-Object { $_.operation -eq 'Startup.Modules' })[0]
            $summary.level | Should -Be 'Info'
            $summary.message | Should -Match ("^Załadowano moduły: {0} \(z paczek: 0\) w \d+ ms\.$" -f $ok)
            $summary.data.Loaded | Should -Be $ok
            $summary.data.Failed | Should -Be 0
            @($summary.data.Modules).Count | Should -Be $ok
            @($summary.data.Modules)[0].Name | Should -Be 'MWP.Core'
            foreach ($module in $summary.data.Modules) {
                $module.Name | Should -Match '^MWP\.'
                $module.Version | Should -Match '^\d+\.\d+'
                $module.Source | Should -Be 'Built-in'
                $module.ImportMs | Should -BeGreaterOrEqual 0
                $module.Status | Should -Be 'Loaded'
            }
        }

        It 'wpisy startowe nie zawierają sekretów' {
            $records.Count | Should -Be 2
            $names = @(foreach ($record in $records) { Get-PropertyName -InputObject $record.data })
            $names.Count | Should -BeGreaterThan 10
            @($names | Where-Object { $_ -match $sensitiveName }) | Should -BeNullOrEmpty
            ($records | ConvertTo-Json -Depth 8) | Should -Not -Match '\[UKRYTE\]'
        }

        It 'nie tworzy awaryjnego pliku ani niczego w LOCALAPPDATA' {
            Join-Path -Path $result.LocalAppData -ChildPath 'MyWindowsPower' | Should -Not -Exist
        }
    }

    Context 'uruchomienie w trybie MTA' {
        BeforeAll {
            $app = Copy-LauncherApp -Name 'Mta'
            $result = Invoke-Launcher -App $app -HostArguments @('-MTA')
            $records = @(Get-StartupLogRecord -App $app)
        }

        It 'uruchamia się ponownie z -STA i kończy kodem 0' {
            $result.Text | Should -Match 'Ponowne uruchomienie z parametrem -STA'
            $result.Text | Should -Match 'Tryb wątku: STA'
            $result.ExitCode | Should -Be 0
        }

        It 'zapisuje ponowne uruchomienie i jego powód w Startup.Environment (Warning)' {
            $environment = @($records | Where-Object { $_.operation -eq 'Startup.Environment' })
            $environment.Count | Should -Be 1
            $environment[0].level | Should -Be 'Warning'
            $environment[0].data.Relaunched | Should -BeTrue
            $environment[0].data.RelaunchReason | Should -Match 'MTA'
            $environment[0].data.ApartmentState | Should -Be 'STA'
            $environment[0].data.Parameters.NoRelaunch | Should -BeTrue
        }
    }

    Context 'moduł zainstalowany z paczki (src\Modules\Installed, D-031)' {
        BeforeAll {
            # Kopia aplikacji na TestDrive: instalacja nie dotyka folderu repozytorium.
            $app = Copy-LauncherApp -Name 'Aplikacja'
            $builtInCount = @(Get-ChildItem -LiteralPath (Join-Path -Path $app -ChildPath 'src\Modules') -Directory -Filter 'MWP.*').Count

            Add-ProbeModule -Directory (Join-Path -Path $app -ChildPath 'src\Modules\Installed') -Name 'MWP.Probe'
            $installedResult = Invoke-Launcher -App $app

            # Ten sam moduł pod inną nazwą w katalogu danych aplikacji (<app>\data\modules, D-038).
            Add-ProbeModule -Directory (Join-Path -Path $app -ChildPath 'data\modules') -Name 'MWP.DataProbe'
            $dataResult = Invoke-Launcher -App $app
            $summary = @(Get-StartupLogRecord -App $app | Where-Object { $_.operation -eq 'Startup.Modules' }) | Select-Object -Last 1
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

        It 'Startup.Modules liczy moduły z paczek i oznacza ich źródło' {
            $summary.message | Should -Match ("^Załadowano moduły: {0} \(z paczek: 2\)" -f ($builtInCount + 2))
            $installed = @($summary.data.Modules | Where-Object { $_.Source -eq 'Installed' })
            @($installed | ForEach-Object { $_.Name } | Sort-Object) | Should -Be @('MWP.DataProbe', 'MWP.Probe')
            $installed | ForEach-Object { $_.Version | Should -Be '1.0.0' }
        }
    }

    Context 'wadliwe moduły z paczki (D-042)' {
        BeforeAll {
            $app = Copy-LauncherApp -Name 'Wadliwa'
            $installed = Join-Path -Path $app -ChildPath 'src\Modules\Installed'
            # Niepoprawny kontrakt (za nowa wersja hosta) i błąd importu (wyjątek w module).
            Add-ProbeModule -Directory $installed -Name 'MWP.Broken' -MinimumHostVersion '99.0.0'
            Add-ProbeModule -Directory $installed -Name 'MWP.Throws' -Body "throw 'awaria testowa modułu'`r`n"
            $result = Invoke-Launcher -App $app
            $records = @(Get-StartupLogRecord -App $app)
            $logPath = Get-LauncherLogPath -App $app
        }

        It 'kończy się kodem 1 z dotychczasowym komunikatem w konsoli' {
            $result.ExitCode | Should -Be 1
            $result.Text | Should -Match '\[BŁĄD\] MWP\.Broken'
            $result.Text | Should -Match '\[BŁĄD\] MWP\.Throws: .*awaria testowa'
            $result.Text | Should -Match 'Nie udało się zaimportować modułów: 2 z \d+\.'
        }

        It 'zapisuje osobny wpis Startup.Module na poziomie Error dla każdego wadliwego modułu' {
            $errors = @($records | Where-Object { $_.operation -eq 'Startup.Module' })
            $errors.Count | Should -Be 2
            $errors | ForEach-Object { $_.level | Should -Be 'Error'; $_.source | Should -Be 'Launcher' }
            $broken = @($errors | Where-Object { $_.data.Name -eq 'MWP.Broken' })[0]
            $broken.message | Should -Match '^Nie załadowano modułu MWP\.Broken: niepoprawny kontrakt'
            @($broken.data.ContractErrors).Count | Should -BeGreaterThan 0
            $broken.data.Source | Should -Be 'Installed'
            $throws = @($errors | Where-Object { $_.data.Name -eq 'MWP.Throws' })[0]
            $throws.data.Error | Should -Match 'awaria testowa'
            $throws.data.Status | Should -Be 'Failed'
        }

        It 'zachowuje kolejność zdarzeń: środowisko, błędy modułów, podsumowanie' {
            @($records | ForEach-Object { $_.operation }) | Should -Be @('Startup.Environment', 'Startup.Module', 'Startup.Module', 'Startup.Modules')
            $records[-1].level | Should -Be 'Warning'
            $records[-1].data.Failed | Should -Be 2
            $records[-1].message | Should -Match 'nie załadowano: MWP\.Broken, MWP\.Throws'
        }

        It 'filtr „Tylko ostrzeżenia i błędy” (Read-MwpLogEntry -MinimumLevel Warning) pokazuje błędy modułów' {
            $visible = @(Read-MwpLogEntry -Path $logPath -MinimumLevel Warning)
            @($visible | Where-Object { $_.Level -eq 'Error' -and $_.Operation -eq 'Startup.Module' }).Count | Should -Be 2
            @($visible | Where-Object { $_.Operation -eq 'Startup.Environment' }) | Should -BeNullOrEmpty
        }

        It 'nie tworzy awaryjnego pliku, bo MWP.Core działa' {
            Join-Path -Path $result.LocalAppData -ChildPath 'MyWindowsPower' | Should -Not -Exist
        }
    }

    Context 'nieudany import MWP.Core (plik awaryjny, D-042)' {
        BeforeAll {
            $app = Copy-LauncherApp -Name 'BezRdzenia'
            Set-Content -LiteralPath (Join-Path -Path $app -ChildPath 'src\Modules\MWP.Core\MWP.Core.psd1') -Value '@{ uszkodzony' -Encoding UTF8
            $result = Invoke-Launcher -App $app
            $failureLog = Join-Path -Path $result.LocalAppData -ChildPath 'MyWindowsPower\logs\mwp-startup-failure.log'
        }

        It 'kończy się kodem 1 z komunikatem w konsoli' {
            $result.ExitCode | Should -Be 1
            $result.Text | Should -Match '\[BŁĄD\] MWP\.Core'
        }

        It 'zapisuje jedną linię JSON w %LOCALAPPDATA%\MyWindowsPower\logs\mwp-startup-failure.log' {
            $failureLog | Should -Exist
            $lines = @([IO.File]::ReadAllLines($failureLog, [Text.Encoding]::UTF8) | Where-Object { $_.Trim() -ne '' })
            $lines.Count | Should -Be 1
            $entry = ConvertFrom-Json -InputObject $lines[0]
            @($entry.PSObject.Properties.Name) | Should -Be @('timestamp', 'level', 'operation', 'message')
            $entry.level | Should -Be 'Error'
            $entry.operation | Should -Be 'Startup.Module'
            $entry.message | Should -Match 'MWP\.Core'
        }

        It 'nie tworzy logu w katalogu danych kopii aplikacji' {
            Join-Path -Path $app -ChildPath 'data\logs' | Should -Not -Exist
        }
    }
}
