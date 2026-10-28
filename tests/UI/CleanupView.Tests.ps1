#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
    Testy logiki prezentacji widoku Czyszczenie dysku (FAZA 9, D-047) bez WPF: katalog widoków modułów,
    wiersze tabeli kategorii, dostępność przycisków i treść okna potwierdzenia (lista kategorii z liczbą
    plików i rozmiarem), szczegóły kategorii i analizy DISM oraz bloki zadań GUI. Bez wywołań systemowych.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Zmienne z bloków BeforeDiscovery/BeforeAll są używane w blokach It (zakresy Pestera).')]
param()

Describe 'MWP.UI — widok Czyszczenie dysku (logika prezentacji)' {
    BeforeAll {
        $root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        foreach ($name in 'MWP.Core', 'MWP.Remote', 'MWP.Cleanup') {
            Import-Module -Name (Join-Path -Path $root -ChildPath "src\Modules\$name\$name.psd1") -Force
        }
        Import-Module -Name (Join-Path -Path $root -ChildPath 'src\UI\MWP.UI.psm1') -Force

        function Get-TestCategory {
            param([string] $Id, [bool] $Available = $true, [long] $Files = 2, [long] $Bytes = 2048, [string[]] $Notes = @())
            [pscustomobject]@{
                PSTypeName   = 'MWP.CleanupCategoryResult'
                Id           = $Id
                Name         = 'Kategoria ' + $Id
                Description  = 'Opis ' + $Id
                Scope        = 'System'
                Mode         = 'Scan'
                Available    = $Available
                FileCount    = $Files
                SizeBytes    = $Bytes
                SizeText     = Format-MwpCleanupSize -Bytes $Bytes
                SkippedCount = [long]1
                SkippedBytes = [long]10
                SkippedText  = '10 B'
                Skipped      = @([pscustomobject]@{ Reason = 'InUse'; ReasonText = 'w użyciu (otwarte przez inny program)'; Count = 1; Bytes = 10; SizeText = '10 B' })
                Samples      = @([pscustomobject]@{ Path = 'C:\Windows\Temp\a.tmp'; Reason = 'InUse'; ReasonText = 'w użyciu (otwarte przez inny program)' })
                Notes        = $Notes
                Roots        = @([pscustomobject]@{ Path = 'C:\Windows\Temp'; Scope = 'System'; UserName = ''; Available = $Available; Reason = ''; ReasonText = $(if ($Available) { '' } else { 'wymaga uprawnień administratora' }); Exists = $true; FileCount = $Files; SizeBytes = $Bytes; Error = $null })
            }
        }
        $scan = [pscustomobject]@{
            PSTypeName          = 'MWP.CleanupScan'
            ComputerName        = 'localhost'
            CollectedAt         = Get-Date
            IsAdministrator     = $true
            IsRemote            = $false
            IncludeUserProfiles = $false
            Categories          = @((Get-TestCategory -Id 'A'), (Get-TestCategory -Id 'B' -Bytes 1048576), (Get-TestCategory -Id 'Empty' -Files 0 -Bytes 0),
                (Get-TestCategory -Id 'Admin' -Available $false -Files 0 -Bytes 0 -Notes @('Pominięte lokalizacje (1): wymaga uprawnień administratora.')))
            TotalBytes          = 1050624
            TotalText           = '1 MB'
            TotalFiles          = 4
            Warnings            = @()
        }
    }

    It 'katalog widoków ma widok modułu Cleanup z plikiem w src\UI\Views i funkcjami MWP.UI' {
        $view = Get-MwpModuleViewCatalog -ModuleId 'Cleanup'
        $view.View | Should -Be 'Views\Cleanup.xaml'
        Test-Path -LiteralPath (Join-Path -Path $root -ChildPath ('src\UI\{0}' -f $view.View)) | Should -BeTrue
        Get-Command -Name $view.Initialize -Module MWP.UI | Should -Not -BeNullOrEmpty
        Get-Command -Name $view.Update -Module MWP.UI | Should -Not -BeNullOrEmpty
    }

    It 'wiersze tabeli: rozmiar, pominięte, uwagi (niedostępna, nic do usunięcia)' {
        $rows = @(Get-MwpCleanupRow -Scan $scan)
        $rows.Count | Should -Be 4
        $rows[1].SizeText | Should -Be '1 MB'
        $rows[0].SkippedText | Should -Be '1 (10 B)'
        $rows[2].NoteText | Should -Be 'Nic do usunięcia.'
        $rows[3].NoteText | Should -Match 'administratora'
        @(Get-MwpCleanupRow -Scan $null).Count | Should -Be 0
    }

    It 'czyszczenie dostępne tylko dla zaznaczonych kategorii dostępnych i z plikami; podgląd z rozmiarem i sumą' {
        $state = Get-MwpCleanupActionState -Scan $scan -SelectedId @('A', 'B', 'Empty', 'Admin')
        $state.CanRun | Should -BeTrue
        @($state.Categories).Id | Should -Be @('A', 'B')
        $state.TotalBytes | Should -Be (2048 + 1048576)
        $state.PreviewLine[0] | Should -Be 'Kategoria A: 2 plików, 2 KB'
        $state.PreviewLine[-1] | Should -Match '^Razem: 4 plików'
        $state.SelectionText | Should -Match 'pozostałe zaznaczone'
        (Get-MwpCleanupActionState -Scan $scan -SelectedId @('Empty', 'Admin')).CanRun | Should -BeFalse
        (Get-MwpCleanupActionState -Scan $scan -SelectedId @('A') -Ready $false).CanRun | Should -BeFalse
        (Get-MwpCleanupActionState -Scan $null -SelectedId @('A')).CanRun | Should -BeFalse
        (Get-MwpCleanupActionState -Scan $scan).CanSelectAll | Should -BeTrue
        (Get-MwpCleanupActionState -Scan $scan).CanRun | Should -BeFalse -Because 'domyślnie nic nie jest zaznaczone'
    }

    It 'szczegóły kategorii: opis, lokalizacje, pominięcia z przykładami' {
        $detail = Get-MwpCleanupDetail -Category (Get-TestCategory -Id 'A')
        $detail.Title | Should -Be 'Kategoria A'
        $detail.Text | Should -Match 'C:\\Windows\\Temp — 2 plików'
        $detail.Text | Should -Match 'w użyciu'
        (Get-MwpCleanupDetail -Category $null).Text | Should -BeNullOrEmpty
    }

    It 'opis analizy DISM: rozmiary i zalecenie; błąd; brak analizy' {
        $analysis = [pscustomobject]@{
            PSTypeName = 'MWP.ComponentStoreAnalysis'; ComputerName = 'localhost'; Success = $true; Message = 'ok'
            ExplorerSizeText = '7,9 GB'; ActualSizeText = '7,6 GB'; SharedText = '5,6 GB'; BackupsText = '1,9 GB'; CacheText = '54,3 MB'
            LastCleanup = [datetime]'2026-10-01 10:14'; LastCleanupText = ''; ReclaimablePackages = 2; CleanupRecommended = $true; CollectedAt = Get-Date
        }
        (Get-MwpCleanupDetail -Analysis $analysis).Text | Should -Match 'ZALECANE'
        (Get-MwpCleanupDetail -Analysis $analysis).Text | Should -Match '2026-10-01 10:14'
        $analysis.Success = $false
        $analysis.Message = 'wymaga administratora'
        (Get-MwpCleanupDetail -Analysis $analysis).Text | Should -Be 'wymaga administratora'
        (Get-MwpCleanupDetail -Analysis $null).Text | Should -Match 'nie była jeszcze wykonana'
    }

    It 'bloki zadań GUI wywołują tylko funkcje MWP.Cleanup (czyszczenie zawsze z -Confirm:$false po oknie potwierdzenia)' {
        foreach ($name in 'Scan', 'Clear') {
            $block = Get-MwpUiCleanupScript -Name $name
            $commands = @($block.Ast.FindAll({ param($node) $node -is [Management.Automation.Language.CommandAst] }, $true) | ForEach-Object { $_.GetCommandName() } | Where-Object { $_ })
            @($commands | Where-Object { $_ -notmatch '-Mwp' -and $_ -notin 'Import-Module', 'New-Object' }) | Should -BeNullOrEmpty -Because $name
        }
        (Get-MwpUiCleanupScript -Name Scan).ToString() | Should -Not -Match 'Clear-Mwp'
        (Get-MwpUiCleanupScript -Name Clear).ToString() | Should -Match 'Progress\.Results'
    }
}
