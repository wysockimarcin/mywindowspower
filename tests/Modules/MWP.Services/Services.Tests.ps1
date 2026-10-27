#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
    Testy modułu MWP.Services (FAZA 7) z symulatorem usług: mocki Get-CimInstance (Win32_Service,
    Win32_DependentService) i Get-Service (kontroler z Start/Stop/WaitForStatus) w zakresie MWP.Remote
    (tam Invoke-MwpOnTarget wykonuje bloki), a dla bezpieczeństwa także w MWP.Services i w zakresie
    pliku. sc.exe zastępuje globalna funkcja-symulator o tej samej nazwie (funkcja ma pierwszeństwo
    przed programem; Pester w 5.1 nie umie zamockować sc.exe, bo tworzy też alias „sc”, a ten jest
    w 5.1 wbudowanym aliasem Set-Content tylko do odczytu); funkcja jest usuwana po testach.
    Usługi mają fikcyjne nazwy (MwpTest*), więc nawet ominięcie symulatora nie zmieni prawdziwej
    usługi. Sprawdzają: listę i filtry, start/stop/restart z usługami zależnymi, typ
    uruchomienia z opóźnionym startem, listę ochronną (wbudowaną i lokalną), -WhatIf (polecenie
    zmieniające nie zostało wywołane), log, wpis cofnięcia i cofnięcie, profil usług, widget,
    komputer zdalny (mock transportu WinRM) i błąd połączenia.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Zmienne z bloków BeforeDiscovery/BeforeAll są używane w blokach It (zakresy Pestera).')]
param()

Describe 'MWP.Services — usługi Windows' {
    BeforeAll {
        $root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
        foreach ($name in 'MWP.Core', 'MWP.Remote', 'MWP.Services') {
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
        # Lokalne rozszerzenie listy ochronnej (D-045): chroni fikcyjną usługę MwpTestGuard.
        $protectedLocal = Join-Path -Path $configDirectory -ChildPath 'protected.local.json'
        Set-Content -LiteralPath $protectedLocal -Encoding UTF8 -Value '{ "schemaVersion": 1, "items": [ { "category": "Service", "name": "MwpTestGuard", "reason": "Usługa testowa chroniona lokalnie." } ] }'

        # Stan symulatora: usługi (stan, typ, opóźniony start), zależności (usługa → wymagana), błędy.
        function Initialize-FakeService {
            $services = [ordered]@{}
            foreach ($line in @(
                    'MwpTestBase|Running|Auto|0|Baza testowa'
                    'MwpTestMid|Running|Manual|0|Środek testowy'
                    'MwpTestTop|Running|Manual|0|Szczyt testowy'
                    'MwpTestOff|Stopped|Manual|0|Zatrzymana zależna'
                    'MwpTestNet|Running|Auto|0|Sieć testowa'
                    'MwpTestGuard|Running|Auto|0|Strażnik testowy'
                    'MwpTestDelayed|Stopped|Auto|1|Opóźniona testowa'
                    'MwpTestDisabled|Stopped|Disabled|0|Wyłączona testowa'
                    'MwpTest(R) Paren|Running|Manual|0|Z nawiasem'
                    'MwpTestUser_1a|Stopped|Unknown|0|Szablon użytkownika'
                    'WinRM|Running|Manual|0|Zdalne zarządzanie'
                )) {
                $item = $line.Split('|')
                $services[$item[0]] = @{ State = $item[1]; StartMode = $item[2]; Delayed = $item[3] -eq '1'; DisplayName = $item[4]; AcceptStop = $true }
            }
            $script:Fake = @{
                Services        = $services
                Links           = @(
                    @('MwpTestMid', 'MwpTestBase'), @('MwpTestOff', 'MwpTestBase'), @('MwpTestTop', 'MwpTestMid'),
                    @('MwpTestGuard', 'MwpTestNet'), @('WinRM', 'MwpTestNet')
                )
                Admin           = $true
                FailStop        = @()
                FailStart       = @()
                ScExit          = 0
                ScKeepsDelayed  = $false
            }
            $script:Calls = New-Object -TypeName System.Collections.Generic.List[string]
            # Wspólny kontener dla symulatora sc.exe (domknięcie): ten sam obiekt przez cały plik.
            $script:Simulator.Fake = $script:Fake
            $script:Simulator.Calls = $script:Calls
        }
        $script:Simulator = @{}
        Initialize-FakeService

        $fakeCim = {
            if ($ClassName -eq 'Win32_DependentService') {
                foreach ($link in $script:Fake.Links) {
                    [pscustomobject]@{ Dependent = [pscustomobject]@{ Name = $link[0] }; Antecedent = [pscustomobject]@{ Name = $link[1] } }
                }
                return
            }
            foreach ($name in $script:Fake.Services.Keys) {
                $service = $script:Fake.Services[$name]
                [pscustomobject]@{
                    Name             = $name
                    DisplayName      = $service.DisplayName
                    State            = $service.State
                    StartMode        = $service.StartMode
                    DelayedAutoStart = $service.Delayed
                    StartName        = 'LocalSystem'
                    PathName         = 'C:\Test\{0}.exe' -f $name
                    Description      = 'Opis usługi {0}' -f $service.DisplayName
                    ProcessId        = $(if ($service.State -eq 'Running') { 100 } else { 0 })
                    AcceptStop       = $service.State -eq 'Running' -and $service.AcceptStop
                    ServiceType      = 'Own Process'
                }
            }
        }
        $fakeGetService = {
            $serviceName = [string]@($Name)[0]
            if (-not $script:Fake.Services.Contains($serviceName)) {
                throw ("Nie można odnaleźć usługi '{0}'." -f $serviceName)
            }
            $controller = [pscustomobject]@{ Name = $serviceName }
            $controller | Add-Member -MemberType ScriptProperty -Name Status -Value { $script:Fake.Services[$this.Name].State }
            $controller | Add-Member -MemberType ScriptMethod -Name Stop -Value {
                $script:Calls.Add('Stop ' + $this.Name)
                if ($script:Fake.FailStop -contains $this.Name) { throw 'Usługa nie odpowiedziała na żądanie zatrzymania.' }
                $script:Fake.Services[$this.Name].State = 'Stopped'
            }
            $controller | Add-Member -MemberType ScriptMethod -Name Start -Value {
                $script:Calls.Add('Start ' + $this.Name)
                if ($script:Fake.FailStart -contains $this.Name) { throw 'Usługa nie uruchomiła się.' }
                $script:Fake.Services[$this.Name].State = 'Running'
            }
            $controller | Add-Member -MemberType ScriptMethod -Name WaitForStatus -Value { }
            $controller
        }
        $simulator = $script:Simulator
        $fakeSc = {
            $a = @($args | ForEach-Object { [string]$_ })
            $fake = $simulator.Fake
            $simulator.Calls.Add('sc ' + ($a -join ' '))
            Set-Variable -Name LASTEXITCODE -Scope Global -Value 0
            if ($fake.ScExit -ne 0) {
                Set-Variable -Name LASTEXITCODE -Scope Global -Value $fake.ScExit
                return '[SC] OpenService FAILED: odmowa dostępu.'
            }
            if ($a[0] -ne 'config' -or $a[2] -ne 'start=' -or -not $fake.Services.Contains($a[1])) {
                Set-Variable -Name LASTEXITCODE -Scope Global -Value 1060
                return '[SC] OpenService FAILED 1060.'
            }
            $service = $fake.Services[$a[1]]
            switch ($a[3]) {
                'auto' { $service.StartMode = 'Auto'; if (-not $fake.ScKeepsDelayed) { $service.Delayed = $false } }
                'delayed-auto' { $service.StartMode = 'Auto'; $service.Delayed = $true }
                'demand' { $service.StartMode = 'Manual'; $service.Delayed = $false }
                'disabled' { $service.StartMode = 'Disabled'; $service.Delayed = $false }
                default { Set-Variable -Name LASTEXITCODE -Scope Global -Value 87; return 'Invalid' }
            }
            '[SC] ChangeServiceConfig SUCCESS'
        }.GetNewClosure()
        Set-Item -Path 'Function:\global:sc.exe' -Value $fakeSc
        foreach ($scope in 'MWP.Remote', 'MWP.Services') {
            Mock -ModuleName $scope Get-CimInstance -ParameterFilter { $ClassName -in @('Win32_Service', 'Win32_DependentService') } $fakeCim
            Mock -ModuleName $scope Get-Service $fakeGetService
        }
        Mock Get-CimInstance -ParameterFilter { $ClassName -in @('Win32_Service', 'Win32_DependentService') } $fakeCim
        Mock Get-Service $fakeGetService
        Mock -ModuleName MWP.Services Test-MwpAdmin { $script:Fake.Admin }

        $context = New-MwpExecutionContext
        function Get-Call {
            param([string] $Prefix)
            @($script:Calls | Where-Object { $_ -like "$Prefix*" })
        }
        function Get-Log {
            Get-ChildItem -LiteralPath (Join-Path -Path $TestDrive -ChildPath 'Logs') -Filter '*.log' | Get-Content -Raw -Encoding UTF8
        }
    }

    AfterAll {
        # Ścieżka bez „global:” — Remove-Item z kwalifikatorem zakresu niczego nie usuwa (sprawdzone w 5.1 i 7.6.7).
        Remove-Item -Path 'Function:\sc.exe' -ErrorAction SilentlyContinue
        Remove-Module -Name MWP.Services, MWP.Remote, MWP.Core -Force -ErrorAction SilentlyContinue
    }

    BeforeEach {
        Initialize-FakeService
    }

    Context 'lista usług i filtry' {
        It 'zwraca stan, typ uruchomienia (z opóźnionym startem), zależności i listę ochronną' {
            $result = Get-MwpService -Context $context -IncludeDependencies
            $result.Success | Should -BeTrue -Because $result.Message
            $list = $result.Data
            $list.PSObject.TypeNames | Should -Contain 'MWP.ServiceList'
            $list.HasGraph | Should -BeTrue
            $services = @{}
            foreach ($item in $list.Services) { $services[$item.Name] = $item }
            $services['MwpTestDelayed'].StartupType | Should -Be 'AutomaticDelayedStart'
            $services['MwpTestDelayed'].StartupTypeText | Should -Be 'Automatyczny (opóźniony start)'
            $services['MwpTestBase'].StatusText | Should -Be 'Działa'
            $services['MwpTestUser_1a'].StartupType | Should -Be 'Unknown'
            @($services['MwpTestBase'].Dependents) | Should -Be @('MwpTestMid', 'MwpTestOff')
            @($services['MwpTestTop'].DependsOn) | Should -Be @('MwpTestMid')
            $services['WinRM'].IsProtected | Should -BeTrue
            $services['MwpTestGuard'].IsProtected | Should -BeTrue
            $services['MwpTestGuard'].ProtectionReason | Should -Match 'lokalnie'
            $services['MwpTestBase'].IsProtected | Should -BeFalse
        }

        It 'filtry: stan, typ, tekst, tylko chronione, nazwy' {
            @((Get-MwpService -Context $context -Status Stopped -StartupType AnyAutomatic).Data.Services.Name) | Should -Be @('MwpTestDelayed')
            @((Get-MwpService -Context $context -Search 'strażnik').Data.Services.Name) | Should -Be @('MwpTestGuard')
            @((Get-MwpService -Context $context -ProtectedOnly).Data.Services.Name | Sort-Object) | Should -Be @('MwpTestGuard', 'WinRM')
            @((Get-MwpService -Context $context -Name 'MwpTestBase', 'MwpTest(R) Paren').Data.Services).Count | Should -Be 2
            (Get-MwpService -Context $context -StartupType Disabled).Message | Should -Match 'po filtrach: 1'
            @((Get-MwpService -Context $context).Data.Dependencies).Count | Should -Be 0
        }

        It 'nazwy usług są walidowane przed użyciem w poleceniach' {
            foreach ($valid in 'Spooler', 'MSSQL$SQLEXPRESS', 'Intel(R) TPM Provisioning Service', 'CDPUserSvc_1a2b3', 'a.b-c@d#e+{f}') {
                Test-MwpServiceName -Name $valid | Should -BeTrue -Because $valid
            }
            foreach ($invalid in 'Spo*', 'Spo?ler', '[a]', 'a"b', "a'b", '..\x', 'a/b', 'a=b', ' lead', 'trail ', '', ('x' * 257), "a`nb") {
                Test-MwpServiceName -Name $invalid | Should -BeFalse -Because $invalid
            }
            { Stop-MwpService -Name 'Mwp*' -Context $context -WhatIf } | Should -Throw
            { Get-MwpService -Name 'a"b' -Context $context } | Should -Throw
        }

        It 'błąd odczytu Win32_Service: wynik z błędem, bez wyjątku' {
            Mock -ModuleName MWP.Remote Get-CimInstance -ParameterFilter { $ClassName -eq 'Win32_Service' } { throw 'Usługa WMI niedostępna.' }
            $result = Get-MwpService -Context $context
            $result.Success | Should -BeFalse
            $result.Message | Should -Match 'WMI niedostępna'
        }

        It '-AsOperation startuje operację w tle z blokiem List, a Resolve-MwpServiceList parsuje surowy wynik' {
            Mock -ModuleName MWP.Services Start-MwpOperation { [pscustomobject]@{ PSTypeName = 'MWP.Operation'; Operation = $Operation; Arguments = $ArgumentList } }
            $operation = Get-MwpService -Context $context -AsOperation -IncludeDependencies
            $operation.Operation | Should -Be 'Services.List'
            $json = InModuleScope MWP.Remote -Parameters @{ Request = [string]$operation.Arguments[0] } {
                param($Request)
                $text = (& (Get-Module -Name MWP.Services) { Get-MwpServiceScript -Name List }).ToString()
                & ((Get-Module -Name MWP.Remote).NewBoundScriptBlock([scriptblock]::Create($text))) $Request
            }
            $list = Resolve-MwpServiceList -Data $json
            @($list.Services).Count | Should -Be 11
            $list.HasGraph | Should -BeTrue
            Resolve-MwpServiceList -Data $null | Should -BeNullOrEmpty
        }
    }

    Context 'uruchamianie' {
        It '-WhatIf: podgląd z nazwą komputera, bez uruchamiania' {
            $result = Start-MwpService -Name MwpTestDelayed -Context $context -WhatIf
            $result.IsPreview | Should -BeTrue -Because $result.Message
            $result.Changed | Should -BeFalse
            Get-Call 'Start' | Should -BeNullOrEmpty
        }

        It 'uruchamia, loguje i cofa (Invoke-MwpUndo zatrzymuje)' {
            $result = Start-MwpService -Name MwpTestDelayed -Context $context -Confirm:$false
            $result.Success | Should -BeTrue -Because $result.Message
            $result.Changed | Should -BeTrue
            $script:Fake.Services['MwpTestDelayed'].State | Should -Be 'Running'
            Get-Log | Should -Match '"operation":"Services.Start"'
            $undo = Invoke-MwpUndo -Id $result.UndoId -Context $context -Confirm:$false
            $undo.Success | Should -BeTrue -Because $undo.Message
            $script:Fake.Services['MwpTestDelayed'].State | Should -Be 'Stopped'
        }

        It 'usługa wyłączona: odmowa; działająca: bez zmian; nieistniejąca: błąd' {
            (Start-MwpService -Name MwpTestDisabled -Context $context -Confirm:$false).Message | Should -Match 'wyłączona'
            (Start-MwpService -Name MwpTestBase -Context $context -Confirm:$false).Changed | Should -BeFalse
            (Start-MwpService -Name MwpTestBrak -Context $context -Confirm:$false).Success | Should -BeFalse
            Get-Call 'Start' | Should -BeNullOrEmpty
        }

        It 'bez uprawnień administratora: odmowa przed zmianą' {
            $script:Fake.Admin = $false
            $result = Start-MwpService -Name MwpTestDelayed -Context $context -Confirm:$false
            $result.Success | Should -BeFalse
            $result.Message | Should -Match 'administratora'
            Get-Call 'Start' | Should -BeNullOrEmpty
        }

        It 'usługa chroniona: uruchomienie dozwolone, ale bez wpisu cofnięcia' {
            $script:Fake.Services['MwpTestGuard'].State = 'Stopped'
            $result = Start-MwpService -Name MwpTestGuard -Context $context -Confirm:$false
            $result.Success | Should -BeTrue -Because $result.Message
            $result.UndoId | Should -BeNullOrEmpty
            $result.Message | Should -Match 'chroniona'
        }
    }

    Context 'zatrzymywanie i ponowne uruchamianie z usługami zależnymi' {
        It '-WhatIf: podgląd wymienia działające usługi zależne, nic nie zatrzymuje' {
            $result = Stop-MwpService -Name MwpTestBase -Context $context -WhatIf
            $result.IsPreview | Should -BeTrue -Because $result.Message
            $result.Message | Should -Match 'MwpTestTop, MwpTestMid'
            $result.Message | Should -Not -Match 'MwpTestOff'
            Get-Call 'Stop' | Should -BeNullOrEmpty
        }

        It 'zatrzymuje najpierw zależne (od najdalszej), a cofnięcie uruchamia je w odwrotnej kolejności' {
            $result = Stop-MwpService -Name MwpTestBase -Context $context -Confirm:$false
            $result.Success | Should -BeTrue -Because $result.Message
            @(Get-Call 'Stop') | Should -Be @('Stop MwpTestTop', 'Stop MwpTestMid', 'Stop MwpTestBase')
            $script:Fake.Services['MwpTestBase'].State | Should -Be 'Stopped'
            $entry = Get-MwpUndoEntry -Id $result.UndoId
            $entry.UndoCommand | Should -Be 'Start-MwpService'

            $script:Calls.Clear()
            $undo = Invoke-MwpUndo -Id $result.UndoId -Context $context -Confirm:$false
            $undo.Success | Should -BeTrue -Because $undo.Message
            @(Get-Call 'Start') | Should -Be @('Start MwpTestBase', 'Start MwpTestMid', 'Start MwpTestTop')
            $script:Fake.Services['MwpTestOff'].State | Should -Be 'Stopped'
        }

        It 'lista ochronna: odmowa zatrzymania usługi chronionej i usługi, od której zależy działająca usługa chroniona' {
            $winrm = Stop-MwpService -Name WinRM -Context $context -Confirm:$false
            $winrm.Success | Should -BeFalse
            $winrm.Message | Should -Match 'liście ochronnej'
            $net = Stop-MwpService -Name MwpTestNet -Context $context -Confirm:$false
            $net.Success | Should -BeFalse
            $net.Message | Should -Match 'chroniona'
            (Restart-MwpService -Name MwpTestGuard -Context $context -Confirm:$false).Message | Should -Match 'liście ochronnej'
            Get-Call 'Stop' | Should -BeNullOrEmpty
        }

        It 'błąd w trakcie: zatrzymane usługi zależne wracają, bez wpisu cofnięcia' {
            $script:Fake.FailStop = @('MwpTestBase')
            $result = Stop-MwpService -Name MwpTestBase -Context $context -Confirm:$false
            $result.Success | Should -BeFalse
            $result.UndoId | Should -BeNullOrEmpty
            $result.Message | Should -Match 'Ponownie uruchomiono: MwpTestMid, MwpTestTop'
            $script:Fake.Services['MwpTestTop'].State | Should -Be 'Running'
            $script:Fake.Services['MwpTestMid'].State | Should -Be 'Running'
            Get-Log | Should -Match '"level":"Error"'
        }

        It 'zatrzymana usługa: bez zmian; usługa nieprzyjmująca zatrzymania: odmowa' {
            (Stop-MwpService -Name MwpTestOff -Context $context -Confirm:$false).Changed | Should -BeFalse
            $script:Fake.Services['MwpTest(R) Paren'].AcceptStop = $false
            (Stop-MwpService -Name 'MwpTest(R) Paren' -Context $context -Confirm:$false).Message | Should -Match 'nie przyjmuje'
            Get-Call 'Stop' | Should -BeNullOrEmpty
        }

        It 'restart: zatrzymanie i uruchomienie z zależnymi, bez wpisu cofnięcia; usługa zatrzymana — błąd' {
            (Restart-MwpService -Name MwpTestMid -Context $context -WhatIf).IsPreview | Should -BeTrue
            Get-Call 'Stop' | Should -BeNullOrEmpty
            $result = Restart-MwpService -Name MwpTestMid -Context $context -Confirm:$false
            $result.Success | Should -BeTrue -Because $result.Message
            $result.UndoId | Should -BeNullOrEmpty
            @($script:Calls) | Should -Be @('Stop MwpTestTop', 'Stop MwpTestMid', 'Start MwpTestMid', 'Start MwpTestTop')
            (Restart-MwpService -Name MwpTestOff -Context $context -Confirm:$false).Success | Should -BeFalse
        }

        It 'bez uprawnień administratora: odmowa zatrzymania przed zmianą' {
            $script:Fake.Admin = $false
            (Stop-MwpService -Name MwpTestTop -Context $context -WhatIf).Message | Should -Match 'administratora'
            Get-Call 'Stop' | Should -BeNullOrEmpty
        }
    }

    Context 'typ uruchomienia' {
        It '-WhatIf: podgląd bez sc.exe' {
            $result = Set-MwpServiceStartupType -Name MwpTestBase -StartupType Manual -Context $context -WhatIf
            $result.IsPreview | Should -BeTrue -Because $result.Message
            $result.Before | Should -Be 'Automatyczny'
            $result.After | Should -Be 'Ręczny'
            Get-Call 'sc' | Should -BeNullOrEmpty
        }

        It 'ustawia opóźniony start (argumenty sc.exe jako tablica), loguje i cofa' {
            $result = Set-MwpServiceStartupType -Name MwpTestBase -StartupType AutomaticDelayedStart -Context $context -Confirm:$false
            $result.Success | Should -BeTrue -Because $result.Message
            @(Get-Call 'sc') | Should -Be @('sc config MwpTestBase start= delayed-auto')
            $script:Fake.Services['MwpTestBase'].Delayed | Should -BeTrue
            Get-Log | Should -Match '"operation":"Services.SetStartupType"'
            (Invoke-MwpUndo -Id $result.UndoId -Context $context -Confirm:$false).Success | Should -BeTrue
            $script:Fake.Services['MwpTestBase'].Delayed | Should -BeFalse
            $script:Fake.Services['MwpTestBase'].StartMode | Should -Be 'Auto'
        }

        It 'każdy typ trafia do sc.exe właściwym trybem' -ForEach @(
            @{ Type = 'Automatic'; Mode = 'auto'; Service = 'MwpTestOff' }
            @{ Type = 'Manual'; Mode = 'demand'; Service = 'MwpTestBase' }
            @{ Type = 'Disabled'; Mode = 'disabled'; Service = 'MwpTestTop' }
        ) {
            (Set-MwpServiceStartupType -Name $Service -StartupType $Type -Context $context -Confirm:$false).Success | Should -BeTrue
            @(Get-Call 'sc') | Should -Be @("sc config $Service start= $Mode")
        }

        It 'lista ochronna: tylko typ automatyczny; nie można wyłączyć usługi, od której zależy usługa chroniona' {
            (Set-MwpServiceStartupType -Name WinRM -StartupType Disabled -Context $context -Confirm:$false).Message | Should -Match 'liście ochronnej'
            (Set-MwpServiceStartupType -Name MwpTestGuard -StartupType Manual -Context $context -Confirm:$false).Success | Should -BeFalse
            (Set-MwpServiceStartupType -Name MwpTestNet -StartupType Disabled -Context $context -Confirm:$false).Message | Should -Match 'zależy od niej usługa chroniona'
            Get-Call 'sc' | Should -BeNullOrEmpty
            (Set-MwpServiceStartupType -Name WinRM -StartupType Automatic -Context $context -Confirm:$false).Success | Should -BeTrue
            (Set-MwpServiceStartupType -Name MwpTestNet -StartupType Manual -Context $context -Confirm:$false).Success | Should -BeTrue
        }

        It 'wyłączenie działającej usługi: uwaga w podglądzie o zależnych i o tym, że nie zostanie zatrzymana' {
            $message = (Set-MwpServiceStartupType -Name MwpTestBase -StartupType Disabled -Context $context -WhatIf).Message
            $message | Should -Match 'MwpTestMid'
            $message | Should -Match 'nie zatrzymuje'
        }

        It 'błąd sc.exe (odmowa dostępu): wynik z błędem i bez wpisu cofnięcia' {
            $script:Fake.ScExit = 5
            $result = Set-MwpServiceStartupType -Name MwpTestBase -StartupType Manual -Context $context -Confirm:$false
            $result.Success | Should -BeFalse
            $result.Message | Should -Match 'odmowa dostępu'
            $result.UndoId | Should -BeNullOrEmpty
        }

        It 'typ po zmianie różny od oczekiwanego: błąd, ale wpis cofnięcia dla faktycznej zmiany' {
            $script:Fake.Services['MwpTestDelayed'].State = 'Stopped'
            $script:Fake.ScKeepsDelayed = $true
            $result = Set-MwpServiceStartupType -Name MwpTestDelayed -StartupType Automatic -Context $context -Confirm:$false
            $result.Success | Should -BeFalse
            $result.Message | Should -Match 'zamiast'
            $result.UndoId | Should -BeNullOrEmpty

            $script:Fake.Services['MwpTestDelayed'].StartMode = 'Manual'
            $script:Fake.Services['MwpTestDelayed'].Delayed = $true
            $partial = Set-MwpServiceStartupType -Name MwpTestDelayed -StartupType Automatic -Context $context -Confirm:$false
            $partial.Success | Should -BeFalse
            $partial.UndoId | Should -Not -BeNullOrEmpty
        }

        It 'nieznany typ (usługa szablonowa) i ten sam typ: bez sc.exe' {
            (Set-MwpServiceStartupType -Name MwpTestUser_1a -StartupType Manual -Context $context -Confirm:$false).Message | Should -Match 'nieznany'
            (Set-MwpServiceStartupType -Name MwpTestBase -StartupType Automatic -Context $context -Confirm:$false).Changed | Should -BeFalse
            Get-Call 'sc' | Should -BeNullOrEmpty
        }
    }

    Context 'profil usług' {
        BeforeAll {
            $profilePath = Join-Path -Path $TestDrive -ChildPath 'profil\uslugi.json'
        }

        It 'eksport: JSON bez BOM z typami i stanami (bez typów nieznanych); -WhatIf nic nie zapisuje' {
            (Export-MwpServiceProfile -Path $profilePath -Context $context -WhatIf).IsPreview | Should -BeTrue
            Test-Path -LiteralPath $profilePath | Should -BeFalse
            $result = Export-MwpServiceProfile -Path $profilePath -Context $context -Confirm:$false
            $result.Success | Should -BeTrue -Because $result.Message
            $bytes = [IO.File]::ReadAllBytes($profilePath)
            $bytes[0] | Should -Not -Be 0xEF
            $data = Get-Content -LiteralPath $profilePath -Raw -Encoding UTF8 | ConvertFrom-Json
            $data.kind | Should -Be 'MWP.ServiceProfile'
            @($data.services).Count | Should -Be 10
            ($data.services | Where-Object name -eq 'MwpTestDelayed').startupType | Should -Be 'AutomaticDelayedStart'
            ($data.services | Where-Object name -eq 'MwpTestBase').status | Should -Be 'Running'
        }

        It 'wczytanie: niepoprawne pozycje są pomijane z ostrzeżeniem; zły rodzaj i wersja to błąd' {
            $bad = Join-Path -Path $TestDrive -ChildPath 'zly.json'
            Set-Content -LiteralPath $bad -Encoding UTF8 -Value '{ "kind": "MWP.ServiceProfile", "schemaVersion": 1, "services": [ { "name": "Ok", "startupType": "Manual" }, { "name": "Zł*", "startupType": "Manual" }, { "name": "Inny", "startupType": "Boot" }, { "name": "ok", "startupType": "Disabled" } ] }'
            $read = Read-MwpServiceProfile -Path $bad
            $read.Success | Should -BeTrue
            @($read.Data.Services).Count | Should -Be 1
            @($read.Data.Warnings).Count | Should -Be 3
            Set-Content -LiteralPath $bad -Encoding UTF8 -Value '{ "kind": "Inny", "schemaVersion": 1 }'
            (Read-MwpServiceProfile -Path $bad).Success | Should -BeFalse
            Set-Content -LiteralPath $bad -Encoding UTF8 -Value '{ "kind": "MWP.ServiceProfile", "schemaVersion": 2 }'
            (Read-MwpServiceProfile -Path $bad).Message | Should -Match 'wersja'
            (Read-MwpServiceProfile -Path (Join-Path -Path $TestDrive -ChildPath 'brak.json')).Success | Should -BeFalse
        }

        It 'porównanie: zmiany, bez zmian, chronione i brakujące' {
            $null = Export-MwpServiceProfile -Path $profilePath -Context $context -Confirm:$false
            $data = Get-Content -LiteralPath $profilePath -Raw -Encoding UTF8 | ConvertFrom-Json
            ($data.services | Where-Object name -eq 'MwpTestBase').startupType = 'Manual'
            ($data.services | Where-Object name -eq 'WinRM').startupType = 'Disabled'
            $data.services += [pscustomobject]@{ name = 'MwpTestBrak'; displayName = 'Brak'; startupType = 'Manual'; status = 'Stopped' }
            [IO.File]::WriteAllText($profilePath, (ConvertTo-Json -InputObject $data -Depth 5))
            $compare = Compare-MwpServiceProfile -ProfileData (Read-MwpServiceProfile -Path $profilePath) -Context $context
            $compare.Success | Should -BeTrue -Because $compare.Message
            $rows = @($compare.Data)
            $rows[0].Name | Should -Be 'MwpTestBase'
            $rows[0].Action | Should -Be 'Change'
            ($rows | Where-Object Name -eq 'WinRM').Action | Should -Be 'Protected'
            ($rows | Where-Object Name -eq 'MwpTestBrak').Action | Should -Be 'Missing'
            @($rows | Where-Object Action -eq 'Same').Count | Should -Be 8
            Get-Call 'sc' | Should -BeNullOrEmpty
        }

        It 'import: -WhatIf bez zmian; potem zmienia tylko różnice (z cofnięciem każdej), pomija chronione' {
            $null = Export-MwpServiceProfile -Path $profilePath -Context $context -Confirm:$false
            $script:Fake.Services['MwpTestBase'].StartMode = 'Disabled'
            $script:Fake.Services['MwpTestOff'].StartMode = 'Auto'
            $script:Fake.Services['WinRM'].StartMode = 'Auto'
            $preview = Import-MwpServiceProfile -Path $profilePath -Context $context -WhatIf
            $preview.IsPreview | Should -BeTrue
            @($preview.Data).Count | Should -Be 2
            Get-Call 'sc' | Should -BeNullOrEmpty

            $result = Import-MwpServiceProfile -Path $profilePath -Context $context -Confirm:$false
            $result.Success | Should -BeTrue -Because $result.Message
            @($result.Data).Count | Should -Be 2
            @($result.Data | Where-Object { $_.UndoId }).Count | Should -Be 2
            $script:Fake.Services['MwpTestBase'].StartMode | Should -Be 'Auto'
            $script:Fake.Services['MwpTestOff'].StartMode | Should -Be 'Manual'
            $script:Fake.Services['WinRM'].StartMode | Should -Be 'Auto'
            (Import-MwpServiceProfile -Path $profilePath -Context $context -Confirm:$false).Message | Should -Match 'zgodny'
        }
    }

    Context 'widget „Status usług”' {
        It 'podsumowanie, obserwowane usługi z tonami i zatrzymane automatyczne' {
            $script:Fake.Services['MwpTestNet'].State = 'Stopped'
            $view = ConvertTo-MwpServiceStatusView -Data (Get-MwpService -Context $context) -WidgetParameters @{ Names = @('MwpTestBase', 'MwpTestNet', 'MwpTestBrak', 'MwpTestDisabled') }
            $view.PSObject.TypeNames | Should -Contain 'MWP.WidgetView'
            $view.Summary | Should -Match 'działa 6 z 11'
            $watch = $view.Sections[0].Items
            $watch[0].Tone | Should -Be 'Success'
            $watch[1].Tone | Should -Be 'Warning'
            $watch[2].Value | Should -Be 'brak usługi'
            $watch[2].Tone | Should -Be 'Danger'
            $watch[3].Tone | Should -Be 'Neutral'
            ($view.Sections | Where-Object Title -eq 'Automatyczne, zatrzymane').Items[0].Value | Should -Be 'MwpTestNet'
            ConvertTo-MwpServiceStatusView -Data $null | Should -BeNullOrEmpty
        }
    }

    Context 'komputer zdalny (D-019)' {
        BeforeEach {
            Mock -ModuleName MWP.Remote Remove-MwpPSSession { }
            Mock -ModuleName MWP.Remote New-MwpPSSession { [pscustomobject]@{ ComputerName = $ComputerName; State = 'Opened' } }
            # „Zdalne” wykonanie: blok związany z zakresem MWP.Remote (tam działają mocki usług; sc.exe — symulator globalny).
            Mock -ModuleName MWP.Remote Invoke-MwpSessionCommand {
                $bound = (Get-Module -Name MWP.Remote).NewBoundScriptBlock($ScriptBlock)
                [pscustomobject]@{ Output = @(& $bound @ArgumentList); Errors = @() }
            }
            # Sprawdzenie administratora w sesji (Test-MwpServiceAdmin): konto zdalne jest administratorem.
            Mock -ModuleName MWP.Remote Invoke-MwpSessionCommand -ParameterFilter { $ScriptBlock.ToString() -match 'IsInRole' -and $ScriptBlock.ToString() -notmatch 'Win32_Service' } {
                [pscustomobject]@{ Output = @($script:Fake.Admin); Errors = @() }
            }
            $remote = New-MwpExecutionContext -ComputerName $remoteName
        }

        It 'odczyt i zmiana przez sesję komputera zdalnego; log, wpis cofnięcia i wynik z jego nazwą' {
            (Get-MwpService -Context $remote).Success | Should -BeTrue
            $result = Set-MwpServiceStartupType -Name MwpTestBase -StartupType Manual -Context $remote -Confirm:$false
            $result.Success | Should -BeTrue -Because $result.Message
            $result.ComputerName | Should -Be $remoteName
            (Get-MwpUndoEntry -Id $result.UndoId).ComputerName | Should -Be $remoteName
            Should -Invoke Test-MwpAdmin -ModuleName MWP.Services -Times 0 -Exactly
            Get-Log | Should -Match ('"computer":"{0}","source":"MWP.Services","operation":"Services.SetStartupType"' -f $remoteName)
        }

        It 'lista ochronna obowiązuje zdalnie tak samo jak lokalnie' {
            (Stop-MwpService -Name WinRM -Context $remote -Confirm:$false).Message | Should -Match 'liście ochronnej'
            (Set-MwpServiceStartupType -Name MwpTestNet -StartupType Disabled -Context $remote -Confirm:$false).Success | Should -BeFalse
            Get-Call 'Stop' | Should -BeNullOrEmpty
            Get-Call 'sc' | Should -BeNullOrEmpty
        }

        It 'cofnięcie zmiany zdalnej wymaga kontekstu tego komputera' {
            $result = Stop-MwpService -Name MwpTestTop -Context $remote -Confirm:$false
            $result.Success | Should -BeTrue -Because $result.Message
            (Invoke-MwpUndo -Id $result.UndoId -Context $context -Confirm:$false).Success | Should -BeFalse
            (Invoke-MwpUndo -Id $result.UndoId -Context $remote -Confirm:$false).Success | Should -BeTrue
            $script:Fake.Services['MwpTestTop'].State | Should -Be 'Running'
        }

        It 'uprawnienia administratora sprawdzane na komputerze zdalnym (blok w sesji)' {
            Mock -ModuleName MWP.Remote Invoke-MwpSessionCommand -ParameterFilter { $ScriptBlock.ToString() -match 'IsInRole' -and $ScriptBlock.ToString() -notmatch 'Win32_Service' } {
                [pscustomobject]@{ Output = @($false); Errors = @() }
            }
            $result = Stop-MwpService -Name MwpTestTop -Context $remote -Confirm:$false
            $result.Success | Should -BeFalse
            $result.Message | Should -Match ('administratora na komputerze ''{0}''' -f $remoteName)
            Get-Call 'Stop' | Should -BeNullOrEmpty
        }

        It 'utrata połączenia: wynik z błędem dla tej instancji, bez wyjątku i bez zmiany; localhost działa dalej' {
            Mock -ModuleName MWP.Remote Invoke-MwpSessionCommand { throw (New-Object -TypeName Management.Automation.Remoting.PSRemotingTransportException -ArgumentList 'Połączenie zerwane') }
            $result = Stop-MwpService -Name MwpTestTop -Context $remote -Confirm:$false
            $result.Success | Should -BeFalse
            $result.ComputerName | Should -Be $remoteName
            $remote.Connection.State | Should -Be 'Disconnected'
            $script:Fake.Services['MwpTestTop'].State | Should -Be 'Running'
            (Get-MwpService -Context $context).Success | Should -BeTrue
        }
    }

    Context 'kontrakt modułu, bloki komputera docelowego i lista ochronna' {
        It 'kontrakt jest poprawny: RemoteTarget, tryby z widgetem i widget ServiceStatus' {
            $definition = Get-MwpModuleDefinition -Name 'MWP.Services'
            $definition.IsValid | Should -BeTrue -Because ($definition.Errors -join ' ')
            $definition.Capabilities | Should -Contain 'RemoteTarget'
            $definition.SupportedPresentationModes | Should -Contain 'DashboardWidget'
            @(Get-MwpWidgetDefinition | Where-Object { $_.ModuleId -eq 'Services' -and $_.WidgetId -eq 'ServiceStatus' }).Count | Should -Be 1
        }

        It 'bloki nie używają funkcji MWP, Invoke-Expression ani $using:, a sc.exe dostaje argumenty jako tablicę' {
            foreach ($name in 'List', 'Control', 'StartupType') {
                $block = InModuleScope MWP.Services -Parameters @{ Name = $name } { param($Name) Get-MwpServiceScript -Name $Name }
                $commands = @($block.Ast.FindAll({ param($node) $node -is [Management.Automation.Language.CommandAst] }, $true) | ForEach-Object { $_.GetCommandName() } | Where-Object { $_ })
                @($commands | Where-Object { $_ -match '-Mwp' }) | Should -BeNullOrEmpty -Because $name
                $block.ToString() | Should -Not -Match 'Invoke-Expression|\$using:'
            }
            (InModuleScope MWP.Services { Get-MwpServiceScript -Name StartupType }).ToString() | Should -Match '& sc\.exe @arguments'
        }

        It 'lista ochronna usług ma co najmniej 30 usług wbudowanych, w tym usługi sieci i zarządzania zdalnego' {
            $builtIn = @(Get-MwpProtectedItem -Category Service | Where-Object Source -eq 'BuiltIn')
            $builtIn.Count | Should -BeGreaterOrEqual 30
            foreach ($name in 'WinRM', 'Winmgmt', 'RpcSs', 'Dhcp', 'Dnscache', 'nsi', 'Appinfo') {
                $builtIn.Name | Should -Contain $name
            }
            (Get-MwpProtectedItem -Category Service -Name 'MwpTestGuard').Source | Should -Be 'Local'
        }

        It 'typy uruchomienia: cztery, chronionym wolno tylko automatyczne' {
            $types = @(Get-MwpServiceStartupTypeList)
            $types.Id | Should -Be @('Automatic', 'AutomaticDelayedStart', 'Manual', 'Disabled')
            @($types | Where-Object AllowedWhenProtected).Id | Should -Be @('Automatic', 'AutomaticDelayedStart')
        }
    }
}
