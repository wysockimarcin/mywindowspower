#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
    Testy logiki prezentacji widoku Windows Update (FAZA 10, D-048) bez WPF: katalog widoków modułów,
    wiersze tabel (aktualizacje, historia), dostępność przycisków (instalacja tylko lokalnie i jako
    administrator, pominięte aktualizacje w podglądzie), pozycje list, szczegóły i blok zadania instalacji.
    Dane z Resolve-MwpUpdate* na surowym JSON — bez wywołań systemowych.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Zmienne z bloków BeforeDiscovery/BeforeAll są używane w blokach It (zakresy Pestera).')]
param()

Describe 'MWP.UI — widok Windows Update (logika prezentacji)' {
    BeforeAll {
        $root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        foreach ($name in 'MWP.Core', 'MWP.Remote', 'MWP.Update') {
            Import-Module -Name (Join-Path -Path $root -ChildPath "src\Modules\$name\$name.psd1") -Force
        }
        Import-Module -Name (Join-Path -Path $root -ChildPath 'src\UI\MWP.UI.psm1') -Force

        $searchRaw = ConvertTo-Json -Depth 6 -Compress -InputObject ([pscustomobject]@{
                Kind            = 'MWP.UpdateSearchRaw'
                ComputerName    = 'PC'
                CollectedAt     = '2026-10-28T10:00:00Z'
                IsAdministrator = $true
                Criteria        = 'IsInstalled=0 and IsHidden=0'
                ResultCode      = 2
                Error           = $null
                HResult         = $null
                Updates         = @(
                    [pscustomobject]@{ UpdateId = 'a1'; Revision = 1; Title = 'Zbiorcza (KB5000001)'; Description = 'Opis A'; KB = @('KB5000001'); Categories = @('Zabezpieczenia'); Type = 1; Severity = 'Critical'; MaxDownloadSize = 104857600; IsDownloaded = $false; IsMandatory = $true; EulaAccepted = $true; RebootBehavior = 1; CanRequestUserInput = $false; Published = '2026-10-14T00:00:00Z'; SupportUrl = 'https://support.microsoft.com' }
                    [pscustomobject]@{ UpdateId = 'b2'; Revision = 1; Title = 'Sterownik'; Description = ''; KB = @(); Categories = @('Sterowniki'); Type = 2; Severity = ''; MaxDownloadSize = 0; IsDownloaded = $true; IsMandatory = $false; EulaAccepted = $true; RebootBehavior = 0; CanRequestUserInput = $true; Published = $null; SupportUrl = '' }
                )
            })
        $search = Resolve-MwpUpdateSearch -Data $searchRaw
        $history = Resolve-MwpUpdateHistory -Data (ConvertTo-Json -Depth 6 -Compress -InputObject ([pscustomobject]@{
                    Kind = 'MWP.UpdateHistoryRaw'; ComputerName = 'PC'; CollectedAt = '2026-10-28T10:00:00Z'; TotalCount = 2; Error = $null; HResult = $null
                    Entries = @(
                        [pscustomobject]@{ Date = '2026-10-20T08:00:00Z'; Operation = 1; ResultCode = 2; HResult = '0x00000000'; Title = 'A (KB1234567)'; Description = ''; ClientApplicationId = ''; SupportUrl = ''; UpdateId = 'x' }
                        [pscustomobject]@{ Date = '2026-10-21T08:00:00Z'; Operation = 1; ResultCode = 4; HResult = '0x8024402C'; Title = 'B (KB7654321)'; Description = ''; ClientApplicationId = ''; SupportUrl = ''; UpdateId = 'y' }
                    )
                }))
        function Get-TestStatus {
            param($Admin = $true, [bool] $Paused = $false)
            [pscustomobject]@{
                PSTypeName      = 'MWP.UpdateStatus'
                IsAdministrator = $Admin
                Pause           = [pscustomobject]@{ HasValues = $Paused; IsPaused = $Paused }
                RebootText      = 'Restart nie jest wymagany.'
                LastSearchText  = '2026-10-28 07:37'
                LastInstallText = 'brak danych'
                PauseText       = 'Aktualizacje nie są wstrzymane.'
                Backups         = @([pscustomobject]@{ Suffix = 'mwp-20261028-120000'; Folders = @('SoftwareDistribution', 'catroot2') })
            }
        }
    }

    AfterAll {
        Remove-Module -Name MWP.UI, MWP.Update, MWP.Remote, MWP.Core -Force -ErrorAction SilentlyContinue
    }

    It 'katalog widoków ma widok modułu Update z plikiem w src\UI\Views i funkcjami MWP.UI' {
        $view = Get-MwpModuleViewCatalog -ModuleId 'Update'
        $view.View | Should -Be 'Views\Update.xaml'
        Test-Path -LiteralPath (Join-Path -Path $root -ChildPath ('src\UI\{0}' -f $view.View)) | Should -BeTrue
        Get-Command -Name $view.Initialize -Module MWP.UI | Should -Not -BeNullOrEmpty
        Get-Command -Name $view.Update -Module MWP.UI | Should -Not -BeNullOrEmpty
    }

    It 'wiersze aktualizacji: KB, rozmiar, pobrana, restart i uwagi; wiersze historii z filtrem niepowodzeń' {
        $rows = @(Get-MwpUpdateRow -Search $search)
        $rows.Count | Should -Be 2
        $a = $rows | Where-Object UpdateId -eq 'a1'
        $a.SizeText | Should -Be '100 MB'
        $a.DownloadedText | Should -Be 'Nie'
        $a.SeverityText | Should -Be 'Krytyczna'
        $a.Note | Should -Be 'obowiązkowa'
        ($rows | Where-Object UpdateId -eq 'b2').Note | Should -Match 'interakcji'
        @(Get-MwpUpdateRow -Search $null).Count | Should -Be 0
        @(Get-MwpUpdateRow -History $history).Count | Should -Be 2
        $failed = @(Get-MwpUpdateRow -History $history -FailedOnly)
        $failed.Count | Should -Be 1
        $failed[0].ErrorText | Should -Match '0x8024402C — brak połączenia'
    }

    It 'instalacja: tylko lokalnie, jako administrator i dla instalowalnych; pominięte w podglądzie' {
        $state = Get-MwpUpdateActionState -Status (Get-TestStatus) -Search $search -SelectedId 'a1', 'b2' -IsLocal $true -Ready $true
        $state.CanInstall | Should -BeTrue
        @($state.Installable).Count | Should -Be 1
        $state.PreviewLine[0] | Should -Match 'Zbiorcza .*KB5000001, 100 MB, może wymagać restartu'
        $state.PreviewLine[1] | Should -Match '^Pominięta: Sterownik'
        $state.SelectionText | Should -Match 'Zaznaczono 2 \(do instalacji: 1, do 100 MB\)'
        $remote = Get-MwpUpdateActionState -Status (Get-TestStatus) -Search $search -SelectedId 'a1' -IsLocal $false -Ready $true
        $remote.CanInstall | Should -BeFalse
        $remote.InstallBlocked | Should -Match 'D-048'
        $remote.CanOpenSettings | Should -BeFalse
        $remote.CanReset | Should -BeTrue
        $user = Get-MwpUpdateActionState -Status (Get-TestStatus -Admin $false) -Search $search -SelectedId 'a1' -IsLocal $true -Ready $true
        $user.CanInstall | Should -BeFalse
        $user.CanPause | Should -BeFalse
        $user.InstallBlocked | Should -Match 'administratora'
        (Get-MwpUpdateActionState -Status (Get-TestStatus) -Search $search -SelectedId 'b2').CanInstall | Should -BeFalse
        (Get-MwpUpdateActionState -Status (Get-TestStatus) -Search $search -SelectedId 'a1' -Ready $false).CanInstall | Should -BeFalse
    }

    It 'pauza i wznowienie: wznowienie tylko przy wartościach pauzy; bez odczytu stanu wszystko wyłączone' {
        (Get-MwpUpdateActionState -Status (Get-TestStatus) -Search $null).CanResume | Should -BeFalse
        (Get-MwpUpdateActionState -Status (Get-TestStatus -Paused $true) -Search $null).CanResume | Should -BeTrue
        $none = Get-MwpUpdateActionState -Status $null -Search $null
        $none.CanPause | Should -BeFalse
        $none.CanReset | Should -BeFalse
        $none.CanSearch | Should -BeTrue
    }

    It 'pozycje list: rodzaje wyszukiwania i 1–5 tygodni pauzy' {
        @(Get-MwpUpdateViewOption -Kind SearchType).Value | Should -Be @('All', 'Software', 'Driver')
        $weeks = @(Get-MwpUpdateViewOption -Kind PauseWeeks)
        @($weeks.Value) | Should -Be @(1, 2, 3, 4, 5)
        $weeks[0].Label | Should -Be '1 tydzień'
        $weeks[4].Label | Should -Be '5 tygodnie'
    }

    It 'szczegóły aktualizacji i podsumowanie stanu z kopiami z resetu' {
        $detail = Get-MwpUpdateDetail -Update ($search.Updates | Where-Object UpdateId -eq 'a1')
        $detail.Title | Should -Be 'Zbiorcza (KB5000001)'
        $detail.Text | Should -Match 'Opublikowana: 2026-10-14'
        $detail.Text | Should -Match 'Obowiązkowa'
        (Get-MwpUpdateDetail -Update ($search.Updates | Where-Object UpdateId -eq 'b2')).Text | Should -Match 'Aplikacja jej nie zainstaluje'
        (Get-MwpUpdateDetail -Update $null).Title | Should -Match 'Wybierz'
        $summary = Get-MwpUpdateDetail -Status (Get-TestStatus)
        $summary.Title | Should -Be 'Restart nie jest wymagany.'
        $summary.Backup | Should -Match 'mwp-20261028-120000 — SoftwareDistribution, catroot2'
        (Get-MwpUpdateDetail -Status $null).Title | Should -Match 'Brak odczytu'
    }

    It 'blok zadania instalacji: Install-MwpUpdate z kontekstem, tabelą postępu i -Confirm:$false; zmiany z widoku mają własny napis przycisku' {
        $text = (Get-MwpUiUpdateScript).ToString()
        $text | Should -Match 'Install-MwpUpdate -UpdateId \$UpdateId -Context \$Context -Progress \$Progress -Confirm:\$false'
        $text | Should -Match 'Import-Module -Name \$ModulePath'
        (Get-Command -Name Invoke-MwpUiInstanceChange).Parameters.ContainsKey('ConfirmText') | Should -BeTrue
    }
}
