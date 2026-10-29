#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
    Testy kontekstu wykonania New-MwpExecutionContext: tryb Local/Remote, niezmienność,
    tożsamość bez sekretów, parametry modułu i polityka limitów czasu (D-019).
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Zmienne z bloków BeforeDiscovery/BeforeAll są używane w blokach It (zakresy Pestera).')]
param()

Describe 'Kontekst wykonania' {
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
        $local = [ordered]@{
            schemaVersion                 = 2
            remoteConnectTimeoutSeconds   = 7
            remoteOperationTimeoutSeconds = 42
            targets                       = @(@{ name = $computerOne; displayName = 'Biuro'; userName = 'PC-TEST1\admin' })
        }
        ConvertTo-Json -InputObject $local -Depth 5 | Set-Content -LiteralPath (Join-Path -Path $configDirectory -ChildPath 'settings.local.json') -Encoding UTF8

        $secret = New-Object -TypeName Security.SecureString
        'TajneHaslo123'.ToCharArray() | ForEach-Object { $secret.AppendChar($_) }
        $credential = New-Object -TypeName Management.Automation.PSCredential -ArgumentList 'PC-TEST1\admin', $secret
    }

    AfterAll {
        Remove-Module -Name MWP.Remote, MWP.Core -Force -ErrorAction SilentlyContinue
    }

    It 'domyślnie dotyczy localhost w trybie Local, ze stanem połączenia Connected' {
        $context = New-MwpExecutionContext

        $context.PSObject.TypeNames | Should -Contain 'MWP.ExecutionContext'
        $context.ComputerName | Should -Be 'localhost'
        $context.Mode | Should -Be 'Local'
        $context.Transport | Should -Be 'Local'
        $context.Connection.State | Should -Be 'Connected'
        $context.Id | Should -Not -BeNullOrEmpty
    }

    It 'nazwa tego komputera i adres pętli oznaczają tryb Local' {
        (New-MwpExecutionContext -ComputerName $env:COMPUTERNAME).Mode | Should -Be 'Local'
        $loopback = '127.0.0.1'
        (New-MwpExecutionContext -ComputerName $loopback).ComputerName | Should -Be 'localhost'
    }

    It 'komputer zdalny z rejestru: tryb Remote, WinRM, stan Disconnected, polityka z ustawień' {
        $context = New-MwpExecutionContext -ComputerName $computerOne

        $context.Mode | Should -Be 'Remote'
        $context.Transport | Should -Be 'WinRM'
        $context.Port | Should -Be 5985
        $context.DisplayName | Should -Be 'Biuro'
        $context.Connection.State | Should -Be 'Disconnected'
        $context.Identity.Authentication | Should -Be 'Credential'
        $context.Identity.UserName | Should -Be 'PC-TEST1\admin'
        $context.Policy.ConnectTimeoutSeconds | Should -Be 7
        $context.Policy.OperationTimeoutSeconds | Should -Be 42
        $context.Policy.ErrorPolicy | Should -Be 'Stop'
        $context.Policy.AutoConnect | Should -BeTrue
    }

    It 'komputer spoza rejestru jest odrzucany z podpowiedzią Add-MwpTarget' {
        $unknown = 'PC-BRAK'
        { New-MwpExecutionContext -ComputerName $unknown } | Should -Throw '*Add-MwpTarget*'
    }

    It 'pola kontekstu, tożsamości i polityki są tylko do odczytu' {
        $context = New-MwpExecutionContext -ComputerName $computerOne

        { $context.ComputerName = 'inny' } | Should -Throw
        { $context.Mode = 'Local' } | Should -Throw
        { $context.Connection = $null } | Should -Throw
        { $context.Identity.UserName = 'inny' } | Should -Throw
        { $context.Policy.OperationTimeoutSeconds = 1 } | Should -Throw
        $context.ComputerName | Should -Be $computerOne
    }

    It 'parametry modułu są kopią tylko do odczytu' {
        $parameters = @{ Filtr = 'Spooler' }
        $context = New-MwpExecutionContext -ModuleParameters $parameters

        $parameters['Filtr'] = 'zmienione'
        $context.ModuleParameters['Filtr'] | Should -Be 'Spooler'
        $context.ModuleParameters.filtr | Should -Be 'Spooler'
        { $context.ModuleParameters['Filtr'] = 'x' } | Should -Throw
    }

    It 'jawne limity czasu i polityka błędów nadpisują ustawienia' {
        $context = New-MwpExecutionContext -ComputerName $computerOne -ConnectTimeoutSeconds 3 -OperationTimeoutSeconds 9 -ErrorPolicy Continue -NoAutoConnect

        $context.Policy.ConnectTimeoutSeconds | Should -Be 3
        $context.Policy.OperationTimeoutSeconds | Should -Be 9
        $context.Policy.ErrorPolicy | Should -Be 'Continue'
        $context.Policy.AutoConnect | Should -BeFalse
    }

    It 'poświadczenia są tylko w obiekcie połączenia; tożsamość i JSON kontekstu nie zawierają hasła' {
        $context = New-MwpExecutionContext -ComputerName $computerOne -Credential $credential

        $context.Connection.Credential | Should -Be $credential
        @($context.Identity.PSObject.Properties.Name) | Should -Be @('Authentication', 'UserName')
        ($context | ConvertTo-Json -Depth 6 -WarningAction SilentlyContinue) | Should -Not -Match 'TajneHaslo123'
    }

    It 'dla localhost poświadczenia są pomijane z ostrzeżeniem' {
        $context = New-MwpExecutionContext -Credential $credential -WarningVariable warnings -WarningAction SilentlyContinue

        $context.Connection.Credential | Should -BeNullOrEmpty
        $warnings | Should -Not -BeNullOrEmpty
    }

    It 'każdy kontekst ma własny obiekt połączenia (brak współdzielenia stanu)' {
        $first = New-MwpExecutionContext -ComputerName $computerOne
        $second = New-MwpExecutionContext -ComputerName $computerOne

        [object]::ReferenceEquals($first.Connection, $second.Connection) | Should -BeFalse
        $first.Connection.State = 'Error'
        $second.Connection.State | Should -Be 'Disconnected'
    }
}
