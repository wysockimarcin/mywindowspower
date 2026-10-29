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

    .PARAMETER Name
        Nazwa bloku.
    #>
    [CmdletBinding()]
    [OutputType([scriptblock])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Inventory', 'Winget', 'RemoveAppx')]
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
