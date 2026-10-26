#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
    Testy rejestru komputerów docelowych: Get-MwpTarget, Add-MwpTarget, Remove-MwpTarget, Set-MwpTarget
    oraz odczytu Get-MwpTargetInfo (z mockami wykonania).
    Ustawienia i dane są na TestDrive (mocki ścieżek w MWP.Core); nazwy komputerów są fikcyjne.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Zmienne z bloków BeforeDiscovery/BeforeAll są używane w blokach It (zakresy Pestera).')]
param()

Describe 'Rejestr komputerów docelowych' {
    BeforeAll {
        $root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
        Import-Module -Name (Join-Path -Path $root -ChildPath 'src\Modules\MWP.Core\MWP.Core.psd1') -Force
        Import-Module -Name (Join-Path -Path $root -ChildPath 'src\Modules\MWP.Remote\MWP.Remote.psd1') -Force
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
        $localPath = Join-Path -Path $configDirectory -ChildPath 'settings.local.json'
        $computerOne = 'PC-TEST1'
        $computerTwo = 'PC-TEST2'

        function Write-TestTarget {
            param([object[]] $Target)
            ConvertTo-Json -InputObject ([ordered]@{ schemaVersion = 2; targets = @($Target) }) -Depth 5 |
                Set-Content -LiteralPath $localPath -Encoding UTF8
        }
    }

    AfterAll {
        Remove-Module -Name MWP.Remote, MWP.Core -Force -ErrorAction SilentlyContinue
    }

    BeforeEach {
        Get-ChildItem -LiteralPath $configDirectory -Filter 'settings.local.json*' | Remove-Item -Force
        Remove-Item -LiteralPath (Join-Path -Path $TestDrive -ChildPath 'Undo') -Recurse -Force -ErrorAction SilentlyContinue
    }

    Context 'Get-MwpTarget' {
        It 'bez pliku lokalnego zwraca tylko localhost (wpis przykładowy z szablonu jest pomijany)' {
            $targets = @(Get-MwpTarget)

            $targets.Count | Should -Be 1
            $targets[0].Name | Should -Be 'localhost'
            $targets[0].IsLocal | Should -BeTrue
            $targets[0].Transport | Should -Be 'Local'
        }

        It 'localhost jest zawsze pierwszy, a komputery zdalne mają transport WinRM i domyślny port' {
            Write-TestTarget @(@{ name = $computerOne; displayName = 'Biuro' }, @{ name = $computerTwo; useSsl = $true })

            $targets = @(Get-MwpTarget)

            $targets.Name | Should -Be @('localhost', $computerOne, $computerTwo)
            $targets[1].DisplayName | Should -Be 'Biuro'
            $targets[1].Port | Should -Be 5985
            $targets[1].Authentication | Should -Be 'Credential'
            $targets[2].Port | Should -Be 5986
            $targets[2].UseSsl | Should -BeTrue
        }

        It 'pomija z ostrzeżeniem niepoprawne nazwy, nazwy komputera lokalnego i duplikaty' {
            Write-TestTarget @(
                @{ name = 'zła nazwa;rm' }
                @{ name = '127.0.0.1' }
                @{ name = $computerOne }
                @{ name = $computerOne }
                @{ name = $computerTwo; transport = 'SSH' }
            )

            $targets = @(Get-MwpTarget -WarningVariable warnings -WarningAction SilentlyContinue)

            $targets.Name | Should -Be @('localhost', $computerOne)
            @($warnings).Count | Should -Be 4
        }

        It 'filtruje po nazwie' {
            Write-TestTarget @(@{ name = $computerOne }, @{ name = $computerTwo })

            (Get-MwpTarget -Name '*TEST2').Name | Should -Be $computerTwo
        }
    }

    Context 'Add-MwpTarget i Remove-MwpTarget' {
        It 'dodaje komputer do pliku lokalnego z wpisem cofnięcia, bez hasła' {
            $result = Add-MwpTarget -Name $computerOne -DisplayName 'Biuro' -UserName 'PC-TEST1\admin'

            $result.Success | Should -BeTrue
            $result.Changed | Should -BeTrue
            $result.UndoId | Should -Not -BeNullOrEmpty
            (Get-MwpTarget -Name $computerOne).UserName | Should -Be 'PC-TEST1\admin'
            $saved = Get-Content -LiteralPath $localPath -Raw -Encoding UTF8
            $saved | Should -Match 'PC-TEST1'
            $saved | Should -Not -Match '(?i)password|haslo|hasło'
        }

        It '-WhatIf niczego nie zapisuje' {
            $result = Add-MwpTarget -Name $computerOne -WhatIf

            $result.IsPreview | Should -BeTrue
            $localPath | Should -Not -Exist
        }

        It 'odrzuca localhost, niepoprawną nazwę i duplikat' {
            (Add-MwpTarget -Name 'localhost').Success | Should -BeFalse
            (Add-MwpTarget -Name $env:COMPUTERNAME).Success | Should -BeFalse
            (Add-MwpTarget -Name 'a b').Success | Should -BeFalse
            $null = Add-MwpTarget -Name $computerOne
            (Add-MwpTarget -Name $computerOne).Message | Should -Match 'już w rejestrze'
        }

        It 'nie przenosi wpisu przykładowego z szablonu do pliku lokalnego' {
            $null = Add-MwpTarget -Name $computerOne

            (Get-Content -LiteralPath $localPath -Raw -Encoding UTF8) | Should -Not -Match 'NAZWA-KOMPUTERA'
        }

        It 'usuwa komputer; localhost i nieznany komputer są odrzucane' {
            $null = Add-MwpTarget -Name $computerOne
            $null = Add-MwpTarget -Name $computerTwo

            (Remove-MwpTarget -Name 'localhost').Success | Should -BeFalse
            (Remove-MwpTarget -Name 'PC-BRAK').Success | Should -BeFalse
            (Remove-MwpTarget -Name $computerOne).Success | Should -BeTrue

            (Get-MwpTarget).Name | Should -Be @('localhost', $computerTwo)
        }

        It 'usunięcie ostatniego komputera zostawia pustą listę' {
            $null = Add-MwpTarget -Name $computerOne

            (Remove-MwpTarget -Name $computerOne).Success | Should -BeTrue

            @(Get-MwpTarget).Count | Should -Be 1
        }

        It 'dodanie można cofnąć przez Invoke-MwpUndo' {
            $null = Add-MwpTarget -Name $computerOne
            $change = Add-MwpTarget -Name $computerTwo

            (Invoke-MwpUndo -Id $change.UndoId).Success | Should -BeTrue

            (Get-MwpTarget).Name | Should -Be @('localhost', $computerOne)
        }
    }

    Context 'Set-MwpTarget (FAZA 4: edycja w Ustawieniach)' {
        It 'zmienia tylko podane pola i zapisuje wpis cofnięcia' {
            $null = Add-MwpTarget -Name $computerOne -DisplayName 'Biuro' -UserName 'PC-TEST1\admin'

            $result = Set-MwpTarget -Name $computerOne -UserName 'PC-TEST1\admin2'

            $result.Success | Should -BeTrue
            $result.Changed | Should -BeTrue
            $result.UndoId | Should -Not -BeNullOrEmpty
            $target = Get-MwpTarget -Name $computerOne
            $target.UserName | Should -Be 'PC-TEST1\admin2'
            $target.DisplayName | Should -Be 'Biuro'
            $target.Port | Should -Be 5985
        }

        It 'przełączenie HTTPS bez portu zmienia port domyślny na 5986' {
            $null = Add-MwpTarget -Name $computerOne

            $null = Set-MwpTarget -Name $computerOne -UseSsl $true

            $target = Get-MwpTarget -Name $computerOne
            $target.UseSsl | Should -BeTrue
            $target.Port | Should -Be 5986
        }

        It '-WhatIf zwraca podgląd z różnicami i niczego nie zapisuje' {
            $null = Add-MwpTarget -Name $computerOne -DisplayName 'Biuro'

            $preview = Set-MwpTarget -Name $computerOne -DisplayName 'Dom' -WhatIf

            $preview.IsPreview | Should -BeTrue
            $preview.Message | Should -Match "displayName: 'Biuro' -> 'Dom'"
            (Get-MwpTarget -Name $computerOne).DisplayName | Should -Be 'Biuro'
        }

        It 'brak różnic daje wynik bez zmian, a nieznany komputer — błąd' {
            $null = Add-MwpTarget -Name $computerOne -DisplayName 'Biuro'

            $same = Set-MwpTarget -Name $computerOne -DisplayName 'Biuro'
            $same.Success | Should -BeTrue
            $same.Changed | Should -BeFalse
            (Set-MwpTarget -Name 'PC-BRAK' -DisplayName 'X').Success | Should -BeFalse
        }

        It 'zmianę można cofnąć przez Invoke-MwpUndo' {
            $null = Add-MwpTarget -Name $computerOne -DisplayName 'Biuro'
            $change = Set-MwpTarget -Name $computerOne -DisplayName 'Dom'

            (Invoke-MwpUndo -Id $change.UndoId).Success | Should -BeTrue

            (Get-MwpTarget -Name $computerOne).DisplayName | Should -Be 'Biuro'
        }
    }

    Context 'Get-MwpTargetInfo (odczyt testowy instancji)' {
        It 'synchronicznie wykonuje samowystarczalny blok przez Invoke-MwpOnTarget' {
            Mock -ModuleName MWP.Remote Invoke-MwpOnTarget { New-MwpResult -Success $true -Operation $Operation -Message 'ok' -Data ([pscustomobject]@{ ComputerName = 'X' }) }
            $context = New-MwpExecutionContext

            $result = Get-MwpTargetInfo -Context $context

            $result.Success | Should -BeTrue
            Should -Invoke -ModuleName MWP.Remote Invoke-MwpOnTarget -Times 1 -ParameterFilter {
                $Operation -eq 'Remote.TargetInfo' -and $ScriptBlock.ToString() -match 'Win32_OperatingSystem' -and $Context.ComputerName -eq 'localhost'
            }
        }

        It 'z -AsOperation uruchamia operację w tle (Start-MwpOperation)' {
            Mock -ModuleName MWP.Remote Start-MwpOperation { [pscustomobject]@{ PSTypeName = 'MWP.Operation'; Operation = $Operation } }
            $context = New-MwpExecutionContext

            $operation = Get-MwpTargetInfo -Context $context -AsOperation

            $operation.Operation | Should -Be 'Remote.TargetInfo'
            Should -Invoke -ModuleName MWP.Remote Start-MwpOperation -Times 1
        }
    }
}
