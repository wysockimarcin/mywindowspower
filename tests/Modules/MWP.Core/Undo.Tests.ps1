#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
    Testy rejestru cofnięć: Save-MwpUndoEntry, Get-MwpUndoEntry, Invoke-MwpUndo.
    Zamiast prawdziwej zmiany systemu cofnięcie wywołuje sondę Set-MwpUndoTestProbe,
    która zapisuje otrzymane parametry w pliku na TestDrive.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Zmienne z bloków BeforeDiscovery/BeforeAll są używane w blokach It (zakresy Pestera).')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalFunctions', '',
    Justification = 'Sonda testowa musi być widoczna dla Get-Command wywoływanego z modułu MWP.Core.')]
param()

Describe 'Rejestr cofnięć' {
    BeforeAll {
        $root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
        Import-Module -Name (Join-Path -Path $root -ChildPath 'src\Modules\MWP.Core\MWP.Core.psd1') -Force
        $null = New-Item -ItemType Directory -Path (Join-Path -Path $TestDrive -ChildPath 'config') -Force
        Copy-Item -LiteralPath (Join-Path -Path $root -ChildPath 'config\settings.example.json') -Destination (Join-Path -Path $TestDrive -ChildPath 'config\settings.example.json')
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

        $remoteComputer = 'PC-ZDALNY'
        $computerOne = 'PC-1'
        $computerTwo = 'PC-2'
        $testComputer = 'PC-TEST'
        $undoDirectory = Join-Path -Path $TestDrive -ChildPath 'Undo'
        $record = Join-Path -Path $TestDrive -ChildPath 'probe.json'

        function global:Set-MwpUndoTestProbe {
            [CmdletBinding(SupportsShouldProcess)]
            param(
                [string] $Value,
                [string] $ComputerName,
                [string] $RecordPath,
                [switch] $Fail
            )

            if ($PSCmdlet.ShouldProcess($Value)) {
                @{ Value = $Value; ComputerName = $ComputerName } | ConvertTo-Json | Set-Content -LiteralPath $RecordPath -Encoding UTF8
            }
            $message = if ($Fail) { 'Sonda: błąd' } else { 'Sonda: ok' }
            New-MwpResult -Success (-not $Fail) -Message $message -ComputerName $ComputerName
        }

        function global:Set-MwpUndoContextProbe {
            [CmdletBinding(SupportsShouldProcess)]
            param(
                [string] $Value,
                [PSTypeName('MWP.ExecutionContext')] [object] $Context,
                [string] $RecordPath
            )

            $computer = if ($null -ne $Context) { $Context.ComputerName } else { 'localhost (domyślnie)' }
            if ($PSCmdlet.ShouldProcess($Value)) {
                @{ Value = $Value; ComputerName = $computer } | ConvertTo-Json | Set-Content -LiteralPath $RecordPath -Encoding UTF8
            }
            New-MwpResult -Success $true -Message 'Sonda: ok' -ComputerName $computer
        }

        function Get-FakeContext {
            param([string] $Name, [string] $Mode = 'Remote')
            [pscustomobject]@{ PSTypeName = 'MWP.ExecutionContext'; ComputerName = $Name; Mode = $Mode }
        }

        $entryArguments = @{
            Module      = 'Testy'
            Operation   = 'Test.Change'
            Target      = 'Element'
            Description = 'Przywrócenie elementu'
            Before      = 'A'
            After       = 'B'
            UndoCommand = 'Set-MwpUndoTestProbe'
        }
    }

    AfterAll {
        Remove-Item -LiteralPath 'Function:\Set-MwpUndoTestProbe' -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath 'Function:\Set-MwpUndoContextProbe' -Force -ErrorAction SilentlyContinue
        Remove-Module -Name MWP.Core -Force -ErrorAction SilentlyContinue
    }

    BeforeEach {
        Remove-Item -LiteralPath $undoDirectory -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $record -Force -ErrorAction SilentlyContinue
    }

    Context 'Save-MwpUndoEntry' {
        It 'zapisuje wpis JSON z komputerem localhost domyślnie' {
            $entry = Save-MwpUndoEntry @entryArguments -UndoParameters @{ Value = 'A'; RecordPath = $record }

            $entry.PSObject.TypeNames | Should -Contain 'MWP.UndoEntry'
            $entry.ComputerName | Should -Be 'localhost'
            $entry.Status | Should -Be 'Pending'
            $entry.Before | Should -Be 'A'
            $entry.After | Should -Be 'B'
            $entry.UndoParameters['Value'] | Should -Be 'A'
            $entry.CreatedAt | Should -BeOfType ([datetime])
            Join-Path -Path $undoDirectory -ChildPath ($entry.Id + '.json') | Should -Exist
        }

        It 'zapisuje podany komputer docelowy' {
            (Save-MwpUndoEntry @entryArguments -ComputerName $remoteComputer).ComputerName | Should -Be 'PC-ZDALNY'
        }

        It 'odrzuca polecenie cofające spoza konwencji Verb-MwpNoun' {
            $arguments = $entryArguments.Clone()
            $arguments.UndoCommand = 'Remove-Item'
            { Save-MwpUndoEntry @arguments } | Should -Throw
        }
    }

    Context 'Get-MwpUndoEntry' {
        It 'zwraca wpisy od najnowszego' {
            $first = Save-MwpUndoEntry @entryArguments
            Start-Sleep -Milliseconds 30
            $second = Save-MwpUndoEntry @entryArguments

            $entries = @(Get-MwpUndoEntry)
            $entries.Count | Should -Be 2
            $entries[0].Id | Should -Be $second.Id
            $entries[1].Id | Should -Be $first.Id
        }

        It 'filtruje po komputerze i statusie' {
            $null = Save-MwpUndoEntry @entryArguments -ComputerName $computerOne
            $null = Save-MwpUndoEntry @entryArguments -ComputerName $computerTwo

            @(Get-MwpUndoEntry -ComputerName $computerOne).Count | Should -Be 1
            @(Get-MwpUndoEntry -Status Pending).Count | Should -Be 2
            @(Get-MwpUndoEntry -Status Undone).Count | Should -Be 0
        }

        It 'odrzuca identyfikator, który nie jest GUID' {
            { Get-MwpUndoEntry -Id '..\..\inny-plik' } | Should -Throw '*Niepoprawny identyfikator*'
        }

        It 'pomija uszkodzony plik wpisu z ostrzeżeniem' {
            $null = Save-MwpUndoEntry @entryArguments
            Set-Content -LiteralPath (Join-Path -Path $undoDirectory -ChildPath ([guid]::NewGuid().ToString() + '.json')) -Value '{ uszkodzony'

            @(Get-MwpUndoEntry -WarningVariable warnings -WarningAction SilentlyContinue).Count | Should -Be 1
            $warnings | Should -Not -BeNullOrEmpty
        }

        It 'zwraca pustą listę, gdy rejestr nie istnieje' {
            Get-MwpUndoEntry | Should -BeNullOrEmpty
        }
    }

    Context 'Invoke-MwpUndo' {
        It 'wywołuje polecenie cofające z parametrami i komputerem z wpisu' {
            $entry = Save-MwpUndoEntry @entryArguments -ComputerName $testComputer -UndoParameters @{ Value = 'A'; RecordPath = $record }

            $result = Invoke-MwpUndo -Id $entry.Id

            $result.Success | Should -BeTrue
            $result.Changed | Should -BeTrue
            $result.ComputerName | Should -Be 'PC-TEST'
            $result.Before | Should -Be 'B'
            $result.After | Should -Be 'A'
            $probe = Get-Content -LiteralPath $record -Raw -Encoding UTF8 | ConvertFrom-Json
            $probe.Value | Should -Be 'A'
            $probe.ComputerName | Should -Be 'PC-TEST'
            $saved = Get-MwpUndoEntry -Id $entry.Id
            $saved.Status | Should -Be 'Undone'
            $saved.UndoneAt | Should -BeOfType ([datetime])
        }

        It '-WhatIf nie wywołuje polecenia cofającego' {
            $entry = Save-MwpUndoEntry @entryArguments -UndoParameters @{ Value = 'A'; RecordPath = $record }

            $result = Invoke-MwpUndo -Id $entry.Id -WhatIf

            $result.IsPreview | Should -BeTrue
            $record | Should -Not -Exist
            (Get-MwpUndoEntry -Id $entry.Id).Status | Should -Be 'Pending'
        }

        It 'przyjmuje wpis z potoku' {
            $entry = Save-MwpUndoEntry @entryArguments -UndoParameters @{ Value = 'A'; RecordPath = $record }

            ($entry | Invoke-MwpUndo).Success | Should -BeTrue
        }

        It 'nie cofa drugi raz tego samego wpisu' {
            $entry = Save-MwpUndoEntry @entryArguments -UndoParameters @{ Value = 'A'; RecordPath = $record }
            $null = Invoke-MwpUndo -Id $entry.Id

            $again = Invoke-MwpUndo -Id $entry.Id

            $again.Success | Should -BeFalse
            $again.Message | Should -Match 'już cofnięty'
        }

        It 'zgłasza niedostępne polecenie cofające' {
            $arguments = $entryArguments.Clone()
            $arguments.UndoCommand = 'Set-MwpNieIstniejacePolecenie'
            $entry = Save-MwpUndoEntry @arguments

            $result = Invoke-MwpUndo -Id $entry.Id

            $result.Success | Should -BeFalse
            $result.Message | Should -Match 'nie jest dostępne'
        }

        It 'nieudane cofnięcie zostawia wpis do ponowienia z opisem błędu' {
            $entry = Save-MwpUndoEntry @entryArguments -UndoParameters @{ Value = 'A'; RecordPath = $record; Fail = $true }

            $result = Invoke-MwpUndo -Id $entry.Id

            $result.Success | Should -BeFalse
            $saved = Get-MwpUndoEntry -Id $entry.Id
            $saved.Status | Should -Be 'Pending'
            $saved.LastError | Should -Be 'Sonda: błąd'
        }

        It 'zgłasza nieznany wpis' {
            (Invoke-MwpUndo -Id ([guid]::NewGuid().ToString())).Success | Should -BeFalse
        }
    }

    Context 'Invoke-MwpUndo z kontekstem wykonania (FAZA 3)' {
        BeforeAll {
            $contextArguments = $entryArguments.Clone()
            $contextArguments.UndoCommand = 'Set-MwpUndoContextProbe'
        }

        It 'wpis z komputera zdalnego dla polecenia z -Context wymaga kontekstu' {
            $entry = Save-MwpUndoEntry @contextArguments -ComputerName $remoteComputer -UndoParameters @{ Value = 'A'; RecordPath = $record }

            $result = Invoke-MwpUndo -Id $entry.Id

            $result.Success | Should -BeFalse
            $result.Message | Should -Match 'wymaga kontekstu'
            $record | Should -Not -Exist
            (Get-MwpUndoEntry -Id $entry.Id).Status | Should -Be 'Pending'
        }

        It 'przekazuje kontekst komputera z wpisu do polecenia cofającego' {
            $entry = Save-MwpUndoEntry @contextArguments -ComputerName $remoteComputer -UndoParameters @{ Value = 'A'; RecordPath = $record }

            $result = Invoke-MwpUndo -Id $entry.Id -Context (Get-FakeContext -Name $remoteComputer)

            $result.Success | Should -BeTrue
            $result.ComputerName | Should -Be 'PC-ZDALNY'
            (Get-Content -LiteralPath $record -Raw -Encoding UTF8 | ConvertFrom-Json).ComputerName | Should -Be 'PC-ZDALNY'
        }

        It 'odrzuca kontekst innego komputera niż we wpisie' {
            $entry = Save-MwpUndoEntry @contextArguments -ComputerName $remoteComputer -UndoParameters @{ Value = 'A'; RecordPath = $record }

            $result = Invoke-MwpUndo -Id $entry.Id -Context (Get-FakeContext -Name $computerOne)

            $result.Success | Should -BeFalse
            $result.Message | Should -Match 'Kontekst dotyczy komputera'
            $record | Should -Not -Exist
        }

        It 'wpis lokalny bez kontekstu wywołuje polecenie bez -Context (komputer lokalny domyślnie)' {
            $entry = Save-MwpUndoEntry @contextArguments -UndoParameters @{ Value = 'A'; RecordPath = $record }

            (Invoke-MwpUndo -Id $entry.Id).Success | Should -BeTrue
            (Get-Content -LiteralPath $record -Raw -Encoding UTF8 | ConvertFrom-Json).ComputerName | Should -Be 'localhost (domyślnie)'
        }

        It 'wpis lokalny przyjmuje kontekst lokalny' {
            $entry = Save-MwpUndoEntry @contextArguments -UndoParameters @{ Value = 'A'; RecordPath = $record }

            (Invoke-MwpUndo -Id $entry.Id -Context (Get-FakeContext -Name 'localhost' -Mode 'Local')).Success | Should -BeTrue
        }
    }
}
