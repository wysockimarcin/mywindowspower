#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
    Testy modułu MWP.Cleanup (FAZA 9, D-047) WYŁĄCZNIE na katalogach utworzonych w TestDrive: każda próba
    buduje „komputer” (Windows\Temp, ProgramData\…\WER, profile Users\anna i Users\jan, Kosz na „dysku”
    Drive1, folder Outside poza wszystkimi kategoriami), a dane komputera docelowego
    (Get-MwpCleanupEnvironment) są podmienione mockiem, więc kategorie wskazują tylko te katalogi.
    Sprawdzają: definicje kategorii (plik danych, biała lista ścieżek), zasady ścieżek (Test-MwpCleanupRoot),
    skan tylko do odczytu, -WhatIf i ConfirmImpact High (domyślnie nic nie jest usuwane bez potwierdzenia),
    usuwanie tylko w katalogach kategorii (junction do katalogu spoza nie jest przechodzony, dowiązanie
    w ścieżce katalogu głównego blokuje kategorię, lokalizacje chronione i pliki w użyciu są pomijane,
    ścieżka niekanoniczna w żądaniu jest odrzucana przez blok), raport, log bez wpisu cofnięcia,
    uprawnienia administratora, profile użytkowników, anulowanie, komputer zdalny (mock transportu WinRM)
    i utratę połączenia, analizę DISM (parsowanie, brak administratora, operacja w tle).
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Zmienne z bloków BeforeDiscovery/BeforeAll są używane w blokach It (zakresy Pestera).')]
param()

Describe 'MWP.Cleanup — czyszczenie dysku' {
    BeforeAll {
        $root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
        foreach ($name in 'MWP.Core', 'MWP.Remote', 'MWP.Cleanup') {
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

        # Bezpiecznik: DISM nigdy nie jest uruchamiany naprawdę.
        Mock -ModuleName MWP.Remote dism.exe { throw 'Uruchomienie DISM w testach jest zablokowane.' }
        Mock -ModuleName MWP.Cleanup dism.exe { throw 'Uruchomienie DISM w testach jest zablokowane.' }
        # Dane komputera docelowego: tylko katalogi z TestDrive.
        Mock -ModuleName MWP.Cleanup Get-MwpCleanupEnvironment { [pscustomobject]@{ Success = $true; Result = $null; Environment = $script:Machine.Environment } }

        $annaSid = 'S-1-5-21-1-2-3-1001'
        $janSid = 'S-1-5-21-1-2-3-1002'
        $context = New-MwpExecutionContext

        function Write-TestFile {
            param([string] $Path, [int] $Size = 100, [int] $AgeDays = 30)
            $null = [IO.Directory]::CreateDirectory((Split-Path -Parent $Path))
            [IO.File]::WriteAllBytes($Path, (New-Object -TypeName byte[] -ArgumentList $Size))
            $time = (Get-Date).AddDays(-$AgeDays)
            [IO.File]::SetCreationTime($Path, $time)
            [IO.File]::SetLastWriteTime($Path, $time)
        }
        function Initialize-FakeMachine {
            param([switch] $LinkedUsers)
            $base = Join-Path -Path $TestDrive -ChildPath ('pc-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
            $users = Join-Path -Path $base -ChildPath 'Users'
            $anna = Join-Path -Path $users -ChildPath 'anna'
            $jan = Join-Path -Path $users -ChildPath 'jan'
            $annaTemp = Join-Path -Path $anna -ChildPath 'AppData\Local\Temp'
            $paths = @{
                Base        = $base
                AnnaTemp    = $annaTemp
                JanTemp     = Join-Path -Path $jan -ChildPath 'AppData\Local\Temp'
                WindowsTemp = Join-Path -Path $base -ChildPath 'Windows\Temp'
                Explorer    = Join-Path -Path $anna -ChildPath 'AppData\Local\Microsoft\Windows\Explorer'
                Wer         = Join-Path -Path $base -ChildPath 'ProgramData\Microsoft\Windows\WER\ReportArchive'
                Recycle     = Join-Path -Path $base -ChildPath ('Drive1\$Recycle.Bin\' + $annaSid)
                Outside     = Join-Path -Path $base -ChildPath 'Outside'
                Documents   = Join-Path -Path $anna -ChildPath 'Documents'
            }
            foreach ($directory in @($paths.WindowsTemp, (Join-Path -Path $base -ChildPath 'Windows\SoftwareDistribution\Download'), (Join-Path -Path $base -ChildPath 'Windows\Logs\CBS'),
                    (Join-Path -Path $base -ChildPath 'ProgramData\Microsoft\Windows\WER\ReportQueue'), (Join-Path -Path $annaTemp -ChildPath 'pusty\pusty2'))) {
                $null = [IO.Directory]::CreateDirectory($directory)
            }
            Write-TestFile -Path (Join-Path -Path $annaTemp -ChildPath 'stary1.tmp') -Size 100
            Write-TestFile -Path (Join-Path -Path $annaTemp -ChildPath 'sub\stary2.log') -Size 200
            Write-TestFile -Path (Join-Path -Path $annaTemp -ChildPath 'nowy.tmp') -Size 50 -AgeDays 0
            Write-TestFile -Path (Join-Path -Path $annaTemp -ChildPath 'Chronione\zostaw.txt') -Size 10
            Write-TestFile -Path (Join-Path -Path $paths.Outside -ChildPath 'poza.txt') -Size 10
            Write-TestFile -Path (Join-Path -Path $paths.Documents -ChildPath 'dokument.txt') -Size 10
            Write-TestFile -Path (Join-Path -Path $paths.WindowsTemp -ChildPath 'system.tmp') -Size 300
            Write-TestFile -Path (Join-Path -Path $paths.Explorer -ChildPath 'thumbcache_32.db') -Size 400 -AgeDays 0
            Write-TestFile -Path (Join-Path -Path $paths.Explorer -ChildPath 'iconcache_32.db') -Size 400
            Write-TestFile -Path (Join-Path -Path $paths.Wer -ChildPath 'r1\Report.wer') -Size 500 -AgeDays 0
            Write-TestFile -Path (Join-Path -Path $paths.Recycle -ChildPath '$RABC123.txt') -Size 600 -AgeDays 0
            Write-TestFile -Path (Join-Path -Path $paths.Recycle -ChildPath 'desktop.ini') -Size 20
            Write-TestFile -Path (Join-Path -Path $paths.JanTemp -ChildPath 'jan.tmp') -Size 700
            # Junction w katalogu kategorii wskazujący katalog spoza kategorii (tworzenie nie wymaga administratora).
            $null = New-Item -ItemType Junction -Path (Join-Path -Path $annaTemp -ChildPath 'Link') -Value $paths.Outside
            $profileRoot = $users
            if ($LinkedUsers) {
                $profileRoot = Join-Path -Path $base -ChildPath 'UsersLink'
                $null = New-Item -ItemType Junction -Path $profileRoot -Value $users
            }
            $environment = [pscustomobject]@{
                Kind              = 'MWP.CleanupEnvironment'
                ComputerName      = 'TEST'
                SystemRoot        = Join-Path -Path $base -ChildPath 'Windows'
                ProgramData       = Join-Path -Path $base -ChildPath 'ProgramData'
                ProfilesDirectory = $profileRoot
                CurrentSid        = $annaSid
                CurrentUserName   = 'TEST\anna'
                CurrentProfile    = Join-Path -Path $profileRoot -ChildPath 'anna'
                IsAdministrator   = $true
                FixedDrives       = @((Join-Path -Path $base -ChildPath 'Drive1'))
                Profiles          = @(
                    [pscustomobject]@{ Sid = $annaSid; Path = (Join-Path -Path $profileRoot -ChildPath 'anna'); UserName = 'TEST\anna'; IsCurrent = $true }
                    [pscustomobject]@{ Sid = $janSid; Path = (Join-Path -Path $profileRoot -ChildPath 'jan'); UserName = 'TEST\jan'; IsCurrent = $false }
                )
                Protected         = @($paths.Documents, (Join-Path -Path $anna -ChildPath 'Desktop'), (Join-Path -Path $annaTemp -ChildPath 'Chronione'))
                Error             = $null
            }
            [pscustomobject]@{ Paths = $paths; Environment = $environment }
        }
        function Get-Category {
            param([object] $Result, [string] $Id)
            @($Result.Data.Categories | Where-Object { $_.Id -eq $Id })[0]
        }
        function Get-Log {
            $directory = Join-Path -Path $TestDrive -ChildPath 'Logs'
            if (Test-Path -LiteralPath $directory) {
                Get-ChildItem -LiteralPath $directory -Filter '*.log' | Get-Content -Raw -Encoding UTF8
            }
        }
        function Test-File {
            param([string] $Path)
            [IO.File]::Exists($Path)
        }
    }

    BeforeEach {
        $script:Machine = Initialize-FakeMachine
        $paths = $script:Machine.Paths
    }

    Context 'definicje kategorii (plik danych)' {
        It 'plik danych modułu ma 8 poprawnych kategorii z zakresu fazy' {
            $categories = @(Get-MwpCleanupCategory -IncludeInvalid)
            @($categories | Where-Object { -not $_.IsValid }) | Should -BeNullOrEmpty
            $categories.Id | Should -Be @('UserTemp', 'WindowsTemp', 'RecycleBin', 'ThumbnailCache', 'ErrorReports', 'WindowsUpdateDownload', 'DeliveryOptimization', 'Logs')
            (Get-MwpCleanupCategory -Id ErrorReports).Scope | Should -Be 'Mixed'
            (Get-MwpCleanupCategory -Id RecycleBin).Roots[0].Exclude | Should -Contain 'desktop.ini'
        }

        It 'ścieżki spoza białej listy, segmenty „..” i wzorce ze ścieżką są odrzucane' {
            $file = Join-Path -Path $TestDrive -ChildPath 'kategorie-zle.json'
            $bad = @(
                @{ id = 'Absolute'; path = 'C:\Windows\Temp' }
                @{ id = 'System32'; path = '{SystemRoot}\System32\LogFiles' }
                @{ id = 'Traversal'; path = '{SystemRoot}\Temp\..\System32' }
                @{ id = 'Documents'; path = '{UserProfile}\Documents' }
                @{ id = 'AppDataRoot'; path = '{UserProfile}\AppData' }
                @{ id = 'StartMenu'; path = '{ProgramData}\Microsoft\Windows\Start Menu\Programs' }
                @{ id = 'DataStore'; path = '{SystemRoot}\SoftwareDistribution\DataStore' }
                @{ id = 'Wildcard'; path = '{SystemRoot}\Temp\*' }
                @{ id = 'Good'; path = '{SystemRoot}\Temp' }
            )
            $categories = @($bad | ForEach-Object { @{ id = $_.id; name = $_.id; roots = @(@{ path = $_.path; patterns = @('*') }) } })
            $categories += @{ id = 'BadPattern'; name = 'x'; roots = @(@{ path = '{SystemRoot}\Temp'; patterns = @('..\*.tmp') }) }
            $data = @{ schemaVersion = 1; categories = $categories }
            [IO.File]::WriteAllText($file, (ConvertTo-Json -InputObject $data -Depth 6), (New-Object -TypeName Text.UTF8Encoding -ArgumentList $false))
            Mock -ModuleName MWP.Cleanup Get-MwpCleanupDefinitionPath { $file }
            $all = @(Get-MwpCleanupCategory -IncludeInvalid)
            @($all | Where-Object { $_.IsValid }).Id | Should -Be @('Good')
            @(Get-MwpCleanupCategory -WarningAction SilentlyContinue).Id | Should -Be @('Good')
        }

        It 'brak pliku definicji: skan kończy się błędem z przyczyną (nie pustym sukcesem)' {
            Mock -ModuleName MWP.Cleanup Get-MwpCleanupDefinitionPath { Join-Path -Path $TestDrive -ChildPath 'brak.json' }
            $result = Measure-MwpCleanupCategory -Context $context
            $result.Success | Should -BeFalse
            $result.Message | Should -Match 'Brak kategorii'
            $result.Message | Should -Match 'brak\.json'
            (Measure-MwpCleanupCategory -Context $context -Category Nieznana).Success | Should -BeFalse
        }
    }

    Context 'zasady ścieżek (Test-MwpCleanupRoot)' {
        It 'odrzuca <Name>' -ForEach @(
            @{ Name = 'katalog główny dysku'; Path = 'C:\' }
            @{ Name = 'ścieżkę względną'; Path = 'Windows\Temp' }
            @{ Name = 'segment ..'; Path = '{Base}\Windows\Temp\..\..\Outside' }
            @{ Name = 'folder Windows'; Path = '{Base}\Windows' }
            @{ Name = 'profil użytkownika'; Path = '{Base}\Users\anna' }
            @{ Name = 'AppData\Local (sam folder)'; Path = '{Base}\Users\anna\AppData\Local' }
            @{ Name = 'dokumenty (chronione)'; Path = '{Base}\Users\anna\Documents' }
            @{ Name = 'folder spoza baz'; Path = '{Base}\Outside' }
            @{ Name = 'lokalizację chronioną w katalogu kategorii'; Path = '{Base}\Users\anna\AppData\Local\Temp\Chronione' }
            @{ Name = 'symbol wieloznaczny'; Path = '{Base}\Windows\Temp\*' }
        ) {
            $check = InModuleScope MWP.Cleanup -Parameters @{ P = $Path.Replace('{Base}', $paths.Base); E = $script:Machine.Environment } {
                param($P, $E)
                Test-MwpCleanupRoot -Path $P -Environment $E
            }
            $check.IsValid | Should -BeFalse
            $check.Reason | Should -Not -BeNullOrEmpty
        }

        It 'akceptuje katalogi kategorii: Temp systemu i profilu, WER, Kosz' {
            foreach ($path in $paths.WindowsTemp, $paths.AnnaTemp, $paths.Wer, $paths.Recycle) {
                $check = InModuleScope MWP.Cleanup -Parameters @{ P = $path; E = $script:Machine.Environment } { param($P, $E) Test-MwpCleanupRoot -Path $P -Environment $E }
                $check.IsValid | Should -BeTrue -Because ('{0}: {1}' -f $path, $check.Reason)
            }
        }
    }

    Context 'skan (tylko odczyt)' {
        It 'liczy pliki i rozmiar na kategorię, z progiem wieku, wzorcami i wykluczeniami; niczego nie usuwa' {
            $result = Measure-MwpCleanupCategory -Context $context
            $result.Success | Should -BeTrue -Because $result.Message
            $result.Data.PSObject.TypeNames | Should -Contain 'MWP.CleanupScan'
            $temp = Get-Category $result 'UserTemp'
            $temp.FileCount | Should -Be 2
            $temp.SizeBytes | Should -Be 300
            @($temp.Skipped | Where-Object Reason -eq 'TooNew')[0].Count | Should -Be 1
            @($temp.Skipped | Where-Object Reason -eq 'ReparsePoint')[0].Count | Should -Be 1
            @($temp.Skipped | Where-Object Reason -eq 'Protected')[0].Count | Should -Be 1
            (Get-Category $result 'WindowsTemp').SizeBytes | Should -Be 300
            (Get-Category $result 'ThumbnailCache').FileCount | Should -Be 1 -Because 'tylko thumbcache_*.db'
            (Get-Category $result 'ErrorReports').SizeBytes | Should -Be 500
            (Get-Category $result 'RecycleBin').FileCount | Should -Be 1 -Because 'desktop.ini jest wykluczony'
            $result.Data.TotalBytes | Should -Be (300 + 300 + 400 + 500 + 600)
            $result.Data.UserProfiles | Should -Be @('TEST\anna')
            foreach ($file in (Join-Path $paths.AnnaTemp 'stary1.tmp'), (Join-Path $paths.WindowsTemp 'system.tmp'), (Join-Path $paths.Recycle '$RABC123.txt')) {
                Test-File $file | Should -BeTrue
            }
        }

        It 'lokalnie z -IncludeUserProfiles obejmuje profile wszystkich użytkowników' {
            $result = Measure-MwpCleanupCategory -Context $context -Category UserTemp -IncludeUserProfiles
            (Get-Category $result 'UserTemp').FileCount | Should -Be 3
            @($result.Data.Categories).Count | Should -Be 1
        }

        It 'bez administratora: lokalizacje systemowe i cudze profile są niedostępne, z ostrzeżeniem' {
            $script:Machine.Environment.IsAdministrator = $false
            $result = Measure-MwpCleanupCategory -Context $context -IncludeUserProfiles
            $result.Success | Should -BeTrue
            (Get-Category $result 'WindowsTemp').Available | Should -BeFalse
            (Get-Category $result 'WindowsTemp').Notes -join ' ' | Should -Match 'administratora'
            (Get-Category $result 'UserTemp').FileCount | Should -Be 2 -Because 'profil bieżącego konta nie wymaga administratora'
            @($result.Data.Warnings) -join ' ' | Should -Match 'administratora'
        }

        It 'tabela postępu: procent 100 po skanie; CancelRequested przerywa skan' {
            $progress = [hashtable]::Synchronized(@{ Percent = -1; Message = ''; CancelRequested = $false })
            $null = Measure-MwpCleanupCategory -Context $context -Progress $progress
            $progress.Percent | Should -Be 100
            $progress.CancelRequested = $true
            $result = Measure-MwpCleanupCategory -Context $context -Progress $progress
            $result.Data.Cancelled | Should -BeTrue
            @($result.Data.Categories).Count | Should -Be 0
        }
    }

    Context 'widget Dashboardu (D-053)' {
        It 'skan w tle (blok Estimate) daje te same liczby co skan krok po kroku i niczego nie usuwa' {
            $direct = Measure-MwpCleanupCategory -Context $context
            Mock -ModuleName MWP.Cleanup Start-MwpOperation { [pscustomobject]@{ PSTypeName = 'MWP.Operation'; Block = $ScriptBlock; Arguments = $ArgumentList; Operation = $Operation } }
            $operation = Measure-MwpCleanupCategory -Context $context -AsOperation -WidgetParameters @{ Categories = @('UserTemp', 'WindowsTemp', 'RecycleBin', 'ThumbnailCache', 'ErrorReports', 'WindowsUpdateDownload', 'DeliveryOptimization', 'Logs') }
            $operation.Operation | Should -Be 'Cleanup.Scan'
            # Blok Environment zastąpiony danymi komputera testowego (reszta bloku bez zmian).
            $environmentPath = Join-Path -Path $TestDrive -ChildPath 'environment.json'
            [IO.File]::WriteAllText($environmentPath, (ConvertTo-Json -Compress -Depth 5 -InputObject $script:Machine.Environment), [Text.Encoding]::UTF8)
            $environmentText = (InModuleScope MWP.Cleanup { Get-MwpCleanupScript -Name Environment }).ToString()
            $text = $operation.Block.ToString()
            $text.Contains($environmentText) | Should -BeTrue
            $code = [scriptblock]::Create($text.Replace($environmentText, ("[IO.File]::ReadAllText('{0}')" -f $environmentPath)))
            $raw = & { Set-StrictMode -Off; & $code @($operation.Arguments) }
            $scan = Resolve-MwpCleanupScan -Data $raw
            $scan.PSObject.TypeNames | Should -Contain 'MWP.CleanupScan'
            $scan.TotalBytes | Should -Be $direct.Data.TotalBytes
            $scan.TotalFiles | Should -Be $direct.Data.TotalFiles
            foreach ($file in (Join-Path $paths.AnnaTemp 'stary1.tmp'), (Join-Path $paths.WindowsTemp 'system.tmp')) {
                Test-File $file | Should -BeTrue
            }
            $view = ConvertTo-MwpCleanupEstimateView -Data $raw
            @($view.Sections | ForEach-Object Title) | Should -Be @('Suma')
            $view.Sections[0].Items[0].Value | Should -Be $direct.Data.TotalText
            $withCategories = ConvertTo-MwpCleanupEstimateView -Data $raw -WidgetParameters @{ ShowCategories = $true }
            @($withCategories.Sections[1].Items | Where-Object { $_.Percent -ge 0 }).Count | Should -BeGreaterThan 0
            ConvertTo-MwpCleanupEstimateView -Data $null | Should -BeNullOrEmpty
        }

        It 'blok Estimate ma tryb Scan na stałe i nie usuwa plików' {
            $block = InModuleScope MWP.Cleanup { Get-MwpCleanupScript -Name Estimate }
            $text = $block.ToString()
            $text | Should -Match "Mode\s*=\s*'Scan'"
            $text | Should -Not -Match 'Invoke-Expression|\$using:|Remove-Item'
            $text | Should -Not -Match "Mode\s*=\s*\[string\]\`$request\.Mode\s*$"
        }
    }

    Context 'usuwanie z potwierdzeniem i podglądem' {
        It 'domyślnie pyta o potwierdzenie (ConfirmImpact High) i obsługuje -WhatIf' {
            $binding = (Get-Command -Name Clear-MwpCleanupCategory).ScriptBlock.Attributes | Where-Object { $_ -is [System.Management.Automation.CmdletBindingAttribute] }
            $binding.ConfirmImpact | Should -Be 'High'
            $binding.SupportsShouldProcess | Should -BeTrue
        }

        It '-WhatIf: podgląd z liczbą plików, rozmiarem i komputerem; nic nie jest usuwane ani logowane' {
            $results = @(Clear-MwpCleanupCategory -Category UserTemp, WindowsTemp -Context $context -WhatIf)
            $results.Count | Should -Be 2
            $results | ForEach-Object { $_.IsPreview | Should -BeTrue; $_.Changed | Should -BeFalse; $_.ComputerName | Should -Be 'localhost' }
            $results[0].Message | Should -Match '2 plików'
            Test-File (Join-Path $paths.AnnaTemp 'stary1.tmp') | Should -BeTrue
            Test-File (Join-Path $paths.WindowsTemp 'system.tmp') | Should -BeTrue
            (Get-Log) -join '' | Should -Not -Match 'Cleanup\.Clear'
        }

        It 'usuwa tylko pasujące pliki w katalogu kategorii; junction, chronione, nowe pliki i katalog główny zostają' {
            $result = Clear-MwpCleanupCategory -Category UserTemp -Context $context -Confirm:$false
            $result.Success | Should -BeTrue -Because $result.Message
            $result.Changed | Should -BeTrue
            $result.Data.DeletedCount | Should -Be 2
            $result.Data.DeletedBytes | Should -Be 300
            Test-File (Join-Path $paths.AnnaTemp 'stary1.tmp') | Should -BeFalse
            Test-File (Join-Path $paths.AnnaTemp 'sub\stary2.log') | Should -BeFalse
            [IO.Directory]::Exists((Join-Path $paths.AnnaTemp 'sub')) | Should -BeFalse -Because 'pusty katalog jest usuwany'
            [IO.Directory]::Exists((Join-Path $paths.AnnaTemp 'pusty')) | Should -BeFalse
            [IO.Directory]::Exists($paths.AnnaTemp) | Should -BeTrue -Because 'katalog główny kategorii zostaje'
            Test-File (Join-Path $paths.AnnaTemp 'nowy.tmp') | Should -BeTrue
            Test-File (Join-Path $paths.AnnaTemp 'Chronione\zostaw.txt') | Should -BeTrue
            Test-File (Join-Path $paths.Outside 'poza.txt') | Should -BeTrue -Because 'junction nie jest przechodzony'
            [IO.Directory]::Exists((Join-Path $paths.AnnaTemp 'Link')) | Should -BeTrue -Because 'samo dowiązanie też zostaje'
            Test-File (Join-Path $paths.Documents 'dokument.txt') | Should -BeTrue
            Test-File (Join-Path $paths.WindowsTemp 'system.tmp') | Should -BeTrue -Because 'inna kategoria'
            Test-File (Join-Path $paths.JanTemp 'jan.tmp') | Should -BeTrue -Because 'cudzy profil bez -IncludeUserProfiles'
        }

        It 'kryterium: żadna operacja nie wychodzi poza zdefiniowane ścieżki (wszystkie kategorie, wszystkie profile)' {
            $before = @(Get-ChildItem -LiteralPath $paths.Base -Recurse -Force -File | ForEach-Object { $_.FullName })
            $ids = @(Get-MwpCleanupCategory | ForEach-Object { $_.Id })
            $results = @(Clear-MwpCleanupCategory -Category $ids -Context $context -IncludeUserProfiles -Confirm:$false)
            @($results | Where-Object { -not $_.Success }) | Should -BeNullOrEmpty
            $after = @(Get-ChildItem -LiteralPath $paths.Base -Recurse -Force -File | ForEach-Object { $_.FullName })
            $removed = @($before | Where-Object { $after -notcontains $_ })
            $allowed = @($paths.AnnaTemp, $paths.JanTemp, $paths.WindowsTemp, $paths.Explorer, $paths.Wer, $paths.Recycle)
            foreach ($file in $removed) {
                @($allowed | Where-Object { $file.StartsWith($_ + '\', [StringComparison]::OrdinalIgnoreCase) }).Count | Should -Be 1 -Because $file
                $file | Should -Not -BeLike ('{0}\Chronione\*' -f $paths.AnnaTemp)
                $file | Should -Not -BeLike ('{0}\Link\*' -f $paths.AnnaTemp)
            }
            $removed.Count | Should -Be 7
            foreach ($kept in (Join-Path $paths.Outside 'poza.txt'), (Join-Path $paths.Documents 'dokument.txt'), (Join-Path $paths.Explorer 'iconcache_32.db'), (Join-Path $paths.Recycle 'desktop.ini'), (Join-Path $paths.AnnaTemp 'nowy.tmp')) {
                $after | Should -Contain $kept
            }
        }

        It 'dowiązanie w ścieżce katalogu głównego blokuje lokalizację (nic nie jest usuwane przez junction)' {
            $script:Machine = Initialize-FakeMachine -LinkedUsers
            $paths = $script:Machine.Paths
            $result = Clear-MwpCleanupCategory -Category UserTemp -Context $context -Confirm:$false
            $result.Success | Should -BeFalse
            $result.Data.Roots[0].Error | Should -Match 'dowiązanie'
            Test-File (Join-Path $paths.AnnaTemp 'stary1.tmp') | Should -BeTrue
        }

        It 'plik w użyciu jest pomijany z powodem; plik tylko do odczytu jest usuwany' {
            $busy = Join-Path $paths.AnnaTemp 'stary1.tmp'
            $readOnly = Join-Path $paths.AnnaTemp 'sub\stary2.log'
            [IO.File]::SetAttributes($readOnly, [IO.FileAttributes]::ReadOnly)
            $stream = [IO.File]::Open($busy, 'Open', 'Read', 'None')
            try {
                $result = Clear-MwpCleanupCategory -Category UserTemp -Context $context -Confirm:$false
            }
            finally {
                $stream.Dispose()
            }
            $result.Success | Should -BeTrue
            $result.Data.DeletedCount | Should -Be 1
            @($result.Data.Skipped | Where-Object Reason -eq 'InUse')[0].Count | Should -Be 1
            @($result.Data.Samples | Where-Object Reason -eq 'InUse')[0].Path | Should -Be $busy
            Test-File $busy | Should -BeTrue
            Test-File $readOnly | Should -BeFalse
            $result.Message | Should -Match 'w użyciu'
        }

        It 'log początku i wyniku z nazwą komputera; brak wpisu cofnięcia' {
            $result = Clear-MwpCleanupCategory -Category WindowsTemp -Context $context -Confirm:$false
            $result.UndoId | Should -BeNullOrEmpty
            $result.Message | Should -Match 'nie można cofnąć'
            $log = (Get-Log) -join ''
            $log | Should -Match '"computer":"localhost","source":"MWP.Cleanup","operation":"Cleanup.Clear"'
            $log | Should -Match 'Rozpoczęto czyszczenie'
            @(Get-MwpUndoEntry | Where-Object { $_.Module -eq 'MWP.Cleanup' }) | Should -BeNullOrEmpty
        }

        It 'bez administratora: kategoria systemowa odrzucona przed podglądem; nieznana kategoria — błąd' {
            $script:Machine.Environment.IsAdministrator = $false
            $result = Clear-MwpCleanupCategory -Category WindowsTemp -Context $context -WhatIf
            $result.Success | Should -BeFalse
            $result.IsPreview | Should -BeFalse
            $result.Message | Should -Match "administratora na komputerze 'localhost'"
            (Clear-MwpCleanupCategory -Category Nieznana -Context $context -Confirm:$false).Success | Should -BeFalse
            Test-File (Join-Path $paths.WindowsTemp 'system.tmp') | Should -BeTrue
        }

        It 'kategoria bez plików: „Nic do usunięcia”, bez zmiany i bez pytania' {
            $result = Clear-MwpCleanupCategory -Category Logs -Context $context -WhatIf
            $result.Success | Should -BeTrue
            $result.IsPreview | Should -BeFalse
            $result.Changed | Should -BeFalse
            $result.Message | Should -Match 'Nic do usunięcia'
        }

        It 'anulowanie: CancelRequested przed kategorią — nic nie jest usuwane' {
            $progress = [hashtable]::Synchronized(@{ Percent = -1; Message = ''; CancelRequested = $true })
            $result = Clear-MwpCleanupCategory -Category UserTemp -Context $context -Progress $progress -Confirm:$false
            $result.Success | Should -BeFalse
            $result.Message | Should -Match 'anulowane'
            Test-File (Join-Path $paths.AnnaTemp 'stary1.tmp') | Should -BeTrue
        }

        It 'raport: zwolnione miejsce, pominięcia według powodu, kategorie; podgląd jest pomijany' {
            $results = @(Clear-MwpCleanupCategory -Category UserTemp, RecycleBin -Context $context -Confirm:$false) + @(Clear-MwpCleanupCategory -Category WindowsTemp -Context $context -WhatIf)
            $report = $results | ConvertTo-MwpCleanupReport
            $report.PSObject.TypeNames | Should -Contain 'MWP.CleanupReport'
            $report.FreedBytes | Should -Be 900
            $report.DeletedCount | Should -Be 3
            @($report.Categories).Count | Should -Be 2
            @($report.Reasons | Where-Object Reason -eq 'TooNew')[0].Count | Should -Be 1
            $report.Text | Should -Match 'Zwolniono: 900 B'
            $report.Text | Should -Match 'nowsze niż próg'
            (ConvertTo-MwpCleanupReport -Result @() -Cancelled).Text | Should -Match 'przerwane'
        }
    }

    Context 'blok Process — obrona w bloku komputera docelowego' {
        BeforeAll {
            function Invoke-ProcessBlock {
                param([object[]] $Roots, [string] $Mode = 'Delete', [string[]] $Protected = @(), $Cancel = $null)
                $json = ConvertTo-Json -Compress -Depth 5 -InputObject ([pscustomobject]@{ Mode = $Mode; MaxSamples = 20; Protected = @($Protected); Roots = @($Roots) })
                $block = InModuleScope MWP.Cleanup { Get-MwpCleanupScript -Name Process }
                $code = [scriptblock]::Create($block.ToString())
                $arguments = @($json, $Cancel)
                # Jak w Invoke-MwpOnTarget: blok bez trybu ścisłego.
                ConvertFrom-Json -InputObject ([string](& { Set-StrictMode -Off; & $code @arguments }))
            }
            function Get-RootRequest {
                param([string] $Path, [bool] $Recurse = $true)
                [pscustomobject]@{ Key = 'k'; Path = $Path; Recurse = $Recurse; Patterns = @('*'); Exclude = @(); MinAgeDays = 0; RemoveEmptyDirectories = $true }
            }
        }

        It 'ścieżka niekanoniczna (..) jest odrzucana, a pliki poza katalogiem zostają' {
            $raw = Invoke-ProcessBlock -Roots @(Get-RootRequest -Path ('{0}\..\..\Outside' -f $paths.WindowsTemp))
            $raw.Roots[0].Error | Should -Match 'kanoniczna'
            $raw.Roots[0].Deleted | Should -Be 0
            Test-File (Join-Path $paths.Outside 'poza.txt') | Should -BeTrue
        }

        It 'katalog główny chroniony albo krótka ścieżka jest odrzucany' {
            (Invoke-ProcessBlock -Roots @(Get-RootRequest -Path $paths.Documents) -Protected @($paths.Documents)).Roots[0].Error | Should -Match 'chronion'
            (Invoke-ProcessBlock -Roots @(Get-RootRequest -Path 'C:\') -Mode Scan).Roots[0].Error | Should -Not -BeNullOrEmpty
            Test-File (Join-Path $paths.Documents 'dokument.txt') | Should -BeTrue
        }

        It 'anulowanie w trakcie kategorii (lokalnie): przerwanie po bieżącym pliku, wynik z flagą Cancelled' {
            $many = Join-Path $paths.WindowsTemp 'duzo'
            foreach ($index in 1..450) {
                Write-TestFile -Path (Join-Path $many ('p{0}.tmp' -f $index)) -Size 1
            }
            $raw = Invoke-ProcessBlock -Roots @(Get-RootRequest -Path $many) -Cancel @{ CancelRequested = $true }
            $raw.Cancelled | Should -BeTrue
            $raw.Roots[0].Cancelled | Should -BeTrue
            $raw.Roots[0].Deleted | Should -BeLessThan 450
            @(Get-ChildItem -LiteralPath $many -File).Count | Should -BeGreaterThan 0
        }

        It 'bloki nie używają funkcji MWP, Invoke-Expression, $using:, Remove-Item ani usuwania rekurencyjnego' {
            foreach ($name in 'Environment', 'Process', 'ComponentStore') {
                $block = InModuleScope MWP.Cleanup -Parameters @{ Name = $name } { param($Name) Get-MwpCleanupScript -Name $Name }
                $commands = @($block.Ast.FindAll({ param($node) $node -is [Management.Automation.Language.CommandAst] }, $true) | ForEach-Object { $_.GetCommandName() } | Where-Object { $_ })
                @($commands | Where-Object { $_ -match '-Mwp' }) | Should -BeNullOrEmpty -Because $name
                $text = $block.ToString()
                $text | Should -Not -Match 'Invoke-Expression|\$using:|Remove-Item|-Recurse|Delete\([^)]*\$true\)'
            }
        }
    }

    Context 'komputer zdalny (D-019)' {
        BeforeEach {
            Mock -ModuleName MWP.Remote Remove-MwpPSSession { }
            Mock -ModuleName MWP.Remote New-MwpPSSession { [pscustomobject]@{ ComputerName = $ComputerName; State = 'Opened' } }
            Mock -ModuleName MWP.Remote Invoke-MwpSessionCommand {
                $bound = (Get-Module -Name MWP.Remote).NewBoundScriptBlock($ScriptBlock)
                [pscustomobject]@{ Output = @(& $bound @ArgumentList); Errors = @() }
            }
            $remote = New-MwpExecutionContext -ComputerName $remoteName
        }

        It 'domyślnie tylko lokalizacje systemowe; profile użytkowników — po jawnym wyborze' {
            $result = Measure-MwpCleanupCategory -Context $remote
            $result.Success | Should -BeTrue -Because $result.Message
            $result.ComputerName | Should -Be $remoteName
            (Get-Category $result 'UserTemp').Available | Should -BeFalse
            (Get-Category $result 'UserTemp').Notes -join ' ' | Should -Match 'profile użytkowników nie zostały wybrane'
            (Get-Category $result 'WindowsTemp').FileCount | Should -Be 1
            (Get-Category $result 'ErrorReports').SizeBytes | Should -Be 500 -Because 'część systemowa WER'
            @($result.Data.Warnings) -join ' ' | Should -Match 'tylko lokalizacje systemowe'
            $result.Data.UserProfiles | Should -BeNullOrEmpty
            $explicit = Measure-MwpCleanupCategory -Context $remote -Category UserTemp -IncludeUserProfiles
            (Get-Category $explicit 'UserTemp').FileCount | Should -Be 3
        }

        It 'czyszczenie: kategoria użytkownika odrzucona bez wyboru profili; systemowa z nazwą komputera w wyniku i logu' {
            $user = Clear-MwpCleanupCategory -Category UserTemp -Context $remote -Confirm:$false
            $user.Success | Should -BeFalse
            $user.Message | Should -Match 'jawnym wyborze'
            Test-File (Join-Path $paths.AnnaTemp 'stary1.tmp') | Should -BeTrue
            $result = Clear-MwpCleanupCategory -Category WindowsTemp -Context $remote -Confirm:$false
            $result.Success | Should -BeTrue -Because $result.Message
            $result.ComputerName | Should -Be $remoteName
            $result.Message | Should -Match $remoteName
            Test-File (Join-Path $paths.WindowsTemp 'system.tmp') | Should -BeFalse
            (Get-Log) -join '' | Should -Match ('"computer":"{0}","source":"MWP.Cleanup","operation":"Cleanup.Clear"' -f $remoteName)
        }

        It 'utrata połączenia: błąd tylko tej instancji, pliki zostają; localhost działa dalej' {
            Mock -ModuleName MWP.Remote Invoke-MwpSessionCommand { throw (New-Object -TypeName Management.Automation.Remoting.PSRemotingTransportException -ArgumentList 'Połączenie zerwane') }
            $result = Clear-MwpCleanupCategory -Category WindowsTemp -Context $remote -Confirm:$false
            $result.Success | Should -BeFalse
            $result.ComputerName | Should -Be $remoteName
            $remote.Connection.State | Should -Be 'Disconnected'
            Test-File (Join-Path $paths.WindowsTemp 'system.tmp') | Should -BeTrue
            (Measure-MwpCleanupCategory -Context $remote).Success | Should -BeFalse
            (Measure-MwpCleanupCategory -Context $context -Category WindowsTemp).Success | Should -BeTrue
        }
    }

    Context 'analiza magazynu składników (DISM)' {
        BeforeAll {
            $dismLines = @(
                'Deployment Image Servicing and Management tool', 'Version: 10.0.26100.1', '', 'Image Version: 10.0.26300.9711', '',
                '[===========================100.0%==========================]', '', 'Component Store (WinSxS) information:', '',
                'Windows Explorer Reported Size of Component Store : 7.89 GB', '', 'Actual Size of Component Store : 7.61 GB', '',
                '    Shared with Windows : 5.61 GB', '    Backups and Disabled Features : 1.94 GB', '    Cache and Temporary Data :  54.32 MB', '',
                'Date of Last Cleanup : 2026-10-01 10:14:41', '', 'Number of Reclaimable Packages : 2', 'Component Store Cleanup Recommended : Yes', '',
                'The operation completed successfully.'
            )
            function Get-DismRaw {
                param([bool] $Admin = $true, $ExitCode = 0, [string[]] $Lines = $dismLines)
                ConvertTo-Json -Compress -InputObject ([pscustomobject]@{ Kind = 'MWP.ComponentStoreRaw'; IsAdministrator = $Admin; ExitCode = $ExitCode; Lines = @($Lines); Error = $null })
            }
        }

        It 'parsuje angielski wynik DISM (rozmiary, data, pakiety, zalecenie)' {
            $analysis = Resolve-MwpComponentStoreAnalysis -Data (Get-DismRaw) -ComputerName 'localhost'
            $analysis.Success | Should -BeTrue -Because $analysis.Message
            $analysis.ActualSizeBytes | Should -Be ([long](7.61 * [Math]::Pow(1024, 3)))
            $analysis.ActualSizeText | Should -Be '7,6 GB'
            $analysis.BackupsText | Should -Be '1,9 GB'
            $analysis.CacheBytes | Should -Be ([long](54.32 * 1MB))
            $analysis.LastCleanup | Should -Be ([datetime]'2026-10-01 10:14:41')
            $analysis.ReclaimablePackages | Should -Be 2
            $analysis.CleanupRecommended | Should -BeTrue
            $analysis.Message | Should -Match 'zalecane'
        }

        It 'brak administratora (lub kod 740) i błąd DISM dają czytelny wynik z błędem' {
            (Resolve-MwpComponentStoreAnalysis -Data (Get-DismRaw -Admin $false -ExitCode $null -Lines @())).Message | Should -Match 'administratora'
            (Resolve-MwpComponentStoreAnalysis -Data (Get-DismRaw -ExitCode 740 -Lines @('Error: 740'))).Success | Should -BeFalse
            $failed = Resolve-MwpComponentStoreAnalysis -Data (Get-DismRaw -ExitCode 87 -Lines @('Error: 87', 'The parameter is incorrect.'))
            $failed.Success | Should -BeFalse
            $failed.Message | Should -Match '87'
            Resolve-MwpComponentStoreAnalysis -Data $null | Should -BeNullOrEmpty
        }

        It 'Get-MwpComponentStoreAnalysis: wynik z komputera kontekstu; -AsOperation z limitem czasu 1 h' {
            Mock -ModuleName MWP.Cleanup Invoke-MwpOnTarget { New-MwpResult -Success $true -ComputerName $Context.ComputerName -Data @((Get-DismRaw)) }
            $result = Get-MwpComponentStoreAnalysis -Context $context
            $result.Success | Should -BeTrue -Because $result.Message
            $result.Data.CleanupRecommended | Should -BeTrue
            Should -Invoke Invoke-MwpOnTarget -ModuleName MWP.Cleanup -Times 1 -Exactly -ParameterFilter { $TimeoutSeconds -eq 3600 -and $ScriptBlock.ToString() -match 'AnalyzeComponentStore' -and $ScriptBlock.ToString() -match '/English' }
            Mock -ModuleName MWP.Cleanup Start-MwpOperation { [pscustomobject]@{ PSTypeName = 'MWP.Operation'; TimeoutSeconds = $TimeoutSeconds } }
            (Get-MwpComponentStoreAnalysis -Context $context -AsOperation).TimeoutSeconds | Should -Be 3600
            $block = InModuleScope MWP.Cleanup { Get-MwpCleanupScript -Name ComponentStore }
            $block.ToString() | Should -Not -Match 'StartComponentCleanup|RestoreHealth|ResetBase'
        }
    }

    Context 'kontrakt modułu i pomocnicze' {
        It 'kontrakt jest poprawny: Read, Destructive, RemoteTarget; tryby Embedded i SeparateWindow; -Context i -WhatIf' {
            $definition = Get-MwpModuleDefinition -Name 'MWP.Cleanup'
            $definition.IsValid | Should -BeTrue -Because ($definition.Errors -join ' ')
            $definition.Capabilities | Should -Contain 'RemoteTarget'
            $definition.Capabilities | Should -Contain 'Destructive'
            $definition.SupportedPresentationModes | Should -Contain 'SeparateWindow'
            foreach ($command in 'Measure-MwpCleanupCategory', 'Clear-MwpCleanupCategory', 'Get-MwpComponentStoreAnalysis') {
                (Get-Command -Name $command).Parameters.ContainsKey('Context') | Should -BeTrue -Because $command
            }
            (Get-Command -Name Clear-MwpCleanupCategory).Parameters.ContainsKey('WhatIf') | Should -BeTrue
            (Get-Command -Name Measure-MwpCleanupCategory).Parameters.ContainsKey('WhatIf') | Should -BeFalse -Because 'skan to odczyt'
        }

        It 'rozmiar po polsku: <Bytes> → <Text>' -ForEach @(
            @{ Bytes = 0; Text = '0 B' }
            @{ Bytes = 900; Text = '900 B' }
            @{ Bytes = 1536; Text = '1,5 KB' }
            @{ Bytes = 1073741824; Text = '1 GB' }
            @{ Bytes = 157286400; Text = '150 MB' }
        ) {
            Format-MwpCleanupSize -Bytes $Bytes | Should -Be $Text
        }

        It 'blok Environment działa lokalnie (tylko odczyt): katalog Windows, profil bieżącego konta, lokalizacje chronione' {
            $block = InModuleScope MWP.Cleanup { Get-MwpCleanupScript -Name Environment }
            $result = Invoke-MwpOnTarget -Context $context -ScriptBlock $block -Operation 'Test.Environment'
            $result.Success | Should -BeTrue
            $environment = ConvertFrom-Json -InputObject ([string]@($result.Data)[-1])
            $environment.SystemRoot | Should -Be ([Environment]::GetFolderPath('Windows')).TrimEnd('\')
            $environment.CurrentSid | Should -Be ([Security.Principal.WindowsIdentity]::GetCurrent().User.Value)
            @($environment.Profiles | Where-Object { $_.IsCurrent }).Count | Should -Be 1
            $environment.Protected | Should -Contain ([Environment]::GetFolderPath('MyDocuments')).TrimEnd('\')
            @($environment.FixedDrives).Count | Should -BeGreaterThan 0
        }
    }
}
