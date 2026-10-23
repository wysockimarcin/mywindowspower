#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
    Testy zasad repozytorium: kodowanie plików, szablon ustawień, .gitignore,
    brak ścieżek bezwzględnych i obecność materiałów potrzebnych w kolejnych fazach.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Zmienne z bloków BeforeDiscovery/BeforeAll są używane w blokach It (zakresy Pestera).')]
param()

BeforeDiscovery {
    $root = Split-Path -Parent $PSScriptRoot
    $codeFiles = @(Get-ChildItem -Path $root -Recurse -File -Include '*.ps1', '*.psm1', '*.psd1' |
            Where-Object { $_.FullName -notmatch '\\(\.git|docs)\\' } |
            ForEach-Object { @{ Name = $_.FullName.Substring($root.Length + 1); Path = $_.FullName } })
}

BeforeAll {
    $root = Split-Path -Parent $PSScriptRoot
}

Describe 'Kodowanie pliku <Name>' -ForEach $codeFiles {
    It 'jest zapisany jako UTF-8 z BOM' {
        $bytes = [IO.File]::ReadAllBytes($Path)
        $bytes.Length | Should -BeGreaterThan 2
        $bytes[0..2] | Should -Be @(0xEF, 0xBB, 0xBF)
    }

    It 'nie zawiera ścieżek bezwzględnych do profilu użytkownika' {
        $Path | Should -Not -FileContentMatch '[A-Za-z]:\\Users\\'
    }
}

Describe 'Szablon ustawień config/settings.example.json' {
    BeforeAll {
        $path = Join-Path -Path $root -ChildPath 'config\settings.example.json'
    }

    It 'istnieje i jest poprawnym JSON-em z polem schemaVersion' {
        $path | Should -Exist
        $settings = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
        $settings.schemaVersion | Should -BeOfType [int]
    }
}

Describe 'Plik .gitignore' {
    It 'wyklucza lokalne ustawienia użytkownika' {
        Get-Content -LiteralPath (Join-Path -Path $root -ChildPath '.gitignore') | Should -Contain 'config/settings.local.json'
    }
}

Describe 'Materiały dla kolejnych faz' {
    It 'zawiera mockup głównego okna docs/design/mockup-pulpit.png (FAZA 3)' {
        Join-Path -Path $root -ChildPath 'docs\design\mockup-pulpit.png' | Should -Exist
    }
}
