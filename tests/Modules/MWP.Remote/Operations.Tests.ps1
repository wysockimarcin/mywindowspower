#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
    Testy operacji asynchronicznych (D-023): Start-, Wait-, Stop-MwpOperation w puli runspace'ów.
    Operacje działają na localhost i niczego nie zmieniają w systemie (obliczenia, Start-Sleep).
    Test architektoniczny 8 z ARCHITEKTURA.md (anulowanie długiej operacji i zwolnienie zasobów).
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Zmienne z bloków BeforeDiscovery/BeforeAll są używane w blokach It (zakresy Pestera).')]
param()

Describe 'Operacje asynchroniczne' {
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
        $local = [ordered]@{ schemaVersion = 2; remoteMaxParallelOperations = 2; targets = @(@{ name = $computerOne }) }
        ConvertTo-Json -InputObject $local -Depth 5 | Set-Content -LiteralPath (Join-Path -Path $configDirectory -ChildPath 'settings.local.json') -Encoding UTF8
        InModuleScope MWP.Remote { Close-MwpOperationPool }
        $context = New-MwpExecutionContext
    }

    BeforeEach {
        Clear-MwpTargetCredentialCache
    }

    AfterAll {
        Remove-Module -Name MWP.Remote, MWP.Core -Force -ErrorAction SilentlyContinue
    }

    It 'zwraca uchwyt od razu, a wynik po Wait-MwpOperation' {
        $operation = Start-MwpOperation -Context $context -ScriptBlock { param($Value) $Value * 2 } -ArgumentList 21 -Operation 'Test.Mnozenie'

        $operation.PSObject.TypeNames | Should -Contain 'MWP.Operation'
        $result = Wait-MwpOperation -Operation $operation

        $result.Success | Should -BeTrue
        $result.Operation | Should -Be 'Test.Mnozenie'
        $result.ComputerName | Should -Be 'localhost'
        $result.Data | Should -Be @(42)
        $operation.Status | Should -Be 'Completed'
        $operation.PowerShell | Should -BeNullOrEmpty -Because 'zasoby operacji są zwolnione'
        (Wait-MwpOperation -Operation $operation).Data | Should -Be @(42) -Because 'wynik jest zapamiętany'
    }

    It 'limit równoległości pochodzi z ustawienia remoteMaxParallelOperations' {
        $null = Start-MwpOperation -Context $context -ScriptBlock { 1 } | Wait-MwpOperation

        InModuleScope MWP.Remote { $script:MwpOperationPool.GetMaxRunspaces() } | Should -Be 2
    }

    It 'błąd jednej operacji nie wpływa na inne' {
        $failing = Start-MwpOperation -Context $context -ScriptBlock { throw 'awaria testowa' }
        $working = Start-MwpOperation -Context $context -ScriptBlock { 'ok' }

        $failed = Wait-MwpOperation -Operation $failing
        $done = Wait-MwpOperation -Operation $working

        $failed.Success | Should -BeFalse
        $failed.ErrorMessage | Should -Match 'awaria testowa'
        $failing.Status | Should -Be 'Failed'
        $done.Success | Should -BeTrue
        $done.Data | Should -Be @('ok')
    }

    It 'przekroczenie limitu czasu przerywa operację (TimedOut)' {
        $operation = Start-MwpOperation -Context $context -ScriptBlock { Start-Sleep -Seconds 30 } -TimeoutSeconds 1
        $watch = [Diagnostics.Stopwatch]::StartNew()

        $result = Wait-MwpOperation -Operation $operation

        $watch.Elapsed.TotalSeconds | Should -BeLessThan 15
        $result.Success | Should -BeFalse
        $result.Message | Should -Match 'limit czasu'
        $operation.Status | Should -Be 'TimedOut'
    }

    It 'Wait-MwpOperation z -WaitSeconds nie przerywa trwającej operacji' {
        $operation = Start-MwpOperation -Context $context -ScriptBlock { Start-Sleep -Milliseconds 1500; 'koniec' }

        Wait-MwpOperation -Operation $operation -WaitSeconds 0 | Should -BeNullOrEmpty
        $operation.Status | Should -Be 'Running'
        (Wait-MwpOperation -Operation $operation).Data | Should -Be @('koniec')
    }

    It 'anulowanie zatrzymuje długą operację i zwalnia zasoby' {
        $operation = Start-MwpOperation -Context $context -ScriptBlock { Start-Sleep -Seconds 30 }

        $result = Stop-MwpOperation -Operation $operation -Confirm:$false

        $result.Success | Should -BeFalse
        $result.Message | Should -Match 'Anulowano'
        $operation.Status | Should -Be 'Cancelled'
        $operation.PowerShell | Should -BeNullOrEmpty
        (Get-MwpRemoteModuleInfo).RunningOperations | Should -Be 0
    }

    It 'Stop-MwpOperation -WhatIf nie anuluje operacji' {
        $operation = Start-MwpOperation -Context $context -ScriptBlock { Start-Sleep -Milliseconds 500; 'dalej' }

        (Stop-MwpOperation -Operation $operation -WhatIf).IsPreview | Should -BeTrue
        (Wait-MwpOperation -Operation $operation).Data | Should -Be @('dalej')
    }

    It 'komputer zdalny bez wymaganych poświadczeń: operacja od razu kończy się błędem' {
        $remote = New-MwpExecutionContext -ComputerName $computerOne

        $operation = Start-MwpOperation -Context $remote -ScriptBlock { 'x' }

        $operation.Status | Should -Be 'Failed'
        (Wait-MwpOperation -Operation $operation).Message | Should -Match 'poświadcze'
    }

    It 'usunięcie modułu zamyka pulę runspace''ów' {
        $null = Start-MwpOperation -Context $context -ScriptBlock { 1 } | Wait-MwpOperation
        $pool = InModuleScope MWP.Remote { $script:MwpOperationPool }

        Remove-Module -Name MWP.Remote -Force
        Import-Module -Name (Join-Path -Path $root -ChildPath 'src\Modules\MWP.Remote\MWP.Remote.psd1') -Force

        [string]$pool.RunspacePoolStateInfo.State | Should -Be 'Closed'
    }
}
