# src/

Kod aplikacji.

- `Modules/MWP.*` — moduły logiki, po jednym na obszar (FAZA 1: szkielety z jedną funkcją-zaślepką).
  Każdy moduł: manifest `MWP.<Obszar>.psd1`, plik `MWP.<Obszar>.psm1`, funkcje publiczne w `Public/`, wewnętrzne w `Private/` (jeden plik = jedna funkcja).
- `UI/` — interfejs WPF/XAML (powstanie w FAZIE 3).

Szczegóły i konwencje: `docs/00_PROJEKT/ARCHITEKTURA.md`.
