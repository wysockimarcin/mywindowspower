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

## FAZA 1 — Szkielet techniczny (2026-10-23)
- Status: ZAKOŃCZONA
- Commit: `FAZA 1: szkielet techniczny, launcher, moduły, Pester i PSScriptAnalyzer` — hash do uzupełnienia w FAZIE 2
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
- Uzupełnienie (2026-10-22, po zamknięciu fazy): dodano dane środowiska docelowego (Windows 11 Pro 26H2 kompilacja 26300.9711, PowerShell 5.1.26100.9711), materiały użytkownika (`docs/design/mockup-pulpit.png`, `CLAUDE_przed_FAZA0.md`, `README_przed_faza0.md`), decyzje D-009 … D-011 oraz zmiany w FAZACH 1 i 3 i ich promptach.
- Następna faza: FAZA 1 — Szkielet techniczny
