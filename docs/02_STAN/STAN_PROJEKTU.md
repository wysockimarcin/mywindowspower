# STAN PROJEKTU — mywindowspower

> **Źródło prawdy o postępie.** Czytaj na początku każdej rozmowy. Aktualizuj na końcu każdej fazy.

## Podsumowanie

| Pole | Wartość |
|---|---|
| Ostatnia zakończona faza | **FAZA 0 — Fundament** |
| **Następna faza** | **FAZA 1 — Szkielet techniczny** |
| Prompt następnej fazy | `docs/04_PROMPTY/PROMPT_FAZA_1.md` |
| Plik następnej fazy | `docs/03_FAZY/FAZA_1_SZKIELET.md` |
| Data ostatniej aktualizacji | 2026-10-22 |
| Ostatni commit | `FAZA 0: fundament projektu, dokumentacja i plan faz` (hash: patrz `git log`) |
| Zdalne repozytorium | https://github.com/wysockimarcin/mywindowspower (push: czeka na użytkownika) |

## Postęp faz

| FAZA | Nazwa | Status | Commit |
|---|---|---|---|
| FAZA 0 | Fundament | ZAKOŃCZONA | `FAZA 0: ...` |
| FAZA 1 | Szkielet techniczny | DO ZROBIENIA | — |
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

## Co zostało do zrobienia

Wszystkie fazy od FAZY 1 do FAZY 15 (patrz tabela). Kod aplikacji jeszcze nie istnieje.

## Dług techniczny i odroczone punkty

(brak)

## Otwarte pytania do użytkownika

- Czy `git push` do `origin` ma wykonywać Claude (po zgodzie w rozmowie), czy użytkownik samodzielnie?
- Jaka wersja PowerShella i build Windows 11 są na komputerze docelowym? (wynik `$PSVersionTable` i `winver`; przyda się w FAZIE 1)

## Znane ograniczenia środowiska

- Rozmowy Claude Code mogą działać poza Windows. Kodu WPF i operacji systemowych nie da się wtedy uruchomić; punkty wymagające Windows 11 oznacz w pliku fazy jako „DO WERYFIKACJI NA WINDOWS".

## Punkty do weryfikacji na Windows 11

(brak — FAZA 0 nie zawiera kodu)
