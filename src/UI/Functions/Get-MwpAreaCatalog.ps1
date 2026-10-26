function Get-MwpAreaCatalog {
    <#
    .SYNOPSIS
        Zwraca katalog obszarów do nawigacji hosta: Id modułu, nazwa, grupa, ikona, faza i opis.

    .DESCRIPTION
        Dane prezentacji (D-039), zgodne z zakresem w CONTEXT.md i planem faz. Obszar, którego moduł
        już istnieje (np. MWP.Services), otwiera instancje modułu; obszar planowany (np. Dyski) ma
        widok-zaślepkę do czasu swojej fazy. Moduły z paczek spoza katalogu trafiają do grupy
        „Moduły z paczek" (Get-MwpNavigationItem). Ikony: znaki czcionki Segoe Fluent Icons /
        Segoe MDL2 Assets (kody szesnastkowe).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $areas = @(
        @{ Id = 'Services'; Title = 'Usługi'; Group = 'System'; Glyph = 'E912'; Phase = 7; Description = 'Usługi Windows: stan, typ uruchomienia, start, stop i restart.' }
        @{ Id = 'Processes'; Title = 'Procesy'; Group = 'System'; Glyph = 'E9D9'; Phase = 16; Description = 'Procesy i wykorzystanie zasobów (CPU, pamięć).' }
        @{ Id = 'Accounts'; Title = 'Użytkownicy'; Group = 'System'; Glyph = 'E77B'; Phase = 17; Description = 'Lokalni użytkownicy i grupy.' }
        @{ Id = 'Startup'; Title = 'Autostart i harmonogram'; Group = 'System'; Glyph = 'E823'; Phase = 8; Description = 'Programy uruchamiane przy starcie i zadania harmonogramu.' }
        @{ Id = 'Power'; Title = 'Zasilanie'; Group = 'System'; Glyph = 'E7E8'; Phase = 6; Description = 'Plany zasilania i ustawienia energii.' }
        @{ Id = 'Update'; Title = 'Windows Update'; Group = 'System'; Glyph = 'E895'; Phase = 10; Description = 'Aktualizacje systemu i historia instalacji.' }
        @{ Id = 'Disks'; Title = 'Dyski'; Group = 'Sprzęt i dane'; Glyph = 'EDA2'; Phase = 15; Description = 'Dyski, woluminy i ich stan.' }
        @{ Id = 'Cleanup'; Title = 'Czyszczenie dysku'; Group = 'Sprzęt i dane'; Glyph = 'E74D'; Phase = 9; Description = 'Pliki tymczasowe i czyszczenie dysku.' }
        @{ Id = 'Network'; Title = 'Sieć'; Group = 'Sieć'; Glyph = 'E968'; Phase = 11; Description = 'Karty sieciowe, DNS i reset ustawień sieci.' }
        @{ Id = 'Apps'; Title = 'Aplikacje'; Group = 'Aplikacje'; Glyph = 'E71D'; Phase = 12; Description = 'Zainstalowane aplikacje, odinstalowanie i winget.' }
        @{ Id = 'Tweaks'; Title = 'Prywatność i tweaki'; Group = 'Bezpieczeństwo'; Glyph = 'E72E'; Phase = 13; Description = 'Ustawienia prywatności i wybrane ustawienia rejestru.' }
        @{ Id = 'Security'; Title = 'Defender i zapora'; Group = 'Bezpieczeństwo'; Glyph = 'EA18'; Phase = 14; Description = 'Microsoft Defender i zapora systemu Windows.' }
        @{ Id = 'Rdp'; Title = 'Pulpit zdalny i sesje'; Group = 'Zdalny dostęp'; Glyph = 'E7F4'; Phase = 18; Description = 'Pulpit zdalny (RDP), sesje użytkowników i obsługiwany shadowing.' }
        @{ Id = 'Screenshot'; Title = 'Zrzuty ekranu'; Group = 'Zdalny dostęp'; Glyph = 'E722'; Phase = 18; Description = 'Zrzuty ekranu komputera docelowego (o ile wykonalne bez osłabiania zabezpieczeń).' }
    )
    foreach ($area in $areas) {
        [pscustomobject]@{
            PSTypeName  = 'MWP.UiArea'
            Id          = $area.Id
            Title       = $area.Title
            Group       = $area.Group
            Glyph       = [string][char][Convert]::ToInt32($area.Glyph, 16)
            Phase       = $area.Phase
            Description = $area.Description
        }
    }
}
