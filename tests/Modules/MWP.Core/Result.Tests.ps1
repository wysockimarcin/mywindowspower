#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
    Testy standardowego obiektu wyniku (New-MwpResult) i opisu celu operacji z komputerem.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Zmienne z bloków BeforeDiscovery/BeforeAll są używane w blokach It (zakresy Pestera).')]
param()

Describe 'Obiekt wyniku operacji' {
    BeforeAll {
        $root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
        Import-Module -Name (Join-Path -Path $root -ChildPath 'src\Modules\MWP.Core\MWP.Core.psd1') -Force
        $remoteComputer = 'PC-ZDALNY'
    }

    AfterAll {
        Remove-Module -Name MWP.Core -Force -ErrorAction SilentlyContinue
    }

    Context 'New-MwpResult' {
        It 'ma typ MWP.Result i domyślnie komputer localhost' {
            $result = New-MwpResult -Success $true

            $result.PSObject.TypeNames | Should -Contain 'MWP.Result'
            $result.ComputerName | Should -Be 'localhost'
            $result.Changed | Should -BeFalse
            $result.IsPreview | Should -BeFalse
            $result.RestartRequired | Should -BeFalse
            $result.Timestamp | Should -BeOfType ([datetime])
        }

        It 'zawiera wszystkie pola wzorca' {
            $expected = @('Success', 'Changed', 'IsPreview', 'RestartRequired', 'Operation', 'Target', 'ComputerName',
                'Message', 'Before', 'After', 'UndoId', 'ErrorMessage', 'Data', 'Timestamp')
            @((New-MwpResult -Success $true).PSObject.Properties.Name) | Should -Be $expected
        }

        It 'przenosi stan przed i po, komputer, restart i identyfikator cofnięcia' {
            $result = New-MwpResult -Success $true -Changed $true -Operation 'Services.SetStartupType' -Target 'Spooler' `
                -ComputerName $remoteComputer -Before 'Automatic' -After 'Manual' -RestartRequired -UndoId 'abc' -Message 'OK'

            $result.Success | Should -BeTrue
            $result.Changed | Should -BeTrue
            $result.Operation | Should -Be 'Services.SetStartupType'
            $result.Target | Should -Be 'Spooler'
            $result.ComputerName | Should -Be 'PC-ZDALNY'
            $result.Before | Should -Be 'Automatic'
            $result.After | Should -Be 'Manual'
            $result.RestartRequired | Should -BeTrue
            $result.UndoId | Should -Be 'abc'
        }

        It 'w podglądzie Changed jest zawsze fałszywe' {
            $result = New-MwpResult -Success $true -Changed $true -IsPreview

            $result.IsPreview | Should -BeTrue
            $result.Changed | Should -BeFalse
        }

        It 'puste UndoId i ErrorMessage zamienia na $null' {
            $result = New-MwpResult -Success $false -UndoId '' -ErrorMessage ''

            $result.UndoId | Should -BeNullOrEmpty
            $null -eq $result.UndoId | Should -BeTrue
            $null -eq $result.ErrorMessage | Should -BeTrue
        }

        It 'wymaga parametru Success' {
            @((Get-Command -Name New-MwpResult).Parameters['Success'].ParameterSets.Values.IsMandatory) | Should -Contain $true
        }
    }

    Context 'Format-MwpOperationTarget' {
        It 'zawiera nazwę komputera docelowego' {
            Format-MwpOperationTarget -Target "usługa 'Spooler'" -ComputerName $remoteComputer | Should -Be "usługa 'Spooler' — komputer: PC-ZDALNY"
        }

        It 'domyślnie wskazuje localhost' {
            Format-MwpOperationTarget -Target 'element' | Should -Match 'komputer: localhost$'
        }
    }
}
