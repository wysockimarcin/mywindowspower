# STAN PROJEKTU — mywindowspower

> **Źródło prawdy o postępie.** Czytaj na początku każdej rozmowy. Aktualizuj na końcu każdej fazy.

## Podsumowanie

| Pole | Wartość |
|---|---|
| Ostatnia zakończona faza | **FAZA 3 — Komputery docelowe i połączenia zdalne** |
| **Następna faza** | **FAZA 4 — Szkielet GUI i host modułów** |
| Prompt następnej fazy | `docs/04_PROMPTY/PROMPT_FAZA_4.md` |
| Plik następnej fazy | `docs/03_FAZY/FAZA_4_GUI_SZKIELET.md` |
| Data ostatniej aktualizacji | 2026-10-23 |
| Ostatni commit | commit `FAZA 3: komputery docelowe, kontekst wykonania, połączenia zdalne, instancje i paczki modułów` (hash uzupełnia FAZA 4 w `CHANGELOG_FAZ.md`); poprzedni: `6f9925d` (korekta D-032) |
| Zdalne repozytorium | https://github.com/wysockimarcin/mywindowspower (`origin/main` = `6f9925d` według `git status` na starcie FAZY 3; commit FAZY 3 czeka na `git push` użytkownika) |
| Testy (FAZA 3) | `.\tests\Invoke-Checks.ps1`: PowerShell 5.1.26100.9711 — 0 uwag, 660/660; PowerShell 7.6.7 (`C:\Program Files\PowerShell\7\pwsh.exe`, MSI) — 0 uwag, 660/660 (baza: 420/420) |

## Postęp faz

| FAZA | Nazwa | Status | Commit |
|---|---|---|---|
| FAZA 0 | Fundament | ZAKOŃCZONA | `47c4b0a` |
| FAZA 1 | Szkielet techniczny | ZAKOŃCZONA | `286fcfb` |
| FAZA 2 | Rdzeń i bezpieczeństwo zmian | ZAKOŃCZONA | `10646d9` (korekty: `aa92c91`, `6f9925d`) |
| FAZA 3 | Komputery docelowe i połączenia zdalne | ZAKOŃCZONA | hash w `CHANGELOG_FAZ.md` (uzupełnia FAZA 4) |
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
- Korekta FAZY 2 (2026-10-23, D-032): miejsce danych aplikacji. `Get-MwpDataPath` czyta klucz `dataPath` (nowy w `config/settings.example.json`, domyślnie pusty = `<folder aplikacji>\data`, względna od folderu aplikacji, bezwzględna ze zmiennymi środowiskowymi i UNC); katalog niezapisywalny lub ścieżka niepoprawna → `%LOCALAPPDATA%\MyWindowsPower` z ostrzeżeniem w wyniku i w logu (`DataPath.Fallback`); `settings.local.json` w trybie zapasowym też tam (`Get-MwpConfigPath -ForWrite`); nowa funkcja `Test-MwpDirectoryWritable` (wynik pamiętany do końca procesu); `Write-MwpLog` ponawia zapis przy blokadzie pliku; `Write-MwpJsonFile` i log tworzą katalogi metodą .NET (nawiasy `[ ]` w ścieżce). `.gitignore`: `/data/`. Testy: `DataPath.Tests.ps1` (+21), `Repository.Tests.ps1` (+2 oraz +4 testy kodowania dwóch nowych plików); mocki `Get-MwpDataPath` w 5 plikach obsługują `-Detailed`. Wynik: 0 uwag, 420/420 w 5.1 i 7.x.

- FAZA 3 (2026-10-23): nowy moduł bazowy `MWP.Remote` 0.3.0 — rejestr komputerów docelowych (`Get-`/`Add-`/`Remove-MwpTarget`, `localhost` zawsze obecny), niezmienny kontekst wykonania (`New-MwpExecutionContext`; obiekt połączenia ze stanem `Connected`/`Connecting`/`Disconnected`/`Unauthorized`/`Error`), połączenia WinRM (`Connect-`/`Disconnect-`/`Test-MwpTarget`: sieć, uwierzytelnienie, autoryzacja), wykonanie lokalnie i zdalnie (`Invoke-MwpOnTarget`), odczyt CIM (`Get-MwpCimSessionParameter`), operacje asynchroniczne w puli runspace'ów z limitem równoległości, limitem czasu i anulowaniem (`Start-`/`Wait-`/`Stop-MwpOperation`), instancje modułów (`New-`/`Initialize-`/`Close-`/`Get-MwpModuleInstance`), adapter transportu w funkcjach prywatnych. `MWP.Core` 0.3.0: paczki `.mwpmod` (`Test-`/`Install-`/`Uninstall-MwpModulePackage`, `Get-MwpInstalledModule`), odkrywanie w `src/Modules` i `src/Modules/Installed` (`Source`, `IsBase`), `-Context` w `New-MwpRestorePoint` (punkt na komputerze zdalnym) i `Invoke-MwpUndo`. Launcher importuje moduły zainstalowane. Szablon ustawień w schemacie 2 (`targets`, `installedModules`, `modules`, limity połączeń) z migracją zachowującą `dataPath`. ADR D-033…D-037. Testy: 660 (+240), 0 uwag w 5.1 i 7.x.

## Co zostało do zrobienia

Fazy od FAZY 4 do FAZY 21 (patrz tabela). Jest rdzeń, kontrakt modułu, obsługa komputerów zdalnych, instancje i paczki modułów; moduły obszarów mają nadal tylko funkcje-zaślepki, nie ma GUI ani logiki obszarów. Najbliższa: FAZA 4 (szkielet GUI i host modułów, widok „Moduły", katalog danych w Ustawieniach).

Instalacja i odinstalowanie modułów z paczek `.mwpmod` (D-031): logika gotowa w FAZIE 3; FAZA 4 — widok „Moduły" w hoście; FAZA 5 — usuwanie widgetów odinstalowanego modułu z Dashboardu.

## Dług techniczny i odroczone punkty

- ~~Wykrywanie środowiska w `MWP.Core`~~ — zrobione w FAZIE 2 (`Get-MwpEnvironment`). Launcher świadomie zachowuje własne, minimalne wykrywanie, bo działa przed importem `MWP.Core` (D-017).
- ~~`-ComputerName` w funkcjach rdzenia (przejściowe)~~ — rozstrzygnięte w FAZIE 3 (D-035): `-Context` w `New-MwpRestorePoint` (punkt na komputerze zdalnym przez `Invoke-MwpOnTarget`) i `Invoke-MwpUndo`, wzorzec funkcji z `-Context`. `-ComputerName` zostaje dla zgodności i oznacza tylko komputer lokalny (`Test-MwpLocalComputer` dla tej ścieżki); log, wpis cofnięcia i wynik nadal przyjmują nazwę jako etykietę.
- ~~Pula runspace'ów (D-023)~~ — zrobiona w FAZIE 3 (`Start-`/`Wait-`/`Stop-MwpOperation`, `remoteMaxParallelOperations`, D-036); użycie w GUI — FAZA 4. Zmiana limitu działa po ponownym uruchomieniu (pula tworzona raz na proces).
- Rejestr cofnięć: brak retencji i usuwania starych wpisów (`<katalog danych>\undo\`, D-032) oraz widoku w GUI — dodać w FAZIE 4 (panel cofnięć) lub FAZIE 20.
- Lista ochronna: tylko kategoria `Service` (15 usług); brak lokalnych rozszerzeń listy (np. `config/protected.local.json`) — FAZA 7 (usługi) i kolejne fazy obszarów.
- ~~Fabryka instancji a `EntryPoint` (D-024)~~ — rozstrzygnięte w FAZIE 3 (D-035): fabryką jest host (`New-MwpModuleInstance`), `ContractVersion` 1 bez zmian; haki inicjalizacji/zamknięcia w module → `ContractVersion` 2, gdy faza obszaru ich potrzebuje. `Capabilities` i `SupportedPresentationModes` modułów obszarów uzupełniają fazy obszarów — **instancja dla komputera zdalnego wymaga `RemoteTarget`**, którego moduły obszarów jeszcze nie deklarują (FAZA 4: moduł-zaślepka do testu dwóch instancji; fazy obszarów: dopisanie `RemoteTarget`).
- Ustawienia modułów (`ConfigurationSchema`) są walidowane w kontrakcie, ale jeszcze nie odczytywane ani zapisywane — FAZA 4 (miejsce: klucz `modules.<Id>` w `settings.local.json`, D-037; odinstalowanie już go usuwa).
- Konfiguracja nie ma pamięci podręcznej (każdy `Write-MwpLog` czyta plik ustawień) — jeśli w GUI okaże się to wolne, rozważyć bezpieczną pamięć podręczną z kontrolą daty pliku.
- Profile zgodności PSScriptAnalyzer dotyczą Windows 10 1809 / PS 5.1 i PS 7.0 — nowszych brak (D-018). Przy nowej wersji PSScriptAnalyzer sprawdzić, czy pojawiły się profile Windows 11 / PS 7.4+.
- `tests/Modules.Tests.ps1`: lista oczekiwanych modułów trzeba uzupełnić o nowe moduły przy ich tworzeniu (`MWP.Remote` dodany w FAZIE 3; `MWP.Disks`, `MWP.Processes`, `MWP.Accounts`, `MWP.Rdp`, `MWP.Screenshot` w FAZACH 15–18).
- ~~Sekcja `targets` i migracja `schemaVersion`~~ — zrobione w FAZIE 3 (schemat 2, D-037). ~~Paczki modułów i dwa katalogi modułów~~ — zrobione w FAZIE 3 (D-031, D-037), z testem `.gitignore` dla `src/Modules/Installed/`; widok „Moduły" — FAZA 4, usuwanie widgetów — FAZA 5.
- Połączenia zdalne (FAZA 3): brak poświadczeń zapisanych lokalnie (DPAPI) — świadomie odrzucone w D-034, można dodać nowym ADR; brak obsługi IPv6 w nazwach komputerów (`Test-MwpTargetName`: NetBIOS/DNS/IPv4); `Test-MwpTarget` nie ma własnego limitu czasu dla `Test-WSMan` (zależy od systemu); paczki nie mają limitu rozmiaru archiwum (jeden użytkownik, własne paczki).
- Rejestr instancji i pula runspace'ów są w pamięci procesu hosta (D-023): instancje nie są odtwarzane po restarcie aplikacji — zapis i odtworzenie konfiguracji (Dashboard) w FAZIE 5.
- Katalog danych (D-032), FAZA 4: edycja `dataPath` w Ustawieniach (podgląd ścieżki wynikowej, ostrzeżenie o trybie zapasowym), przycisk „Przenieś dane” (przeniesienie `logs`/`undo` do nowego katalogu z podglądem, logiem i potwierdzeniem), przeniesienie modułów z paczek z `src/Modules/Installed` do katalogu danych (skanowanie w `Get-MwpModuleDefinition` i launcherze, migracja instalacji). `Get-MwpDataPath` jest wewnętrzna — do GUI potrzebna funkcja publiczna (np. stan katalogu danych). Wybór miejsca przy instalacji — wraz z instalatorem aplikacji.
- Katalog danych (D-032): wynik sprawdzenia zapisywalności jest pamiętany do końca procesu — zmiana uprawnień folderu wymaga ponownego uruchomienia aplikacji. Brak automatycznej migracji starych danych z `%LOCALAPPDATA%\MyWindowsPower` (dane z ręcznych prób sprzed korekty trzeba przenieść ręcznie, jeśli są potrzebne).
- Testy `Launcher.Tests.ps1` uruchamiają launcher w nowym procesie (ok. 2–3 s); przy rozbudowie launchera (GUI w FAZIE 4) trzeba dodać tryb bez okna do testów.

## Otwarte pytania do użytkownika

- ~~Opis komputera zdalnego~~ — odpowiedzi w FAZIE 3 (D-033): Windows 11, WinRM HTTP 5985, grupa robocza, Get-Credential na żądanie.
- Składnia samodzielnego launchera (`apprun`) — do zatwierdzenia w FAZIE 19.
- Zakres shadowingu RDP i zrzutów ekranu zdalnego komputera — po zbadaniu ograniczeń w FAZIE 18.

## Znane środowisko docelowe

- Komputery docelowe (D-019): `localhost` (poniżej) oraz jeden komputer zdalny; jego nazwa i parametry są tylko w `config/settings.local.json` (poza repozytorium). Komputer zdalny (D-033): Windows 11, grupa robocza, WinRM HTTP 5985 włączony, logowanie kontem z `Get-Credential` na żądanie; bez PowerShell 7 (tylko wbudowany 5.1).
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
- **Korekta D-032 — weryfikacja testami 2026-10-23**, każda wersja w nowym procesie: 5.1.26100.9711 — 0 uwag, 420/420; 7.6.7 — 0 uwag, 420/420 (baza: 393/393). Testy nie zapisują do prawdziwego `%LOCALAPPDATA%\MyWindowsPower` ani do `data\`/`config\` repozytorium (sprawdza to ostatni test `DataPath.Tests.ps1`).
- **FAZA 2, weryfikacja ręczna na Windows 11 (2026-10-23) — CZĘŚCIOWA, nie zamknięta w całości.**
  - ZROBIONE: zapis logu w `data\logs` obok aplikacji, bez zapisu do `%LOCALAPPDATA%` przy ustawieniach domyślnych (D-032); tryb zapasowy przy niezapisywalnym `dataPath` (`IsFallback = True`, ostrzeżenie, katalog `%LOCALAPPDATA%\MyWindowsPower`); podgląd cofnięcia `Invoke-MwpUndo -WhatIf` (wpis dostępny po przełączeniu na katalog zapasowy); `New-MwpRestorePoint` — podgląd `-WhatIf` oraz obsługa limitu 24 h (`Success = True`, `Changed = False`, czytelny komunikat; ostatni punkt 201 „Zaplanowany punkt kontrolny” z 11:02).
  - DO ZROBIENIA: (a) prawdziwe utworzenie punktu przywracania — limit 24 h blokował próbę; test z czasowym wyłączeniem limitu (`SystemRestorePointCreationFrequency = 0`, potem usunąć wartość) albo po 24 h; (b) komunikat przy wyłączonej ochronie systemu (kod 1058) — opcjonalnie; (c) `.\Start-MyWindowsPower.ps1 -Elevate` — zatwierdzenie i anulowanie monitu UAC (oczekiwany kod wyjścia 1 przy anulowaniu); (d) wykonanie cofnięcia `Invoke-MwpUndo -Id b8fc07cf-4708-4d20-a168-4a381f162fb3` i powrót `Get-MwpDataPath -Detailed` do `IsFallback = False`; (e) odczyt logu `Get-Content -Encoding UTF8` — „rÄ™czny” w 5.1 bez `-Encoding` to najpewniej odczyt UTF-8 bez BOM jako ANSI, do potwierdzenia.
  - Uwagi do FAZY 4: odczyt logu w kodzie zawsze z jawnym UTF-8; po zmianie `dataPath` wpisy cofnięć z poprzedniego katalogu są niewidoczne (brak migracji) — „Przenieś dane” albo odczyt ze starej lokalizacji.
- **FAZA 3 — weryfikacja testami zakończona 2026-10-23**, każda wersja w nowym procesie: 5.1.26100.9711 — 0 uwag, 660/660; 7.6.7 — 0 uwag, 660/660 (baza 420/420). Test dymny (tylko odczyt) na localhost w 5.1: `Invoke-MwpOnTarget` i `Start-`/`Wait-MwpOperation` działają.
- **FAZA 3, ręcznie z prawdziwym komputerem zdalnym (wymaga poświadczeń i wpisu `TrustedHosts` wykonanego przez użytkownika, instrukcja w `ARCHITEKTURA.md`, sekcja „Konfiguracja komputera zdalnego"):** (a) `Add-MwpTarget`, `New-MwpExecutionContext -Credential (Get-Credential)` i `(Test-MwpTarget -Context $c).Data` — `Reachable`, `Authenticated`, `Authorized`, `IsAdministrator`, `RemotePSVersion` 5.1; (b) `Invoke-MwpOnTarget` (odczyt, np. `$PSVersionTable`) i `Get-MwpCimSessionParameter` z `Get-CimInstance Win32_OperatingSystem`; (c) zachowanie przy wyłączonym komputerze zdalnym (stan `Error`, czas do błędu) i przy złym haśle (`Unauthorized`); (d) brak wpisu w `TrustedHosts` (komunikat `Configuration`); (e) utrata połączenia w trakcie (np. odłączenie sieci) i ponowne połączenie; (f) `Start-MwpOperation` na komputerze zdalnym; (g) opcjonalnie `New-MwpRestorePoint -Context` na komputerze zdalnym (zmienia system — tylko za zgodą użytkownika).
- **FAZA 3, ręcznie — paczki:** instalacja i odinstalowanie przykładowej paczki `.mwpmod` na prawdziwym dysku (`src\Modules\Installed`, poza `TestDrive`) i import modułu przez launcher („(z paczki)").
- Zachowanie launchera przy zasadzie wykonywania `Restricted`/`AllSigned` (FAZA 1; przy `RemoteSigned` działa).
