function Get-MwpCleanupScript {
    <#
    .SYNOPSIS
        Zwraca blok skryptu wykonywany na komputerze docelowym (Invoke-MwpOnTarget / Start-MwpOperation).

    .DESCRIPTION
        Bloki są samowystarczalne i zgodne z Windows PowerShell 5.1 (D-036): dane przychodzą przez
        parametry (tekst JSON), wynik wraca jako tekst JSON. Bloki nie sklejają poleceń z tekstu (D-015).
        - Environment: dane do rozwinięcia tokenów kategorii (Windows, ProgramData, profile z ProfileList,
          dyski lokalne, SID bieżącego konta, administrator) i lokalizacje chronione użytkowników
          (pulpit, dokumenty, pobrane, obrazy, muzyka, wideo, ulubione, OneDrive) — tylko odczyt.
        - Process: skan (Mode Scan, tylko odczyt) albo usuwanie (Mode Delete) plików w podanych
          katalogach głównych (D-047): tylko wewnątrz katalogu głównego, bez wchodzenia w dowiązania
          (junction/symlink — atrybut ReparsePoint, sprawdzany też dla katalogu głównego i jego
          przodków), bez lokalizacji chronionych, pliki w użyciu pomijane (błąd udostępniania),
          usuwanie pojedynczych plików (FileInfo.Delete) i pustych katalogów bez rekurencji
          (Directory.Delete(path, $false)). Drugi parametr (lokalnie tabela postępu) pozwala przerwać
          pracę po bieżącym pliku (CancelRequested); zdalnie jest pusty.
        - ComponentStore: DISM /Online /Cleanup-Image /AnalyzeComponentStore /English (tylko analiza;
          wymaga administratora), linie wyniku i kod wyjścia.

    .PARAMETER Name
        Nazwa bloku.
    #>
    [CmdletBinding()]
    [OutputType([scriptblock])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Environment', 'Process', 'ComponentStore')]
        [string] $Name
    )

    switch ($Name) {
        'Environment' {
            {
                $ErrorActionPreference = 'Continue'
                $errorText = $null
                $profiles = @()
                $protected = @()
                $drives = @()
                $profilesDirectory = $null
                $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
                $currentSid = [string]$identity.User.Value
                $principal = New-Object -TypeName Security.Principal.WindowsPrincipal -ArgumentList $identity
                $isAdministrator = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
                $currentProfile = [Environment]::GetFolderPath('UserProfile')
                try {
                    $key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey('SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList')
                    if ($null -ne $key) {
                        try {
                            $profilesDirectory = [string]$key.GetValue('ProfilesDirectory')
                            foreach ($sid in @($key.GetSubKeyNames())) {
                                if ($sid -notmatch '^S-1-5-21-[0-9-]+$') {
                                    continue
                                }
                                $sub = $key.OpenSubKey($sid)
                                if ($null -eq $sub) {
                                    continue
                                }
                                try {
                                    $path = [string]$sub.GetValue('ProfileImagePath')
                                }
                                finally {
                                    $sub.Close()
                                }
                                if (-not $path -or -not [IO.Directory]::Exists($path)) {
                                    continue
                                }
                                $userName = $null
                                try {
                                    $userName = (New-Object -TypeName Security.Principal.SecurityIdentifier -ArgumentList $sid).Translate([Security.Principal.NTAccount]).Value
                                }
                                catch {
                                    $userName = Split-Path -Leaf $path
                                }
                                $profiles += [pscustomobject]@{ Sid = $sid; Path = $path.TrimEnd('\'); UserName = $userName; IsCurrent = ($sid -eq $currentSid) }
                            }
                        }
                        finally {
                            $key.Close()
                        }
                    }
                }
                catch {
                    $errorText = $_.Exception.Message
                }
                if (@($profiles | Where-Object { $_.IsCurrent }).Count -eq 0 -and $currentProfile) {
                    $profiles += [pscustomobject]@{ Sid = $currentSid; Path = $currentProfile.TrimEnd('\'); UserName = $identity.Name; IsCurrent = $true }
                }
                foreach ($folder in 'Desktop', 'MyDocuments', 'MyPictures', 'MyMusic', 'MyVideos', 'Favorites') {
                    $path = [Environment]::GetFolderPath($folder)
                    if ($path) {
                        $protected += $path.TrimEnd('\')
                    }
                }
                if ($env:OneDrive) {
                    $protected += ([string]$env:OneDrive).TrimEnd('\')
                }
                foreach ($userProfile in $profiles) {
                    foreach ($folder in 'Desktop', 'Documents', 'Downloads', 'Pictures', 'Music', 'Videos', 'Favorites', 'OneDrive') {
                        $protected += (Join-Path -Path $userProfile.Path -ChildPath $folder)
                    }
                    try {
                        foreach ($directory in @([IO.Directory]::GetDirectories($userProfile.Path, 'OneDrive*'))) {
                            $protected += $directory.TrimEnd('\')
                        }
                    }
                    catch {
                        $null = $_
                    }
                }
                try {
                    foreach ($drive in @([IO.DriveInfo]::GetDrives())) {
                        if ($drive.DriveType -eq [IO.DriveType]::Fixed -and $drive.IsReady) {
                            $drives += [string]$drive.RootDirectory.FullName
                        }
                    }
                }
                catch {
                    $errorText = $_.Exception.Message
                }
                ConvertTo-Json -Compress -Depth 4 -InputObject ([pscustomobject]@{
                        Kind              = 'MWP.CleanupEnvironment'
                        ComputerName      = [string]$env:COMPUTERNAME
                        SystemRoot        = ([Environment]::GetFolderPath('Windows')).TrimEnd('\')
                        ProgramData       = ([Environment]::GetFolderPath('CommonApplicationData')).TrimEnd('\')
                        ProfilesDirectory = $(if ($profilesDirectory) { [Environment]::ExpandEnvironmentVariables($profilesDirectory).TrimEnd('\') } else { $null })
                        CurrentSid        = $currentSid
                        CurrentUserName   = [string]$identity.Name
                        CurrentProfile    = $currentProfile.TrimEnd('\')
                        IsAdministrator   = $isAdministrator
                        FixedDrives       = @($drives)
                        Profiles          = @($profiles)
                        Protected         = @($protected | Select-Object -Unique)
                        Error             = $errorText
                    })
            }
        }
        'Process' {
            {
                param([string] $RequestJson, $Cancel)
                $ErrorActionPreference = 'Continue'
                $request = ConvertFrom-Json -InputObject $RequestJson
                $delete = [string]$request.Mode -eq 'Delete'
                $maxSamples = [int]$request.MaxSamples
                $nowUtc = [DateTime]::UtcNow
                $ignoreCase = [StringComparison]::OrdinalIgnoreCase
                $reparse = [IO.FileAttributes]::ReparsePoint
                $protected = @(@($request.Protected) | Where-Object { $_ } | ForEach-Object { ([string]$_).TrimEnd('\') })
                $protectedPrefix = @($protected | ForEach-Object { $_ + '\' })
                $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
                $principal = New-Object -TypeName Security.Principal.WindowsPrincipal -ArgumentList $identity
                $cancelled = $false

                $isProtected = {
                    param([string] $Path)
                    $candidate = $Path.TrimEnd('\')
                    for ($i = 0; $i -lt $protected.Count; $i++) {
                        if ($candidate.Equals($protected[$i], $ignoreCase) -or $candidate.StartsWith($protectedPrefix[$i], $ignoreCase)) {
                            return $true
                        }
                    }
                    $false
                }

                $results = @()
                foreach ($root in @($request.Roots)) {
                    $state = @{
                        Key          = [string]$root.Key
                        Path         = [string]$root.Path
                        Exists       = $false
                        Files        = [long]0
                        Bytes        = [long]0
                        Deleted      = [long]0
                        DeletedBytes = [long]0
                        Directories  = [long]0
                        Skipped      = @{}
                        Samples      = New-Object -TypeName System.Collections.ArrayList
                        Error        = $null
                        Cancelled    = $false
                        TooNew       = [long]0
                        TooNewBytes  = [long]0
                    }
                    $skip = {
                        param([string] $Reason, [string] $Path, [long] $Bytes)
                        if (-not $state.Skipped.ContainsKey($Reason)) {
                            $state.Skipped[$Reason] = @([long]0, [long]0)
                        }
                        $state.Skipped[$Reason] = @(($state.Skipped[$Reason][0] + 1), ($state.Skipped[$Reason][1] + $Bytes))
                        if ($Reason -ne 'TooNew' -and $state.Samples.Count -lt $maxSamples) {
                            $null = $state.Samples.Add([pscustomobject]@{ Path = $Path; Reason = $Reason })
                        }
                    }

                    if ($cancelled) {
                        $state.Cancelled = $true
                    }
                    else {
                        try {
                            $rootPath = ([string]$root.Path).TrimEnd('\')
                            if (-not [IO.Path]::IsPathRooted($rootPath) -or $rootPath.Length -le 3 -or
                                -not ([IO.Path]::GetFullPath($rootPath).TrimEnd('\')).Equals($rootPath, $ignoreCase)) {
                                throw 'Niepoprawna ścieżka katalogu głównego (oczekiwana pełna, kanoniczna ścieżka).'
                            }
                            if ([IO.Directory]::Exists($rootPath)) {
                                $state.Exists = $true
                                # Katalog główny i jego przodkowie nie mogą być dowiązaniami (junction/symlink).
                                $cursor = New-Object -TypeName IO.DirectoryInfo -ArgumentList $rootPath
                                while ($null -ne $cursor) {
                                    if (($cursor.Attributes -band $reparse) -eq $reparse) {
                                        throw ('Ścieżka zawiera dowiązanie (junction/symlink): {0}' -f $cursor.FullName)
                                    }
                                    $cursor = $cursor.Parent
                                }
                                if (& $isProtected $rootPath) {
                                    throw 'Katalog główny jest lokalizacją chronioną użytkownika.'
                                }
                                $patterns = @(@($root.Patterns) | ForEach-Object { [string]$_ })
                                $exclude = @(@($root.Exclude) | Where-Object { $_ } | ForEach-Object { [string]$_ })
                                $cutoff = $nowUtc.AddDays( - [double]$root.MinAgeDays)
                                $checkAge = [double]$root.MinAgeDays -gt 0
                                $recurse = [bool]$root.Recurse
                                $directories = New-Object -TypeName System.Collections.Generic.List[string]
                                $stack = New-Object -TypeName System.Collections.Generic.Stack[string]
                                $stack.Push($rootPath)
                                $counter = 0
                                while ($stack.Count -gt 0 -and -not $cancelled) {
                                    $directory = $stack.Pop()
                                    if ($directory -ne $rootPath -and (& $isProtected $directory)) {
                                        & $skip 'Protected' $directory 0
                                        continue
                                    }
                                    try {
                                        $entries = @((New-Object -TypeName IO.DirectoryInfo -ArgumentList $directory).GetFileSystemInfos())
                                    }
                                    catch {
                                        $exception = $_.Exception
                                        while ($exception -is [Management.Automation.MethodInvocationException] -and $null -ne $exception.InnerException) {
                                            $exception = $exception.InnerException
                                        }
                                        & $skip $(if ($exception -is [UnauthorizedAccessException]) { 'AccessDenied' } else { 'Error' }) $directory 0
                                        continue
                                    }
                                    foreach ($entry in $entries) {
                                        $counter++
                                        if (($counter % 200) -eq 0 -and $null -ne $Cancel -and $Cancel -is [Collections.IDictionary] -and [bool]$Cancel['CancelRequested']) {
                                            $cancelled = $true
                                            break
                                        }
                                        $full = $entry.FullName
                                        $size = if ($entry -is [IO.FileInfo]) { [long]$entry.Length } else { [long]0 }
                                        if (($entry.Attributes -band $reparse) -eq $reparse) {
                                            & $skip 'ReparsePoint' $full 0
                                            continue
                                        }
                                        if (-not $full.StartsWith($rootPath + '\', $ignoreCase)) {
                                            & $skip 'OutsideRoot' $full $size
                                            continue
                                        }
                                        if ($entry -is [IO.DirectoryInfo]) {
                                            if ($recurse) {
                                                $stack.Push($full)
                                                $directories.Add($full)
                                            }
                                            continue
                                        }
                                        $name = $entry.Name
                                        $excluded = $false
                                        foreach ($item in $exclude) {
                                            if ($name -like $item) { $excluded = $true }
                                        }
                                        $matched = $false
                                        foreach ($item in $patterns) {
                                            if ($name -like $item) { $matched = $true }
                                        }
                                        if ($excluded -or -not $matched) {
                                            continue
                                        }
                                        # Lokalizacje chronione są sprawdzane przy wejściu do katalogu (plik w chronionym
                                        # katalogu nie jest osiągany), a katalog główny nie może być chroniony.
                                        if ($checkAge) {
                                            $age = if ($entry.CreationTimeUtc -gt $entry.LastWriteTimeUtc) { $entry.CreationTimeUtc } else { $entry.LastWriteTimeUtc }
                                            if ($age -gt $cutoff) {
                                                $state.TooNew++
                                                $state.TooNewBytes += $size
                                                continue
                                            }
                                        }
                                        $state.Files++
                                        $state.Bytes += $size
                                        if (-not $delete) {
                                            continue
                                        }
                                        $attributes = $entry.Attributes
                                        try {
                                            $entry.Refresh()
                                            if (($entry.Attributes -band $reparse) -eq $reparse) {
                                                & $skip 'ReparsePoint' $full 0
                                                continue
                                            }
                                            if (($attributes -band [IO.FileAttributes]::ReadOnly) -eq [IO.FileAttributes]::ReadOnly) {
                                                $entry.Attributes = $attributes -band (-bnot [IO.FileAttributes]::ReadOnly)
                                            }
                                            $entry.Delete()
                                            $state.Deleted++
                                            $state.DeletedBytes += $size
                                        }
                                        catch {
                                            $exception = $_.Exception
                                            while ($exception -is [Management.Automation.MethodInvocationException] -and $null -ne $exception.InnerException) {
                                                $exception = $exception.InnerException
                                            }
                                            $reason = if ($exception -is [UnauthorizedAccessException]) { 'AccessDenied' } elseif ($exception -is [IO.IOException]) { 'InUse' } else { 'Error' }
                                            & $skip $reason $full $size
                                            try {
                                                $entry.Refresh()
                                                if ($entry.Exists -and $entry.Attributes -ne $attributes) {
                                                    $entry.Attributes = $attributes
                                                }
                                            }
                                            catch {
                                                $null = $_
                                            }
                                        }
                                    }
                                }
                                if ($delete -and $root.RemoveEmptyDirectories -and -not $cancelled) {
                                    foreach ($directory in @($directories | Sort-Object -Property Length -Descending)) {
                                        try {
                                            $info = New-Object -TypeName IO.DirectoryInfo -ArgumentList $directory
                                            if (-not $info.Exists -or ($info.Attributes -band $reparse) -eq $reparse -or (& $isProtected $directory) -or
                                                -not $directory.StartsWith($rootPath + '\', $ignoreCase)) {
                                                continue
                                            }
                                            if (@($info.GetFileSystemInfos()).Count -eq 0) {
                                                # Bez rekurencji: usuwa tylko pusty katalog.
                                                [IO.Directory]::Delete($directory, $false)
                                                $state.Directories++
                                            }
                                        }
                                        catch {
                                            $null = $_
                                        }
                                    }
                                }
                                if ($cancelled) {
                                    $state.Cancelled = $true
                                }
                            }
                        }
                        catch {
                            $state.Error = [string]$_.Exception.Message
                        }
                    }
                    if ($state.TooNew -gt 0) {
                        $state.Skipped['TooNew'] = @($state.TooNew, $state.TooNewBytes)
                    }
                    $skipped = @()
                    foreach ($reason in @($state.Skipped.Keys)) {
                        $skipped += [pscustomobject]@{ Reason = $reason; Count = $state.Skipped[$reason][0]; Bytes = $state.Skipped[$reason][1] }
                    }
                    $results += [pscustomobject]@{
                        Key          = $state.Key
                        Path         = $state.Path
                        Exists       = $state.Exists
                        Files        = $state.Files
                        Bytes        = $state.Bytes
                        Deleted      = $state.Deleted
                        DeletedBytes = $state.DeletedBytes
                        Directories  = $state.Directories
                        Skipped      = $skipped
                        Samples      = @($state.Samples)
                        Error        = $state.Error
                        Cancelled    = $state.Cancelled
                    }
                }
                ConvertTo-Json -Compress -Depth 5 -InputObject ([pscustomobject]@{
                        Kind            = 'MWP.CleanupProcess'
                        Mode            = [string]$request.Mode
                        IsAdministrator = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
                        Cancelled       = $cancelled
                        Roots           = @($results)
                    })
            }
        }
        'ComponentStore' {
            {
                $ErrorActionPreference = 'Continue'
                $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
                $principal = New-Object -TypeName Security.Principal.WindowsPrincipal -ArgumentList $identity
                $isAdministrator = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
                $lines = @()
                $code = $null
                $errorText = $null
                if ($isAdministrator) {
                    try {
                        $arguments = @('/Online', '/Cleanup-Image', '/AnalyzeComponentStore', '/English')
                        $lines = @(& dism.exe @arguments 2>&1 | ForEach-Object { [string]$_ })
                        $code = [int]$LASTEXITCODE
                    }
                    catch {
                        $errorText = $_.Exception.Message
                    }
                }
                ConvertTo-Json -Compress -InputObject ([pscustomobject]@{
                        Kind            = 'MWP.ComponentStoreRaw'
                        IsAdministrator = $isAdministrator
                        ExitCode        = $code
                        Lines           = @($lines)
                        Error           = $errorText
                    })
            }
        }
    }
}
