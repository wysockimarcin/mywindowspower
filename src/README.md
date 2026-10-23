# src/

Kod aplikacji.

- `Modules/MWP.Core` — rdzeń (FAZA 2): log, konfiguracja, środowisko i elewacja, punkt przywracania, rejestr cofnięć, obiekt wyniku, lista ochronna (`Data/`), kontrakt i odkrywanie modułów.
- `Modules/MWP.*` — moduły logiki, po jednym na obszar (na razie szkielety z jedną funkcją-zaślepką). Każdy manifest ma kontrakt modułu w `PrivateData.MWP`.
  Każdy moduł: manifest `MWP.<Obszar>.psd1`, plik `MWP.<Obszar>.psm1`, funkcje publiczne w `Public/`, wewnętrzne w `Private/` (jeden plik = jedna funkcja).
- `UI/` — interfejs WPF/XAML, host modułów (powstanie w FAZIE 4).
- Moduły dla komputerów zdalnych i nowych obszarów (`MWP.Remote`, `MWP.Disks`, `MWP.Processes`, `MWP.Accounts`, `MWP.Rdp`, `MWP.Screenshot`) pojawią się w odpowiednich fazach (zob. `docs/01_PLAN/PLAN_FAZ.md`).

Szczegóły i konwencje: `docs/00_PROJEKT/ARCHITEKTURA.md`.
