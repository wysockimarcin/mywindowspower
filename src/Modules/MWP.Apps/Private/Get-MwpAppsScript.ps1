function Get-MwpAppsScript {
    <#
    .SYNOPSIS
        Zwraca blok skryptu wykonywany na komputerze docelowym (Invoke-MwpOnTarget / Start-MwpOperation).

    .DESCRIPTION
        Bloki są samowystarczalne i zgodne z Windows PowerShell 5.1 (D-036): dane przychodzą przez
        parametry (żądanie JSON z hosta, wartości sprawdzone przed wysłaniem, D-015), wynik wraca jako
        tekst JSON. Tekst winget nie jest interpretowany na komputerze docelowym — blok zwraca linie
        i kod wyjścia, a tabelę czyta host (ConvertFrom-MwpWingetOutput, D-050).
        - Inventory: programy z rejestru (klucze Uninstall komputera 64/32 bit, profilu bieżącego
          użytkownika albo wskazanych profili z HKEY_USERS), pakiety Appx bieżącego konta (z nazwą
          z menu Start), załadowane profile, uprawnienia administratora.
        - Winget: uruchomienie winget.exe z podanymi argumentami (każdy osobno, bez sklejania tekstu
          wejściowego) z limitem czasu; wyjście dekodowane stroną kodową OEM komputera docelowego.
        - RemoveAppx: Remove-AppxPackage pakietu bieżącego konta i sprawdzenie, że zniknął.
        - WingetTask (D-051): winget przez jednorazowe zadania harmonogramu — jako SYSTEM (programy
          komputera; winget.exe z pakietu App Installer wszystkich użytkowników) albo w sesji
          zalogowanego użytkownika (jego programy; zadanie Interactive, bez hasła); opcjonalnie też
          uruchomienie bezpośrednie (Direct). Zadania \MyWindowsPower\MWP-Winget-<GUID> uruchamiają
          stały skrypt (Get-MwpWingetTaskScript) z blokiem Winget w żądaniu; wynik w pliku JSON
          w katalogu tylko dla SYSTEM i Administratorów (zadanie użytkownika — podkatalog z prawem
          zapisu dla niego). Odpytywanie z limitem, zatrzymanie zadania i drzewa procesów po
          przekroczeniu limitu albo przerwaniu, usunięcie zadania i plików zawsze; osierocone zadania
          i pliki z poprzednich wywołań są usuwane na początku. Wymaga administratora.

    .PARAMETER Name
        Nazwa bloku.
    #>
    [CmdletBinding()]
    [OutputType([scriptblock])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Inventory', 'Winget', 'WingetTask', 'RemoveAppx')]
        [string] $Name
    )

    switch ($Name) {
        'Inventory' {
            {
                param([string] $RequestJson)
                $request = ConvertFrom-Json -InputObject $RequestJson
                $warnings = @()
                $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
                $principal = New-Object -TypeName Security.Principal.WindowsPrincipal -ArgumentList $identity
                $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
                $currentSid = [string]$identity.User.Value
                $is64 = [Environment]::Is64BitOperatingSystem
                $uninstallPath = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall'
                $wowPath = 'SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
                # Odczyt przez .NET (RegistryKey) — kilkaset kluczy szybciej niż Get-ItemProperty w 5.1.
                $machine = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, [Microsoft.Win32.RegistryView]::Registry64)
                $users = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::Users, [Microsoft.Win32.RegistryView]::Registry64)
                $found = New-Object -TypeName System.Collections.Generic.List[object]
                $readKey = {
                    param([Microsoft.Win32.RegistryKey] $Base, [string] $Path, [string] $Scope, [string] $Architecture, [string] $UserSid, [string] $UserName)
                    $parent = $Base.OpenSubKey($Path)
                    if ($null -eq $parent) {
                        return
                    }
                    try {
                        foreach ($name in $parent.GetSubKeyNames()) {
                            $key = $null
                            try {
                                $key = $parent.OpenSubKey($name)
                            }
                            catch {
                                $key = $null
                            }
                            if ($null -eq $key) {
                                continue
                            }
                            try {
                                $displayName = [string]$key.GetValue('DisplayName')
                                if ([string]::IsNullOrWhiteSpace($displayName)) {
                                    continue
                                }
                                $size = $key.GetValue('EstimatedSize')
                                $found.Add([pscustomobject]@{
                                        KeyName          = [string]$name
                                        Scope            = $Scope
                                        Architecture     = $Architecture
                                        UserSid          = $UserSid
                                        UserName         = $UserName
                                        DisplayName      = $displayName.Trim()
                                        DisplayVersion   = [string]$key.GetValue('DisplayVersion')
                                        Publisher        = [string]$key.GetValue('Publisher')
                                        InstallDate      = [string]$key.GetValue('InstallDate')
                                        InstallLocation  = [string]$key.GetValue('InstallLocation')
                                        EstimatedSizeKb  = $(if ($size -is [int] -or $size -is [long]) { [long]$size } else { [long]0 })
                                        HasUninstall     = -not [string]::IsNullOrWhiteSpace([string]$key.GetValue('UninstallString'))
                                        HasQuiet         = -not [string]::IsNullOrWhiteSpace([string]$key.GetValue('QuietUninstallString'))
                                        WindowsInstaller = [string]$key.GetValue('WindowsInstaller') -eq '1'
                                        SystemComponent  = [string]$key.GetValue('SystemComponent') -eq '1'
                                        NoRemove         = [string]$key.GetValue('NoRemove') -eq '1'
                                        ParentKeyName    = [string]$key.GetValue('ParentKeyName')
                                        ReleaseType      = [string]$key.GetValue('ReleaseType')
                                    })
                            }
                            finally {
                                $key.Close()
                            }
                        }
                    }
                    finally {
                        $parent.Close()
                    }
                }

                $profiles = @()
                $appx = @()
                $errorText = $null
                try {
                    & $readKey $machine $uninstallPath 'Machine' $(if ($is64) { 'X64' } else { 'X86' }) '' ''
                    if ($is64) {
                        & $readKey $machine $wowPath 'Machine' 'X86' '' ''
                    }

                    # Załadowane profile użytkowników (HKEY_USERS\S-1-5-21-…), do wyboru w widoku.
                    foreach ($sid in @($users.GetSubKeyNames())) {
                        if ($sid -notmatch '^S-1-5-21-[0-9-]+$') {
                            continue
                        }
                        $userName = $sid
                        try {
                            $userName = [string](New-Object -TypeName Security.Principal.SecurityIdentifier -ArgumentList $sid).Translate([Security.Principal.NTAccount]).Value
                        }
                        catch {
                            $userName = $sid
                        }
                        $profiles += [pscustomobject]@{ Sid = $sid; Name = $userName; IsCurrent = $sid -eq $currentSid }
                    }

                    # Programy profili: bieżące konto (HKCU) albo wskazane profile (HKEY_USERS\<SID>).
                    $userArch = if ($is64) { 'X64' } else { 'X86' }
                    $userPath = 'Software\Microsoft\Windows\CurrentVersion\Uninstall'
                    if ([bool]$request.CurrentUser) {
                        & $readKey ([Microsoft.Win32.Registry]::CurrentUser) $userPath 'User' $userArch $currentSid ([string]$identity.Name)
                    }
                    foreach ($sid in @($request.UserSids | Where-Object { $_ })) {
                        $sid = [string]$sid
                        $userProfile = @($profiles | Where-Object { $_.Sid -eq $sid }) | Select-Object -First 1
                        if ($null -eq $userProfile) {
                            $warnings += ('Profil {0} nie jest załadowany (użytkownik nie jest zalogowany) — jego programy są pominięte.' -f $sid)
                            continue
                        }
                        if ([bool]$request.CurrentUser -and $sid -eq $currentSid) {
                            continue
                        }
                        & $readKey $users ($sid + '\' + $userPath) 'User' $userArch $sid $userProfile.Name
                    }

                    if ([bool]$request.IncludeAppx) {
                        $packages = @()
                        try {
                            $packages = @(Get-AppxPackage -ErrorAction Stop)
                        }
                        catch {
                            $warnings += ('Pakiety Appx: ' + $_.Exception.Message)
                        }
                        # Nazwy wyświetlane: menu Start (AppID = rodzina!aplikacja), potem rejestr pakietów, potem Name.
                        $startNames = @{}
                        if ($packages.Count -gt 0) {
                            try {
                                foreach ($app in @(Get-StartApps)) {
                                    $appId = [string]$app.AppID
                                    if ($appId -match '^([^!\\]+)!') {
                                        if (-not $startNames.ContainsKey($Matches[1])) {
                                            $startNames[$Matches[1]] = [string]$app.Name
                                        }
                                    }
                                }
                            }
                            catch {
                                $startNames = @{}
                            }
                        }
                        $repository = 'Registry::HKEY_CURRENT_USER\Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\Repository\Packages'
                        foreach ($package in $packages) {
                            $display = $null
                            if ($startNames.ContainsKey([string]$package.PackageFamilyName)) {
                                $display = $startNames[[string]$package.PackageFamilyName]
                            }
                            if (-not $display) {
                                try {
                                    $value = [string](Get-ItemProperty -LiteralPath ('{0}\{1}' -f $repository, $package.PackageFullName) -Name 'DisplayName' -ErrorAction Stop).DisplayName
                                    if ($value -and -not $value.StartsWith('@') -and $value -notlike 'ms-resource:*') {
                                        $display = $value
                                    }
                                }
                                catch {
                                    $display = $null
                                }
                            }
                            $appx += [pscustomobject]@{
                                Name              = [string]$package.Name
                                DisplayName       = [string]$display
                                PackageFullName   = [string]$package.PackageFullName
                                PackageFamilyName = [string]$package.PackageFamilyName
                                Publisher         = [string]$package.Publisher
                                Version           = [string]$package.Version
                                Architecture      = [string]$package.Architecture
                                SignatureKind     = [string]$package.SignatureKind
                                IsFramework       = [bool]$package.IsFramework
                                IsResourcePackage = [bool]$package.IsResourcePackage
                                IsBundle          = [bool]$package.IsBundle
                                NonRemovable      = [bool]$package.NonRemovable
                                InstallLocation   = [string]$package.InstallLocation
                            }
                        }
                    }
                }
                catch {
                    $errorText = $_.Exception.Message
                }
                ConvertTo-Json -Depth 4 -Compress -InputObject ([pscustomobject]@{
                        Kind            = 'MWP.AppInventoryRaw'
                        ComputerName    = $env:COMPUTERNAME
                        CollectedAt     = (Get-Date).ToString('o')
                        IsAdministrator = $isAdmin
                        CurrentUser     = [string]$identity.Name
                        CurrentUserSid  = $currentSid
                        Registry        = $found.ToArray()
                        Appx            = @($appx)
                        Profiles        = @($profiles)
                        Warnings        = @($warnings)
                        Error           = $errorText
                    })
            }
        }
        'Winget' {
            {
                param([string] $RequestJson)
                $request = ConvertFrom-Json -InputObject $RequestJson
                $started = Get-Date
                $path = [string]$request.WingetPath
                $found = $false
                $lines = @()
                $exitCode = $null
                $errorText = $null
                $timedOut = $false
                try {
                    if (-not $path) {
                        # Alias użytkownika (sesja interaktywna), potem plik z pakietu App Installer bieżącego konta.
                        $alias = Join-Path -Path ([Environment]::GetFolderPath('LocalApplicationData')) -ChildPath 'Microsoft\WindowsApps\winget.exe'
                        if (Test-Path -LiteralPath $alias) {
                            $path = $alias
                        }
                        else {
                            try {
                                $installer = @(Get-AppxPackage -Name 'Microsoft.DesktopAppInstaller' -ErrorAction Stop | Sort-Object -Property Version -Descending) | Select-Object -First 1
                                if ($null -ne $installer -and $installer.InstallLocation) {
                                    $candidate = Join-Path -Path ([string]$installer.InstallLocation) -ChildPath 'winget.exe'
                                    if (Test-Path -LiteralPath $candidate) {
                                        $path = $candidate
                                    }
                                }
                            }
                            catch {
                                $path = ''
                            }
                        }
                    }
                    if ($path -and (Test-Path -LiteralPath $path)) {
                        $found = $true
                        $codePage = 437
                        try {
                            $codePage = [int](Get-ItemProperty -LiteralPath 'Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Nls\CodePage' -Name 'OEMCP' -ErrorAction Stop).OEMCP
                        }
                        catch {
                            $codePage = 437
                        }
                        $encoding = $null
                        try {
                            $encoding = [Text.Encoding]::GetEncoding($codePage)
                        }
                        catch {
                            $encoding = [Text.Encoding]::UTF8
                        }
                        # Argumenty sprawdzone na hoście (bez cudzysłowów); ze spacją — w cudzysłowie.
                        $arguments = @(foreach ($argument in @($request.Arguments)) {
                                $text = [string]$argument
                                if ($text -match '\s') { '"' + $text + '"' } else { $text }
                            }) -join ' '
                        $info = New-Object -TypeName System.Diagnostics.ProcessStartInfo
                        $info.FileName = $path
                        $info.Arguments = $arguments
                        $info.UseShellExecute = $false
                        $info.CreateNoWindow = $true
                        $info.RedirectStandardOutput = $true
                        $info.RedirectStandardError = $true
                        $info.StandardOutputEncoding = $encoding
                        $info.StandardErrorEncoding = $encoding
                        $process = [Diagnostics.Process]::Start($info)
                        $outputTask = $process.StandardOutput.ReadToEndAsync()
                        $errorTask = $process.StandardError.ReadToEndAsync()
                        $limit = [int]$request.TimeoutSeconds
                        if ($limit -le 0) {
                            $limit = 300
                        }
                        if (-not $process.WaitForExit($limit * 1000)) {
                            $timedOut = $true
                            try {
                                $process.Kill()
                            }
                            catch {
                                $timedOut = $true
                            }
                            $null = $process.WaitForExit(5000)
                        }
                        $text = [string]$outputTask.Result + [Environment]::NewLine + [string]$errorTask.Result
                        if (-not $timedOut) {
                            $exitCode = [long]$process.ExitCode
                        }
                        foreach ($line in ($text -split "`n")) {
                            # Wskaźniki postępu winget nadpisują linię znakiem CR — zostaje ostatni fragment.
                            $last = @($line -split "`r" | Where-Object { $_.Trim() }) | Select-Object -Last 1
                            if ($null -ne $last) {
                                $lines += ([string]$last).TrimEnd()
                            }
                            else {
                                $lines += ''
                            }
                        }
                    }
                }
                catch {
                    $errorText = $_.Exception.Message
                }
                ConvertTo-Json -Depth 3 -Compress -InputObject ([pscustomobject]@{
                        Kind         = 'MWP.WingetRaw'
                        ComputerName = $env:COMPUTERNAME
                        Found        = $found
                        WingetPath   = $path
                        ExitCode     = $exitCode
                        TimedOut     = $timedOut
                        Lines        = @($lines)
                        Error        = $errorText
                        DurationMs   = [int]((Get-Date) - $started).TotalMilliseconds
                    })
            }
        }
        'WingetTask' {
            {
                param([string] $RequestJson)
                $request = ConvertFrom-Json -InputObject $RequestJson
                $started = Get-Date
                $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
                $isAdmin = (New-Object -TypeName Security.Principal.WindowsPrincipal -ArgumentList $identity).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
                if (-not [bool]$request.CheckAdministrator) {
                    $isAdmin = $true
                }
                $taskPath = [string]$request.TaskPath
                $prefix = [string]$request.TaskPrefix
                $timeout = [int]$request.TimeoutSeconds
                if ($timeout -le 0) {
                    $timeout = 300
                }
                $root = [string]$request.ResultRoot
                if (-not $root) {
                    $root = Join-Path -Path $env:ProgramData -ChildPath 'MyWindowsPower\winget'
                }
                $warnings = @()
                $runs = New-Object -TypeName System.Collections.Generic.List[object]

                $unpack = {
                    param([string] $Packed)
                    $stream = New-Object -TypeName IO.MemoryStream -ArgumentList (, [Convert]::FromBase64String($Packed))
                    $gzip = New-Object -TypeName IO.Compression.GZipStream -ArgumentList $stream, ([IO.Compression.CompressionMode]::Decompress)
                    $reader = New-Object -TypeName IO.StreamReader -ArgumentList $gzip, ([Text.Encoding]::UTF8)
                    try {
                        $reader.ReadToEnd()
                    }
                    finally {
                        $reader.Close()
                    }
                }
                # Wynik bloku Winget (tekst JSON) przepisany do wyniku przebiegu.
                $merge = {
                    param($Raw, [string] $Json)
                    $parsed = $null
                    try {
                        $parsed = ConvertFrom-Json -InputObject $Json
                    }
                    catch {
                        $parsed = $null
                    }
                    if ($null -eq $parsed -or [string]$parsed.Kind -ne 'MWP.WingetRaw') {
                        $Raw.Reason = 'TaskFailed'
                        $Raw.Error = 'zadanie nie zwróciło wyniku winget'
                        return
                    }
                    foreach ($field in 'Found', 'WingetPath', 'ExitCode', 'TimedOut', 'Error', 'DurationMs') {
                        $Raw[$field] = $parsed.$field
                    }
                    $Raw.Lines = @($parsed.Lines)
                    if ($parsed.TimedOut) {
                        $Raw.Reason = 'TimedOut'
                    }
                    elseif (-not $parsed.Found -and -not $parsed.Error) {
                        $Raw.Reason = 'WingetNotFound'
                    }
                }
                # Katalog wyników: bez dowiązań, właściciel Administratorzy, tylko SYSTEM i Administratorzy (+ użytkownik zadania).
                $ensureDirectory = {
                    param([string] $Path, [string] $UserSid)
                    $parent = Split-Path -Path $Path -Parent
                    foreach ($item in @($parent, $Path)) {
                        if ((Test-Path -LiteralPath $item) -and ((Get-Item -LiteralPath $item -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
                            throw ('Katalog {0} jest dowiązaniem — wynik winget nie zostanie tam zapisany.' -f $item)
                        }
                    }
                    if (-not (Test-Path -LiteralPath $Path)) {
                        $null = New-Item -ItemType Directory -Path $Path -Force
                    }
                    if ([bool]$request.ProtectResultRoot) {
                        $administrators = New-Object -TypeName Security.Principal.SecurityIdentifier -ArgumentList 'S-1-5-32-544'
                        $acl = New-Object -TypeName System.Security.AccessControl.DirectorySecurity
                        $acl.SetOwner($administrators)
                        $acl.SetAccessRuleProtection($true, $false)
                        $inherit = [System.Security.AccessControl.InheritanceFlags]'ContainerInherit, ObjectInherit'
                        $none = [System.Security.AccessControl.PropagationFlags]::None
                        foreach ($sid in @('S-1-5-18', 'S-1-5-32-544')) {
                            $acl.AddAccessRule((New-Object -TypeName System.Security.AccessControl.FileSystemAccessRule -ArgumentList (New-Object -TypeName Security.Principal.SecurityIdentifier -ArgumentList $sid), 'FullControl', $inherit, $none, 'Allow'))
                        }
                        if ($UserSid) {
                            $acl.AddAccessRule((New-Object -TypeName System.Security.AccessControl.FileSystemAccessRule -ArgumentList (New-Object -TypeName Security.Principal.SecurityIdentifier -ArgumentList $UserSid), 'Modify', $inherit, $none, 'Allow'))
                        }
                        Set-Acl -LiteralPath $Path -AclObject $acl
                    }
                }
                # Drzewo procesów zadania (PID z pliku) — przed zatrzymaniem zadania, potem zakończenie pozostałych.
                $getTree = {
                    param([string] $PidFile)
                    $ids = @()
                    if (-not $PidFile -or -not (Test-Path -LiteralPath $PidFile)) {
                        return @()
                    }
                    $rootId = 0
                    if (-not [int]::TryParse(([IO.File]::ReadAllText($PidFile)).Trim(), [ref]$rootId) -or $rootId -le 0) {
                        return @()
                    }
                    $rootProcess = @(Get-CimInstance -ClassName Win32_Process -Filter ('ProcessId = {0}' -f $rootId) -ErrorAction SilentlyContinue) | Select-Object -First 1
                    if ($null -eq $rootProcess -or [string]$rootProcess.Name -ne 'powershell.exe') {
                        return @()
                    }
                    $ids += $rootId
                    for ($i = 0; $i -lt $ids.Count; $i++) {
                        foreach ($child in @(Get-CimInstance -ClassName Win32_Process -Filter ('ParentProcessId = {0}' -f $ids[$i]) -ErrorAction SilentlyContinue)) {
                            if ($ids -notcontains [int]$child.ProcessId) {
                                $ids += [int]$child.ProcessId
                            }
                        }
                    }
                    $ids
                }

                $userRuns = @($request.Runs | Where-Object { [string]$_.Mode -eq 'User' }).Count -gt 0
                $systemRuns = @($request.Runs | Where-Object { [string]$_.Mode -eq 'System' }).Count -gt 0

                # Osierocone zadania (termin minął) i stare pliki wyników z poprzednich wywołań.
                if ($isAdmin -and ($userRuns -or $systemRuns)) {
                    try {
                        foreach ($old in @(Get-ScheduledTask -TaskPath $taskPath -ErrorAction SilentlyContinue | Where-Object { [string]$_.TaskName -like ($prefix + '*') })) {
                            $end = $null
                            try {
                                $end = [datetime]([string]@($old.Triggers)[0].EndBoundary)
                            }
                            catch {
                                $end = $null
                            }
                            if ($null -eq $end -or $end -lt (Get-Date)) {
                                Stop-ScheduledTask -TaskPath $taskPath -TaskName ([string]$old.TaskName) -ErrorAction SilentlyContinue
                                Unregister-ScheduledTask -TaskPath $taskPath -TaskName ([string]$old.TaskName) -Confirm:$false -ErrorAction SilentlyContinue
                                $warnings += ('Usunięto osierocone zadanie winget {0}.' -f $old.TaskName)
                            }
                        }
                        if (Test-Path -LiteralPath $root) {
                            $limit = (Get-Date).AddMinutes(-[int]$request.OrphanMinutes)
                            foreach ($file in @(Get-ChildItem -LiteralPath $root -Recurse -File -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -like ($prefix + '*') -and $_.LastWriteTime -lt $limit })) {
                                Remove-Item -LiteralPath $file.FullName -Force -ErrorAction SilentlyContinue
                            }
                        }
                    }
                    catch {
                        $warnings += ('Sprzątanie zadań winget: ' + $_.Exception.Message)
                    }
                }

                # Zalogowani użytkownicy (właściciele explorer.exe, jak w MWP.Startup).
                $sessions = @{}
                if ($userRuns -and $isAdmin) {
                    try {
                        foreach ($process in @(Get-CimInstance -ClassName Win32_Process -Filter "Name = 'explorer.exe'" -ErrorAction Stop)) {
                            try {
                                $owner = Invoke-CimMethod -InputObject $process -MethodName GetOwnerSid -ErrorAction Stop
                                if ($owner.Sid) {
                                    $sessions[[string]$owner.Sid] = $true
                                }
                            }
                            catch {
                                $warnings += ('Właściciel procesu explorer.exe: ' + $_.Exception.Message)
                            }
                        }
                    }
                    catch {
                        $warnings += ('Nie udało się ustalić zalogowanych użytkowników: ' + $_.Exception.Message)
                    }
                }

                # winget.exe dla SYSTEM: najnowszy pakiet App Installer zarejestrowany dla dowolnego użytkownika.
                $systemPath = [string]$request.WingetPath
                if (-not $systemPath -and $systemRuns -and $isAdmin) {
                    try {
                        foreach ($package in @(Get-AppxPackage -AllUsers -Name 'Microsoft.DesktopAppInstaller' -ErrorAction Stop | Sort-Object -Property { [version][string]$_.Version } -Descending)) {
                            if ($package.InstallLocation) {
                                $candidate = Join-Path -Path ([string]$package.InstallLocation) -ChildPath 'winget.exe'
                                if (Test-Path -LiteralPath $candidate) {
                                    $systemPath = $candidate
                                    break
                                }
                            }
                        }
                    }
                    catch {
                        $warnings += ('Pakiet App Installer: ' + $_.Exception.Message)
                    }
                }

                foreach ($spec in @($request.Runs)) {
                    $mode = [string]$spec.Mode
                    $raw = [ordered]@{
                        Kind = 'MWP.WingetRaw'; ComputerName = $env:COMPUTERNAME; Found = $false; WingetPath = ''; ExitCode = $null; TimedOut = $false
                        Lines = @(); Error = $null; DurationMs = 0; RunAs = $mode; UserSid = [string]$spec.UserSid; UserName = ''; TaskName = ''; Reason = ''; TaskMs = 0
                    }
                    $state = @{ Raw = $raw; Mode = $mode; Done = $false; TaskName = ''; ResultFile = ''; PidFile = ''; Begin = (Get-Date); Stopped = $false }
                    $runs.Add($state)
                    if ($mode -eq 'Direct') {
                        continue
                    }
                    if ($mode -eq 'User') {
                        try {
                            $raw.UserName = [string](New-Object -TypeName Security.Principal.SecurityIdentifier -ArgumentList $raw.UserSid).Translate([Security.Principal.NTAccount]).Value
                        }
                        catch {
                            $raw.UserName = $raw.UserSid
                        }
                    }
                    if (-not $isAdmin) {
                        $raw.Reason = 'NotAdministrator'
                        $state.Done = $true
                        continue
                    }
                    try {
                        $runPath = ''
                        $directory = $root
                        if ($mode -eq 'User') {
                            if (-not $sessions.ContainsKey($raw.UserSid)) {
                                $raw.Reason = 'UserNotLoggedOn'
                                $state.Done = $true
                                continue
                            }
                            & $ensureDirectory $root ''
                            $directory = Join-Path -Path $root -ChildPath ('user-' + $raw.UserSid)
                            & $ensureDirectory $directory $raw.UserSid
                            $runPath = [string]$request.WingetPath
                        }
                        else {
                            if (-not $systemPath) {
                                $raw.Reason = 'WingetNotFound'
                                $state.Done = $true
                                continue
                            }
                            & $ensureDirectory $root ''
                            $runPath = $systemPath
                        }
                        $name = $prefix + [guid]::NewGuid().ToString()
                        $state.TaskName = $name
                        $raw.TaskName = $name
                        $state.ResultFile = Join-Path -Path $directory -ChildPath ($name + '.json')
                        $state.PidFile = Join-Path -Path $directory -ChildPath ($name + '.pid')
                        $runRequest = ConvertTo-Json -Compress -InputObject ([pscustomobject]@{ Arguments = @($request.Arguments); WingetPath = $runPath; TimeoutSeconds = $timeout })
                        $taskRequest = ConvertTo-Json -Compress -InputObject ([pscustomobject]@{ RunScript = [string]$request.RunScript; RunRequest = $runRequest; ResultFile = $state.ResultFile; PidFile = $state.PidFile })
                        $text = ([string]$request.TaskScript).Replace('__MWP_REQUEST__', [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($taskRequest)))
                        $argument = '-NoProfile -NonInteractive -EncodedCommand ' + [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($text))
                        if ($argument.Length -gt [int]$request.MaxCommandLength) {
                            throw ('polecenie zadania ma {0} znaków (limit {1})' -f $argument.Length, $request.MaxCommandLength)
                        }
                        $executable = Join-Path -Path $env:SystemRoot -ChildPath 'System32\WindowsPowerShell\v1.0\powershell.exe'
                        $action = New-ScheduledTaskAction -Execute $executable -Argument $argument
                        # Wyzwalacz w przeszłości (bez StartWhenAvailable nie uruchomi się sam) z terminem wygaśnięcia:
                        # zadanie osierocone po utracie połączenia usuwa harmonogram (DeleteExpiredTaskAfter).
                        $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(-1)
                        $trigger.EndBoundary = (Get-Date).AddMinutes([int]$request.OrphanMinutes).ToString('s')
                        if ($mode -eq 'User') {
                            $principal = New-ScheduledTaskPrincipal -UserId $raw.UserName -LogonType Interactive -RunLevel Limited
                        }
                        else {
                            $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
                        }
                        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Seconds ($timeout + 120)) -DeleteExpiredTaskAfter (New-TimeSpan -Minutes 1) -MultipleInstances IgnoreNew
                        $task = New-ScheduledTask -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description 'MyWindowsPower: jednorazowe uruchomienie winget (usuwane automatycznie).'
                        $state.Begin = Get-Date
                        $null = Register-ScheduledTask -TaskPath $taskPath -TaskName $name -InputObject $task -ErrorAction Stop
                        Start-ScheduledTask -TaskPath $taskPath -TaskName $name -ErrorAction Stop
                    }
                    catch {
                        $raw.Reason = 'TaskFailed'
                        $raw.Error = $_.Exception.Message
                        $state.Done = $true
                    }
                }

                # Uruchomienie bezpośrednie (konto sesji) — ten sam blok Winget.
                foreach ($state in @($runs | Where-Object { $_.Mode -eq 'Direct' })) {
                    $runRequest = ConvertTo-Json -Compress -InputObject ([pscustomobject]@{ Arguments = @($request.Arguments); WingetPath = [string]$request.WingetPath; TimeoutSeconds = $timeout })
                    try {
                        $run = [scriptblock]::Create((& $unpack ([string]$request.RunScript)))
                        & $merge $state.Raw ([string](@(& $run $runRequest) | Select-Object -Last 1))
                    }
                    catch {
                        $state.Raw.Reason = 'TaskFailed'
                        $state.Raw.Error = $_.Exception.Message
                    }
                    $state.Done = $true
                }

                try {
                    $deadline = (Get-Date).AddSeconds($timeout + [int]$request.StartGraceSeconds)
                    while (@($runs | Where-Object { -not $_.Done }).Count -gt 0) {
                        foreach ($state in @($runs | Where-Object { -not $_.Done })) {
                            if (Test-Path -LiteralPath $state.ResultFile) {
                                & $merge $state.Raw ([IO.File]::ReadAllText($state.ResultFile, [Text.Encoding]::UTF8))
                                $state.Done = $true
                                continue
                            }
                            # Zadanie zakończone bez pliku wyniku — bez czekania do limitu.
                            $task = Get-ScheduledTask -TaskPath $taskPath -TaskName $state.TaskName -ErrorAction SilentlyContinue
                            $info = if ($null -ne $task) { Get-ScheduledTaskInfo -TaskPath $taskPath -TaskName $state.TaskName -ErrorAction SilentlyContinue } else { $null }
                            $ran = $null -ne $info -and $null -ne $info.LastRunTime -and [datetime]$info.LastRunTime -ge $state.Begin.AddSeconds(-2)
                            if ($null -eq $task -or ([string]$task.State -eq 'Ready' -and $ran)) {
                                if (Test-Path -LiteralPath $state.ResultFile) {
                                    & $merge $state.Raw ([IO.File]::ReadAllText($state.ResultFile, [Text.Encoding]::UTF8))
                                }
                                else {
                                    $state.Raw.Reason = 'TaskFailed'
                                    $state.Raw.Error = if ($null -eq $task) { 'zadanie zniknęło z harmonogramu' } else { 'zadanie zakończyło się bez wyniku (kod 0x{0:X8})' -f ([long]$info.LastTaskResult -band 0xFFFFFFFFL) }
                                }
                                $state.Done = $true
                            }
                        }
                        if (@($runs | Where-Object { -not $_.Done }).Count -eq 0) {
                            break
                        }
                        if ((Get-Date) -gt $deadline) {
                            foreach ($state in @($runs | Where-Object { -not $_.Done })) {
                                $state.Raw.Reason = 'TimedOut'
                                $state.Raw.TimedOut = $true
                                $state.Stopped = $true
                                $state.Done = $true
                            }
                            break
                        }
                        Start-Sleep -Milliseconds ([int]$request.PollMilliseconds)
                    }
                }
                finally {
                    # Zawsze: zatrzymanie (limit, przerwanie), usunięcie zadania i plików.
                    foreach ($state in $runs) {
                        if (-not $state.TaskName) {
                            continue
                        }
                        if (-not $state.Done) {
                            $state.Raw.Reason = 'Cancelled'
                            $state.Stopped = $true
                        }
                        if ($state.Stopped) {
                            $tree = @(& $getTree $state.PidFile)
                            Stop-ScheduledTask -TaskPath $taskPath -TaskName $state.TaskName -ErrorAction SilentlyContinue
                            [array]::Reverse($tree)
                            foreach ($id in $tree) {
                                Stop-Process -Id $id -Force -ErrorAction SilentlyContinue
                            }
                        }
                        Unregister-ScheduledTask -TaskPath $taskPath -TaskName $state.TaskName -Confirm:$false -ErrorAction SilentlyContinue
                        foreach ($file in @($state.ResultFile, ($state.ResultFile + '.tmp'), $state.PidFile)) {
                            if (Test-Path -LiteralPath $file) {
                                Remove-Item -LiteralPath $file -Force -ErrorAction SilentlyContinue
                            }
                        }
                        $state.Raw.TaskMs = [int]((Get-Date) - $state.Begin).TotalMilliseconds
                    }
                }
                ConvertTo-Json -Depth 4 -Compress -InputObject ([pscustomobject]@{
                        Kind            = 'MWP.WingetRawSet'
                        ComputerName    = $env:COMPUTERNAME
                        IsAdministrator = $isAdmin
                        Runs            = @($runs | ForEach-Object { [pscustomobject]$_.Raw })
                        Warnings        = @($warnings)
                        DurationMs      = [int]((Get-Date) - $started).TotalMilliseconds
                    })
            }
        }
        'RemoveAppx' {
            {
                param([string] $PackageFullName)
                $errorText = $null
                $existed = $false
                $remaining = $false
                try {
                    $existed = @(Get-AppxPackage -ErrorAction Stop | Where-Object { $_.PackageFullName -eq $PackageFullName }).Count -gt 0
                    if ($existed) {
                        Remove-AppxPackage -Package $PackageFullName -ErrorAction Stop
                        $remaining = @(Get-AppxPackage -ErrorAction Stop | Where-Object { $_.PackageFullName -eq $PackageFullName }).Count -gt 0
                    }
                }
                catch {
                    $errorText = $_.Exception.Message
                }
                ConvertTo-Json -Compress -InputObject ([pscustomobject]@{
                        Kind      = 'MWP.AppxRemoveRaw'
                        Existed   = $existed
                        Remaining = $remaining
                        Error     = $errorText
                    })
            }
        }
    }
}
