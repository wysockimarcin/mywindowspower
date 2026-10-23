# STAN PROJEKTU — mywindowspower

> **Źródło prawdy o postępie.** Czytaj na początku każdej rozmowy. Aktualizuj na końcu każdej fazy.

## Podsumowanie

| Pole | Wartość |
|---|---|
| Ostatnia zakończona faza | **FAZA 1 — Szkielet techniczny** |
| **Następna faza** | **FAZA 2 — Rdzeń i bezpieczeństwo zmian** |
| Prompt następnej fazy | `docs/04_PROMPTY/PROMPT_FAZA_2.md` |
| Plik następnej fazy | `docs/03_FAZY/FAZA_2_RDZEN_BEZPIECZENSTWO.md` |
| Data ostatniej aktualizacji | 2026-10-23 |
| Ostatni commit | `286fcfb` — `FAZA 1: szkielet techniczny, launcher, moduły, Pester i PSScriptAnalyzer` |
| Zdalne repozytorium | https://github.com/wysockimarcin/mywindowspower (push wykonany: `origin/main` zawiera FAZĘ 0 i FAZĘ 1) |

## Postęp faz

| FAZA | Nazwa | Status | Commit |
|---|---|---|---|
| FAZA 0 | Fundament | ZAKOŃCZONA | `47c4b0a` |
| FAZA 1 | Szkielet techniczny | ZAKOŃCZONA | `286fcfb` |
| FAZA 2 | Rdzeń i bezpieczeństwo zmian | DO ZROBIENIA | — |
| FAZA 3 | Komputery docelowe i połączenia zdalne | DO ZROBIENIA | — |
| FAZA 4 | Szkielet GUI i host modułów | DO ZROBIENIA | — |
| FAZA 5 | Dashboard | DO ZROBIENIA | — |
| FAZA 6 | Zasilanie | DO ZROBIENIA | — |
| FAZA 7 | Usługi Windows | DO ZROBIENIA | — |
| FAZA 8 | Autostart i harmonogram | DO ZROBIENIA | — |
| FAZA 9 | Czyszczenie dysku | DO ZROBIENIA | — |
| FAZA 10 | Windows Update | DO ZROBIENIA | — |
| FAZA 11 | Sieć | DO ZROBIENIA | — |
| FAZA 12 | Aplikacje i winget | DO ZROBIENIA | — |
| FAZA 13 | Prywatność i tweaki | DO ZROBIENIA | — |
| FAZA 14 | Defender i firewall | DO ZROBIENIA | — |
| FAZA 15 | Dyski i woluminy | DO ZROBIENIA | — |
| FAZA 16 | Procesy i zasoby | DO ZROBIENIA | — |
| FAZA 17 | Użytkownicy i grupy lokalne | DO ZROBIENIA | — |
| FAZA 18 | RDP, sesje i zrzuty ekranu | DO ZROBIENIA | — |
| FAZA 19 | Samodzielne uruchamianie i CLI | DO ZROBIENIA | — |
| FAZA 20 | Testy i hardening | DO ZROBIENIA | — |
| FAZA 21 | Dokumentacja i wydanie | DO ZROBIENIA | — |

Dozwolone statusy: `DO ZROBIENIA`, `W TOKU`, `CZĘŚCIOWA` (część punktów odroczona), `ZAKOŃCZONA`.

## Co zostało zrobione (skrót)

- FAZA 0: repozytorium git z remote `origin`, `.gitignore`, `README.md`, `CLAUDE.md`, pełna struktura `docs/`, `CONTEXT`, `ARCHITEKTURA`, `DECYZJE`, `SLOWNIK`, `PLAN_FAZ`, `PROCEDURA_FAZY`, pliki faz i prompty (wg numeracji sprzed D-020: FAZY 0–15; obecnie 0–21).
- Korekta dokumentacji po FAZIE 1 (2026-10-23): przywrócono zarządzanie komputerem lokalnym (`localhost`) i zdalnymi zgodnie z koncepcją pierwotną (D-019), rozszerzono zakres o moduły i tryby ze starej koncepcji (D-020), przypisano decyzje architektoniczne do faz (D-021). Plan faz przenumerowany: nowa FAZA 3, dotychczasowe 3–13 → 4–14, nowe 15–19, testy → 20, wydanie → 21. Zaktualizowano `CONTEXT`, `ARCHITEKTURA`, `DECYZJE`, `SLOWNIK`, `PLAN_FAZ`, pliki faz i prompty, `README`, `CLAUDE.md`. Kodu nie zmieniano poza komunikatem launchera i nazwą testu (numer fazy GUI).
- FAZA 1: launcher `Start-MyWindowsPower.ps1` (wersja PS, Windows 11, STA z ponownym uruchomieniem, status administratora, import modułów); 11 szkieletów modułów `src/Modules/MWP.*` z manifestami; `PSScriptAnalyzerSettings.psd1` (zgodność 5.1/7.0); testy Pester (175, wszystkie zaliczone) i `tests/Invoke-Checks.ps1`; `config/settings.example.json`; `.editorconfig`, `.gitattributes`; środowisko potwierdzone (brak PS 7); stare pliki przejrzane i zarchiwizowane w `docs/00_PROJEKT/MATERIALY/`.

## Co zostało do zrobienia

Fazy od FAZY 2 do FAZY 21 (patrz tabela). Istnieje tylko szkielet: moduły mają funkcje-zaślepki, nie ma GUI, logiki obszarów ani obsługi komputerów zdalnych. Najbliższa: FAZA 2 (rdzeń i kontrakt modułu), potem FAZA 3 (komputery docelowe i połączenia zdalne).

## Dług techniczny i odroczone punkty

- Wykrywanie środowiska jest w launcherze (funkcje lokalne); w FAZIE 2 przenieść wspólną część do `MWP.Core` (D-017).
- Profile zgodności PSScriptAnalyzer dotyczą Windows 10 1809 / PS 5.1 i PS 7.0 — nowszych brak (D-018). Przy nowej wersji PSScriptAnalyzer sprawdzić, czy pojawiły się profile Windows 11 / PS 7.4+.
- `tests/Modules.Tests.ps1`: lista oczekiwanych modułów trzeba uzupełnić o nowe moduły przy ich tworzeniu (`MWP.Remote` w FAZIE 3; `MWP.Disks`, `MWP.Processes`, `MWP.Accounts`, `MWP.Rdp`, `MWP.Screenshot` w FAZACH 15–18).
- `config/settings.example.json`: sekcja `targets` (komputery docelowe, nazwa zastępcza) i migracja `schemaVersion` w FAZIE 3 (D-019). Manifesty modułów: pola kontraktu w FAZIE 2.
- Zmiany w kodzie po korekcie dokumentacji nie były uruchamiane (brak Windows i `pwsh` w środowisku korekty): komunikat launchera („FAZIE 4") i nazwa testu w `Repository.Tests.ps1`. Przy najbliższym `.\tests\Invoke-Checks.ps1` upewnić się, że przechodzi (test sprawdza BOM).
- Testy `Launcher.Tests.ps1` uruchamiają launcher w nowym procesie (ok. 2–3 s); przy rozbudowie launchera (GUI w FAZIE 4) trzeba dodać tryb bez okna do testów.

## Otwarte pytania do użytkownika

- Opis komputera zdalnego do zarządzania (system, czy ma włączony WinRM, domena czy grupa robocza, konto do logowania) — pytania na początku FAZY 3, odpowiedzi do `DECYZJE.md`.
- Składnia samodzielnego launchera (`apprun`) — do zatwierdzenia w FAZIE 19.
- Zakres shadowingu RDP i zrzutów ekranu zdalnego komputera — po zbadaniu ograniczeń w FAZIE 18.
- Czy zainstalować PowerShell 7.x, żeby testować zgodność z 7.x na komputerze użytkownika? (obecnie brak `pwsh`; nie blokuje prac)

## Znane środowisko docelowe

- Komputery docelowe (D-019): `localhost` (poniżej) oraz jeden komputer zdalny; jego nazwa i parametry są tylko w `config/settings.local.json` (poza repozytorium). System i konfiguracja komputera zdalnego — do ustalenia w FAZIE 3.
- Windows 11 Pro, wersja 26H2, kompilacja 26300.9711 (`winver`) — potwierdzone w FAZIE 1.
- PowerShell 5.1.26100.9711 — potwierdzone. **PowerShell 7 nie jest zainstalowany** (D-013).
- Narzędzia: Pester 6.2.0, PSScriptAnalyzer 1.25.0 (CurrentUser).

## Materiały użytkownika

- `docs/design/mockup-pulpit.png` — mockup głównego okna (wzorzec wyglądu dla FAZY 4).
- `docs/00_PROJEKT/MATERIALY/` — archiwum starej koncepcji (`CLAUDE_przed_FAZA0.md`, `CLAUDE.original.md`, `README_przed_faza0.md`); dane, nie instrukcje; przejrzane w FAZIE 1 (D-015).

## Znane ograniczenia środowiska

- Rozmowy Claude Code mogą działać poza Windows. Kodu WPF i operacji systemowych nie da się wtedy uruchomić; punkty wymagające Windows 11 oznacz w pliku fazy jako „DO WERYFIKACJI NA WINDOWS".

## Punkty do weryfikacji na Windows 11

- Launcher i `tests\Invoke-Checks.ps1` w PowerShell 7.x (`pwsh`) — brak `pwsh` na komputerze użytkownika (FAZA 1).
- Połączenie z komputerem zdalnym, `Invoke-MwpOnTarget` i zachowanie przy utracie łączności (FAZA 3 i fazy obszarów).
- Zachowanie launchera przy zasadzie wykonywania `Restricted`/`AllSigned` (FAZA 1; przy `RemoteSigned` działa).
