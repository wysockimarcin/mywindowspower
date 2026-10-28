function Get-MwpNetworkScript {
    <#
    .SYNOPSIS
        Zwraca blok skryptu wykonywany na komputerze docelowym (Invoke-MwpOnTarget / Start-MwpOperation).

    .DESCRIPTION
        Bloki są samowystarczalne i zgodne z Windows PowerShell 5.1 (D-036): dane przychodzą przez
        parametry (żądanie JSON z hosta, wartości sprawdzone przed wysłaniem, D-015), wynik wraca jako
        tekst JSON. Polecenia wbudowane (NetAdapter, NetTCPIP, DnsClient, ScheduledTasks, CIM), bez
        modułów zewnętrznych (D-049).
        - Status: adaptery (także wyłączone), adresy IP, bramy, serwery DNS (skuteczne i statyczne
          z rejestru Tcpip/Tcpip6), DHCP i dzierżawa, profil sieci, adaptery połączenia zdalnego
          (połączenia TCP na porcie WinRM), zmiany czekające na zatwierdzenie (zadania wycofania),
          uprawnienia administratora.
        - Change: zmiana DNS (reset do DHCP i opcjonalnie lista statyczna), wyłączenie albo włączenie
          adaptera; przed zmianą — gdy RollbackSeconds > 0 — rejestruje jednorazowe zadanie
          harmonogramu (SYSTEM) z blokiem wycofania i stanem sprzed zmiany wbudowanym w zadanie;
          błąd zmiany wycofuje ją od razu tym samym blokiem.
        - Approve: zatwierdzenie zmiany = usunięcie zadania wycofania.
        - FlushDns, RenewDhcp, ResetStack (netsh winsock reset / netsh int ip reset), Test (ping,
          rozwiązywanie nazwy, port TCP).

    .PARAMETER Name
        Nazwa bloku.
    #>
    [CmdletBinding()]
    [OutputType([scriptblock])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Status', 'Change', 'Approve', 'FlushDns', 'RenewDhcp', 'ResetStack', 'Test')]
        [string] $Name
    )

    switch ($Name) {
        'Status' {
            {
                param([string] $RequestJson)
                $request = ConvertFrom-Json -InputObject $RequestJson
                $warnings = @()
                $readStatic = {
                    param([string] $Service, [string] $Guid)
                    $path = 'HKLM:\SYSTEM\CurrentControlSet\Services\{0}\Parameters\Interfaces\{1}' -f $Service, $Guid
                    $value = $null
                    try {
                        $value = (Get-ItemProperty -LiteralPath $path -Name 'NameServer' -ErrorAction Stop).NameServer
                    }
                    catch {
                        $value = $null
                    }
                    @(([string]$value) -split '[,\s]+' | Where-Object { $_ })
                }
                $adapters = @()
                try {
                    $adapters = @(Get-NetAdapter -ErrorAction Stop)
                }
                catch {
                    $warnings += ('Adaptery: ' + $_.Exception.Message)
                }
                $addresses = @(Get-NetIPAddress -ErrorAction SilentlyContinue)
                $routes = @(Get-NetRoute -DestinationPrefix '0.0.0.0/0', '::/0' -ErrorAction SilentlyContinue)
                $dnsServers = @(Get-DnsClientServerAddress -ErrorAction SilentlyContinue)
                $ipInterfaces = @(Get-NetIPInterface -ErrorAction SilentlyContinue)
                $profiles = @(Get-NetConnectionProfile -ErrorAction SilentlyContinue)
                $configs = @()
                try {
                    $configs = @(Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration -ErrorAction Stop)
                }
                catch {
                    $warnings += ('Win32_NetworkAdapterConfiguration: ' + $_.Exception.Message)
                }

                # Adaptery połączenia zdalnego: połączenia TCP na porcie WinRM tego komputera.
                $connectionIndex = @()
                $connectionAddress = @()
                if ([int]$request.ConnectionPort -gt 0) {
                    foreach ($tcp in @(Get-NetTCPConnection -LocalPort ([int]$request.ConnectionPort) -State Established -ErrorAction SilentlyContinue)) {
                        $connectionAddress += [string]$tcp.LocalAddress
                        foreach ($address in $addresses) {
                            if ([string]$address.IPAddress -eq [string]$tcp.LocalAddress) {
                                $connectionIndex += [int]$address.InterfaceIndex
                            }
                        }
                    }
                }

                $date = {
                    param($Value)
                    if ($null -eq $Value -or [string]$Value -eq '') { return $null }
                    try { return ([datetime]$Value).ToString('o') } catch { return $null }
                }
                $items = @()
                foreach ($adapter in $adapters) {
                    $index = [int]$adapter.InterfaceIndex
                    $guid = [string]$adapter.InterfaceGuid
                    $ipv4 = @($addresses | Where-Object { [int]$_.InterfaceIndex -eq $index -and [string]$_.AddressFamily -eq 'IPv4' } |
                            ForEach-Object { '{0}/{1}' -f $_.IPAddress, $_.PrefixLength })
                    $ipv6 = @($addresses | Where-Object { [int]$_.InterfaceIndex -eq $index -and [string]$_.AddressFamily -eq 'IPv6' } |
                            ForEach-Object { '{0}/{1}' -f $_.IPAddress, $_.PrefixLength })
                    $gateways = @($routes | Where-Object { [int]$_.InterfaceIndex -eq $index -and $_.NextHop -and [string]$_.NextHop -ne '0.0.0.0' -and [string]$_.NextHop -ne '::' } |
                            Sort-Object -Property RouteMetric | ForEach-Object { [string]$_.NextHop })
                    $dnsV4 = @($dnsServers | Where-Object { [int]$_.InterfaceIndex -eq $index -and [int]$_.AddressFamily -eq 2 } | ForEach-Object { @($_.ServerAddresses) })
                    $dnsV6 = @($dnsServers | Where-Object { [int]$_.InterfaceIndex -eq $index -and [int]$_.AddressFamily -eq 23 } | ForEach-Object { @($_.ServerAddresses) })
                    $dhcpV4 = @($ipInterfaces | Where-Object { [int]$_.InterfaceIndex -eq $index -and [string]$_.AddressFamily -eq 'IPv4' } | Select-Object -First 1)
                    $hasV6 = @($ipInterfaces | Where-Object { [int]$_.InterfaceIndex -eq $index -and [string]$_.AddressFamily -eq 'IPv6' }).Count -gt 0
                    $netProfile = @($profiles | Where-Object { [int]$_.InterfaceIndex -eq $index } | Select-Object -First 1)
                    $config = @($configs | Where-Object { [int]$_.InterfaceIndex -eq $index } | Select-Object -First 1)
                    $items += [pscustomobject]@{
                        InterfaceIndex       = $index
                        InterfaceGuid        = $guid
                        Name                 = [string]$adapter.Name
                        Description          = [string]$adapter.InterfaceDescription
                        Status               = [string]$adapter.Status
                        MacAddress           = [string]$adapter.MacAddress
                        LinkSpeed            = [string]$adapter.LinkSpeed
                        MediaType            = [string]$adapter.MediaType
                        Virtual              = [bool]$adapter.Virtual
                        Hardware             = [bool]$adapter.HardwareInterface
                        IPv4                 = $ipv4
                        IPv6                 = $ipv6
                        HasIPv6              = $hasV6
                        Gateways             = $gateways
                        DnsIPv4              = @($dnsV4 | ForEach-Object { [string]$_ })
                        DnsIPv6              = @($dnsV6 | ForEach-Object { [string]$_ })
                        DnsStaticIPv4        = @(& $readStatic 'Tcpip' $guid)
                        DnsStaticIPv6        = @(& $readStatic 'Tcpip6' $guid)
                        DhcpEnabled          = $(if ($dhcpV4.Count -gt 0) { [string]$dhcpV4[0].Dhcp -eq 'Enabled' } elseif ($config.Count -gt 0) { [bool]$config[0].DHCPEnabled } else { $false })
                        DhcpServer           = $(if ($config.Count -gt 0) { [string]$config[0].DHCPServer } else { '' })
                        LeaseObtained        = $(if ($config.Count -gt 0) { & $date $config[0].DHCPLeaseObtained } else { $null })
                        LeaseExpires         = $(if ($config.Count -gt 0) { & $date $config[0].DHCPLeaseExpires } else { $null })
                        ProfileName          = $(if ($netProfile.Count -gt 0) { [string]$netProfile[0].Name } else { '' })
                        NetworkCategory      = $(if ($netProfile.Count -gt 0) { [string]$netProfile[0].NetworkCategory } else { '' })
                        IPv4Connectivity     = $(if ($netProfile.Count -gt 0) { [string]$netProfile[0].IPv4Connectivity } else { '' })
                        IsConnectionAdapter  = $connectionIndex -contains $index
                    }
                }

                # Zmiany czekające na zatwierdzenie: zadania wycofania z wbudowanym stanem.
                $pending = @()
                $now = Get-Date
                foreach ($task in @(Get-ScheduledTask -TaskPath ([string]$request.TaskPath) -ErrorAction SilentlyContinue |
                            Where-Object { [string]$_.TaskName -like ([string]$request.TaskPrefix + '*') })) {
                    $state = $null
                    try {
                        $arguments = [string]@($task.Actions)[0].Arguments
                        if ($arguments -match '-EncodedCommand\s+([A-Za-z0-9+/=]+)') {
                            $text = [Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($Matches[1]))
                            if ($text -match "FromBase64String\('([A-Za-z0-9+/=]+)'\)") {
                                $state = ConvertFrom-Json -InputObject ([Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($Matches[1])))
                            }
                        }
                    }
                    catch {
                        $state = $null
                    }
                    $deadline = $null
                    try {
                        $deadline = [datetime]@($task.Triggers)[0].StartBoundary
                    }
                    catch {
                        $deadline = $null
                    }
                    $pending += [pscustomobject]@{
                        ChangeId         = ([string]$task.TaskName).Substring(([string]$request.TaskPrefix).Length)
                        TaskName         = [string]$task.TaskName
                        Description      = [string]$task.Description
                        State            = [string]$task.State
                        Kind             = $(if ($null -ne $state) { [string]$state.Kind } else { '' })
                        InterfaceIndex   = $(if ($null -ne $state) { [int]$state.InterfaceIndex } else { 0 })
                        Deadline         = $(if ($null -ne $deadline) { $deadline.ToString('o') } else { $null })
                        RemainingSeconds = $(if ($null -ne $deadline) { [int][Math]::Max(0, ($deadline - $now).TotalSeconds) } else { 0 })
                    }
                }

                $principal = New-Object -TypeName Security.Principal.WindowsPrincipal -ArgumentList ([Security.Principal.WindowsIdentity]::GetCurrent())
                ConvertTo-Json -Depth 5 -Compress -InputObject ([pscustomobject]@{
                        Kind                = 'MWP.NetworkStatusRaw'
                        ComputerName        = $env:COMPUTERNAME
                        CollectedAt         = (Get-Date).ToString('o')
                        IsAdministrator     = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
                        Adapters            = $items
                        Pending             = $pending
                        ConnectionAddresses = $connectionAddress
                        Warnings            = $warnings
                    })
            }
        }
        'Change' {
            {
                param([string] $RequestJson)
                $request = ConvertFrom-Json -InputObject $RequestJson
                $index = [int]$request.InterfaceIndex
                $errorText = $null
                $before = $null
                $after = $null
                $registered = $false
                $rolledBack = $false
                $deadline = $null
                $readStatic = {
                    param([string] $Guid)
                    $list = @()
                    foreach ($service in 'Tcpip', 'Tcpip6') {
                        $path = 'HKLM:\SYSTEM\CurrentControlSet\Services\{0}\Parameters\Interfaces\{1}' -f $service, $Guid
                        try {
                            $value = (Get-ItemProperty -LiteralPath $path -Name 'NameServer' -ErrorAction Stop).NameServer
                            $list += @(([string]$value) -split '[,\s]+' | Where-Object { $_ })
                        }
                        catch {
                            $list += @()
                        }
                    }
                    $list
                }
                $script = $null
                try {
                    $adapter = Get-NetAdapter -InterfaceIndex $index -ErrorAction Stop
                    $guid = [string]$adapter.InterfaceGuid
                    if ([string]$request.InterfaceGuid -and $guid.Trim('{}') -ne ([string]$request.InterfaceGuid).Trim('{}')) {
                        throw ('Adapter o indeksie {0} ma inny identyfikator ({1}) niż oczekiwany ({2}).' -f $index, $guid, $request.InterfaceGuid)
                    }
                    $kind = [string]$request.Kind
                    if ($kind -eq 'Dns') {
                        $before = [pscustomobject]@{ Servers = @(& $readStatic $guid); Status = [string]$adapter.Status }
                        $rollbackKind = 'Dns'
                    }
                    else {
                        $before = [pscustomobject]@{ Servers = @(); Status = [string]$adapter.Status }
                        $rollbackKind = $(if ($kind -eq 'AdapterDisable') { 'Enable' } else { '' })
                    }

                    # Zadanie wycofania (przed zmianą). Stan sprzed zmiany jest wbudowany w zadanie (Base64),
                    # więc nie ma pliku, który ktoś mógłby podmienić.
                    if ([int]$request.RollbackSeconds -gt 0 -and $rollbackKind) {
                        $state = [pscustomobject]@{
                            Kind            = $rollbackKind
                            InterfaceIndex  = $index
                            InterfaceGuid   = $guid
                            ServerAddresses = @($before.Servers)
                            TaskPath        = [string]$request.TaskPath
                            TaskName        = [string]$request.TaskName
                        }
                        $stateText = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes((ConvertTo-Json -Compress -InputObject $state)))
                        $script = ([string]$request.RollbackTemplate).Replace('__MWP_STATE__', $stateText)
                        $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($script))
                        $executable = Join-Path -Path $env:SystemRoot -ChildPath 'System32\WindowsPowerShell\v1.0\powershell.exe'
                        $deadline = (Get-Date).AddSeconds([int]$request.RollbackSeconds)
                        $action = New-ScheduledTaskAction -Execute $executable -Argument ('-NoProfile -NonInteractive -EncodedCommand ' + $encoded)
                        $trigger = New-ScheduledTaskTrigger -Once -At $deadline
                        $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
                        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 10)
                        $task = New-ScheduledTask -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description ([string]$request.Description)
                        $null = Register-ScheduledTask -TaskPath ([string]$request.TaskPath) -TaskName ([string]$request.TaskName) -InputObject $task -ErrorAction Stop
                        $registered = $true
                    }

                    try {
                        switch ($kind) {
                            'Dns' {
                                Set-DnsClientServerAddress -InterfaceIndex $index -ResetServerAddresses -ErrorAction Stop
                                $servers = @($request.ServerAddresses | Where-Object { $_ } | ForEach-Object { [string]$_ })
                                $families = @(Get-NetIPInterface -InterfaceIndex $index -ErrorAction SilentlyContinue | ForEach-Object { [string]$_.AddressFamily })
                                $servers = @($servers | Where-Object { $families -contains $(if ($_ -match ':') { 'IPv6' } else { 'IPv4' }) })
                                if ($servers.Count -gt 0) {
                                    Set-DnsClientServerAddress -InterfaceIndex $index -ServerAddresses $servers -ErrorAction Stop
                                }
                                Clear-DnsClientCache -ErrorAction SilentlyContinue
                                $after = [pscustomobject]@{ Servers = @(& $readStatic $guid); Status = [string]$adapter.Status }
                            }
                            'AdapterDisable' {
                                Disable-NetAdapter -InputObject $adapter -Confirm:$false -ErrorAction Stop
                                $after = [pscustomobject]@{ Servers = @(); Status = [string](Get-NetAdapter -InterfaceIndex $index -ErrorAction Stop).Status }
                            }
                            'AdapterEnable' {
                                Enable-NetAdapter -InputObject $adapter -Confirm:$false -ErrorAction Stop
                                $after = [pscustomobject]@{ Servers = @(); Status = [string](Get-NetAdapter -InterfaceIndex $index -ErrorAction Stop).Status }
                            }
                            default {
                                throw ('Nieznany rodzaj zmiany: {0}' -f $kind)
                            }
                        }
                    }
                    catch {
                        $errorText = $_.Exception.Message
                        if ($registered) {
                            # Błąd zmiany: od razu ten sam blok wycofania (przywraca stan i usuwa zadanie).
                            try {
                                & ([scriptblock]::Create($script))
                                $rolledBack = $true
                                $registered = $false
                            }
                            catch {
                                $errorText = '{0} Wycofanie nie powiodło się: {1}' -f $errorText, $_.Exception.Message
                            }
                        }
                    }
                }
                catch {
                    $errorText = $_.Exception.Message
                }
                $principalCheck = New-Object -TypeName Security.Principal.WindowsPrincipal -ArgumentList ([Security.Principal.WindowsIdentity]::GetCurrent())
                ConvertTo-Json -Depth 5 -Compress -InputObject ([pscustomobject]@{
                        Kind               = 'MWP.NetworkChangeRaw'
                        ComputerName       = $env:COMPUTERNAME
                        IsAdministrator    = $principalCheck.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
                        Before             = $before
                        After              = $after
                        RollbackRegistered = $registered
                        RolledBack         = $rolledBack
                        Deadline           = $(if ($registered -and $null -ne $deadline) { $deadline.ToString('o') } else { $null })
                        RemainingSeconds   = $(if ($registered -and $null -ne $deadline) { [int][Math]::Max(0, ($deadline - (Get-Date)).TotalSeconds) } else { 0 })
                        Error              = $errorText
                    })
            }
        }
        'Approve' {
            {
                param([string] $RequestJson)
                $request = ConvertFrom-Json -InputObject $RequestJson
                $found = $false
                $errorText = $null
                try {
                    $task = Get-ScheduledTask -TaskPath ([string]$request.TaskPath) -TaskName ([string]$request.TaskName) -ErrorAction SilentlyContinue
                    if ($null -ne $task) {
                        $found = $true
                        Unregister-ScheduledTask -TaskPath ([string]$request.TaskPath) -TaskName ([string]$request.TaskName) -Confirm:$false -ErrorAction Stop
                    }
                }
                catch {
                    $errorText = $_.Exception.Message
                }
                ConvertTo-Json -Compress -InputObject ([pscustomobject]@{
                        Kind         = 'MWP.NetworkApproveRaw'
                        ComputerName = $env:COMPUTERNAME
                        Found        = $found
                        Error        = $errorText
                    })
            }
        }
        'FlushDns' {
            {
                $errorText = $null
                try {
                    Clear-DnsClientCache -ErrorAction Stop
                }
                catch {
                    $errorText = $_.Exception.Message
                }
                ConvertTo-Json -Compress -InputObject ([pscustomobject]@{ Kind = 'MWP.NetworkFlushRaw'; ComputerName = $env:COMPUTERNAME; Error = $errorText })
            }
        }
        'RenewDhcp' {
            {
                param([string] $RequestJson)
                $request = ConvertFrom-Json -InputObject $RequestJson
                $index = [int]$request.InterfaceIndex
                $errorText = $null
                $code = $null
                $read = {
                    @(Get-NetIPAddress -InterfaceIndex $index -AddressFamily IPv4 -ErrorAction SilentlyContinue | ForEach-Object { '{0}/{1}' -f $_.IPAddress, $_.PrefixLength })
                }
                $before = @(& $read)
                $after = @()
                try {
                    $config = @(Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration -ErrorAction Stop | Where-Object { [int]$_.InterfaceIndex -eq $index }) | Select-Object -First 1
                    if ($null -eq $config) {
                        throw ('Brak konfiguracji IP adaptera o indeksie {0}.' -f $index)
                    }
                    if (-not $config.DHCPEnabled) {
                        throw 'Adapter nie używa DHCP (adres statyczny).'
                    }
                    $code = [long](Invoke-CimMethod -InputObject $config -MethodName RenewDHCPLease -ErrorAction Stop).ReturnValue
                    $after = @(& $read)
                }
                catch {
                    $errorText = $_.Exception.Message
                }
                ConvertTo-Json -Compress -InputObject ([pscustomobject]@{
                        Kind         = 'MWP.NetworkRenewRaw'
                        ComputerName = $env:COMPUTERNAME
                        ReturnValue  = $code
                        Before       = $before
                        After        = $after
                        Error        = $errorText
                    })
            }
        }
        'ResetStack' {
            {
                param([string] $Component, [string] $NetshPath)
                # Argumenty netsh są stałe dla składnika (D-015) i przekazywane jako tablica; ścieżka netsh
                # to stała modułu (Get-MwpNetworkTargetConfig) ze zmienną %SystemRoot% komputera docelowego.
                $arguments = switch ($Component) {
                    'Winsock' { @('winsock', 'reset') }
                    'IP' { @('int', 'ip', 'reset') }
                    default { $null }
                }
                $lines = @()
                $exitCode = $null
                $errorText = $null
                if ($null -eq $arguments) {
                    $errorText = 'Nieznany składnik: ' + $Component
                }
                else {
                    try {
                        $netsh = [Environment]::ExpandEnvironmentVariables($NetshPath)
                        $lines = @(& $netsh @arguments 2>&1 | ForEach-Object { [string]$_ } | Where-Object { $_.Trim() })
                        $exitCode = $LASTEXITCODE
                    }
                    catch {
                        $errorText = $_.Exception.Message
                    }
                }
                ConvertTo-Json -Compress -InputObject ([pscustomobject]@{
                        Kind         = 'MWP.NetworkResetRaw'
                        ComputerName = $env:COMPUTERNAME
                        Component    = $Component
                        ExitCode     = $exitCode
                        Lines        = $lines
                        Error        = $errorText
                    })
            }
        }
        'Test' {
            {
                param([string] $RequestJson)
                $request = ConvertFrom-Json -InputObject $RequestJson
                $timeout = [int]$request.TimeoutMs
                $tests = @()
                $ping = {
                    param([string] $Name, [string] $Target)
                    $watch = [Diagnostics.Stopwatch]::StartNew()
                    $pinger = New-Object -TypeName Net.NetworkInformation.Ping
                    try {
                        $reply = $pinger.Send($Target, $timeout)
                        $ok = [string]$reply.Status -eq 'Success'
                        $detail = if ($ok) { 'odpowiedź {0} ms ({1})' -f $reply.RoundtripTime, $reply.Address } else { 'brak odpowiedzi ({0})' -f $reply.Status }
                    }
                    catch {
                        $ok = $false
                        $detail = $(if ($null -ne $_.Exception.InnerException) { $_.Exception.InnerException.Message } else { $_.Exception.Message })
                    }
                    finally {
                        $pinger.Dispose()
                    }
                    [pscustomobject]@{ Name = $Name; Target = $Target; Success = $ok; Detail = $detail; DurationMs = [int]$watch.ElapsedMilliseconds }
                }

                $gateway = @(Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue | Where-Object { $_.NextHop -and [string]$_.NextHop -ne '0.0.0.0' } |
                        Sort-Object -Property RouteMetric | Select-Object -First 1)
                if ($gateway.Count -gt 0) {
                    $tests += & $ping 'Gateway' ([string]$gateway[0].NextHop)
                }
                else {
                    $tests += [pscustomobject]@{ Name = 'Gateway'; Target = ''; Success = $false; Detail = 'brak bramy domyślnej IPv4'; DurationMs = 0 }
                }
                if ([string]$request.ExternalHost) {
                    $tests += & $ping 'External' ([string]$request.ExternalHost)
                }
                if ([string]$request.DnsName) {
                    $watch = [Diagnostics.Stopwatch]::StartNew()
                    try {
                        $records = @(Resolve-DnsName -Name ([string]$request.DnsName) -DnsOnly -QuickTimeout -ErrorAction Stop | Where-Object { $_.PSObject.Properties['IPAddress'] -and $_.IPAddress })
                        $found = @($records | ForEach-Object { [string]$_.IPAddress } | Select-Object -Unique)
                        $tests += [pscustomobject]@{ Name = 'Dns'; Target = [string]$request.DnsName; Success = $found.Count -gt 0; Detail = $(if ($found.Count -gt 0) { $found -join ', ' } else { 'brak adresów w odpowiedzi' }); DurationMs = [int]$watch.ElapsedMilliseconds }
                    }
                    catch {
                        $tests += [pscustomobject]@{ Name = 'Dns'; Target = [string]$request.DnsName; Success = $false; Detail = $_.Exception.Message; DurationMs = [int]$watch.ElapsedMilliseconds }
                    }
                }
                if ([string]$request.PortHost -and [int]$request.Port -gt 0) {
                    $target = '{0}:{1}' -f $request.PortHost, $request.Port
                    $watch = [Diagnostics.Stopwatch]::StartNew()
                    $client = New-Object -TypeName Net.Sockets.TcpClient
                    try {
                        $connect = $client.ConnectAsync([string]$request.PortHost, [int]$request.Port)
                        $done = $connect.Wait($timeout)
                        $ok = $done -and $client.Connected
                        $detail = if ($ok) { 'port otwarty' } elseif ($done) { 'połączenie odrzucone' } else { 'brak odpowiedzi w limicie czasu' }
                    }
                    catch {
                        $ok = $false
                        $inner = $_.Exception
                        while ($null -ne $inner.InnerException) { $inner = $inner.InnerException }
                        $detail = $inner.Message
                    }
                    finally {
                        $client.Dispose()
                    }
                    $tests += [pscustomobject]@{ Name = 'Port'; Target = $target; Success = $ok; Detail = $detail; DurationMs = [int]$watch.ElapsedMilliseconds }
                }
                ConvertTo-Json -Depth 4 -Compress -InputObject ([pscustomobject]@{
                        Kind         = 'MWP.NetworkTestRaw'
                        ComputerName = $env:COMPUTERNAME
                        CollectedAt  = (Get-Date).ToString('o')
                        Tests        = $tests
                    })
            }
        }
    }
}
