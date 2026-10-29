#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
    Testy modułu MWP.Apps (FAZA 12, D-050). winget to atrapa winget.cmd w TestDrive (mock Get-MwpAppsTargetConfig):
    zapisuje argumenty, wypisuje przygotowaną tabelę (w stronie kodowej OEM, jak prawdziwy winget przy przekierowanym
    wyjściu) i kończy się podanym kodem (także HRESULT 0x8A15…); po poleceniu może podmienić listę pakietów
    i inwentarz (stan „po instalacji” / „po odinstalowaniu”). Inwentarz i usuwanie Appx to atrapy bloków komputera
    docelowego (mock Get-MwpAppsScript) czytające i zmieniające plik JSON w TestDrive. Komputer zdalny — mock
    transportu WinRM. Testy nie instalują, nie aktualizują i nie usuwają prawdziwych programów; jedyny test na
    prawdziwym systemie tylko czyta rejestr (blok Inventory bez Appx).
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Zmienne z bloków BeforeDiscovery/BeforeAll są używane w blokach It (zakresy Pestera).')]
param()

Describe 'MWP.Apps — aplikacje i winget' {
    BeforeAll {
        $root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
        foreach ($name in 'MWP.Core', 'MWP.Remote', 'MWP.Apps') {
            Import-Module -Name (Join-Path -Path $root -ChildPath "src\Modules\$name\$name.psd1") -Force
        }
        $configDirectory = Join-Path -Path $TestDrive -ChildPath 'config'
        $null = New-Item -ItemType Directory -Path $configDirectory -Force
        Copy-Item -LiteralPath (Join-Path -Path $root -ChildPath 'config\settings.example.json') -Destination (Join-Path -Path $configDirectory -ChildPath 'settings.example.json')
        Mock -ModuleName MWP.Core Get-MwpDataPath {
            $name = Get-Variable -Name Kind -ValueOnly -ErrorAction SilentlyContinue
            $path = if ($name -and $name -ne 'Root') { Join-Path -Path $TestDrive -ChildPath $name } else { [string]$TestDrive }
            if (Get-Variable -Name Detailed -ValueOnly -ErrorAction SilentlyContinue) { [pscustomobject]@{ Path = $path; Root = $TestDrive; Configured = ''; IsFallback = $false; Warning = $null } } else { $path }
        }
        Mock -ModuleName MWP.Core Get-MwpConfigPath {
            [pscustomobject]@{
                Example    = Join-Path -Path $TestDrive -ChildPath 'config\settings.example.json'
                Local      = Join-Path -Path $TestDrive -ChildPath 'config\settings.local.json'
                IsFallback = $false
            }
        }
        $remoteName = 'PC-TEST1'
        $local = [ordered]@{ schemaVersion = 2; targets = @(@{ name = $remoteName; authentication = 'CurrentUser' }) }
        ConvertTo-Json -InputObject $local -Depth 5 | Set-Content -LiteralPath (Join-Path -Path $configDirectory -ChildPath 'settings.local.json') -Encoding UTF8

        # Atrapa winget: argumenty do args.txt; <polecenie>.txt na wyjście; <polecenie>.code = kod wyjścia;
        # <polecenie>.next → list.txt i <polecenie>.inv → inventory.json (stan po zmianie).
        $script:Fake = Join-Path -Path $TestDrive -ChildPath 'winget'
        $null = New-Item -ItemType Directory -Path $script:Fake -Force
        $script:WingetPath = Join-Path -Path $script:Fake -ChildPath 'winget.cmd'
        Set-Content -LiteralPath $script:WingetPath -Encoding Ascii -Value @(
            '@echo off'
            'setlocal'
            ('set "D={0}"' -f $script:Fake)
            '>>"%D%\args.txt" echo %*'
            'set "C=%~1"'
            'if "%C%"=="--version" set "C=version"'
            'if exist "%D%\%C%.next" copy /y "%D%\%C%.next" "%D%\list.txt" >nul'
            'if exist "%D%\%C%.inv" copy /y "%D%\%C%.inv" "%D%\inventory.json" >nul'
            'if exist "%D%\%C%.txt" type "%D%\%C%.txt"'
            'set "CODE=0"'
            'if exist "%D%\%C%.code" set /p CODE=<"%D%\%C%.code"'
            'exit /b %CODE%'
        )
        $script:ConfiguredWinget = $script:WingetPath
        Mock -ModuleName MWP.Apps Get-MwpAppsTargetConfig {
            [pscustomobject]@{
                Source = 'winget'; WingetPath = $script:ConfiguredWinget; ReadTimeoutSeconds = 60; ChangeTimeoutSeconds = 60; SearchCount = 50
                RuntimePatterns = @('Microsoft Visual C++*Redistributable*', 'Microsoft .NET*Runtime*', 'Microsoft.VCRedist.*', 'Microsoft.DotNet.*')
            }
        }
        $oemCodePage = [int](Get-ItemProperty -LiteralPath 'Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Nls\CodePage' -Name 'OEMCP').OEMCP
        $script:Oem = [Text.Encoding]::GetEncoding($oemCodePage)

        function Write-FakeWinget {
            param([string] $Command, [string[]] $Line, [long] $Code = 0, [string[]] $Next, [object] $Inventory)
            [IO.File]::WriteAllText((Join-Path -Path $script:Fake -ChildPath "$Command.txt"), (($Line -join "`r`n") + "`r`n"), $script:Oem)
            # Kod HRESULT jako liczba ze znakiem (tak jak exit /b w cmd).
            $signed = if ($Code -gt [int]::MaxValue) { $Code - 0x100000000L } else { $Code }
            Set-Content -LiteralPath (Join-Path -Path $script:Fake -ChildPath "$Command.code") -Value ([string]$signed) -Encoding Ascii
            if ($PSBoundParameters.ContainsKey('Next')) {
                [IO.File]::WriteAllText((Join-Path -Path $script:Fake -ChildPath "$Command.next"), (($Next -join "`r`n") + "`r`n"), $script:Oem)
            }
            if ($PSBoundParameters.ContainsKey('Inventory')) {
                [IO.File]::WriteAllText((Join-Path -Path $script:Fake -ChildPath "$Command.inv"), (ConvertTo-Json -Depth 6 -InputObject $Inventory), [Text.Encoding]::UTF8)
            }
        }
        function Get-FakeArgument {
            $path = Join-Path -Path $script:Fake -ChildPath 'args.txt'
            if (Test-Path -LiteralPath $path) { @(Get-Content -LiteralPath $path) } else { @() }
        }
        # Tabela jak w winget: kolumny szerokości najdłuższej wartości + spacja, linia kresek.
        function Get-ListLine {
            param([object[]] $Row, [string[]] $Header = @('Name', 'Id', 'Version', 'Available'))
            $all = @(, $Header) + @($Row)
            $widths = @(for ($c = 0; $c -lt $Header.Count; $c++) { ($all | ForEach-Object { ([string]@($_)[$c]).Length } | Measure-Object -Maximum).Maximum })
            $format = { param($cells) (@(for ($c = 0; $c -lt $Header.Count; $c++) { ([string]@($cells)[$c]).PadRight($widths[$c] + 1) }) -join '').TrimEnd() }
            @((& $format $Header), ('-' * (($widths | Measure-Object -Sum).Sum + $Header.Count))) + @($Row | ForEach-Object { & $format $_ })
        }

        # Inwentarz komputera „testowego”: rejestr (komputer 64/32 bit, użytkownik) i Appx.
        function Get-FakeInventory {
            param([switch] $WithoutGit, [switch] $WithoutCamera, [bool] $Admin = $true)
            $registry = @(
                [pscustomobject]@{ KeyName = 'Git_is1'; Scope = 'Machine'; Architecture = 'X64'; UserSid = ''; UserName = ''; DisplayName = 'Git'; DisplayVersion = '2.55.0.3'; Publisher = 'The Git Development Community'; InstallDate = '20260115'; InstallLocation = 'C:\Program Files\Git'; EstimatedSizeKb = 350000; HasUninstall = $true; HasQuiet = $true; WindowsInstaller = $false; SystemComponent = $false; NoRemove = $false; ParentKeyName = ''; ReleaseType = '' }
                [pscustomobject]@{ KeyName = 'Edytor Pro'; Scope = 'Machine'; Architecture = 'X86'; UserSid = ''; UserName = ''; DisplayName = 'Edytor Łódź'; DisplayVersion = '1.0'; Publisher = 'Firma Żółw'; InstallDate = ''; InstallLocation = ''; EstimatedSizeKb = 0; HasUninstall = $true; HasQuiet = $false; WindowsInstaller = $false; SystemComponent = $false; NoRemove = $false; ParentKeyName = ''; ReleaseType = '' }
                [pscustomobject]@{ KeyName = 'Microsoft Edge'; Scope = 'Machine'; Architecture = 'X86'; UserSid = ''; UserName = ''; DisplayName = 'Microsoft Edge'; DisplayVersion = '156.0.1'; Publisher = 'Microsoft Corporation'; InstallDate = '20261001'; InstallLocation = ''; EstimatedSizeKb = 0; HasUninstall = $true; HasQuiet = $false; WindowsInstaller = $false; SystemComponent = $false; NoRemove = $false; ParentKeyName = ''; ReleaseType = '' }
                [pscustomobject]@{ KeyName = '{VC-2015}'; Scope = 'Machine'; Architecture = 'X64'; UserSid = ''; UserName = ''; DisplayName = 'Microsoft Visual C++ 2015 Redistributable (x64)'; DisplayVersion = '14.0.1'; Publisher = 'Microsoft Corporation'; InstallDate = '20250101'; InstallLocation = ''; EstimatedSizeKb = 20000; HasUninstall = $true; HasQuiet = $false; WindowsInstaller = $true; SystemComponent = $false; NoRemove = $false; ParentKeyName = ''; ReleaseType = '' }
                [pscustomobject]@{ KeyName = '{HIDDEN}'; Scope = 'Machine'; Architecture = 'X64'; UserSid = ''; UserName = ''; DisplayName = 'Składnik ukryty'; DisplayVersion = '1.0'; Publisher = 'Microsoft Corporation'; InstallDate = ''; InstallLocation = ''; EstimatedSizeKb = 0; HasUninstall = $true; HasQuiet = $false; WindowsInstaller = $true; SystemComponent = $true; NoRemove = $false; ParentKeyName = ''; ReleaseType = '' }
                [pscustomobject]@{ KeyName = 'KB1'; Scope = 'Machine'; Architecture = 'X64'; UserSid = ''; UserName = ''; DisplayName = 'Poprawka dla Git'; DisplayVersion = '1'; Publisher = ''; InstallDate = ''; InstallLocation = ''; EstimatedSizeKb = 0; HasUninstall = $true; HasQuiet = $false; WindowsInstaller = $false; SystemComponent = $false; NoRemove = $false; ParentKeyName = 'Git_is1'; ReleaseType = 'Update' }
                [pscustomobject]@{ KeyName = 'Narzedzie'; Scope = 'User'; Architecture = 'X64'; UserSid = 'S-1-5-21-1-2-3-1001'; UserName = 'PC\anna'; DisplayName = 'Narzędzie Anny'; DisplayVersion = '3.1'; Publisher = 'Anna'; InstallDate = '20260501'; InstallLocation = ''; EstimatedSizeKb = 2048; HasUninstall = $true; HasQuiet = $false; WindowsInstaller = $false; SystemComponent = $false; NoRemove = $false; ParentKeyName = ''; ReleaseType = '' }
                [pscustomobject]@{ KeyName = 'Moje'; Scope = 'User'; Architecture = 'X64'; UserSid = 'S-1-5-21-1-2-3-1000'; UserName = 'PC\test'; DisplayName = 'Moje narzędzie'; DisplayVersion = '0.9'; Publisher = 'Ja'; InstallDate = ''; InstallLocation = ''; EstimatedSizeKb = 0; HasUninstall = $true; HasQuiet = $false; WindowsInstaller = $false; SystemComponent = $false; NoRemove = $false; ParentKeyName = ''; ReleaseType = '' }
            )
            if ($WithoutGit) {
                $registry = @($registry | Where-Object { $_.KeyName -ne 'Git_is1' })
            }
            $appx = @(
                [pscustomobject]@{ Name = 'Microsoft.WindowsCamera'; DisplayName = 'Aparat'; PackageFullName = 'Microsoft.WindowsCamera_2026.1.0.0_x64__8wekyb3d8bbwe'; PackageFamilyName = 'Microsoft.WindowsCamera_8wekyb3d8bbwe'; Publisher = 'CN=Microsoft Corporation, O=Microsoft Corporation, L=Redmond, S=Washington, C=US'; Version = '2026.1.0.0'; Architecture = 'X64'; SignatureKind = 'Store'; IsFramework = $false; IsResourcePackage = $false; IsBundle = $false; NonRemovable = $false; InstallLocation = 'C:\Program Files\WindowsApps\Microsoft.WindowsCamera' }
                [pscustomobject]@{ Name = 'Microsoft.WindowsStore'; DisplayName = 'Microsoft Store'; PackageFullName = 'Microsoft.WindowsStore_22609.1.0.0_x64__8wekyb3d8bbwe'; PackageFamilyName = 'Microsoft.WindowsStore_8wekyb3d8bbwe'; Publisher = 'CN=Microsoft Corporation, O=Microsoft Corporation'; Version = '22609.1.0.0'; Architecture = 'X64'; SignatureKind = 'Store'; IsFramework = $false; IsResourcePackage = $false; IsBundle = $false; NonRemovable = $false; InstallLocation = '' }
                [pscustomobject]@{ Name = 'Microsoft.VCLibs.140.00'; DisplayName = ''; PackageFullName = 'Microsoft.VCLibs.140.00_14.0.1_x64__8wekyb3d8bbwe'; PackageFamilyName = 'Microsoft.VCLibs.140.00_8wekyb3d8bbwe'; Publisher = 'CN=Microsoft Corporation'; Version = '14.0.1'; Architecture = 'X64'; SignatureKind = 'Store'; IsFramework = $true; IsResourcePackage = $false; IsBundle = $false; NonRemovable = $false; InstallLocation = '' }
                [pscustomobject]@{ Name = 'Microsoft.Windows.ShellExperienceHost'; DisplayName = ''; PackageFullName = 'Microsoft.Windows.ShellExperienceHost_10.0_neutral_neutral_cw5n1h2txyewy'; PackageFamilyName = 'Microsoft.Windows.ShellExperienceHost_cw5n1h2txyewy'; Publisher = 'CN=Microsoft Windows'; Version = '10.0'; Architecture = 'Neutral'; SignatureKind = 'System'; IsFramework = $false; IsResourcePackage = $false; IsBundle = $false; NonRemovable = $true; InstallLocation = '' }
            )
            if ($WithoutCamera) {
                $appx = @($appx | Where-Object { $_.Name -ne 'Microsoft.WindowsCamera' })
            }
            [pscustomobject]@{
                Kind = 'MWP.AppInventoryRaw'; ComputerName = 'PC'; CollectedAt = '2026-10-29T10:00:00Z'; IsAdministrator = $Admin; CurrentUser = 'PC\test'; CurrentUserSid = 'S-1-5-21-1-2-3-1000'
                Registry = $registry; Appx = $appx
                Profiles = @([pscustomobject]@{ Sid = 'S-1-5-21-1-2-3-1000'; Name = 'PC\test'; IsCurrent = $true }, [pscustomobject]@{ Sid = 'S-1-5-21-1-2-3-1001'; Name = 'PC\anna'; IsCurrent = $false })
                Warnings = @(); Error = $null
            }
        }
        function Write-FakeInventory {
            param([object] $Inventory)
            [IO.File]::WriteAllText((Join-Path -Path $script:Fake -ChildPath 'inventory.json'), (ConvertTo-Json -Depth 6 -InputObject $Inventory), [Text.Encoding]::UTF8)
        }
        $inventoryPath = Join-Path -Path $script:Fake -ChildPath 'inventory.json'
        $requestPath = Join-Path -Path $script:Fake -ChildPath 'request.json'
        $script:FakeInventoryBlock = [scriptblock]::Create(("param([string] `$RequestJson) Set-Content -LiteralPath '{0}' -Value `$RequestJson -Encoding UTF8; Get-Content -LiteralPath '{1}' -Raw -Encoding UTF8" -f $requestPath, $inventoryPath))
        $script:FakeRemoveBlock = [scriptblock]::Create((@(
                    'param([string] $PackageFullName)'
                    ('$path = ''{0}''' -f $inventoryPath)
                    '$data = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json'
                    '$existed = @($data.Appx | Where-Object { $_.PackageFullName -eq $PackageFullName }).Count -gt 0'
                    '$data.Appx = @($data.Appx | Where-Object { $_.PackageFullName -ne $PackageFullName })'
                    '[IO.File]::WriteAllText($path, (ConvertTo-Json -Depth 6 -InputObject $data), [Text.Encoding]::UTF8)'
                    'ConvertTo-Json -Compress -InputObject ([pscustomobject]@{ Kind = ''MWP.AppxRemoveRaw''; Existed = $existed; Remaining = $false; Error = $null })'
                ) -join [Environment]::NewLine))
        # Prawdziwe bloki zapamiętane przed mockiem (Winget uruchamia atrapę winget.cmd).
        $script:RealBlocks = @{}
        foreach ($blockName in 'Inventory', 'Winget', 'RemoveAppx') {
            $script:RealBlocks[$blockName] = InModuleScope MWP.Apps -Parameters @{ Name = $blockName } { param($Name) Get-MwpAppsScript -Name $Name }
        }
        Mock -ModuleName MWP.Apps Get-MwpAppsScript {
            switch ($Name) {
                'Inventory' { $script:FakeInventoryBlock }
                'RemoveAppx' { $script:FakeRemoveBlock }
                default { $script:RealBlocks[$Name] }
            }
        }

        $script:ListGit = Get-ListLine -Row @(
            , @('Git', 'Git.Git', '2.55.0.3', '2.56.0.3')
            , @('Microsoft Edge', 'Microsoft.Edge', '156.0.1', '')
            , @('Microsoft Visual C++ 2015 Redistributable (x64)', 'Microsoft.VCRedist.2015+.x64', '14.0.1', '')
        )
        $script:Search = Get-ListLine -Header 'Name', 'Id', 'Version', 'Match' -Row @(
            , @('7-Zip', '7zip.7zip', '26.05', 'Moniker: 7zip')
            , @('Git', 'Git.Git', '2.56.0.3', '')
        )
        function Get-AppsUndo {
            param([string] $ComputerName = 'localhost')
            @(Get-MwpUndoEntry -ComputerName $ComputerName -Status Pending | Where-Object { $_.Module -eq 'MWP.Apps' })
        }
        function Get-AppsLog {
            $path = Join-Path -Path $TestDrive -ChildPath 'Logs'
            @(Get-ChildItem -LiteralPath $path -Filter 'mwp-*.log' -ErrorAction SilentlyContinue | ForEach-Object { Get-Content -LiteralPath $_.FullName -Encoding UTF8 } | ForEach-Object { $_ | ConvertFrom-Json } | Where-Object { $_.source -eq 'MWP.Apps' })
        }
    }

    BeforeEach {
        Get-ChildItem -LiteralPath $script:Fake | Where-Object { $_.Name -ne 'winget.cmd' } | Remove-Item -Force
        $script:ConfiguredWinget = $script:WingetPath
        Write-FakeInventory -Inventory (Get-FakeInventory)
        Write-FakeWinget -Command 'version' -Line @('v1.29.380')
        Write-FakeWinget -Command 'list' -Line $script:ListGit
    }

    AfterAll {
        Remove-Module -Name MWP.Apps, MWP.Remote, MWP.Core -Force -ErrorAction SilentlyContinue
    }

    Context 'parsowanie tabel winget (niezależne od języka i szerokości kolumn)' {
        It 'lista: kolumny z nagłówka, Id lokalne ze spacją, puste Available, pominięte komunikaty, postęp i stopka' {
            $lines = @(
                "  -  `r  \  `r"
                'Failed when searching source; results will not be included: msstore'
                'Name                    Id                            Version       Available'
                '---------------------------------------------------------------------------------'
                'Google Chrome           ARP\Machine\X86\Google Chrome 156.0.8078.48'
                'Git                     Git.Git                       2.55.0.3      2.56.0.3'
                'Unity Hub 3.18.0        Unity.UnityHub                < 3.21.0.6    3.22.5'
                '3 upgrades available.'
            )
            $rows = @(ConvertFrom-MwpWingetOutput -Line $lines -Column Name, Id, Version, Available)
            $rows.Count | Should -Be 3
            $rows[0].Id | Should -Be 'ARP\Machine\X86\Google Chrome'
            $rows[0].IsLocalId | Should -BeTrue
            $rows[0].Available | Should -Be ''
            $rows[1].Name | Should -Be 'Git'
            $rows[1].Available | Should -Be '2.56.0.3'
            $rows[2].Version | Should -Be '< 3.21.0.6'
            $rows[0].PSObject.TypeNames | Should -Contain 'MWP.WingetRow'
        }

        It 'polski system: nagłówki po polsku (także dwuwyrazowy), polskie znaki i znaki szerokie (CJK) wyrównane jak w konsoli' {
            $lines = @(
                'Nazwa pakietu      Identyfikator     Wersja   Dostępne'
                '-------------------------------------------------------'
                'Łącze z telefonem  Microsoft.YourPh  1.2      1.3'
                '记事本工具          Example.Notes     2.0'
                'Zażółć gęślą jaźń  Pl.Test           0.1.2'
            )
            $rows = @(ConvertFrom-MwpWingetOutput -Line $lines -Column Name, Id, Version, Available)
            $rows.Count | Should -Be 3
            $rows[0].Name | Should -Be 'Łącze z telefonem'
            $rows[0].Id | Should -Be 'Microsoft.YourPh'
            $rows[0].Available | Should -Be '1.3'
            $rows[1].Name | Should -Be '记事本工具'
            $rows[1].Id | Should -Be 'Example.Notes'
            $rows[1].Version | Should -Be '2.0'
            $rows[2].Name | Should -Be 'Zażółć gęślą jaźń'
        }

        It 'wyszukiwanie: kolumna dopasowania, wąska tabela i linia o ucięciu wyników nie psują kolumn' {
            $lines = @(
                'Name   Id        Version Match'
                '------------------------------------'
                '7-Zip  7zip.7zip 26.05   Moniker: 7zip'
                'Cram   Nex.Cram  1.3.2   Tag: 7zip'
                '<additional entries truncated due to result limit>'
            )
            $rows = @(ConvertFrom-MwpWingetOutput -Line $lines -Column Name, Id, Version, Match)
            $rows.Count | Should -Be 2
            $rows[0].Id | Should -Be '7zip.7zip'
            $rows[0].Match | Should -Be 'Moniker: 7zip'
        }

        It 'kilka tabel (pakiety do jawnego wskazania) mają numer tabeli; wartość ucięta jest oznaczona' {
            $lines = @(
                'Name  Id      Version Available'
                '-------------------------------'
                'Git   Git.Git 2.55    2.56'
                ''
                'The following packages have an upgrade available, but require explicit targeting for upgrade:'
                'Name  Id         Version Available'
                '----------------------------------'
                ('Long' + [char]0x2026 + ' Long.Pkg   1.0     2.0')
            )
            $rows = @(ConvertFrom-MwpWingetOutput -Line $lines -Column Name, Id, Version, Available)
            $rows.Count | Should -Be 2
            $rows[1].Table | Should -Be 2
            $rows[1].Truncated | Should -BeTrue
            $rows[0].Truncated | Should -BeFalse
        }

        It 'brak tabeli albo puste wyjście daje pustą listę' {
            @(ConvertFrom-MwpWingetOutput -Line @('No package found matching input criteria.')).Count | Should -Be 0
            @(ConvertFrom-MwpWingetOutput -Line @()).Count | Should -Be 0
        }
    }

    Context 'lista programów (rejestr i Appx), ochrona, filtry i łączenie z winget' {
        It 'programy z rejestru i pakiety Appx: identyfikatory, Id lokalne winget, data, rozmiar, zakres i składniki systemowe' {
            $result = Get-MwpInstalledApp
            $result.Success | Should -BeTrue -Because $result.Message
            $apps = @($result.Data.Apps)
            $git = $apps | Where-Object { $_.Name -eq 'Git' }
            $git.Id | Should -Be 'Registry:Machine:X64::Git_is1'
            $git.WingetLocalId | Should -Be 'ARP\Machine\X64\Git_is1'
            $git.InstallDate | Should -Be ([datetime]'2026-01-15')
            $git.SizeText | Should -Match 'MB'
            $git.UninstallMethod | Should -Be 'Winget'
            ($apps | Where-Object { $_.Name -eq 'Edytor Łódź' }).WingetLocalId | Should -Be 'ARP\Machine\X86\Edytor Pro'
            $camera = $apps | Where-Object { $_.PackageName -eq 'Microsoft.WindowsCamera' }
            $camera.Name | Should -Be 'Aparat'
            $camera.Publisher | Should -Be 'Microsoft Corporation'
            $camera.WingetLocalId | Should -Be 'MSIX\Microsoft.WindowsCamera_2026.1.0.0_x64__8wekyb3d8bbwe'
            $camera.UninstallMethod | Should -Be 'Appx'
            ($apps | Where-Object { $_.Name -eq 'Składnik ukryty' }).IsSystem | Should -BeTrue
            ($apps | Where-Object { $_.Name -eq 'Poprawka dla Git' }).IsSystem | Should -BeTrue
            ($apps | Where-Object { $_.PackageName -eq 'Microsoft.VCLibs.140.00' }).IsSystem | Should -BeTrue
            @($result.Data.Profiles).Count | Should -Be 2
            # Lokalnie: programy bieżącego konta, Appx, bez wskazanych profili.
            $request = Get-Content -LiteralPath $requestPath -Raw | ConvertFrom-Json
            $request.CurrentUser | Should -BeTrue
            $request.IncludeAppx | Should -BeTrue
        }

        It 'lista ochronna i składniki systemu: Edge, Store, struktura, podpis System, SystemComponent i aktualizacja; środowisko uruchomieniowe tylko z ostrzeżeniem' {
            $apps = @((Get-MwpInstalledApp).Data.Apps)
            ($apps | Where-Object { $_.Source -eq 'Registry' -and $_.Name -eq 'Microsoft Edge' }).ProtectedReason | Should -Match 'Edge'
            ($apps | Where-Object { $_.PackageName -eq 'Microsoft.WindowsStore' }).IsProtected | Should -BeTrue
            ($apps | Where-Object { $_.PackageName -eq 'Microsoft.VCLibs.140.00' }).ProtectedReason | Should -Match 'struktury'
            ($apps | Where-Object { $_.PackageName -eq 'Microsoft.Windows.ShellExperienceHost' }).ProtectedReason | Should -Match 'System'
            ($apps | Where-Object { $_.Name -eq 'Składnik ukryty' }).ProtectedReason | Should -Match 'SystemComponent'
            ($apps | Where-Object { $_.Name -eq 'Poprawka dla Git' }).ProtectedReason | Should -Match 'Aktualizacja'
            $vc = $apps | Where-Object { $_.Name -like 'Microsoft Visual C++*' }
            $vc.IsProtected | Should -BeFalse
            $vc.Warning | Should -Match 'uruchomieniowe'
            ($apps | Where-Object { $_.Name -eq 'Git' }).IsProtected | Should -BeFalse
        }

        It 'filtry i sortowanie: składniki systemowe ukryte domyślnie, wyszukiwanie, źródło, zakres, tylko z aktualizacją, rozmiar malejąco' {
            $apps = @((Get-MwpInstalledApp).Data.Apps)
            $null = Join-MwpAppWinget -App $apps -Package (Resolve-MwpWingetPackage -Data (Get-MwpWingetPackage).Data).Packages
            $visible = @($apps | Select-MwpInstalledApp)
            $visible.Name | Should -Not -Contain 'Składnik ukryty'
            @($apps | Select-MwpInstalledApp -IncludeSystemComponent).Count | Should -Be $apps.Count
            @($apps | Select-MwpInstalledApp -Search 'ŁÓDŹ').Name | Should -Be 'Edytor Łódź'
            @($apps | Select-MwpInstalledApp -Search 'git.git').Name | Should -Be 'Git'
            @($apps | Select-MwpInstalledApp -Source Appx).Name | Should -Be @('Aparat', 'Microsoft Store')
            @($apps | Select-MwpInstalledApp -Scope User).Name | Should -Be @('Aparat', 'Microsoft Store', 'Moje narzędzie', 'Narzędzie Anny')
            @($apps | Select-MwpInstalledApp -UpgradeOnly).Name | Should -Be 'Git'
            @($apps | Select-MwpInstalledApp -SortBy Size -Descending)[0].Name | Should -Be 'Git'
        }

        It 'łączenie z winget: identyfikator źródła i dostępna wersja po nazwie i wersji; identyfikator winget też podlega liście ochronnej' {
            $apps = @((Get-MwpInstalledApp).Data.Apps)
            $list = (Get-MwpWingetPackage).Data
            $null = Join-MwpAppWinget -App $apps -Package $list.Packages
            $git = $apps | Where-Object { $_.Name -eq 'Git' }
            $git.WingetId | Should -Be 'Git.Git'
            $git.Available | Should -Be '2.56.0.3'
            ($apps | Where-Object { $_.Source -eq 'Registry' -and $_.Name -eq 'Microsoft Edge' }).WingetId | Should -Be 'Microsoft.Edge'
            ($apps | Where-Object { $_.Name -like 'Microsoft Visual C++*' }).WingetId | Should -Be 'Microsoft.VCRedist.2015+.x64'
            ($apps | Where-Object { $_.Name -eq 'Edytor Łódź' }).WingetId | Should -Be ''
        }

        It '-AsOperation zwraca operację w tle; Resolve-MwpInstalledApp czyta surowy JSON i przepuszcza gotowy inwentarz' {
            $operation = Get-MwpInstalledApp -AsOperation
            $operation.PSObject.TypeNames | Should -Contain 'MWP.Operation'
            $result = Wait-MwpOperation -Operation $operation
            $inventory = Resolve-MwpInstalledApp -Data $result
            @($inventory.Apps).Count | Should -BeGreaterThan 5
            (Resolve-MwpInstalledApp -Data $inventory) | Should -Be $inventory
            Resolve-MwpInstalledApp -Data 'nie-json' | Should -BeNullOrEmpty
        }

        It 'prawdziwy blok Inventory (tylko odczyt rejestru tego komputera, bez Appx) zwraca dane zgodne z kontraktem' {
            $raw = & $script:RealBlocks.Inventory '{"CurrentUser":true,"UserSids":[],"IncludeAppx":false}' | ConvertFrom-Json
            $raw.Kind | Should -Be 'MWP.AppInventoryRaw'
            $raw.Error | Should -BeNullOrEmpty
            @($raw.Registry).Count | Should -BeGreaterThan 0
            @($raw.Registry | Where-Object { $_.Scope -eq 'Machine' }).Count | Should -BeGreaterThan 0
            $raw.CurrentUserSid | Should -Match '^S-1-5-21-'
        }
    }

    Context 'winget: wykrycie, lista, aktualizacje, wyszukiwanie' {
        It 'wykrycie: wersja i ścieżka; brak winget = Available false z komunikatem' {
            $info = Get-MwpWingetInfo
            $info.Data.Available | Should -BeTrue
            $info.Data.Version | Should -Be '1.29.380'
            $script:ConfiguredWinget = Join-Path -Path $TestDrive -ChildPath 'brak\winget.exe'
            $missing = Get-MwpWingetInfo
            $missing.Success | Should -BeTrue
            $missing.Data.Available | Should -BeFalse
            $missing.Message | Should -Match 'niedostępny'
        }

        It 'lista i aktualizacje: argumenty ze źródłem winget i --disable-interactivity, bez akceptacji umów; „nie znaleziono” = pusta lista' {
            $list = Get-MwpWingetPackage
            $list.Success | Should -BeTrue
            @($list.Data.Packages).Count | Should -Be 3
            @(Get-FakeArgument)[-1] | Should -Be 'list --source winget --disable-interactivity'
            $null = Get-MwpWingetPackage -UpgradeAvailable
            @(Get-FakeArgument)[-1] | Should -Be 'list --source winget --upgrade-available --disable-interactivity'
            (Get-FakeArgument) -join ' ' | Should -Not -Match 'accept'
            Write-FakeWinget -Command 'list' -Line @('No installed package found matching input criteria.') -Code 0x8A150014L
            $empty = Get-MwpWingetPackage -Id 'Brak.Pakietu'
            $empty.Success | Should -BeTrue
            @($empty.Data.Packages).Count | Should -Be 0
        }

        It 'polski system: nagłówki po polsku i polskie znaki w stronie kodowej OEM są czytane poprawnie przez cały łańcuch' {
            Write-FakeWinget -Command 'list' -Line (Get-ListLine -Header 'Nazwa', 'Identyfikator', 'Wersja', 'Dostępne' -Row @(, @('Edytor Łódź', 'Firma.Edytor', '1.0', '1.1')))
            $result = Get-MwpWingetPackage
            $result.Success | Should -BeTrue
            $result.Data.Packages[0].Name | Should -Be 'Edytor Łódź'
            $result.Data.Packages[0].Available | Should -Be '1.1'
            $apps = @((Get-MwpInstalledApp).Data.Apps)
            $null = Join-MwpAppWinget -App $apps -Package $result.Data.Packages
            ($apps | Where-Object { $_.Name -eq 'Edytor Łódź' }).WingetId | Should -Be 'Firma.Edytor'
        }

        It 'błąd winget: kod HRESULT z opisem po polsku i ostatnią linią wyjścia; niepoprawny identyfikator odrzucony przed wywołaniem' {
            Write-FakeWinget -Command 'list' -Line @('Failed in attempting to update the source: winget') -Code 0x8A15000FL
            $result = Get-MwpWingetPackage
            $result.Success | Should -BeFalse
            $result.Message | Should -Match '0x8A15000F'
            $result.Message | Should -Match 'Failed in attempting'
            { Get-MwpWingetPackage -Id 'zły"id' } | Should -Throw
            { Get-MwpWingetPackage -Id 'Git.Git --force' } | Should -Throw
        }

        It 'wyszukiwanie: zapytanie ze spacją jako jeden argument, liczba wyników; niepoprawne zapytanie odrzucone' {
            Write-FakeWinget -Command 'search' -Line (Get-ListLine -Header 'Name', 'Id', 'Version', 'Match' -Row @(, @('Notepad++', 'Notepad++.Notepad++', '8.9', 'Tag: notepad')))
            $result = Find-MwpWingetPackage -Query 'notepad plus' -Count 5
            $result.Success | Should -BeTrue
            $result.Data.Kind | Should -Be 'Search'
            $result.Data.Packages[0].Id | Should -Be 'Notepad++.Notepad++'
            @(Get-FakeArgument)[-1] | Should -Be 'search "notepad plus" --source winget --count 5 --disable-interactivity'
            { Find-MwpWingetPackage -Query 'a"; calc' } | Should -Throw
            $operation = Find-MwpWingetPackage -Query '7zip' -AsOperation
            (Resolve-MwpWingetPackage -Kind Search -Data (Wait-MwpOperation -Operation $operation)).Kind | Should -Be 'Search'
        }
    }

    Context 'instalacja i aktualizacja pojedyncza' {
        BeforeEach {
            Write-FakeWinget -Command 'search' -Line $script:Search
            Write-FakeWinget -Command 'install' -Line @('Successfully installed') -Next (Get-ListLine -Row @(, @('7-Zip', '7zip.7zip', '26.05', '')))
            Write-FakeWinget -Command 'upgrade' -Line @('Successfully installed') -Next (Get-ListLine -Row @(, @('Git', 'Git.Git', '2.56.0.3', '')))
        }

        It 'instalacja -WhatIf: podgląd z wersją i zgodą na umowy, bez wywołania install' {
            $result = Install-MwpWingetPackage -Id '7zip.7zip' -WhatIf
            $result.IsPreview | Should -BeTrue
            $result.After | Should -Be '26.05'
            $result.Message | Should -Match 'umów'
            @(Get-FakeArgument | Where-Object { $_ -like 'install*' }).Count | Should -Be 0
        }

        It 'instalacja: winget install z akceptacją umów i --silent, ponowny odczyt, wpis cofnięcia (odinstalowanie) i log' {
            $result = Install-MwpWingetPackage -Id '7zip.7zip' -Confirm:$false
            $result.Success | Should -BeTrue -Because $result.Message
            $result.Changed | Should -BeTrue
            $result.After | Should -Be '26.05'
            @(Get-FakeArgument) | Should -Contain 'install --id 7zip.7zip --exact --source winget --silent --accept-package-agreements --accept-source-agreements --disable-interactivity'
            $undo = Get-AppsUndo | Where-Object { $_.Id -eq $result.UndoId }
            $undo.UndoCommand | Should -Be 'Uninstall-MwpApp'
            $undo.UndoParameters.WingetId | Should -Be '7zip.7zip'
            @(Get-AppsLog | Where-Object { $_.operation -eq 'Apps.Install' -and $_.message -match '7-Zip' }).Count | Should -BeGreaterOrEqual 2
        }

        It 'instalacja: pakiet już zainstalowany = bez zmian; brak pakietu w repozytorium i nieudana instalacja = błąd' {
            (Install-MwpWingetPackage -Id 'Git.Git' -Confirm:$false).Message | Should -Match 'Bez zmian'
            Write-FakeWinget -Command 'search' -Line @('No package found matching input criteria.') -Code 0x8A150014L
            (Install-MwpWingetPackage -Id 'Brak.Pakietu' -Confirm:$false).Message | Should -Match 'nie ma w repozytorium'
            Write-FakeWinget -Command 'search' -Line $script:Search
            Remove-Item -LiteralPath (Join-Path -Path $script:Fake -ChildPath 'install.next')
            Write-FakeWinget -Command 'install' -Line @('Installer failed with exit code: 1603') -Code 0x8A150006L
            $undoBefore = @(Get-AppsUndo).Count
            $failed = Install-MwpWingetPackage -Id '7zip.7zip' -Confirm:$false
            $failed.Success | Should -BeFalse
            $failed.Message | Should -Match '0x8A150006'
            @(Get-AppsUndo).Count | Should -Be $undoBefore
        }

        It 'aktualizacja: brak nowszej wersji = bez zmian; -WhatIf z wersjami; aktualizacja z ponownym odczytem, bez wpisu cofnięcia' {
            (Update-MwpWingetPackage -Id 'Microsoft.Edge' -Confirm:$false).Message | Should -Match 'Bez zmian'
            $preview = Update-MwpWingetPackage -Id 'Git.Git' -WhatIf
            $preview.IsPreview | Should -BeTrue
            $preview.Before | Should -Be '2.55.0.3'
            $preview.After | Should -Be '2.56.0.3'
            @(Get-FakeArgument | Where-Object { $_ -like 'upgrade*' }).Count | Should -Be 0
            $result = Update-MwpWingetPackage -Id 'Git.Git' -Confirm:$false
            $result.Success | Should -BeTrue -Because $result.Message
            $result.After | Should -Be '2.56.0.3'
            $result.UndoId | Should -BeNullOrEmpty
            @(Get-FakeArgument) | Should -Contain 'upgrade --id Git.Git --exact --source winget --silent --accept-package-agreements --accept-source-agreements --disable-interactivity'
            (Update-MwpWingetPackage -Id 'Nie.Ma' -Confirm:$false).Success | Should -BeFalse
        }
    }

    Context 'odinstalowanie: potwierdzenie, lista ochronna, log i cofnięcie' {
        It 'ConfirmImpact High; chronione (Store, Edge, składnik systemowy) — odmowa także z -Confirm:$false, bez wywołania winget' {
            (Get-Command -Name Uninstall-MwpApp).ScriptBlock.Attributes.Where({ $_ -is [System.Management.Automation.CmdletBindingAttribute] }).ConfirmImpact | Should -Be 'High'
            $apps = @((Get-MwpInstalledApp).Data.Apps)
            foreach ($app in @(
                    ($apps | Where-Object { $_.PackageName -eq 'Microsoft.WindowsStore' })
                    ($apps | Where-Object { $_.Source -eq 'Registry' -and $_.Name -eq 'Microsoft Edge' })
                    ($apps | Where-Object { $_.Name -eq 'Składnik ukryty' })
                )) {
                $result = Uninstall-MwpApp -AppId $app.Id -Confirm:$false
                $result.Success | Should -BeFalse
                $result.Message | Should -Match 'chroniona'
            }
            (Uninstall-MwpApp -WingetId 'Microsoft.Edge' -Confirm:$false).Success | Should -BeFalse
            @(Get-FakeArgument | Where-Object { $_ -like 'uninstall*' }).Count | Should -Be 0
        }

        It '-WhatIf: nazwa, wersja, wydawca, sposób i informacja o cofnięciu; nic nie usuwa i nie loguje zmiany' {
            $git = @((Get-MwpInstalledApp).Data.Apps) | Where-Object { $_.Name -eq 'Git' }
            $result = Uninstall-MwpApp -AppId $git.Id -WhatIf
            $result.IsPreview | Should -BeTrue
            $result.Message | Should -Match "'Git' w wersji 2.55.0.3 \(The Git Development Community\)"
            $result.Message | Should -Match 'ARP\\Machine\\X64\\Git_is1'
            $result.Message | Should -Match 'Cofnięcie: ponowna instalacja.*Git.Git'
            @(Get-FakeArgument | Where-Object { $_ -like 'uninstall*' }).Count | Should -Be 0
            @(Get-AppsLog | Where-Object { $_.operation -eq 'Apps.Uninstall' }).Count | Should -Be 0
        }

        It 'program z rejestru: winget uninstall Id lokalnym, sprawdzenie, log z nazwą, wersją i wydawcą, cofnięcie = instalacja z winget' {
            Write-FakeWinget -Command 'uninstall' -Line @('Successfully uninstalled') -Inventory (Get-FakeInventory -WithoutGit) -Next (Get-ListLine -Row @(, @('Microsoft Edge', 'Microsoft.Edge', '156.0.1', '')))
            $git = @((Get-MwpInstalledApp).Data.Apps) | Where-Object { $_.Name -eq 'Git' }
            $result = Uninstall-MwpApp -AppId $git.Id -Confirm:$false
            $result.Success | Should -BeTrue -Because $result.Message
            $result.Changed | Should -BeTrue
            $result.Before | Should -Be '2.55.0.3'
            @(Get-FakeArgument) | Should -Contain 'uninstall --id ARP\Machine\X64\Git_is1 --exact --silent --disable-interactivity'
            $log = @(Get-AppsLog | Where-Object { $_.operation -eq 'Apps.Uninstall' })
            $log.Count | Should -Be 2
            $log[-1].data.Name | Should -Be 'Git'
            $log[-1].data.Version | Should -Be '2.55.0.3'
            $log[-1].data.Publisher | Should -Be 'The Git Development Community'
            $undo = Get-AppsUndo | Where-Object { $_.Id -eq $result.UndoId }
            $undo.UndoCommand | Should -Be 'Install-MwpWingetPackage'
            $undo.UndoParameters.Id | Should -Be 'Git.Git'
            # Cofnięcie = ponowna instalacja z winget.
            Write-FakeWinget -Command 'search' -Line $script:Search
            Write-FakeWinget -Command 'install' -Line @('Successfully installed') -Next (Get-ListLine -Row @(, @('Git', 'Git.Git', '2.56.0.3', '')))
            $back = Invoke-MwpUndo -Id $result.UndoId -Confirm:$false
            $back.Success | Should -BeTrue -Because $back.Message
            @(Get-FakeArgument) | Should -Contain 'install --id Git.Git --exact --source winget --silent --accept-package-agreements --accept-source-agreements --disable-interactivity'
        }

        It 'Id lokalne ze spacją jest przekazywane jako jeden argument; program bez pakietu w winget — bez wpisu cofnięcia' {
            $inventory = Get-FakeInventory
            $inventory.Registry = @($inventory.Registry | Where-Object { $_.KeyName -ne 'Edytor Pro' })
            Write-FakeWinget -Command 'uninstall' -Line @('Successfully uninstalled') -Inventory $inventory
            $editor = @((Get-MwpInstalledApp).Data.Apps) | Where-Object { $_.Name -eq 'Edytor Łódź' }
            $result = Uninstall-MwpApp -AppId $editor.Id -Confirm:$false
            $result.Success | Should -BeTrue -Because $result.Message
            $result.UndoId | Should -BeNullOrEmpty
            @(Get-FakeArgument) | Should -Contain 'uninstall --id "ARP\Machine\X86\Edytor Pro" --exact --silent --disable-interactivity'
        }

        It 'pakiet Appx: Remove-AppxPackage konta sesji, bez wpisu cofnięcia; program nadal obecny = błąd' {
            $camera = @((Get-MwpInstalledApp).Data.Apps) | Where-Object { $_.PackageName -eq 'Microsoft.WindowsCamera' }
            $preview = Uninstall-MwpApp -AppId $camera.Id -WhatIf
            $preview.Message | Should -Match 'Remove-AppxPackage'
            $result = Uninstall-MwpApp -AppId $camera.Id -Confirm:$false
            $result.Success | Should -BeTrue -Because $result.Message
            $result.UndoId | Should -BeNullOrEmpty
            @((Get-MwpInstalledApp).Data.Apps | Where-Object { $_.PackageName -eq 'Microsoft.WindowsCamera' }).Count | Should -Be 0
            # winget kończy się bez błędu, ale program zostaje.
            Write-FakeWinget -Command 'uninstall' -Line @('Successfully uninstalled')
            $git = @((Get-MwpInstalledApp).Data.Apps) | Where-Object { $_.Name -eq 'Git' }
            $still = Uninstall-MwpApp -AppId $git.Id -Confirm:$false
            $still.Success | Should -BeFalse
            $still.Message | Should -Match 'nadal'
            @(Get-AppsLog | Where-Object { $_.operation -eq 'Apps.Uninstall' -and $_.level -eq 'Error' }).Count | Should -Be 1
        }

        It 'program innego profilu i nieistniejący identyfikator są odrzucane przed podglądem' {
            $inventory = Get-MwpInstalledApp -UserSid 'S-1-5-21-1-2-3-1001'
            $anna = @($inventory.Data.Apps) | Where-Object { $_.Name -eq 'Narzędzie Anny' }
            $result = Uninstall-MwpApp -AppId $anna.Id -WhatIf
            $result.Success | Should -BeFalse
            $result.Message | Should -Match 'PC\\anna'
            (Uninstall-MwpApp -AppId 'Registry:Machine:X64::Nie-ma' -WhatIf).Message | Should -Match 'nie ma już'
            { Uninstall-MwpApp -WingetId 'zły"id' -WhatIf } | Should -Throw
        }

        It 'winget niedostępny: programu z rejestru nie da się odinstalować (komunikat), pakiet Appx — tak' {
            $script:ConfiguredWinget = Join-Path -Path $TestDrive -ChildPath 'brak\winget.exe'
            $apps = @((Get-MwpInstalledApp).Data.Apps)
            $git = $apps | Where-Object { $_.Name -eq 'Git' }
            (Uninstall-MwpApp -AppId $git.Id -WhatIf).Message | Should -Match 'niedostępny'
            $camera = $apps | Where-Object { $_.PackageName -eq 'Microsoft.WindowsCamera' }
            (Uninstall-MwpApp -AppId $camera.Id -WhatIf).IsPreview | Should -BeTrue
        }
    }

    Context 'komputer zdalny (D-019, D-050)' {
        BeforeEach {
            $script:RemoteAdmin = $true
            Mock -ModuleName MWP.Remote Remove-MwpPSSession { }
            Mock -ModuleName MWP.Remote New-MwpPSSession { [pscustomobject]@{ ComputerName = $ComputerName; State = 'Opened' } }
            Mock -ModuleName MWP.Remote Invoke-MwpSessionCommand {
                $bound = (Get-Module -Name MWP.Remote).NewBoundScriptBlock($ScriptBlock)
                [pscustomobject]@{ Output = @(& $bound @ArgumentList); Errors = @() }
            }
            Mock -ModuleName MWP.Remote Invoke-MwpSessionCommand -ParameterFilter { $ScriptBlock.ToString() -match 'IsInRole' -and $ScriptBlock.ToString() -notmatch 'RequestJson' } {
                [pscustomobject]@{ Output = @($script:RemoteAdmin); Errors = @() }
            }
            $remote = New-MwpExecutionContext -ComputerName $remoteName
        }

        It 'lista przez sesję: bez programów konta połączenia, chyba że wskazano profil; wynik z nazwą komputera' {
            $result = Get-MwpInstalledApp -Context $remote
            $result.Success | Should -BeTrue -Because $result.Message
            $result.ComputerName | Should -Be $remoteName
            (Get-Content -LiteralPath $requestPath -Raw | ConvertFrom-Json).CurrentUser | Should -BeFalse
            $null = Get-MwpInstalledApp -Context $remote -UserSid 'S-1-5-21-1-2-3-1001'
            @((Get-Content -LiteralPath $requestPath -Raw | ConvertFrom-Json).UserSids) | Should -Be @('S-1-5-21-1-2-3-1001')
            (Get-MwpWingetPackage -Context $remote).Success | Should -BeTrue
        }

        It 'brak administratora w sesji zdalnej: odinstalowanie, instalacja i aktualizacja odrzucone przed podglądem (12)' {
            $script:RemoteAdmin = $false
            $git = @((Get-MwpInstalledApp -Context $remote).Data.Apps) | Where-Object { $_.Name -eq 'Git' }
            foreach ($result in @(
                    (Uninstall-MwpApp -AppId $git.Id -Context $remote -WhatIf)
                    (Install-MwpWingetPackage -Id '7zip.7zip' -Context $remote -WhatIf)
                    (Update-MwpWingetPackage -Id 'Git.Git' -Context $remote -WhatIf)
                )) {
                $result.Success | Should -BeFalse
                $result.Message | Should -Match 'administratora'
                $result.Message | Should -Match $remoteName
            }
        }

        It 'lista ochronna identyczna zdalnie; odinstalowanie z nazwą komputera w podglądzie, logu i wpisie cofnięcia' {
            $apps = @((Get-MwpInstalledApp -Context $remote).Data.Apps)
            (Uninstall-MwpApp -AppId ($apps | Where-Object { $_.PackageName -eq 'Microsoft.WindowsStore' }).Id -Context $remote -Confirm:$false).Success | Should -BeFalse
            $git = $apps | Where-Object { $_.Name -eq 'Git' }
            (Uninstall-MwpApp -AppId $git.Id -Context $remote -WhatIf).Message | Should -Match 'Odinstalowanie'
            Write-FakeWinget -Command 'uninstall' -Line @('Successfully uninstalled') -Inventory (Get-FakeInventory -WithoutGit)
            $result = Uninstall-MwpApp -AppId $git.Id -Context $remote -Confirm:$false
            $result.Success | Should -BeTrue -Because $result.Message
            $result.ComputerName | Should -Be $remoteName
            (Get-AppsUndo -ComputerName $remoteName | Where-Object { $_.Id -eq $result.UndoId }).ComputerName | Should -Be $remoteName
            @(Get-AppsLog | Where-Object { $_.operation -eq 'Apps.Uninstall' -and $_.computer -eq $remoteName }).Count | Should -Be 2
        }

        It 'utrata połączenia w trakcie odinstalowania: błąd tylko tej instancji, inny kontekst działa' {
            Mock -ModuleName MWP.Remote Invoke-MwpSessionCommand -ParameterFilter { $ScriptBlock.ToString() -match 'ProcessStartInfo' -and ($ArgumentList -join ' ') -match 'uninstall' } {
                throw (New-Object -TypeName Management.Automation.Remoting.PSRemotingTransportException -ArgumentList 'Połączenie zerwane')
            }
            $git = @((Get-MwpInstalledApp -Context $remote).Data.Apps) | Where-Object { $_.Name -eq 'Git' }
            $other = New-MwpExecutionContext
            $undoBefore = @(Get-AppsUndo -ComputerName $remoteName).Count
            $result = Uninstall-MwpApp -AppId $git.Id -Context $remote -Confirm:$false
            $result.Success | Should -BeFalse
            $result.Message | Should -Match 'błąd połączenia'
            $remote.Connection.State | Should -Be 'Disconnected'
            @(Get-AppsUndo -ComputerName $remoteName).Count | Should -Be $undoBefore
            (Get-MwpInstalledApp -Context $other).Success | Should -BeTrue
        }
    }

    Context 'kontrakt modułu i bloki komputera docelowego' {
        It 'manifest deklaruje komputer zdalny, tryby widoku i zgodny kontrakt' {
            $definition = @(Get-MwpModuleDefinition | Where-Object { $_.Id -eq 'Apps' })[0]
            $definition.IsValid | Should -BeTrue -Because ($definition.Errors -join '; ')
            $definition.Capabilities | Should -Contain 'RemoteTarget'
            $definition.Capabilities | Should -Contain 'Destructive'
            $definition.SupportedPresentationModes | Should -Contain 'Embedded'
        }

        It 'bloki parsują się bez błędów i nie używają składni tylko z 7.x' {
            foreach ($name in 'Inventory', 'Winget', 'RemoveAppx') {
                $block = $script:RealBlocks[$name]
                $errors = $null
                $null = [Management.Automation.Language.Parser]::ParseInput($block.ToString(), [ref]$null, [ref]$errors)
                $errors | Should -BeNullOrEmpty -Because $name
                $block.ToString() | Should -Not -Match '\?\?|\?\.'
            }
        }

        It 'identyfikatory winget: źródło bez spacji i cudzysłowów; lokalne ARP\ i MSIX\ tylko z -AllowLocal' {
            InModuleScope MWP.Apps {
                Test-MwpWingetId -Id 'Microsoft.VCRedist.2015+.x64' | Should -BeTrue
                Test-MwpWingetId -Id 'Git.Git --force' | Should -BeFalse
                Test-MwpWingetId -Id 'ARP\Machine\X86\Google Chrome' | Should -BeFalse
                Test-MwpWingetId -Id 'ARP\Machine\X86\Google Chrome' -AllowLocal | Should -BeTrue
                Test-MwpWingetId -Id 'ARP\Machine\X86\a"b' -AllowLocal | Should -BeFalse
                Test-MwpWingetId -Id 'ARP\Machine\X86\koniec\' -AllowLocal | Should -BeFalse
                Test-MwpWingetId -Id 'MSIX\Microsoft.WindowsCamera_2026.1.0.0_x64__8wekyb3d8bbwe' -AllowLocal | Should -BeTrue
            }
        }
    }
}
