#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
    Testy modułu MWP.Startup (FAZA 8) z symulatorem: rejestr (Test-Path, Get-ItemProperty, New-Item,
    New-ItemProperty dla ścieżek Registry::), foldery Startup (Get-ChildItem dla folderów z symulatora),
    skróty (New-Object -ComObject WScript.Shell), podpisy (Get-AuthenticodeSignature), zalogowani
    użytkownicy (Win32_Process + GetOwnerSid) i harmonogram (Get-ScheduledTask, Get-ScheduledTaskInfo,
    Enable-/Disable-/Start-/Export-/Unregister-/Register-ScheduledTask). Mocki są w zakresie MWP.Remote
    (tam Invoke-MwpOnTarget wykonuje bloki), a dla bezpieczeństwa także w MWP.Startup i w zakresie pliku;
    filtry obejmują WSZYSTKIE ścieżki Registry:: i C:\MwpFake\, więc prawdziwy rejestr i pliki nie są
    zmieniane. Pozycje i zadania mają fikcyjne nazwy (MwpTest*). Sprawdzają: odczyt wszystkich źródeł
    autostartu, stan StartupApproved (format Menedżera zadań), podpis i ocenę ryzyka, włącz/wyłącz bez
    kasowania wpisu, -WhatIf, uprawnienia, log, wpis cofnięcia i cofnięcie, zadania (lista, lista
    ochronna, włącz/wyłącz, uruchom, usunięcie z eksportem XML i odtworzenie), komputer zdalny
    (zalogowani użytkownicy, mock transportu WinRM) i błąd połączenia.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Zmienne z bloków BeforeDiscovery/BeforeAll są używane w blokach It (zakresy Pestera).')]
param()

Describe 'MWP.Startup — autostart i harmonogram' {
    BeforeAll {
        $root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
        foreach ($name in 'MWP.Core', 'MWP.Remote', 'MWP.Startup') {
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

        $currentSid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
        $remoteSid = 'S-1-5-21-1000-2000-3000-1001'
        $commonStartup = [Environment]::GetFolderPath('CommonStartup')
        $userStartup = [Environment]::GetFolderPath('Startup')
        $remoteStartup = 'C:\MwpFake\Users\anna\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup'
        $hklm = 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE'
        $approved = 'Microsoft\Windows\CurrentVersion\Explorer\StartupApproved'
        $run = 'Microsoft\Windows\CurrentVersion'

        # W pełnym przebiegu (Invoke-Checks) działa Set-StrictMode, a ciało i filtr mocka widzą tylko przekazane parametry.
        function Get-Bound {
            param([string] $Name)
            Get-Variable -Name $Name -ValueOnly -ErrorAction SilentlyContinue
        }
        function ConvertTo-ByteArray {
            param([string] $Hex)
            , [byte[]]@(for ($index = 0; $index -lt $Hex.Length; $index += 2) { [Convert]::ToByte($Hex.Substring($index, 2), 16) })
        }
        function ConvertTo-Hex {
            param([byte[]] $Bytes)
            (@($Bytes | ForEach-Object { '{0:X2}' -f $_ }) -join '')
        }

        # Stan symulatora: rejestr (klucz → wartości), pliki z podpisem, foldery, skróty, zadania.
        function Initialize-FakeStartup {
            $registry = @{}
            $set = {
                param([string] $Key, [hashtable] $Values)
                $map = [ordered]@{}
                foreach ($name in $Values.Keys) { $map[$name] = $Values[$name] }
                $registry[$Key.ToLowerInvariant()] = $map
            }
            & $set "$hklm\$run\Run" @{ MwpTestAudio = 'C:\MwpFake\Audio\audio.exe -background' }
            & $set "$hklm\WOW6432Node\$run\Run" @{ MwpTestPrinter = '"C:\MwpFake\Printer\monitor.exe" /autorun' }
            & $set "$hklm\$run\RunOnce" @{ MwpTestSetup = 'C:\MwpFake\Setup\finish.exe' }
            & $set "$hklm\$approved\Run" @{ MwpTestAudio = (ConvertTo-ByteArray '020000000000000000000000') }
            & $set "$hklm\$approved\Run32" @{ MwpTestPrinter = (ConvertTo-ByteArray '0300000000B0E5D6B058DA01') }
            & $set "$hklm\$approved\StartupFolder" @{ 'MwpTest Monitor.lnk' = (ConvertTo-ByteArray '060000000000000000000000') }
            & $set "Registry::HKEY_CURRENT_USER\SOFTWARE\$run\Run" @{ MwpTestChat = '"C:\MwpFake\Chat\chat.exe" --minimized'; MwpTestGone = 'C:\MwpFake\Gone\gone.exe' }
            & $set "Registry::HKEY_CURRENT_USER\SOFTWARE\$approved\StartupFolder" @{ 'mwptest-start.bat' = (ConvertTo-ByteArray '0300000000B0E5D6B058DA01') }
            & $set 'Registry::HKEY_CURRENT_USER' @{}
            # Profil zalogowanego użytkownika komputera zdalnego (HKEY_USERS\<SID>).
            & $set "Registry::HKEY_USERS\$remoteSid" @{}
            & $set "Registry::HKEY_USERS\$remoteSid\SOFTWARE\$run\Run" @{ MwpTestRemoteChat = 'C:\MwpFake\Chat\chat.exe' }
            & $set "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$remoteSid" @{ ProfileImagePath = 'C:\MwpFake\Users\anna' }

            $files = @{}
            foreach ($entry in @(
                    , @('C:\MwpFake\Audio\audio.exe', 'Valid', 'CN=Contoso Audio, O=Contoso Ltd, C=PL')
                    , @('C:\MwpFake\Printer\monitor.exe', 'NotSigned', '')
                    , @('C:\MwpFake\Setup\finish.exe', 'Valid', 'CN="Fabrikam, Inc.", O=Fabrikam')
                    , @('C:\MwpFake\Chat\chat.exe', 'Valid', 'CN=Chat Corp')
                    , @('C:\MwpFake\Monitor\mon.exe', 'HashMismatch', 'CN=Monitor Ltd')
                    , @('C:\MwpFake\Updater\upd.exe', 'Valid', 'CN=Updater Sp. z o.o.')
                    , @('C:\MwpFake\Backup\backup.exe', 'NotSigned', '')
                    , @('C:\MwpFake\Report\report.exe', 'Valid', 'CN=Report Ltd')
                    , @((Join-Path -Path $userStartup -ChildPath 'mwptest-start.bat'), 'UnknownError', '')
                )) {
                $files[$entry[0].ToLowerInvariant()] = @{ Status = $entry[1]; Subject = $entry[2] }
            }
            $folders = @{
                $commonStartup.ToLowerInvariant() = @('MwpTest Monitor.lnk', 'desktop.ini')
                $userStartup.ToLowerInvariant()   = @('mwptest-start.bat')
                $remoteStartup.ToLowerInvariant() = @()
            }
            $links = @{ (Join-Path -Path $commonStartup -ChildPath 'MwpTest Monitor.lnk').ToLowerInvariant() = @{ TargetPath = 'C:\MwpFake\Monitor\mon.exe'; Arguments = '/tray' } }

            $xml = { param([string] $Logon) '<?xml version="1.0" encoding="UTF-16"?><Task xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task"><Principals><Principal><LogonType>{0}</LogonType></Principal></Principals></Task>' -f $Logon }
            $tasks = [ordered]@{}
            foreach ($entry in @(
                    , @('\', 'MwpTest Updater', 'Ready', 'C:\MwpFake\Updater\upd.exe', 'SYSTEM', 'ServiceAccount', @('MSFT_TaskLogonTrigger', 'MSFT_TaskDailyTrigger'))
                    , @('\MwpTest\', 'Backup [x]', 'Disabled', 'C:\MwpFake\Backup\backup.exe', 'anna', 'Password', @('MSFT_TaskWeeklyTrigger'))
                    , @('\MwpTest\', 'Report', 'Ready', 'C:\MwpFake\Report\report.exe', 'anna', 'Interactive', @())
                    , @('\Microsoft\Windows\SystemRestore\', 'SR', 'Ready', 'C:\MwpFake\Updater\upd.exe', 'SYSTEM', 'ServiceAccount', @('MSFT_TaskDailyTrigger'))
                    , @('\Microsoft\Windows\MwpTestMaint\', 'Cleanup', 'Ready', 'C:\MwpFake\Report\report.exe', 'SYSTEM', 'ServiceAccount', @('MSFT_TaskIdleTrigger'))
                )) {
                $tasks[$entry[0] + $entry[1]] = @{
                    TaskPath = $entry[0]; TaskName = $entry[1]; State = $entry[2]; Execute = $entry[3]; UserId = $entry[4]; LogonType = $entry[5]
                    Triggers = $entry[6]; Xml = (& $xml $entry[5])
                }
            }
            $script:Fake = @{
                Registry  = $registry
                Files     = $files
                Folders   = $folders
                Links     = $links
                Tasks     = $tasks
                Explorer  = @($remoteSid)
                Admin     = $true
                FailTask  = @()
                FailWrite = $false
            }
            $script:Calls = New-Object -TypeName System.Collections.Generic.List[string]
        }
        Initialize-FakeStartup

        $isFake = { param([string] $Path) $lower = $Path.ToLowerInvariant(); $lower -like 'registry::*' -or $lower -like 'c:\mwpfake\*' -or $script:Fake.Folders.ContainsKey($lower) -or $script:Fake.Files.ContainsKey($lower) }
        $fakeTestPath = {
            $key = ([string](Get-Bound LiteralPath | Select-Object -First 1)).ToLowerInvariant()
            if ($key -like 'registry::*') { return $script:Fake.Registry.ContainsKey($key) }
            if ($script:Fake.Folders.ContainsKey($key)) { return (Get-Bound PathType) -ne 'Leaf' }
            $script:Fake.Files.ContainsKey($key)
        }
        $fakeGetItemProperty = {
            $key = ([string](Get-Bound LiteralPath | Select-Object -First 1)).ToLowerInvariant()
            if (-not $script:Fake.Registry.ContainsKey($key)) { throw ("Nie można odnaleźć ścieżki '{0}'." -f $LiteralPath) }
            $values = [ordered]@{}
            foreach ($name in $script:Fake.Registry[$key].Keys) { $values[$name] = $script:Fake.Registry[$key][$name] }
            [pscustomobject]$values
        }
        $fakeNewItem = {
            $key = ([string](Get-Bound Path | Select-Object -First 1)).ToLowerInvariant()
            $script:Calls.Add('NewKey ' + $key)
            if (-not $script:Fake.Registry.ContainsKey($key)) { $script:Fake.Registry[$key] = [ordered]@{} }
        }
        $fakeNewItemProperty = {
            $key = ([string](Get-Bound LiteralPath | Select-Object -First 1)).ToLowerInvariant()
            if ($script:Fake.FailWrite) { throw 'Odmowa dostępu do klucza rejestru.' }
            $bytes = [byte[]]$Value
            $script:Calls.Add(('SetValue {0}|{1}|{2}' -f $key, $Name, (@($bytes | ForEach-Object { '{0:X2}' -f $_ }) -join '')))
            $script:Fake.Registry[$key][$Name] = $bytes
        }
        $fakeChildItem = {
            $folder = [string](Get-Bound LiteralPath | Select-Object -First 1)
            foreach ($name in $script:Fake.Folders[$folder.ToLowerInvariant()]) {
                [pscustomobject]@{ Name = $name; FullName = (Join-Path -Path $folder -ChildPath $name); Extension = [IO.Path]::GetExtension($name) }
            }
        }
        $fakeShell = {
            $shell = [pscustomobject]@{}
            $shell | Add-Member -MemberType ScriptMethod -Name CreateShortcut -Value {
                param($Path)
                $link = $script:Fake.Links[([string]$Path).ToLowerInvariant()]
                [pscustomobject]@{ TargetPath = $link.TargetPath; Arguments = $link.Arguments }
            }
            $shell
        }
        $fakeSignature = {
            $key = ([string](Get-Bound LiteralPath | Select-Object -First 1)).ToLowerInvariant()
            $script:Calls.Add('Sig ' + $key)
            $info = $script:Fake.Files[$key]
            [pscustomobject]@{
                Status            = $info.Status
                SignerCertificate = $(if ($info.Subject) { [pscustomobject]@{ Subject = $info.Subject } } else { $null })
            }
        }
        $newTask = {
            param($Data)
            [pscustomobject]@{
                TaskPath    = $Data.TaskPath
                TaskName    = $Data.TaskName
                State       = $Data.State
                Author      = 'MwpTest'
                Description = 'Zadanie testowe {0}' -f $Data.TaskName
                Actions     = @([pscustomobject]@{ Execute = $Data.Execute; Arguments = '/run' })
                Triggers    = @(foreach ($class in @($Data.Triggers)) { [pscustomobject]@{ CimClass = [pscustomobject]@{ CimClassName = $class } } })
                Principal   = [pscustomobject]@{ UserId = $Data.UserId; GroupId = $null; LogonType = $Data.LogonType; RunLevel = 'Limited' }
            }
        }
        $fakeGetTask = {
            $path = [string](Get-Bound TaskPath | Select-Object -First 1)
            $found = @(foreach ($key in $script:Fake.Tasks.Keys) {
                    $data = $script:Fake.Tasks[$key]
                    if (-not $path -or $data.TaskPath -eq $path) { & $newTask $data }
                })
            if ($path -and $found.Count -eq 0) { throw ('No MSFT_ScheduledTask objects found with property TaskPath equal to {0}.' -f $path) }
            $found
        }
        $fakeTaskInfo = {
            foreach ($task in @($InputObject)) {
                [pscustomobject]@{ TaskPath = $task.TaskPath; TaskName = $task.TaskName; LastRunTime = [datetime]'2026-10-20 08:00'; NextRunTime = [datetime]'1999-11-30'; LastTaskResult = 267011 }
            }
        }
        $taskAction = {
            param([string] $Verb)
            foreach ($task in @($InputObject)) {
                $key = $task.TaskPath + $task.TaskName
                $script:Calls.Add(('{0} {1}' -f $Verb, $key))
                if ($script:Fake.FailTask -contains $Verb) {
                    $exception = New-Object -TypeName UnauthorizedAccessException -ArgumentList 'Odmowa dostępu.'
                    throw $exception
                }
                switch ($Verb) {
                    'Enable' { $script:Fake.Tasks[$key].State = 'Ready' }
                    'Disable' { $script:Fake.Tasks[$key].State = 'Disabled' }
                    'Start' { $script:Fake.Tasks[$key].State = 'Running' }
                    'Export' { $script:Fake.Tasks[$key].Xml }
                    'Remove' { $script:Fake.Tasks.Remove($key) }
                }
            }
        }
        $fakeRegister = {
            $script:Calls.Add(('Register {0}{1}' -f $TaskPath, $TaskName))
            $script:Fake.Tasks[$TaskPath + $TaskName] = @{
                TaskPath = $TaskPath; TaskName = $TaskName; State = 'Ready'; Execute = 'C:\MwpFake\Report\report.exe'; UserId = 'anna'; LogonType = 'Interactive'; Triggers = @(); Xml = $Xml
            }
        }
        $fakeProcess = { foreach ($sid in $script:Fake.Explorer) { [pscustomobject]@{ Name = 'explorer.exe'; OwnerSid = $sid } } }
        $fakeOwner = { [pscustomobject]@{ Sid = $InputObject.OwnerSid; ReturnValue = 0 } }

        foreach ($scope in 'MWP.Remote', 'MWP.Startup') {
            $module = @{ ModuleName = $scope }
            # Pester 6 nie przepuszcza wywołań niepasujących do filtra: domyślne mocki wołają oryginał (nazwa z modułem omija mock).
            Mock @module Test-Path { Microsoft.PowerShell.Management\Test-Path @PesterBoundParameters }
            Mock @module Get-ItemProperty { Microsoft.PowerShell.Management\Get-ItemProperty @PesterBoundParameters }
            Mock @module New-Item { Microsoft.PowerShell.Management\New-Item @PesterBoundParameters }
            Mock @module New-ItemProperty { throw 'Zapis do rejestru poza symulatorem jest zablokowany w testach.' }
            Mock @module Get-ChildItem { Microsoft.PowerShell.Management\Get-ChildItem @PesterBoundParameters }
            Mock @module New-Object { Microsoft.PowerShell.Utility\New-Object @PesterBoundParameters }
            Mock @module Get-CimInstance { CimCmdlets\Get-CimInstance @PesterBoundParameters }
            Mock @module Invoke-CimMethod -RemoveParameterType InputObject { throw 'Wywołanie metody CIM poza symulatorem jest zablokowane w testach.' }
            Mock @module Test-Path -ParameterFilter { & $isFake ([string](Get-Bound LiteralPath | Select-Object -First 1)) } $fakeTestPath
            Mock @module Get-ItemProperty -ParameterFilter { ([string](Get-Bound LiteralPath | Select-Object -First 1)) -like 'Registry::*' } $fakeGetItemProperty
            Mock @module New-Item -ParameterFilter { ([string](Get-Bound Path | Select-Object -First 1)) -like 'Registry::*' } $fakeNewItem
            Mock @module New-ItemProperty -ParameterFilter { ([string](Get-Bound LiteralPath | Select-Object -First 1)) -like 'Registry::*' } $fakeNewItemProperty
            Mock @module Get-ChildItem -ParameterFilter { $script:Fake.Folders.ContainsKey(([string](Get-Bound LiteralPath | Select-Object -First 1)).ToLowerInvariant()) } $fakeChildItem
            Mock @module New-Object -ParameterFilter { (Get-Bound ComObject) -eq 'WScript.Shell' } $fakeShell
            Mock @module Get-AuthenticodeSignature $fakeSignature
            Mock @module Get-CimInstance -ParameterFilter { (Get-Bound ClassName) -eq 'Win32_Process' } $fakeProcess
            Mock @module Invoke-CimMethod -RemoveParameterType InputObject -ParameterFilter { (Get-Bound MethodName) -eq 'GetOwnerSid' } $fakeOwner
            Mock @module Get-ScheduledTask $fakeGetTask
            Mock @module Get-ScheduledTaskInfo -RemoveParameterType InputObject $fakeTaskInfo
            Mock @module Enable-ScheduledTask -RemoveParameterType InputObject { & $taskAction 'Enable' }
            Mock @module Disable-ScheduledTask -RemoveParameterType InputObject { & $taskAction 'Disable' }
            Mock @module Start-ScheduledTask -RemoveParameterType InputObject { & $taskAction 'Start' }
            Mock @module Export-ScheduledTask -RemoveParameterType InputObject { & $taskAction 'Export' }
            Mock @module Unregister-ScheduledTask -RemoveParameterType InputObject { & $taskAction 'Remove' }
            Mock @module Register-ScheduledTask $fakeRegister
        }
        Mock -ModuleName MWP.Startup Test-MwpAdmin { $script:Fake.Admin }

        $context = New-MwpExecutionContext
        function Get-Call {
            param([string] $Prefix)
            @($script:Calls | Where-Object { $_ -like ([WildcardPattern]::Escape($Prefix) + '*') })
        }
        function Get-Log {
            Get-ChildItem -LiteralPath (Join-Path -Path $TestDrive -ChildPath 'Logs') -Filter '*.log' | Get-Content -Raw -Encoding UTF8
        }
        function Get-ItemMap {
            param($Context = $context)
            $result = Get-MwpStartupItem -Context $Context
            $result.Success | Should -BeTrue -Because $result.Message
            $map = @{}
            foreach ($item in $result.Data.Items) { $map[$item.Name] = $item }
            $map
        }
    }

    AfterAll {
        Remove-Module -Name MWP.Startup, MWP.Remote, MWP.Core -Force -ErrorAction SilentlyContinue
    }

    BeforeEach {
        Initialize-FakeStartup
    }

    Context 'autostart — odczyt' {
        It 'czyta Run/RunOnce (z WOW6432Node), foldery Startup i stan StartupApproved jak Menedżer zadań' {
            $result = Get-MwpStartupItem -Context $context
            $result.Success | Should -BeTrue -Because $result.Message
            $list = $result.Data
            $list.PSObject.TypeNames | Should -Contain 'MWP.StartupItemList'
            $list.UserMode | Should -Be 'Current'
            $list.CurrentUserSid | Should -Be $currentSid
            @($list.Items).Count | Should -Be 7
            $items = Get-ItemMap
            $items['MwpTestAudio'].Location | Should -Be 'MachineRun'
            $items['MwpTestAudio'].Enabled | Should -BeTrue
            $items['MwpTestPrinter'].Location | Should -Be 'MachineRun32'
            $items['MwpTestPrinter'].Enabled | Should -BeFalse
            $items['MwpTestPrinter'].StateText | Should -Be 'Wyłączony'
            $items['MwpTestPrinter'].DisabledAt | Should -BeOfType [datetime]
            $items['MwpTestPrinter'].FilePath | Should -Be 'C:\MwpFake\Printer\monitor.exe'
            $items['MwpTestSetup'].CanToggle | Should -BeFalse
            $items['MwpTestSetup'].StateText | Should -Match 'RunOnce'
            $items['MwpTestChat'].Scope | Should -Be 'User'
            $items['MwpTestChat'].UserSid | Should -Be $currentSid
            $items['MwpTestChat'].Enabled | Should -BeTrue -Because 'brak wartości StartupApproved = włączona'
            $items['MwpTestChat'].Id | Should -Be ('UserRun|{0}|MwpTestChat' -f $currentSid)
            $items['MwpTest Monitor.lnk'].Location | Should -Be 'MachineStartupFolder'
            $items['MwpTest Monitor.lnk'].Enabled | Should -BeTrue -Because '06 — bit 0 wyłączony'
            $items['MwpTest Monitor.lnk'].FilePath | Should -Be 'C:\MwpFake\Monitor\mon.exe'
            $items['MwpTest Monitor.lnk'].Command | Should -Match '/tray'
            $items['mwptest-start.bat'].Location | Should -Be 'UserStartupFolder'
            $items['mwptest-start.bat'].Enabled | Should -BeFalse
            $items.ContainsKey('desktop.ini') | Should -BeFalse
        }

        It 'podpis wydawcy i ocena ryzyka: podpisany, niepodpisany, nieprawidłowy, brak pliku, skrypt bez podpisu' {
            $items = Get-ItemMap
            $items['MwpTestAudio'].Risk | Should -Be 'Signed'
            $items['MwpTestAudio'].Publisher | Should -Be 'Contoso Audio'
            $items['MwpTestSetup'].Publisher | Should -Be 'Fabrikam, Inc.'
            $items['MwpTestPrinter'].Risk | Should -Be 'Unsigned'
            $items['MwpTestPrinter'].RiskText | Should -Be 'Niepodpisany'
            $items['MwpTest Monitor.lnk'].Risk | Should -Be 'Invalid'
            $items['MwpTestGone'].Risk | Should -Be 'Missing'
            $items['MwpTestGone'].FileExists | Should -BeFalse
            $items['mwptest-start.bat'].Risk | Should -Be 'Unsigned' -Because 'UnknownError bez certyfikatu = format bez podpisów (.bat)'
        }

        It 'filtry: zakres, stan, ryzyko, tekst; -NoSignature nie sprawdza podpisów' {
            @((Get-MwpStartupItem -Context $context -Scope Machine).Data.Items).Count | Should -Be 4
            $disabled = @((Get-MwpStartupItem -Context $context -State Disabled).Data.Items.Name)
            $disabled.Count | Should -Be 2
            $disabled | Should -Contain 'MwpTestPrinter'
            $disabled | Should -Contain 'mwptest-start.bat'
            @((Get-MwpStartupItem -Context $context -State RunOnce).Data.Items.Name) | Should -Be @('MwpTestSetup')
            @((Get-MwpStartupItem -Context $context -Risk NotSigned).Data.Items).Count | Should -Be 4
            @((Get-MwpStartupItem -Context $context -Search 'contoso').Data.Items.Name) | Should -Be @('MwpTestAudio')
            (Get-MwpStartupItem -Context $context -State Enabled).Message | Should -Match 'po filtrach: 4'
            $script:Calls.Clear()
            $items = (Get-MwpStartupItem -Context $context -NoSignature).Data.Items
            Get-Call 'Sig' | Should -BeNullOrEmpty
            @($items | Where-Object { $_.FileExists } | ForEach-Object { $_.Risk } | Select-Object -Unique) | Should -Be @('NotChecked')
        }

        It '-AsOperation startuje operację z blokiem ItemList, a Resolve-MwpStartupItemList parsuje surowy wynik' {
            Mock -ModuleName MWP.Startup Start-MwpOperation { [pscustomobject]@{ PSTypeName = 'MWP.Operation'; Operation = $Operation; Arguments = $ArgumentList } }
            $operation = Get-MwpStartupItem -Context $context -AsOperation
            $operation.Operation | Should -Be 'Startup.ListItems'
            $json = InModuleScope MWP.Remote -Parameters @{ Request = [string]$operation.Arguments[0] } {
                param($Request)
                $text = (& (Get-Module -Name MWP.Startup) { Get-MwpStartupScript -Name ItemList }).ToString()
                & ((Get-Module -Name MWP.Remote).NewBoundScriptBlock([scriptblock]::Create($text))) $Request
            }
            $list = Resolve-MwpStartupItemList -Data $json
            @($list.Items).Count | Should -Be 7
            Resolve-MwpStartupItemList -Data $null | Should -BeNullOrEmpty
        }

        It 'nieczytelny klucz: ostrzeżenie w wyniku, pozostałe źródła czytane dalej' {
            Mock -ModuleName MWP.Remote Get-ItemProperty -ParameterFilter { ([string](Get-Bound LiteralPath | Select-Object -First 1)) -like '*WOW6432Node*\Run' } { throw 'Odmowa dostępu.' }
            $result = Get-MwpStartupItem -Context $context
            $result.Success | Should -BeTrue
            @($result.Data.Warnings) -join ' ' | Should -Match 'Odmowa dostępu'
            $result.Data.Items.Name | Should -Not -Contain 'MwpTestPrinter'
            $result.Data.Items.Name | Should -Contain 'MwpTestAudio'
        }
    }

    Context 'widget Dashboardu (D-053)' {
        It 'widok „Autostart”: domyślnie podsumowanie; włączone i ryzykowne z parametrów; brak danych bez wyjątku' {
            $data = (Get-MwpStartupItem -Context $context).Data
            $view = ConvertTo-MwpStartupSummaryView -Data $data
            $view.PSObject.TypeNames | Should -Contain 'MWP.WidgetView'
            @($view.Sections | ForEach-Object Title) | Should -Be @('Autostart')
            $enabled = @($data.Items | Where-Object { $_.CanToggle -and $_.Enabled }).Count
            $view.Sections[0].Items[0].Value | Should -Be ([string]$enabled)
            $full = ConvertTo-MwpStartupSummaryView -Data $data -WidgetParameters @{ Sections = @('Enabled', 'Risky'); Top = 1 }
            @($full.Sections | ForEach-Object Title) | Should -Be @('Włączone programy', 'Do sprawdzenia')
            $full.Sections[0].Items[-1].Label | Should -Match 'innych'
            ConvertTo-MwpStartupSummaryView -Data $null | Should -BeNullOrEmpty
        }

        It 'bez sekcji „Ryzykowne” funkcja danych nie sprawdza podpisów (szybszy odczyt)' {
            Mock -ModuleName MWP.Startup Invoke-MwpStartupRead { [pscustomobject]@{ PSTypeName = 'MWP.Operation'; NoSignature = [bool]$NoSignature } }
            (Get-MwpStartupItem -Context $context -AsOperation -WidgetParameters @{ Sections = @('Summary') }).NoSignature | Should -BeTrue
            (Get-MwpStartupItem -Context $context -AsOperation -WidgetParameters @{ Sections = @('Summary', 'Risky') }).NoSignature | Should -BeFalse
            (Get-MwpStartupItem -Context $context -AsOperation).NoSignature | Should -BeFalse
        }
    }

    Context 'autostart — włączanie i wyłączanie (StartupApproved)' {
        It '-WhatIf: podgląd z nazwą komputera, bez zapisu do rejestru' {
            $item = (Get-ItemMap)['MwpTestChat']
            $result = Set-MwpStartupItemState -Id $item.Id -Enabled $false -Context $context -WhatIf
            $result.IsPreview | Should -BeTrue -Because $result.Message
            $result.Message | Should -Match 'nie jest kasowany'
            Get-Call 'SetValue' | Should -BeNullOrEmpty
        }

        It 'wyłączenie pozycji własnego profilu (bez administratora): 03 + czas wyłączenia, wpis Run zostaje, log i wpis cofnięcia' {
            $script:Fake.Admin = $false
            $item = (Get-ItemMap)['MwpTestChat']
            $result = Set-MwpStartupItemState -Id $item.Id -Enabled $false -Context $context -Confirm:$false
            $result.Success | Should -BeTrue -Because $result.Message
            $result.Changed | Should -BeTrue
            $result.After | Should -Be 'Wyłączony'
            $key = "Registry::HKEY_CURRENT_USER\SOFTWARE\$approved\Run".ToLowerInvariant()
            $script:Fake.Registry.ContainsKey($key) | Should -BeTrue -Because 'brakujący klucz StartupApproved\Run jest tworzony'
            $bytes = $script:Fake.Registry[$key]['MwpTestChat']
            $bytes.Length | Should -Be 12
            $bytes[0] | Should -Be 3
            [BitConverter]::ToInt64($bytes, 4) | Should -BeGreaterThan 0
            $script:Fake.Registry["Registry::HKEY_CURRENT_USER\SOFTWARE\$run\Run".ToLowerInvariant()]['MwpTestChat'] | Should -Match 'chat\.exe'
            (Get-ItemMap)['MwpTestChat'].Enabled | Should -BeFalse
            $undo = Get-MwpUndoEntry -Id $result.UndoId
            $undo.UndoCommand | Should -Be 'Set-MwpStartupItemState'
            $undo.UndoParameters.Enabled | Should -BeTrue
            Get-Log | Should -Match '"source":"MWP.Startup","operation":"Startup.SetItemState"'
        }

        It 'włączenie i wyłączenie zachowuje wyższe bity pierwszego bajtu (06 → 07 → 06)' {
            $script:Fake.Registry["$hklm\$approved\StartupFolder".ToLowerInvariant()]['MwpTest Monitor.lnk'] = (ConvertTo-ByteArray '060000000000000000000000')
            $item = (Get-ItemMap)['MwpTest Monitor.lnk']
            (Set-MwpStartupItemState -Id $item.Id -Enabled $false -Context $context -Confirm:$false).Success | Should -BeTrue
            $script:Fake.Registry["$hklm\$approved\StartupFolder".ToLowerInvariant()]['MwpTest Monitor.lnk'][0] | Should -Be 7
            (Set-MwpStartupItemState -Id $item.Id -Enabled $true -Context $context -Confirm:$false).Success | Should -BeTrue
            ConvertTo-Hex $script:Fake.Registry["$hklm\$approved\StartupFolder".ToLowerInvariant()]['MwpTest Monitor.lnk'] | Should -Be '060000000000000000000000'
        }

        It 'włączenie pozycji 32-bitowej (Run32) i cofnięcie przez rejestr cofnięć' {
            $item = (Get-ItemMap)['MwpTestPrinter']
            $result = Set-MwpStartupItemState -Id $item.Id -Enabled $true -Context $context -Confirm:$false
            $result.Success | Should -BeTrue -Because $result.Message
            ConvertTo-Hex $script:Fake.Registry["$hklm\$approved\Run32".ToLowerInvariant()]['MwpTestPrinter'] | Should -Be '020000000000000000000000'
            (Invoke-MwpUndo -Id $result.UndoId -Context $context -Confirm:$false).Success | Should -BeTrue
            (Get-ItemMap)['MwpTestPrinter'].Enabled | Should -BeFalse
            (Get-MwpUndoEntry -Id $result.UndoId).Status | Should -Be 'Undone'
        }

        It 'pozycja komputera bez administratora: odmowa przed podglądem, bez zapisu' {
            $script:Fake.Admin = $false
            $item = (Get-ItemMap)['MwpTestAudio']
            $result = Set-MwpStartupItemState -Id $item.Id -Enabled $false -Context $context -WhatIf
            $result.Success | Should -BeFalse
            $result.IsPreview | Should -BeFalse
            $result.Message | Should -Match 'administratora'
            Get-Call 'SetValue' | Should -BeNullOrEmpty
        }

        It 'RunOnce nie obsługuje przełączania; stan bez zmian nie zapisuje; nieznana pozycja i zły identyfikator' {
            $items = Get-ItemMap
            $result = Set-MwpStartupItemState -Id $items['MwpTestSetup'].Id -Enabled $false -Context $context -Confirm:$false
            $result.Success | Should -BeFalse
            $result.Message | Should -Match 'RunOnce'
            $same = Set-MwpStartupItemState -Id $items['MwpTestAudio'].Id -Enabled $true -Context $context -Confirm:$false
            $same.Success | Should -BeTrue
            $same.Changed | Should -BeFalse
            (Set-MwpStartupItemState -Id 'MachineRun||MwpTestBrak' -Enabled $false -Context $context -Confirm:$false).Message | Should -Match 'nie ma pozycji'
            { Set-MwpStartupItemState -Id 'zly-identyfikator' -Enabled $false -Context $context -WhatIf } | Should -Throw
            Get-Call 'SetValue' | Should -BeNullOrEmpty
        }

        It 'błąd zapisu: wynik z błędem i wpis w logu, bez wpisu cofnięcia' {
            $script:Fake.FailWrite = $true
            $item = (Get-ItemMap)['MwpTestChat']
            $result = Set-MwpStartupItemState -Id $item.Id -Enabled $false -Context $context -Confirm:$false
            $result.Success | Should -BeFalse
            $result.Message | Should -Match 'Odmowa dostępu'
            $result.UndoId | Should -BeNullOrEmpty
            Get-Log | Should -Match '"level":"Error"'
        }
    }

    Context 'harmonogram — odczyt' {
        It 'lista zadań: stan, wyzwalacze, konto, wynik, podpis (bez folderu \Microsoft\), lista ochronna' {
            $result = Get-MwpScheduledTask -Context $context
            $result.Success | Should -BeTrue -Because $result.Message
            $tasks = @{}
            foreach ($task in $result.Data.Tasks) { $tasks[$task.Path] = $task }
            $tasks.Count | Should -Be 5
            $updater = $tasks['\MwpTest Updater']
            $updater.StateText | Should -Be 'Gotowe'
            $updater.TriggerText | Should -Be 'przy logowaniu, codziennie'
            $updater.Account | Should -Be 'SYSTEM'
            $updater.Risk | Should -Be 'Signed'
            $updater.Publisher | Should -Be 'Updater Sp. z o.o.'
            $updater.LastResultText | Should -Match 'nie było jeszcze uruchamiane'
            $updater.NextRunTime | Should -BeNullOrEmpty -Because 'data 1999-11-30 oznacza brak'
            $updater.CanRemove | Should -BeTrue
            $backup = $tasks['\MwpTest\Backup [x]']
            $backup.Enabled | Should -BeFalse
            $backup.HasStoredPassword | Should -BeTrue
            $backup.Risk | Should -Be 'Unsigned'
            $sr = $tasks['\Microsoft\Windows\SystemRestore\SR']
            $sr.IsMicrosoft | Should -BeTrue
            $sr.IsProtected | Should -BeTrue
            $sr.CanRemove | Should -BeFalse
            $sr.Risk | Should -Be 'NotChecked'
            $maint = $tasks['\Microsoft\Windows\MwpTestMaint\Cleanup']
            $maint.IsProtected | Should -BeFalse
            $maint.CanRemove | Should -BeFalse
            $maint.RemovalReason | Should -Not -BeNullOrEmpty
        }

        It 'filtry: bez zadań Microsoft, stan, tylko chronione, tekst' {
            @((Get-MwpScheduledTask -Context $context -HideMicrosoft).Data.Tasks).Count | Should -Be 3
            @((Get-MwpScheduledTask -Context $context -State Disabled).Data.Tasks.Path) | Should -Be @('\MwpTest\Backup [x]')
            @((Get-MwpScheduledTask -Context $context -ProtectedOnly).Data.Tasks.Path) | Should -Be @('\Microsoft\Windows\SystemRestore\SR')
            @((Get-MwpScheduledTask -Context $context -Search 'report').Data.Tasks).Count | Should -Be 2
        }

        It 'folder i nazwa zadania są walidowane (bez symboli wieloznacznych w folderze)' {
            Test-MwpScheduledTaskName -TaskPath '\' -TaskName 'Zadanie' | Should -BeTrue
            Test-MwpScheduledTaskName -TaskPath '\Microsoft\Windows\Defrag\' -TaskName 'ScheduledDefrag' | Should -BeTrue
            Test-MwpScheduledTaskName -TaskPath '\MwpTest\' -TaskName 'Backup [x]' | Should -BeTrue
            Test-MwpScheduledTaskName -TaskPath '\MwpTest\' -TaskName 'OneDrive Task-S-1-5-21-1' | Should -BeTrue
            foreach ($invalid in @(@('Microsoft\', 'a'), @('\Micro*\', 'a'), @('\a', 'b'), @('\[a]\', 'b'), @('\', 'a*'), @('\', 'a\b'), @('\', ' a'), @('\', ''), @('\', 'a?'))) {
                Test-MwpScheduledTaskName -TaskPath $invalid[0] -TaskName $invalid[1] | Should -BeFalse -Because ($invalid -join '|')
            }
            (Set-MwpScheduledTaskState -TaskPath '\Micro*\' -TaskName 'SR' -Enabled $false -Context $context -Confirm:$false).Message | Should -Match 'Niepoprawny'
            Get-Call 'Disable' | Should -BeNullOrEmpty
        }
    }

    Context 'harmonogram — zmiany' {
        It 'wyłączenie i włączenie zadania (nazwa z nawiasami), wpis cofnięcia i cofnięcie' {
            $result = Set-MwpScheduledTaskState -TaskPath '\' -TaskName 'MwpTest Updater' -Enabled $false -Context $context -Confirm:$false
            $result.Success | Should -BeTrue -Because $result.Message
            $script:Fake.Tasks['\MwpTest Updater'].State | Should -Be 'Disabled'
            (Invoke-MwpUndo -Id $result.UndoId -Context $context -Confirm:$false).Success | Should -BeTrue
            $script:Fake.Tasks['\MwpTest Updater'].State | Should -Be 'Ready'
            $enable = Set-MwpScheduledTaskState -TaskPath '\MwpTest\' -TaskName 'Backup [x]' -Enabled $true -Context $context -Confirm:$false
            $enable.Success | Should -BeTrue -Because $enable.Message
            Get-Call 'Enable \MwpTest\Backup [x]' | Should -HaveCount 1
            Get-Log | Should -Match '"operation":"Startup.SetTaskState"'
        }

        It '-WhatIf i stan bez zmian nie wywołują Enable/Disable' {
            $preview = Set-MwpScheduledTaskState -TaskPath '\' -TaskName 'MwpTest Updater' -Enabled $false -Context $context -WhatIf
            $preview.IsPreview | Should -BeTrue
            $same = Set-MwpScheduledTaskState -TaskPath '\' -TaskName 'MwpTest Updater' -Enabled $true -Context $context -Confirm:$false
            $same.Changed | Should -BeFalse
            Get-Call 'Disable' | Should -BeNullOrEmpty
            Get-Call 'Enable' | Should -BeNullOrEmpty
        }

        It 'zadanie chronione: wyłączenie i usunięcie zablokowane, uruchomienie dozwolone' {
            $disable = Set-MwpScheduledTaskState -TaskPath '\Microsoft\Windows\SystemRestore\' -TaskName 'SR' -Enabled $false -Context $context -Confirm:$false
            $disable.Success | Should -BeFalse
            $disable.Message | Should -Match 'liście ochronnej'
            (Remove-MwpScheduledTask -TaskPath '\Microsoft\Windows\SystemRestore\' -TaskName 'SR' -Context $context -Confirm:$false).Success | Should -BeFalse
            (Remove-MwpScheduledTask -TaskPath '\Microsoft\Windows\MwpTestMaint\' -TaskName 'Cleanup' -Context $context -Confirm:$false).Message | Should -Match 'nie można go usunąć'
            (Set-MwpScheduledTaskState -TaskPath '\Microsoft\Windows\MwpTestMaint\' -TaskName 'Cleanup' -Enabled $false -Context $context -Confirm:$false).Success | Should -BeTrue
            (Start-MwpScheduledTask -TaskPath '\Microsoft\Windows\SystemRestore\' -TaskName 'SR' -Context $context -Confirm:$false).Success | Should -BeTrue
            Get-Call 'Remove' | Should -BeNullOrEmpty
            Get-Call 'Export' | Should -BeNullOrEmpty
            Get-Call 'Disable \Microsoft\Windows\SystemRestore' | Should -BeNullOrEmpty
        }

        It 'brak administratora: odmowa przed podglądem dla każdej zmiany zadania' {
            $script:Fake.Admin = $false
            foreach ($result in @(
                    Set-MwpScheduledTaskState -TaskPath '\' -TaskName 'MwpTest Updater' -Enabled $false -Context $context -WhatIf
                    Start-MwpScheduledTask -TaskPath '\' -TaskName 'MwpTest Updater' -Context $context -WhatIf
                    Remove-MwpScheduledTask -TaskPath '\' -TaskName 'MwpTest Updater' -Context $context -WhatIf
                )) {
                $result.Success | Should -BeFalse
                $result.IsPreview | Should -BeFalse
                $result.Message | Should -Match 'administratora'
            }
        }

        It 'uruchomienie: zadanie wyłączone — odmowa; włączone — Start bez wpisu cofnięcia' {
            (Start-MwpScheduledTask -TaskPath '\MwpTest\' -TaskName 'Backup [x]' -Context $context -Confirm:$false).Message | Should -Match 'wyłączone'
            (Start-MwpScheduledTask -TaskPath '\' -TaskName 'MwpTest Updater' -Context $context -WhatIf).Message | Should -Match 'nie da się cofnąć'
            $result = Start-MwpScheduledTask -TaskPath '\' -TaskName 'MwpTest Updater' -Context $context -Confirm:$false
            $result.Success | Should -BeTrue -Because $result.Message
            $result.UndoId | Should -BeNullOrEmpty
            $script:Fake.Tasks['\MwpTest Updater'].State | Should -Be 'Running'
            Get-Call 'Start' | Should -HaveCount 1
        }

        It 'usunięcie: -WhatIf bez eksportu; potem eksport XML (UTF-16) przed usunięciem, cofnięcie odtwarza zadanie' {
            $preview = Remove-MwpScheduledTask -TaskPath '\MwpTest\' -TaskName 'Report' -Context $context -WhatIf
            $preview.IsPreview | Should -BeTrue
            $preview.Message | Should -Match 'exports\\tasks'
            Get-Call 'Export' | Should -BeNullOrEmpty
            $result = Remove-MwpScheduledTask -TaskPath '\MwpTest\' -TaskName 'Report' -Context $context -Confirm:$false
            $result.Success | Should -BeTrue -Because $result.Message
            @($script:Calls | Where-Object { $_ -like 'Export*' -or $_ -like 'Remove*' }) | Should -Be @('Export \MwpTest\Report', 'Remove \MwpTest\Report')
            $file = $result.Data.ExportPath
            $file | Should -BeLike (Join-Path -Path $TestDrive -ChildPath 'exports\tasks\*.xml')
            [IO.File]::ReadAllBytes($file)[0..1] | Should -Be @(0xFF, 0xFE)
            [IO.File]::ReadAllText($file) | Should -Match '<LogonType>Interactive</LogonType>'
            $script:Fake.Tasks.Contains('\MwpTest\Report') | Should -BeFalse
            $undo = Invoke-MwpUndo -Id $result.UndoId -Context $context -Confirm:$false
            $undo.Success | Should -BeTrue -Because $undo.Message
            Get-Call 'Register \MwpTest\Report' | Should -HaveCount 1
            $script:Fake.Tasks['\MwpTest\Report'].Xml | Should -Match 'Interactive'
        }

        It 'nieudany eksport przerywa usunięcie; zadanie z hasłem: ostrzeżenie w podglądzie i odmowa automatycznego odtworzenia' {
            $script:Fake.FailTask = @('Export')
            $failed = Remove-MwpScheduledTask -TaskPath '\' -TaskName 'MwpTest Updater' -Context $context -Confirm:$false
            $failed.Success | Should -BeFalse
            $failed.Message | Should -Match 'eksport'
            Get-Call 'Remove' | Should -BeNullOrEmpty
            $script:Fake.FailTask = @()
            (Remove-MwpScheduledTask -TaskPath '\MwpTest\' -TaskName 'Backup [x]' -Context $context -WhatIf).Message | Should -Match 'hasło'
            $result = Remove-MwpScheduledTask -TaskPath '\MwpTest\' -TaskName 'Backup [x]' -Context $context -Confirm:$false
            $result.Success | Should -BeTrue -Because $result.Message
            $restore = Restore-MwpScheduledTask -XmlPath $result.Data.ExportPath -TaskPath '\MwpTest\' -TaskName 'Backup [x]' -Context $context -Confirm:$false
            $restore.Success | Should -BeFalse
            $restore.Message | Should -Match 'Importuj'
            Get-Call 'Register' | Should -BeNullOrEmpty
        }

        It 'odtworzenie odmawia, gdy zadanie już istnieje albo plik XML jest uszkodzony' {
            $file = Join-Path -Path $TestDrive -ChildPath 'zadanie.xml'
            [IO.File]::WriteAllText($file, $script:Fake.Tasks['\MwpTest\Report'].Xml, [Text.Encoding]::Unicode)
            (Restore-MwpScheduledTask -XmlPath $file -TaskPath '\MwpTest\' -TaskName 'Report' -Context $context -Confirm:$false).Message | Should -Match 'już istnieje'
            Set-Content -LiteralPath $file -Value '<Task' -Encoding UTF8
            (Restore-MwpScheduledTask -XmlPath $file -TaskPath '\MwpTest\' -TaskName 'Nowe' -Context $context -Confirm:$false).Message | Should -Match 'Nie można odczytać'
            Get-Call 'Register' | Should -BeNullOrEmpty
        }

        It 'odmowa dostępu przy zmianie: komunikat po polsku, bez wpisu cofnięcia' {
            $script:Fake.FailTask = @('Disable')
            $result = Set-MwpScheduledTaskState -TaskPath '\' -TaskName 'MwpTest Updater' -Enabled $false -Context $context -Confirm:$false
            $result.Success | Should -BeFalse
            $result.Message | Should -Match 'odmowa dostępu|Odmowa dostępu'
            $result.UndoId | Should -BeNullOrEmpty
        }
    }

    Context 'komputer zdalny (D-019, D-046)' {
        BeforeEach {
            Mock -ModuleName MWP.Remote Remove-MwpPSSession { }
            Mock -ModuleName MWP.Remote New-MwpPSSession { [pscustomobject]@{ ComputerName = $ComputerName; State = 'Opened' } }
            # „Zdalne” wykonanie: blok związany z zakresem MWP.Remote (tam działają mocki symulatora).
            Mock -ModuleName MWP.Remote Invoke-MwpSessionCommand {
                $bound = (Get-Module -Name MWP.Remote).NewBoundScriptBlock($ScriptBlock)
                [pscustomobject]@{ Output = @(& $bound @ArgumentList); Errors = @() }
            }
            # Sprawdzenie administratora w sesji (Test-MwpStartupAdmin): krótki blok bez żądania JSON.
            Mock -ModuleName MWP.Remote Invoke-MwpSessionCommand -ParameterFilter { $ScriptBlock.ToString() -match 'IsInRole' -and $ScriptBlock.ToString() -notmatch 'RequestJson' } {
                [pscustomobject]@{ Output = @($script:Fake.Admin); Errors = @() }
            }
            $remote = New-MwpExecutionContext -ComputerName $remoteName
        }

        It 'odczyt: pozycje systemowe i profile zalogowanych użytkowników (gałąź HKEY_USERS z SID)' {
            $result = Get-MwpStartupItem -Context $remote
            $result.Success | Should -BeTrue -Because $result.Message
            $result.ComputerName | Should -Be $remoteName
            $list = $result.Data
            $list.UserMode | Should -Be 'LoggedOn'
            @($list.Users).Sid | Should -Be @($remoteSid)
            $remoteItem = @($list.Items | Where-Object { $_.Name -eq 'MwpTestRemoteChat' })[0]
            $remoteItem.UserSid | Should -Be $remoteSid
            $remoteItem.Source | Should -Match ([regex]::Escape("HKEY_USERS\$remoteSid"))
            $list.Items.Name | Should -Not -Contain 'MwpTestChat' -Because 'HKCU konta połączenia nie jest pokazywany'
            $list.Items.Name | Should -Contain 'MwpTestAudio'
        }

        It 'bez zalogowanych użytkowników: tylko pozycje systemowe z ostrzeżeniem' {
            $script:Fake.Explorer = @()
            $result = Get-MwpStartupItem -Context $remote
            $result.Success | Should -BeTrue
            @($result.Data.Items | Where-Object Scope -eq 'User').Count | Should -Be 0
            @($result.Data.Warnings) -join ' ' | Should -Match 'nie jest zalogowany'
        }

        It 'zmiana pozycji profilu innego użytkownika wymaga administratora (sprawdzanego w sesji); log i cofnięcie z nazwą komputera' {
            $item = @((Get-MwpStartupItem -Context $remote).Data.Items | Where-Object { $_.Name -eq 'MwpTestRemoteChat' })[0]
            $script:Fake.Admin = $false
            (Set-MwpStartupItemState -Id $item.Id -Enabled $false -Context $remote -Confirm:$false).Message | Should -Match ('administratora na komputerze ''{0}''' -f $remoteName)
            Get-Call 'SetValue' | Should -BeNullOrEmpty
            $script:Fake.Admin = $true
            $result = Set-MwpStartupItemState -Id $item.Id -Enabled $false -Context $remote -Confirm:$false
            $result.Success | Should -BeTrue -Because $result.Message
            Get-Call ('SetValue registry::hkey_users\{0}' -f $remoteSid.ToLowerInvariant()) | Should -HaveCount 1
            (Get-MwpUndoEntry -Id $result.UndoId).ComputerName | Should -Be $remoteName
            Should -Invoke Test-MwpAdmin -ModuleName MWP.Startup -Times 0 -Exactly
            Get-Log | Should -Match ('"computer":"{0}","source":"MWP.Startup","operation":"Startup.SetItemState"' -f $remoteName)
            (Invoke-MwpUndo -Id $result.UndoId -Context $context -Confirm:$false).Success | Should -BeFalse
            (Invoke-MwpUndo -Id $result.UndoId -Context $remote -Confirm:$false).Success | Should -BeTrue
        }

        It 'harmonogram zdalnie: lista ochronna jak lokalnie, zmiana i usunięcie z eksportem po stronie hosta' {
            (Set-MwpScheduledTaskState -TaskPath '\Microsoft\Windows\SystemRestore\' -TaskName 'SR' -Enabled $false -Context $remote -Confirm:$false).Success | Should -BeFalse
            $result = Remove-MwpScheduledTask -TaskPath '\' -TaskName 'MwpTest Updater' -Context $remote -Confirm:$false
            $result.Success | Should -BeTrue -Because $result.Message
            $result.ComputerName | Should -Be $remoteName
            Split-Path -Leaf $result.Data.ExportPath | Should -BeLike "$remoteName*"
            Test-Path -LiteralPath $result.Data.ExportPath | Should -BeTrue
        }

        It 'utrata połączenia: wynik z błędem dla tej instancji, bez zmiany; localhost działa dalej' {
            Mock -ModuleName MWP.Remote Invoke-MwpSessionCommand { throw (New-Object -TypeName Management.Automation.Remoting.PSRemotingTransportException -ArgumentList 'Połączenie zerwane') }
            $result = Set-MwpScheduledTaskState -TaskPath '\' -TaskName 'MwpTest Updater' -Enabled $false -Context $remote -Confirm:$false
            $result.Success | Should -BeFalse
            $result.ComputerName | Should -Be $remoteName
            $remote.Connection.State | Should -Be 'Disconnected'
            $script:Fake.Tasks['\MwpTest Updater'].State | Should -Be 'Ready'
            (Get-MwpStartupItem -Context $remote).Success | Should -BeFalse
            (Get-MwpScheduledTask -Context $context).Success | Should -BeTrue
        }
    }

    Context 'kontrakt modułu, bloki komputera docelowego, lista ochronna i ocena podpisu' {
        It 'kontrakt jest poprawny: RemoteTarget, tryby Embedded i SeparateWindow' {
            $definition = Get-MwpModuleDefinition -Name 'MWP.Startup'
            $definition.IsValid | Should -BeTrue -Because ($definition.Errors -join ' ')
            $definition.Capabilities | Should -Contain 'RemoteTarget'
            $definition.SupportedPresentationModes | Should -Contain 'SeparateWindow'
            foreach ($command in 'Get-MwpStartupItem', 'Set-MwpStartupItemState', 'Get-MwpScheduledTask', 'Set-MwpScheduledTaskState', 'Start-MwpScheduledTask', 'Remove-MwpScheduledTask', 'Restore-MwpScheduledTask') {
                (Get-Command -Name $command).Parameters.ContainsKey('Context') | Should -BeTrue -Because $command
            }
            foreach ($command in 'Set-MwpStartupItemState', 'Set-MwpScheduledTaskState', 'Start-MwpScheduledTask', 'Remove-MwpScheduledTask', 'Restore-MwpScheduledTask') {
                (Get-Command -Name $command).Parameters.ContainsKey('WhatIf') | Should -BeTrue -Because $command
            }
        }

        It 'bloki nie używają funkcji MWP, Invoke-Expression ani $using:' {
            foreach ($name in 'ItemList', 'ItemState', 'TaskList', 'TaskControl') {
                $block = InModuleScope MWP.Startup -Parameters @{ Name = $name } { param($Name) Get-MwpStartupScript -Name $Name }
                $commands = @($block.Ast.FindAll({ param($node) $node -is [Management.Automation.Language.CommandAst] }, $true) | ForEach-Object { $_.GetCommandName() } | Where-Object { $_ })
                @($commands | Where-Object { $_ -match '-Mwp' }) | Should -BeNullOrEmpty -Because $name
                $block.ToString() | Should -Not -Match 'Invoke-Expression|\$using:'
            }
            (InModuleScope MWP.Startup { Get-MwpStartupScript -Name ItemState }).ToString() | Should -Not -Match 'Remove-ItemProperty|Remove-Item'
        }

        It 'lista ochronna: zadania krytyczne (Task) i blokada usuwania \Microsoft\* (TaskRemoval)' {
            (Get-MwpProtectedItem -Category TaskRemoval -Name '\Microsoft\Windows\Defrag\ScheduledDefrag').Source | Should -Be 'BuiltIn'
            foreach ($path in '\Microsoft\Windows\WindowsUpdate\Scheduled Start', '\Microsoft\Windows\Windows Defender\Windows Defender Scheduled Scan', '\Microsoft\Windows\SystemRestore\SR') {
                Test-MwpProtectedItem -Category Task -Name $path | Should -BeTrue -Because $path
            }
            Test-MwpProtectedItem -Category Task -Name '\MwpTest Updater' | Should -BeFalse
            Test-MwpProtectedItem -Category TaskRemoval -Name '\MwpTest Updater' | Should -BeFalse
        }

        It 'ocena podpisu: <Status> → <Risk>' -ForEach @(
            @{ Status = 'Valid'; Subject = 'CN=Contoso, O=Contoso'; Risk = 'Signed' }
            @{ Status = 'NotSigned'; Subject = ''; Risk = 'Unsigned' }
            @{ Status = 'NotSupportedFileFormat'; Subject = ''; Risk = 'Unsigned' }
            @{ Status = 'UnknownError'; Subject = ''; Risk = 'Unsigned' }
            @{ Status = 'UnknownError'; Subject = 'CN=X'; Risk = 'Invalid' }
            @{ Status = 'HashMismatch'; Subject = 'CN=X'; Risk = 'Invalid' }
            @{ Status = 'NotTrusted'; Subject = 'CN=X'; Risk = 'Invalid' }
            @{ Status = 'Missing'; Subject = ''; Risk = 'Missing' }
            @{ Status = 'NoProgram'; Subject = ''; Risk = 'NotApplicable' }
            @{ Status = ''; Subject = ''; Risk = 'Unknown' }
        ) {
            (Get-MwpSignatureRisk -SignatureStatus $Status -SignerSubject $Subject).Risk | Should -Be $Risk
        }

        It 'wydawca z tematu certyfikatu: CN, CN w cudzysłowie, O bez CN' {
            (Get-MwpSignatureRisk -SignatureStatus Valid -SignerSubject 'CN=Microsoft Corporation, O=Microsoft Corporation, L=Redmond').Publisher | Should -Be 'Microsoft Corporation'
            (Get-MwpSignatureRisk -SignatureStatus Valid -SignerSubject 'CN="Fabrikam, Inc.", O=Fabrikam').Publisher | Should -Be 'Fabrikam, Inc.'
            (Get-MwpSignatureRisk -SignatureStatus Valid -SignerSubject 'OU=Dział, O=Firma Sp. z o.o.').Publisher | Should -Be 'Firma Sp. z o.o.'
            (Get-MwpSignatureRisk -SignatureStatus NotSigned).Publisher | Should -BeNullOrEmpty
        }
    }
}
