#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
    Testy warstwy połączeń: Connect-/Disconnect-/Test-MwpTarget, Invoke-MwpOnTarget,
    Get-MwpCimSessionParameter. Adapter transportu (New-MwpPSSession, Invoke-MwpSessionCommand,
    Test-MwpWsMan, New-MwpCimSession) jest mockowany: testy nie łączą się z żadnym komputerem.
    Wykonanie lokalne (localhost) jest prawdziwe, ale bloki niczego nie zmieniają w systemie.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Zmienne z bloków BeforeDiscovery/BeforeAll są używane w blokach It (zakresy Pestera).')]
param()

Describe 'Połączenia z komputerami docelowymi' {
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
        $computerDomain = 'PC-DOMENA'
        $local = [ordered]@{
            schemaVersion = 2
            logLevel      = 'Debug'
            targets       = @(
                @{ name = $computerOne }
                @{ name = $computerTwo }
                @{ name = $computerDomain; authentication = 'CurrentUser' }
            )
        }
        ConvertTo-Json -InputObject $local -Depth 5 | Set-Content -LiteralPath (Join-Path -Path $configDirectory -ChildPath 'settings.local.json') -Encoding UTF8

        $secret = New-Object -TypeName Security.SecureString
        'TajneHaslo123'.ToCharArray() | ForEach-Object { $secret.AppendChar($_) }
        $credential = New-Object -TypeName Management.Automation.PSCredential -ArgumentList 'admin', $secret

        function Get-TransportError {
            param([string] $Message, [int] $Code)
            $exception = New-Object -TypeName Management.Automation.Remoting.PSRemotingTransportException -ArgumentList $Message
            $exception.ErrorCode = $Code
            $exception
        }

        function Get-LogText {
            $logs = Join-Path -Path $TestDrive -ChildPath 'Logs'
            if (Test-Path -LiteralPath $logs) {
                (Get-ChildItem -LiteralPath $logs -Filter '*.log' | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8 }) -join "`n"
            }
        }
    }

    AfterAll {
        Remove-Module -Name MWP.Remote, MWP.Core -Force -ErrorAction SilentlyContinue
    }

    BeforeEach {
        Clear-MwpTargetCredentialCache
        Mock -ModuleName MWP.Remote New-MwpPSSession { [pscustomobject]@{ ComputerName = $ComputerName; State = 'Opened' } }
        Mock -ModuleName MWP.Remote Remove-MwpPSSession { }
        Mock -ModuleName MWP.Remote Remove-MwpCimSession { }
        Mock -ModuleName MWP.Remote Invoke-MwpSessionCommand { [pscustomobject]@{ Output = @("wynik z $($Session.ComputerName)"); Errors = @() } }
    }

    Context 'Connect-MwpTarget i Disconnect-MwpTarget' {
        It 'localhost nie wymaga połączenia' {
            $context = New-MwpExecutionContext

            (Connect-MwpTarget -Context $context).Success | Should -BeTrue
            Should -Invoke New-MwpPSSession -ModuleName MWP.Remote -Times 0 -Exactly
        }

        It 'łączy się z poświadczeniami i ustawia stan Connected' {
            $context = New-MwpExecutionContext -ComputerName $computerOne

            $result = Connect-MwpTarget -Context $context -Credential $credential

            $result.Success | Should -BeTrue
            $result.ComputerName | Should -Be $computerOne
            $context.Connection.State | Should -Be 'Connected'
            $context.Connection.Session | Should -Not -BeNullOrEmpty
            Should -Invoke New-MwpPSSession -ModuleName MWP.Remote -Times 1 -Exactly -ParameterFilter {
                $ComputerName -eq 'PC-TEST1' -and $Port -eq 5985 -and $Credential.UserName -eq 'admin'
            }
        }

        It 'bez poświadczeń dla uwierzytelnienia Credential: stan Unauthorized, bez próby połączenia' {
            $context = New-MwpExecutionContext -ComputerName $computerOne

            $result = Connect-MwpTarget -Context $context

            $result.Success | Should -BeFalse
            $result.Message | Should -Match 'poświadcze'
            $context.Connection.State | Should -Be 'Unauthorized'
            $context.Connection.ErrorKind | Should -Be 'CredentialRequired'
            Should -Invoke New-MwpPSSession -ModuleName MWP.Remote -Times 0 -Exactly
        }

        It 'uwierzytelnienie CurrentUser łączy się bez poświadczeń' {
            $context = New-MwpExecutionContext -ComputerName $computerDomain

            (Connect-MwpTarget -Context $context).Success | Should -BeTrue
            $context.Connection.State | Should -Be 'Connected'
        }

        It 'odmowa dostępu: stan Unauthorized, poświadczenia usunięte, log z nazwą komputera' {
            Mock -ModuleName MWP.Remote New-MwpPSSession { throw (Get-TransportError -Message 'Access is denied.' -Code 5) }
            $context = New-MwpExecutionContext -ComputerName $computerOne

            $result = Connect-MwpTarget -Context $context -Credential $credential

            $result.Success | Should -BeFalse
            $result.Message | Should -Match 'Odmowa dostępu'
            $context.Connection.State | Should -Be 'Unauthorized'
            $context.Connection.Credential | Should -BeNullOrEmpty
            Get-LogText | Should -Match '"computer":"PC-TEST1"'
        }

        It 'komputer niedostępny: stan Error (Network), bez wyjątku' {
            Mock -ModuleName MWP.Remote New-MwpPSSession { throw (Get-TransportError -Message 'WinRM cannot complete the operation.' -Code 53) }
            $context = New-MwpExecutionContext -ComputerName $computerOne

            $result = Connect-MwpTarget -Context $context -Credential $credential

            $result.Success | Should -BeFalse
            $context.Connection.State | Should -Be 'Error'
            $context.Connection.ErrorKind | Should -Be 'Network'
            $result.Message | Should -Match 'niedostępny'
        }

        It 'brak komputera w TrustedHosts (grupa robocza): komunikat bez zmiany konfiguracji' {
            Mock -ModuleName MWP.Remote New-MwpPSSession { throw (Get-TransportError -Message 'The WinRM client cannot process the request... add the destination computer to the TrustedHosts configuration setting.' -Code -2144108269) }
            $context = New-MwpExecutionContext -ComputerName $computerOne

            $result = Connect-MwpTarget -Context $context -Credential $credential

            $context.Connection.ErrorKind | Should -Be 'Configuration'
            $result.Message | Should -Match 'TrustedHosts'
        }

        It 'Disconnect zamyka sesje, ustawia Disconnected i usuwa poświadczenia' {
            $context = New-MwpExecutionContext -ComputerName $computerOne
            $null = Connect-MwpTarget -Context $context -Credential $credential

            $result = Disconnect-MwpTarget -Context $context

            $result.Success | Should -BeTrue
            $context.Connection.State | Should -Be 'Disconnected'
            $context.Connection.Session | Should -BeNullOrEmpty
            $context.Connection.Credential | Should -BeNullOrEmpty
            Should -Invoke Remove-MwpPSSession -ModuleName MWP.Remote -ParameterFilter { $null -ne $Session }
        }

        It 'log połączeń nie zawiera hasła' {
            $context = New-MwpExecutionContext -ComputerName $computerOne
            $null = Connect-MwpTarget -Context $context -Credential $credential
            $null = Disconnect-MwpTarget -Context $context

            Get-LogText | Should -Not -Match 'TajneHaslo123'
        }
    }

    Context 'Test-MwpTarget' {
        BeforeEach {
            Mock -ModuleName MWP.Remote Test-MwpWsMan { }
            Mock -ModuleName MWP.Remote Invoke-MwpSessionCommand { [pscustomobject]@{ Output = @(@{ IsAdministrator = $true; PSVersion = '5.1.26100.1' }); Errors = @() } }
        }

        It 'localhost: wszystkie kroki spełnione' {
            $result = Test-MwpTarget -Context (New-MwpExecutionContext)

            $result.Success | Should -BeTrue
            $result.Data.Reachable | Should -BeTrue
            $result.Data.Authorized | Should -BeTrue
        }

        It 'rozdziela dostępność, uwierzytelnienie i autoryzację oraz zamyka sesję tymczasową' {
            $context = New-MwpExecutionContext -ComputerName $computerOne

            $result = Test-MwpTarget -Context $context -Credential $credential

            $result.Success | Should -BeTrue
            $result.Data.Reachable | Should -BeTrue
            $result.Data.Authenticated | Should -BeTrue
            $result.Data.Authorized | Should -BeTrue
            $result.Data.IsAdministrator | Should -BeTrue
            $result.Data.RemotePSVersion | Should -Be '5.1.26100.1'
            $context.Connection.State | Should -Be 'Disconnected' -Because 'test nie zmienia stanu połączenia kontekstu'
            Should -Invoke Remove-MwpPSSession -ModuleName MWP.Remote -Times 1 -Exactly
        }

        It 'komputer niedostępny: Reachable = $false, bez próby uwierzytelnienia' {
            Mock -ModuleName MWP.Remote Test-MwpWsMan { throw (Get-TransportError -Message 'WinRM cannot complete the operation.' -Code 53) }

            $result = Test-MwpTarget -Context (New-MwpExecutionContext -ComputerName $computerOne) -Credential $credential

            $result.Success | Should -BeFalse
            $result.Data.Reachable | Should -BeFalse
            $result.Data.ErrorKind | Should -Be 'Network'
            Should -Invoke New-MwpPSSession -ModuleName MWP.Remote -Times 0 -Exactly
        }

        It 'złe poświadczenia: Reachable = $true, Authenticated = $false' {
            Mock -ModuleName MWP.Remote New-MwpPSSession { throw (Get-TransportError -Message 'Access is denied.' -Code 5) }

            $result = Test-MwpTarget -Context (New-MwpExecutionContext -ComputerName $computerOne) -Credential $credential

            $result.Data.Reachable | Should -BeTrue
            $result.Data.Authenticated | Should -BeFalse
            $result.Data.ErrorKind | Should -Be 'Unauthorized'
        }

        It 'brak praw do wykonania poleceń: Authenticated = $true, Authorized = $false' {
            Mock -ModuleName MWP.Remote Invoke-MwpSessionCommand { throw (New-Object -TypeName UnauthorizedAccessException -ArgumentList 'Access is denied.') }

            $result = Test-MwpTarget -Context (New-MwpExecutionContext -ComputerName $computerOne) -Credential $credential

            $result.Data.Authenticated | Should -BeTrue
            $result.Data.Authorized | Should -BeFalse
        }
    }

    Context 'Invoke-MwpOnTarget' {
        It 'localhost: wykonuje blok bezpośrednio, z argumentami, bez sesji zdalnej' {
            $result = Invoke-MwpOnTarget -Context (New-MwpExecutionContext) -ScriptBlock { param($A, $B) $A + $B } -ArgumentList 2, 3 -Operation 'Test.Suma'

            $result.Success | Should -BeTrue
            $result.ComputerName | Should -Be 'localhost'
            $result.Operation | Should -Be 'Test.Suma'
            $result.Data | Should -Be @(5)
            Should -Invoke Invoke-MwpSessionCommand -ModuleName MWP.Remote -Times 0 -Exactly
        }

        It 'localhost: blok nie widzi zmiennych wywołującego (jak na komputerze zdalnym)' {
            $tajne = 'z zewnątrz'
            $result = Invoke-MwpOnTarget -Context (New-MwpExecutionContext) -ScriptBlock { "[$tajne]" }

            $tajne | Should -Not -BeNullOrEmpty
            $result.Data | Should -Be @('[]')
        }

        It 'localhost: błąd w bloku daje wynik z błędem, nie wyjątek' {
            $result = Invoke-MwpOnTarget -Context (New-MwpExecutionContext) -ScriptBlock { Write-Error 'awaria testowa' }

            $result.Success | Should -BeFalse
            $result.ErrorMessage | Should -Match 'awaria testowa'
        }

        It 'localhost z polityką Continue: sukces, a błędy w ErrorMessage' {
            $context = New-MwpExecutionContext -ErrorPolicy Continue
            $result = Invoke-MwpOnTarget -Context $context -ScriptBlock { Write-Error 'ostrzeżenie testowe'; 'dalej' }

            $result.Success | Should -BeTrue
            $result.Data | Should -Be @('dalej')
            $result.ErrorMessage | Should -Match 'ostrzeżenie testowe'
        }

        It 'komputer zdalny: łączy się sam (AutoConnect) i wykonuje blok w sesji' {
            $context = New-MwpExecutionContext -ComputerName $computerOne -Credential $credential

            $result = Invoke-MwpOnTarget -Context $context -ScriptBlock { 'x' }

            $result.Success | Should -BeTrue
            $result.ComputerName | Should -Be $computerOne
            $result.Data | Should -Be @('wynik z PC-TEST1')
            $context.Connection.State | Should -Be 'Connected'
            Should -Invoke New-MwpPSSession -ModuleName MWP.Remote -Times 1 -Exactly
        }

        It 'przekazuje argumenty i limit czasu z polityki kontekstu' {
            $context = New-MwpExecutionContext -ComputerName $computerOne -Credential $credential -OperationTimeoutSeconds 17

            $null = Invoke-MwpOnTarget -Context $context -ScriptBlock { param($Name) $Name } -ArgumentList 'Spooler'

            Should -Invoke Invoke-MwpSessionCommand -ModuleName MWP.Remote -Times 1 -Exactly -ParameterFilter {
                $TimeoutSeconds -eq 17 -and $ArgumentList[0] -eq 'Spooler'
            }
        }

        It 'bez AutoConnect i bez połączenia zwraca błąd bez łączenia' {
            $context = New-MwpExecutionContext -ComputerName $computerOne -Credential $credential -NoAutoConnect

            $result = Invoke-MwpOnTarget -Context $context -ScriptBlock { 'x' }

            $result.Success | Should -BeFalse
            $result.Message | Should -Match 'Connect-MwpTarget'
            Should -Invoke New-MwpPSSession -ModuleName MWP.Remote -Times 0 -Exactly
        }

        It 'błąd połączenia przy AutoConnect daje wynik z błędem i stan połączenia w kontekście' {
            Mock -ModuleName MWP.Remote New-MwpPSSession { throw (Get-TransportError -Message 'WinRM cannot complete the operation.' -Code 53) }
            $context = New-MwpExecutionContext -ComputerName $computerOne -Credential $credential

            $result = Invoke-MwpOnTarget -Context $context -ScriptBlock { 'x' }

            $result.Success | Should -BeFalse
            $context.Connection.State | Should -Be 'Error'
        }

        It 'utrata połączenia z jednym komputerem nie wpływa na drugi; kolejne wywołanie łączy ponownie' {
            Mock -ModuleName MWP.Remote Invoke-MwpSessionCommand {
                if ($Session.ComputerName -eq 'PC-TEST1') {
                    $Session.State = 'Broken'
                    throw (Get-TransportError -Message 'The network connection to PC-TEST1 has been interrupted.' -Code 1236)
                }
                [pscustomobject]@{ Output = @("wynik z $($Session.ComputerName)"); Errors = @() }
            }
            $first = New-MwpExecutionContext -ComputerName $computerOne -Credential $credential
            $second = New-MwpExecutionContext -ComputerName $computerTwo -Credential $credential

            $lost = Invoke-MwpOnTarget -Context $first -ScriptBlock { 'x' }
            $ok = Invoke-MwpOnTarget -Context $second -ScriptBlock { 'x' }

            $lost.Success | Should -BeFalse
            $lost.Message | Should -Match 'Utracono połączenie'
            $first.Connection.State | Should -Be 'Disconnected'
            $first.Connection.ErrorKind | Should -Be 'ConnectionLost'
            $ok.Success | Should -BeTrue
            $ok.Data | Should -Be @('wynik z PC-TEST2')
            $second.Connection.State | Should -Be 'Connected'

            Mock -ModuleName MWP.Remote Invoke-MwpSessionCommand { [pscustomobject]@{ Output = @('ponownie'); Errors = @() } }
            (Invoke-MwpOnTarget -Context $first -ScriptBlock { 'x' }).Success | Should -BeTrue
            $first.Connection.State | Should -Be 'Connected'
            Should -Invoke New-MwpPSSession -ModuleName MWP.Remote -Times 3 -Exactly
        }

        It 'przekroczenie limitu czasu: wynik z błędem, połączenie zostaje' {
            Mock -ModuleName MWP.Remote Invoke-MwpSessionCommand { throw (New-Object -TypeName TimeoutException -ArgumentList 'Przekroczono limit czasu operacji (1 s).') }
            $context = New-MwpExecutionContext -ComputerName $computerOne -Credential $credential

            $result = Invoke-MwpOnTarget -Context $context -ScriptBlock { Start-Sleep -Seconds 5 } -TimeoutSeconds 1

            $result.Success | Should -BeFalse
            $result.Message | Should -Match 'limit czasu'
            $context.Connection.State | Should -Be 'Connected'
        }

        It 'błąd nieprzerywający na komputerze zdalnym przy polityce Stop daje wynik z błędem' {
            Mock -ModuleName MWP.Remote Invoke-MwpSessionCommand {
                $record = New-Object -TypeName Management.Automation.ErrorRecord -ArgumentList (New-Object -TypeName Exception -ArgumentList 'brak usługi'), 'Test', 'ObjectNotFound', $null
                [pscustomobject]@{ Output = @(); Errors = @($record) }
            }
            $context = New-MwpExecutionContext -ComputerName $computerOne -Credential $credential

            $result = Invoke-MwpOnTarget -Context $context -ScriptBlock { 'x' }

            $result.Success | Should -BeFalse
            $result.ErrorMessage | Should -Match 'brak usługi'
        }
    }

    Context 'Get-MwpCimSessionParameter' {
        It 'localhost: pusty słownik (CIM lokalnie)' {
            (Get-MwpCimSessionParameter -Context (New-MwpExecutionContext)).Count | Should -Be 0
        }

        It 'komputer zdalny: sesja CIM tworzona raz i zamykana przez Disconnect' {
            Mock -ModuleName MWP.Remote New-MwpCimSession { [pscustomobject]@{ ComputerName = $ComputerName } }
            $context = New-MwpExecutionContext -ComputerName $computerOne -Credential $credential

            $first = Get-MwpCimSessionParameter -Context $context
            $second = Get-MwpCimSessionParameter -Context $context
            $null = Disconnect-MwpTarget -Context $context

            $first.CimSession.ComputerName | Should -Be $computerOne
            [object]::ReferenceEquals($first.CimSession, $second.CimSession) | Should -BeTrue
            Should -Invoke New-MwpCimSession -ModuleName MWP.Remote -Times 1 -Exactly
            Should -Invoke Remove-MwpCimSession -ModuleName MWP.Remote -Times 1 -Exactly -ParameterFilter { $null -ne $CimSession }
        }

        It 'błąd sesji CIM: wyjątek z komunikatem, nigdy ciche przejście na komputer lokalny' {
            Mock -ModuleName MWP.Remote New-MwpCimSession { throw (Get-TransportError -Message 'Access is denied.' -Code 5) }
            $context = New-MwpExecutionContext -ComputerName $computerOne -Credential $credential

            { Get-MwpCimSessionParameter -Context $context } | Should -Throw '*Odmowa dostępu*'
            $context.Connection.State | Should -Be 'Unauthorized'
        }
    }

    Context 'adapter transportu bez mocka opcji sesji' {
        # Opcje sesji (New-CimSessionOption, New-PSSessionOption) są budowane naprawdę, lokalnie i bez połączenia;
        # podmienione są tylko polecenia, które łączyłyby się z siecią. Test wykrywa błędną kombinację
        # parametrów (np. -Protocol z -UseSsl w New-CimSessionOption), której nie widać przy mocku całego adaptera.
        # Funkcje adaptera są wywoływane przez Get-Command -CommandType Function, bo mocki z BeforeEach je zastępują.
        BeforeAll {
            Mock -ModuleName MWP.Remote New-CimSession { 'sesja CIM (test)' }
            Mock -ModuleName MWP.Remote New-PSSession { 'sesja WinRM (test)' }
        }

        It 'New-MwpCimSession buduje opcje WSMan <Opis>' -ForEach @(
            @{ Opis = 'dla HTTP'; UseSsl = $false }
            @{ Opis = 'dla HTTPS'; UseSsl = $true }
        ) {
            $arguments = @{ ComputerName = $computerOne; Port = 5985; UseSsl = $UseSsl; Credential = $credential; OperationTimeoutSeconds = 30 }

            $session = InModuleScope MWP.Remote -Parameters @{ Arguments = $arguments } { param($Arguments) & (Get-Command -Name New-MwpCimSession -CommandType Function) @Arguments }

            $session | Should -Be 'sesja CIM (test)'
            Should -Invoke New-CimSession -ModuleName MWP.Remote -Times 1 -Exactly -ParameterFilter {
                $SessionOption.GetType().Name -eq 'WSManSessionOptions' -and $SessionOption.UseSsl -eq $UseSsl -and
                $ComputerName -eq 'PC-TEST1' -and $Port -eq 5985 -and $OperationTimeoutSec -eq 30 -and $Credential.UserName -eq 'admin'
            }
        }

        It 'New-MwpPSSession buduje opcje sesji z limitami czasu <Opis>' -ForEach @(
            @{ Opis = 'dla HTTP'; UseSsl = $false }
            @{ Opis = 'dla HTTPS'; UseSsl = $true }
        ) {
            $arguments = @{ ComputerName = $computerOne; Port = 5986; UseSsl = $UseSsl; Credential = $credential; OpenTimeoutSeconds = 7; OperationTimeoutSeconds = 42 }

            $session = InModuleScope MWP.Remote -Parameters @{ Arguments = $arguments } { param($Arguments) & (Get-Command -Name New-MwpPSSession -CommandType Function) @Arguments }

            $session | Should -Be 'sesja WinRM (test)'
            Should -Invoke New-PSSession -ModuleName MWP.Remote -Times 1 -Exactly -ParameterFilter {
                $SessionOption.OpenTimeout.TotalSeconds -eq 7 -and $SessionOption.OperationTimeout.TotalSeconds -eq 42 -and
                [bool]$UseSSL -eq $UseSsl -and $Port -eq 5986
            }
        }
    }
}
