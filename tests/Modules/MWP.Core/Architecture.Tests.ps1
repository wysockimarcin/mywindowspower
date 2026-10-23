#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
    Testy architektoniczne rdzenia (D-019): brak globalnego „bieżącego komputera",
    komputer docelowy domyślnie 'localhost', -WhatIf w funkcjach zmieniających stan.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Zmienne z bloków BeforeDiscovery/BeforeAll są używane w blokach It (zakresy Pestera).')]
param()

Describe 'Architektura rdzenia' {
    BeforeAll {
        $root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
        $module = Import-Module -Name (Join-Path -Path $root -ChildPath 'src\Modules\MWP.Core\MWP.Core.psd1') -Force -PassThru
        $sourceFiles = @(Get-ChildItem -Path (Join-Path -Path $root -ChildPath 'src') -Recurse -File -Include '*.ps1', '*.psm1')

        function Get-ParameterAst {
            param([string] $Command, [string] $Parameter)
            $ast = (Get-Command -Name $Command).ScriptBlock.Ast
            @($ast.Body.ParamBlock.Parameters) | Where-Object { $_.Name.VariablePath.UserPath -eq $Parameter }
        }
    }

    AfterAll {
        Remove-Module -Name MWP.Core -Force -ErrorAction SilentlyContinue
    }

    It 'kod w src nie używa zmiennych globalnych' {
        $hits = @($sourceFiles | Select-String -Pattern '\$global:' | ForEach-Object { '{0}:{1}' -f $_.Filename, $_.LineNumber })
        $hits | Should -BeNullOrEmpty
    }

    It 'kod w src nie ma zmiennej modułu z komputerem docelowym („bieżący komputer")' {
        $hits = @($sourceFiles | Select-String -Pattern '\$script:\w*(Computer|Target|Komputer)' | ForEach-Object { '{0}:{1}' -f $_.Filename, $_.LineNumber })
        $hits | Should -BeNullOrEmpty
    }

    It 'parametr ComputerName z wartością domyślną ma domyślnie localhost' {
        $checked = 0
        foreach ($command in $module.ExportedFunctions.Keys) {
            $parameter = Get-ParameterAst -Command $command -Parameter 'ComputerName'
            if ($null -ne $parameter -and $null -ne $parameter.DefaultValue) {
                $parameter.DefaultValue.Value | Should -Be 'localhost' -Because "$command"
                $checked++
            }
        }
        $checked | Should -BeGreaterOrEqual 4
    }

    It 'log, wpis cofnięcia i obiekt wyniku przyjmują komputer docelowy' {
        foreach ($command in 'Write-MwpLog', 'Save-MwpUndoEntry', 'New-MwpResult', 'New-MwpRestorePoint') {
            (Get-Command -Name $command).Parameters.ContainsKey('ComputerName') | Should -BeTrue -Because $command
        }
    }

    It 'funkcje zmieniające stan obsługują -WhatIf i -Confirm' {
        foreach ($command in 'Set-MwpSetting', 'New-MwpRestorePoint', 'Invoke-MwpUndo', 'Request-MwpElevation') {
            $parameters = (Get-Command -Name $command).Parameters
            $parameters.ContainsKey('WhatIf') | Should -BeTrue -Because $command
            $parameters.ContainsKey('Confirm') | Should -BeTrue -Because $command
        }
    }
}
