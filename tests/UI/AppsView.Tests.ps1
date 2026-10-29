#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
    Testy logiki prezentacji widoku aplikacji (FAZA 12, D-050) bez WPF: katalog widoków modułów, wiersze tabel
    (programy z filtrem, aktualizacje, wyniki wyszukiwania z oznaczeniem zainstalowanych), dostępność przycisków
    (ochrona, komputer zdalny bez administratora, program innego profilu, brak winget), szczegóły i pozycje list.
    Korekta D-051: program innego profilu w jego sesji (lokalnie z administratorem, zablokowany, gdy profil
    niezalogowany), kontekst pakietów (SYSTEM / użytkownik), profile i miejsce instalacji, tekst kontekstu winget.
    Dane z Resolve-MwpInstalledApp na surowym JSON — bez wywołań systemowych.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Zmienne z bloków BeforeDiscovery/BeforeAll są używane w blokach It (zakresy Pestera).')]
param()

Describe 'MWP.UI — widok aplikacji (logika prezentacji)' {
    BeforeAll {
        $root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        foreach ($name in 'MWP.Core', 'MWP.Remote', 'MWP.Apps') {
            Import-Module -Name (Join-Path -Path $root -ChildPath "src\Modules\$name\$name.psd1") -Force
        }
        Import-Module -Name (Join-Path -Path $root -ChildPath 'src\UI\MWP.UI.psm1') -Force

        function Get-TestInventory {
            param([bool] $Admin = $true)
            $raw = [pscustomobject]@{
                Kind = 'MWP.AppInventoryRaw'; ComputerName = 'PC'; CollectedAt = '2026-10-29T10:00:00Z'; IsAdministrator = $Admin; CurrentUser = 'PC\test'; CurrentUserSid = 'S-1-5-21-1-1000'
                Registry = @(
                    [pscustomobject]@{ KeyName = 'Git_is1'; Scope = 'Machine'; Architecture = 'X64'; UserSid = ''; UserName = ''; DisplayName = 'Git'; DisplayVersion = '2.55'; Publisher = 'Git'; InstallDate = '20260115'; InstallLocation = 'C:\Git'; EstimatedSizeKb = 2048; HasUninstall = $true; HasQuiet = $false; WindowsInstaller = $false; SystemComponent = $false; NoRemove = $false; ParentKeyName = ''; ReleaseType = '' }
                    [pscustomobject]@{ KeyName = 'Edge'; Scope = 'Machine'; Architecture = 'X86'; UserSid = ''; UserName = ''; DisplayName = 'Microsoft Edge'; DisplayVersion = '156'; Publisher = 'Microsoft'; InstallDate = ''; InstallLocation = ''; EstimatedSizeKb = 0; HasUninstall = $true; HasQuiet = $false; WindowsInstaller = $false; SystemComponent = $false; NoRemove = $false; ParentKeyName = ''; ReleaseType = '' }
                    [pscustomobject]@{ KeyName = 'Hidden'; Scope = 'Machine'; Architecture = 'X64'; UserSid = ''; UserName = ''; DisplayName = 'Ukryty'; DisplayVersion = '1'; Publisher = ''; InstallDate = ''; InstallLocation = ''; EstimatedSizeKb = 0; HasUninstall = $true; HasQuiet = $false; WindowsInstaller = $true; SystemComponent = $true; NoRemove = $false; ParentKeyName = ''; ReleaseType = '' }
                    [pscustomobject]@{ KeyName = 'Anna'; Scope = 'User'; Architecture = 'X64'; UserSid = 'S-1-5-21-1-1001'; UserName = 'PC\anna'; DisplayName = 'Program Anny'; DisplayVersion = '1'; Publisher = ''; InstallDate = ''; InstallLocation = ''; EstimatedSizeKb = 0; HasUninstall = $true; HasQuiet = $false; WindowsInstaller = $false; SystemComponent = $false; NoRemove = $false; ParentKeyName = ''; ReleaseType = '' }
                )
                Appx = @(
                    [pscustomobject]@{ Name = 'Microsoft.WindowsCamera'; DisplayName = 'Aparat'; PackageFullName = 'Microsoft.WindowsCamera_1_x64__8wekyb3d8bbwe'; PackageFamilyName = 'Microsoft.WindowsCamera_8wekyb3d8bbwe'; Publisher = 'CN=Microsoft Corporation, O=Microsoft Corporation'; Version = '1'; Architecture = 'X64'; SignatureKind = 'Store'; IsFramework = $false; IsResourcePackage = $false; IsBundle = $false; NonRemovable = $false; InstallLocation = '' }
                )
                Profiles = @([pscustomobject]@{ Sid = 'S-1-5-21-1-1000'; Name = 'PC\test'; IsCurrent = $true }, [pscustomobject]@{ Sid = 'S-1-5-21-1-1001'; Name = 'PC\anna'; IsCurrent = $false }); Warnings = @(); Error = $null
            }
            $inventory = Resolve-MwpInstalledApp -Data (ConvertTo-Json -Depth 6 -Compress -InputObject $raw)
            $packages = @([pscustomobject]@{ Name = 'Git'; Id = 'Git.Git'; Version = '2.55'; Available = '2.56'; HasUpgrade = $true; Match = ''; Source = 'winget'; IsLocalId = $false; Truncated = $false; Table = 1 })
            $null = Join-MwpAppWinget -App $inventory.Apps -Package $packages
            $inventory
        }
        function Get-AppId {
            param([object] $Inventory, [string] $Name)
            (@($Inventory.Apps | Where-Object { $_.Name -eq $Name }) | Select-Object -First 1).Id
        }
    }

    AfterAll {
        Remove-Module -Name MWP.UI, MWP.Apps, MWP.Remote, MWP.Core -Force -ErrorAction SilentlyContinue
    }

    It 'katalog widoków ma widok aplikacji z funkcjami okna' {
        $view = Get-MwpModuleViewCatalog -ModuleId Apps
        $view.View | Should -Be 'Views\Apps.xaml'
        Test-Path -LiteralPath (Join-Path -Path $root -ChildPath ('src\UI\' + $view.View)) | Should -BeTrue
        Get-Command -Name $view.Initialize -Module MWP.UI | Should -Not -BeNullOrEmpty
        Get-Command -Name $view.Update -Module MWP.UI | Should -Not -BeNullOrEmpty
    }

    It 'wiersze programów: filtr (składniki systemowe ukryte, wyszukiwanie, źródło, tylko z aktualizacją), teksty kolumn i oznaczenie ochrony' {
        $inventory = Get-TestInventory
        $rows = @(Get-MwpAppsRow -Inventory $inventory)
        $rows.Name | Should -Not -Contain 'Ukryty'
        $git = $rows | Where-Object { $_.Name -eq 'Git' }
        $git.Available | Should -Be '2.56'
        $git.SourceText | Should -Be 'Rejestr · winget'
        $git.InstallDateText | Should -Be '2026-01-15'
        $git.SizeText | Should -Be '2,0 MB'
        ($rows | Where-Object { $_.Name -eq 'Microsoft Edge' }).ProtectionText | Should -Be 'Chroniona'
        @(Get-MwpAppsRow -Inventory $inventory -Filter @{ IncludeSystemComponent = $true }).Count | Should -Be 5
        @(Get-MwpAppsRow -Inventory $inventory -Filter @{ Search = 'apar' }).Name | Should -Be 'Aparat'
        @(Get-MwpAppsRow -Inventory $inventory -Filter @{ Source = 'Appx' }).Name | Should -Be 'Aparat'
        @(Get-MwpAppsRow -Inventory $inventory -Filter @{ UpgradeOnly = $true }).Name | Should -Be 'Git'
        @(Get-MwpAppsRow -Inventory $null).Count | Should -Be 0
    }

    It 'wiersze pakietów: aktualizacje i wyniki wyszukiwania z oznaczeniem zainstalowanych' {
        $search = [pscustomobject]@{ Packages = @(
                [pscustomobject]@{ Name = 'Git'; Id = 'Git.Git'; Version = '2.56'; Available = ''; Match = 'Moniker: git'; Truncated = $false; Table = 1 }
                [pscustomobject]@{ Name = '7-Zip'; Id = '7zip.7zip'; Version = '26'; Available = ''; Match = ''; Truncated = $false; Table = 1 }
            )
        }
        $installed = [pscustomobject]@{ Packages = @([pscustomobject]@{ Id = 'Git.Git'; Version = '2.55' }) }
        $rows = @(Get-MwpAppsRow -Package $search -Installed $installed)
        $rows[0].InstalledText | Should -Be 'Tak (2.55)'
        $rows[1].InstalledText | Should -Be ''
        @(Get-MwpAppsRow -Package $null).Count | Should -Be 0
    }

    It 'przyciski: odinstalowanie zwykłej aplikacji, blokada chronionej, aktualizacja tylko z winget i nowszą wersją' {
        $inventory = Get-TestInventory
        $git = Get-MwpAppsActionState -Inventory $inventory -AppId (Get-AppId $inventory 'Git') -WingetAvailable $true
        $git.CanUninstall | Should -BeTrue
        $git.CanUpgradeApp | Should -BeTrue
        $edge = Get-MwpAppsActionState -Inventory $inventory -AppId (Get-AppId $inventory 'Microsoft Edge') -WingetAvailable $true
        $edge.CanUninstall | Should -BeFalse
        $edge.Hint | Should -Match 'Chroniona'
        $camera = Get-MwpAppsActionState -Inventory $inventory -AppId (Get-AppId $inventory 'Aparat') -WingetAvailable $false
        $camera.CanUninstall | Should -BeTrue
        $camera.CanUpgradeApp | Should -BeFalse
        $noWinget = Get-MwpAppsActionState -Inventory $inventory -AppId (Get-AppId $inventory 'Git') -WingetAvailable $false
        $noWinget.CanUninstall | Should -BeFalse
        $noWinget.Hint | Should -Match 'winget'
        (Get-MwpAppsActionState -Inventory $inventory -AppId (Get-AppId $inventory 'Git') -WingetAvailable $true -Ready $false).CanUninstall | Should -BeFalse
    }

    It 'komputer zdalny: bez administratora zmiany wyłączone; program innego profilu w jego sesji (zablokowany, gdy niezalogowany); wyszukiwanie i instalacja wymagają winget' {
        $inventory = Get-TestInventory -Admin $false
        $state = Get-MwpAppsActionState -Inventory $inventory -AppId (Get-AppId $inventory 'Git') -WingetAvailable $true -Remote $true -SelectedUpgrades 2 -SearchSelected $true
        $state.CanUninstall | Should -BeFalse
        $state.CanUpgrade | Should -BeFalse
        $state.CanInstall | Should -BeFalse
        $state.Hint | Should -Match 'administratora'
        $admin = Get-TestInventory
        $anna = Get-MwpAppsActionState -Inventory $admin -AppId (Get-AppId $admin 'Program Anny') -WingetAvailable $true -Remote $true
        $anna.CanUninstall | Should -BeTrue
        $anna.Hint | Should -Match 'w sesji tego użytkownika'
        $loggedOff = [pscustomobject]@{ Packages = @(); Runs = @([pscustomobject]@{ RunAs = 'System'; UserSid = ''; Success = $true; Message = '' }, [pscustomobject]@{ RunAs = 'User'; UserSid = 'S-1-5-21-1-1001'; UserName = 'PC\anna'; Success = $false; Message = 'Użytkownik PC\anna nie jest zalogowany na komputerze ''PC''.' }) }
        $blocked = Get-MwpAppsActionState -Inventory $admin -AppId (Get-AppId $admin 'Program Anny') -WingetAvailable $true -Packages $loggedOff -Remote $true
        $blocked.CanUninstall | Should -BeFalse
        $blocked.Hint | Should -Match 'nie jest zalogowany'
        # localhost: program innego profilu w jego sesji tylko jako administrator.
        (Get-MwpAppsActionState -Inventory (Get-TestInventory -Admin $false) -AppId (Get-AppId $admin 'Program Anny') -WingetAvailable $true).Hint | Should -Match 'administrator'
        (Get-MwpAppsActionState -Inventory $admin -AppId (Get-AppId $admin 'Program Anny') -WingetAvailable $true).CanUninstall | Should -BeTrue
        $ok = Get-MwpAppsActionState -Inventory $admin -AppId '' -WingetAvailable $true -Remote $true -SelectedUpgrades 1 -SearchSelected $true
        $ok.CanUpgrade | Should -BeTrue
        $ok.CanInstall | Should -BeTrue
        (Get-MwpAppsActionState -Inventory $admin -WingetAvailable $false -SearchSelected $true).CanSearch | Should -BeFalse
    }

    It 'szczegóły: wersja z aktualizacją, źródło, winget, sposób odinstalowania i ochrona; pozycje list' {
        $inventory = Get-TestInventory
        $detail = Get-MwpAppsDetail -App (@($inventory.Apps | Where-Object { $_.Name -eq 'Git' })[0])
        $detail.Title | Should -Be 'Git'
        $detail.Text | Should -Match 'dostępna aktualizacja: 2.56'
        $detail.Text | Should -Match 'winget: Git.Git'
        $detail.Text | Should -Match 'cofnięcie przez ponowną instalację'
        $edge = Get-MwpAppsDetail -App (@($inventory.Apps | Where-Object { $_.Name -eq 'Microsoft Edge' })[0])
        $edge.Title | Should -Match 'chroniona'
        (Get-MwpAppsDetail -App $null).Title | Should -Match 'Wybierz'
        @(Get-MwpAppsViewOption -Kind Source).Value | Should -Be @('All', 'Registry', 'Appx')
        @(Get-MwpAppsViewOption -Kind Scope).Value | Should -Be @('All', 'Machine', 'User')
    }

    It 'kontekst winget (D-051): profile i miejsce instalacji, kontekst pakietów w aktualizacjach, aktualizacja pakietu profilu w jego sesji' {
        $inventory = Get-TestInventory
        @(Get-MwpAppsTargetOption -Kind Profile -Inventory $inventory -Remote $true).Value | Should -Be @('', 'S-1-5-21-1-1000', 'S-1-5-21-1-1001')
        @(Get-MwpAppsTargetOption -Kind Profile -Inventory $inventory).Value | Should -Be @('', 'S-1-5-21-1-1001')
        $install = @(Get-MwpAppsTargetOption -Kind Install -Inventory $inventory -Remote $true)
        $install[0].Label | Should -Match 'SYSTEM'
        $install[0].Value | Should -Be ''
        (Get-MwpAppsTargetOption -Kind Install -Inventory $null)[0].Label | Should -Be 'Konto aplikacji'
        $list = [pscustomobject]@{
            Packages = @(
                [pscustomobject]@{ Name = 'Git'; Id = 'Git.Git'; Version = '2.55'; Available = '2.56'; HasUpgrade = $true; Match = ''; Truncated = $false; Table = 1; RunAs = 'System'; UserSid = ''; UserName = '' }
                [pscustomobject]@{ Name = 'Teams'; Id = 'Microsoft.Teams'; Version = '1'; Available = '2'; HasUpgrade = $true; Match = ''; Truncated = $false; Table = 1; RunAs = 'User'; UserSid = 'S-1-5-21-1-1001'; UserName = 'PC\anna' }
            )
            Runs     = @([pscustomobject]@{ RunAs = 'System'; UserSid = ''; Success = $true; Message = '' }, [pscustomobject]@{ RunAs = 'User'; UserSid = 'S-1-5-21-1-1001'; UserName = 'PC\anna'; Success = $true; Message = '' })
        }
        $rows = @(Get-MwpAppsRow -Package $list)
        $rows[0].ContextText | Should -Be 'SYSTEM'
        $rows[1].ContextText | Should -Be 'PC\anna'
        $rows[1].UserSid | Should -Be 'S-1-5-21-1-1001'
        (Get-MwpAppsActionState -Inventory $inventory -AppId (Get-AppId $inventory 'Git') -WingetAvailable $true -Packages $list -Remote $true).UpgradeUserSid | Should -Be ''
        Get-MwpAppsContextText -Remote $true -Packages $list | Should -Match 'SYSTEM.*Profil PC\\anna: odczytany'
        Get-MwpAppsContextText | Should -Match 'bezpośrednio na koncie aplikacji'
    }
}
