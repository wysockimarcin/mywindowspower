#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
    Testy logiki prezentacji widoku Autostart i harmonogram (FAZA 8, D-046) bez WPF: katalog widoków
    modułów, pozycje filtrów, dostępność przycisków (RunOnce, uprawnienia, lista ochronna zadań w GUI)
    i szczegóły pozycji oraz zadania. Bez wywołań systemowych.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Zmienne z bloków BeforeDiscovery/BeforeAll są używane w blokach It (zakresy Pestera).')]
param()

Describe 'MWP.UI — widok Autostart i harmonogram (logika prezentacji)' {
    BeforeAll {
        $root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        foreach ($name in 'MWP.Core', 'MWP.Remote', 'MWP.Startup') {
            Import-Module -Name (Join-Path -Path $root -ChildPath "src\Modules\$name\$name.psd1") -Force
        }
        Import-Module -Name (Join-Path -Path $root -ChildPath 'src\UI\MWP.UI.psm1') -Force
        $sid = 'S-1-5-21-1-2-3-1001'

        function Get-TestItem {
            param([string] $Location = 'UserRun', [bool] $Enabled = $true, [string] $UserSid = 'S-1-5-21-1-2-3-1001')
            [pscustomobject]@{
                PSTypeName   = 'MWP.StartupItem'
                Id           = '{0}|{1}|MwpTest' -f $Location, $UserSid
                Name         = 'MwpTest'
                Location     = $Location
                LocationText = 'Rejestr użytkownika …\Run'
                Scope        = $(if ($Location -like 'User*') { 'User' } else { 'Machine' })
                UserSid      = $(if ($Location -like 'User*') { $UserSid } else { $null })
                UserName     = 'PC\anna'
                Command      = '"C:\Test\app.exe" /tray'
                FilePath     = 'C:\Test\app.exe'
                FileExists   = $true
                Enabled      = $Enabled
                CanToggle    = $Location -notlike '*RunOnce*'
                StateText    = $(if ($Enabled) { 'Włączony' } else { 'Wyłączony' })
                DisabledAt   = $(if ($Enabled) { $null } else { [datetime]'2026-10-01 12:00' })
                Publisher    = 'Contoso'
                Risk         = 'Signed'
                RiskText     = 'Podpisany'
                Source       = 'HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'
            }
        }
        function Get-TestTask {
            param([string] $State = 'Ready', [bool] $IsProtected = $false, [bool] $CanRemove = $true)
            [pscustomobject]@{
                PSTypeName        = 'MWP.ScheduledTask'
                Path              = '\MwpTest\Zadanie'
                TaskPath          = '\MwpTest\'
                TaskName          = 'Zadanie'
                State             = $State
                StateText         = 'Gotowe'
                Enabled           = $State -ne 'Disabled'
                Description       = 'Opis zadania'
                Author            = 'Test'
                Account           = 'SYSTEM'
                RunLevel          = 'Highest'
                HasStoredPassword = $true
                ActionText        = 'C:\Test\task.exe /run'
                TriggerText       = 'przy logowaniu'
                RiskText          = 'Podpisany'
                Publisher         = 'Contoso'
                LastRunTime       = [datetime]'2026-10-20 08:00'
                NextRunTime       = $null
                LastResultText    = 'Sukces (0x0)'
                IsProtected       = $IsProtected
                ProtectionReason  = $(if ($IsProtected) { 'Krytyczne.' } else { $null })
                CanRemove         = $CanRemove -and -not $IsProtected
                RemovalReason     = $(if (-not $CanRemove) { 'Zadania Microsoft.' } else { $null })
            }
        }
    }

    AfterAll {
        Remove-Module -Name MWP.UI, MWP.Startup, MWP.Remote, MWP.Core -Force -ErrorAction SilentlyContinue
    }

    It 'katalog widoków ma widok modułu Startup z plikiem w src\UI\Views i funkcjami MWP.UI' {
        $view = Get-MwpModuleViewCatalog -ModuleId 'Startup'
        $view.View | Should -Be 'Views\Startup.xaml'
        Test-Path -LiteralPath (Join-Path -Path $root -ChildPath ('src\UI\{0}' -f $view.View)) | Should -BeTrue
        Get-Command -Name $view.Initialize -Module MWP.UI | Should -Not -BeNullOrEmpty
        Get-Command -Name $view.Update -Module MWP.UI | Should -Not -BeNullOrEmpty
        [xml](Get-Content -LiteralPath (Join-Path -Path $root -ChildPath 'src\UI\Views\Startup.xaml') -Raw -Encoding UTF8) | Should -Not -BeNullOrEmpty
    }

    It 'filtry: wartości zgodne z parametrami Select-MwpStartupItem i Select-MwpScheduledTask, pierwsza pozycja „wszystkie”' {
        foreach ($pair in @(@('ItemScope', 'Select-MwpStartupItem', 'Scope'), @('ItemState', 'Select-MwpStartupItem', 'State'), @('ItemRisk', 'Select-MwpStartupItem', 'Risk'), @('TaskState', 'Select-MwpScheduledTask', 'State'))) {
            $options = @(Get-MwpStartupViewOption -Kind $pair[0])
            $options[0].Value | Should -Be 'All'
            $allowed = (Get-Command -Name $pair[1]).Parameters[$pair[2]].Attributes | Where-Object { $_ -is [ValidateSet] } | ForEach-Object { $_.ValidValues }
            @($options.Value | Where-Object { $allowed -notcontains $_ }) | Should -BeNullOrEmpty -Because $pair[0]
        }
    }

    It 'pozycja autostartu: własny profil bez administratora — włącz/wyłącz dostępne zgodnie ze stanem' {
        $state = Get-MwpStartupActionState -Item (Get-TestItem -Enabled $true) -Ready $true -IsAdministrator $false -CurrentUserSid $sid
        $state.CanDisable | Should -BeTrue
        $state.CanEnable | Should -BeFalse
        $state.Note | Should -BeNullOrEmpty
        (Get-MwpStartupActionState -Item (Get-TestItem -Enabled $false) -Ready $true -IsAdministrator $false -CurrentUserSid $sid).CanEnable | Should -BeTrue
    }

    It 'pozycja komputera albo innego użytkownika bez administratora, RunOnce, brak gotowości — przyciski wyłączone' {
        $machine = Get-MwpStartupActionState -Item (Get-TestItem -Location 'MachineRun') -Ready $true -IsAdministrator $false -CurrentUserSid $sid
        $machine.CanDisable | Should -BeFalse
        $machine.Note | Should -Match 'administratora'
        (Get-MwpStartupActionState -Item (Get-TestItem -Location 'MachineRun') -Ready $true -IsAdministrator $true -CurrentUserSid $sid).CanDisable | Should -BeTrue
        (Get-MwpStartupActionState -Item (Get-TestItem -UserSid 'S-1-5-21-9-9-9-1002') -Ready $true -IsAdministrator $false -CurrentUserSid $sid).CanDisable | Should -BeFalse
        $once = Get-MwpStartupActionState -Item (Get-TestItem -Location 'UserRunOnce') -Ready $true -IsAdministrator $true -CurrentUserSid $sid
        $once.CanDisable | Should -BeFalse
        $once.Note | Should -Match 'RunOnce'
        (Get-MwpStartupActionState -Item (Get-TestItem) -Ready $false -IsAdministrator $true -CurrentUserSid $sid).CanDisable | Should -BeFalse
        (Get-MwpStartupActionState -Item $null -Ready $true -IsAdministrator $true).CanDisable | Should -BeFalse
    }

    It 'zadanie: administrator wymagany; chronione — bez wyłączania i usuwania; \Microsoft\ — bez usuwania; wyłączone i działające — bez uruchamiania' {
        $plain = Get-MwpStartupActionState -Task (Get-TestTask) -Ready $true -IsAdministrator $true
        $plain.CanDisable | Should -BeTrue
        $plain.CanRun | Should -BeTrue
        $plain.CanRemove | Should -BeTrue
        $plain.CanEnable | Should -BeFalse
        $noAdmin = Get-MwpStartupActionState -Task (Get-TestTask) -Ready $true -IsAdministrator $false
        @($noAdmin.CanEnable, $noAdmin.CanDisable, $noAdmin.CanRun, $noAdmin.CanRemove) | Should -Not -Contain $true
        $noAdmin.Note | Should -Match 'administratora'
        $guarded = Get-MwpStartupActionState -Task (Get-TestTask -IsProtected $true) -Ready $true -IsAdministrator $true
        $guarded.CanDisable | Should -BeFalse
        $guarded.CanRemove | Should -BeFalse
        $guarded.CanRun | Should -BeTrue
        $guarded.Note | Should -Match 'chronione'
        $microsoft = Get-MwpStartupActionState -Task (Get-TestTask -CanRemove $false) -Ready $true -IsAdministrator $true
        $microsoft.CanRemove | Should -BeFalse
        $microsoft.CanDisable | Should -BeTrue
        $microsoft.Note | Should -Match 'Usunięcie zablokowane'
        $disabled = Get-MwpStartupActionState -Task (Get-TestTask -State Disabled) -Ready $true -IsAdministrator $true
        $disabled.CanEnable | Should -BeTrue
        $disabled.CanRun | Should -BeFalse
        (Get-MwpStartupActionState -Task (Get-TestTask -State Running) -Ready $true -IsAdministrator $true).CanRun | Should -BeFalse
    }

    It 'szczegóły pozycji i zadania: miejsce, polecenie, podpis z wydawcą, data wyłączenia, konto, hasło, uruchomienia' {
        $item = Get-MwpStartupDetail -Item (Get-TestItem -Enabled $false)
        $item.Title | Should -Be 'MwpTest'
        $item.Text | Should -Match 'Podpis: Podpisany — wydawca: Contoso'
        $item.Text | Should -Match 'Wyłączony \(od 2026-10-01 12:00\)'
        $task = Get-MwpStartupDetail -Task (Get-TestTask)
        $task.Title | Should -Be '\MwpTest\Zadanie'
        $task.Text | Should -Match 'Konto: SYSTEM, najwyższe uprawnienia'
        $task.Text | Should -Match 'zapisane hasło'
        $task.Text | Should -Match 'Następne uruchomienie: brak'
        (Get-MwpStartupDetail -Item $null).Title | Should -Match 'Wybierz'
        (Get-MwpStartupDetail -Task $null).Title | Should -Match 'Wybierz'
    }
}
