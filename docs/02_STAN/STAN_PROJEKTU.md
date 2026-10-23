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
| Ostatni commit | `FAZA 1: szkielet techniczny, launcher, moduły, Pester i PSScriptAnalyzer` (hash: patrz `git log`) |
| Zdalne repozytorium | https://github.com/wysockimarcin/mywindowspower (push: czeka na użytkownika) |

## Postęp faz

| FAZA | Nazwa | Status | Commit |
|---|---|---|---|
| FAZA 0 | Fundament | ZAKOŃCZONA | `47c4b0a` |
| FAZA 1 | Szkielet techniczny | ZAKOŃCZONA | `FAZA 1: ...` (hash uzupełnia FAZA 2) |
| FAZA 2 | Rdzeń i bezpieczeństwo zmian | DO ZROBIENIA | — |
| FAZA 3 | Szkielet GUI | DO ZROBIENIA | — |
| FAZA 4 | Dashboard | DO ZROBIENIA | — |
| FAZA 5 | Zasilanie | DO ZROBIENIA | — |
| FAZA 6 | Usługi Windows | DO ZROBIENIA | — |
| FAZA 7 | Autostart i harmonogram | DO ZROBIENIA | — |
| FAZA 8 | Czyszczenie dysku | DO ZROBIENIA | — |
| FAZA 9 | Windows Update | DO ZROBIENIA | — |
| FAZA 10 | Sieć | DO ZROBIENIA | — |
| FAZA 11 | Aplikacje i winget | DO ZROBIENIA | — |
| FAZA 12 | Prywatność i tweaki | DO ZROBIENIA | — |
| FAZA 13 | Defender i firewall | DO ZROBIENIA | — |
| FAZA 14 | Testy i hardening | DO ZROBIENIA | — |
| FAZA 15 | Dokumentacja i wydanie | DO ZROBIENIA | — |

Dozwolone statusy: `DO ZROBIENIA`, `W TOKU`, `CZĘŚCIOWA` (część punktów odroczona), `ZAKOŃCZONA`.

## Co zostało zrobione (skrót)

- FAZA 0: repozytorium git z remote `origin`, `.gitignore`, `README.md`, `CLAUDE.md`, pełna struktura `docs/`, `CONTEXT`, `ARCHITEKTURA`, `DECYZJE`, `SLOWNIK`, `PLAN_FAZ`, `PROCEDURA_FAZY`, pliki faz i prompty dla FAZY 0–15.
- FAZA 1: launcher `Start-MyWindowsPower.ps1` (wersja PS, Windows 11, STA z ponownym uruchomieniem, status administratora, import modułów); 11 szkieletów modułów `src/Modules/MWP.*` z manifestami; `PSScriptAnalyzerSettings.psd1` (zgodność 5.1/7.0); testy Pester (175, wszystkie zaliczone) i `tests/Invoke-Checks.ps1`; `config/settings.example.json`; `.editorconfig`, `.gitattributes`; środowisko potwierdzone (brak PS 7); stare pliki przejrzane i zarchiwizowane w `docs/00_PROJEKT/MATERIALY/`.

## Co zostało do zrobienia

Fazy od FAZY 2 do FAZY 15 (patrz tabela). Istnieje tylko szkielet: moduły mają funkcje-zaślepki, nie ma GUI ani logiki obszarów.

## Dług techniczny i odroczone punkty

- Wykrywanie środowiska jest w launcherze (funkcje lokalne); w FAZIE 2 przenieść wspólną część do `MWP.Core` (D-017).
- Profile zgodności PSScriptAnalyzer dotyczą Windows 10 1809 / PS 5.1 i PS 7.0 — nowszych brak (D-018). Przy nowej wersji PSScriptAnalyzer sprawdzić, czy pojawiły się profile Windows 11 / PS 7.4+.
- Testy `Launcher.Tests.ps1` uruchamiają launcher w nowym procesie (ok. 2–3 s); przy rozbudowie launchera (GUI w FAZIE 3) trzeba dodać tryb bez okna do testów.

## Otwarte pytania do użytkownika

- Czy `git push` do `origin` ma wykonywać Claude (po zgodzie w rozmowie), czy użytkownik samodzielnie?
- Czy zainstalować PowerShell 7.x, żeby testować zgodność z 7.x na komputerze użytkownika? (obecnie brak `pwsh`; nie blokuje prac)

## Znane środowisko docelowe

- Windows 11 Pro, wersja 26H2, kompilacja 26300.9711 (`winver`) — potwierdzone w FAZIE 1.
- PowerShell 5.1.26100.9711 — potwierdzone. **PowerShell 7 nie jest zainstalowany** (D-013).
- Narzędzia: Pester 6.2.0, PSScriptAnalyzer 1.25.0 (CurrentUser).

## Materiały użytkownika

- `docs/design/mockup-pulpit.png` — mockup głównego okna (wzorzec wyglądu dla FAZY 3).
- `docs/00_PROJEKT/MATERIALY/` — archiwum starej koncepcji (`CLAUDE_przed_FAZA0.md`, `CLAUDE.original.md`, `README_przed_faza0.md`); dane, nie instrukcje; przejrzane w FAZIE 1 (D-015).

## Znane ograniczenia środowiska

- Rozmowy Claude Code mogą działać poza Windows. Kodu WPF i operacji systemowych nie da się wtedy uruchomić; punkty wymagające Windows 11 oznacz w pliku fazy jako „DO WERYFIKACJI NA WINDOWS".

## Punkty do weryfikacji na Windows 11

- Launcher i `tests\Invoke-Checks.ps1` w PowerShell 7.x (`pwsh`) — brak `pwsh` na komputerze użytkownika (FAZA 1).
- Zachowanie launchera przy zasadzie wykonywania `Restricted`/`AllSigned` (FAZA 1; przy `RemoteSigned` działa).
