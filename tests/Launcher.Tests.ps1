#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
    Testy launchera Start-MyWindowsPower.ps1. Launcher jest uruchamiany w osobnym procesie
    tej samej wersji PowerShella, w której działają testy (5.1 albo 7.x).
    Launcher niczego nie zmienia w systemie, więc testy są bezpieczne.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Zmienne z bloków BeforeDiscovery/BeforeAll są używane w blokach It (zakresy Pestera).')]
param()

BeforeAll {
    $launcher = Join-Path -Path (Split-Path -Parent $PSScriptRoot) -ChildPath 'Start-MyWindowsPower.ps1'
    $hostPath = (Get-Process -Id $PID).Path

    function Invoke-Launcher {
        param([string[]] $HostArguments = @())

        $output = & $hostPath -NoProfile @HostArguments -File $launcher 2>&1 | ForEach-Object { "$_" }
        [pscustomobject]@{
            ExitCode = $LASTEXITCODE
            Text     = $output -join [Environment]::NewLine
        }
    }
}

Describe 'Start-MyWindowsPower.ps1' {
    It 'parsuje się bez błędów składni' {
        $errors = $null
        $null = [Management.Automation.Language.Parser]::ParseFile($launcher, [ref]$null, [ref]$errors)
        $errors | Should -BeNullOrEmpty
    }

    Context 'uruchomienie w trybie STA' {
        BeforeAll {
            $result = Invoke-Launcher -HostArguments @('-STA')
        }

        It 'kończy się kodem 0' {
            $result.ExitCode | Should -Be 0
        }

        It 'wypisuje wersję PowerShella' {
            $result.Text | Should -Match ([regex]::Escape("PowerShell: $($PSVersionTable.PSVersion)"))
        }

        It 'wypisuje status administratora' {
            $result.Text | Should -Match 'Administrator: (tak|nie)'
        }

        It 'importuje wszystkie moduły' {
            $count = @(Get-ChildItem -Path (Join-Path -Path (Split-Path -Parent $launcher) -ChildPath 'src\Modules') -Directory -Filter 'MWP.*').Count
            $result.Text | Should -Match ("Zaimportowano moduły: {0}\." -f $count)
        }
    }

    Context 'uruchomienie w trybie MTA' {
        BeforeAll {
            $result = Invoke-Launcher -HostArguments @('-MTA')
        }

        It 'uruchamia się ponownie z -STA i kończy kodem 0' {
            $result.Text | Should -Match 'Ponowne uruchomienie z parametrem -STA'
            $result.Text | Should -Match 'Tryb wątku: STA'
            $result.ExitCode | Should -Be 0
        }
    }
}
