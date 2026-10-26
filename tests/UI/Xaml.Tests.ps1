#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
    Testy statyczne warstwy UI (FAZA 4): pliki XAML (poprawny XML, bez x:Class i zdarzeń, motywy
    z tymi samymi kluczami, kontrolki używane w kodzie istnieją), wczytanie każdego okna i widoku
    przez XamlReader z zasobami aplikacji (gdy wątek jest STA) oraz granica warstw: kod src\UI wywołuje
    tylko funkcje Mwp i nieszkodliwe polecenia wbudowane (bez poleceń systemowych i WinRM, D-015, D-019).
    Wyglądu i działania okna testy nie sprawdzają — to weryfikacja ręczna na Windows 11.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Zmienne z bloków BeforeDiscovery/BeforeAll są używane w blokach It (zakresy Pestera).')]
param()

BeforeDiscovery {
    $uiRoot = Join-Path -Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) -ChildPath 'src\UI'
    $xamlFiles = @()
    foreach ($file in @(Get-ChildItem -LiteralPath $uiRoot -Recurse -File -Filter '*.xaml')) {
        $xamlFiles += @{ Name = $file.FullName.Substring($uiRoot.Length + 1); Path = $file.FullName }
    }
    $windowFiles = @($xamlFiles | Where-Object { $_.Name -notlike 'Themes\*' })
}

Describe 'Pliki XAML <Name>' -ForEach $xamlFiles {
    It 'są poprawnym XML-em bez x:Class i bez zdarzeń w atrybutach' {
        $text = [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8)
        { [xml]$text } | Should -Not -Throw
        $text | Should -Not -Match 'x:Class='
        $text | Should -Not -Match '\s(Click|Loaded|Checked|SelectionChanged|TextChanged|MouseDoubleClick)="'
    }
}

Describe 'Warstwa UI' {
    BeforeAll {
        $root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        $uiRoot = Join-Path -Path $root -ChildPath 'src\UI'
        $codeFiles = @(Get-ChildItem -LiteralPath $uiRoot -Recurse -File | Where-Object { $_.Extension -in @('.ps1', '.psm1') })

        function Get-PatternGroup {
            param([string[]] $Path, [string] $Pattern)
            $values = New-Object -TypeName System.Collections.Generic.List[string]
            foreach ($item in $Path) {
                foreach ($match in [regex]::Matches([IO.File]::ReadAllText($item, [Text.Encoding]::UTF8), $Pattern)) {
                    $values.Add($match.Groups[1].Value)
                }
            }
            @($values | Sort-Object -Unique)
        }

        $xamlPaths = @(Get-ChildItem -LiteralPath $uiRoot -Recurse -File -Filter '*.xaml' | ForEach-Object { $_.FullName })
        $declaredNames = @(Get-PatternGroup -Path $xamlPaths -Pattern 'x:Name="([A-Za-z_][A-Za-z0-9_]*)"')
        $isSta = [Threading.Thread]::CurrentThread.GetApartmentState() -eq [Threading.ApartmentState]::STA
    }

    It 'motywy jasny i ciemny mają te same klucze zasobów' {
        $light = @(Get-PatternGroup -Path (Join-Path -Path $uiRoot -ChildPath 'Themes\Light.xaml') -Pattern 'x:Key="([^"]+)"')
        $dark = @(Get-PatternGroup -Path (Join-Path -Path $uiRoot -ChildPath 'Themes\Dark.xaml') -Pattern 'x:Key="([^"]+)"')
        ($light -join ',') | Should -Be ($dark -join ',')
        $light | Should -Contain 'Mwp.Brush.Accent'
    }

    It 'każda kontrolka używana w kodzie (Controls[...]) jest nazwana w którymś pliku XAML' {
        $used = @(Get-PatternGroup -Path @($codeFiles.FullName) -Pattern "(?:\`$c|\`$v|\`$controls|Controls)\['([A-Za-z_][A-Za-z0-9_]*)'\]")
        $used.Count | Should -BeGreaterThan 40
        @($used | Where-Object { $declaredNames -notcontains $_ }) | Should -BeNullOrEmpty
    }

    It 'kod UI wywołuje tylko funkcje Mwp i dozwolone polecenia wbudowane (bez poleceń systemowych i WinRM)' {
        # Polecenia wbudowane potrzebne warstwie prezentacji; zmiany systemu i połączenia należą do MWP.Core/MWP.Remote.
        $allowed = @(
            'Add-Member', 'Add-Type', 'ConvertFrom-Json', 'Export-ModuleMember', 'ForEach-Object', 'Get-ChildItem', 'Get-Date',
            'Get-ItemPropertyValue', 'Get-Module', 'Import-Module', 'Join-Path', 'New-Object', 'Remove-Module', 'Select-Object',
            'Set-StrictMode', 'Sort-Object', 'Split-Path', 'Start-Sleep', 'Where-Object', 'Write-Error', 'Write-Verbose', 'Write-Warning'
        )
        $commands = New-Object -TypeName System.Collections.Generic.List[string]
        foreach ($file in $codeFiles) {
            $ast = [Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$null)
            foreach ($node in $ast.FindAll({ param($node) $node -is [Management.Automation.Language.CommandAst] }, $true)) {
                $name = $node.GetCommandName()
                if ($null -ne $name -and $name -notmatch '^[A-Za-z]+-Mwp' -and $allowed -notcontains $name) {
                    $commands.Add(('{0}: {1}' -f $file.Name, $name))
                }
            }
        }
        $commands | Should -BeNullOrEmpty
    }

    It 'Get-ItemPropertyValue (motyw systemu) czyta tylko klucz Personalize w HKCU' {
        $hits = @($codeFiles | Select-String -Pattern 'HK(LM|CU):' | ForEach-Object { $_.Line.Trim() })
        $hits.Count | Should -Be 1
        $hits[0] | Should -Match 'HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize'
    }

    Context 'wczytanie przez XamlReader (WPF, wątek STA)' {
        BeforeAll {
            if ($isSta) {
                Import-Module -Name (Join-Path -Path $uiRoot -ChildPath 'MWP.UI.psm1') -Force
                $application = Initialize-MwpWpf -UiRoot $uiRoot -Theme Light
            }
        }

        AfterAll {
            Remove-Module -Name MWP.UI -Force -ErrorAction SilentlyContinue
        }

        It 'okno lub widok <Name> wczytuje się z zasobami aplikacji, a nazwane kontrolki są dostępne' -ForEach $windowFiles {
            if (-not $isSta) {
                Set-ItResult -Skipped -Because 'WPF wymaga wątku STA'
                return
            }
            $view = Import-MwpXaml -Path $Path
            $view.Root | Should -Not -BeNullOrEmpty
            $names = @(Get-PatternGroup -Path $Path -Pattern 'x:Name="([A-Za-z_][A-Za-z0-9_]*)"')
            $view.Controls.Count | Should -Be $names.Count
        }

        It 'zmiana motywu podmienia słownik pędzli (jasny i ciemny wczytują się)' {
            if (-not $isSta) {
                Set-ItResult -Skipped -Because 'WPF wymaga wątku STA'
                return
            }
            foreach ($theme in 'Dark', 'Light') {
                $dictionary = (Import-MwpXaml -Path (Join-Path -Path $uiRoot -ChildPath "Themes\$theme.xaml")).Root
                $application.Resources.MergedDictionaries[0] = $dictionary
                $application.Resources['Mwp.Brush.Accent'] | Should -Not -BeNullOrEmpty
            }
            $application.Resources.MergedDictionaries.Count | Should -Be 2
        }
    }
}
