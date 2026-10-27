#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
    Testy logiki prezentacji widoku Usługi (FAZA 7, D-045) bez WPF: katalog widoków modułów,
    pozycje list (filtry, typy uruchomienia dozwolone dla usługi chronionej), dostępność przycisków
    (blokada usług z listy ochronnej w GUI), szczegóły usługi i kroki importu profilu.
    Bez wywołań systemowych.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Zmienne z bloków BeforeDiscovery/BeforeAll są używane w blokach It (zakresy Pestera).')]
param()

Describe 'MWP.UI — widok Usługi (logika prezentacji)' {
    BeforeAll {
        $root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        foreach ($name in 'MWP.Core', 'MWP.Remote', 'MWP.Services') {
            Import-Module -Name (Join-Path -Path $root -ChildPath "src\Modules\$name\$name.psd1") -Force
        }
        Import-Module -Name (Join-Path -Path $root -ChildPath 'src\UI\MWP.UI.psm1') -Force

        function Get-TestService {
            param([string] $Status = 'Running', [string] $StartupType = 'Automatic', [bool] $IsProtected = $false, [bool] $CanStop = $true)
            [pscustomobject]@{
                PSTypeName       = 'MWP.Service'
                Name             = 'MwpTest'
                DisplayName      = 'Usługa testowa'
                Status           = $Status
                StatusText       = 'Działa'
                StartupType      = $StartupType
                StartupTypeText  = 'Automatyczny'
                Account          = 'LocalSystem'
                Path             = 'C:\Test\svc.exe'
                Description      = 'Opis'
                ProcessId        = 42
                CanStop          = $CanStop
                DependsOn        = @('RpcSs')
                Dependents       = @()
                IsProtected      = $IsProtected
                ProtectionReason = $(if ($IsProtected) { 'Krytyczna.' } else { $null })
            }
        }
    }

    AfterAll {
        Remove-Module -Name MWP.UI, MWP.Services, MWP.Remote, MWP.Core -Force -ErrorAction SilentlyContinue
    }

    It 'katalog widoków ma widok modułu Services z plikiem w src\UI\Views i funkcjami MWP.UI' {
        $view = Get-MwpModuleViewCatalog -ModuleId 'Services'
        $view.View | Should -Be 'Views\Services.xaml'
        Test-Path -LiteralPath (Join-Path -Path $root -ChildPath ('src\UI\{0}' -f $view.View)) | Should -BeTrue
        Get-Command -Name $view.Initialize -Module MWP.UI | Should -Not -BeNullOrEmpty
        Get-Command -Name $view.Update -Module MWP.UI | Should -Not -BeNullOrEmpty
    }

    It 'filtry: stany i typy uruchomienia z pozycją „wszystkie”' {
        @(Get-MwpServiceViewOption -Kind StatusFilter)[0].Value | Should -Be 'All'
        $types = @(Get-MwpServiceViewOption -Kind StartupTypeFilter)
        $types.Value | Should -Be @('All', 'AnyAutomatic', 'Automatic', 'AutomaticDelayedStart', 'Manual', 'Disabled')
        ($types | Where-Object Value -eq 'AutomaticDelayedStart').Label | Should -Be 'Automatyczny (opóźniony start)'
    }

    It 'typy uruchomienia dla usługi: wszystkie; chroniona — tylko automatyczne i bieżący; nieznany — brak' {
        @(Get-MwpServiceViewOption -Kind StartupType -Service (Get-TestService)).Count | Should -Be 4
        @(Get-MwpServiceViewOption -Kind StartupType -Service (Get-TestService -IsProtected $true)).Value | Should -Be @('Automatic', 'AutomaticDelayedStart')
        @(Get-MwpServiceViewOption -Kind StartupType -Service (Get-TestService -IsProtected $true -StartupType Manual)).Value | Should -Be @('Automatic', 'AutomaticDelayedStart', 'Manual')
        @(Get-MwpServiceViewOption -Kind StartupType -Service (Get-TestService -StartupType Unknown)).Count | Should -Be 0
        @(Get-MwpServiceViewOption -Kind StartupType -Service $null).Count | Should -Be 0
    }

    It 'przyciski: usługa chroniona ma zablokowane zatrzymanie i ponowne uruchomienie (blokada w GUI)' {
        $normal = Get-MwpServiceActionState -Service (Get-TestService) -Ready $true -StartupType 'Manual'
        $normal.CanStart | Should -BeFalse
        $normal.CanStop | Should -BeTrue
        $normal.CanRestart | Should -BeTrue
        $normal.CanSetStartupType | Should -BeTrue
        $normal.ProtectionText | Should -BeNullOrEmpty

        $guarded = Get-MwpServiceActionState -Service (Get-TestService -IsProtected $true) -Ready $true -StartupType 'AutomaticDelayedStart'
        $guarded.CanStop | Should -BeFalse
        $guarded.CanRestart | Should -BeFalse
        $guarded.CanSetStartupType | Should -BeTrue
        $guarded.ProtectionText | Should -Match 'Krytyczna'

        $stopped = Get-MwpServiceActionState -Service (Get-TestService -Status Stopped -StartupType Disabled) -Ready $true -StartupType 'Disabled'
        $stopped.CanStart | Should -BeFalse
        $stopped.CanStop | Should -BeFalse
        $stopped.CanSetStartupType | Should -BeFalse
        (Get-MwpServiceActionState -Service (Get-TestService -Status Stopped) -Ready $true).CanStart | Should -BeTrue
        (Get-MwpServiceActionState -Service (Get-TestService -CanStop $false) -Ready $true).CanStop | Should -BeFalse
    }

    It 'bez gotowości (rozłączona, trwa operacja, brak odczytu) wszystko jest wyłączone' {
        $state = Get-MwpServiceActionState -Service (Get-TestService -IsProtected $true) -Ready $false -StartupType 'Manual'
        $state.CanStart -or $state.CanStop -or $state.CanRestart -or $state.CanSetStartupType | Should -BeFalse
        $state.ProtectionText | Should -Not -BeNullOrEmpty
        (Get-MwpServiceActionState -Service $null -Ready $true).CanStart | Should -BeFalse
    }

    It 'szczegóły: stan, konto, PID, ścieżka i zależności (gdy jest graf)' {
        $detail = Get-MwpServiceDetail -Service (Get-TestService) -HasGraph $true
        $detail.Title | Should -Be 'Usługa testowa (MwpTest)'
        $detail.Text | Should -Match 'PID 42'
        $detail.Text | Should -Match 'Wymaga usług: RpcSs'
        $detail.Text | Should -Match 'Usługi zależne: brak'
        (Get-MwpServiceDetail -Service (Get-TestService) -HasGraph $false).Text | Should -Not -Match 'Wymaga'
        (Get-MwpServiceDetail -Service $null).Title | Should -Match 'Wybierz'
    }

    It 'kroki importu profilu: tylko wiersze do zmiany, każdy jako Set-MwpServiceStartupType' {
        $rows = @(
            [pscustomobject]@{ Name = 'A'; DisplayName = 'Usługa A'; Action = 'Change'; Wanted = 'Manual'; CurrentText = 'Automatyczny'; WantedText = 'Ręczny' }
            [pscustomobject]@{ Name = 'B'; DisplayName = 'Usługa B'; Action = 'Protected'; Wanted = 'Disabled'; CurrentText = 'Automatyczny'; WantedText = 'Wyłączony' }
            [pscustomobject]@{ Name = 'C'; DisplayName = 'Usługa C'; Action = 'Same'; Wanted = 'Manual'; CurrentText = 'Ręczny'; WantedText = 'Ręczny' }
            [pscustomobject]@{ Name = 'D'; DisplayName = 'Usługa D'; Action = 'Missing'; Wanted = 'Manual'; CurrentText = '—'; WantedText = 'Ręczny' }
        )
        $steps = @(Get-MwpServiceProfileStep -Row $rows)
        $steps.Count | Should -Be 1
        $steps[0].Command | Should -Be 'Set-MwpServiceStartupType'
        $steps[0].Parameters.Name | Should -Be 'A'
        $steps[0].Parameters.StartupType | Should -Be 'Manual'
        $steps[0].Label | Should -Be 'Usługa A: Automatyczny → Ręczny'
        @(Get-MwpServiceProfileStep -Row @()).Count | Should -Be 0
    }
}
