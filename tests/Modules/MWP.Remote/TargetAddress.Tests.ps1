#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
    Testy korekty D-054: nazwa komputera (identyfikator) i adres połączenia rozdzielone, weryfikacja
    nazwy po połączeniu (NameMismatch), adres LAN komputera lokalnego tylko informacyjnie, ostrzeżenie
    „to ten komputer” i zmiana nazwy z przeniesieniem hasła, widgetów, cofnięć i pamięci procesu.
    Adapter transportu (New-MwpPSSession, Get-MwpRemoteIdentity, New-MwpCimSession, Test-MwpWsMan,
    Invoke-MwpSessionCommand) i warstwa P/Invoke magazynu są zastąpione mockami/symulatorem: testy nie
    łączą się z żadnym komputerem i nie dotykają Menedżera poświadczeń. Adresy są dokumentacyjne
    (192.0.2.x, 198.51.100.x), nazwy komputerów fikcyjne, hasło sztuczne.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Zmienne z bloków BeforeDiscovery/BeforeAll są używane w blokach It (zakresy Pestera).')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingComputerNameHardcoded', '',
    Justification = 'Sztuczne nazwy komputerów testowych; testy nie łączą się z żadnym komputerem.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
    Justification = 'Pomocnicze funkcje testów tworzą tylko obiekty w pamięci.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', '',
    Justification = 'Sztuczne hasło testowe; testy nie używają prawdziwych haseł.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '',
    Justification = 'Sztuczne hasło testowe.')]
param()

Describe 'Nazwa komputera i adres połączenia (D-054)' {
    BeforeAll {
        $root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
        Import-Module -Name (Join-Path -Path $root -ChildPath 'src\Modules\MWP.Core\MWP.Core.psd1') -Force
        Import-Module -Name (Join-Path -Path $root -ChildPath 'src\Modules\MWP.Remote\MWP.Remote.psd1') -Force
        $configDirectory = Join-Path -Path $TestDrive -ChildPath 'config'
        $null = New-Item -ItemType Directory -Path $configDirectory -Force
        Copy-Item -LiteralPath (Join-Path -Path $root -ChildPath 'config\settings.example.json') -Destination (Join-Path -Path $configDirectory -ChildPath 'settings.example.json')
        $localPath = Join-Path -Path $configDirectory -ChildPath 'settings.local.json'
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

        $secretText = 'Test-Hasło-D054-Nie-Ujawniać!'
        $secure = New-Object -TypeName Security.SecureString
        $secretText.ToCharArray() | ForEach-Object { $secure.AppendChar($_) }
        $credential = New-Object -TypeName Management.Automation.PSCredential -ArgumentList 'admin', $secure

        function Write-TestSetting {
            param([object[]] $Target, [object[]] $Widget = @())
            $local = [ordered]@{ schemaVersion = 2; logLevel = 'Debug'; targets = @($Target) }
            if (@($Widget).Count -gt 0) {
                $local['dashboardWidgets'] = @($Widget)
            }
            ConvertTo-Json -InputObject $local -Depth 6 | Set-Content -LiteralPath $localPath -Encoding UTF8
        }
        function Get-LogText {
            $logs = Join-Path -Path $TestDrive -ChildPath 'Logs'
            if (Test-Path -LiteralPath $logs) {
                (Get-ChildItem -LiteralPath $logs -Filter '*.log' | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8 }) -join "`n"
            }
        }
        function New-Identity {
            param([string] $ComputerName, [string[]] $Address = @('192.0.2.10'))
            @{
                MwpIdentity  = $true
                ComputerName = $ComputerName
                HostName     = $ComputerName
                Network      = @{
                    PreferredAddress = $Address[0]
                    Error            = $null
                    Interfaces       = @(@{
                            Name = 'Ethernet'; Type = 'Ethernet'; Status = 'Up'; HasGateway = $true
                            Addresses = @($Address | ForEach-Object { @{ Address = $_; Family = 'IPv4' } })
                        })
                }
            }
        }

        # Symulator magazynu (wpisy MWP:<komputer>) z wymuszonymi błędami zapisu.
        $store = @{ Entries = @{}; FailWrite = $false }
        Mock -ModuleName MWP.Remote Invoke-MwpCredentialApi {
            $name = $PesterBoundParameters['TargetName']
            switch ($PesterBoundParameters['Action']) {
                'Read' {
                    $entry = $store.Entries[$name]
                    if ($null -eq $entry) {
                        return [pscustomobject]@{ ErrorCode = 1168; UserName = $null; Password = $null; LastWritten = [datetime]::MinValue; BlobSize = 0 }
                    }
                    $password = if ($PesterBoundParameters['IncludePassword']) { $entry.Password.Copy() } else { $null }
                    [pscustomobject]@{ ErrorCode = 0; UserName = $entry.UserName; Password = $password; LastWritten = Get-Date; BlobSize = $entry.Password.Length * 2 }
                }
                'Write' {
                    if ($store.FailWrite) {
                        return [pscustomobject]@{ ErrorCode = 1312 }
                    }
                    $store.Entries[$name] = @{ UserName = $PesterBoundParameters['UserName']; Password = $PesterBoundParameters['Password'].Copy() }
                    [pscustomobject]@{ ErrorCode = 0 }
                }
                'Delete' {
                    if ($store.Entries.ContainsKey($name)) {
                        $store.Entries.Remove($name)
                        return [pscustomobject]@{ ErrorCode = 0 }
                    }
                    [pscustomobject]@{ ErrorCode = 1168 }
                }
            }
        }
    }

    AfterAll {
        Clear-MwpTargetCredentialCache
        Remove-Module -Name MWP.Remote, MWP.Core -Force -ErrorAction SilentlyContinue
    }

    BeforeEach {
        Clear-MwpTargetCredentialCache
        $store.Entries.Clear()
        $store.FailWrite = $false
        Remove-Item -LiteralPath (Join-Path -Path $TestDrive -ChildPath 'Undo') -Recurse -Force -ErrorAction SilentlyContinue
        Write-TestSetting -Target @(
            @{ name = 'PC-ADRES'; address = '192.0.2.10' }
            @{ name = 'PC-NAZWA' }
            @{ name = 'PC-SSL'; address = '192.0.2.30'; useSsl = $true; port = 5986 }
            @{ name = '192.0.2.40' }
            @{ name = 'pc-fqdn.firma.example'; address = '198.51.100.7' }
        )
        Mock -ModuleName MWP.Remote New-MwpPSSession { [pscustomobject]@{ ComputerName = $ComputerName; State = 'Opened' } }
        Mock -ModuleName MWP.Remote Remove-MwpPSSession { }
        Mock -ModuleName MWP.Remote Remove-MwpCimSession { }
        Mock -ModuleName MWP.Remote Invoke-MwpSessionCommand { [pscustomobject]@{ Output = @('wynik'); Errors = @() } }
        Mock -ModuleName MWP.Remote Get-MwpRemoteIdentity { New-Identity -ComputerName 'PC-ADRES' }
    }

    Context 'model: pole address i adres połączenia' {
        It 'wpis z adresem łączy się pod adres, bez adresu — po nazwie; przy HTTPS zawsze po nazwie' {
            $targets = @(Get-MwpTarget)
            ($targets | Where-Object Name -EQ 'PC-ADRES').ConnectionAddress | Should -Be '192.0.2.10'
            ($targets | Where-Object Name -EQ 'PC-ADRES').Address | Should -Be '192.0.2.10'
            ($targets | Where-Object Name -EQ 'PC-NAZWA').ConnectionAddress | Should -Be 'PC-NAZWA'
            ($targets | Where-Object Name -EQ 'PC-NAZWA').Address | Should -Be ''
            ($targets | Where-Object Name -EQ 'PC-SSL').ConnectionAddress | Should -Be 'PC-SSL'
            ($targets | Where-Object Name -EQ 'localhost').ConnectionAddress | Should -Be 'localhost'
        }

        It 'wpis z niepoprawnym adresem jest pomijany z ostrzeżeniem' {
            Write-TestSetting -Target @(@{ name = 'PC-ZLY'; address = '192.0.2.1;calc' }, @{ name = 'PC-NAZWA' })
            $targets = @(Get-MwpTarget -WarningVariable warnings -WarningAction SilentlyContinue)
            $targets.Name | Should -Not -Contain 'PC-ZLY'
            $targets.Name | Should -Contain 'PC-NAZWA'
            ($warnings -join ' ') | Should -Match 'PC-ZLY'
        }

        It 'kontekst: ComputerName to nazwa (identyfikator), Address — adres połączenia; localhost bez zmian' {
            $context = New-MwpExecutionContext -ComputerName 'PC-ADRES'
            $context.ComputerName | Should -Be 'PC-ADRES'
            $context.Address | Should -Be '192.0.2.10'
            $context.Connection.ComputerName | Should -Be 'PC-ADRES'
            $context.Connection.Address | Should -Be '192.0.2.10'
            $local = New-MwpExecutionContext
            $local.Mode | Should -Be 'Local'
            $local.ComputerName | Should -Be 'localhost'
        }

        It 'Add-MwpTarget -Address zapisuje adres; adres równy nazwie nie jest zapisywany' {
            (Add-MwpTarget -Name 'PC-NOWY' -Address '192.0.2.50' -Confirm:$false).Success | Should -BeTrue
            (Add-MwpTarget -Name 'PC-TAKI' -Address 'PC-TAKI' -Confirm:$false).Success | Should -BeTrue
            $saved = @((Get-Content -LiteralPath $localPath -Raw | ConvertFrom-Json).targets)
            ($saved | Where-Object name -EQ 'PC-NOWY').address | Should -Be '192.0.2.50'
            ($saved | Where-Object name -EQ 'PC-TAKI').PSObject.Properties['address'] | Should -BeNullOrEmpty
        }

        It 'Add-MwpTarget odrzuca niepoprawne adresy (wstrzyknięcia, spacje, ukośniki, symbole wieloznaczne)' {
            foreach ($bad in '192.0.2.1;calc', 'a b', 'pc/x', 'pc*', '$(calc)', '"pc"') {
                $result = Add-MwpTarget -Name 'PC-NOWY' -Address $bad -Confirm:$false
                $result.Success | Should -BeFalse -Because $bad
                $result.Message | Should -Match 'Niepoprawny adres' -Because $bad
            }
            (Get-Content -LiteralPath $localPath -Raw) | Should -Not -Match 'PC-NOWY'
        }

        It 'Add-MwpTarget -WhatIf niczego nie zapisuje' {
            $before = Get-Content -LiteralPath $localPath -Raw
            (Add-MwpTarget -Name 'PC-NOWY' -Address '192.0.2.50' -WhatIf).IsPreview | Should -BeTrue
            Get-Content -LiteralPath $localPath -Raw | Should -Be $before
        }

        It 'Set-MwpTarget -Address ustawia i czyści adres (pusty tekst = połączenie po nazwie)' {
            (Set-MwpTarget -Name 'PC-NAZWA' -Address '192.0.2.20' -Confirm:$false).Success | Should -BeTrue
            (Get-MwpTarget -Name 'PC-NAZWA').ConnectionAddress | Should -Be '192.0.2.20'
            (Set-MwpTarget -Name 'PC-NAZWA' -Address '' -Confirm:$false).Success | Should -BeTrue
            (Get-MwpTarget -Name 'PC-NAZWA').ConnectionAddress | Should -Be 'PC-NAZWA'
            (Set-MwpTarget -Name 'PC-NAZWA' -Address 'zly adres' -Confirm:$false).Success | Should -BeFalse
        }

        It 'Set-MwpTarget -Address -WhatIf niczego nie zapisuje' {
            $before = Get-Content -LiteralPath $localPath -Raw
            (Set-MwpTarget -Name 'PC-NAZWA' -Address '192.0.2.20' -WhatIf).IsPreview | Should -BeTrue
            Get-Content -LiteralPath $localPath -Raw | Should -Be $before
        }

        It 'HTTPS z adresem: ostrzeżenie, że adres jest pomijany' {
            $result = Add-MwpTarget -Name 'PC-HTTPS' -Address '192.0.2.60' -UseSsl -Confirm:$false
            $result.Success | Should -BeTrue
            $result.Message | Should -Match 'HTTPS'
            (Get-MwpTarget -Name 'PC-HTTPS').ConnectionAddress | Should -Be 'PC-HTTPS'
        }
    }

    Context 'połączenia idą pod adres, a log i wyniki zawierają nazwę' {
        It 'Connect-MwpTarget przekazuje adapterowi adres; wynik, log i połączenie mają nazwę' {
            $context = New-MwpExecutionContext -ComputerName 'PC-ADRES' -Credential $credential
            $result = Connect-MwpTarget -Context $context

            $result.Success | Should -BeTrue
            $result.ComputerName | Should -Be 'PC-ADRES'
            $result.Message | Should -Match "'PC-ADRES'"
            $result.Message | Should -Match '192\.0\.2\.10'
            $context.Connection.ComputerName | Should -Be 'PC-ADRES'
            $context.Connection.NameVerified | Should -BeTrue
            $context.Connection.RemoteComputerName | Should -Be 'PC-ADRES'
            @($context.Connection.DetectedAddresses) | Should -Contain '192.0.2.10'
            Should -Invoke New-MwpPSSession -ModuleName MWP.Remote -Times 1 -Exactly -ParameterFilter { $ComputerName -eq '192.0.2.10' }
            Get-LogText | Should -Match 'PC-ADRES'
        }

        It 'bez adresu łączy się po nazwie (zgodność wsteczna)' {
            Mock -ModuleName MWP.Remote Get-MwpRemoteIdentity { New-Identity -ComputerName 'PC-NAZWA' }
            $context = New-MwpExecutionContext -ComputerName 'PC-NAZWA' -Credential $credential
            (Connect-MwpTarget -Context $context).Success | Should -BeTrue
            Should -Invoke New-MwpPSSession -ModuleName MWP.Remote -Times 1 -Exactly -ParameterFilter { $ComputerName -eq 'PC-NAZWA' }
        }

        It 'HTTPS: połączenie po nazwie mimo zapisanego adresu' {
            Mock -ModuleName MWP.Remote Get-MwpRemoteIdentity { New-Identity -ComputerName 'PC-SSL' -Address '192.0.2.30' }
            $context = New-MwpExecutionContext -ComputerName 'PC-SSL' -Credential $credential
            (Connect-MwpTarget -Context $context).Success | Should -BeTrue
            Should -Invoke New-MwpPSSession -ModuleName MWP.Remote -Times 1 -Exactly -ParameterFilter { $ComputerName -eq 'PC-SSL' -and $UseSsl }
        }

        It 'Get-MwpCimSessionParameter i Test-MwpTarget łączą się pod adres' {
            Mock -ModuleName MWP.Remote New-MwpCimSession { [pscustomobject]@{ ComputerName = $ComputerName } }
            Mock -ModuleName MWP.Remote Get-MwpCimComputerName { 'PC-ADRES' }
            Mock -ModuleName MWP.Remote Test-MwpWsMan { }
            $context = New-MwpExecutionContext -ComputerName 'PC-ADRES' -Credential $credential
            $null = Get-MwpCimSessionParameter -Context $context
            $null = Test-MwpTarget -Context $context
            Should -Invoke New-MwpCimSession -ModuleName MWP.Remote -Times 1 -Exactly -ParameterFilter { $ComputerName -eq '192.0.2.10' }
            Should -Invoke Test-MwpWsMan -ModuleName MWP.Remote -Times 1 -Exactly -ParameterFilter { $ComputerName -eq '192.0.2.10' }
            Should -Invoke New-MwpPSSession -ModuleName MWP.Remote -ParameterFilter { $ComputerName -eq '192.0.2.10' }
        }

        It 'operacja w tle dostaje adres, a sprawdzenie nazwy — nazwę z rejestru (bez połączenia: brak hasła)' {
            $source = (Get-Command -Name Start-MwpOperation).ScriptBlock.ToString()
            $source | Should -Match 'ComputerName\s+=\s+\$Context\.Address'
            $source | Should -Match 'Get-MwpExpectedComputerName -Name \$Context\.ComputerName'
            $context = New-MwpExecutionContext -ComputerName 'PC-ADRES'
            $operation = Start-MwpOperation -Context $context -ScriptBlock { 1 }
            $operation.ComputerName | Should -Be 'PC-ADRES'
            $operation.Address | Should -Be '192.0.2.10'
        }
    }

    Context 'weryfikacja nazwy po połączeniu (NameMismatch)' {
        It 'niezgodna nazwa: stan Error, NameMismatch, sesja zamknięta, hasło nie trafia do pamięci' {
            Mock -ModuleName MWP.Remote Get-MwpRemoteIdentity { New-Identity -ComputerName 'PC-INNY' }
            $context = New-MwpExecutionContext -ComputerName 'PC-ADRES' -Credential $credential
            $result = Connect-MwpTarget -Context $context

            $result.Success | Should -BeFalse
            $result.Data.ErrorKind | Should -Be 'NameMismatch'
            $result.Message | Should -Match 'PC-INNY'
            $result.Message | Should -Match 'PC-ADRES'
            $result.Message | Should -Match '192\.0\.2\.10'
            $context.Connection.State | Should -Be 'Error'
            $context.Connection.ErrorKind | Should -Be 'NameMismatch'
            $context.Connection.Session | Should -BeNullOrEmpty
            $context.Connection.NameVerified | Should -BeFalse
            Should -Invoke Remove-MwpPSSession -ModuleName MWP.Remote -Times 1 -Exactly
            InModuleScope MWP.Remote { Get-MwpCachedCredential -ComputerName 'PC-ADRES' } | Should -BeNullOrEmpty
        }

        It 'operacja zmieniająca (Invoke-MwpOnTarget) jest odrzucona przed wykonaniem bloku' {
            Mock -ModuleName MWP.Remote Get-MwpRemoteIdentity { New-Identity -ComputerName 'PC-INNY' }
            $context = New-MwpExecutionContext -ComputerName 'PC-ADRES' -Credential $credential
            $result = Invoke-MwpOnTarget -Context $context -ScriptBlock { 'zmiana' } -Operation 'Test.Change'

            $result.Success | Should -BeFalse
            $result.Message | Should -Match 'PC-INNY'
            Should -Invoke Invoke-MwpSessionCommand -ModuleName MWP.Remote -Times 0 -Exactly
        }

        It 'porównanie bez wielkości liter i z FQDN (pierwszy człon nazwy)' {
            Mock -ModuleName MWP.Remote Get-MwpRemoteIdentity { New-Identity -ComputerName 'PC-FQDN' -Address '198.51.100.7' }
            $context = New-MwpExecutionContext -ComputerName 'pc-fqdn.firma.example' -Credential $credential
            (Connect-MwpTarget -Context $context).Success | Should -BeTrue
            $context.Connection.NameVerified | Should -BeTrue
        }

        It 'nazwa krótka NetBIOS (15 znaków) albo pełna nazwa hosta — wystarczy jedna zgodna' {
            InModuleScope MWP.Remote {
                Test-MwpRemoteNameMatch -Name 'KOMPUTER-BARDZO-DLUGI' -RemoteNames @('KOMPUTER-BARDZO', 'Komputer-Bardzo-Dlugi') | Should -BeTrue
                Test-MwpRemoteNameMatch -Name 'PC-A' -RemoteNames @('PC-B', 'pc-b.example') | Should -BeFalse
                Test-MwpRemoteNameMatch -Name '192.0.2.40' -RemoteNames @('PC-X') | Should -BeNullOrEmpty
                Test-MwpRemoteNameMatch -Name 'PC-A' -RemoteNames @('', $null) | Should -BeNullOrEmpty
            }
        }

        It 'nazwa w rejestrze jest adresem IP: bez weryfikacji, połączenie działa jak przed korektą' {
            Mock -ModuleName MWP.Remote Get-MwpRemoteIdentity { New-Identity -ComputerName 'PC-COKOLWIEK' -Address '192.0.2.40' }
            $context = New-MwpExecutionContext -ComputerName '192.0.2.40' -Credential $credential
            (Connect-MwpTarget -Context $context).Success | Should -BeTrue
            $context.Connection.NameVerified | Should -BeNullOrEmpty
            $context.Connection.RemoteComputerName | Should -Be 'PC-COKOLWIEK'
        }

        It 'nie udało się odczytać nazwy: połączenie działa (bez weryfikacji), wpis w logu' {
            Mock -ModuleName MWP.Remote Get-MwpRemoteIdentity { throw 'brak odpowiedzi' }
            $context = New-MwpExecutionContext -ComputerName 'PC-ADRES' -Credential $credential
            (Connect-MwpTarget -Context $context).Success | Should -BeTrue
            $context.Connection.NameVerified | Should -BeNullOrEmpty
            Get-LogText | Should -Match 'Nie udało się odczytać nazwy'
        }

        It 'adres IP spoza adresów wykrytych: ostrzeżenie bez blokady' {
            Mock -ModuleName MWP.Remote Get-MwpRemoteIdentity { New-Identity -ComputerName 'PC-ADRES' -Address '198.51.100.20' }
            $context = New-MwpExecutionContext -ComputerName 'PC-ADRES' -Credential $credential
            $result = Connect-MwpTarget -Context $context
            $result.Success | Should -BeTrue
            $result.Message | Should -Match 'NAT'
            $context.Connection.AddressWarning | Should -Match '198\.51\.100\.20'
        }

        It 'niezgodność jednego komputera nie wpływa na inne konteksty (D-019)' {
            Mock -ModuleName MWP.Remote Get-MwpRemoteIdentity { New-Identity -ComputerName 'PC-INNY' } -ParameterFilter { $Session.ComputerName -eq '192.0.2.10' }
            Mock -ModuleName MWP.Remote Get-MwpRemoteIdentity { New-Identity -ComputerName 'PC-NAZWA' } -ParameterFilter { $Session.ComputerName -eq 'PC-NAZWA' }
            $bad = New-MwpExecutionContext -ComputerName 'PC-ADRES' -Credential $credential
            $good = New-MwpExecutionContext -ComputerName 'PC-NAZWA' -Credential $credential
            (Connect-MwpTarget -Context $bad).Success | Should -BeFalse
            (Connect-MwpTarget -Context $good).Success | Should -BeTrue
            $good.Connection.State | Should -Be 'Connected'
            (Invoke-MwpOnTarget -Context $good -ScriptBlock { 'ok' }).Success | Should -BeTrue
        }

        It 'odczyt CIM bez Connect: niezgodna nazwa (CSName) kończy się wyjątkiem NameMismatch' {
            Mock -ModuleName MWP.Remote New-MwpCimSession { [pscustomobject]@{ ComputerName = $ComputerName } }
            Mock -ModuleName MWP.Remote Get-MwpCimComputerName { 'PC-INNY' }
            $context = New-MwpExecutionContext -ComputerName 'PC-ADRES' -Credential $credential
            { Get-MwpCimSessionParameter -Context $context } | Should -Throw '*PC-INNY*'
            $context.Connection.ErrorKind | Should -Be 'NameMismatch'
            $context.Connection.CimSession | Should -BeNullOrEmpty
            Should -Invoke Remove-MwpCimSession -ModuleName MWP.Remote -Times 1 -Exactly
        }

        It 'diagnostyka pokazuje adres, nazwę zgłoszoną, zgodność, adresy wykryte i wartość do TrustedHosts' {
            Mock -ModuleName MWP.Remote Test-MwpWsMan { }
            Mock -ModuleName MWP.Remote Invoke-MwpSessionCommand {
                [pscustomobject]@{ Output = @(@{ IsAdministrator = $true; PSVersion = '5.1'; ComputerName = 'PC-INNY'; HostName = 'PC-INNY'; Network = (New-Identity -ComputerName 'x').Network }); Errors = @() }
            }
            $context = New-MwpExecutionContext -ComputerName 'PC-ADRES' -Credential $credential
            $result = Test-MwpTarget -Context $context

            $result.Success | Should -BeFalse
            $result.Data.Address | Should -Be '192.0.2.10'
            $result.Data.TrustedHostsValue | Should -Be '192.0.2.10'
            $result.Data.RemoteComputerName | Should -Be 'PC-INNY'
            $result.Data.NameMatches | Should -BeFalse
            $result.Data.ErrorKind | Should -Be 'NameMismatch'
            @($result.Data.DetectedAddresses) | Should -Contain '192.0.2.10'
        }

        It 'diagnostyka przy zgodnej nazwie: komunikat zawiera adres i wpis TrustedHosts (IP — tylko NTLM)' {
            Mock -ModuleName MWP.Remote Test-MwpWsMan { }
            Mock -ModuleName MWP.Remote Invoke-MwpSessionCommand {
                [pscustomobject]@{ Output = @(@{ IsAdministrator = $true; PSVersion = '5.1'; ComputerName = 'PC-ADRES'; HostName = 'PC-ADRES'; Network = $null }); Errors = @() }
            }
            $result = Test-MwpTarget -Context (New-MwpExecutionContext -ComputerName 'PC-ADRES' -Credential $credential)
            $result.Success | Should -BeTrue
            $result.Message | Should -Match "TrustedHosts.*'192\.0\.2\.10'.*NTLM"
        }

        It 'błąd TrustedHosts przy łączeniu po IP wskazuje adres IP do dopisania' {
            $context = New-MwpExecutionContext -ComputerName 'PC-ADRES'
            $message = InModuleScope MWP.Remote -Parameters @{ Context = $context } { param($Context) Get-MwpRemoteErrorMessage -Kind 'Configuration' -Context $Context }
            $message | Should -Match "dopisać '192\.0\.2\.10'"
        }

        It 'blok operacji w tle: niezgodna nazwa zgłasza znacznik NameMismatch, zgodna wykonuje blok modułu z argumentami' {
            $guard = InModuleScope MWP.Remote { Get-MwpNameGuardScript }
            { & $guard 'PC-NA-PEWNO-INNY' '"blok"' } | Should -Throw '*MWP-NAMEMISMATCH:*'
            & $guard $env:COMPUTERNAME 'param($a, $b) "{0}-{1}" -f $a, $b' 'x' 'y' | Should -Be 'x-y'
            & $guard '' '"bez sprawdzania"' | Should -Be 'bez sprawdzania'
            $exception = New-Object -TypeName Management.Automation.RuntimeException -ArgumentList 'MWP-NAMEMISMATCH:PC-INNY'
            InModuleScope MWP.Remote -Parameters @{ E = $exception } { param($E) Get-MwpRemoteErrorKind -Exception $E } | Should -Be 'NameMismatch'
        }
    }

    Context 'adres LAN komputera lokalnego (informacyjnie)' {
        BeforeAll {
            function New-Nic {
                param([string] $Name, [string[]] $Address, [bool] $Gateway = $true, [string] $Status = 'Up', [string] $Type = 'Ethernet', [string] $Family = 'IPv4')
                @{ Name = $Name; Type = $Type; Status = $Status; HasGateway = $Gateway; Addresses = @($Address | ForEach-Object { @{ Address = $_; Family = $(if ($_ -match ':') { 'IPv6' } else { $Family }) } }) }
            }
            function Select-Test {
                param([object[]] $Interfaces, [string] $Preferred, [string] $ErrorText)
                $data = @{ Interfaces = @($Interfaces); PreferredAddress = $Preferred; Error = $ErrorText }
                InModuleScope MWP.Remote -Parameters @{ Data = $data } { param($Data) Select-MwpNetworkAddress -Data $Data }
            }
        }

        It 'kilka kart z bramą: wygrywa adres trasy domyślnej (najniższa metryka), reszta w podpowiedzi z nazwą karty' {
            $result = Select-Test -Interfaces @((New-Nic 'Ethernet' '192.0.2.5'), (New-Nic 'Wi-Fi' '198.51.100.5')) -Preferred '198.51.100.5'
            $result.Status | Should -Be 'Ok'
            $result.PrimaryAddress | Should -Be '198.51.100.5'
            $result.InterfaceName | Should -Be 'Wi-Fi'
            @($result.OtherAddresses | ForEach-Object { $_.Address }) | Should -Contain '192.0.2.5'
            $result.ToolTip | Should -Match 'Ethernet'
        }

        It 'bez adresu trasy domyślnej: pierwszy kandydat; karta bez bramy (Hyper-V, WSL) nie jest wybierana' {
            $result = Select-Test -Interfaces @((New-Nic 'vEthernet (WSL)' '198.51.100.1' -Gateway $false), (New-Nic 'Ethernet' '192.0.2.5')) -Preferred ''
            $result.PrimaryAddress | Should -Be '192.0.2.5'
            @($result.OtherAddresses | ForEach-Object { $_.Address }) | Should -Contain '198.51.100.1'
        }

        It 'VPN z bramą wybrany przez system jest adresem głównym' {
            $result = Select-Test -Interfaces @((New-Nic 'Ethernet' '192.0.2.5'), (New-Nic 'VPN' '198.51.100.99' -Type 'Ppp')) -Preferred '198.51.100.99'
            $result.PrimaryAddress | Should -Be '198.51.100.99'
            $result.InterfaceName | Should -Be 'VPN'
        }

        It 'APIPA, pętla zwrotna, link-local i karty wyłączone są pomijane; tylko IPv6 → brak połączenia z siecią' {
            $result = Select-Test -Interfaces @(
                (New-Nic 'Ethernet' '169.254.10.1'),
                (New-Nic 'Loopback' '127.0.0.1' -Type 'Loopback'),
                (New-Nic 'Wi-Fi' '192.0.2.8' -Status 'Down'),
                (New-Nic 'Tunel' @('2001:db8::5', 'fe80::1'))
            ) -Preferred '169.254.10.1'
            $result.Status | Should -Be 'NoNetwork'
            $result.Text | Should -Be 'brak połączenia z siecią'
            $result.PrimaryAddress | Should -BeNullOrEmpty
            @($result.OtherAddresses | ForEach-Object { $_.Address }) | Should -Be @('2001:db8::5')
        }

        It 'brak kart → brak połączenia z siecią; błąd odczytu → brak danych' {
            (Select-Test -Interfaces @() -Preferred '').Status | Should -Be 'NoNetwork'
            $failed = Select-Test -Interfaces @() -ErrorText 'odmowa'
            $failed.Status | Should -Be 'Unavailable'
            $failed.Text | Should -Be 'brak danych'
            $failed.ToolTip | Should -Match 'odmowa'
        }

        It 'wyjątek przy odczycie daje „brak danych”, nie wyjątek; funkcja niczego nie zapisuje' {
            Mock -ModuleName MWP.Remote Get-MwpNetworkDataScript { { throw 'awaria odczytu' } }
            Mock -ModuleName MWP.Remote Set-MwpSetting { throw 'nie wolno zapisywać' }
            $result = Get-MwpLocalNetworkAddress
            $result.Status | Should -Be 'Unavailable'
            $result.Text | Should -Be 'brak danych'
            Should -Invoke Set-MwpSetting -ModuleName MWP.Remote -Times 0 -Exactly
        }

        It 'prawdziwy odczyt kart (.NET, bez zmian w systemie) zwraca wynik bez wyjątku' {
            $result = Get-MwpLocalNetworkAddress
            $result.Status | Should -BeIn @('Ok', 'NoNetwork', 'Unavailable')
            $result.Text | Should -Not -BeNullOrEmpty
        }

        It 'localhost działa lokalnie niezależnie od adresu LAN (bez adaptera transportu)' {
            $context = New-MwpExecutionContext
            $context.Mode | Should -Be 'Local'
            (Invoke-MwpOnTarget -Context $context -ScriptBlock { 'lokalnie' }).Data | Should -Be 'lokalnie'
            Should -Invoke New-MwpPSSession -ModuleName MWP.Remote -Times 0 -Exactly
        }
    }

    Context 'ostrzeżenie „to ten komputer”' {
        It 'nazwa tego komputera, adres pętli albo adres LAN tego komputera — ostrzeżenie bez blokady' {
            Mock -ModuleName MWP.Remote Get-MwpLocalNetworkAddress { [pscustomobject]@{ AllAddresses = @('192.0.2.77'); PrimaryAddress = '192.0.2.77' } }
            (Test-MwpTargetIsLocalComputer -Name $env:COMPUTERNAME).IsLocalComputer | Should -BeTrue
            (Test-MwpTargetIsLocalComputer -Name 'PC-INNY' -Address '192.0.2.77').IsLocalComputer | Should -BeTrue
            (Test-MwpTargetIsLocalComputer -Name 'PC-INNY' -Address '127.0.0.2').IsLocalComputer | Should -BeTrue
            $other = Test-MwpTargetIsLocalComputer -Name 'PC-INNY' -Address '192.0.2.78'
            $other.IsLocalComputer | Should -BeFalse
            $other.Message | Should -Be ''

            $result = Add-MwpTarget -Name 'PC-INNY' -Address '192.0.2.77' -Confirm:$false
            $result.Success | Should -BeTrue
            $result.Message | Should -Match 'localhost'
            (Get-MwpTarget -Name 'PC-INNY').IsLocal | Should -BeFalse
        }
    }

    Context 'zmiana nazwy (Set-MwpTarget -NewName)' {
        BeforeEach {
            Write-TestSetting -Target @(
                @{ name = '192.0.2.40'; displayName = '192.0.2.40'; userName = 'admin' }
                @{ name = 'PC-NAZWA' }
            ) -Widget @(
                @{ id = 'w1'; moduleId = 'Dashboard'; widgetId = 'SystemInfo'; computerName = '192.0.2.40'; refreshSeconds = 60; size = 'Wide' }
                @{ id = 'w2'; moduleId = 'Dashboard'; widgetId = 'SystemInfo'; computerName = 'localhost'; refreshSeconds = 60; size = 'Wide' }
            )
            $null = Save-MwpUndoEntry -Module 'MWP.Test' -Operation 'Test.Change' -Target 'element' -ComputerName '192.0.2.40' -UndoCommand 'Set-MwpSetting'
            $store.Entries['MWP:192.0.2.40'] = @{ UserName = 'admin'; Password = $credential.Password.Copy() }
            InModuleScope MWP.Remote -Parameters @{ C = $credential } { param($C) $null = Set-MwpCachedCredential -ComputerName '192.0.2.40' -Credential $C -Source Dialog }
        }

        It 'przenosi wpis (stary IP → adres), hasło, pamięć procesu, widgety i wpisy cofnięcia; hasło nie trafia do logu ani wyniku' {
            $result = Set-MwpTarget -Name '192.0.2.40' -NewName 'PC-BIURO' -Confirm:$false

            $result.Success | Should -BeTrue
            $result.Data.Moved.Credential | Should -BeTrue
            $result.Data.Moved.Widgets | Should -Be 1
            $result.Data.Moved.UndoEntries | Should -Be 1
            $result.Data.Moved.CachedCredential | Should -BeTrue
            $target = Get-MwpTarget -Name 'PC-BIURO'
            $target.Address | Should -Be '192.0.2.40'
            $target.ConnectionAddress | Should -Be '192.0.2.40'
            $target.DisplayName | Should -Be 'PC-BIURO'
            @(Get-MwpTarget).Name | Should -Not -Contain '192.0.2.40'
            $store.Entries.ContainsKey('MWP:PC-BIURO') | Should -BeTrue
            $store.Entries.ContainsKey('MWP:192.0.2.40') | Should -BeFalse
            InModuleScope MWP.Remote { (Get-MwpCachedCredential -ComputerName 'PC-BIURO')['State'] } | Should -Be 'Verified'
            InModuleScope MWP.Remote { Get-MwpCachedCredential -ComputerName '192.0.2.40' } | Should -BeNullOrEmpty
            $widgets = @(Get-MwpSetting -Name 'dashboardWidgets')
            ($widgets | Where-Object { $_['id'] -eq 'w1' })['computerName'] | Should -Be 'PC-BIURO'
            ($widgets | Where-Object { $_['id'] -eq 'w2' })['computerName'] | Should -Be 'localhost'
            @(Get-MwpUndoEntry -ComputerName 'PC-BIURO').Count | Should -Be 1
            @(Get-MwpUndoEntry -ComputerName '192.0.2.40').Count | Should -Be 0
            ($result | ConvertTo-Json -Depth 8) | Should -Not -Match ([regex]::Escape($secretText))
            Get-LogText | Should -Not -Match ([regex]::Escape($secretText))
        }

        It 'nowy kontekst używa nowej nazwy i łączy się pod stary adres bez pytania o hasło' {
            $null = Set-MwpTarget -Name '192.0.2.40' -NewName 'PC-BIURO' -Confirm:$false
            Mock -ModuleName MWP.Remote Get-MwpRemoteIdentity { New-Identity -ComputerName 'PC-BIURO' -Address '192.0.2.40' }
            $context = New-MwpExecutionContext -ComputerName 'PC-BIURO'
            $result = Connect-MwpTarget -Context $context
            $result.Success | Should -BeTrue
            $result.Data.CredentialSource | Should -Be 'Cache'
            Should -Invoke New-MwpPSSession -ModuleName MWP.Remote -Times 1 -Exactly -ParameterFilter { $ComputerName -eq '192.0.2.40' }
        }

        It '-WhatIf: podgląd z podsumowaniem, bez zmian' {
            $before = Get-Content -LiteralPath $localPath -Raw
            $result = Set-MwpTarget -Name '192.0.2.40' -NewName 'PC-BIURO' -WhatIf
            $result.IsPreview | Should -BeTrue
            $result.Message | Should -Match 'widgety Pulpitu: 1'
            $result.Message | Should -Match 'zapisane hasło: tak'
            Get-Content -LiteralPath $localPath -Raw | Should -Be $before
            $store.Entries.ContainsKey('MWP:PC-BIURO') | Should -BeFalse
            @(Get-MwpUndoEntry -ComputerName '192.0.2.40').Count | Should -Be 1
        }

        It 'odmowa: nazwa zajęta, nazwa lokalna, niepoprawna nazwa' {
            (Set-MwpTarget -Name '192.0.2.40' -NewName 'PC-NAZWA' -Confirm:$false).Message | Should -Match 'już w rejestrze'
            (Set-MwpTarget -Name '192.0.2.40' -NewName 'localhost' -Confirm:$false).Message | Should -Match 'lokalny'
            (Set-MwpTarget -Name '192.0.2.40' -NewName 'zla nazwa' -Confirm:$false).Success | Should -BeFalse
            (Get-MwpTarget -Name '192.0.2.40') | Should -Not -BeNullOrEmpty
        }

        It 'odmowa przy otwartej instancji modułu lub widgetu tego komputera' {
            InModuleScope MWP.Remote {
                $script:MwpInstanceRegistry['test-instancja'] = [pscustomobject]@{ Id = 'test-instancja'; Context = [pscustomobject]@{ ComputerName = '192.0.2.40' } }
            }
            try {
                $result = Set-MwpTarget -Name '192.0.2.40' -NewName 'PC-BIURO' -Confirm:$false
                $result.Success | Should -BeFalse
                $result.Message | Should -Match 'otwarte instancje'
                $store.Entries.ContainsKey('MWP:192.0.2.40') | Should -BeTrue
            }
            finally {
                InModuleScope MWP.Remote { $script:MwpInstanceRegistry.Remove('test-instancja') }
            }
        }

        It 'nieudany zapis hasła: nic nie jest zmieniane, hasło zostaje w starym wpisie' {
            $store.FailWrite = $true
            $before = Get-Content -LiteralPath $localPath -Raw
            $result = Set-MwpTarget -Name '192.0.2.40' -NewName 'PC-BIURO' -Confirm:$false
            $result.Success | Should -BeFalse
            Get-Content -LiteralPath $localPath -Raw | Should -Be $before
            $store.Entries.ContainsKey('MWP:192.0.2.40') | Should -BeTrue
        }

        It 'nieudany zapis ustawień: kopia hasła jest wycofana, stary wpis zostaje' {
            Mock -ModuleName MWP.Remote Set-MwpSetting { New-MwpResult -Operation 'Settings.Set' -Target 'targets' -Success $false -Message 'dysk pełny' }
            $result = Set-MwpTarget -Name '192.0.2.40' -NewName 'PC-BIURO' -Confirm:$false
            $result.Success | Should -BeFalse
            $result.Message | Should -Match 'dysk pełny'
            $store.Entries.ContainsKey('MWP:PC-BIURO') | Should -BeFalse
            $store.Entries.ContainsKey('MWP:192.0.2.40') | Should -BeTrue
            (Get-MwpTarget -Name '192.0.2.40') | Should -Not -BeNullOrEmpty
        }

        It 'zmiana nazwy nie tworzy wpisu cofnięcia' {
            $null = Set-MwpTarget -Name '192.0.2.40' -NewName 'PC-BIURO' -Confirm:$false
            @(Get-MwpUndoEntry | Where-Object { $_.Operation -like 'Settings.*' -or $_.Operation -like 'Remote.*' }).Count | Should -Be 0
        }
    }
}
