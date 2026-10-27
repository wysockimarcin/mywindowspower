function Get-MwpSystemInfoScript {
    <#
    .SYNOPSIS
        Zwraca blok skryptu, który odczytuje informacje o systemie i sprzęcie na komputerze docelowym.

    .DESCRIPTION
        Blok jest samowystarczalny i zgodny z Windows PowerShell 5.1 (D-036): wykonuje go
        Invoke-MwpOnTarget albo Start-MwpOperation lokalnie lub na komputerze zdalnym, bez modułów MWP.
        Odczyt wyłącznie przez CIM (Get-CimInstance) i rejestr (DisplayVersion, UBR); nic nie zmienia.
        Każda sekcja jest czytana osobno: błąd jednej (np. brak klasy, brak uprawnień) trafia do
        Warnings i nie przerywa pozostałych; brak danych (np. brak baterii) to pusta lista albo $null.
        Wynik jest zwracany jako tekst JSON, bo serializacja WinRM spłaszcza obiekty zagnieżdżone
        głębiej niż dwa poziomy; daty jako tekst 'yyyy-MM-dd HH:mm:ss' (ConvertFrom-Json w 7.x
        nie zamienia ich na DateTime, D-025).
        Parametr bloku: Sections — lista sekcji (System, Cpu, Memory, Gpu, Disks, Board, Battery,
        Network); pusta = wszystkie.
    #>
    [CmdletBinding()]
    [OutputType([scriptblock])]
    param()

    {
        param([string[]] $Sections)

        $all = @('System', 'Cpu', 'Memory', 'Gpu', 'Disks', 'Board', 'Battery', 'Network')
        if ($null -eq $Sections -or @($Sections).Count -eq 0) {
            $Sections = $all
        }
        $warnings = New-Object -TypeName System.Collections.Generic.List[string]
        $read = {
            param([string] $Name, [scriptblock] $Code)
            try {
                & $Code
            }
            catch {
                $warnings.Add(('{0}: {1}' -f $Name, $_.Exception.Message))
            }
        }
        $date = {
            param($Value)
            if ($Value -is [datetime]) {
                $Value.ToString('yyyy-MM-dd HH:mm:ss')
            }
        }
        $percent = {
            param($Used, $Total)
            if ($null -ne $Total -and [double]$Total -gt 0) {
                [math]::Round(100 * [double]$Used / [double]$Total, 1)
            }
        }
        $want = {
            param([string] $Name)
            $Sections -contains $Name
        }

        $os = $null
        if ((& $want 'System') -or (& $want 'Memory')) {
            $os = & $read 'System' { Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop }
        }
        $computer = & $read 'ComputerSystem' { Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop }

        $system = $null
        if (& $want 'System') {
            $version = & $read 'Registry' { Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction Stop }
            $uptime = $null
            if ($null -ne $os -and $os.LastBootUpTime -is [datetime]) {
                $uptime = [int64]((Get-Date) - $os.LastBootUpTime).TotalSeconds
            }
            $system = [ordered]@{
                Caption        = $(if ($null -ne $os) { [string]$os.Caption } else { $null })
                Version        = $(if ($null -ne $os) { [string]$os.Version } else { $null })
                BuildNumber    = $(if ($null -ne $os) { [string]$os.BuildNumber } else { $null })
                DisplayVersion = $(if ($null -ne $version -and $null -ne $version.PSObject.Properties['DisplayVersion']) { [string]$version.DisplayVersion } else { $null })
                Ubr            = $(if ($null -ne $version -and $null -ne $version.PSObject.Properties['UBR']) { [int]$version.UBR } else { $null })
                Architecture   = $(if ($null -ne $os) { [string]$os.OSArchitecture } else { $null })
                InstallDate    = $(if ($null -ne $os) { & $date $os.InstallDate } else { $null })
                LastBootUpTime = $(if ($null -ne $os) { & $date $os.LastBootUpTime } else { $null })
                UptimeSeconds  = $uptime
                Manufacturer   = $(if ($null -ne $computer) { [string]$computer.Manufacturer } else { $null })
                Model          = $(if ($null -ne $computer) { [string]$computer.Model } else { $null })
                Domain         = $(if ($null -ne $computer) { [string]$computer.Domain } else { $null })
                PartOfDomain   = $(if ($null -ne $computer) { [bool]$computer.PartOfDomain } else { $null })
            }
        }

        $cpu = $null
        if (& $want 'Cpu') {
            $processors = @(& $read 'Cpu' { Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop })
            $loads = @($processors | Where-Object { $null -ne $_.LoadPercentage } | ForEach-Object { [double]$_.LoadPercentage })
            $cpu = [ordered]@{
                LoadPercent = $(if ($loads.Count -gt 0) { [math]::Round(($loads | Measure-Object -Average).Average, 0) } else { $null })
                Processors  = @(foreach ($processor in $processors) {
                        [ordered]@{
                            Name              = ([string]$processor.Name).Trim()
                            Manufacturer      = [string]$processor.Manufacturer
                            Cores             = $processor.NumberOfCores
                            LogicalProcessors = $processor.NumberOfLogicalProcessors
                            MaxClockMHz       = $processor.MaxClockSpeed
                        }
                    })
            }
        }

        $memory = $null
        if (& $want 'Memory') {
            $modules = @(& $read 'MemoryModules' { Get-CimInstance -ClassName Win32_PhysicalMemory -ErrorAction Stop })
            $total = $null
            $free = $null
            if ($null -ne $os -and $null -ne $os.TotalVisibleMemorySize) {
                $total = [int64]$os.TotalVisibleMemorySize * 1024
                $free = [int64]$os.FreePhysicalMemory * 1024
            }
            $installed = $null
            if ($modules.Count -gt 0) {
                $installed = [int64](($modules | Measure-Object -Property Capacity -Sum).Sum)
            }
            $memory = [ordered]@{
                TotalBytes     = $total
                FreeBytes      = $free
                UsedBytes      = $(if ($null -ne $total) { $total - $free } else { $null })
                UsedPercent    = $(if ($null -ne $total) { & $percent ($total - $free) $total } else { $null })
                InstalledBytes = $installed
                ModuleCount    = $modules.Count
                SpeedMHz       = $modules | Where-Object { $_.Speed } | ForEach-Object { [int]$_.Speed } | Sort-Object -Descending | Select-Object -First 1
            }
        }

        $gpu = $null
        if (& $want 'Gpu') {
            $gpu = @(foreach ($controller in @(& $read 'Gpu' { Get-CimInstance -ClassName Win32_VideoController -ErrorAction Stop })) {
                    $resolution = $null
                    if ($controller.CurrentHorizontalResolution -and $controller.CurrentVerticalResolution) {
                        $resolution = '{0} x {1}' -f $controller.CurrentHorizontalResolution, $controller.CurrentVerticalResolution
                    }
                    [ordered]@{
                        Name          = [string]$controller.Name
                        DriverVersion = [string]$controller.DriverVersion
                        # AdapterRAM to UInt32: dla kart z pamięcią > 4 GB wartość jest zaniżona.
                        AdapterRamBytes = $(if ($null -ne $controller.AdapterRAM) { [int64]$controller.AdapterRAM } else { $null })
                        Resolution    = $resolution
                    }
                })
        }

        $disks = $null
        if (& $want 'Disks') {
            $mediaNames = @{ 0 = 'Nieokreślony'; 3 = 'HDD'; 4 = 'SSD'; 5 = 'SCM' }
            $busNames = @{ 1 = 'SCSI'; 3 = 'ATA'; 6 = 'Fibre Channel'; 7 = 'USB'; 8 = 'RAID'; 9 = 'iSCSI'; 10 = 'SAS'; 11 = 'SATA'; 12 = 'SD'; 13 = 'MMC'; 15 = 'Plik wirtualny'; 16 = 'Storage Spaces'; 17 = 'NVMe' }
            $healthNames = @{ 0 = 'Sprawny'; 1 = 'Ostrzeżenie'; 2 = 'Niesprawny'; 5 = 'Nieznany' }
            $storage = 'root/Microsoft/Windows/Storage'
            $physical = @(& $read 'PhysicalDisks' { Get-CimInstance -Namespace $storage -ClassName MSFT_PhysicalDisk -ErrorAction Stop })
            $partitions = @(& $read 'Partitions' { Get-CimInstance -Namespace $storage -ClassName MSFT_Partition -ErrorAction Stop })
            $describe = {
                param($Disk)
                $media = $mediaNames[[int]$Disk.MediaType]
                $bus = $busNames[[int]$Disk.BusType]
                if ($bus -eq 'NVMe') { 'SSD NVMe' } elseif ($media -and $media -ne 'Nieokreślony') { $media } elseif ($bus) { $bus } else { 'Nieznany' }
            }
            $disks = [ordered]@{
                Volumes       = @(foreach ($volume in @(& $read 'Volumes' { Get-CimInstance -ClassName Win32_LogicalDisk -Filter 'DriveType=3' -ErrorAction Stop })) {
                        $letter = ([string]$volume.DeviceID).TrimEnd(':')
                        $type = $null
                        $partition = @($partitions | Where-Object { [string]$_.DriveLetter -eq $letter }) | Select-Object -First 1
                        if ($null -ne $partition) {
                            $disk = @($physical | Where-Object { [string]$_.DeviceId -eq [string]$partition.DiskNumber }) | Select-Object -First 1
                            if ($null -ne $disk) {
                                $type = & $describe $disk
                            }
                        }
                        $size = $(if ($null -ne $volume.Size) { [int64]$volume.Size } else { $null })
                        $freeSpace = $(if ($null -ne $volume.FreeSpace) { [int64]$volume.FreeSpace } else { $null })
                        [ordered]@{
                            Drive       = [string]$volume.DeviceID
                            Label       = [string]$volume.VolumeName
                            FileSystem  = [string]$volume.FileSystem
                            SizeBytes   = $size
                            FreeBytes   = $freeSpace
                            UsedPercent = $(if ($null -ne $size -and $null -ne $freeSpace) { & $percent ($size - $freeSpace) $size } else { $null })
                            MediaType   = $type
                        }
                    })
                PhysicalDisks = @(foreach ($disk in $physical) {
                        [ordered]@{
                            Name      = [string]$disk.FriendlyName
                            MediaType = & $describe $disk
                            BusType   = $busNames[[int]$disk.BusType]
                            SizeBytes = $(if ($null -ne $disk.Size) { [int64]$disk.Size } else { $null })
                            Health    = $healthNames[[int]$disk.HealthStatus]
                        }
                    })
            }
        }

        $board = $null
        if (& $want 'Board') {
            $baseBoard = & $read 'Board' { Get-CimInstance -ClassName Win32_BaseBoard -ErrorAction Stop } | Select-Object -First 1
            $bios = & $read 'Bios' { Get-CimInstance -ClassName Win32_BIOS -ErrorAction Stop } | Select-Object -First 1
            $board = [ordered]@{
                Manufacturer    = $(if ($null -ne $baseBoard) { [string]$baseBoard.Manufacturer } else { $null })
                Product         = $(if ($null -ne $baseBoard) { [string]$baseBoard.Product } else { $null })
                BiosVendor      = $(if ($null -ne $bios) { [string]$bios.Manufacturer } else { $null })
                BiosVersion     = $(if ($null -ne $bios) { [string]$bios.SMBIOSBIOSVersion } else { $null })
                BiosReleaseDate = $(if ($null -ne $bios -and $bios.ReleaseDate -is [datetime]) { $bios.ReleaseDate.ToString('yyyy-MM-dd') } else { $null })
            }
        }

        $battery = $null
        if (& $want 'Battery') {
            $statusNames = @{ 1 = 'Rozładowywanie'; 2 = 'Zasilanie sieciowe'; 3 = 'Naładowana'; 4 = 'Niski poziom'; 5 = 'Krytyczny poziom'; 6 = 'Ładowanie'; 7 = 'Ładowanie (wysoki poziom)'; 8 = 'Ładowanie (niski poziom)'; 9 = 'Ładowanie (krytyczny poziom)'; 10 = 'Nieokreślony'; 11 = 'Częściowo naładowana' }
            $items = @(& $read 'Battery' { Get-CimInstance -ClassName Win32_Battery -ErrorAction Stop })
            $battery = [ordered]@{
                Present   = $items.Count -gt 0
                Batteries = @(foreach ($item in $items) {
                        $runtime = $item.EstimatedRunTime
                        [ordered]@{
                            Name             = [string]$item.Name
                            ChargePercent    = $item.EstimatedChargeRemaining
                            Status           = $statusNames[[int]$item.BatteryStatus]
                            # 71582788 min oznacza zasilanie sieciowe (brak szacunku).
                            RunTimeMinutes   = $(if ($null -ne $runtime -and $runtime -lt 71582788) { [int]$runtime } else { $null })
                        }
                    })
            }
        }

        $network = $null
        if (& $want 'Network') {
            $adapters = @(& $read 'NetworkAdapters' { Get-CimInstance -ClassName Win32_NetworkAdapter -ErrorAction Stop })
            $network = @(foreach ($config in @(& $read 'Network' { Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration -Filter 'IPEnabled=True' -ErrorAction Stop })) {
                    $adapter = @($adapters | Where-Object { $_.Index -eq $config.Index }) | Select-Object -First 1
                    $addresses = @($config.IPAddress | Where-Object { $_ })
                    [ordered]@{
                        Name        = $(if ($null -ne $adapter -and $adapter.NetConnectionID) { [string]$adapter.NetConnectionID } else { [string]$config.Description })
                        Description = [string]$config.Description
                        MacAddress  = [string]$config.MACAddress
                        IPv4        = @($addresses | Where-Object { $_ -match '^\d+\.\d+\.\d+\.\d+$' })
                        IPv6        = @($addresses | Where-Object { $_ -match ':' })
                        Gateway     = @($config.DefaultIPGateway | Where-Object { $_ })
                        Dns         = @($config.DNSServerSearchOrder | Where-Object { $_ })
                        Dhcp        = [bool]$config.DHCPEnabled
                        SpeedBps    = $(if ($null -ne $adapter -and $null -ne $adapter.Speed) { [int64]$adapter.Speed } else { $null })
                    }
                })
        }

        $result = [ordered]@{
            Kind          = 'MWP.SystemInfo'
            SchemaVersion = 1
            ComputerName  = $(if ($null -ne $computer -and $computer.Name) { [string]$computer.Name } else { $env:COMPUTERNAME })
            CollectedAt   = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
            Sections      = @($Sections)
            System        = $system
            Cpu           = $cpu
            Memory        = $memory
            Gpu           = $gpu
            Disks         = $disks
            Board         = $board
            Battery       = $battery
            Network       = $network
            Warnings      = @($warnings)
        }
        ConvertTo-Json -InputObject $result -Depth 8 -Compress
    }
}
