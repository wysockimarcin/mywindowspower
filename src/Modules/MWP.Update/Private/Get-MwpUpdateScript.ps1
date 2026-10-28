function Get-MwpUpdateScript {
    <#
    .SYNOPSIS
        Zwraca blok skryptu wykonywany na komputerze docelowym (Invoke-MwpOnTarget / Start-MwpOperation).

    .DESCRIPTION
        Bloki są samowystarczalne i zgodne z Windows PowerShell 5.1 (D-036): dane przychodzą przez
        parametry (żądanie JSON z kluczami, folderami i stałymi kryteriami wyszukiwania z hosta, D-015),
        wynik wraca jako tekst JSON. Windows Update Agent przez COM (Microsoft.Update.*), bez modułów
        zewnętrznych (D-048).
        - Status: usługi wuauserv/bits/cryptsvc/usosvc (Win32_Service), wymagany restart
          (Microsoft.Update.SystemInfo i klucze RebootRequired/RebootPending), daty ostatniego
          wyszukiwania i instalacji (Microsoft.Update.AutoUpdate), wartości pauzy i zasad, kopie
          folderów z resetu (*.mwp-*), uprawnienia administratora.
        - Search: IUpdateSearcher.Search ze stałymi kryteriami (oczekujące, nieukryte).
        - History: IUpdateSearcher.QueryHistory (najnowsze wpisy).
        - PauseWrite: zapis albo usunięcie wartości pauzy (REG_SZ) i ponowny odczyt.
        - Install: wyszukanie, potem pobranie i instalacja po jednej aktualizacji (postęp i anulowanie
          między aktualizacjami przez tabelę -Progress); tylko lokalnie (D-048).
        - Reset: zatrzymanie usług, zmiana nazw SoftwareDistribution i catroot2 (Mode Reset) albo
          przywrócenie kopii (Mode Restore), ponowne uruchomienie usług, które działały; przy błędzie
          zmiany nazwy wcześniejsze zmiany są wycofywane.

    .PARAMETER Name
        Nazwa bloku.
    #>
    [CmdletBinding()]
    [OutputType([scriptblock])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Status', 'Search', 'History', 'PauseWrite', 'Install', 'Reset')]
        [string] $Name
    )

    switch ($Name) {
        'Status' {
            {
                param([string] $RequestJson)
                $request = ConvertFrom-Json -InputObject $RequestJson
                $warnings = @()
                $services = @()
                $names = @(@($request.Services) | ForEach-Object { [string]$_ })
                try {
                    $found = @{}
                    foreach ($item in @(Get-CimInstance -ClassName Win32_Service -ErrorAction Stop)) {
                        if ($names -notcontains [string]$item.Name) {
                            continue
                        }
                        $delayed = $false
                        if ($null -ne $item.PSObject.Properties['DelayedAutoStart'] -and $null -ne $item.DelayedAutoStart) {
                            $delayed = [bool]$item.DelayedAutoStart
                        }
                        $found[([string]$item.Name).ToLowerInvariant()] = $true
                        $services += [pscustomobject]@{
                            Name        = [string]$item.Name
                            DisplayName = [string]$item.DisplayName
                            State       = [string]$item.State
                            StartMode   = [string]$item.StartMode
                            Delayed     = $delayed
                        }
                    }
                    foreach ($name in $names) {
                        if (-not $found.ContainsKey($name.ToLowerInvariant())) {
                            $services += [pscustomobject]@{ Name = $name; DisplayName = $name; State = 'Missing'; StartMode = ''; Delayed = $false }
                        }
                    }
                }
                catch {
                    $warnings += ('Usługi: ' + $_.Exception.Message)
                }

                $rebootRequired = $null
                try {
                    $rebootRequired = [bool](New-Object -ComObject Microsoft.Update.SystemInfo).RebootRequired
                }
                catch {
                    $warnings += ('Microsoft.Update.SystemInfo: ' + $_.Exception.Message)
                }
                $rebootKeys = @()
                foreach ($key in @($request.RebootKeys)) {
                    if (Test-Path -LiteralPath ([string]$key)) {
                        $rebootKeys += [string]$key
                    }
                }

                $lastSearch = $null
                $lastInstall = $null
                try {
                    $results = (New-Object -ComObject Microsoft.Update.AutoUpdate).Results
                    foreach ($pair in @(@('Search', $results.LastSearchSuccessDate), @('Install', $results.LastInstallationSuccessDate))) {
                        $value = $pair[1]
                        if ($null -ne $value -and ([datetime]$value).Year -gt 2000) {
                            $text = [datetime]::SpecifyKind([datetime]$value, [DateTimeKind]::Utc).ToString('o')
                            if ($pair[0] -eq 'Search') { $lastSearch = $text } else { $lastInstall = $text }
                        }
                    }
                }
                catch {
                    $warnings += ('Microsoft.Update.AutoUpdate: ' + $_.Exception.Message)
                }

                $pause = New-Object -TypeName PSObject
                $policy = New-Object -TypeName PSObject
                foreach ($set in @(@($request.PauseKey, $request.PauseValues, $pause), @($request.PolicyKey, $request.PolicyValues, $policy))) {
                    $item = $null
                    try {
                        if (Test-Path -LiteralPath ([string]$set[0])) {
                            $item = Get-ItemProperty -LiteralPath ([string]$set[0]) -ErrorAction Stop
                        }
                    }
                    catch {
                        $warnings += ('Rejestr {0}: {1}' -f $set[0], $_.Exception.Message)
                    }
                    foreach ($valueName in @($set[1])) {
                        $value = $null
                        if ($null -ne $item -and $null -ne $item.PSObject.Properties[[string]$valueName]) {
                            $value = [string]$item.([string]$valueName)
                        }
                        $set[2] | Add-Member -MemberType NoteProperty -Name ([string]$valueName) -Value $value
                    }
                }

                $root = if ($request.WindowsRoot) { [string]$request.WindowsRoot } else { $env:SystemRoot }
                $backups = @()
                foreach ($folder in @($request.ResetFolders)) {
                    $path = Join-Path -Path $root -ChildPath ([string]$folder.RelativePath)
                    $parent = Split-Path -Parent $path
                    $leaf = Split-Path -Leaf $path
                    try {
                        foreach ($directory in @(Get-ChildItem -LiteralPath $parent -Directory -Force -ErrorAction Stop | Where-Object { $_.Name -like ($leaf + '.mwp-*') })) {
                            $backups += [pscustomobject]@{
                                Folder    = [string]$folder.Name
                                Path      = $directory.FullName
                                Suffix    = $directory.Name.Substring($leaf.Length + 1)
                                CreatedAt = $directory.CreationTimeUtc.ToString('o')
                            }
                        }
                    }
                    catch {
                        $warnings += ('Kopie folderu {0}: {1}' -f $folder.Name, $_.Exception.Message)
                    }
                }

                $principal = New-Object -TypeName Security.Principal.WindowsPrincipal -ArgumentList ([Security.Principal.WindowsIdentity]::GetCurrent())
                ConvertTo-Json -Depth 5 -Compress -InputObject ([pscustomobject]@{
                        Kind            = 'MWP.UpdateStatusRaw'
                        ComputerName    = $env:COMPUTERNAME
                        CollectedAt     = (Get-Date).ToString('o')
                        IsAdministrator = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
                        Services        = $services
                        RebootRequired  = $rebootRequired
                        RebootKeys      = $rebootKeys
                        LastSearch      = $lastSearch
                        LastInstall     = $lastInstall
                        Pause           = $pause
                        Policy          = $policy
                        Backups         = $backups
                        Warnings        = $warnings
                    })
            }
        }
        'Search' {
            {
                param([string] $RequestJson)
                $request = ConvertFrom-Json -InputObject $RequestJson
                $updates = @()
                $errorText = $null
                $hresult = $null
                $resultCode = $null
                try {
                    $session = New-Object -ComObject Microsoft.Update.Session
                    $session.ClientApplicationID = [string]$request.ClientApplicationId
                    $searcher = $session.CreateUpdateSearcher()
                    $found = $searcher.Search([string]$request.Criteria)
                    $resultCode = [int]$found.ResultCode
                    foreach ($update in @($found.Updates)) {
                        if ($null -eq $update) {
                            continue
                        }
                        $published = $null
                        try {
                            if ($null -ne $update.LastDeploymentChangeTime -and ([datetime]$update.LastDeploymentChangeTime).Year -gt 2000) {
                                $published = [datetime]::SpecifyKind([datetime]$update.LastDeploymentChangeTime, [DateTimeKind]::Utc).ToString('o')
                            }
                        }
                        catch {
                            $published = $null
                        }
                        $behavior = $update.InstallationBehavior
                        $updates += [pscustomobject]@{
                            UpdateId            = [string]$update.Identity.UpdateID
                            Revision            = [int]$update.Identity.RevisionNumber
                            Title               = [string]$update.Title
                            Description         = [string]$update.Description
                            KB                  = @(foreach ($kb in @($update.KBArticleIDs)) { if ($kb) { 'KB' + [string]$kb } })
                            Categories          = @(foreach ($category in @($update.Categories)) { if ($null -ne $category) { [string]$category.Name } })
                            Type                = [int]$update.Type
                            Severity            = [string]$update.MsrcSeverity
                            MaxDownloadSize     = [double]$update.MaxDownloadSize
                            IsDownloaded        = [bool]$update.IsDownloaded
                            IsMandatory         = [bool]$update.IsMandatory
                            EulaAccepted        = [bool]$update.EulaAccepted
                            RebootBehavior      = $(if ($null -ne $behavior) { [int]$behavior.RebootBehavior } else { -1 })
                            CanRequestUserInput = $(if ($null -ne $behavior) { [bool]$behavior.CanRequestUserInput } else { $false })
                            Published           = $published
                            SupportUrl          = [string]$update.SupportUrl
                        }
                    }
                }
                catch {
                    $exception = $_.Exception
                    while ($null -ne $exception.InnerException -and $exception -isnot [Runtime.InteropServices.COMException]) {
                        $exception = $exception.InnerException
                    }
                    $errorText = $exception.Message
                    $hresult = '0x{0:X8}' -f [int]$exception.HResult
                }
                $principal = New-Object -TypeName Security.Principal.WindowsPrincipal -ArgumentList ([Security.Principal.WindowsIdentity]::GetCurrent())
                ConvertTo-Json -Depth 5 -Compress -InputObject ([pscustomobject]@{
                        Kind            = 'MWP.UpdateSearchRaw'
                        ComputerName    = $env:COMPUTERNAME
                        CollectedAt     = (Get-Date).ToString('o')
                        IsAdministrator = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
                        Criteria        = [string]$request.Criteria
                        ResultCode      = $resultCode
                        Updates         = $updates
                        Error           = $errorText
                        HResult         = $hresult
                    })
            }
        }
        'History' {
            {
                param([string] $RequestJson)
                $request = ConvertFrom-Json -InputObject $RequestJson
                $entries = @()
                $total = 0
                $errorText = $null
                $hresult = $null
                try {
                    $session = New-Object -ComObject Microsoft.Update.Session
                    $searcher = $session.CreateUpdateSearcher()
                    $total = [int]$searcher.GetTotalHistoryCount()
                    $count = [Math]::Min($total, [int]$request.First)
                    if ($count -gt 0) {
                        foreach ($entry in @($searcher.QueryHistory(0, $count))) {
                            if ($null -eq $entry) {
                                continue
                            }
                            $date = $null
                            try {
                                if ($null -ne $entry.Date -and ([datetime]$entry.Date).Year -gt 2000) {
                                    $date = [datetime]::SpecifyKind([datetime]$entry.Date, [DateTimeKind]::Utc).ToString('o')
                                }
                            }
                            catch {
                                $date = $null
                            }
                            $updateId = ''
                            if ($null -ne $entry.UpdateIdentity) {
                                $updateId = [string]$entry.UpdateIdentity.UpdateID
                            }
                            $entries += [pscustomobject]@{
                                Date                = $date
                                Operation           = [int]$entry.Operation
                                ResultCode          = [int]$entry.ResultCode
                                HResult             = ('0x{0:X8}' -f [int]$entry.HResult)
                                Title               = [string]$entry.Title
                                Description         = [string]$entry.Description
                                ClientApplicationId = [string]$entry.ClientApplicationID
                                SupportUrl          = [string]$entry.SupportUrl
                                UpdateId            = $updateId
                            }
                        }
                    }
                }
                catch {
                    $exception = $_.Exception
                    while ($null -ne $exception.InnerException -and $exception -isnot [Runtime.InteropServices.COMException]) {
                        $exception = $exception.InnerException
                    }
                    $errorText = $exception.Message
                    $hresult = '0x{0:X8}' -f [int]$exception.HResult
                }
                ConvertTo-Json -Depth 5 -Compress -InputObject ([pscustomobject]@{
                        Kind         = 'MWP.UpdateHistoryRaw'
                        ComputerName = $env:COMPUTERNAME
                        CollectedAt  = (Get-Date).ToString('o')
                        TotalCount   = $total
                        Entries      = $entries
                        Error        = $errorText
                        HResult      = $hresult
                    })
            }
        }
        'PauseWrite' {
            {
                param([string] $RequestJson)
                $request = ConvertFrom-Json -InputObject $RequestJson
                $key = [string]$request.Key
                $errorText = $null
                try {
                    $item = $null
                    if (Test-Path -LiteralPath $key) {
                        $item = Get-ItemProperty -LiteralPath $key -ErrorAction Stop
                    }
                    foreach ($property in @($request.Values.PSObject.Properties)) {
                        $exists = $null -ne $item -and $null -ne $item.PSObject.Properties[$property.Name]
                        $value = $property.Value
                        if ($value -is [datetime]) {
                            # ConvertFrom-Json w PowerShell 7 zamienia tekst ISO 8601 na datę — wracamy do zapisu Ustawień.
                            if ($value.Kind -eq [DateTimeKind]::Local) {
                                $value = $value.ToUniversalTime()
                            }
                            $value = $value.ToString("yyyy-MM-dd'T'HH:mm:ss'Z'", [Globalization.CultureInfo]::InvariantCulture)
                        }
                        if ($null -eq $value -or [string]$value -eq '') {
                            if ($exists) {
                                Remove-ItemProperty -LiteralPath $key -Name $property.Name -ErrorAction Stop
                            }
                            continue
                        }
                        if (-not (Test-Path -LiteralPath $key)) {
                            $null = New-Item -Path $key -Force -ErrorAction Stop
                        }
                        Set-ItemProperty -LiteralPath $key -Name $property.Name -Value ([string]$value) -ErrorAction Stop
                    }
                }
                catch {
                    $errorText = $_.Exception.Message
                }
                $after = New-Object -TypeName PSObject
                $item = $null
                if (Test-Path -LiteralPath $key) {
                    $item = Get-ItemProperty -LiteralPath $key -ErrorAction SilentlyContinue
                }
                foreach ($property in @($request.Values.PSObject.Properties)) {
                    $value = $null
                    if ($null -ne $item -and $null -ne $item.PSObject.Properties[$property.Name]) {
                        $value = [string]$item.($property.Name)
                    }
                    $after | Add-Member -MemberType NoteProperty -Name $property.Name -Value $value
                }
                ConvertTo-Json -Depth 5 -Compress -InputObject ([pscustomobject]@{
                        Kind  = 'MWP.UpdatePauseWrite'
                        After = $after
                        Error = $errorText
                    })
            }
        }
        'Install' {
            {
                param([string] $RequestJson, $Progress)
                $request = ConvertFrom-Json -InputObject $RequestJson
                $wanted = @(@($request.UpdateIds) | ForEach-Object { ([string]$_).ToLowerInvariant() })
                $items = @()
                $errorText = $null
                $hresult = $null
                $cancelled = $false
                $rebootRequired = $false
                $describe = {
                    param($Exception)
                    while ($null -ne $Exception.InnerException -and $Exception -isnot [Runtime.InteropServices.COMException]) {
                        $Exception = $Exception.InnerException
                    }
                    @($Exception.Message, ('0x{0:X8}' -f [int]$Exception.HResult))
                }
                try {
                    if ($null -ne $Progress) {
                        $Progress.Percent = 0
                        $Progress.Message = 'Wyszukiwanie aktualizacji…'
                    }
                    $session = New-Object -ComObject Microsoft.Update.Session
                    $session.ClientApplicationID = [string]$request.ClientApplicationId
                    $found = $session.CreateUpdateSearcher().Search([string]$request.Criteria)
                    $selected = @()
                    $seen = @{}
                    foreach ($update in @($found.Updates)) {
                        $id = ([string]$update.Identity.UpdateID).ToLowerInvariant()
                        if ($wanted -contains $id -and -not $seen.ContainsKey($id)) {
                            $seen[$id] = $true
                            $selected += $update
                        }
                    }
                    foreach ($id in $wanted) {
                        if (-not $seen.ContainsKey($id)) {
                            $items += [pscustomobject]@{ UpdateId = $id; Title = ''; Status = 'NotFound'; ResultCode = $null; HResult = $null; RebootRequired = $false; Reason = 'nie ma jej już wśród oczekujących aktualizacji' }
                        }
                    }
                    $index = 0
                    foreach ($update in $selected) {
                        $id = [string]$update.Identity.UpdateID
                        $title = [string]$update.Title
                        if ($null -ne $Progress -and $Progress.CancelRequested) {
                            $cancelled = $true
                            $items += [pscustomobject]@{ UpdateId = $id; Title = $title; Status = 'Cancelled'; ResultCode = $null; HResult = $null; RebootRequired = $false; Reason = 'anulowano przed rozpoczęciem' }
                            continue
                        }
                        if ($null -ne $Progress) {
                            $Progress.Percent = [int](100 * $index / [Math]::Max(1, $selected.Count))
                            $Progress.Message = ('({0}/{1}) {2}' -f ($index + 1), $selected.Count, $title)
                        }
                        $index++
                        $behavior = $update.InstallationBehavior
                        if ($null -ne $behavior -and [bool]$behavior.CanRequestUserInput) {
                            $items += [pscustomobject]@{ UpdateId = $id; Title = $title; Status = 'Skipped'; ResultCode = $null; HResult = $null; RebootRequired = $false; Reason = 'wymaga interakcji użytkownika — zainstaluj w Ustawieniach Windows Update' }
                            continue
                        }
                        if (-not [bool]$update.EulaAccepted) {
                            $items += [pscustomobject]@{ UpdateId = $id; Title = $title; Status = 'Skipped'; ResultCode = $null; HResult = $null; RebootRequired = $false; Reason = 'wymaga akceptacji postanowień licencyjnych — zainstaluj w Ustawieniach Windows Update' }
                            continue
                        }
                        try {
                            $collection = New-Object -ComObject Microsoft.Update.UpdateColl
                            $null = $collection.Add($update)
                            if (-not [bool]$update.IsDownloaded) {
                                $downloader = $session.CreateUpdateDownloader()
                                $downloader.Updates = $collection
                                $download = $downloader.Download()
                                if ([int]$download.ResultCode -ne 2 -and [int]$download.ResultCode -ne 3) {
                                    $items += [pscustomobject]@{ UpdateId = $id; Title = $title; Status = 'Failed'; ResultCode = [int]$download.ResultCode; HResult = ('0x{0:X8}' -f [int]$download.HResult); RebootRequired = $false; Reason = 'pobieranie nie powiodło się' }
                                    continue
                                }
                            }
                            $installer = $session.CreateUpdateInstaller()
                            if ([bool]$installer.IsBusy) {
                                $items += [pscustomobject]@{ UpdateId = $id; Title = $title; Status = 'Failed'; ResultCode = $null; HResult = '0x80240016'; RebootRequired = $false; Reason = 'instalator Windows Update jest zajęty inną instalacją' }
                                continue
                            }
                            $installer.AllowSourcePrompts = $false
                            $installer.Updates = $collection
                            $install = $installer.Install()
                            $one = $install.GetUpdateResult(0)
                            $code = [int]$one.ResultCode
                            $reboot = [bool]$one.RebootRequired -or [bool]$install.RebootRequired
                            if ($reboot) {
                                $rebootRequired = $true
                            }
                            $status = if ($code -eq 2 -or $code -eq 3) { 'Installed' } else { 'Failed' }
                            $items += [pscustomobject]@{ UpdateId = $id; Title = $title; Status = $status; ResultCode = $code; HResult = ('0x{0:X8}' -f [int]$one.HResult); RebootRequired = $reboot; Reason = $(if ($status -eq 'Failed') { 'instalacja nie powiodła się' } else { '' }) }
                        }
                        catch {
                            $info = & $describe $_.Exception
                            $items += [pscustomobject]@{ UpdateId = $id; Title = $title; Status = 'Failed'; ResultCode = $null; HResult = $info[1]; RebootRequired = $false; Reason = $info[0] }
                        }
                    }
                    if ($null -ne $Progress) {
                        $Progress.Percent = 100
                    }
                }
                catch {
                    $info = & $describe $_.Exception
                    $errorText = $info[0]
                    $hresult = $info[1]
                }
                try {
                    if ([bool](New-Object -ComObject Microsoft.Update.SystemInfo).RebootRequired) {
                        $rebootRequired = $true
                    }
                }
                catch {
                    $null = $_
                }
                ConvertTo-Json -Depth 5 -Compress -InputObject ([pscustomobject]@{
                        Kind           = 'MWP.UpdateInstallRaw'
                        ComputerName   = $env:COMPUTERNAME
                        Items          = $items
                        RebootRequired = $rebootRequired
                        Cancelled      = $cancelled
                        Error          = $errorText
                        HResult        = $hresult
                    })
            }
        }
        'Reset' {
            {
                param([string] $RequestJson)
                $request = ConvertFrom-Json -InputObject $RequestJson
                $root = if ($request.WindowsRoot) { [string]$request.WindowsRoot } else { $env:SystemRoot }
                $timeout = [TimeSpan]::FromSeconds([int]$request.TimeoutSeconds)
                $optional = @(@($request.OptionalServices) | ForEach-Object { ([string]$_).ToLowerInvariant() })
                $steps = @()
                $renamed = @()
                $errorText = $null
                $initial = @{}
                $controllers = @{}

                foreach ($name in @($request.Services)) {
                    try {
                        $service = Get-Service -Name ([string]$name) -ErrorAction Stop
                        $controllers[[string]$name] = $service
                        $initial[[string]$name] = [string]$service.Status
                    }
                    catch {
                        $initial[[string]$name] = 'Missing'
                        $steps += [pscustomobject]@{ Step = 'Read'; Target = [string]$name; Success = $true; Message = ('usługa nie istnieje — pominięto ({0})' -f $_.Exception.Message) }
                    }
                }
                foreach ($name in @($request.Services)) {
                    if (-not $controllers.ContainsKey([string]$name)) {
                        continue
                    }
                    $service = $controllers[[string]$name]
                    try {
                        $service.Refresh()
                        if ([string]$service.Status -ne 'Stopped') {
                            $service.Stop()
                            $service.WaitForStatus('Stopped', $timeout)
                            $steps += [pscustomobject]@{ Step = 'Stop'; Target = [string]$name; Success = $true; Message = 'zatrzymano' }
                        }
                        else {
                            $steps += [pscustomobject]@{ Step = 'Stop'; Target = [string]$name; Success = $true; Message = 'była zatrzymana' }
                        }
                    }
                    catch {
                        if ($optional -contains ([string]$name).ToLowerInvariant()) {
                            $steps += [pscustomobject]@{ Step = 'Stop'; Target = [string]$name; Success = $true; Message = ('nie zatrzymano (usługa opcjonalna, reset trwa dalej): {0}' -f $_.Exception.Message) }
                            continue
                        }
                        $errorText = 'Nie udało się zatrzymać usługi {0}: {1}' -f $name, $_.Exception.Message
                        $steps += [pscustomobject]@{ Step = 'Stop'; Target = [string]$name; Success = $false; Message = $_.Exception.Message }
                        break
                    }
                }

                if ($null -eq $errorText) {
                    foreach ($folder in @($request.Folders)) {
                        $path = Join-Path -Path $root -ChildPath ([string]$folder.RelativePath)
                        $backup = $path + '.' + [string]$request.Suffix
                        if ($request.Mode -eq 'Restore') {
                            $moves = @()
                            if (-not (Test-Path -LiteralPath $backup)) {
                                $steps += [pscustomobject]@{ Step = 'Rename'; Target = $backup; Success = $true; Message = 'brak kopii — pominięto' }
                                continue
                            }
                            if (Test-Path -LiteralPath $path) {
                                $moves += , @($path, ($path + '.' + [string]$request.ReplacedSuffix))
                            }
                            $moves += , @($backup, $path)
                        }
                        else {
                            if (-not (Test-Path -LiteralPath $path)) {
                                $steps += [pscustomobject]@{ Step = 'Rename'; Target = $path; Success = $true; Message = 'folder nie istnieje — pominięto' }
                                continue
                            }
                            $moves = @(, @($path, $backup))
                        }
                        foreach ($move in $moves) {
                            $from = $move[0]
                            $to = $move[1]
                            if (Test-Path -LiteralPath $to) {
                                $errorText = 'Folder docelowy {0} już istnieje.' -f $to
                            }
                            elseif (([IO.File]::GetAttributes($from) -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                                $errorText = 'Folder {0} jest dowiązaniem (junction/symlink) — zmiana nazwy odrzucona.' -f $from
                            }
                            else {
                                $last = $null
                                for ($attempt = 1; $attempt -le 3; $attempt++) {
                                    try {
                                        [IO.Directory]::Move($from, $to)
                                        $last = $null
                                        break
                                    }
                                    catch {
                                        $last = $_.Exception.Message
                                        Start-Sleep -Seconds 2
                                        foreach ($service in $controllers.Values) {
                                            try {
                                                $service.Refresh()
                                                if ([string]$service.Status -ne 'Stopped') {
                                                    $service.Stop()
                                                    $service.WaitForStatus('Stopped', $timeout)
                                                }
                                            }
                                            catch {
                                                $null = $_
                                            }
                                        }
                                    }
                                }
                                if ($null -ne $last) {
                                    $errorText = 'Nie udało się zmienić nazwy {0}: {1}' -f $from, $last
                                }
                            }
                            if ($null -ne $errorText) {
                                $steps += [pscustomobject]@{ Step = 'Rename'; Target = $from; Success = $false; Message = $errorText }
                                break
                            }
                            $renamed += [pscustomobject]@{ Folder = [string]$folder.Name; From = $from; To = $to }
                            $steps += [pscustomobject]@{ Step = 'Rename'; Target = $from; Success = $true; Message = ('→ {0}' -f $to) }
                        }
                        if ($null -ne $errorText) {
                            break
                        }
                    }
                    if ($null -ne $errorText -and $renamed.Count -gt 0) {
                        $kept = @()
                        for ($i = $renamed.Count - 1; $i -ge 0; $i--) {
                            $item = $renamed[$i]
                            try {
                                [IO.Directory]::Move($item.To, $item.From)
                                $steps += [pscustomobject]@{ Step = 'Rollback'; Target = $item.To; Success = $true; Message = ('przywrócono nazwę {0}' -f $item.From) }
                            }
                            catch {
                                $kept += $item
                                $steps += [pscustomobject]@{ Step = 'Rollback'; Target = $item.To; Success = $false; Message = $_.Exception.Message }
                            }
                        }
                        $renamed = $kept
                    }
                }

                $order = @($request.Services)
                for ($i = $order.Count - 1; $i -ge 0; $i--) {
                    $name = [string]$order[$i]
                    if ($initial[$name] -ne 'Running' -or -not $controllers.ContainsKey($name)) {
                        continue
                    }
                    $service = $controllers[$name]
                    try {
                        $service.Refresh()
                        if ([string]$service.Status -ne 'Running') {
                            $service.Start()
                            $service.WaitForStatus('Running', $timeout)
                        }
                        $steps += [pscustomobject]@{ Step = 'Start'; Target = $name; Success = $true; Message = 'uruchomiono' }
                    }
                    catch {
                        $steps += [pscustomobject]@{ Step = 'Start'; Target = $name; Success = $false; Message = $_.Exception.Message }
                    }
                }

                $principal = New-Object -TypeName Security.Principal.WindowsPrincipal -ArgumentList ([Security.Principal.WindowsIdentity]::GetCurrent())
                ConvertTo-Json -Depth 5 -Compress -InputObject ([pscustomobject]@{
                        Kind            = 'MWP.UpdateResetRaw'
                        ComputerName    = $env:COMPUTERNAME
                        Mode            = [string]$request.Mode
                        Root            = $root
                        IsAdministrator = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
                        Steps           = $steps
                        Renamed         = $renamed
                        Error           = $errorText
                    })
            }
        }
    }
}
