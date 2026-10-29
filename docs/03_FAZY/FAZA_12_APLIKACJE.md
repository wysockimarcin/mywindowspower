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

## Do weryfikacji na Windows 11 — lista dla użytkownika
1. CLI: `(Get-MwpInstalledApp).Data.Apps | Select-MwpInstalledApp | Format-Table Name, Version, Publisher, ScopeText` — porównać z Ustawienia → Aplikacje → Zainstalowane aplikacje.
2. Aplikacje → Aktualizacje: „Sprawdź aktualizacje” zgodne z `winget upgrade`; zaktualizować jeden mały pakiet (monit UAC, wersja po odświeżeniu, wpis w Dzienniku operacji z wersjami).
3. Wyszukaj i zainstaluj: małą aplikację testową (np. `7zip.7zip`) — okno z informacją o umowach, po instalacji „Zainstalowany”, wpis cofnięcia.
4. Odinstaluj tę aplikację z zakładki Zainstalowane (okno ostrzegawcze) — znika z listy i z Ustawień; w logu nazwa, wersja, wydawca; „Cofnij wybraną…” instaluje ją ponownie.
5. Pakiet Appx (np. aplikacja ze Sklepu, której nie potrzebujesz) — odinstalowanie przez `Remove-AppxPackage`, brak wpisu cofnięcia.
6. Edge, Microsoft Store, Instalator aplikacji, VCLibs — przycisk „Odinstaluj…” wyłączony z powodem; `Uninstall-MwpApp -AppId … -Confirm:$false` w CLI też odmawia.
7. Komputer zdalny (Połącz, konto administratora): lista z rejestru i Appx, wybór profilu zalogowanego użytkownika, komunikat „winget niedostępny”, odinstalowanie pakietu Appx z wpisaniem nazwy komputera; utrata połączenia — błąd tylko tej instancji.
8. Język: system z innym językiem wyświetlania winget (np. polski pakiet językowy) — lista i aktualizacje nadal się wczytują.

## Następna faza
FAZA 13 — Prywatność i tweaki. Prompt: `docs/04_PROMPTY/PROMPT_FAZA_13.md`.
