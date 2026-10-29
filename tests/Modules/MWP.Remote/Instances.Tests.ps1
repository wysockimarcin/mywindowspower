#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
    Testy instancji modułów (definicja ≠ instancja, D-019, D-024): New-, Initialize-, Close-,
    Get-MwpModuleInstance. Moduły testowe leżą na TestDrive; połączenia zdalne są mockowane.
    Testy architektoniczne 3, 4 i 9 z ARCHITEKTURA.md (dwie instancje dla dwóch komputerów,
    brak współdzielenia stanu, zamknięcie jednej instancji bez wpływu na inne).
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Zmienne z bloków BeforeDiscovery/BeforeAll są używane w blokach It (zakresy Pestera).')]
param()

Describe 'Instancje modułów' {
    BeforeAll {
        $root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
        Import-Module -Name (Join-Path -Path $root -ChildPath 'src\Modules\MWP.Core\MWP.Core.psd1') -Force
        Import-Module -Name (Join-Path -Path $root -ChildPath 'src\Modules\MWP.Remote\MWP.Remote.psd1') -Force
        # D-052: testy nie dotykają prawdziwego Menedżera poświadczeń; pamięć poświadczeń jest wspólna dla procesu.
        Mock -ModuleName MWP.Remote Invoke-MwpCredentialApi { throw 'Testy nie mogą używać prawdziwego Menedżera poświadczeń Windows.' }
        Clear-MwpTargetCredentialCache
        $configDirectory = Join-Path -Path $TestDrive -ChildPath 'config'
        $null = New-Item -ItemType Directory -Path $configDirectory -Force
        Copy-Item -LiteralPath (Join-Path -Path $root -ChildPath 'config\settings.example.json') -Destination (Join-Path -Path $configDirectory -ChildPath 'settings.example.json')
        Mock -ModuleName MWP.Core Get-MwpDataPath {
            $path = Join-Path -Path $TestDrive -ChildPath $Kind
            if (Get-Variable -Name Detailed -ValueOnly -ErrorAction SilentlyContinue) { [pscustomobject]@{ Path = $path; Root = $TestDrive; Configured = ''; IsFallback = $false; Warning = $null } } else { $path }
        }
        Mock -ModuleName MWP.Core Get-MwpConfigPath {
            [pscustomobject]@{
                Example = Join-Path -Path $TestDrive -ChildPath 'config\settings.example.json'
                Local   = Join-Path -Path $TestDrive -ChildPath 'config\settings.local.json'
            }
        }
        $computerOne = 'PC-TEST1'
        $computerTwo = 'PC-TEST2'
        $local = [ordered]@{
            schemaVersion = 2
            targets       = @(@{ name = $computerOne; authentication = 'CurrentUser' }, @{ name = $computerTwo; authentication = 'CurrentUser' })
        }
        ConvertTo-Json -InputObject $local -Depth 5 | Set-Content -LiteralPath (Join-Path -Path $configDirectory -ChildPath 'settings.local.json') -Encoding UTF8

        $fixtures = Join-Path -Path $TestDrive -ChildPath 'Fixtures'
        function Add-FixtureModule {
            param([string] $Name, [string] $Capabilities)
            $directory = Join-Path -Path $fixtures -ChildPath "MWP.$Name"
            $null = New-Item -ItemType Directory -Path $directory -Force
            $manifest = @(
                '@{'
                "    RootModule = 'MWP.$Name.psm1'"
                "    ModuleVersion = '1.0.0'"
                "    Description = 'Moduł testowy $Name'"
                "    FunctionsToExport = @('Get-Mwp${Name}ModuleInfo')"
                "    PrivateData = @{ MWP = @{ ContractVersion = 1; Id = '$Name'; Name = 'Test $Name'; EntryPoint = 'Get-Mwp${Name}ModuleInfo'; MinimumHostVersion = '0.3.0';"
                "        Dependencies = @(@{ Id = 'Core'; MinimumVersion = '0.3.0' }); Capabilities = $Capabilities; SupportedPresentationModes = @('Embedded');"
                "        RequiredPermissions = @('User'); ConfigurationSchema = @{} } }"
                '}'
            ) -join [Environment]::NewLine
            Set-Content -LiteralPath (Join-Path -Path $directory -ChildPath "MWP.$Name.psd1") -Value $manifest -Encoding UTF8
            Set-Content -LiteralPath (Join-Path -Path $directory -ChildPath "MWP.$Name.psm1") -Encoding UTF8 `
                -Value "function Get-Mwp${Name}ModuleInfo { 'MWP.$Name' }`nExport-ModuleMember -Function Get-Mwp${Name}ModuleInfo"
        }
        Add-FixtureModule -Name 'Probe' -Capabilities "@('Read', 'RemoteTarget')"
        Add-FixtureModule -Name 'LocalOnly' -Capabilities "@('Read')"
        $definitions = @(Get-MwpModuleDefinition -ModulesRoot (Join-Path -Path $root -ChildPath 'src\Modules'), $fixtures)
        Mock -ModuleName MWP.Remote Get-MwpModuleDefinition { $definitions }
        Mock -ModuleName MWP.Remote Remove-MwpPSSession { }
        Mock -ModuleName MWP.Remote Remove-MwpCimSession { }
    }

    AfterAll {
        Get-MwpModuleInstance | Close-MwpModuleInstance | Out-Null
        Remove-Module -Name MWP.Probe, MWP.LocalOnly, MWP.Remote, MWP.Core -Force -ErrorAction SilentlyContinue
    }

    BeforeEach {
        Clear-MwpTargetCredentialCache
        Get-MwpModuleInstance | Close-MwpModuleInstance | Out-Null
        Mock -ModuleName MWP.Remote New-MwpPSSession { [pscustomobject]@{ ComputerName = $ComputerName; State = 'Opened' } }
    }

    It 'moduły testowe mają poprawny kontrakt' {
        $definitions | Where-Object { $_.Id -in @('Probe', 'LocalOnly') } | ForEach-Object { $_.IsValid | Should -BeTrue -Because ($_.Errors -join ' ') }
    }

    It 'tworzy instancję z własnym kontekstem, stanem i statusem Created' {
        $instance = New-MwpModuleInstance -ModuleId 'Probe'

        $instance.PSObject.TypeNames | Should -Contain 'MWP.ModuleInstance'
        $instance.Id | Should -Not -BeNullOrEmpty
        $instance.Status | Should -Be 'Created'
        $instance.Name | Should -Be 'Test Probe — localhost'
        $instance.Context.InstanceId | Should -Be $instance.Id
        $instance.Context.Mode | Should -Be 'Local'
        @(Get-MwpModuleInstance -ModuleId 'Probe').Count | Should -Be 1
    }

    It 'dwie instancje tego samego modułu dla dwóch komputerów nie współdzielą kontekstu ani stanu' {
        $first = New-MwpModuleInstance -ModuleId 'Probe' -ComputerName 'localhost'
        $second = New-MwpModuleInstance -ModuleId 'Probe' -ComputerName $computerOne

        $first.State['filtr'] = 'Spooler'

        $second.State.ContainsKey('filtr') | Should -BeFalse
        [object]::ReferenceEquals($first.State, $second.State) | Should -BeFalse
        [object]::ReferenceEquals($first.Context.Connection, $second.Context.Connection) | Should -BeFalse
        $first.Context.ComputerName | Should -Be 'localhost'
        $second.Context.ComputerName | Should -Be $computerOne
        $second.Context.Mode | Should -Be 'Remote'
        { $first.Context.ComputerName = $computerTwo } | Should -Throw
        $first.Context.ComputerName | Should -Be 'localhost'
    }

    It 'dwie instancje dla tego samego komputera mają osobne połączenia' {
        $first = New-MwpModuleInstance -ModuleId 'Probe' -ComputerName $computerOne
        $second = New-MwpModuleInstance -ModuleId 'Probe' -ComputerName $computerOne

        $null = Connect-MwpTarget -Context $first.Context
        $first.Context.Connection.State | Should -Be 'Connected'
        $second.Context.Connection.State | Should -Be 'Disconnected'
    }

    It 'zamknięcie jednej instancji zwalnia jej zasoby i nie wpływa na drugą' {
        $first = New-MwpModuleInstance -ModuleId 'Probe' -ComputerName $computerOne
        $second = New-MwpModuleInstance -ModuleId 'Probe' -ComputerName $computerTwo
        $null = Connect-MwpTarget -Context $first.Context
        $null = Connect-MwpTarget -Context $second.Context
        $first.State['dane'] = 1
        $firstSession = $first.Context.Connection.Session

        $result = Close-MwpModuleInstance -Instance $first

        $result.Success | Should -BeTrue
        $first.Status | Should -Be 'Closed'
        $first.State.Count | Should -Be 0
        $first.Context.Connection.State | Should -Be 'Disconnected'
        $second.Status | Should -Be 'Created'
        $second.Context.Connection.State | Should -Be 'Connected'
        (Get-MwpModuleInstance).Id | Should -Be @($second.Id)
        Should -Invoke Remove-MwpPSSession -ModuleName MWP.Remote -Times 1 -Exactly -ParameterFilter { [object]::ReferenceEquals($Session, $firstSession) }
    }

    It 'zamknięcie anuluje operacje asynchroniczne instancji, a nie innych instancji' {
        $first = New-MwpModuleInstance -ModuleId 'Probe'
        $second = New-MwpModuleInstance -ModuleId 'Probe'
        $slowFirst = Start-MwpOperation -Context $first.Context -ScriptBlock { Start-Sleep -Seconds 30 }
        $slowSecond = Start-MwpOperation -Context $second.Context -ScriptBlock { Start-Sleep -Milliseconds 300; 'gotowe' }

        $result = Close-MwpModuleInstance -Instance $first

        $result.Data.StoppedOperations | Should -Be 1
        $slowFirst.Status | Should -Be 'Cancelled'
        (Wait-MwpOperation -Operation $slowSecond).Data | Should -Be @('gotowe')
    }

    It 'inicjalizacja importuje moduł raz i ustawia status Initialized' {
        Remove-Module -Name MWP.Probe -Force -ErrorAction SilentlyContinue
        $first = New-MwpModuleInstance -ModuleId 'Probe'
        $second = New-MwpModuleInstance -ModuleId 'Probe'

        (Initialize-MwpModuleInstance -Instance $first).Success | Should -BeTrue
        (Initialize-MwpModuleInstance -Instance $second).Success | Should -BeTrue

        $first.Status | Should -Be 'Initialized'
        Get-Module -Name MWP.Probe | Should -Not -BeNullOrEmpty
        Get-MwpProbeModuleInfo | Should -Be 'MWP.Probe'
    }

    It 'błąd połączenia przy inicjalizacji dotyczy tylko tej instancji' {
        Mock -ModuleName MWP.Remote New-MwpPSSession {
            if ($ComputerName -eq 'PC-TEST1') { throw (New-Object -TypeName Management.Automation.Remoting.PSRemotingTransportException -ArgumentList 'WinRM cannot complete the operation.') }
            [pscustomobject]@{ ComputerName = $ComputerName; State = 'Opened' }
        }
        $broken = New-MwpModuleInstance -ModuleId 'Probe' -ComputerName $computerOne
        $healthy = New-MwpModuleInstance -ModuleId 'Probe' -ComputerName $computerTwo

        $brokenResult = Initialize-MwpModuleInstance -Instance $broken -Connect
        $healthyResult = Initialize-MwpModuleInstance -Instance $healthy -Connect

        $brokenResult.Success | Should -BeFalse
        $broken.Status | Should -Be 'Initialized'
        $broken.Context.Connection.State | Should -Be 'Error'
        $healthyResult.Success | Should -BeTrue
        $healthy.Context.Connection.State | Should -Be 'Connected'
    }

    It 'zamkniętej instancji nie da się zainicjalizować; ponowne zamknięcie nic nie robi' {
        $instance = New-MwpModuleInstance -ModuleId 'Probe'
        $null = Close-MwpModuleInstance -Instance $instance

        (Initialize-MwpModuleInstance -Instance $instance).Success | Should -BeFalse
        (Close-MwpModuleInstance -Instance $instance).Changed | Should -BeFalse
    }

    It 'zamyka instancję po identyfikatorze' {
        $instance = New-MwpModuleInstance -ModuleId 'Probe'

        (Close-MwpModuleInstance -Id $instance.Id).Success | Should -BeTrue
        (Close-MwpModuleInstance -Id 'brak').Success | Should -BeFalse
    }

    It 'moduł bez RemoteTarget nie tworzy instancji dla komputera zdalnego, a dla localhost tak' {
        { New-MwpModuleInstance -ModuleId 'LocalOnly' -ComputerName $computerOne } | Should -Throw '*RemoteTarget*'
        (New-MwpModuleInstance -ModuleId 'LocalOnly').Context.Mode | Should -Be 'Local'
    }

    It 'odrzuca moduł nieznany i moduł bazowy' {
        { New-MwpModuleInstance -ModuleId 'BrakModulu' } | Should -Throw '*Nie znaleziono*'
        { New-MwpModuleInstance -ModuleId 'Core' } | Should -Throw '*bazowy*'
        { New-MwpModuleInstance -ModuleId 'Remote' } | Should -Throw '*bazowy*'
    }

    It 'moduł bazowy z widgetem tworzy instancję tylko dla widgetu (-ForWidget, D-053); moduł bez trybu DashboardWidget — nie' {
        $instance = New-MwpModuleInstance -ModuleId 'Core' -ForWidget
        try {
            $instance.ModuleId | Should -Be 'Core'
            $instance.Context.Mode | Should -Be 'Local'
        }
        finally {
            $null = Close-MwpModuleInstance -Instance $instance
        }
        { New-MwpModuleInstance -ModuleId 'LocalOnly' -ForWidget } | Should -Throw '*DashboardWidget*'
    }

    It 'filtruje instancje po komputerze' {
        $null = New-MwpModuleInstance -ModuleId 'Probe'
        $null = New-MwpModuleInstance -ModuleId 'Probe' -ComputerName $computerOne

        @(Get-MwpModuleInstance -ComputerName $computerOne).Count | Should -Be 1
        @(Get-MwpModuleInstance -ModuleId 'MWP.Probe').Count | Should -Be 2
    }
}
