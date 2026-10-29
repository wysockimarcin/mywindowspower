#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
    Testy logiki prezentacji widoku Zasilanie (FAZA 6, D-044) bez WPF: katalog widoków modułów,
    pozycje list AC/DC, wyliczenie kroków zmian z wyborów w widoku i blok zadania wykonującego kroki
    (podgląd -WhatIf i wykonanie -Confirm:$false z kontekstem instancji). Funkcje MWP.Power są
    zastąpione funkcjami testowymi — system bez zmian.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Zmienne z bloków BeforeDiscovery/BeforeAll są używane w blokach It (zakresy Pestera).')]
param()

Describe 'MWP.UI — widok Zasilanie (logika prezentacji)' {
    BeforeAll {
        $root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        Import-Module -Name (Join-Path -Path $root -ChildPath 'src\Modules\MWP.Core\MWP.Core.psd1') -Force
        Import-Module -Name (Join-Path -Path $root -ChildPath 'src\Modules\MWP.Remote\MWP.Remote.psd1') -Force
        # D-052: testy nie dotykają prawdziwego Menedżera poświadczeń; pamięć poświadczeń jest wspólna dla procesu.
        Mock -ModuleName MWP.Remote Invoke-MwpCredentialApi { throw 'Testy nie mogą używać prawdziwego Menedżera poświadczeń Windows.' }
        Clear-MwpTargetCredentialCache
        Import-Module -Name (Join-Path -Path $root -ChildPath 'src\UI\MWP.UI.psm1') -Force

        function Get-TestStatus {
            [pscustomobject]@{
                Kind        = 'MWP.PowerStatus'
                ActivePlan  = [pscustomobject]@{ Guid = '381b4222-f694-41f0-9685-ff5bb260df2e'; Name = 'Zrównoważony' }
                Settings    = @(
                    [pscustomobject]@{ Id = 'MonitorTimeout'; Label = 'Wyłącz ekran po'; Kind = 'Timeout'; Available = $true; Ac = 600; Dc = 180; MaxIndex = 0 }
                    [pscustomobject]@{ Id = 'LidAction'; Label = 'Zamknięcie pokrywy'; Kind = 'Action'; Available = $false; Ac = $null; Dc = $null; MaxIndex = 3 }
                )
                Hibernate   = $true
                FastStartup = $null
            }
        }
    }

    AfterAll {
        Remove-Module -Name MWP.UI, MWP.Remote, MWP.Core -Force -ErrorAction SilentlyContinue
    }

    It 'katalog widoków ma widok modułu Power z plikiem w src\UI\Views i funkcjami MWP.UI' {
        $view = Get-MwpModuleViewCatalog -ModuleId 'Power'
        $view.View | Should -Be 'Views\Power.xaml'
        Test-Path -LiteralPath (Join-Path -Path $root -ChildPath ('src\UI\{0}' -f $view.View)) | Should -BeTrue
        Get-Command -Name $view.Initialize -Module MWP.UI | Should -Not -BeNullOrEmpty
        Get-Command -Name $view.Update -Module MWP.UI | Should -Not -BeNullOrEmpty
        Get-MwpModuleViewCatalog -ModuleId 'Tweaks' | Should -BeNullOrEmpty
    }

    It 'pozycje czasów: Nigdy, minuty i godziny; wartość spoza listy jest dopisywana' {
        $options = @(Get-MwpPowerOption -Kind Timeout -Current 420)
        $options[0].Label | Should -Be 'Nigdy'
        ($options | Where-Object Value -eq 600).Label | Should -Be '10 min'
        ($options | Where-Object Value -eq 7200).Label | Should -Be '2 godz.'
        ($options | Where-Object Value -eq 420).Label | Should -Be '7 min'
        @($options | Where-Object Value -eq 600).Count | Should -Be 1
    }

    It 'pozycje akcji do MaxIndex' {
        $options = @(Get-MwpPowerOption -Kind Action -MaxIndex 3)
        $options.Count | Should -Be 4
        $options[3].Label | Should -Be 'Zamknij system'
        @(Get-MwpPowerOption -Kind Action -MaxIndex 4)[4].Label | Should -Be 'Wyłącz ekran'
    }

    It 'kroki zmian: tylko różnice, z GUID planu aktywnego; ustawienia niedostępne są pomijane' {
        $selection = @{ 'MonitorTimeout|AC' = 600; 'MonitorTimeout|DC' = 300; 'LidAction|AC' = 0; Hibernate = $false; FastStartup = $true }
        $steps = @(Get-MwpPowerChangeStep -Status (Get-TestStatus) -Selection $selection)
        $steps.Count | Should -Be 3
        $steps[0].Command | Should -Be 'Set-MwpPowerSetting'
        $steps[0].Parameters.PowerSource | Should -Be 'DC'
        $steps[0].Parameters.Value | Should -Be 300
        $steps[0].Parameters.PlanGuid | Should -Be '381b4222-f694-41f0-9685-ff5bb260df2e'
        $steps[1].Command | Should -Be 'Set-MwpHibernation'
        $steps[1].Parameters.Enabled | Should -BeFalse
        $steps[2].Command | Should -Be 'Set-MwpFastStartup'
    }

    It 'brak zmian albo brak stanu: brak kroków' {
        @(Get-MwpPowerChangeStep -Status (Get-TestStatus) -Selection @{ 'MonitorTimeout|AC' = 600; Hibernate = $true }).Count | Should -Be 0
        @(Get-MwpPowerChangeStep -Status $null -Selection @{ Hibernate = $true }).Count | Should -Be 0
    }

    Context 'blok zadania kroków zmian' {
        BeforeAll {
            $script:Invocations = New-Object -TypeName System.Collections.Generic.List[object]
            # Funkcja testowa w zakresie globalnym: blok zadania (z MWP.UI) wywołuje kroki po nazwie.
            Set-Item -Path 'Function:\global:Set-MwpTestPowerThing' -Value {
                [CmdletBinding(SupportsShouldProcess)]
                param([int] $Value, [object] $Context)
                $script:Invocations.Add(@{ Value = $Value; Context = $Context; WhatIf = [bool]$WhatIfPreference })
                $preview = -not $PSCmdlet.ShouldProcess('test', 'zmiana')
                [pscustomobject]@{ PSTypeName = 'MWP.Result'; Success = $true; IsPreview = $preview; Message = "wartość $Value" }
            }
        }

        AfterAll {
            Remove-Item -Path 'Function:\Set-MwpTestPowerThing' -ErrorAction SilentlyContinue
        }

        It 'podgląd przekazuje -WhatIf i kontekst, wynik ma indeks kroku' {
            $block = Get-MwpUiChangeScript
            $progress = @{ Percent = -1; Message = ''; CancelRequested = $false }
            $context = New-MwpExecutionContext
            $steps = @(
                @{ Command = 'Set-MwpTestPowerThing'; Parameters = @{ Value = 1 }; Label = 'pierwszy' }
                @{ Command = 'Set-MwpTestPowerThing'; Parameters = @{ Value = 2 }; Label = 'drugi' }
            )
            $output = @(& $block $progress '' $context $steps $true)
            $output.Count | Should -Be 2
            $output[1].Index | Should -Be 1
            $output[1].Result.IsPreview | Should -BeTrue
            $script:Invocations[0].Context.Id | Should -Be $context.Id
            $script:Invocations[0].WhatIf | Should -BeTrue
            $progress.Message | Should -Be 'drugi'
        }

        It 'wykonanie bez -WhatIf; anulowanie zatrzymuje kolejne kroki' {
            $script:Invocations.Clear()
            $block = Get-MwpUiChangeScript
            $progress = @{ Percent = -1; Message = ''; CancelRequested = $false }
            $output = @(& $block $progress '' (New-MwpExecutionContext) @(@{ Command = 'Set-MwpTestPowerThing'; Parameters = @{ Value = 5 }; Label = 'x' }) $false)
            $output[0].Result.IsPreview | Should -BeFalse
            $script:Invocations[0].WhatIf | Should -BeFalse

            $progress.CancelRequested = $true
            @(& $block $progress '' (New-MwpExecutionContext) @(@{ Command = 'Set-MwpTestPowerThing'; Parameters = @{ Value = 6 }; Label = 'y' }) $false).Count | Should -Be 0
        }
    }
}
