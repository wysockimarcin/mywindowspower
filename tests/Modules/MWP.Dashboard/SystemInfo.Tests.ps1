#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
    Testy modułu MWP.Dashboard (FAZA 5): blok odczytu informacji o systemie z mockami CIM
    (Get-CimInstance, rejestr), odporność na braki danych (brak baterii, błąd klasy CIM), Get-MwpSystemInfo
    dla localhost i komputera zdalnego (mock Invoke-MwpOnTarget / Start-MwpOperation), widok widgetu,
    raport JSON i tekst oraz eksport do pliku na TestDrive. System bez zmian.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Zmienne z bloków BeforeDiscovery/BeforeAll są używane w blokach It (zakresy Pestera).')]
param()

Describe 'MWP.Dashboard — informacje o systemie' {
    BeforeAll {
        $root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
        foreach ($name in 'MWP.Core', 'MWP.Remote', 'MWP.Dashboard') {
            Import-Module -Name (Join-Path -Path $root -ChildPath "src\Modules\$name\$name.psd1") -Force
        }
        $configDirectory = Join-Path -Path $TestDrive -ChildPath 'config'
        $null = New-Item -ItemType Directory -Path $configDirectory -Force
        Copy-Item -LiteralPath (Join-Path -Path $root -ChildPath 'config\settings.example.json') -Destination (Join-Path -Path $configDirectory -ChildPath 'settings.example.json')
        Mock -ModuleName MWP.Core Get-MwpDataPath {
            $path = Join-Path -Path $TestDrive -ChildPath $Kind
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

        # Wykonuje blok odczytu w zakresie modułu (tam działają mocki CIM) i zwraca obiekt z tekstu JSON.
        function Invoke-TestBlock {
            param([string[]] $Sections = @())
            $json = InModuleScope MWP.Dashboard -Parameters @{ Sections = $Sections } {
                param($Sections)
                $block = Get-MwpSystemInfoScript
                & $block $Sections
            }
            $json | ConvertFrom-Json
        }
        function Use-CimMock {
            param([switch] $NoBattery, [string] $FailClass)
            $script:CimState = @{ NoBattery = [bool]$NoBattery; FailClass = $FailClass }
            Mock -ModuleName MWP.Dashboard Get-ItemProperty { [pscustomobject]@{ DisplayVersion = '26H2'; UBR = 9711 } }
            Mock -ModuleName MWP.Dashboard Get-CimInstance {
                if ($ClassName -eq $script:CimState.FailClass) {
                    throw "Klasa $ClassName niedostępna"
                }
                switch ($ClassName) {
                    'Win32_OperatingSystem' {
                        [pscustomobject]@{
                            Caption = 'Microsoft Windows 11 Pro'; Version = '10.0.26300'; BuildNumber = '26300'; OSArchitecture = '64-bit'
                            InstallDate = [datetime]'2024-12-09 08:24:01'; LastBootUpTime = (Get-Date).AddHours(-50); TotalVisibleMemorySize = 16777216; FreePhysicalMemory = 4194304
                        }
                    }
                    'Win32_ComputerSystem' { [pscustomobject]@{ Name = 'PC-LOKALNY'; Manufacturer = 'Dell Inc.'; Model = 'Precision 3530'; Domain = 'WORKGROUP'; PartOfDomain = $false } }
                    'Win32_Processor' { [pscustomobject]@{ Name = '  Intel Core i5  '; Manufacturer = 'GenuineIntel'; NumberOfCores = 4; NumberOfLogicalProcessors = 8; MaxClockSpeed = 2300; LoadPercentage = 12 } }
                    'Win32_PhysicalMemory' {
                        [pscustomobject]@{ Capacity = 8GB; Speed = 2667 }
                        [pscustomobject]@{ Capacity = 8GB; Speed = 2667 }
                    }
                    'Win32_VideoController' { [pscustomobject]@{ Name = 'NVIDIA Quadro P600'; DriverVersion = '31.0'; AdapterRAM = 2GB; CurrentHorizontalResolution = 1920; CurrentVerticalResolution = 1080 } }
                    'MSFT_PhysicalDisk' { [pscustomobject]@{ DeviceId = '0'; FriendlyName = 'NVMe SSD'; MediaType = 4; BusType = 17; Size = 1TB; HealthStatus = 0 } }
                    'MSFT_Partition' { [pscustomobject]@{ DriveLetter = 'C'; DiskNumber = 0 } }
                    'Win32_LogicalDisk' {
                        [pscustomobject]@{ DeviceID = 'C:'; VolumeName = 'System'; FileSystem = 'NTFS'; Size = 100GB; FreeSpace = 9GB }
                        [pscustomobject]@{ DeviceID = 'D:'; VolumeName = ''; FileSystem = 'NTFS'; Size = 100GB; FreeSpace = 50GB }
                    }
                    'Win32_BaseBoard' { [pscustomobject]@{ Manufacturer = 'Dell Inc.'; Product = '0YM64G' } }
                    'Win32_BIOS' { [pscustomobject]@{ Manufacturer = 'Dell Inc.'; SMBIOSBIOSVersion = '1.39.0'; ReleaseDate = [datetime]'2025-04-07' } }
                    'Win32_Battery' {
                        if (-not $script:CimState.NoBattery) {
                            [pscustomobject]@{ Name = 'Bateria 1'; EstimatedChargeRemaining = 15; BatteryStatus = 1; EstimatedRunTime = 95 }
                        }
                    }
                    'Win32_NetworkAdapter' { [pscustomobject]@{ Index = 3; NetConnectionID = 'Wi-Fi'; Speed = 866000000 } }
                    'Win32_NetworkAdapterConfiguration' {
                        [pscustomobject]@{
                            Index = 3; Description = 'Intel Wireless'; MACAddress = 'AA-BB'; IPAddress = @('192.168.1.10', 'fe80::1'); DefaultIPGateway = @('192.168.1.1')
                            DNSServerSearchOrder = @('192.168.1.1'); DHCPEnabled = $true
                        }
                    }
                }
            }
        }
    }

    AfterAll {
        Remove-Module -Name MWP.Dashboard, MWP.Remote, MWP.Core -Force -ErrorAction SilentlyContinue
    }

    Context 'blok odczytu (CIM)' {
        It 'odczytuje wszystkie sekcje: system, uptime, CPU, RAM, GPU, dyski z typem, płyta i BIOS, bateria, sieć' {
            Use-CimMock

            $info = Invoke-TestBlock

            $info.Kind | Should -Be 'MWP.SystemInfo'
            $info.ComputerName | Should -Be 'PC-LOKALNY'
            $info.System.Caption | Should -Be 'Microsoft Windows 11 Pro'
            $info.System.DisplayVersion | Should -Be '26H2'
            $info.System.Ubr | Should -Be 9711
            $info.System.InstallDate | Should -Be '2024-12-09 08:24:01'
            $info.System.UptimeSeconds | Should -BeGreaterOrEqual (50 * 3600 - 5)
            $info.Cpu.LoadPercent | Should -Be 12
            $info.Cpu.Processors[0].Name | Should -Be 'Intel Core i5'
            $info.Memory.TotalBytes | Should -Be 16GB
            $info.Memory.UsedPercent | Should -Be 75
            $info.Memory.InstalledBytes | Should -Be 16GB
            $info.Memory.ModuleCount | Should -Be 2
            $info.Gpu[0].Resolution | Should -Be '1920 x 1080'
            @($info.Disks.Volumes).Count | Should -Be 2
            $info.Disks.Volumes[0].UsedPercent | Should -Be 91
            $info.Disks.Volumes[0].MediaType | Should -Be 'SSD NVMe'
            $info.Disks.Volumes[1].MediaType | Should -BeNullOrEmpty -Because 'wolumin bez partycji w MSFT_Partition nie ma typu'
            $info.Disks.PhysicalDisks[0].Health | Should -Be 'Sprawny'
            $info.Board.BiosVersion | Should -Be '1.39.0'
            $info.Board.BiosReleaseDate | Should -Be '2025-04-07'
            $info.Battery.Present | Should -BeTrue
            $info.Battery.Batteries[0].Status | Should -Be 'Rozładowywanie'
            $info.Battery.Batteries[0].RunTimeMinutes | Should -Be 95
            @($info.Network[0].IPv4) | Should -Be @('192.168.1.10')
            @($info.Network[0].IPv6) | Should -Be @('fe80::1')
            $info.Network[0].Name | Should -Be 'Wi-Fi'
            @($info.Warnings).Count | Should -Be 0
        }

        It 'brak baterii to Present = $false i pusta lista, bez ostrzeżeń' {
            Use-CimMock -NoBattery

            $info = Invoke-TestBlock -Sections @('Battery')

            $info.Battery.Present | Should -BeFalse
            @($info.Battery.Batteries).Count | Should -Be 0
            @($info.Warnings).Count | Should -Be 0
        }

        It 'błąd jednej klasy CIM trafia do Warnings, a pozostałe sekcje są odczytane' {
            Use-CimMock -FailClass 'Win32_VideoController'

            $info = Invoke-TestBlock

            @($info.Warnings) -join ' ' | Should -Match '^Gpu: Klasa Win32_VideoController niedostępna'
            @($info.Gpu).Count | Should -Be 0
            $info.Memory.UsedPercent | Should -Be 75
            $info.System.Caption | Should -Not -BeNullOrEmpty
        }

        It 'brak systemu operacyjnego (błąd Win32_OperatingSystem) nie przerywa odczytu' {
            Use-CimMock -FailClass 'Win32_OperatingSystem'

            $info = Invoke-TestBlock -Sections @('System', 'Memory')

            $info.System.Caption | Should -BeNullOrEmpty
            $info.Memory.TotalBytes | Should -BeNullOrEmpty
            @($info.Warnings) -join ' ' | Should -Match 'System:'
        }

        It 'odczytuje tylko wybrane sekcje i nie pyta o klasy pozostałych' {
            Use-CimMock

            $info = Invoke-TestBlock -Sections @('Cpu')

            @($info.Sections) | Should -Be @('Cpu')
            $info.Cpu | Should -Not -BeNullOrEmpty
            $info.System | Should -BeNullOrEmpty
            $info.Disks | Should -BeNullOrEmpty
            Should -Invoke -ModuleName MWP.Dashboard Get-CimInstance -Times 0 -Exactly -ParameterFilter { $ClassName -eq 'Win32_LogicalDisk' }
        }

        It 'blok jest samowystarczalny: bez funkcji MWP i bez poleceń zmieniających system (D-036)' {
            $text = InModuleScope MWP.Dashboard { (Get-MwpSystemInfoScript).ToString() }
            $ast = [Management.Automation.Language.Parser]::ParseInput($text, [ref]$null, [ref]$null)
            $commands = @($ast.FindAll({ param($node) $node -is [Management.Automation.Language.CommandAst] }, $true) | ForEach-Object { $_.GetCommandName() } | Where-Object { $_ } | Sort-Object -Unique)

            @($commands | Where-Object { $_ -match '-Mwp' }) | Should -BeNullOrEmpty
            @($commands | Where-Object { $_ -notmatch '^(Get-|ConvertTo-Json|New-Object|Where-Object|ForEach-Object|Select-Object|Sort-Object|Measure-Object)' }) | Should -BeNullOrEmpty
            $text | Should -Not -Match 'Get-WmiObject'
        }
    }

    Context 'Get-MwpSystemInfo' {
        It 'localhost: wykonuje blok przez Invoke-MwpOnTarget i zwraca obiekt w Data' {
            Use-CimMock
            $script:TestJson = InModuleScope MWP.Dashboard { & (Get-MwpSystemInfoScript) @() }
            Mock -ModuleName MWP.Dashboard Invoke-MwpOnTarget { New-MwpResult -Success $true -Operation $Operation -ComputerName $Context.ComputerName -Message 'ok' -Data @($script:TestJson) }

            $result = Get-MwpSystemInfo -Context (New-MwpExecutionContext)

            $result.Success | Should -BeTrue
            $result.Operation | Should -Be 'Dashboard.SystemInfo'
            $result.Data.Kind | Should -Be 'MWP.SystemInfo'
            $result.Data.Memory.UsedPercent | Should -Be 75
        }

        It 'komputer zdalny: ten sam blok w kontekście komputera zdalnego, sekcje z parametrów widgetu' {
            Mock -ModuleName MWP.Dashboard Invoke-MwpOnTarget {
                New-MwpResult -Success $true -ComputerName $Context.ComputerName -Data @('{"Kind":"MWP.SystemInfo","ComputerName":"PC-TEST1","Sections":["Cpu"]}')
            }
            $context = New-MwpExecutionContext -ComputerName $remoteName

            $result = Get-MwpSystemInfo -Context $context -WidgetParameters @{ Sections = @('Cpu', 'Nieznana') }

            $result.Data.ComputerName | Should -Be 'PC-TEST1'
            $result.ComputerName | Should -Be $remoteName
            Should -Invoke -ModuleName MWP.Dashboard Invoke-MwpOnTarget -Times 1 -Exactly -ParameterFilter {
                $Context.ComputerName -eq $remoteName -and $Operation -eq 'Dashboard.SystemInfo' -and (@($ArgumentList[0]) -join ',') -eq 'Cpu'
            }
        }

        It 'błąd połączenia zwraca wynik z błędem (bez wyjątku)' {
            Mock -ModuleName MWP.Dashboard Invoke-MwpOnTarget { New-MwpResult -Success $false -ComputerName $Context.ComputerName -Message 'Komputer niedostępny.' }

            $result = Get-MwpSystemInfo -Context (New-MwpExecutionContext -ComputerName $remoteName)

            $result.Success | Should -BeFalse
            $result.Message | Should -Be 'Komputer niedostępny.'
        }

        It 'puste dane z komputera dają wynik z błędem' {
            Mock -ModuleName MWP.Dashboard Invoke-MwpOnTarget { New-MwpResult -Success $true -Data @() }

            (Get-MwpSystemInfo -Context (New-MwpExecutionContext)).Success | Should -BeFalse
        }

        It '-AsOperation startuje operację w tle z sekcjami jako argumentem' {
            Mock -ModuleName MWP.Dashboard Invoke-MwpOnTarget { }
            Mock -ModuleName MWP.Dashboard Start-MwpOperation { [pscustomobject]@{ PSTypeName = 'MWP.Operation'; Operation = $Operation; Arguments = $ArgumentList } }

            $operation = Get-MwpSystemInfo -Context (New-MwpExecutionContext) -Section Memory, Disks -AsOperation

            $operation.Operation | Should -Be 'Dashboard.SystemInfo'
            @($operation.Arguments[0]) | Should -Be @('Memory', 'Disks')
            Should -Invoke -ModuleName MWP.Dashboard Invoke-MwpOnTarget -Times 0 -Exactly
        }

        It 'na localhost odczytuje prawdziwe dane w tle (tylko odczyt)' {
            $operation = Get-MwpSystemInfo -Context (New-MwpExecutionContext) -Section System, Memory -AsOperation
            $result = Wait-MwpOperation -Operation $operation

            $result.Success | Should -BeTrue -Because $result.Message
            $view = ConvertTo-MwpSystemInfoView -Data $result.Data
            @($view.Sections | ForEach-Object { $_.Title }) | Should -Be @('System', 'Pamięć RAM')
            $view.Summary | Should -Match ([regex]::Escape($env:COMPUTERNAME))
        }
    }

    Context 'widok widgetu i raport' {
        BeforeAll {
            Use-CimMock
            $info = Invoke-TestBlock
            $json = InModuleScope MWP.Dashboard { & (Get-MwpSystemInfoScript) @() }
        }

        It 'widok ma sekcje z wierszami, pasek dla procentów i ton według progów' {
            $view = ConvertTo-MwpSystemInfoView -Data $json

            $view.PSObject.TypeNames | Should -Contain 'MWP.WidgetView'
            @($view.Sections | ForEach-Object { $_.Title }) | Should -Be @('System', 'Procesor', 'Pamięć RAM', 'Grafika', 'Dyski', 'Płyta główna i BIOS', 'Bateria', 'Sieć')
            $disks = @($view.Sections | Where-Object { $_.Title -eq 'Dyski' })[0].Items
            $disks[0].Label | Should -Be 'Dysk C: (System)'
            $disks[0].Tone | Should -Be 'Danger'
            $disks[0].Percent | Should -Be 91
            $disks[1].Tone | Should -Be 'Success'
            $memory = @($view.Sections | Where-Object { $_.Title -eq 'Pamięć RAM' })[0].Items[0]
            $memory.Value | Should -Be '12,0 GB z 16,0 GB (75%)'
            $memory.Tone | Should -Be 'Success'
            $system = @($view.Sections | Where-Object { $_.Title -eq 'System' })[0].Items
            ($system | Where-Object { $_.Label -eq 'Kompilacja' }).Value | Should -Be '26300.9711'
            ($system | Where-Object { $_.Label -eq 'Czas pracy' }).Value | Should -Match '^2 d 2 h'
            ($system | Where-Object { $_.Label -eq 'Czas pracy' }).Percent | Should -Be -1
            $battery = @($view.Sections | Where-Object { $_.Title -eq 'Bateria' })[0].Items[0]
            $battery.Tone | Should -Be 'Warning'
        }

        It 'parametr Sections ogranicza widok; obiekt, tekst JSON i MWP.Result dają ten sam widok' {
            $byObject = ConvertTo-MwpSystemInfoView -Data $info -WidgetParameters @{ Sections = @('Disks', 'Cpu') }
            $byResult = ConvertTo-MwpSystemInfoView -Data (New-MwpResult -Success $true -Data @($json)) -WidgetParameters @{ Sections = @('Disks', 'Cpu') }

            @($byObject.Sections | ForEach-Object { $_.Title }) | Should -Be @('Procesor', 'Dyski')
            @($byResult.Sections | ForEach-Object { $_.Title }) | Should -Be @('Procesor', 'Dyski')
        }

        It 'brak danych daje $null (widget: brak danych), braki pól — „brak danych” i „brak baterii”' {
            ConvertTo-MwpSystemInfoView -Data $null | Should -BeNullOrEmpty
            ConvertTo-MwpSystemInfoView -Data 'to nie jest JSON' | Should -BeNullOrEmpty
            Use-CimMock -NoBattery -FailClass 'Win32_VideoController'
            $partial = Invoke-TestBlock

            $view = ConvertTo-MwpSystemInfoView -Data $partial

            @($view.Sections | Where-Object { $_.Title -eq 'Bateria' })[0].Items[0].Value | Should -Be 'brak baterii'
            @($view.Sections | Where-Object { $_.Title -eq 'Grafika' })[0].Items[0].Value | Should -Be 'brak danych'
            @($view.Warnings).Count | Should -Be 1
        }

        It 'raport JSON zawiera metadane i wszystkie dane; raport tekstowy — sekcje' {
            $report = ConvertTo-MwpSystemReport -Data $info -Format Json | ConvertFrom-Json
            $text = ConvertTo-MwpSystemReport -Data $info -Format Text

            $report.Report.Application | Should -Be 'MyWindowsPower'
            $report.Report.ComputerName | Should -Be 'PC-LOKALNY'
            $report.SystemInfo.Disks.Volumes[0].Drive | Should -Be 'C:'
            $text | Should -Match 'Komputer: PC-LOKALNY'
            $text | Should -Match '== Dyski =='
            $text | Should -Match 'Dysk C: \(System\): wolne 9,0 GB z 100,0 GB'
            { ConvertTo-MwpSystemReport -Data $null } | Should -Throw
        }

        It 'eksport zapisuje JSON (UTF-8 bez BOM) i tekst (UTF-8 z BOM); format z rozszerzenia' {
            Mock -ModuleName MWP.Dashboard Write-MwpLog { }
            $jsonPath = Join-Path -Path $TestDrive -ChildPath 'raporty\raport.json'
            $textPath = Join-Path -Path $TestDrive -ChildPath 'raporty\raport.txt'

            $jsonResult = Export-MwpSystemReport -Data $info -Path $jsonPath -Confirm:$false
            $textResult = Export-MwpSystemReport -Data $info -Path $textPath -Confirm:$false

            $jsonResult.Success | Should -BeTrue
            $jsonResult.Data.Format | Should -Be 'Json'
            $textResult.Data.Format | Should -Be 'Text'
            [IO.File]::ReadAllBytes($jsonPath)[0] | Should -Be ([byte][char]'{')
            @([IO.File]::ReadAllBytes($textPath)[0..2]) | Should -Be @(0xEF, 0xBB, 0xBF)
            ([IO.File]::ReadAllText($jsonPath) | ConvertFrom-Json).SystemInfo.ComputerName | Should -Be 'PC-LOKALNY'
            Should -Invoke -ModuleName MWP.Dashboard Write-MwpLog -Times 2 -Exactly -ParameterFilter { $Operation -eq 'Dashboard.Export' }
        }

        It 'eksport z -WhatIf i bez danych niczego nie zapisuje' {
            $path = Join-Path -Path $TestDrive -ChildPath 'raporty\podglad.txt'

            (Export-MwpSystemReport -Data $info -Path $path -WhatIf).IsPreview | Should -BeTrue
            (Export-MwpSystemReport -Data $null -Path $path -Confirm:$false).Success | Should -BeFalse
            $path | Should -Not -Exist
        }
    }
}
