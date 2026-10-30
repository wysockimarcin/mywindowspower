#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
    Testy logiki prezentacji korekty D-054 (bez WPF): etykieta komputera (Format-MwpTargetLabel),
    wiersze siatki „Komputery docelowe” (kolumny Nazwa i Adres IP, adres LAN localhost tylko
    informacyjnie), ostrzeżenia edytora komputera i stan połączenia NameMismatch. Adresy są
    dokumentacyjne (192.0.2.x, 198.51.100.x), nazwy komputerów fikcyjne.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Zmienne z bloków BeforeDiscovery/BeforeAll są używane w blokach It (zakresy Pestera).')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingComputerNameHardcoded', '',
    Justification = 'Sztuczne nazwy komputerów testowych; testy nie łączą się z żadnym komputerem.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
    Justification = 'Pomocnicze funkcje testów tworzą tylko obiekty w pamięci.')]
param()

Describe 'MWP.UI — nazwa komputera i adres (D-054)' {
    BeforeAll {
        $root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        Import-Module -Name (Join-Path -Path $root -ChildPath 'src\Modules\MWP.Core\MWP.Core.psd1') -Force
        Import-Module -Name (Join-Path -Path $root -ChildPath 'src\Modules\MWP.Remote\MWP.Remote.psd1') -Force
        Mock -ModuleName MWP.Remote Invoke-MwpCredentialApi { throw 'Testy nie mogą używać prawdziwego Menedżera poświadczeń Windows.' }
        Clear-MwpTargetCredentialCache
        Import-Module -Name (Join-Path -Path $root -ChildPath 'src\UI\MWP.UI.psm1') -Force

        function New-TestContext {
            param([string] $ComputerName, [string] $Address, [string] $Mode = 'Remote')
            [pscustomobject]@{ PSTypeName = 'MWP.ExecutionContext'; ComputerName = $ComputerName; Address = $Address; Mode = $Mode }
        }
        function New-TestTarget {
            param([string] $Name, [string] $Address = '', [bool] $IsLocal = $false, [bool] $UseSsl = $false)
            $connectionAddress = if ($IsLocal) { 'localhost' } elseif ($Address -eq '' -or $UseSsl) { $Name } else { $Address }
            [pscustomobject]@{
                PSTypeName = 'MWP.Target'; Name = $Name; Address = $Address; ConnectionAddress = $connectionAddress; DisplayName = $Name
                IsLocal = $IsLocal; Transport = $(if ($IsLocal) { 'Local' } else { 'WinRM' }); Port = 5985; UseSsl = $UseSsl
                Authentication = 'Credential'; UserName = ''
            }
        }
    }

    AfterAll {
        Remove-Module -Name MWP.UI, MWP.Remote, MWP.Core -Force -ErrorAction SilentlyContinue
    }

    Context 'Format-MwpTargetLabel' {
        It 'komputer zdalny: nazwa; podtytuł z adresem, gdy łączymy po adresie' {
            $context = New-TestContext -ComputerName 'PC-BIURO' -Address '192.0.2.10'
            Format-MwpTargetLabel -Context $context | Should -Be 'PC-BIURO'
            Format-MwpTargetLabel -Context $context -Format Subtitle | Should -Be 'PC-BIURO (192.0.2.10, zdalnie, WinRM)'
            Format-MwpTargetLabel -Context (New-TestContext -ComputerName 'PC-BIURO' -Address 'PC-BIURO') -Format Subtitle | Should -Be 'PC-BIURO (zdalnie, WinRM)'
        }

        It 'localhost: nazwa hosta zamiast identyfikatora; bez adresu LAN w podtytule' {
            $context = New-TestContext -ComputerName 'localhost' -Address 'localhost' -Mode 'Local'
            Format-MwpTargetLabel -Context $context | Should -Be $env:COMPUTERNAME
            Format-MwpTargetLabel -Context $context -Format Subtitle | Should -Be ('{0} (ten komputer, lokalnie)' -f $env:COMPUTERNAME)
            Format-MwpTargetLabel -ComputerName 'localhost' | Should -Be $env:COMPUTERNAME
            Format-MwpTargetLabel -ComputerName 'PC-BIURO' | Should -Be 'PC-BIURO'
        }

        It 'wpis zapisany pod adresem IP pokazuje adres (do zmiany nazwy)' {
            Format-MwpTargetLabel -Context (New-TestContext -ComputerName '192.0.2.40' -Address '192.0.2.40') -Format Subtitle | Should -Be '192.0.2.40 (zdalnie, WinRM)'
        }
    }

    Context 'Get-MwpTargetRow (siatka Komputery docelowe)' {
        It 'localhost: nazwa hosta i adres LAN z podpowiedzią; identyfikator localhost zostaje w wierszu' {
            $address = [pscustomobject]@{ Text = '192.0.2.77'; ToolTip = 'Karta: Ethernet'; Status = 'Ok' }
            $row = @(Get-MwpTargetRow -Target @(New-TestTarget -Name 'localhost' -IsLocal $true) -LocalAddress $address)[0]
            $row.Name | Should -Be 'localhost'
            $row.NameText | Should -Be $env:COMPUTERNAME
            $row.AddressText | Should -Be '192.0.2.77'
            $row.AddressToolTip | Should -Match 'tylko informacyjnie'
            $row.AddressToolTip | Should -Match 'Karta: Ethernet'
            $row.NeedsName | Should -BeFalse
        }

        It 'localhost przed odczytem: „odczyt…” (siatka pokazuje się od razu)' {
            $row = @(Get-MwpTargetRow -Target @(New-TestTarget -Name 'localhost' -IsLocal $true) -LocalAddress $null)[0]
            $row.AddressText | Should -Be 'odczyt…'
        }

        It 'komputer zdalny z adresem i bez; adresy wykryte w podpowiedzi; HTTPS — po nazwie' {
            $rows = @(Get-MwpTargetRow -Target @(
                    (New-TestTarget -Name 'PC-ADRES' -Address '192.0.2.10'),
                    (New-TestTarget -Name 'PC-NAZWA'),
                    (New-TestTarget -Name 'PC-SSL' -Address '192.0.2.30' -UseSsl $true)
                ) -Detected @{ 'PC-ADRES' = @('192.0.2.10', '198.51.100.10') })
            $rows[0].NameText | Should -Be 'PC-ADRES'
            $rows[0].AddressText | Should -Be '192.0.2.10'
            $rows[0].AddressToolTip | Should -Match '198\.51\.100\.10'
            $rows[1].AddressText | Should -Be '— (po nazwie)'
            $rows[2].AddressToolTip | Should -Match 'HTTPS'
        }

        It 'komputer zapisany pod adresem IP jest oznaczony do ustawienia nazwy (baner)' {
            $row = @(Get-MwpTargetRow -Target @(New-TestTarget -Name '192.0.2.40'))[0]
            $row.NeedsName | Should -BeTrue
            $row.NameText | Should -Be '192.0.2.40'
        }
    }

    Context 'Get-MwpTargetEditorWarning' {
        It 'ten komputer, HTTPS z adresem i nazwa będąca adresem IP — ostrzeżenia, bez blokady' {
            $local = [pscustomobject]@{ IsLocalComputer = $true; Message = 'To ten komputer (…): użyj localhost' }
            @(Get-MwpTargetEditorWarning -Name 'PC-X' -LocalCheck $local) | Should -Contain $local.Message
            (@(Get-MwpTargetEditorWarning -Name 'PC-X' -Address '192.0.2.5' -UseSsl $true) -join ' ') | Should -Match 'HTTPS'
            (@(Get-MwpTargetEditorWarning -Name '192.0.2.5') -join ' ') | Should -Match 'Odczytaj nazwę'
            @(Get-MwpTargetEditorWarning -Name 'PC-X' -Address '192.0.2.5').Count | Should -Be 0
            @(Get-MwpTargetEditorWarning -Name '').Count | Should -Be 0
        }
    }

    Context 'stan połączenia' {
        It 'NameMismatch: „Inny komputer pod adresem” z komunikatem' {
            $context = [pscustomobject]@{
                PSTypeName = 'MWP.ExecutionContext'; ComputerName = 'PC-X'; Mode = 'Remote'
                Identity   = [pscustomobject]@{ Authentication = 'CurrentUser' }
                Connection = [pscustomobject]@{ State = 'Error'; ErrorKind = 'NameMismatch'; LastError = 'Pod adresem odpowiada komputer PC-Y'; StateChangedAt = Get-Date; Credential = $null }
            }
            $state = Get-MwpConnectionStateInfo -Context $context
            $state.Label | Should -Be 'Inny komputer pod adresem'
            $state.Tone | Should -Be 'Danger'
            $state.Detail | Should -Match 'PC-Y'
        }
    }
}
