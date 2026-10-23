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
        # ConvertFrom-Json zwraca liczby całkowite jako [int] w 5.1, a jako [long] w 7.x.
        ($settings.schemaVersion -is [int] -or $settings.schemaVersion -is [long]) |
            Should -BeTrue -Because 'schemaVersion musi być liczbą całkowitą'
    }
}

Describe 'Plik .gitignore' {
    It 'wyklucza lokalne ustawienia użytkownika' {
        Get-Content -LiteralPath (Join-Path -Path $root -ChildPath '.gitignore') | Should -Contain 'config/settings.local.json'
    }

    It 'wyklucza katalog danych aplikacji /data/ w katalogu głównym (D-032)' {
        Get-Content -LiteralPath (Join-Path -Path $root -ChildPath '.gitignore') | Should -Contain '/data/'
    }

    It 'wyklucza moduły zainstalowane z paczek src/Modules/Installed/ (D-031)' {
        Get-Content -LiteralPath (Join-Path -Path $root -ChildPath '.gitignore') | Should -Contain 'src/Modules/Installed/'
        if (Get-Command -Name git -ErrorAction SilentlyContinue) {
            $null = & git -C $root check-ignore -q -- 'src/Modules/Installed/MWP.Przyklad/MWP.Przyklad.psd1'
            $LASTEXITCODE | Should -Be 0 -Because 'moduły z paczek nie trafiają do repozytorium'
        }
    }

    It 'nie wyklucza danych modułów, np. src/Modules/MWP.Core/Data/protected-items.json' {
        if (-not (Get-Command -Name git -ErrorAction SilentlyContinue)) {
            Set-ItResult -Skipped -Because 'brak polecenia git'
            return
        }
        $null = & git -C $root check-ignore -q -- 'src/Modules/MWP.Core/Data/protected-items.json'
        $LASTEXITCODE | Should -Be 1 -Because 'plik danych modułu musi zostać w repozytorium'
    }
}

Describe 'Materiały dla kolejnych faz' {
    It 'zawiera mockup głównego okna docs/design/mockup-pulpit.png (FAZA 4)' {
        Join-Path -Path $root -ChildPath 'docs\design\mockup-pulpit.png' | Should -Exist
    }
}
