#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
    Testy katalogu danych (D-032): Get-MwpDataPath, tryb zapasowy, ustawienia lokalne w trybie
    zapasowym, ponawianie zapisu logu przy blokadzie pliku.
    Folder aplikacji (Get-MwpProjectRoot) i LOCALAPPDATA wskazują na TestDrive (ścieżki ze spacjami
    i polskimi znakami); ostatni test sprawdza, że nic nie trafiło do prawdziwego profilu ani do
    folderu repozytorium.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Zmienne z bloków BeforeDiscovery/BeforeAll są używane w blokach It (zakresy Pestera).')]
param()

Describe 'Katalog danych aplikacji (D-032)' {
    BeforeAll {
        $root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
        Import-Module -Name (Join-Path -Path $root -ChildPath 'src\Modules\MWP.Core\MWP.Core.psd1') -Force

        function Get-DirectorySnapshot {
            param([string] $Path)
            if (-not (Test-Path -LiteralPath $Path)) {
                return '<brak>'
            }
            $lines = foreach ($item in @(Get-ChildItem -LiteralPath $Path -Recurse -Force)) {
                $size = if ($item.PSIsContainer) { 'd' } else { $item.Length }
                '{0}|{1}|{2:o}' -f $item.FullName, $size, $item.LastWriteTimeUtc
            }
            (@($lines) | Sort-Object) -join "`n"
        }

        # Stan prawdziwego profilu i folderu repozytorium przed testami.
        $realLocalAppData = $env:LOCALAPPDATA
        $realFallbackSnapshot = Get-DirectorySnapshot -Path (Join-Path -Path $realLocalAppData -ChildPath 'MyWindowsPower')
        $repoDataSnapshot = Get-DirectorySnapshot -Path (Join-Path -Path $root -ChildPath 'data')
        $repoConfigSnapshot = Get-DirectorySnapshot -Path (Join-Path -Path $root -ChildPath 'config')

        $appRoot = Join-Path -Path $TestDrive -ChildPath 'Moja aplikacja zażółć'
        $configDirectory = Join-Path -Path $appRoot -ChildPath 'config'
        $localSettings = Join-Path -Path $configDirectory -ChildPath 'settings.local.json'
        $testLocalAppData = Join-Path -Path $TestDrive -ChildPath 'Profil Łucja\AppData\Local'
        $fallbackRoot = Join-Path -Path $testLocalAppData -ChildPath 'MyWindowsPower'
        $null = New-Item -ItemType Directory -Path $configDirectory -Force
        $null = New-Item -ItemType Directory -Path $testLocalAppData -Force
        Copy-Item -LiteralPath (Join-Path -Path $root -ChildPath 'config\settings.example.json') -Destination (Join-Path -Path $configDirectory -ChildPath 'settings.example.json')
        $env:LOCALAPPDATA = $testLocalAppData

        Mock -ModuleName MWP.Core Get-MwpProjectRoot { $appRoot }

        function Write-LocalSetting {
            param([hashtable] $Values)
            $json = ConvertTo-Json -InputObject $Values
            [IO.File]::WriteAllText($localSettings, $json, (New-Object -TypeName System.Text.UTF8Encoding -ArgumentList $false))
        }
        function Resolve-TestDataPath {
            param([string] $Kind = 'Root')
            InModuleScope MWP.Core -Parameters @{ Kind = $Kind } {
                param($Kind)
                Get-MwpDataPath -Kind $Kind -Detailed
            }
        }
    }

    AfterAll {
        $env:LOCALAPPDATA = $realLocalAppData
        Remove-Module -Name MWP.Core -Force -ErrorAction SilentlyContinue
    }

    BeforeEach {
        InModuleScope MWP.Core {
            $script:MwpWritableDirectoryCache.Clear()
            $script:MwpDataPathWarningLogged.Clear()
        }
        foreach ($path in @($localSettings, (Join-Path -Path $appRoot -ChildPath 'data'), $fallbackRoot)) {
            Remove-Item -LiteralPath $path -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Context 'Get-MwpDataPath' {
        It 'domyślnie (dataPath pusty) zwraca podkatalog data folderu aplikacji i tworzy go bez pliku próbnego' {
            $result = Resolve-TestDataPath
            $result.Path | Should -Be (Join-Path -Path $appRoot -ChildPath 'data')
            $result.IsFallback | Should -BeFalse
            $result.Warning | Should -BeNullOrEmpty
            $result.Path | Should -Exist
            @(Get-ChildItem -LiteralPath $result.Path -Force) | Should -HaveCount 0
        }

        It 'podkatalogi logs i undo leżą w katalogu danych' {
            (Resolve-TestDataPath -Kind Logs).Path | Should -Be (Join-Path -Path $appRoot -ChildPath 'data\logs')
            (Resolve-TestDataPath -Kind Undo).Path | Should -Be (Join-Path -Path $appRoot -ChildPath 'data\undo')
        }

        It 'ścieżka względna jest liczona od folderu aplikacji, nie od bieżącego katalogu' {
            Write-LocalSetting @{ schemaVersion = 1; dataPath = 'Dane programu\MWP' }
            $other = Join-Path -Path $TestDrive -ChildPath 'inny katalog'
            $null = New-Item -ItemType Directory -Path $other -Force
            Push-Location -LiteralPath $other
            try {
                $result = Resolve-TestDataPath
            }
            finally {
                Pop-Location
            }
            $result.Path | Should -Be (Join-Path -Path $appRoot -ChildPath 'Dane programu\MWP')
            $result.IsFallback | Should -BeFalse
            Join-Path -Path $other -ChildPath 'Dane programu' | Should -Not -Exist
        }

        It 'ścieżka względna z .. jest normalizowana' {
            Write-LocalSetting @{ schemaVersion = 1; dataPath = '..\dane wspólne' }
            (Resolve-TestDataPath).Path | Should -Be (Join-Path -Path $TestDrive -ChildPath 'dane wspólne')
        }

        It 'ścieżka bezwzględna ze zmienną środowiskową jest rozwijana' {
            $env:MWP_TEST_DANE = Join-Path -Path $TestDrive -ChildPath 'Zmienna środowiskowa'
            try {
                Write-LocalSetting @{ schemaVersion = 1; dataPath = '%MWP_TEST_DANE%\Dane MWP' }
                $result = Resolve-TestDataPath
            }
            finally {
                Remove-Item -Path Env:\MWP_TEST_DANE -ErrorAction SilentlyContinue
            }
            $result.Path | Should -Be (Join-Path -Path $TestDrive -ChildPath 'Zmienna środowiskowa\Dane MWP')
            $result.Configured | Should -Be '%MWP_TEST_DANE%\Dane MWP'
            $result.IsFallback | Should -BeFalse
            $result.Path | Should -Exist
        }

        It 'ścieżka bezwzględna ze spacjami, polskimi znakami i nawiasami [ ] działa' {
            $target = Join-Path -Path $TestDrive -ChildPath 'Dane [kopia] ąćęłńóśźż'
            Write-LocalSetting @{ schemaVersion = 1; dataPath = $target }
            $result = Resolve-TestDataPath -Kind Logs
            $result.Path | Should -Be (Join-Path -Path $target -ChildPath 'logs')
            $result.IsFallback | Should -BeFalse
        }

        It 'ścieżka UNC jest zachowana' {
            $unc = '\\serwer\udział\Dane MWP'
            Mock -ModuleName MWP.Core Test-MwpDirectoryWritable { $true }
            Write-LocalSetting @{ schemaVersion = 1; dataPath = $unc }
            $result = Resolve-TestDataPath -Kind Undo
            $result.Root | Should -Be $unc
            $result.Path | Should -Be ($unc + '\undo')
            Should -Invoke -ModuleName MWP.Core Test-MwpDirectoryWritable -ParameterFilter { $Path -eq $unc } -Exactly -Times 1
        }

        It 'niezapisywalny katalog: tryb zapasowy %LOCALAPPDATA%\MyWindowsPower z ostrzeżeniem' {
            # W miejscu katalogu leży plik, więc katalogu nie da się utworzyć (prawdziwy błąd zapisu, bez mocka).
            $blocked = Join-Path -Path $TestDrive -ChildPath 'zajęte miejsce'
            Set-Content -LiteralPath $blocked -Value 'plik' -Encoding UTF8
            Write-LocalSetting @{ schemaVersion = 1; dataPath = $blocked }
            $result = Resolve-TestDataPath -Kind Logs
            $result.IsFallback | Should -BeTrue
            $result.Root | Should -Be $fallbackRoot
            $result.Path | Should -Be (Join-Path -Path $fallbackRoot -ChildPath 'logs')
            $result.Warning | Should -BeLike ("*'{0}'*niezapisywalny*{1}*" -f $blocked, $fallbackRoot)
        }

        It 'niezapisywalny folder aplikacji (domyślny dataPath) też daje tryb zapasowy' {
            Mock -ModuleName MWP.Core Test-MwpDirectoryWritable { $false }
            $result = Resolve-TestDataPath
            $result.IsFallback | Should -BeTrue
            $result.Root | Should -Be $fallbackRoot
        }

        It 'nieznana zmienna środowiskowa daje tryb zapasowy z ostrzeżeniem' {
            Write-LocalSetting @{ schemaVersion = 1; dataPath = '%MWP_BRAK_TAKIEJ_ZMIENNEJ%\dane' }
            $result = Resolve-TestDataPath
            $result.IsFallback | Should -BeTrue
            $result.Warning | Should -BeLike '*MWP_BRAK_TAKIEJ_ZMIENNEJ*'
            Join-Path -Path $appRoot -ChildPath '%MWP_BRAK_TAKIEJ_ZMIENNEJ%' | Should -Not -Exist
        }

        It 'ścieżka zależna od bieżącego dysku (<_>) daje tryb zapasowy' -ForEach @('C:dane', '\dane') {
            Write-LocalSetting @{ schemaVersion = 1; dataPath = $_ }
            (Resolve-TestDataPath).IsFallback | Should -BeTrue
        }

        It 'Test-MwpDirectoryWritable pamięta wynik do końca procesu' {
            $directory = Join-Path -Path $TestDrive -ChildPath 'sprawdzany'
            InModuleScope MWP.Core -Parameters @{ Directory = $directory } {
                param($Directory)
                Test-MwpDirectoryWritable -Path $Directory | Should -BeTrue
                Remove-Item -LiteralPath $Directory -Recurse -Force
                Test-MwpDirectoryWritable -Path $Directory | Should -BeTrue
                $script:MwpWritableDirectoryCache.ContainsKey($Directory) | Should -BeTrue
            }
            $directory | Should -Not -Exist
        }
    }

    Context 'Log i rejestr cofnięć w katalogu danych' {
        It 'Write-MwpLog i Save-MwpUndoEntry piszą domyślnie do podkatalogu data folderu aplikacji' {
            Write-MwpLog -Message 'wpis w folderze aplikacji' -Source 'Test'
            $undo = Save-MwpUndoEntry -Module 'MWP.Core' -Operation 'Test.Op' -Target 'cel' -UndoCommand 'Set-MwpSetting'
            $logFile = Join-Path -Path $appRoot -ChildPath ('data\logs\mwp-{0:yyyy-MM-dd}.log' -f (Get-Date))
            $logFile | Should -Exist
            (Get-Content -LiteralPath $logFile -Encoding UTF8 -Raw) | Should -BeLike '*wpis w folderze aplikacji*'
            $undo.Path | Should -Be (Join-Path -Path $appRoot -ChildPath ('data\undo\{0}.json' -f $undo.Id))
            $fallbackRoot | Should -Not -Exist
        }

        It 'w trybie zapasowym log ma ostrzeżenie DataPath.Fallback raz na proces' {
            $blocked = Join-Path -Path $TestDrive -ChildPath 'zajęte na log'
            Set-Content -LiteralPath $blocked -Value 'plik' -Encoding UTF8
            Write-LocalSetting @{ schemaVersion = 1; dataPath = $blocked }

            Write-MwpLog -Message 'pierwszy' -Source 'Test' -WarningVariable firstWarnings -WarningAction SilentlyContinue
            Write-MwpLog -Message 'drugi' -Source 'Test' -WarningVariable secondWarnings -WarningAction SilentlyContinue

            $logFile = Join-Path -Path $fallbackRoot -ChildPath ('logs\mwp-{0:yyyy-MM-dd}.log' -f (Get-Date))
            $entries = @(Get-Content -LiteralPath $logFile -Encoding UTF8 | ForEach-Object { $_ | ConvertFrom-Json })
            $entries | Should -HaveCount 3
            $entries[0].operation | Should -Be 'DataPath.Fallback'
            $entries[0].level | Should -Be 'Warning'
            $entries[0].message | Should -BeLike ('*{0}*' -f $blocked)
            $entries[1].message | Should -Be 'pierwszy'
            $entries[2].message | Should -Be 'drugi'
            @($firstWarnings) | Should -HaveCount 1
            @($secondWarnings) | Should -HaveCount 0
        }
    }

    Context 'Ustawienia lokalne w trybie zapasowym' {
        It 'niezapisywalny folder config: Set-MwpSetting zapisuje do %LOCALAPPDATA%\MyWindowsPower\settings.local.json' {
            Mock -ModuleName MWP.Core Test-MwpDirectoryWritable { $false } -ParameterFilter { $Path -eq $configDirectory }
            $result = Set-MwpSetting -Name logLevel -Value 'Warning' -WarningAction SilentlyContinue
            $result.Success | Should -BeTrue
            $fallbackSettings = Join-Path -Path $fallbackRoot -ChildPath 'settings.local.json'
            $fallbackSettings | Should -Exist
            $localSettings | Should -Not -Exist
            Get-MwpSetting -Name logLevel | Should -Be 'Warning'
            Remove-Item -LiteralPath $fallbackSettings -Force
        }

        It 'plik w folderze config ma pierwszeństwo przed plikiem zapasowym' {
            Write-LocalSetting @{ schemaVersion = 1; logLevel = 'Error' }
            $null = New-Item -ItemType Directory -Path $fallbackRoot -Force
            Set-Content -LiteralPath (Join-Path -Path $fallbackRoot -ChildPath 'settings.local.json') -Value '{ "schemaVersion": 1, "logLevel": "Debug" }' -Encoding UTF8
            Get-MwpSetting -Name logLevel | Should -Be 'Error'
        }

        It 'odczyt ustawień nie tworzy plików próbnych w folderze config' {
            Mock -ModuleName MWP.Core Test-MwpDirectoryWritable { $true }
            $null = Get-MwpSetting
            Should -Invoke -ModuleName MWP.Core Test-MwpDirectoryWritable -ParameterFilter { $Path -eq $configDirectory } -Exactly -Times 0
        }
    }

    Context 'Ponawianie zapisu logu przy blokadzie pliku' {
        BeforeAll {
            $logFile = Join-Path -Path $appRoot -ChildPath ('data\logs\mwp-{0:yyyy-MM-dd}.log' -f (Get-Date))
        }

        It 'chwilowa blokada (inny proces) nie gubi wpisu i nie daje ostrzeżenia' {
            Write-MwpLog -Message 'przed blokadą' -Source 'Test'
            $marker = Join-Path -Path $TestDrive -ChildPath ('blokada-{0}.txt' -f [guid]::NewGuid().ToString('N'))
            $job = Start-Job -ScriptBlock {
                $stream = [IO.File]::Open($using:logFile, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
                try {
                    [IO.File]::WriteAllText($using:marker, 'zablokowano')
                    Start-Sleep -Milliseconds 500
                }
                finally {
                    $stream.Dispose()
                }
            }
            try {
                $deadline = (Get-Date).AddSeconds(60)
                while (-not (Test-Path -LiteralPath $marker) -and (Get-Date) -lt $deadline -and $job.State -eq 'Running') {
                    Start-Sleep -Milliseconds 50
                }
                $marker | Should -Exist -Because 'zadanie w tle musi zablokować plik logu'
                Write-MwpLog -Message 'po blokadzie' -Source 'Test' -WarningVariable lockWarnings -WarningAction SilentlyContinue
            }
            finally {
                $null = $job | Wait-Job -Timeout 60
                $job | Remove-Job -Force
            }
            @($lockWarnings) | Should -HaveCount 0
            (Get-Content -LiteralPath $logFile -Encoding UTF8 | Select-Object -Last 1 | ConvertFrom-Json).message | Should -Be 'po blokadzie'
        }

        It 'trwała blokada: ostrzeżenie po wyczerpaniu prób, bez wyjątku' {
            Write-MwpLog -Message 'przed trwałą blokadą' -Source 'Test'
            $stream = [IO.File]::Open($logFile, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
            $thrown = $null
            try {
                Write-MwpLog -Message 'zablokowany' -Source 'Test' -WarningVariable lockWarnings -WarningAction SilentlyContinue
            }
            catch {
                $thrown = $_
            }
            finally {
                $stream.Dispose()
            }
            $thrown | Should -BeNullOrEmpty
            @($lockWarnings) | Should -HaveCount 1
            (Get-Content -LiteralPath $logFile -Encoding UTF8 -Raw) | Should -Not -BeLike '*zablokowany*'
        }
    }

    Context 'Izolacja testów' {
        It 'testy nie zapisały niczego w prawdziwym %LOCALAPPDATA%\MyWindowsPower ani w folderze repozytorium' {
            Get-DirectorySnapshot -Path (Join-Path -Path $realLocalAppData -ChildPath 'MyWindowsPower') | Should -Be $realFallbackSnapshot
            Get-DirectorySnapshot -Path (Join-Path -Path $root -ChildPath 'data') | Should -Be $repoDataSnapshot
            Get-DirectorySnapshot -Path (Join-Path -Path $root -ChildPath 'config') | Should -Be $repoConfigSnapshot
        }
    }
}
