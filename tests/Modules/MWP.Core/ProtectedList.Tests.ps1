#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
    Testy listy ochronnej: plik danych, Test-MwpProtectedItem, Get-MwpProtectedItem.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Zmienne z bloków BeforeDiscovery/BeforeAll są używane w blokach It (zakresy Pestera).')]
param()

Describe 'Lista ochronna' {
    BeforeAll {
        $root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
        Import-Module -Name (Join-Path -Path $root -ChildPath 'src\Modules\MWP.Core\MWP.Core.psd1') -Force
        $dataFile = Join-Path -Path $root -ChildPath 'src\Modules\MWP.Core\Data\protected-items.json'
    }

    AfterAll {
        Remove-Module -Name MWP.Core -Force -ErrorAction SilentlyContinue
    }

    It 'plik danych jest poprawnym JSON-em, a każdy element ma kategorię, nazwę i powód' {
        $data = Get-Content -LiteralPath $dataFile -Raw -Encoding UTF8 | ConvertFrom-Json
        ($data.schemaVersion -is [int] -or $data.schemaVersion -is [long]) | Should -BeTrue
        @($data.items).Count | Should -BeGreaterThan 0
        foreach ($item in $data.items) {
            $item.category | Should -Not -BeNullOrEmpty
            $item.name | Should -Not -BeNullOrEmpty
            $item.reason | Should -Not -BeNullOrEmpty
        }
    }

    It 'krytyczna usługa <Name> jest chroniona (bez względu na wielkość liter)' -ForEach @(
        @{ Name = 'RpcSs' }
        @{ Name = 'rpcss' }
        @{ Name = 'WinRM' }
        @{ Name = 'Winmgmt' }
    ) {
        Test-MwpProtectedItem -Category Service -Name $Name | Should -BeTrue
    }

    It 'zwykła usługa nie jest chroniona' {
        Test-MwpProtectedItem -Category Service -Name 'Spooler' | Should -BeFalse
    }

    It 'element innej kategorii nie pasuje' {
        Test-MwpProtectedItem -Category Registry -Name 'RpcSs' | Should -BeFalse
    }

    It 'zwraca powód ochrony' {
        $item = Get-MwpProtectedItem -Category Service -Name 'WinRM'
        $item.PSObject.TypeNames | Should -Contain 'MWP.ProtectedItem'
        $item.Reason | Should -Not -BeNullOrEmpty
    }

    It 'obsługuje wzorce z symbolami wieloznacznymi' {
        $custom = Join-Path -Path $TestDrive -ChildPath 'protected.json'
        Set-Content -LiteralPath $custom -Encoding UTF8 -Value '{ "schemaVersion": 1, "items": [ { "category": "Task", "name": "\\Microsoft\\Windows\\*", "reason": "Zadania systemowe" } ] }'
        Mock -ModuleName MWP.Core Get-MwpProtectedListPath { Join-Path -Path $TestDrive -ChildPath 'protected.json' }

        Test-MwpProtectedItem -Category Task -Name '\Microsoft\Windows\Defrag\ScheduledDefrag' | Should -BeTrue
        Test-MwpProtectedItem -Category Task -Name '\MojeZadanie' | Should -BeFalse
    }

    It 'brak pliku danych daje czytelny błąd' {
        Mock -ModuleName MWP.Core Get-MwpProtectedListPath { Join-Path -Path $TestDrive -ChildPath 'brak.json' }

        { Test-MwpProtectedItem -Category Service -Name 'RpcSs' } | Should -Throw '*listy ochronnej*'
    }
}
