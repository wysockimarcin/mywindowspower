# CHANGELOG FAZ — mywindowspower

> Raport po każdej zakończonej fazie. Najnowsze wpisy na górze. Hash commita fazy uzupełnia następna faza na swoim starcie (nie da się go znać przed wykonaniem commita).

## Szablon wpisu

```
## FAZA N — <nazwa> (<data>)
- Status: ZAKOŃCZONA | CZĘŚCIOWA
- Commit: <hash> `FAZA N: opis`
- Zrobiono: ...
- Niezrobione / odroczone: ... (dokąd przeniesione)
- Decyzje: D-xxx, D-yyy
- Do weryfikacji na Windows 11: ...
- Następna faza: FAZA N+1 — <nazwa>
```

---

## Korekta dokumentacji po FAZIE 1 — przywrócenie zarządzania zdalnego (2026-10-23)
- Status: ZAKOŃCZONA (korekta, nie nowa faza)
- Commit: `FAZA 1: korekta dokumentacji — zarządzanie komputerami zdalnymi (D-019…D-021)` — `a776ca9`
- Powód: użytkownik wskazał, że aplikacja ma zarządzać także komputerami zdalnymi i `localhost` zgodnie ze starym `CLAUDE.md`, a dokumentacja (wpis w „Poza zakresem" w `CONTEXT.md` i D-015) mówiła odwrotnie.
- Zrobiono: D-019 (zarządzanie `localhost` i komputerami zdalnymi, wieloinstancyjność, kontekst wykonania, Dashboard z widgetami, kontrakt modułu), D-020 (nowe moduły i tryby ze starej koncepcji, przenumerowanie faz), D-021 (ADR do podjęcia, przypisane do faz); nowa FAZA 3, nowe FAZY 15–19, rozbudowane FAZY 2, 4, 5 i 6–14, FAZA 20 (testy architektoniczne i zdalne) i 21; zaktualizowano `CONTEXT`, `ARCHITEKTURA` (host, instancje, kontekst wykonania, połączenia zdalne, tryby prezentacji, Dashboard i widgety, kontrakt modułu, `apprun`, model procesów, testy architektoniczne), `SLOWNIK`, `PLAN_FAZ`, `STAN_PROJEKTU`, `README`, `CLAUDE.md`, pliki faz i prompty (FAZA 2–21).
- Zmiany w kodzie: tylko komunikat launchera i opis w komentarzu („FAZIE 3" → „FAZIE 4") oraz nazwa testu w `tests/Repository.Tests.ps1`; nie uruchamiano ich (brak Windows i `pwsh`).
- Niezrobione / odroczone: implementacja (FAZY 2–21); decyzje o transporcie i uwierzytelnianiu zdalnym (FAZA 3), modelu procesów (FAZA 2), kontrakcie widgetu (FAZA 5).
- Decyzje: D-019, D-020, D-021
- Do weryfikacji na Windows 11: `.\tests\Invoke-Checks.ps1` po zmianie nazwy testu i komunikatu launchera.
- Następna faza: FAZA 2 — Rdzeń i bezpieczeństwo zmian

---

## FAZA 1 — Szkielet techniczny (2026-10-23)
- Status: ZAKOŃCZONA
- Commit: `FAZA 1: szkielet techniczny, launcher, moduły, Pester i PSScriptAnalyzer` — `286fcfb`
- Zrobiono: launcher `Start-MyWindowsPower.ps1` (PS 5.1/7.x, Windows 11, STA z ponownym uruchomieniem, status administratora, import modułów, komunikaty po polsku); 11 szkieletów modułów `MWP.*` (manifest, `.psm1`, `Public/`, `Private/`, zaślepka `Get-Mwp<Obszar>ModuleInfo`); `PSScriptAnalyzerSettings.psd1` z regułami zgodności 5.1/7.0; testy Pester `Modules`, `Launcher`, `Repository` (175 zaliczonych) i `tests/Invoke-Checks.ps1`; `config/settings.example.json`; `.editorconfig`, `.gitattributes`; pliki kodu w UTF-8 z BOM; środowisko potwierdzone; instalacja Pester 6.2.0 i PSScriptAnalyzer 1.25.0 (CurrentUser, za zgodą); przegląd starych plików i ich archiwizacja w `docs/00_PROJEKT/MATERIALY/`; usunięcie pozostałości starego projektu (`scripts/`, stare testy i pliki celów).
- Uwaga (zasada E): na starcie fazy w katalogu roboczym były niezacommitowane uzupełnienia dokumentacji FAZY 0 (opisane w jej wpisie jako „Uzupełnienie”) oraz nieśledzone pliki starego projektu. Uzupełnienia weszły do commita FAZY 1, pliki starego projektu obsłużono zgodnie z D-016.
- Niezrobione / odroczone: weryfikacja w PowerShell 7.x (brak `pwsh`) → „Punkty do weryfikacji” w `STAN_PROJEKTU.md`; przeniesienie wykrywania środowiska do `MWP.Core` → FAZA 2.
- Decyzje: D-012 … D-018 (D-009 zastąpiona przez D-013)
- Do weryfikacji na Windows 11: launcher i `Invoke-Checks.ps1` w `pwsh` 7.x; zasady wykonywania inne niż `RemoteSigned`.
- Następna faza: FAZA 2 — Rdzeń i bezpieczeństwo zmian

---

## FAZA 0 — Fundament (2026-10-22)
- Status: ZAKOŃCZONA
- Commit: `47c4b0a` `FAZA 0: fundament projektu, dokumentacja i plan faz`
- Zrobiono: `git init` (gałąź `main`), remote `origin` → https://github.com/wysockimarcin/mywindowspower, `.gitignore`, `README.md`, `CLAUDE.md`, struktura `docs/` (`00_PROJEKT`, `01_PLAN`, `02_STAN`, `03_FAZY`, `04_PROMPTY`, `05_PROCES`), plan 16 faz, pliki faz i prompty.
- Niezrobione / odroczone: `git push` (wymaga uwierzytelnienia użytkownika).
- Decyzje: D-001 … D-008
- Do weryfikacji na Windows 11: nic (brak kodu).
- Uzupełnienie (2026-10-22, po zamknięciu fazy): dodano dane środowiska docelowego (Windows 11 Pro 26H2 kompilacja 26300.9711, PowerShell 5.1.26100.9711), materiały użytkownika (`docs/design/mockup-pulpit.png`, `CLAUDE_przed_FAZA0.md`, `README_przed_faza0.md`), decyzje D-009 … D-011 oraz zmiany w FAZACH 1 i 3 (numeracja sprzed D-020; dziś FAZY 1 i 4) i ich promptach.
- Następna faza: FAZA 1 — Szkielet techniczny
