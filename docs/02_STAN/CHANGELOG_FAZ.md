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

## Korekta dokumentacji po FAZIE 2 — instalacja i usuwanie modułów z paczki (2026-10-23)
- Status: ZAKOŃCZONA (korekta, nie nowa faza)
- Commit: `FAZA 2 (korekta): instalacja i usuwanie modułów z paczki (D-031)` — hash do uzupełnienia na starcie FAZY 3 (razem z hashem FAZY 2)
- Powód: użytkownik tworzy moduły w PowerShellu i dostarcza je jako paczki; host ma je instalować i odinstalowywać. Obowiązujące zapisy (D-020, `CONTEXT.md` „Poza zakresem", „bez instalatora" w `ARCHITEKTURA.md`) wykluczały instalację i usuwanie modułów.
- Zrobiono: D-031 (paczka `.mwpmod`, katalog `src/Modules/Installed/`, walidacja i atomowa instalacja, klasy operacji, odinstalowanie usuwające wszystko poza logami i rejestrem cofnięć, moduły bazowe i wbudowane nieusuwalne, tylko lokalnie, rejestr instalacji, brak aktualizacji przez host); zaktualizowano `CONTEXT`, `ARCHITEKTURA` (struktura, launcher, host, tabela rdzenia, kontrakt, nowa sekcja „Paczki modułów"), `SLOWNIK` (3 hasła), `PLAN_FAZ` (FAZY 3, 4, 5, 19), pliki faz 3, 4, 5, 19, prompty FAZ 3, 4, 5, `STAN_PROJEKTU` (stan `git push`, podział prac, dług techniczny), `.gitignore` (`src/Modules/Installed/`).
- Zmiany w kodzie: jedna poprawka za zgodą użytkownika (opis w punkcie „Testy"). Statusy faz bez zmian. `docs/03_FAZY/FAZA_2_RDZEN_BEZPIECZENSTWO.md` (zamknięta faza) zostaje z historycznym zapisem „odkrywanie tylko `src/Modules`"; D-020 i D-021 bez edycji (zastąpione częściowo przez D-031).
- Testy, pierwszy przebieg (przed poprawką kodu): `.\tests\Invoke-Checks.ps1`, każda wersja w nowym procesie — 5.1.26100.9711: 0 uwag, 392/393; 7.6.7: 0 uwag, 392/393. Nie przechodzi `ModuleContract.Tests.ps1:186` („uszkodzony manifest nie przerywa odkrywania pozostałych modułów"): `Import-PowerShellDataFile` w `ConvertTo-MwpModuleDefinition.ps1:28` zgłasza błąd nieprzerywający, więc `catch` go nie łapie i definicja dostaje komunikat „Manifest nie zawiera kontraktu…" zamiast „Nie udało się odczytać manifestu…". Test pada tak samo na czystym `10646d9` (sprawdzone `git stash`), więc nie jest skutkiem korekty; wynik 393/393 z FAZY 2 się nie powtórzył.
- Poprawka (za zgodą użytkownika): `-ErrorAction Stop` przy `Import-PowerShellDataFile` w `src/Modules/MWP.Core/Private/ConvertTo-MwpModuleDefinition.ps1:28` — błąd odczytu manifestu trafia do `catch` i daje komunikat „Nie udało się odczytać manifestu…". BOM UTF-8 i CRLF zachowane. Wynik końcowy, każda wersja w nowym procesie: 5.1.26100.9711 — 0 uwag, 393/393; 7.6.7 — 0 uwag, 393/393.
- Decyzje: D-031
- Następna faza: FAZA 3 — Komputery docelowe i połączenia zdalne

---

## FAZA 2 — Rdzeń i bezpieczeństwo zmian (2026-10-23)
- Status: ZAKOŃCZONA
- Commit: `FAZA 2: rdzeń MWP.Core, bezpieczeństwo zmian i kontrakt modułu` — hash do uzupełnienia na starcie FAZY 3
- Baza przed zmianami: PowerShell 5.1.26100.9711 i 7.6.7 (`C:\Program Files\PowerShell\7\pwsh.exe`, MSI, nie MSIX) — 0 uwag, 175/175 w obu. Hash FAZY 1 (`286fcfb`) był już wpisany we wszystkich miejscach.
- Zrobiono: `MWP.Core` 0.2.0 (wersja hosta) — środowisko (`Get-MwpEnvironment`, `Test-MwpAdmin`), elewacja na życzenie (`Request-MwpElevation`, launcher `-Elevate`), log `Write-MwpLog` (JSON Lines, plik dzienny, rotacja, muteks, ukrywanie sekretów), konfiguracja `Get-MwpSetting`/`Set-MwpSetting` (szablon + plik lokalny, zapis atomowy, uszkodzony plik, migracje), `New-MwpResult` i `Format-MwpOperationTarget`, rejestr cofnięć (`Save-`/`Get-MwpUndoEntry`, `Invoke-MwpUndo`), `New-MwpRestorePoint` (CIM), lista ochronna (`Data/protected-items.json`, `Test-`/`Get-MwpProtectedItem`), kontrakt modułu `PrivateData.MWP` w 11 manifestach z `Get-MwpModuleDefinition` i `Test-MwpModuleDefinition`; launcher waliduje kontrakty; komputer docelowy (domyślnie `localhost`) w logu, wpisie cofnięcia i wyniku, bez globalnego „bieżącego komputera"; wzorzec funkcji zmieniającej system w `ARCHITEKTURA.md` (przykład: `Set-MwpSetting`); ADR D-023…D-029 i D-030; `PROMPT_FAZA_3.md` uzupełniony o bazę testów i dług techniczny.
- Testy: 393 (było 175): +22 w `Modules.Tests.ps1`, +196 w `tests/Modules/MWP.Core/` (9 plików, mocki CIM, `Start-Process`, administratora i ścieżek danych). Wynik końcowy, każda wersja w nowym procesie: 5.1.26100.9711 — 0 uwag, 393/393; 7.6.7 — 0 uwag, 393/393. BOM UTF-8 i CRLF sprawdzone we wszystkich zmienionych plikach `.ps1`/`.psm1`/`.psd1`.
- Poprawki w trakcie: `[IO.File]::Replace` z `$null` (pusty tekst w .NET → `[NullString]::Value`), walidacja Id wpisu cofnięcia przed odczytem katalogu, `Count` na pojedynczym obiekcie w 5.1 (test), nazwy komputerów w testach przez zmienne (`PSAvoidUsingComputerNameHardcoded`).
- Niezrobione / odroczone: kontekst wykonania zamiast przejściowego `-ComputerName`, punkt przywracania zdalnie, pula runspace'ów → FAZA 3/4; retencja wpisów cofnięć, lokalne rozszerzenia listy ochronnej, obsługa `ConfigurationSchema` → dług techniczny w `STAN_PROJEKTU.md`.
- Decyzje: D-023 … D-030
- Do weryfikacji na Windows 11 (ręcznie, za zgodą): prawdziwy punkt przywracania jako administrator (limit 24 h, wyłączona ochrona), `-Elevate` z monitem UAC, pierwszy zapis w `%LOCALAPPDATA%\MyWindowsPower`.
- Następna faza: FAZA 3 — Komputery docelowe i połączenia zdalne

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
