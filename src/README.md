# src/

Kod aplikacji.

- `Modules/MWP.*` — moduły logiki, po jednym na obszar (FAZA 1: szkielety z jedną funkcją-zaślepką).
  Każdy moduł: manifest `MWP.<Obszar>.psd1`, plik `MWP.<Obszar>.psm1`, funkcje publiczne w `Public/`, wewnętrzne w `Private/` (jeden plik = jedna funkcja).
- `UI/` — interfejs WPF/XAML, host modułów (powstanie w FAZIE 4).
- Moduły dla komputerów zdalnych i nowych obszarów (`MWP.Remote`, `MWP.Disks`, `MWP.Processes`, `MWP.Accounts`, `MWP.Rdp`, `MWP.Screenshot`) pojawią się w odpowiednich fazach (zob. `docs/01_PLAN/PLAN_FAZ.md`).

Szczegóły i konwencje: `docs/00_PROJEKT/ARCHITEKTURA.md`.
