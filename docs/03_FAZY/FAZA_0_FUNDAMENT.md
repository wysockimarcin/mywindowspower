# FAZA 0 — Fundament

**Status:** ZAKOŃCZONA (2026-10-22)

## Cel
Przygotować proces pracy i pamięć projektu, aby kolejne fazy mogły startować w nowych rozmowach Claude Code bez utraty ciągłości.

## Zależności
Brak.

## Zakres
- Inicjalizacja git (gałąź `main`), remote `origin`.
- `.gitignore`, `README.md`, `CLAUDE.md`.
- Struktura `docs/` z podziałem na fazy.
- `CONTEXT`, `ARCHITEKTURA`, `DECYZJE`, `SLOWNIK`.
- `PLAN_FAZ`, `STAN_PROJEKTU`, `CHANGELOG_FAZ`, `PROCEDURA_FAZY`.
- Plik i prompt dla każdej fazy (0–15).

## Poza zakresem
Jakikolwiek kod aplikacji.

## Checklista
- [x] `git init -b main` i `git remote add origin https://github.com/wysockimarcin/mywindowspower`
- [x] `.gitignore`
- [x] `README.md`
- [x] `CLAUDE.md` w głównym folderze
- [x] `docs/00_PROJEKT/` — CONTEXT, ARCHITEKTURA, DECYZJE, SLOWNIK
- [x] `docs/01_PLAN/PLAN_FAZ.md`
- [x] `docs/02_STAN/` — STAN_PROJEKTU, CHANGELOG_FAZ
- [x] `docs/03_FAZY/` — plik dla każdej fazy 0–15
- [x] `docs/04_PROMPTY/` — prompt dla każdej fazy 0–15
- [x] `docs/05_PROCES/PROCEDURA_FAZY.md`
- [x] Commit `FAZA 0: ...`
- [ ] `git push` (wykonuje użytkownik)

## Kryteria ukończenia
Komplet dokumentacji w repozytorium, spójne nazwy i odnośniki, commit FAZY 0.

## Do weryfikacji na Windows 11
Nic.

## Wyniki
Patrz `docs/02_STAN/CHANGELOG_FAZ.md`.

## Następna faza
FAZA 1 — Szkielet techniczny. Prompt: `docs/04_PROMPTY/PROMPT_FAZA_1.md`.
