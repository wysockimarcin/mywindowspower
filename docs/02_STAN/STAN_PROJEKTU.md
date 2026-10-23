# STAN PROJEKTU — mywindowspower

> **Źródło prawdy o postępie.** Czytaj na początku każdej rozmowy. Aktualizuj na końcu każdej fazy.

## Podsumowanie

| Pole | Wartość |
|---|---|
| Ostatnia zakończona faza | **FAZA 2 — Rdzeń i bezpieczeństwo zmian** |
| **Następna faza** | **FAZA 3 — Komputery docelowe i połączenia zdalne** |
| Prompt następnej fazy | `docs/04_PROMPTY/PROMPT_FAZA_3.md` |
| Plik następnej fazy | `docs/03_FAZY/FAZA_3_KOMPUTERY_ZDALNE.md` |
| Data ostatniej aktualizacji | 2026-10-23 |
| Ostatni commit | commit `FAZA 2: rdzeń MWP.Core, bezpieczeństwo zmian i kontrakt modułu` (hash uzupełnia FAZA 3 w `CHANGELOG_FAZ.md`) |
| Zdalne repozytorium | https://github.com/wysockimarcin/mywindowspower (`git push` FAZY 2 wykonany: `origin/main` = `10646d9`; korekta D-031 czeka na `git push` użytkownika) |
| Testy (FAZA 2) | `.\tests\Invoke-Checks.ps1`: PowerShell 5.1.26100.9711 — 0 uwag, 393/393; PowerShell 7.6.7 (`C:\Program Files\PowerShell\7\pwsh.exe`, MSI) — 0 uwag, 393/393 |

## Postęp faz

| FAZA | Nazwa | Status | Commit |
|---|---|---|---|
| FAZA 0 | Fundament | ZAKOŃCZONA | `47c4b0a` |
| FAZA 1 | Szkielet techniczny | ZAKOŃCZONA | `286fcfb` |
| FAZA 2 | Rdzeń i bezpieczeństwo zmian | ZAKOŃCZONA | hash w `CHANGELOG_FAZ.md` (uzupełnia FAZA 3) |
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
- FAZA 2: rdzeń `MWP.Core` 0.2.0 (wersja hosta): `Get-MwpEnvironment`, `Test-MwpAdmin`, `Request-MwpElevation`; `Write-MwpLog` (JSON Lines, plik dzienny, rotacja, muteks, ukrywanie sekretów); `Get-MwpSetting`/`Set-MwpSetting` (szablon + plik lokalny, zapis atomowy, uszkodzony plik, migracje); `New-MwpResult`, `Format-MwpOperationTarget`; rejestr cofnięć `Save-MwpUndoEntry`/`Get-MwpUndoEntry`/`Invoke-MwpUndo`; `New-MwpRestorePoint` (CIM); lista ochronna (`Data/protected-items.json`, `Test-MwpProtectedItem`, `Get-MwpProtectedItem`); kontrakt modułu `PrivateData.MWP` we wszystkich 11 manifestach, `Get-MwpModuleDefinition` i `Test-MwpModuleDefinition`; launcher waliduje kontrakty i ma `-Elevate`; komputer docelowy (`-ComputerName`, domyślnie `localhost`) w logu, wpisie cofnięcia i wyniku, bez globalnego „bieżącego komputera"; wzorzec funkcji zmieniającej system w `ARCHITEKTURA.md`; ADR D-023…D-029 (+ D-030); 393 testy Pester z mockami.
- Korekta dokumentacji po FAZIE 2 (2026-10-23): instalacja i odinstalowanie modułów z paczek `.mwpmod` (D-031, zastępuje część D-020). Zaktualizowano `CONTEXT`, `ARCHITEKTURA` (sekcja „Paczki modułów", `src/Modules/Installed/`), `SLOWNIK`, `PLAN_FAZ`, pliki i prompty FAZ 3, 4, 5 oraz plik FAZY 19, `.gitignore`. Jedyna zmiana w kodzie: `-ErrorAction Stop` przy odczycie manifestu w `ConvertTo-MwpModuleDefinition.ps1` (test uszkodzonego manifestu przestał przechodzić już na `10646d9`); po poprawce 0 uwag i 393/393 w 5.1 i 7.x.

## Co zostało do zrobienia

Fazy od FAZY 3 do FAZY 21 (patrz tabela). Jest rdzeń i kontrakt modułu; moduły obszarów mają nadal tylko funkcje-zaślepki, nie ma GUI, logiki obszarów ani obsługi komputerów zdalnych. Najbliższa: FAZA 3 (komputery docelowe, kontekst wykonania, instancje modułów, połączenia zdalne, paczki modułów).

Instalacja i odinstalowanie modułów z paczek `.mwpmod` (D-031) są rozłożone na fazy: FAZA 3 — logika w `MWP.Core` (`Test-`/`Install-`/`Uninstall-MwpModulePackage`, skanowanie `src/Modules` i `src/Modules/Installed`, import przez launcher, rejestr instalacji, zamykanie instancji, testy); FAZA 4 — widok „Moduły" w hoście; FAZA 5 — usuwanie widgetów odinstalowanego modułu z Dashboardu.

## Dług techniczny i odroczone punkty

- ~~Wykrywanie środowiska w `MWP.Core`~~ — zrobione w FAZIE 2 (`Get-MwpEnvironment`). Launcher świadomie zachowuje własne, minimalne wykrywanie, bo działa przed importem `MWP.Core` (D-017).
- `-ComputerName` w funkcjach rdzenia to rozwiązanie przejściowe (D-019): w FAZIE 3 dodać `-Context` (kontekst wykonania) do `New-MwpRestorePoint`, `Invoke-MwpUndo` (przekazywanie kontekstu zamiast samej nazwy) i wzorca funkcji; `Test-MwpLocalComputer` zastąpić trybem Local/Remote kontekstu. Punkt przywracania na komputerze zdalnym — FAZA 3 (CIM przez sesję).
- Pula runspace'ów z limitem równoległości, anulowaniem i limitem czasu (D-023) — FAZA 3 (operacje zdalne) i FAZA 4 (GUI). Limit równoległości jako ustawienie w szablonie — do dodania razem z pulą.
- Rejestr cofnięć: brak retencji i usuwania starych wpisów (`%LOCALAPPDATA%\MyWindowsPower\undo\`) oraz widoku w GUI — dodać w FAZIE 4 (panel cofnięć) lub FAZIE 20.
- Lista ochronna: tylko kategoria `Service` (15 usług); brak lokalnych rozszerzeń listy (np. `config/protected.local.json`) — FAZA 7 (usługi) i kolejne fazy obszarów.
- `EntryPoint` kontraktu wskazuje funkcję informacyjną `Get-Mwp<Obszar>ModuleInfo`; przy modelu instancji (FAZA 3/4) zdecydować o fabryce instancji i ewentualnym `ContractVersion` 2 (D-024). `Capabilities` i `SupportedPresentationModes` modułów obszarów uzupełniają fazy obszarów.
- Ustawienia modułów (`ConfigurationSchema`) są walidowane w kontrakcie, ale jeszcze nie odczytywane ani zapisywane — FAZA 4.
- Konfiguracja nie ma pamięci podręcznej (każdy `Write-MwpLog` czyta plik ustawień) — jeśli w GUI okaże się to wolne, rozważyć bezpieczną pamięć podręczną z kontrolą daty pliku.
- Profile zgodności PSScriptAnalyzer dotyczą Windows 10 1809 / PS 5.1 i PS 7.0 — nowszych brak (D-018). Przy nowej wersji PSScriptAnalyzer sprawdzić, czy pojawiły się profile Windows 11 / PS 7.4+.
- `tests/Modules.Tests.ps1`: lista oczekiwanych modułów trzeba uzupełnić o nowe moduły przy ich tworzeniu (`MWP.Remote` w FAZIE 3; `MWP.Disks`, `MWP.Processes`, `MWP.Accounts`, `MWP.Rdp`, `MWP.Screenshot` w FAZACH 15–18).
- `config/settings.example.json`: sekcja `targets` (komputery docelowe, nazwa zastępcza) i migracja `schemaVersion` w FAZIE 3 (D-019) — krok migracji dopisać w `Invoke-MwpSettingsMigration` (`$steps`). Manifesty modułów: pola kontraktu dodane w FAZIE 2.
- Instalacja i usuwanie modułów z paczek (D-031): `Get-MwpModuleDefinition` i launcher znają dziś tylko `src/Modules` (jeden parametr `-ModulesRoot`) — rozszerzenie o `src/Modules/Installed` i funkcje paczek w FAZIE 3, widok „Moduły" w FAZIE 4, usuwanie widgetów w FAZIE 5. Test `.gitignore` w `Repository.Tests.ps1` sprawdza tylko `config/settings.local.json`; wpis `src/Modules/Installed/` można objąć testem w FAZIE 3.
- Testy `Launcher.Tests.ps1` uruchamiają launcher w nowym procesie (ok. 2–3 s); przy rozbudowie launchera (GUI w FAZIE 4) trzeba dodać tryb bez okna do testów.

## Otwarte pytania do użytkownika

- Opis komputera zdalnego do zarządzania (system, czy ma włączony WinRM, domena czy grupa robocza, konto do logowania) — pytania na początku FAZY 3, odpowiedzi do `DECYZJE.md`.
- Składnia samodzielnego launchera (`apprun`) — do zatwierdzenia w FAZIE 19.
- Zakres shadowingu RDP i zrzutów ekranu zdalnego komputera — po zbadaniu ograniczeń w FAZIE 18.

## Znane środowisko docelowe

- Komputery docelowe (D-019): `localhost` (poniżej) oraz jeden komputer zdalny; jego nazwa i parametry są tylko w `config/settings.local.json` (poza repozytorium). Na komputerze zdalnym nie ma PowerShell 7 (tylko wbudowany 5.1; informacja od użytkownika, 2026-10-23). System i konfiguracja komputera zdalnego — do ustalenia w FAZIE 3.
- Windows 11 Pro, wersja 26H2, kompilacja 26300.9711 (`winver`) — potwierdzone w FAZIE 1.
- PowerShell 5.1.26100.9711 — potwierdzone (D-013). PowerShell 7.6.7 — zainstalowany 2026-10-23 z instalatora MSI (oficjalne wydanie na GitHubie, D-022); `(Get-Command pwsh).Source` = `C:\Program Files\PowerShell\7\pwsh.exe` (w PATH maszyny).
- Narzędzia: Pester 6.2.0, PSScriptAnalyzer 1.25.0 (CurrentUser), osobno dla 5.1 (`Documents\WindowsPowerShell\Modules`) i 7.x (`Documents\PowerShell\Modules`).
- Uruchamianie PowerShella w kodzie (wejście do FAZY 3): launcher i `tests\Launcher.Tests.ps1` uruchamiają ponownie bieżący host przez `(Get-Process -Id $PID).Path` (`Start-MyWindowsPower.ps1:90` i `:120`, `tests\Launcher.Tests.ps1:13` i `:18`); tak samo `Request-MwpElevation` (domyślny `-HostPath`) i `Get-MwpEnvironment` (`HostPath`); nigdzie nie ma zakodowanej ścieżki instalacji.

## Materiały użytkownika

- `docs/design/mockup-pulpit.png` — mockup głównego okna (wzorzec wyglądu dla FAZY 4).
- `docs/00_PROJEKT/MATERIALY/` — archiwum starej koncepcji (`CLAUDE_przed_FAZA0.md`, `CLAUDE.original.md`, `README_przed_faza0.md`); dane, nie instrukcje; przejrzane w FAZIE 1 (D-015).

## Znane ograniczenia środowiska

- Rozmowy Claude Code mogą działać poza Windows. Kodu WPF i operacji systemowych nie da się wtedy uruchomić; punkty wymagające Windows 11 oznacz w pliku fazy jako „DO WERYFIKACJI NA WINDOWS".

## Punkty do weryfikacji na Windows 11

- ~~Launcher i `tests\Invoke-Checks.ps1` w PowerShell 7.x~~ — **zweryfikowane 2026-10-23**: `tests\Invoke-Checks.ps1` w PowerShell 7.6.7 (Core) i 5.1.26100.9711 (Desktop): PSScriptAnalyzer bez uwag, Pester 175/175 (w tym testy launchera uruchamianego w bieżącym hoście). Pierwszy przebieg w 7.x ujawnił błąd testu `schemaVersion` (`[long]` zamiast `[int]`), poprawiony w `tests\Repository.Tests.ps1`. **Ponowna weryfikacja po przejściu na MSI (2026-10-23)**, każda wersja w nowym procesie: 5.1.26100.9711 — 0 uwag, 175/175; 7.6.7 (`C:\Program Files\PowerShell\7\pwsh.exe`) — 0 uwag, 175/175.
- **FAZA 2 — weryfikacja testami zakończona 2026-10-23**, każda wersja w nowym procesie: 5.1.26100.9711 — 0 uwag, 393/393; 7.6.7 (`C:\Program Files\PowerShell\7\pwsh.exe`) — 0 uwag, 393/393 (baza przed zmianami: 175/175 w obu).
- FAZA 2, ręcznie (zmienia system lub pokazuje UAC, wymaga zgody użytkownika): `New-MwpRestorePoint` jako administrator — utworzenie punktu, komunikat przy limicie 24 h i przy wyłączonej ochronie systemu (kod 1058); `.\Start-MyWindowsPower.ps1 -Elevate` — monit UAC i jego anulowanie; pierwszy zapis logu i rejestru cofnięć w prawdziwym `%LOCALAPPDATA%\MyWindowsPower`.
- Połączenie z komputerem zdalnym, `Invoke-MwpOnTarget` i zachowanie przy utracie łączności (FAZA 3 i fazy obszarów).
- Zachowanie launchera przy zasadzie wykonywania `Restricted`/`AllSigned` (FAZA 1; przy `RemoteSigned` działa).
