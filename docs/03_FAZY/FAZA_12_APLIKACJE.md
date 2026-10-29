# FAZA 12 — Aplikacje i winget

**Status:** ZAKOŃCZONA (ręczna weryfikacja prawdziwej instalacji, aktualizacji i odinstalowania oraz komputera zdalnego — lista niżej)

## Cel
Porządek w zainstalowanych programach: lista, aktualizacje, odinstalowanie.

## Zależności
FAZY 2, 3 i 4 zakończone.

## Zakres
- Moduł `MWP.Apps`: lista programów z rejestru (`Uninstall`, 64/32 bit, użytkownik/maszyna) oraz pakietów Appx (`Get-AppxPackage`), z filtrami i sortowaniem.
- `winget`: wykrycie obecności, lista (`winget list`), aktualizacje (`winget upgrade`), aktualizacja pojedynczej aplikacji, odinstalowanie; parsowanie wyjścia odporne na język i szerokość kolumn (np. przełączniki wyjścia, a gdy ich brak — parsowanie po nagłówkach).
- Odinstalowanie: wyłącznie z potwierdzeniem i podglądem; **lista ochronna** pakietów systemowych (nie do usunięcia z GUI).
- Wyszukiwanie pakietów w repozytorium winget i instalacja wybranego (z potwierdzeniem).
- Zapis informacji o odinstalowanej aplikacji w logu (nazwa, wersja, wydawca); cofnięcie = ponowna instalacja przez winget, jeśli pakiet jest w repozytorium.
- Widok `Apps.xaml`, operacje w tle z postępem.
- Testy Pester z mockami `winget`.
- Obsługa komputera docelowego (D-019): lista z rejestru (HKLM; HKCU tylko dla wskazanego profilu) działa zdalnie. **Do zbadania:** `winget` i pakiety Appx w kontekście sesji zdalnej bez zalogowanego użytkownika bywają niedostępne; zakres zdalny ustal po sprawdzeniu i zapisz w `DECYZJE.md`.

## Poza zakresem
Instalacja z plików `.msi`/`.exe` spoza winget, czyszczenie resztek po odinstalowaniu.

## Checklista
- [x] Lista programów (rejestr + Appx) — `Get-MwpInstalledApp`, `Select-MwpInstalledApp` (filtry, sortowanie); na tym komputerze 682 pozycje (149 bez składników systemowych), ok. 3,3 s
- [x] Wykrycie i obsługa `winget` — `Get-MwpWingetInfo`, `Get-MwpWingetPackage`, parser `ConvertFrom-MwpWingetOutput` (strona kodowa OEM, kolumny z nagłówka), sprawdzone na winget 1.29.380
- [x] Lista aktualizacji i aktualizacja pojedyncza — `Get-MwpWingetPackage -UpgradeAvailable` (25 na tym komputerze), `Update-MwpWingetPackage` (podgląd sprawdzony; prawdziwa aktualizacja — DO WERYFIKACJI)
- [x] Odinstalowanie z potwierdzeniem i listą ochronną — `Uninstall-MwpApp` (Destrukcyjna; kategorie `App`, `AppxPackage`; Appx systemowe i składniki systemu); podgląd sprawdzony, prawdziwe odinstalowanie — DO WERYFIKACJI
- [x] Wyszukiwanie i instalacja pakietu — `Find-MwpWingetPackage`, `Install-MwpWingetPackage` (podgląd sprawdzony; prawdziwa instalacja — DO WERYFIKACJI)
- [x] Widok `Apps.xaml` — test dymny okna w 5.1 (jasny) i 7.6.7 (ciemny)
- [x] Testy Pester, PSScriptAnalyzer — 0 uwag, 1913/1913 w 5.1 i 7.6.7
- [x] Działa dla `localhost` i dla komputera zdalnego (kontekst wykonania `-Context`, błąd połączenia obsłużony na poziomie instancji) — localhost: odczyt, wyszukiwanie, podgląd; zdalnie: sonda na prawdziwym komputerze (Appx i rejestr działają, winget niedostępny dla konta połączenia — D-050) i testy z mockiem transportu (administrator, zerwanie połączenia)
- [x] Dokumentacja zaktualizowana, commit `FAZA 12: ...`

## Kryteria ukończenia
Pakietów systemowych nie da się usunąć z GUI; parsowanie `winget` działa przy polskim systemie.

## Do weryfikacji na Windows 11
`winget` na realnym systemie, odinstalowanie aplikacji testowej. Dodatkowo test na komputerze zdalnym użytkownika (obsługa zdalna, utrata połączenia).

## Wyniki
Zakończona 2026-10-29.

- **Baza przed zmianami** (każda wersja w nowym procesie): 5.1.26100.9711 — 0 uwag, 1803/1803; 7.6.7 (`C:\Program Files\PowerShell\7\pwsh.exe`) — 0 uwag, 1803/1803.
- **Wynik końcowy:** `.\tests\Invoke-Checks.ps1`, każda wersja w nowym procesie: 5.1.26100.9711 — 0 uwag, 1913/1913; 7.6.7 — 0 uwag, 1913/1913 (+110: `Apps.Tests.ps1` 34, `AppsView.Tests.ps1` 6, testy XAML, kodowania i eksportu nowych plików i funkcji). `PowerView.Tests.ps1` — moduł bez widoku: `Tweaks` zamiast `Apps`.
- **Decyzje użytkownika (2026-10-29):** odinstalowanie przez winget + Appx (bez `UninstallString`), zgoda na umowy pakietu i źródła = potwierdzenie w oknie, środowiska uruchomieniowe tylko z ostrzeżeniem, sonda zdalna. **ADR:** D-050.
- **`MWP.Apps` 0.12.0:** `Get-MwpInstalledApp`, `Resolve-MwpInstalledApp`, `Select-MwpInstalledApp`, `Get-MwpWingetInfo`, `Get-MwpWingetPackage`, `Find-MwpWingetPackage`, `Resolve-MwpWingetPackage`, `ConvertFrom-MwpWingetOutput`, `Join-MwpAppWinget`, `Install-MwpWingetPackage`, `Update-MwpWingetPackage`, `Uninstall-MwpApp`; prywatne: bloki `Get-MwpAppsScript` (Inventory, Winget, RemoveAppx), `Invoke-MwpWinget`, `ConvertTo-MwpWingetCall`, `Get-MwpWingetErrorText`, `Get-MwpAppProtection`, `Get-MwpAppTarget`, `Test-MwpWingetId`, `Test-MwpAppsAdmin`, `Get-MwpAppsTargetConfig`. Kontrakt: `Read`, `Change`, `Destructive`, `Undo`, `RemoteTarget`; tryby `Embedded`, `SeparateWindow`. `MWP.Core` 0.12.0: lista ochronna — kategorie `App` i `AppxPackage` (22 wpisy).
- **Okno (`MWP.UI`):** `Views/Apps.xaml`, `Initialize-`/`Update-MwpAppsView`, `Invoke-MwpAppsViewAction`, `Start-MwpUiAppsRefresh`; bez WPF: `Get-MwpAppsRow`, `Get-MwpAppsActionState`, `Get-MwpAppsDetail`, `Get-MwpAppsViewOption`; wpis w `Get-MwpModuleViewCatalog`; `Get-MwpUiChangeScript` ustawia procent postępu kroków.
- **Sprawdzone na tym komputerze (tylko odczyt i podgląd, bez administratora, 5.1 i 7.6.7):** inwentarz 682 pozycje, 77 pakietów rozpoznanych przez winget, 25 aktualizacji, łączenie (Git → `Git.Git`), wyszukiwanie, podgląd instalacji, aktualizacji i odinstalowania (Git: `winget uninstall --id ARP\Machine\X64\Git_is1`, Aparat: `Remove-AppxPackage`), odmowy dla Edge, Microsoft Store i App Installer.
- **Sonda na komputerze zdalnym (2026-10-29, użytkownik):** opis w D-050 — Appx i rejestr działają, winget niedostępny dla konta połączenia (App Installer niezarejestrowany, `WindowsApps` — odmowa dostępu).
- **Znalezione i poprawione w trakcie:** winget pisze w stronie OEM (polskie znaki); stopka „<additional entries truncated…>” psuła kolumny; literały `0x8A15…` w PowerShellu są ujemne bez `L`; `@()` na `List[object]` w tabeli (5.1); `Get-ChildItem -LiteralPath -Exclude` w 5.1 ignoruje wykluczenie (test); inwentarz 7,6 s → 3,3 s (rejestr przez .NET, ochrona bez bloków skryptu w pętli); `Get-StartApps` bez `-ErrorAction`.
- **Ograniczenia:** prawdziwa instalacja, aktualizacja i odinstalowanie nie były wykonane (zasada 5 `CLAUDE.md`) — tylko atrapa winget, odczyt i podgląd; winget zdalnie niedostępny na komputerze użytkownika (D-050); łączenie z winget po nazwie i wersji (różne nazwy = brak Id źródła i brak cofnięcia); rozmiar tylko z `EstimatedSize`, Appx bez rozmiaru i daty; brak widgetu Dashboardu (nie było w zakresie).

### Korekta D-051 — winget na komputerze zdalnym (2026-10-29)
Korekta po FAZIE 12 (status fazy bez zmian). Wymaganie użytkownika: moduł Aplikacje działa tak samo dla `localhost` i komputera zdalnego. Rozwiązanie (D-051): na komputerze zdalnym winget uruchamiany przez jednorazowe zadania harmonogramu — jako SYSTEM (programy komputera) i w sesji zalogowanego użytkownika (jego programy), bez zapisywania haseł; lokalnie bez zmian, a programy innego zalogowanego profilu — też przez zadanie w jego sesji. `MWP.Apps` 0.12.1.

- **Sonda (2 rundy, za zgodą użytkownika, skrypt poza repozytorium):** SYSTEM uruchamia `winget.exe` z pakietu App Installer wszystkich użytkowników (`--version`, `list --source winget`, `search --source winget` — kod 0); bez `--source` — `0x8A150046` (umowa `msstore`); SYSTEM nie widzi programów użytkownika; zadanie `Interactive` zalogowanego użytkownika działa w jego sesji (alias winget, jego programy); narzut zadania ok. 3 s; po sprzątaniu brak zadań, plików i procesów `winget`. Szczegóły w D-051.
- **Decyzje użytkownika:** zgoda na umowy źródeł przy odinstalowaniu programu spoza repozytorium winget (w podglądzie); odmowa dla programu profilu niezalogowanego właściciela; parytet także lokalnie dla innych profili; instalacja zdalnie domyślnie jako SYSTEM (`--scope machine`) z wyborem użytkownika.
- **Kod:** `Invoke-MwpWinget` + `Get-MwpWingetRunPlan` (Direct / System / User), blok `WingetTask`, `Get-MwpWingetTaskScript`, `ConvertTo-MwpAppsPackedText`, `Get-MwpAppsHostSid`, `Get-MwpWingetRunText`, `Test-MwpWingetRunAccess`; `-UserSid` w `Get-MwpWingetPackage` (+ `-UserOnly`), `Install-`, `Update-MwpWingetPackage`, `Uninstall-MwpApp`; `Resolve-MwpWingetPackage` czyta zestaw przebiegów (`RunAs`, `UserSid`, `Warnings`); kod `0x8A150046` po polsku. Widok: tekst kontekstu winget, profil użytkownika także na `localhost`, kolumna „Kontekst” aktualizacji, „Zainstaluj dla”, bez ograniczenia „winget niedostępny” dla komputera zdalnego.
- **Testy:** symulator harmonogramu w `Apps.Tests.ps1` (zadanie wykonuje skrypt ze swojego polecenia), nowe przypadki: plan uruchomienia, lista/aktualizacje/wyszukiwanie zdalnie, profil zalogowanego i niezalogowanego użytkownika, odinstalowanie `Machine` (SYSTEM) i `User` (sesja właściciela), instalacja (SYSTEM i użytkownik), aktualizacja, limit czasu i przerwanie (8), zadanie bez wyniku, osierocone zadania i pliki, brak administratora (12), brak App Installer, polskie znaki (OEM) przez plik wyniku, Id `ARP\…` ze spacją, brak sekretów i długość polecenia, bloki bez składni 7.x; utrata połączenia (7) na nowym bloku. `AppsView.Tests.ps1`: program innego profilu, kontekst pakietów, profile i miejsce instalacji. Wynik: 5.1.26100.9711 — 0 uwag, 1943/1943; 7.6.7 — 0 uwag, 1943/1943 (+30: `Apps.Tests.ps1` 34 → 47, `AppsView.Tests.ps1` 6 → 7, testy kodowania i eksportu nowych plików).

**Tabela parytetu** (wynik testu automatycznego; „rzeczywisty” — sprawdzone na prawdziwym komputerze, „do weryfikacji” — lista niżej):

| Operacja | `localhost` — test | `localhost` — rzeczywisty | Komputer zdalny — test | Komputer zdalny — rzeczywisty |
|---|---|---|---|---|
| Lista programów (rejestr, Appx) | OK | OK (FAZA 12) | OK | OK (sonda D-050) |
| Lista pakietów winget | OK (Direct) | OK (FAZA 12) | OK (SYSTEM) | OK (sonda D-051: 14 pakietów) |
| Pakiety profilu zalogowanego użytkownika | OK (zadanie w jego sesji, administrator) | do weryfikacji | OK (zadanie Interactive) | OK (sonda D-051) |
| Profil niezalogowanego użytkownika | odmowa (jak zdalnie) | do weryfikacji | OK — ostrzeżenie (lista), odmowa (zmiany) | do weryfikacji |
| Aktualizacje (lista) | OK | OK (FAZA 12: 25) | OK | do weryfikacji |
| Aktualizacja pojedyncza / zaznaczonych | OK | do weryfikacji | OK (SYSTEM; pakiet profilu w sesji użytkownika) | do weryfikacji |
| Wyszukiwanie | OK | OK (FAZA 12) | OK | OK (sonda D-051) |
| Instalacja | OK (konto aplikacji) | do weryfikacji | OK (SYSTEM `--scope machine`; użytkownik `--scope user`) | do weryfikacji |
| Odinstalowanie programu komputera | OK (`--source winget` / umowy) | do weryfikacji | OK (SYSTEM) | do weryfikacji |
| Odinstalowanie programu profilu | OK (konto aplikacji; inny profil — jego sesja) | do weryfikacji | OK (sesja właściciela) | do weryfikacji |
| Odinstalowanie pakietu Appx | OK (konto aplikacji) | do weryfikacji | OK (konto połączenia — dług) | do weryfikacji |
| Cofnięcie (instalacja ↔ odinstalowanie) | OK | do weryfikacji | OK (z `UserSid`) | do weryfikacji |
| Brak administratora | OK (inny profil — odmowa) | — | OK (odczyt winget i zmiany — odmowa) | do weryfikacji |
| Limit czasu / anulowanie | proces winget zabijany po limicie; anulowanie go nie zatrzymuje (dług D-050) | — | OK (zadanie i drzewo procesów zatrzymane, zadanie usunięte) | do weryfikacji |

**Do weryfikacji na Windows 11 — korekta D-051 (komputer zdalny, konto administratora; każda zmiana za zgodą):**
1. Aplikacje → Aktualizacje na komputerze zdalnym: lista zgodna z `winget upgrade` uruchomionym tam lokalnie (pakiety komputera; z wybranym zalogowanym profilem — także jego, kolumna „Kontekst”).
2. Instalacja aplikacji testowej (`7zip.7zip`) „dla komputera” (SYSTEM): w podglądzie kontekst i `--scope machine`; po instalacji program w Ustawieniach komputera zdalnego; wpis cofnięcia.
3. Odinstalowanie tej aplikacji (wpisanie nazwy komputera) i „Cofnij wybraną…” — ponowna instalacja.
4. Program profilu zalogowanego użytkownika (np. instalacja `7zip.7zip` „dla użytkownika” i odinstalowanie): działa w jego sesji; po wylogowaniu — odmowa z komunikatem „nie jest zalogowany”.
5. Program spoza repozytorium winget (komputer testowy): podgląd zapowiada zgodę na umowy `msstore`; po odinstalowaniu sprawdzić, że działa.
6. Anulowanie długiej operacji (np. aktualizacja dużego pakietu) z paska stanu: zadanie `\MyWindowsPower\MWP-Winget-*` znika, proces `winget` i instalator kończą się (`Get-Process winget`).
7. Po wszystkim: `Get-ScheduledTask -TaskPath '\MyWindowsPower\'` bez `MWP-Winget-*`, `%ProgramData%\MyWindowsPower\winget` bez plików; uprawnienia katalogu (`Get-Acl`) — właściciel Administratorzy, tylko SYSTEM i Administratorzy (+ `user-<SID>` dla użytkownika).
8. Utrata połączenia w trakcie (np. odłączenie sieci podczas instalacji): błąd tylko tej instancji; po ponownym połączeniu stan odczytany z listy; osierocone zadanie usunięte przy następnym wywołaniu (albo samo po terminie).
9. localhost: programy innego zalogowanego użytkownika (szybkie przełączanie użytkowników) — lista i odinstalowanie w jego sesji przy aplikacji uruchomionej jako administrator.
## Do weryfikacji na Windows 11 — lista dla użytkownika
1. CLI: `(Get-MwpInstalledApp).Data.Apps | Select-MwpInstalledApp | Format-Table Name, Version, Publisher, ScopeText` — porównać z Ustawienia → Aplikacje → Zainstalowane aplikacje.
2. Aplikacje → Aktualizacje: „Sprawdź aktualizacje” zgodne z `winget upgrade`; zaktualizować jeden mały pakiet (monit UAC, wersja po odświeżeniu, wpis w Dzienniku operacji z wersjami).
3. Wyszukaj i zainstaluj: małą aplikację testową (np. `7zip.7zip`) — okno z informacją o umowach, po instalacji „Zainstalowany”, wpis cofnięcia.
4. Odinstaluj tę aplikację z zakładki Zainstalowane (okno ostrzegawcze) — znika z listy i z Ustawień; w logu nazwa, wersja, wydawca; „Cofnij wybraną…” instaluje ją ponownie.
5. Pakiet Appx (np. aplikacja ze Sklepu, której nie potrzebujesz) — odinstalowanie przez `Remove-AppxPackage`, brak wpisu cofnięcia.
6. Edge, Microsoft Store, Instalator aplikacji, VCLibs — przycisk „Odinstaluj…” wyłączony z powodem; `Uninstall-MwpApp -AppId … -Confirm:$false` w CLI też odmawia.
7. Komputer zdalny (Połącz, konto administratora): lista z rejestru i Appx, wybór profilu zalogowanego użytkownika, odinstalowanie pakietu Appx z wpisaniem nazwy komputera; utrata połączenia — błąd tylko tej instancji. (Komunikat „winget niedostępny” nieaktualny po korekcie D-051 — winget zdalnie: lista „Korekta D-051” wyżej).
8. Język: system z innym językiem wyświetlania winget (np. polski pakiet językowy) — lista i aktualizacje nadal się wczytują.

## Następna faza
FAZA 13 — Prywatność i tweaki. Prompt: `docs/04_PROMPTY/PROMPT_FAZA_13.md`.
