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

## FAZA 4 — Szkielet GUI i host modułów (2026-10-26)
- Status: ZAKOŃCZONA (ręczna weryfikacja okna na Windows 11 — lista w pliku fazy)
- Commit: `FAZA 4: okno hosta WPF, instancje modułów, motywy, zadania w tle, widok Moduły i katalog danych` — hash do uzupełnienia na starcie FAZY 5
- Start: uzupełniono hash korekty FAZY 3 (`228bf40`); baza testów w czystej kopii `228bf40` — 5.1.26100.9711: 0 uwag, 664/664; 7.6.7: 0 uwag, 664/664.
- Zrobiono:
  - Okno hosta (`src/UI`, D-039, D-040): `UI.ps1`, moduł prezentacji `MWP.UI` (logika bez WPF w `Functions/`, okna w `Wpf/`), `MainWindow.xaml` (wyszukiwanie Ctrl+K, nawigacja z katalogu obszarów i sekcją otwartych instancji, panel logu, pasek stanu z zadaniami w tle), widoki Pulpit (zaślepka Dashboardu), obszar (zaślepka z fazą), instancja, Moduły, Ustawienia, O programie; okna: potwierdzenie z „Podglądem zmian”, poświadczenia, wybór komputera, edytor komputera, osobne okno instancji; motywy jasny/ciemny (systemowy domyślnie, przełącznik zapamiętany w `theme`) i wspólne style.
  - Zadania w tle GUI: pula runspace'ów z `MWP.Core`/`MWP.Remote`, postęp i anulowanie, wyniki odbierane zegarem okna (`Start-`/`Stop-`/`Update-MwpUiTask`, `Register-MwpUiOperation`).
  - Instancje: wiele instancji tego samego modułu dla różnych komputerów, własne widoki, tryby w oknie głównym i w osobnym oknie, połączenie w tle z oknem poświadczeń, diagnostyka, odczyt testowy, zamknięcie jednej bez wpływu na inne.
  - `MWP.Core` 0.4.0 (D-038): `Get-MwpDataLocation`, `Move-MwpDataDirectory` („Przenieś dane”), `Move-MwpInstalledModule`; moduły z paczek w `<katalog danych>\modules`. `MWP.Remote` 0.4.0 (D-041): `Set-MwpTarget`, `Get-MwpTargetInfo`.
  - Launcher otwiera okno (`-NoGui` bez okna) i importuje moduły także z katalogu danych.
  - Paczka przykładowa `samples/MWP.Przyklad` (RemoteTarget) do weryfikacji instalacji i dwóch instancji.
  - Dokumentacja: `DECYZJE` (D-038…D-041), `ARCHITEKTURA` (struktura `src/UI`, okno hosta, tryby, katalog danych, paczki), `SLOWNIK`, `README`, `FAZA_4`, `FAZA_19` (katalogi modułów), `STAN_PROJEKTU`.
- Testy: 922/922 w 5.1.26100.9711 i 922/922 w 7.6.7, 0 uwag PSScriptAnalyzer (baza 664/664). Nowe: `tests/UI/UiFunctions.Tests.ps1`, `tests/UI/Xaml.Tests.ps1`, `tests/Modules/MWP.Core/DataLocation.Tests.ps1`, `tests/Samples.Tests.ps1`; rozszerzone `Targets`, `Launcher`, `Architecture`. Automatyczny test dymny okna w 5.1 i 7.6.7 (wszystkie widoki, dwie instancje, osobne okno, motyw, zadanie testowe, zamknięcie) — kod wyjścia 0.
- Niezrobione / odroczone: ręczna weryfikacja okna (lista w `FAZA_4_GUI_SZKIELET.md`); usuwanie widgetów odinstalowanego modułu — FAZA 5; panel cofnięć w GUI — dług techniczny; ciemny pasek tytułu — dług techniczny.
- Decyzje: D-038, D-039, D-040, D-041
- Do weryfikacji na Windows 11: okno w 5.1 i 7.x, motywy, DPI, responsywność przy zadaniu testowym, instalacja i odinstalowanie paczki przykładowej, dwie instancje dla localhost i komputera zdalnego, utrata połączenia, „Przenieś dane”.
- Następna faza: FAZA 5 — Dashboard

## Korekta FAZY 3 — opcje sesji CIM (2026-10-26)
- Status: ZAKOŃCZONA (korekta, nie nowa faza)
- Commit: `228bf40` `FAZA 3 (korekta): poprawka New-MwpCimSession i test opcji sesji bez mocka` (hash uzupełniony na starcie FAZY 4)
- Powód: ręczna weryfikacja FAZY 3 z prawdziwym komputerem zdalnym (wyniki użytkownika w `STAN_PROJEKTU.md`) wykazała, że `New-MwpCimSession` łączył w `New-CimSessionOption` parametry `-Protocol` i `-UseSsl` z różnych zestawów, więc każde zdalne `Get-MwpCimSessionParameter` kończyło się błędem. Testy go nie wykryły, bo mockowały cały adapter.
- Zrobiono: poprawka użytkownika w `src/Modules/MWP.Remote/Private/New-MwpCimSession.ps1` (osobne wywołania dla HTTPS i HTTP) z opisem w pomocy funkcji; nowe testy w `tests/Modules/MWP.Remote/Connection.Tests.ps1` (kontekst „adapter transportu bez mocka opcji sesji”): prawdziwe `New-CimSessionOption` i `New-PSSessionOption`, mock tylko `New-CimSession`/`New-PSSession`, dla HTTP i HTTPS; bez poprawki test CIM pada z błędem zestawu parametrów. Zapisy ręcznej weryfikacji FAZY 3 i nowe punkty długu technicznego w `STAN_PROJEKTU.md` (użytkownik).
- Testy: `.\tests\Invoke-Checks.ps1`, każda wersja w nowym procesie — 5.1.26100.9711: 0 uwag, 664/664; 7.6.7: 0 uwag, 664/664 (było 660/660).
- Odroczone (dług techniczny): podkreślenie w nazwie komputera (`Test-MwpTargetName`), `Set-MwpTarget`, pominięte punkty ręcznej weryfikacji (złe hasło, wyłączony komputer, utrata połączenia, punkt przywracania zdalnie).
- Następna faza: FAZA 4 — Szkielet GUI i host modułów

## FAZA 3 — Komputery docelowe i połączenia zdalne (2026-10-23)
- Status: ZAKOŃCZONA (połączenie z prawdziwym komputerem zdalnym — do weryfikacji ręcznej)
- Commit: `7ffb534` `FAZA 3: komputery docelowe, kontekst wykonania, połączenia zdalne, instancje i paczki modułów` (wypchnięty do `origin/main`)
- Start: uzupełniono hashe FAZY 2 (`10646d9`) i korekt (`aa92c91`, `6f9925d`); baza testów w nowych procesach — 5.1.26100.9711: 0 uwag, 420/420; 7.6.7 (`C:\Program Files\PowerShell\7\pwsh.exe`): 0 uwag, 420/420. Niezatwierdzone zmiany użytkownika w `STAN_PROJEKTU.md` (wyniki ręcznej weryfikacji FAZY 2) zachowane.
- Pytania do użytkownika: komputer zdalny — Windows 11, WinRM HTTP 5985 włączony, grupa robocza, logowanie przez Get-Credential na żądanie (D-033).
- Zrobiono:
  - `MWP.Remote` 0.3.0 (nowy moduł bazowy): `Get-`/`Add-`/`Remove-MwpTarget` (rejestr komputerów, `localhost` zawsze obecny, wpis przykładowy z szablonu pomijany), `New-MwpExecutionContext` (pola tylko do odczytu przez `PSVariableProperty`, obiekt połączenia jako jedyny zmienny element, polityka limitów czasu i błędów), `Connect-`/`Disconnect-`/`Test-MwpTarget` (sieć / uwierzytelnienie / autoryzacja, klasy błędów Unauthorized, CredentialRequired, Configuration, Timeout, Network, ConnectionLost), `Invoke-MwpOnTarget` (lokalnie blok odtworzony z tekstu, zdalnie przez sesję WinRM z limitem czasu, bez automatycznego ponawiania), `Get-MwpCimSessionParameter`, `Start-`/`Wait-`/`Stop-MwpOperation` (pula runspace'ów, limit równoległości, limit czasu, anulowanie), `New-`/`Initialize-`/`Close-`/`Get-MwpModuleInstance`; adapter transportu w funkcjach prywatnych (`New-MwpPSSession`, `Invoke-MwpSessionCommand`, `New-MwpCimSession`, `Test-MwpWsMan`, `Remove-*`).
  - `MWP.Core` 0.3.0: `Test-`/`Install-`/`Uninstall-MwpModulePackage`, `Get-MwpInstalledModule`; prywatne `Expand-MwpModulePackage`, `Read-MwpModulePackage`, `Get-MwpModuleRoot`, `Move-MwpDirectory`, `Write-MwpLocalSetting` (wspólny zapis ustawień lokalnych, używany też przez `Set-MwpSetting`), `Get-MwpInstalledModuleEntry`; `Get-MwpModuleDefinition -ModulesRoot` przyjmuje listę katalogów (domyślnie `src/Modules` i `src/Modules/Installed`), definicja ma `Source` i `IsBase`, `Test-MwpModuleDefinition` wykrywa ten sam folder w dwóch katalogach; `New-MwpRestorePoint -Context` (punkt na komputerze zdalnym przez `Invoke-MwpOnTarget`); `Invoke-MwpUndo -Context`; `Set-MwpSetting` przyjmuje pustą listę.
  - Launcher importuje moduły z `src/Modules/Installed` po wbudowanych („(z paczki)").
  - `config/settings.example.json`: `schemaVersion` 2, `targets` (wpis przykładowy `NAZWA-KOMPUTERA`), `installedModules`, `modules`, `remoteMaxParallelOperations`, `remoteConnectTimeoutSeconds`, `remoteOperationTimeoutSeconds`; migracja 1 → 2 w `Invoke-MwpSettingsMigration` zachowuje `dataPath`.
  - Dokumentacja: `DECYZJE` (D-033…D-037), `ARCHITEKTURA` (kontekst, połączenia, instancje, wzorzec funkcji z `-Context`, paczki, konfiguracja komputera zdalnego w grupie roboczej, testy architektoniczne), `CONTEXT`, `SLOWNIK` (4 hasła), `FAZA_3`, `FAZA_4` (wejście z FAZY 3), `STAN_PROJEKTU`.
- Testy: nowe pliki `tests/Modules/MWP.Remote/` (`Targets`, `ExecutionContext`, `Connection`, `Instances`, `Operations`), `tests/Modules/MWP.Core/ModulePackage.Tests.ps1`, `RestorePointRemote.Tests.ps1`; rozszerzone `Settings` (migracja), `ModuleContract` (dwa katalogi), `Undo` (`-Context`), `Architecture` (kontekst, adapter transportu, brak zmian `TrustedHosts`), `Repository` (`.gitignore` dla `src/Modules/Installed/`), `Modules` (`MWP.Remote`), `Launcher` (moduł zainstalowany w kopii aplikacji na TestDrive). `.\tests\Invoke-Checks.ps1`, każda wersja w nowym procesie: 5.1.26100.9711 — 0 uwag, 660/660; 7.6.7 — 0 uwag, 660/660. Testy nie łączą się z komputerami zdalnymi (mocki adaptera transportu) i nie piszą do `data\`, `config\` ani `src\Modules\Installed` repozytorium.
- Niezrobione / odroczone: GUI (wybór komputera, okno poświadczeń, stan połączenia, widok „Moduły") — FAZA 4; `RemoteTarget` w modułach obszarów — fazy obszarów; usuwanie widgetów odinstalowanego modułu — FAZA 5; poświadczenia DPAPI — odrzucone na teraz (D-034).
- Decyzje: D-033, D-034, D-035 (rozstrzyga dług D-024 i przejściowe `-ComputerName`), D-036, D-037
- Do weryfikacji na Windows 11 (ręcznie): połączenie z komputerem zdalnym użytkownika (po wpisie `TrustedHosts`): `Test-MwpTarget`, `Invoke-MwpOnTarget`, CIM, wyłączony komputer, złe hasło, utrata połączenia, operacja asynchroniczna; instalacja i odinstalowanie przykładowej paczki na prawdziwym dysku i import przez launcher.
- Następna faza: FAZA 4 — Szkielet GUI i host modułów

## Korekta FAZY 2 — miejsce danych aplikacji (2026-10-23)
- Status: ZAKOŃCZONA (korekta, nie nowa faza)
- Commit: `6f9925d` `FAZA 2 (korekta): miejsce danych aplikacji w folderze aplikacji (D-032)`; hash korekty D-031: `aa92c91`
- Powód: aplikacja jest używana przez jednego użytkownika i może leżeć w dowolnym folderze; dane (log, rejestr cofnięć) mają być domyślnie obok aplikacji, z możliwością zmiany przez konfigurację. D-026 i D-028 zapisywały je w `%LOCALAPPDATA%\MyWindowsPower`.
- Zrobiono: D-032; `Get-MwpDataPath` (klucz `dataPath`, domyślnie `<folder aplikacji>\data`, ścieżka względna od folderu aplikacji, bezwzględna ze zmiennymi środowiskowymi i UNC, tryb zapasowy `%LOCALAPPDATA%\MyWindowsPower` z ostrzeżeniem, `-Detailed`, `-Kind Fallback`), nowa `Test-MwpDirectoryWritable` (próba utworzenia i usunięcia pliku, wynik pamiętany w procesie), `Get-MwpConfigPath -ForWrite` i `Set-MwpSetting` (plik lokalny w trybie zapasowym), `Write-MwpLog` (ostrzeżenie `DataPath.Fallback` raz na proces, do 5 ponowień zapisu przy blokadzie pliku), `Write-MwpJsonFile` (tworzenie katalogu metodą .NET); `dataPath` w `config/settings.example.json`; `/data/` w `.gitignore`; opisy w `Write-MwpLog`, `Save-MwpUndoEntry`, `ARCHITEKTURA`, `CONTEXT`, `FAZA_2`, `STAN_PROJEKTU`; punkty D-032 w `PROMPT_FAZA_3.md` i w planie FAZY 4 (`FAZA_4_GUI_SZKIELET.md`, `PROMPT_FAZA_4.md`, `PLAN_FAZ.md`).
- Testy: nowy `tests/Modules/MWP.Core/DataPath.Tests.ps1` (25 testów: domyślna ścieżka, względna, bezwzględna ze zmienną, spacje i polskie znaki, UNC, niezapisywalny katalog, niepoprawne ścieżki, ustawienia w trybie zapasowym, blokada pliku logu przez inny proces, brak zapisu do prawdziwego profilu i folderu repozytorium); `Repository.Tests.ps1` +2 (`/data/` w `.gitignore`, `Data/` modułu nie jest pomijany) i +4 automatyczne testy kodowania nowych plików. `.\tests\Invoke-Checks.ps1`, każda wersja w nowym procesie: 5.1.26100.9711 — 0 uwag, 420/420; 7.6.7 — 0 uwag, 420/420 (baza 393/393). BOM UTF-8 i CRLF zachowane.
- Niezrobione / odroczone: edycja `dataPath` i „Przenieś dane” w Ustawieniach oraz przeniesienie modułów z paczek do katalogu danych — FAZA 4; wybór miejsca przy instalacji — z instalatorem aplikacji; migracji starych danych nie ma (decyzja).
- Decyzje: D-032 (zastępuje miejsce danych z D-026 i D-028 oraz odrzucenie `./data/` w D-015 i D-019)
- Do weryfikacji na Windows 11 (ręcznie): pierwszy zapis w `data` obok aplikacji i zachowanie w folderze niezapisywalnym.
- Następna faza: FAZA 3 — Komputery docelowe i połączenia zdalne

## Korekta dokumentacji po FAZIE 2 — instalacja i usuwanie modułów z paczki (2026-10-23)
- Status: ZAKOŃCZONA (korekta, nie nowa faza)
- Commit: `aa92c91` `FAZA 2 (korekta): instalacja i usuwanie modułów z paczki (D-031)`
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
- Commit: `10646d9` `FAZA 2: rdzeń MWP.Core, bezpieczeństwo zmian i kontrakt modułu`
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
