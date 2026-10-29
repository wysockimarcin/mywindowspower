#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
    Testy zapamiętywania poświadczeń (D-052): adapter Menedżera poświadczeń Windows, pamięć podręczna
    procesu, kolejność pamięć → magazyn → okno, blokada ponowień po odmowie dostępu, izolacja komputerów,
    przełącznik remoteCredentialStore i brak wycieku hasła. Warstwa P/Invoke (Invoke-MwpCredentialApi)
    jest zastąpiona symulatorem magazynu, a adapter transportu (New-MwpPSSession) — symulatorem logowania
    z licznikiem prób: testy nie dotykają prawdziwego magazynu i nie łączą się z żadnym komputerem.
    Hasło testowe jest sztuczne i istnieje tylko w testach.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Zmienne z bloków BeforeDiscovery/BeforeAll są używane w blokach It (zakresy Pestera).')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingComputerNameHardcoded', '',
    Justification = 'Sztuczne nazwy komputerów testowych (PC-TEST1, PC-HASLO); testy nie łączą się z żadnym komputerem.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
    Justification = 'Pomocnicze funkcje testów tworzą tylko obiekty w pamięci.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', '',
    Justification = 'Sztuczne hasło testowe; testy nie używają prawdziwych haseł.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingUsernameAndPasswordParams', '',
    Justification = 'Pomocnicze funkcje testów budują PSCredential ze sztucznego hasła.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '',
    Justification = 'Funkcje testowe mają sygnaturę kontraktu widgetu, także gdy nie używają wszystkich parametrów.')]
param()

Describe 'Zapamiętywanie poświadczeń komputerów zdalnych (D-052)' {
    BeforeAll {
        $root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
        Import-Module -Name (Join-Path -Path $root -ChildPath 'src\Modules\MWP.Core\MWP.Core.psd1') -Force
        $remote = Import-Module -Name (Join-Path -Path $root -ChildPath 'src\Modules\MWP.Remote\MWP.Remote.psd1') -Force -PassThru
        $configDirectory = Join-Path -Path $TestDrive -ChildPath 'config'
        $null = New-Item -ItemType Directory -Path $configDirectory -Force
        Copy-Item -LiteralPath (Join-Path -Path $root -ChildPath 'config\settings.example.json') -Destination (Join-Path -Path $configDirectory -ChildPath 'settings.example.json')
        $localSettings = Join-Path -Path $configDirectory -ChildPath 'settings.local.json'
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
        function Write-TestSetting {
            param([bool] $StoreEnabled = $true)
            $local = [ordered]@{
                schemaVersion         = 2
                logLevel              = 'Debug'
                remoteCredentialStore = $StoreEnabled
                targets               = @(
                    @{ name = 'PC-TEST1'; userName = 'PC-TEST1\admin' }
                    @{ name = 'PC-TEST2' }
                    @{ name = 'PC-DOMENA'; authentication = 'CurrentUser' }
                )
            }
            ConvertTo-Json -InputObject $local -Depth 5 | Set-Content -LiteralPath $localSettings -Encoding UTF8
        }

        $secretText = 'Test-Hasło-Nie-Ujawniać!'
        function New-TestCredential {
            param([string] $User = 'admin', [string] $Password = $secretText)
            $secure = New-Object -TypeName Security.SecureString
            $Password.ToCharArray() | ForEach-Object { $secure.AppendChar($_) }
            $secure.MakeReadOnly()
            New-Object -TypeName Management.Automation.PSCredential -ArgumentList $User, $secure
        }
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
        function Get-AttemptCount {
            param([string] $ComputerName)
            @($simulator.Attempts | Where-Object { $_ -eq $ComputerName }).Count
        }

        # Symulator: magazyn (wpisy MWP:<komputer>, wywołania API, wymuszony kod błędu) i logowanie
        # (aktualne hasło komputera zdalnego; zła wartość = odmowa dostępu, kod 5).
        $simulator = @{
            Entries   = @{}
            Calls     = New-Object -TypeName System.Collections.Generic.List[string]
            Attempts  = New-Object -TypeName System.Collections.Generic.List[string]
            Passwords = @{}
            ErrorCode = 0
        }
        Mock -ModuleName MWP.Remote Invoke-MwpCredentialApi {
            $action = $PesterBoundParameters['Action']
            $name = $PesterBoundParameters['TargetName']
            $simulator.Calls.Add(('{0}:{1}' -f $action, $name))
            if ($simulator.ErrorCode -ne 0) {
                return [pscustomobject]@{ ErrorCode = $simulator.ErrorCode; UserName = $null; Password = $null; LastWritten = [datetime]::MinValue; BlobSize = 0 }
            }
            switch ($action) {
                'Read' {
                    $entry = $simulator.Entries[$name]
                    if ($null -eq $entry) {
                        return [pscustomobject]@{ ErrorCode = 1168; UserName = $null; Password = $null; LastWritten = [datetime]::MinValue; BlobSize = 0 }
                    }
                    $password = $null
                    if ($PesterBoundParameters['IncludePassword'] -and $null -ne $entry.Password) {
                        $password = $entry.Password.Copy()
                    }
                    [pscustomobject]@{ ErrorCode = 0; UserName = $entry.UserName; Password = $password; LastWritten = $entry.LastWritten; BlobSize = $entry.BlobSize }
                }
                'Write' {
                    $secure = $PesterBoundParameters['Password']
                    $simulator.Entries[$name] = @{ UserName = $PesterBoundParameters['UserName']; Password = $secure.Copy(); LastWritten = Get-Date; BlobSize = $secure.Length * 2 }
                    [pscustomobject]@{ ErrorCode = 0 }
                }
                'Delete' {
                    if ($simulator.Entries.ContainsKey($name)) {
                        $simulator.Entries.Remove($name)
                        return [pscustomobject]@{ ErrorCode = 0 }
                    }
                    [pscustomobject]@{ ErrorCode = 1168 }
                }
            }
        }
        Mock -ModuleName MWP.Remote New-MwpPSSession {
            $computer = $PesterBoundParameters['ComputerName']
            $simulator.Attempts.Add($computer)
            $given = $PesterBoundParameters['Credential']
            $expected = $simulator.Passwords[$computer]
            if ($null -ne $given -and $null -ne $expected -and $given.GetNetworkCredential().Password -ne $expected) {
                throw (Get-TransportError -Message 'Access is denied.' -Code 5)
            }
            [pscustomobject]@{ ComputerName = $computer; State = 'Opened' }
        }
        Mock -ModuleName MWP.Remote Remove-MwpPSSession { }
        Mock -ModuleName MWP.Remote Remove-MwpCimSession { }
        Mock -ModuleName MWP.Remote Invoke-MwpSessionCommand { [pscustomobject]@{ Output = @('wynik'); Errors = @() } }

        function Add-StoredEntry {
            param([string] $ComputerName, [string] $User = 'PC-TEST1\admin', [string] $Password = $secretText)
            $credential = New-TestCredential -User $User -Password $Password
            $simulator.Entries['MWP:{0}' -f $ComputerName] = @{ UserName = $User; Password = $credential.Password.Copy(); LastWritten = (Get-Date).AddDays(-1); BlobSize = $Password.Length * 2 }
        }
    }

    AfterAll {
        Clear-MwpTargetCredentialCache
        Remove-Module -Name MWP.Remote, MWP.Core -Force -ErrorAction SilentlyContinue
    }

    BeforeEach {
        Clear-MwpTargetCredentialCache
        $simulator.Entries.Clear()
        $simulator.Calls.Clear()
        $simulator.Attempts.Clear()
        $simulator.Passwords.Clear()
        $simulator.Passwords['PC-TEST1'] = $secretText
        $simulator.Passwords['PC-TEST2'] = $secretText
        $simulator.ErrorCode = 0
        Write-TestSetting
    }

    Context 'adapter magazynu (mock warstwy P/Invoke)' {
        It 'zapis i odczyt: wpis MWP:komputer, konto i hasło w SecureString' {
            $write = & $remote { param($c) Set-MwpStoredCredential -ComputerName 'PC-TEST1' -Credential $c } (New-TestCredential -User 'PC-TEST1\admin')
            $read = & $remote { Get-MwpStoredCredential -ComputerName 'PC-TEST1' }

            $write.Success | Should -BeTrue
            $write.Entry | Should -Be 'MWP:PC-TEST1'
            $read.Status | Should -Be 'Found'
            $read.Credential | Should -BeOfType ([pscredential])
            $read.Credential.UserName | Should -Be 'PC-TEST1\admin'
            $read.Credential.GetNetworkCredential().Password | Should -Be $secretText
            $read.LastWritten | Should -BeOfType ([datetime])
            $read.Message | Should -Not -Match ([regex]::Escape($secretText))
        }

        It 'brak wpisu: NotFound (kod 1168), bez wyjątku' {
            $read = & $remote { Get-MwpStoredCredential -ComputerName 'PC-TEST2' }

            $read.Status | Should -Be 'NotFound'
            $read.Credential | Should -BeNullOrEmpty
        }

        It 'błąd Win32: wynik Error z kodem i komunikatem, bez wyjątku (odczyt, zapis, usunięcie)' {
            $simulator.ErrorCode = 5

            $read = & $remote { Get-MwpStoredCredential -ComputerName 'PC-TEST1' }
            $write = & $remote { param($c) Set-MwpStoredCredential -ComputerName 'PC-TEST1' -Credential $c } (New-TestCredential)
            $remove = & $remote { Remove-MwpStoredCredential -ComputerName 'PC-TEST1' }

            $read.Status | Should -Be 'Error'
            $read.ErrorCode | Should -Be 5
            $read.Message | Should -Match 'kod 5'
            $write.Success | Should -BeFalse
            $remove.Success | Should -BeFalse
            $remove.Removed | Should -BeFalse
        }

        It 'wyjątek warstwy P/Invoke (np. kompilacja typu): wynik Error, bez wyjątku' {
            Mock -ModuleName MWP.Remote Invoke-MwpCredentialApi { throw 'Add-Type nie powiódł się' }

            $read = & $remote { Get-MwpStoredCredential -ComputerName 'PC-TEST1' }
            $remove = & $remote { Remove-MwpStoredCredential -ComputerName 'PC-TEST1' }

            $read.Status | Should -Be 'Error'
            $read.Message | Should -Match 'Add-Type'
            $remove.Success | Should -BeFalse
        }

        It 'zły format wpisu (brak konta, blob o nieparzystej długości): InvalidFormat, wpis nieużywany' {
            $simulator.Entries['MWP:PC-TEST1'] = @{ UserName = ''; Password = (New-TestCredential).Password; LastWritten = Get-Date; BlobSize = 10 }
            $simulator.Entries['MWP:PC-TEST2'] = @{ UserName = 'admin'; Password = (New-TestCredential).Password; LastWritten = Get-Date; BlobSize = 3 }

            (& $remote { Get-MwpStoredCredential -ComputerName 'PC-TEST1' }).Status | Should -Be 'InvalidFormat'
            (& $remote { Get-MwpStoredCredential -ComputerName 'PC-TEST2' }).Status | Should -Be 'InvalidFormat'
            (& $remote { Get-MwpStoredCredential -ComputerName 'PC-TEST2' }).Credential | Should -BeNullOrEmpty
        }

        It 'usunięcie: istniejący wpis Removed, brak wpisu to sukces bez usunięcia' {
            Add-StoredEntry -ComputerName 'PC-TEST1'

            $first = & $remote { Remove-MwpStoredCredential -ComputerName 'PC-TEST1' }
            $second = & $remote { Remove-MwpStoredCredential -ComputerName 'PC-TEST1' }

            $first.Success | Should -BeTrue
            $first.Removed | Should -BeTrue
            $second.Success | Should -BeTrue
            $second.Removed | Should -BeFalse
        }

        It 'Test-MwpStoredCredential czyta tylko metadane (bez hasła)' {
            Add-StoredEntry -ComputerName 'PC-TEST1'

            $info = & $remote { Test-MwpStoredCredential -ComputerName 'PC-TEST1' }

            $info.Status | Should -Be 'Found'
            $info.UserName | Should -Be 'PC-TEST1\admin'
            $info.Credential | Should -BeNullOrEmpty
            Should -Invoke Invoke-MwpCredentialApi -ModuleName MWP.Remote -Times 1 -Exactly -ParameterFilter { $Action -eq 'Read' -and -not $IncludePassword }
        }

        It 'typ P/Invoke kompiluje się raz; ponowny import modułu używa tego samego typu (bez dotykania magazynu)' {
            $type = & $remote { Initialize-MwpCredentialType }
            $again = & $remote { Initialize-MwpCredentialType }

            $type.FullName | Should -Be 'MwpRemote.CredentialApiV1'
            $again | Should -Be $type
            @($type.GetMethods() | Where-Object { $_.IsPublic -and $_.IsStatic -and $_.DeclaringType -eq $type } | ForEach-Object { $_.Name } | Sort-Object) -join ',' | Should -Be 'Delete,Read,Write'
        }
    }

    Context 'funkcje publiczne: zapis, metadane, „Zapomnij hasło”, usunięcie komputera' {
        It 'Save-MwpTargetCredential -WhatIf: podgląd bez zapisu' {
            $result = Save-MwpTargetCredential -Name 'PC-TEST1' -Credential (New-TestCredential) -WhatIf

            $result.IsPreview | Should -BeTrue
            $simulator.Entries.Count | Should -Be 0
        }

        It 'Save-MwpTargetCredential zapisuje wpis i loguje konto, bez hasła i bez wpisu cofnięcia' {
            $result = Save-MwpTargetCredential -Name 'PC-TEST1' -Credential (New-TestCredential -User 'PC-TEST1\admin') -Confirm:$false

            $result.Success | Should -BeTrue
            $result.UndoId | Should -BeNullOrEmpty
            $simulator.Entries.ContainsKey('MWP:PC-TEST1') | Should -BeTrue
            Get-LogText | Should -Match 'Remote.SaveCredential'
            Get-LogText | Should -Not -Match ([regex]::Escape($secretText))
        }

        It 'Save-MwpTargetCredential odmawia dla localhost, komputera spoza rejestru i przy wyłączonym zapamiętywaniu' {
            (Save-MwpTargetCredential -Name 'localhost' -Credential (New-TestCredential) -Confirm:$false).Success | Should -BeFalse
            (Save-MwpTargetCredential -Name 'PC-NIEZNANY' -Credential (New-TestCredential) -Confirm:$false).Success | Should -BeFalse
            Write-TestSetting -StoreEnabled $false
            $disabled = Save-MwpTargetCredential -Name 'PC-TEST1' -Credential (New-TestCredential) -Confirm:$false

            $disabled.Success | Should -BeFalse
            $disabled.Message | Should -Match 'wyłączone'
            $simulator.Entries.Count | Should -Be 0
        }

        It 'Get-MwpTargetCredentialInfo zwraca tylko metadane; -SkipStore nie czyta magazynu' {
            Add-StoredEntry -ComputerName 'PC-TEST1'

            $info = Get-MwpTargetCredentialInfo -Name 'PC-TEST1'
            $simulator.Calls.Clear()
            $memory = Get-MwpTargetCredentialInfo -Name 'PC-TEST1' -SkipStore

            $info.Stored | Should -BeTrue
            $info.StoredUserName | Should -Be 'PC-TEST1\admin'
            $info.StoreEnabled | Should -BeTrue
            $info.Entry | Should -Be 'MWP:PC-TEST1'
            @($info.PSObject.Properties.Name | Where-Object { $_ -match 'Password|Credential$|Secure' }) | Should -BeNullOrEmpty
            $memory.Stored | Should -BeNullOrEmpty
            $simulator.Calls.Count | Should -Be 0
        }

        It 'bez nazwy: metadane wszystkich komputerów zdalnych z rejestru' {
            $all = @(Get-MwpTargetCredentialInfo)

            @($all.ComputerName) | Should -Be @('PC-TEST1', 'PC-TEST2', 'PC-DOMENA')
        }

        It 'Remove-MwpTargetCredential usuwa wpis z magazynu i hasło z pamięci' {
            Add-StoredEntry -ComputerName 'PC-TEST1'
            $context = New-MwpExecutionContext -ComputerName 'PC-TEST1'
            $null = Connect-MwpTarget -Context $context -UseStoredCredential

            $result = Remove-MwpTargetCredential -Name 'PC-TEST1' -Confirm:$false
            $info = Get-MwpTargetCredentialInfo -Name 'PC-TEST1'

            $result.Success | Should -BeTrue
            $result.Changed | Should -BeTrue
            $info.Stored | Should -BeFalse
            $info.Cached | Should -BeFalse
            $info.Invalid | Should -BeFalse
        }

        It 'Remove-MwpTarget usuwa też zapisane hasło komputera (wpis cofnięcia bez hasła)' {
            Add-StoredEntry -ComputerName 'PC-TEST2'

            $result = Remove-MwpTarget -Name 'PC-TEST2' -Confirm:$false

            $result.Success | Should -BeTrue
            $result.Message | Should -Match 'Menedżera poświadczeń'
            $simulator.Entries.ContainsKey('MWP:PC-TEST2') | Should -BeFalse
            Should -Invoke Invoke-MwpCredentialApi -ModuleName MWP.Remote -Times 1 -Exactly -ParameterFilter { $Action -eq 'Delete' -and $TargetName -eq 'MWP:PC-TEST2' }
        }

        It 'Remove-MwpTarget -WhatIf nie usuwa wpisu z magazynu' {
            Add-StoredEntry -ComputerName 'PC-TEST2'

            $null = Remove-MwpTarget -Name 'PC-TEST2' -WhatIf

            $simulator.Entries.ContainsKey('MWP:PC-TEST2') | Should -BeTrue
        }
    }

    Context 'kolejność: pamięć procesu → magazyn → okno (warstwa UI)' {
        It 'magazyn jest czytany tylko przy jawnym „Połącz” (-UseStoredCredential), nie przy łączeniu w tle' {
            Add-StoredEntry -ComputerName 'PC-TEST1'
            $context = New-MwpExecutionContext -ComputerName 'PC-TEST1'

            $background = Connect-MwpTarget -Context $context

            $background.Success | Should -BeFalse
            $background.Data.ErrorKind | Should -Be 'CredentialRequired'
            @($simulator.Calls | Where-Object { $_ -like 'Read:*' }).Count | Should -Be 0
            Get-AttemptCount -ComputerName 'PC-TEST1' | Should -Be 0
        }

        It 'hasło z magazynu: połączenie bez okna, potem wspólne dla innych instancji i widgetów bez drugiego odczytu' {
            Add-StoredEntry -ComputerName 'PC-TEST1'
            $first = New-MwpExecutionContext -ComputerName 'PC-TEST1'
            $second = New-MwpExecutionContext -ComputerName 'PC-TEST1'
            $widget = New-MwpExecutionContext -ComputerName 'PC-TEST1'

            $connect = Connect-MwpTarget -Context $first -UseStoredCredential
            $again = Connect-MwpTarget -Context $second -UseStoredCredential
            $state = & $remote { param($c) Resolve-MwpConnectionCredential -Context $c } $widget

            $connect.Success | Should -BeTrue
            $connect.Data.CredentialSource | Should -Be 'Store'
            $again.Data.CredentialSource | Should -Be 'Cache'
            $state.UserName | Should -Be 'PC-TEST1\admin'
            @($simulator.Calls | Where-Object { $_ -like 'Read:*' }).Count | Should -Be 1
            (Get-MwpTargetCredentialInfo -Name 'PC-TEST1' -SkipStore).Cached | Should -BeTrue
        }

        It 'hasło podane w oknie (-Credential) trafia do pamięci procesu dla innych kontekstów komputera' {
            $first = New-MwpExecutionContext -ComputerName 'PC-TEST1'
            $second = New-MwpExecutionContext -ComputerName 'PC-TEST1'

            $null = Connect-MwpTarget -Context $first -Credential (New-TestCredential -User 'PC-TEST1\admin')
            $result = Connect-MwpTarget -Context $second

            $result.Success | Should -BeTrue
            $result.Data.CredentialSource | Should -Be 'Cache'
            @($simulator.Calls | Where-Object { $_ -like 'Read:*' }).Count | Should -Be 0
        }

        It 'brak wpisu w magazynie: CredentialRequired bez próby logowania (warstwa UI pokaże okno)' {
            $context = New-MwpExecutionContext -ComputerName 'PC-TEST1'

            $result = Connect-MwpTarget -Context $context -UseStoredCredential

            $result.Success | Should -BeFalse
            $result.Data.ErrorKind | Should -Be 'CredentialRequired'
            Get-AttemptCount -ComputerName 'PC-TEST1' | Should -Be 0
        }

        It 'zapis tylko po jawnej zgodzie: bez -SaveCredential nic nie trafia do magazynu' {
            $context = New-MwpExecutionContext -ComputerName 'PC-TEST1'

            $result = Connect-MwpTarget -Context $context -Credential (New-TestCredential)

            $result.Data.CredentialSaved | Should -BeFalse
            $simulator.Entries.Count | Should -Be 0
            @($simulator.Calls | Where-Object { $_ -like 'Write:*' }).Count | Should -Be 0
        }

        It '-SaveCredential zapisuje dopiero po udanym połączeniu; złe hasło nie trafia do magazynu' {
            $bad = New-MwpExecutionContext -ComputerName 'PC-TEST1'
            $good = New-MwpExecutionContext -ComputerName 'PC-TEST1'

            $failed = Connect-MwpTarget -Context $bad -Credential (New-TestCredential -Password 'zle-haslo') -SaveCredential
            $simulator.Entries.Count | Should -Be 0
            $saved = Connect-MwpTarget -Context $good -Credential (New-TestCredential -User 'PC-TEST1\admin') -SaveCredential

            $failed.Success | Should -BeFalse
            $saved.Success | Should -BeTrue
            $saved.Data.CredentialSaved | Should -BeTrue
            $simulator.Entries['MWP:PC-TEST1'].UserName | Should -Be 'PC-TEST1\admin'
        }

        It 'przełącznik wyłączony: -UseStoredCredential nie czyta magazynu' {
            Add-StoredEntry -ComputerName 'PC-TEST1'
            Write-TestSetting -StoreEnabled $false
            $context = New-MwpExecutionContext -ComputerName 'PC-TEST1'

            $result = Connect-MwpTarget -Context $context -UseStoredCredential -SaveCredential

            $result.Success | Should -BeFalse
            $result.Message | Should -Match 'wyłączone'
            @($simulator.Calls | Where-Object { $_ -like 'Read:*' }).Count | Should -Be 0
            (Get-MwpTargetCredentialInfo -Name 'PC-TEST1').StoreEnabled | Should -BeFalse
        }

        It 'przełącznik: domyślnie włączony (szablon), wyłączony tylko wartością false' {
            Set-Content -LiteralPath $localSettings -Value '{ "schemaVersion": 2, "targets": [] }' -Encoding UTF8

            & $remote { Test-MwpCredentialStoreEnabled } | Should -BeTrue
            Write-TestSetting -StoreEnabled $false
            & $remote { Test-MwpCredentialStoreEnabled } | Should -BeFalse
        }
    }

    Context 'blokada ponowień po odmowie dostępu (ochrona konta przed blokadą)' {
        It 'nieaktualne hasło z magazynu: jedna próba, potem brak prób dla wszystkich instancji i widgetów komputera' {
            Add-StoredEntry -ComputerName 'PC-TEST1'
            $simulator.Passwords['PC-TEST1'] = 'haslo-zmienione-na-komputerze'
            $contexts = @(1..5 | ForEach-Object { New-MwpExecutionContext -ComputerName 'PC-TEST1' })

            $first = Connect-MwpTarget -Context $contexts[0] -UseStoredCredential
            $others = @($contexts[1..4] | ForEach-Object { Connect-MwpTarget -Context $_ -UseStoredCredential })
            $background = @($contexts | ForEach-Object { Connect-MwpTarget -Context $_ })
            $operations = @($contexts | ForEach-Object { Start-MwpOperation -Context $_ -ScriptBlock { 'odczyt' } })

            Get-AttemptCount -ComputerName 'PC-TEST1' | Should -Be 1
            $first.Data.ErrorKind | Should -Be 'Unauthorized'
            $first.Message | Should -Match 'Menedżerze poświadczeń'
            @($others | Where-Object { $_.Success }).Count | Should -Be 0
            @($others | ForEach-Object { $_.Data.ErrorKind } | Sort-Object -Unique) | Should -Be @('CredentialRequired')
            @($background | Where-Object { $_.Success }).Count | Should -Be 0
            @($operations | ForEach-Object { $_.Status } | Sort-Object -Unique) | Should -Be @('Failed')
            @($operations | ForEach-Object { $_.Result.Data['ErrorKind'] } | Sort-Object -Unique) | Should -Be @('CredentialRequired')
            @($operations | Where-Object { $null -ne $_.PowerShell }).Count | Should -Be 0
            (Get-MwpTargetCredentialInfo -Name 'PC-TEST1' -SkipStore).Invalid | Should -BeTrue
        }

        It 'wpis w magazynie jest tylko unieważniony w tym uruchomieniu, nie usunięty (decyzja użytkownika)' {
            Add-StoredEntry -ComputerName 'PC-TEST1'
            $simulator.Passwords['PC-TEST1'] = 'inne'
            $context = New-MwpExecutionContext -ComputerName 'PC-TEST1'

            $null = Connect-MwpTarget -Context $context -UseStoredCredential
            $info = Get-MwpTargetCredentialInfo -Name 'PC-TEST1'

            $info.Stored | Should -BeTrue
            $info.Invalid | Should -BeTrue
            @($simulator.Calls | Where-Object { $_ -like 'Delete:*' }).Count | Should -Be 0
            Get-LogText | Should -Match 'Remote.CredentialRejected'
        }

        It 'odmowa w operacji w tle (Wait-MwpOperation) unieważnia hasło wspólne: kolejne operacje i połączenia bez prób' {
            $first = New-MwpExecutionContext -ComputerName 'PC-TEST1'
            $second = New-MwpExecutionContext -ComputerName 'PC-TEST1'
            $null = Connect-MwpTarget -Context $first -Credential (New-TestCredential)
            $null = Connect-MwpTarget -Context $second
            Get-AttemptCount -ComputerName 'PC-TEST1' | Should -Be 2
            $generation = [int]$second.Connection.CredentialGeneration
            # Operacja widgetu kończy się odmową dostępu (hasło zmieniono na komputerze zdalnym).
            $powerShell = [powershell]::Create()
            $null = $powerShell.AddScript({ throw (New-Object -TypeName Management.Automation.Remoting.PSRemotingTransportException -ArgumentList 'Access is denied.') })
            $handle = [pscustomobject]@{
                PSTypeName = 'MWP.Operation'; Id = [guid]::NewGuid().ToString(); Operation = 'Widget.Test'; ComputerName = 'PC-TEST1'; Port = 5985
                InstanceId = $null; ContextId = $second.Id; StartedAt = Get-Date; CompletedAt = $null; TimeoutSeconds = 30; Status = 'Running'
                Result = $null; PowerShell = $powerShell; AsyncResult = $powerShell.BeginInvoke(); CredentialGeneration = $generation
            }

            $failed = Wait-MwpOperation -Operation $handle
            $later = Start-MwpOperation -Context $first -ScriptBlock { 'odczyt' }
            $reconnect = Connect-MwpTarget -Context (New-MwpExecutionContext -ComputerName 'PC-TEST1')

            $failed.Data['ErrorKind'] | Should -Be 'Unauthorized'
            $later.Status | Should -Be 'Failed'
            $later.Result.Data['ErrorKind'] | Should -Be 'CredentialRequired'
            $later.Result.Message | Should -Match 'wstrzymane'
            $reconnect.Success | Should -BeFalse
            Get-AttemptCount -ComputerName 'PC-TEST1' | Should -Be 2
            $first.Connection.Credential | Should -BeNullOrEmpty
        }

        It 'odmowa nieaktualnej generacji nie unieważnia nowszego hasła podanego przez użytkownika' {
            $context = New-MwpExecutionContext -ComputerName 'PC-TEST1'
            $null = Connect-MwpTarget -Context $context -Credential (New-TestCredential)
            $old = [int]$context.Connection.CredentialGeneration
            $null = Connect-MwpTarget -Context (New-MwpExecutionContext -ComputerName 'PC-TEST1') -Credential (New-TestCredential -User 'PC-TEST1\admin')

            & $remote { param($g) Set-MwpCachedCredentialInvalid -ComputerName 'PC-TEST1' -Generation $g } $old | Should -BeFalse
            (Get-MwpTargetCredentialInfo -Name 'PC-TEST1' -SkipStore).Cached | Should -BeTrue
        }

        It 'po odrzuceniu nowe hasło z okna znosi blokadę dla wszystkich kontekstów komputera' {
            Add-StoredEntry -ComputerName 'PC-TEST1' -Password 'stare'
            $waiting = New-MwpExecutionContext -ComputerName 'PC-TEST1'
            $null = Connect-MwpTarget -Context (New-MwpExecutionContext -ComputerName 'PC-TEST1') -UseStoredCredential

            $fresh = Connect-MwpTarget -Context (New-MwpExecutionContext -ComputerName 'PC-TEST1') -Credential (New-TestCredential)
            $resumed = Connect-MwpTarget -Context $waiting

            $fresh.Success | Should -BeTrue
            $resumed.Success | Should -BeTrue
            $resumed.Data.CredentialSource | Should -Be 'Cache'
            (Get-MwpTargetCredentialInfo -Name 'PC-TEST1' -SkipStore).Invalid | Should -BeFalse
        }

        It 'izolacja: odmowa na jednym komputerze nie zmienia poświadczeń drugiego' {
            $one = New-MwpExecutionContext -ComputerName 'PC-TEST1'
            $two = New-MwpExecutionContext -ComputerName 'PC-TEST2'
            $null = Connect-MwpTarget -Context $one -Credential (New-TestCredential)
            $null = Connect-MwpTarget -Context $two -Credential (New-TestCredential)
            Add-StoredEntry -ComputerName 'PC-TEST2'
            $simulator.Passwords['PC-TEST1'] = 'zmienione'
            $null = Disconnect-MwpTarget -Context $one -KeepCredential

            $null = Connect-MwpTarget -Context $one

            (Get-MwpTargetCredentialInfo -Name 'PC-TEST1' -SkipStore).Invalid | Should -BeTrue
            (Get-MwpTargetCredentialInfo -Name 'PC-TEST2' -SkipStore).Cached | Should -BeTrue
            $simulator.Entries.ContainsKey('MWP:PC-TEST2') | Should -BeTrue
            $two.Connection.Credential | Should -Not -BeNullOrEmpty
        }

        It 'Disconnect i zamknięcie instancji czyszczą tylko poświadczenie połączenia (magazyn i pamięć procesu zostają)' {
            Add-StoredEntry -ComputerName 'PC-TEST1'
            $context = New-MwpExecutionContext -ComputerName 'PC-TEST1'
            $null = Connect-MwpTarget -Context $context -UseStoredCredential

            $null = Disconnect-MwpTarget -Context $context

            $context.Connection.Credential | Should -BeNullOrEmpty
            $simulator.Entries.ContainsKey('MWP:PC-TEST1') | Should -BeTrue
            (Get-MwpTargetCredentialInfo -Name 'PC-TEST1' -SkipStore).Cached | Should -BeTrue
            @($simulator.Calls | Where-Object { $_ -like 'Delete:*' }).Count | Should -Be 0
        }

        It 'uwierzytelnienie CurrentUser nie używa magazynu ani pamięci poświadczeń' {
            $context = New-MwpExecutionContext -ComputerName 'PC-DOMENA'

            $result = Connect-MwpTarget -Context $context -UseStoredCredential

            $result.Success | Should -BeTrue
            $simulator.Calls.Count | Should -Be 0
            (Get-MwpTargetCredentialInfo -Name 'PC-DOMENA' -SkipStore).Cached | Should -BeFalse
        }
    }

    Context 'współbieżność (runspace''y procesu)' {
        It 'pamięć poświadczeń jest wspólna dla runspace''ów, a licznik generacji bez wyścigu' {
            $before = [int](& $remote { Get-MwpCredentialCache })['Generation']
            $jobs = foreach ($index in 1..4) {
                $powerShell = [powershell]::Create()
                $null = $powerShell.AddScript({
                        param($Root, $Index)
                        Import-Module -Name (Join-Path -Path $Root -ChildPath 'src\Modules\MWP.Core\MWP.Core.psd1')
                        $module = Import-Module -Name (Join-Path -Path $Root -ChildPath 'src\Modules\MWP.Remote\MWP.Remote.psd1') -PassThru
                        $secure = New-Object -TypeName Security.SecureString
                        'x'.ToCharArray() | ForEach-Object { $secure.AppendChar($_) }
                        $credential = New-Object -TypeName Management.Automation.PSCredential -ArgumentList "u$Index", $secure
                        foreach ($step in 1..50) {
                            $null = & $module { param($c, $n) Set-MwpCachedCredential -ComputerName ('PC-R{0}' -f $n) -Credential $c } $credential $Index
                        }
                    }).AddArgument($root).AddArgument($index)
                [pscustomobject]@{ PowerShell = $powerShell; Async = $powerShell.BeginInvoke() }
            }
            foreach ($job in $jobs) {
                $null = $job.PowerShell.EndInvoke($job.Async)
                $job.PowerShell.Dispose()
            }
            $cache = & $remote { Get-MwpCredentialCache }

            [int]$cache['Generation'] - $before | Should -Be 200
            @(1..4 | Where-Object { (Get-MwpTargetCredentialInfo -Name ('PC-R{0}' -f $_) -SkipStore).Cached }).Count | Should -Be 4
        }

        It 'blokada komputera: drugi chętny czeka, a po zwolnieniu ją dostaje (jedno odczytanie magazynu naraz)' {
            $taken = & $remote { Enter-MwpCredentialLock -ComputerName 'PC-TEST1' -TimeoutSeconds 1 }
            $powerShell = [powershell]::Create()
            $null = $powerShell.AddScript({
                    param($Root)
                    Import-Module -Name (Join-Path -Path $Root -ChildPath 'src\Modules\MWP.Core\MWP.Core.psd1')
                    $module = Import-Module -Name (Join-Path -Path $Root -ChildPath 'src\Modules\MWP.Remote\MWP.Remote.psd1') -PassThru
                    & $module { Enter-MwpCredentialLock -ComputerName 'PC-TEST1' -TimeoutSeconds 0 }
                }).AddArgument($root)
            $busy = @($powerShell.Invoke())[-1]
            & $remote { Exit-MwpCredentialLock -ComputerName 'PC-TEST1' }
            $free = & $remote { Enter-MwpCredentialLock -ComputerName 'PC-TEST1' -TimeoutSeconds 1 }
            & $remote { Exit-MwpCredentialLock -ComputerName 'PC-TEST1' }
            $powerShell.Dispose()

            $taken | Should -BeTrue
            $busy | Should -BeFalse
            $free | Should -BeTrue
        }

        It 'Connect-MwpTarget zwalnia blokadę także po błędzie odczytu magazynu' {
            $simulator.ErrorCode = 1312
            $context = New-MwpExecutionContext -ComputerName 'PC-TEST1'

            $result = Connect-MwpTarget -Context $context -UseStoredCredential
            $free = & $remote { Enter-MwpCredentialLock -ComputerName 'PC-TEST1' -TimeoutSeconds 0 }
            & $remote { Exit-MwpCredentialLock -ComputerName 'PC-TEST1' }

            $result.Success | Should -BeFalse
            $result.Message | Should -Match 'kod 1312'
            $free | Should -BeTrue
        }
    }

    Context 'brak wycieku hasła' {
        It 'hasło testowe nie pojawia się w logu, ustawieniach, rejestrze cofnięć, wynikach ani komunikatach' {
            $results = New-Object -TypeName System.Collections.Generic.List[object]
            $context = New-MwpExecutionContext -ComputerName 'PC-TEST1'
            $results.Add((Connect-MwpTarget -Context $context -Credential (New-TestCredential -User 'PC-TEST1\admin') -SaveCredential))
            $results.Add((Save-MwpTargetCredential -Name 'PC-TEST1' -Credential (New-TestCredential) -Confirm:$false))
            $results.Add((Get-MwpTargetCredentialInfo -Name 'PC-TEST1'))
            $simulator.Passwords['PC-TEST1'] = 'zmienione'
            $results.Add((Connect-MwpTarget -Context (New-MwpExecutionContext -ComputerName 'PC-TEST1') -Credential (New-TestCredential) -SaveCredential))
            Clear-MwpTargetCredentialCache
            $results.Add((Connect-MwpTarget -Context (New-MwpExecutionContext -ComputerName 'PC-TEST1') -UseStoredCredential))
            $results.Add((Start-MwpOperation -Context (New-MwpExecutionContext -ComputerName 'PC-TEST1') -ScriptBlock { 'x' }).Result)
            $results.Add((Remove-MwpTargetCredential -Name 'PC-TEST1' -Confirm:$false))
            $results.Add((Remove-MwpTarget -Name 'PC-TEST1' -Confirm:$false))

            $pattern = [regex]::Escape($secretText)
            Get-LogText | Should -Not -Match $pattern
            Get-Content -LiteralPath $localSettings -Raw -Encoding UTF8 | Should -Not -Match $pattern
            $undo = Join-Path -Path $TestDrive -ChildPath 'Undo'
            if (Test-Path -LiteralPath $undo) {
                (Get-ChildItem -LiteralPath $undo -File | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8 }) -join "`n" | Should -Not -Match $pattern
            }
            foreach ($item in $results) {
                ConvertTo-Json -InputObject $item -Depth 6 -WarningAction SilentlyContinue | Should -Not -Match $pattern
                if ($null -ne $item.PSObject.Properties['Message']) {
                    [string]$item.Message | Should -Not -Match $pattern
                }
            }
        }
    }
}
