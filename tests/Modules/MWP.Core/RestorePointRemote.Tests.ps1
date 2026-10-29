#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
    Testy New-MwpRestorePoint -Context dla komputera zdalnego (FAZA 3, D-019): punkt powstaje
    na komputerze docelowym przez Invoke-MwpOnTarget. Transport WinRM jest mockowany
    (New-MwpPSSession, Invoke-MwpSessionCommand w MWP.Remote): nic nie jest tworzone naprawdę.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Zmienne z bloków BeforeDiscovery/BeforeAll są używane w blokach It (zakresy Pestera).')]
param()

Describe 'New-MwpRestorePoint na komputerze zdalnym' {
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
        $local = [ordered]@{ schemaVersion = 2; targets = @(@{ name = $computerOne; authentication = 'CurrentUser' }) }
        ConvertTo-Json -InputObject $local -Depth 5 | Set-Content -LiteralPath (Join-Path -Path $configDirectory -ChildPath 'settings.local.json') -Encoding UTF8

        Mock -ModuleName MWP.Core Test-MwpAdmin { $false }
        Mock -ModuleName MWP.Core Invoke-CimMethod { throw 'Lokalny CIM nie powinien być wywołany dla komputera zdalnego.' }
        Mock -ModuleName MWP.Remote Remove-MwpPSSession { }
    }

    AfterAll {
        Remove-Module -Name MWP.Remote, MWP.Core -Force -ErrorAction SilentlyContinue
    }

    BeforeEach {
        Clear-MwpTargetCredentialCache
        $script:remoteAdmin = $true
        $script:remoteCode = 0
        Mock -ModuleName MWP.Remote New-MwpPSSession { [pscustomobject]@{ ComputerName = $ComputerName; State = 'Opened' } }
        Mock -ModuleName MWP.Remote Invoke-MwpSessionCommand {
            if ($ScriptBlock.ToString() -match 'CreateRestorePoint') {
                $after = if ($script:remoteCode -eq 0) { @{ SequenceNumber = 7; Description = 'Test'; CreationTime = '20261023120000.000000-000' } } else { $null }
                return [pscustomobject]@{
                    Output = @(@{ Code = $script:remoteCode; Before = @{ SequenceNumber = 6; Description = 'Starszy'; CreationTime = '' }; After = $after })
                    Errors = @()
                }
            }
            [pscustomobject]@{ Output = @($script:remoteAdmin); Errors = @() }
        }
        $context = New-MwpExecutionContext -ComputerName $computerOne
    }

    It 'tworzy punkt na komputerze zdalnym; wynik i log mają nazwę komputera' {
        $result = New-MwpRestorePoint -Description 'Test' -Context $context

        $result.Success | Should -BeTrue -Because $result.Message
        $result.Changed | Should -BeTrue
        $result.ComputerName | Should -Be 'PC-TEST1'
        $result.Before.SequenceNumber | Should -Be 6
        $result.After.SequenceNumber | Should -Be 7
        Should -Invoke Invoke-MwpSessionCommand -ModuleName MWP.Remote -Times 2 -Exactly
        Should -Invoke Invoke-CimMethod -ModuleName MWP.Core -Times 0 -Exactly
        $log = Get-ChildItem -LiteralPath (Join-Path -Path $TestDrive -ChildPath 'Logs') -Filter '*.log' | Get-Content -Raw -Encoding UTF8
        $log | Should -Match '"computer":"PC-TEST1","source":"MWP.Core","operation":"Core.RestorePoint"'
    }

    It '-WhatIf sprawdza uprawnienia, ale nie tworzy punktu' {
        $result = New-MwpRestorePoint -Description 'Test' -Context $context -WhatIf

        $result.IsPreview | Should -BeTrue
        $result.Message | Should -Match 'PC-TEST1'
        Should -Invoke Invoke-MwpSessionCommand -ModuleName MWP.Remote -Times 1 -Exactly
    }

    It 'brak uprawnień administratora na komputerze zdalnym: błąd bez próby utworzenia' {
        $script:remoteAdmin = $false

        $result = New-MwpRestorePoint -Description 'Test' -Context $context

        $result.Success | Should -BeFalse
        $result.Message | Should -Match 'administratora na komputerze'
        Should -Invoke Invoke-MwpSessionCommand -ModuleName MWP.Remote -Times 1 -Exactly
    }

    It 'wyłączona ochrona systemu na komputerze zdalnym (kod 1058)' {
        $script:remoteCode = 1058

        $result = New-MwpRestorePoint -Description 'Test' -Context $context

        $result.Success | Should -BeFalse
        $result.Message | Should -Match '1058'
    }

    It 'komputer niedostępny: wynik z błędem i stan połączenia w kontekście' {
        Mock -ModuleName MWP.Remote New-MwpPSSession { throw (New-Object -TypeName Management.Automation.Remoting.PSRemotingTransportException -ArgumentList 'WinRM cannot complete the operation.') }

        $result = New-MwpRestorePoint -Description 'Test' -Context $context

        $result.Success | Should -BeFalse
        $result.ComputerName | Should -Be 'PC-TEST1'
        $context.Connection.State | Should -Be 'Error'
    }

    It 'kontekst lokalny używa ścieżki lokalnej (lokalne sprawdzenie administratora)' {
        $result = New-MwpRestorePoint -Description 'Test' -Context (New-MwpExecutionContext)

        $result.Success | Should -BeFalse
        $result.ComputerName | Should -Be 'localhost'
        Should -Invoke Test-MwpAdmin -ModuleName MWP.Core -Times 1 -Exactly
        Should -Invoke Invoke-MwpSessionCommand -ModuleName MWP.Remote -Times 0 -Exactly
    }
}
