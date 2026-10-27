function Get-MwpStartupScript {
    <#
    .SYNOPSIS
        Zwraca blok skryptu wykonywany na komputerze docelowym (Invoke-MwpOnTarget / Start-MwpOperation).

    .DESCRIPTION
        Bloki są samowystarczalne i zgodne z Windows PowerShell 5.1 (D-036): dane przychodzą przez
        parametry (tekst JSON), wynik wraca jako tekst JSON. Bloki nie sklejają poleceń z tekstu (D-015).
        - ItemList: pozycje autostartu — HKLM Run/RunOnce (także WOW6432Node), wspólny folder Startup,
          a dla użytkowników (UserMode Current: HKCU bieżącego konta; LoggedOn: profile właścicieli
          procesów explorer.exe, HKEY_USERS\<SID>, D-046) Run, RunOnce i folder Startup; stan
          z kluczy StartupApproved (surowe bajty jako tekst szesnastkowy), ścieżka pliku, podpis.
        - ItemState: włączenie albo wyłączenie pozycji wartością StartupApproved (jak Menedżer
          zadań; wpis Run i plik w folderze Startup nie są zmieniane ani kasowane), z ponownym odczytem.
        - TaskList: zadania harmonogramu (Get-ScheduledTask, Get-ScheduledTaskInfo), akcje,
          wyzwalacze, konto, podpis pliku pierwszej akcji (poza folderami pomijanymi).
        - TaskControl: Enable, Disable, Start, Export (XML), Remove, Register (z XML) dla jednego
          zadania wybranego dokładnie po ścieżce i nazwie (bez symboli wieloznacznych w nazwie).

    .PARAMETER Name
        Nazwa bloku.
    #>
    [CmdletBinding()]
    [OutputType([scriptblock])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('ItemList', 'ItemState', 'TaskList', 'TaskControl')]
        [string] $Name
    )

    switch ($Name) {
        'ItemList' {
            {
                param([string] $RequestJson)
                $request = ConvertFrom-Json -InputObject $RequestJson
                $warnings = @()
                $items = @()
                $users = @()
                $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
                $currentSid = [string]$identity.User.Value
                $principal = New-Object -TypeName Security.Principal.WindowsPrincipal -ArgumentList $identity
                $machineRoot = 'Registry::HKEY_LOCAL_MACHINE'
                $approvedPath = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved'
                $runPath = 'SOFTWARE\Microsoft\Windows\CurrentVersion'
                $wowPath = 'SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion'
                $approvalCache = @{}
                $shell = $null

                $readApproval = {
                    param([string] $Key, [string] $ValueName)
                    if (-not $approvalCache.ContainsKey($Key)) {
                        $values = @{}
                        try {
                            if (Test-Path -LiteralPath $Key) {
                                $property = Get-ItemProperty -LiteralPath $Key -ErrorAction Stop
                                foreach ($entry in $property.PSObject.Properties) {
                                    if ($entry.Value -is [byte[]]) {
                                        $values[$entry.Name] = (@($entry.Value | ForEach-Object { '{0:X2}' -f $_ }) -join '')
                                    }
                                }
                            }
                        }
                        catch {
                            $script:approvalWarning = $_.Exception.Message
                        }
                        $approvalCache[$Key] = $values
                    }
                    $approvalCache[$Key][$ValueName]
                }
                $pathOf = {
                    param([string] $Command)
                    $text = [Environment]::ExpandEnvironmentVariables([string]$Command).Trim()
                    if (-not $text) {
                        return $null
                    }
                    $path = $null
                    if ($text.StartsWith('"')) {
                        $end = $text.IndexOf('"', 1)
                        $path = if ($end -gt 1) { $text.Substring(1, $end - 1) } else { $text.Trim('"') }
                    }
                    else {
                        $match = [regex]::Match($text, '^(.+?\.(exe|com|bat|cmd|lnk|ps1|vbs|js|msc|cpl|dll|scr))(\s|,|$)', 'IgnoreCase')
                        $path = if ($match.Success) { $match.Groups[1].Value } else { ($text -split '\s+')[0] }
                    }
                    if ($path -and -not [IO.Path]::IsPathRooted($path)) {
                        $candidate = Join-Path -Path $env:SystemRoot -ChildPath ('System32\' + $path)
                        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
                            $path = $candidate
                        }
                    }
                    $path
                }
                $fileInfo = {
                    param([string] $Path)
                    $info = [ordered]@{ FilePath = $Path; FileExists = $false; SignatureStatus = 'Unknown'; SignerSubject = $null }
                    if (-not $Path) {
                        return $info
                    }
                    try {
                        $info.FileExists = [bool](Test-Path -LiteralPath $Path -PathType Leaf)
                    }
                    catch {
                        $info.FileExists = $false
                    }
                    if (-not $info.FileExists) {
                        $info.SignatureStatus = 'Missing'
                    }
                    elseif (-not $request.IncludeSignature) {
                        $info.SignatureStatus = 'NotChecked'
                    }
                    else {
                        try {
                            $signature = Get-AuthenticodeSignature -LiteralPath $Path -ErrorAction Stop
                            $info.SignatureStatus = [string]$signature.Status
                            if ($null -ne $signature.SignerCertificate) {
                                $info.SignerSubject = [string]$signature.SignerCertificate.Subject
                            }
                        }
                        catch {
                            $info.SignatureStatus = 'Unknown'
                        }
                    }
                    $info
                }
                $addRegistry = {
                    param([string] $Location, [string] $Key, [string] $ApprovalKey, [string] $UserSid, [string] $UserName)
                    try {
                        if (-not (Test-Path -LiteralPath $Key)) {
                            return
                        }
                        $property = Get-ItemProperty -LiteralPath $Key -ErrorAction Stop
                    }
                    catch {
                        $script:readWarnings += ('{0}: {1}' -f $Key, $_.Exception.Message)
                        return
                    }
                    foreach ($entry in $property.PSObject.Properties) {
                        if ($entry.Name -in @('PSPath', 'PSParentPath', 'PSChildName', 'PSDrive', 'PSProvider', '(default)')) {
                            continue
                        }
                        $command = [string]$entry.Value
                        $file = & $fileInfo (& $pathOf $command)
                        $script:found += [pscustomobject]@{
                            Location        = $Location
                            UserSid         = $UserSid
                            UserName        = $UserName
                            Name            = [string]$entry.Name
                            Command         = $command
                            FilePath        = $file.FilePath
                            FileExists      = $file.FileExists
                            SignatureStatus = $file.SignatureStatus
                            SignerSubject   = $file.SignerSubject
                            Approval        = $(if ($ApprovalKey) { & $readApproval $ApprovalKey ([string]$entry.Name) } else { $null })
                            Source          = ($Key -replace '^Registry::', '')
                        }
                    }
                }
                $addFolder = {
                    param([string] $Location, [string] $Folder, [string] $ApprovalKey, [string] $UserSid, [string] $UserName)
                    if (-not $Folder) {
                        return
                    }
                    try {
                        if (-not (Test-Path -LiteralPath $Folder)) {
                            return
                        }
                        $files = @(Get-ChildItem -LiteralPath $Folder -File -Force -ErrorAction Stop | Where-Object { $_.Name -ne 'desktop.ini' })
                    }
                    catch {
                        $script:readWarnings += ('{0}: {1}' -f $Folder, $_.Exception.Message)
                        return
                    }
                    foreach ($file in $files) {
                        $command = [string]$file.FullName
                        $target = [string]$file.FullName
                        if ($file.Extension -eq '.lnk') {
                            try {
                                if ($null -eq $shell) {
                                    $shell = New-Object -ComObject WScript.Shell
                                }
                                $link = $shell.CreateShortcut([string]$file.FullName)
                                if ($link.TargetPath) {
                                    $target = [string]$link.TargetPath
                                    $command = ('"{0}" {1}' -f $link.TargetPath, $link.Arguments).Trim()
                                }
                            }
                            catch {
                                $script:readWarnings += ('Skrót {0}: {1}' -f $file.Name, $_.Exception.Message)
                            }
                        }
                        $info = & $fileInfo ([Environment]::ExpandEnvironmentVariables($target))
                        $script:found += [pscustomobject]@{
                            Location        = $Location
                            UserSid         = $UserSid
                            UserName        = $UserName
                            Name            = [string]$file.Name
                            Command         = $command
                            FilePath        = $info.FilePath
                            FileExists      = $info.FileExists
                            SignatureStatus = $info.SignatureStatus
                            SignerSubject   = $info.SignerSubject
                            Approval        = $(if ($ApprovalKey) { & $readApproval $ApprovalKey ([string]$file.Name) } else { $null })
                            Source          = $Folder
                        }
                    }
                }

                $script:found = @()
                $script:readWarnings = @()
                $script:approvalWarning = $null
                $errorText = $null
                try {
                    # Pozycje całego komputera.
                    & $addRegistry 'MachineRun' "$machineRoot\$runPath\Run" "$machineRoot\$approvedPath\Run" '' ''
                    & $addRegistry 'MachineRun32' "$machineRoot\$wowPath\Run" "$machineRoot\$approvedPath\Run32" '' ''
                    & $addRegistry 'MachineRunOnce' "$machineRoot\$runPath\RunOnce" '' '' ''
                    & $addRegistry 'MachineRunOnce32' "$machineRoot\$wowPath\RunOnce" '' '' ''
                    & $addFolder 'MachineStartupFolder' ([Environment]::GetFolderPath('CommonStartup')) "$machineRoot\$approvedPath\StartupFolder" '' ''

                    # Pozycje profili użytkowników (D-046).
                    $profiles = @()
                    if ([string]$request.UserMode -eq 'Current') {
                        $profiles += [pscustomobject]@{ Sid = $currentSid; Name = [string]$identity.Name; Root = 'Registry::HKEY_CURRENT_USER'; Folder = [Environment]::GetFolderPath('Startup') }
                    }
                    else {
                        $sids = @()
                        try {
                            foreach ($process in @(Get-CimInstance -ClassName Win32_Process -Filter "Name = 'explorer.exe'" -ErrorAction Stop)) {
                                try {
                                    $owner = Invoke-CimMethod -InputObject $process -MethodName GetOwnerSid -ErrorAction Stop
                                    if ($owner.Sid -and $sids -notcontains [string]$owner.Sid) {
                                        $sids += [string]$owner.Sid
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
                        if ($sids.Count -eq 0) {
                            $warnings += 'Na komputerze nie jest zalogowany żaden użytkownik (brak procesu explorer.exe) — pozycje autostartu profili użytkowników nie są pokazywane.'
                        }
                        foreach ($sid in $sids) {
                            $root = 'Registry::HKEY_USERS\' + $sid
                            $userName = $sid
                            try {
                                $userName = [string](New-Object -TypeName Security.Principal.SecurityIdentifier -ArgumentList $sid).Translate([Security.Principal.NTAccount]).Value
                            }
                            catch {
                                $userName = $sid
                            }
                            if (-not (Test-Path -LiteralPath $root)) {
                                $warnings += ('Profil użytkownika {0} nie jest załadowany — jego pozycje autostartu są pominięte.' -f $userName)
                                continue
                            }
                            $folder = $null
                            try {
                                $profileKey = Get-ItemProperty -LiteralPath ('Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\' + $sid) -ErrorAction Stop
                                if ($profileKey.ProfileImagePath) {
                                    $folder = Join-Path -Path ([Environment]::ExpandEnvironmentVariables([string]$profileKey.ProfileImagePath)) -ChildPath 'AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup'
                                }
                            }
                            catch {
                                $warnings += ('Folder profilu użytkownika {0}: {1}' -f $userName, $_.Exception.Message)
                            }
                            $profiles += [pscustomobject]@{ Sid = $sid; Name = $userName; Root = $root; Folder = $folder }
                        }
                    }
                    foreach ($userProfile in $profiles) {
                        $users += [pscustomobject]@{ Sid = $userProfile.Sid; Name = $userProfile.Name; IsCurrent = $userProfile.Sid -eq $currentSid }
                        & $addRegistry 'UserRun' "$($userProfile.Root)\$runPath\Run" "$($userProfile.Root)\$approvedPath\Run" $userProfile.Sid $userProfile.Name
                        & $addRegistry 'UserRunOnce' "$($userProfile.Root)\$runPath\RunOnce" '' $userProfile.Sid $userProfile.Name
                        & $addFolder 'UserStartupFolder' $userProfile.Folder "$($userProfile.Root)\$approvedPath\StartupFolder" $userProfile.Sid $userProfile.Name
                    }
                    $items = $script:found
                    $warnings += $script:readWarnings
                    if ($script:approvalWarning) {
                        $warnings += ('StartupApproved: ' + $script:approvalWarning)
                    }
                }
                catch {
                    $errorText = $_.Exception.Message
                }
                ConvertTo-Json -Depth 5 -Compress -InputObject ([pscustomobject]@{
                        Kind            = 'MWP.StartupItemRaw'
                        ComputerName    = $env:COMPUTERNAME
                        CollectedAt     = (Get-Date).ToString('o')
                        IsAdministrator = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
                        CurrentUserSid  = $currentSid
                        UserMode        = [string]$request.UserMode
                        Users           = @($users)
                        Items           = @($items)
                        Warnings        = @($warnings)
                        Error           = $errorText
                    })
            }
        }
        'ItemState' {
            {
                param([string] $RequestJson)
                $request = ConvertFrom-Json -InputObject $RequestJson
                $approvedPath = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved'
                $currentSid = [string][Security.Principal.WindowsIdentity]::GetCurrent().User.Value
                $before = $null
                $after = $null
                $errorText = $null
                try {
                    $userRoot = if ([string]$request.UserSid -eq $currentSid) { 'Registry::HKEY_CURRENT_USER' } else { 'Registry::HKEY_USERS\' + [string]$request.UserSid }
                    $key = switch ([string]$request.Location) {
                        'MachineRun' { "Registry::HKEY_LOCAL_MACHINE\$approvedPath\Run" }
                        'MachineRun32' { "Registry::HKEY_LOCAL_MACHINE\$approvedPath\Run32" }
                        'MachineStartupFolder' { "Registry::HKEY_LOCAL_MACHINE\$approvedPath\StartupFolder" }
                        'UserRun' { "$userRoot\$approvedPath\Run" }
                        'UserStartupFolder' { "$userRoot\$approvedPath\StartupFolder" }
                        default { throw ('Miejsce {0} nie obsługuje włączania i wyłączania.' -f $request.Location) }
                    }
                    if ([string]$request.Location -like 'User*' -and -not (Test-Path -LiteralPath $userRoot)) {
                        throw ('Profil użytkownika {0} nie jest załadowany.' -f $request.UserSid)
                    }
                    $name = [string]$request.Name
                    $old = $null
                    if (Test-Path -LiteralPath $key) {
                        $property = Get-ItemProperty -LiteralPath $key -ErrorAction Stop
                        if ($null -ne $property.PSObject.Properties[$name] -and $property.PSObject.Properties[$name].Value -is [byte[]]) {
                            $old = [byte[]]$property.PSObject.Properties[$name].Value
                        }
                    }
                    if ($null -ne $old) {
                        $before = (@($old | ForEach-Object { '{0:X2}' -f $_ }) -join '')
                    }
                    # Format Menedżera zadań: 12 bajtów; bit 0 pierwszego bajtu = wyłączona, bajty 4–11 = FILETIME wyłączenia.
                    $first = if ($null -ne $old -and $old.Length -gt 0) { [int]$old[0] -band 0xFC } else { 0 }
                    $bytes = New-Object -TypeName byte[] -ArgumentList 12
                    if ($request.Enabled) {
                        $bytes[0] = [byte]($first -bor 0x02)
                    }
                    else {
                        $bytes[0] = [byte]($first -bor 0x03)
                        $stamp = [BitConverter]::GetBytes([long](Get-Date).ToFileTimeUtc())
                        [Array]::Copy($stamp, 0, $bytes, 4, 8)
                    }
                    if (-not (Test-Path -LiteralPath $key)) {
                        $null = New-Item -Path $key -Force -ErrorAction Stop
                    }
                    $null = New-ItemProperty -LiteralPath $key -Name $name -PropertyType Binary -Value $bytes -Force -ErrorAction Stop
                    $check = Get-ItemProperty -LiteralPath $key -ErrorAction Stop
                    if ($null -ne $check.PSObject.Properties[$name] -and $check.PSObject.Properties[$name].Value -is [byte[]]) {
                        $after = (@([byte[]]$check.PSObject.Properties[$name].Value | ForEach-Object { '{0:X2}' -f $_ }) -join '')
                    }
                }
                catch {
                    $errorText = $_.Exception.Message
                }
                ConvertTo-Json -Compress -InputObject ([pscustomobject]@{
                        Kind   = 'MWP.StartupItemChange'
                        Before = $before
                        After  = $after
                        Error  = $errorText
                    })
            }
        }
        'TaskList' {
            {
                param([string] $RequestJson)
                $request = ConvertFrom-Json -InputObject $RequestJson
                $warnings = @()
                $tasks = @()
                $errorText = $null
                $toText = {
                    param($Value)
                    if ($null -eq $Value) { return $null }
                    try {
                        $date = [datetime]$Value
                        if ($date.Year -lt 2000) { return $null }
                        return $date.ToString('o')
                    }
                    catch {
                        return $null
                    }
                }
                $pathOf = {
                    param([string] $Execute)
                    $path = [Environment]::ExpandEnvironmentVariables([string]$Execute).Trim().Trim('"')
                    if ($path -and -not [IO.Path]::IsPathRooted($path)) {
                        $candidate = Join-Path -Path $env:SystemRoot -ChildPath ('System32\' + $path)
                        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
                            $path = $candidate
                        }
                    }
                    $path
                }
                try {
                    $all = @()
                    if ($request.TaskPath) {
                        try {
                            $all = @(Get-ScheduledTask -TaskPath ([string]$request.TaskPath) -ErrorAction Stop)
                        }
                        catch {
                            $all = @()
                        }
                        if ($request.TaskName) {
                            $all = @($all | Where-Object { [string]$_.TaskName -eq [string]$request.TaskName })
                        }
                    }
                    else {
                        $all = @(Get-ScheduledTask -ErrorAction Stop)
                    }
                    $infoByPath = @{}
                    if ($all.Count -gt 0) {
                        try {
                            foreach ($info in @($all | Get-ScheduledTaskInfo -ErrorAction SilentlyContinue)) {
                                $infoByPath[[string]$info.TaskPath + [string]$info.TaskName] = $info
                            }
                        }
                        catch {
                            $warnings += ('Get-ScheduledTaskInfo: ' + $_.Exception.Message)
                        }
                    }
                    foreach ($task in $all) {
                        $fullPath = [string]$task.TaskPath + [string]$task.TaskName
                        $actions = @()
                        $firstPath = $null
                        foreach ($action in @($task.Actions | Where-Object { $null -ne $_ })) {
                            if ($null -ne $action.PSObject.Properties['Execute'] -and $action.Execute) {
                                $actions += [pscustomobject]@{ Kind = 'Exec'; Execute = [string]$action.Execute; Arguments = [string]$action.Arguments }
                                if (-not $firstPath) {
                                    $firstPath = & $pathOf ([string]$action.Execute)
                                }
                            }
                            else {
                                $actions += [pscustomobject]@{ Kind = 'Other'; Execute = $null; Arguments = $null }
                            }
                        }
                        $triggers = @()
                        foreach ($trigger in @($task.Triggers | Where-Object { $null -ne $_ })) {
                            $className = $null
                            if ($null -ne $trigger.PSObject.Properties['CimClass'] -and $null -ne $trigger.CimClass) {
                                $className = [string]$trigger.CimClass.CimClassName
                            }
                            $triggers += $(if ($className) { $className } else { 'Unknown' })
                        }
                        $signatureStatus = if ($firstPath) { 'NotChecked' } else { 'NoProgram' }
                        $signerSubject = $null
                        $fileExists = $false
                        if ($firstPath) {
                            try {
                                $fileExists = [bool](Test-Path -LiteralPath $firstPath -PathType Leaf)
                            }
                            catch {
                                $fileExists = $false
                            }
                            $skip = $false
                            foreach ($pattern in @($request.SkipSignature | Where-Object { $_ })) {
                                if ($fullPath -like [string]$pattern) {
                                    $skip = $true
                                }
                            }
                            if (-not $fileExists) {
                                $signatureStatus = 'Missing'
                            }
                            elseif ($request.IncludeSignature -and -not $skip) {
                                try {
                                    $signature = Get-AuthenticodeSignature -LiteralPath $firstPath -ErrorAction Stop
                                    $signatureStatus = [string]$signature.Status
                                    if ($null -ne $signature.SignerCertificate) {
                                        $signerSubject = [string]$signature.SignerCertificate.Subject
                                    }
                                }
                                catch {
                                    $signatureStatus = 'Unknown'
                                }
                            }
                        }
                        $info = $infoByPath[$fullPath]
                        $principal = $task.Principal
                        $tasks += [pscustomobject]@{
                            TaskPath        = [string]$task.TaskPath
                            TaskName        = [string]$task.TaskName
                            State           = [string]$task.State
                            Author          = [string]$task.Author
                            Description     = [string]$task.Description
                            UserId          = $(if ($null -ne $principal) { [string]$principal.UserId } else { $null })
                            GroupId         = $(if ($null -ne $principal) { [string]$principal.GroupId } else { $null })
                            LogonType       = $(if ($null -ne $principal) { [string]$principal.LogonType } else { $null })
                            RunLevel        = $(if ($null -ne $principal) { [string]$principal.RunLevel } else { $null })
                            Actions         = @($actions)
                            Triggers        = @($triggers)
                            FilePath        = $firstPath
                            FileExists      = $fileExists
                            SignatureStatus = $signatureStatus
                            SignerSubject   = $signerSubject
                            LastRunTime     = $(if ($null -ne $info) { & $toText $info.LastRunTime } else { $null })
                            NextRunTime     = $(if ($null -ne $info) { & $toText $info.NextRunTime } else { $null })
                            LastTaskResult  = $(if ($null -ne $info -and $null -ne $info.LastTaskResult) { [long]$info.LastTaskResult } else { $null })
                        }
                    }
                }
                catch {
                    $errorText = $_.Exception.Message
                }
                $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
                $principalCheck = New-Object -TypeName Security.Principal.WindowsPrincipal -ArgumentList $identity
                ConvertTo-Json -Depth 5 -Compress -InputObject ([pscustomobject]@{
                        Kind            = 'MWP.ScheduledTaskRaw'
                        ComputerName    = $env:COMPUTERNAME
                        CollectedAt     = (Get-Date).ToString('o')
                        IsAdministrator = $principalCheck.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
                        Tasks           = @($tasks)
                        Warnings        = @($warnings)
                        Error           = $errorText
                    })
            }
        }
        'TaskControl' {
            {
                param([string] $RequestJson)
                $request = ConvertFrom-Json -InputObject $RequestJson
                $taskPath = [string]$request.TaskPath
                $taskName = [string]$request.TaskName
                $action = [string]$request.Action
                $find = {
                    try {
                        @(Get-ScheduledTask -TaskPath $taskPath -ErrorAction Stop | Where-Object { [string]$_.TaskName -eq $taskName }) | Select-Object -First 1
                    }
                    catch {
                        $null
                    }
                }
                $xml = $null
                $errorText = $null
                $errorCode = $null
                $found = $false
                try {
                    $task = & $find
                    $found = $null -ne $task
                    if ($action -eq 'Register') {
                        if ($found) {
                            throw ('Zadanie {0}{1} już istnieje.' -f $taskPath, $taskName)
                        }
                        $null = Register-ScheduledTask -Xml ([string]$request.Xml) -TaskPath $taskPath -TaskName $taskName -ErrorAction Stop
                    }
                    elseif (-not $found) {
                        throw ('Nie ma zadania {0}{1}.' -f $taskPath, $taskName)
                    }
                    else {
                        switch ($action) {
                            'Enable' { $null = $task | Enable-ScheduledTask -ErrorAction Stop }
                            'Disable' { $null = $task | Disable-ScheduledTask -ErrorAction Stop }
                            'Start' { $null = $task | Start-ScheduledTask -ErrorAction Stop }
                            'Export' { $xml = [string]($task | Export-ScheduledTask -ErrorAction Stop) }
                            'Remove' { $null = $task | Unregister-ScheduledTask -Confirm:$false -ErrorAction Stop }
                            default { throw ('Nieznana akcja {0}.' -f $action) }
                        }
                    }
                }
                catch {
                    $errorText = $_.Exception.Message
                    $errorCode = [int]$_.Exception.HResult
                }
                $afterTask = & $find
                ConvertTo-Json -Compress -InputObject ([pscustomobject]@{
                        Kind      = 'MWP.ScheduledTaskControl'
                        Found     = $found
                        Exists    = $null -ne $afterTask
                        State     = $(if ($null -ne $afterTask) { [string]$afterTask.State } else { $null })
                        Xml       = $xml
                        Error     = $errorText
                        ErrorCode = $errorCode
                    })
            }
        }
    }
}
