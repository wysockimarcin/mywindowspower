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

## Korekta po FAZIE 12 — zapamiętywanie poświadczeń komputerów zdalnych (2026-10-29)
- Status: ZAKOŃCZONA (korekta, nie nowa faza; status FAZY 12 bez zmian; ręczna weryfikacja z prawdziwym Menedżerem poświadczeń — lista w pliku FAZY 12, sekcja „Korekta D-052”)
- Commit: `FAZA 12 (korekta): zapamiętywanie poświadczeń komputerów zdalnych w Menedżerze poświadczeń Windows (D-052)` — hash do uzupełnienia na starcie FAZY 13
- Start: korekta D-051 zacommitowana (`df4cc15`); baza testów — 5.1.26100.9711: 0 uwag, 1943/1943; 7.6.7: 0 uwag, 1943/1943.
- Powód: pytanie użytkownika — hasło do komputera zdalnego podawane tylko za pierwszym razem; dotąd (D-034) każda instancja i widget pytały osobno, a po restarcie od nowa.
- Decyzje użytkownika (2026-10-29): po odmowie dostępu wpis unieważniony w bieżącym uruchomieniu (bez usuwania); jedno poświadczenie na komputer; zapisane hasło w tle dopiero po pierwszym ręcznym „Połącz”; RDP (FAZA 18) bez współdzielenia wpisu; projekt z przełącznikiem w Ustawieniach zaakceptowany (z ograniczeniem: operacje trwające w chwili zmiany hasła mogą każda raz dostać odmowę).
- Zrobiono: D-052 (status D-034); `MWP.Remote` 0.12.1 — adapter Menedżera poświadczeń (`Initialize-MwpCredentialType`, `Invoke-MwpCredentialApi`, `Get-`/`Set-`/`Remove-`/`Test-MwpStoredCredential`), pamięć procesu (`Get-MwpCredentialCache`, `*-MwpCachedCredential`, `Enter-`/`Exit-MwpCredentialLock`, `Resolve-MwpConnectionCredential`, `Set-MwpConnectionCredential`), `Connect-MwpTarget -UseStoredCredential -SaveCredential`, unieważnienie w `Connect-MwpTarget`, `Invoke-MwpOnTarget`, `Test-MwpTarget`, `Wait-MwpOperation`, brak próby w `Start-MwpOperation` po odrzuceniu, `Remove-MwpTarget` usuwa wpis, nowe funkcje publiczne `Save-`/`Remove-MwpTargetCredential`, `Get-MwpTargetCredentialInfo`, `Clear-MwpTargetCredentialCache`; ustawienie `remoteCredentialStore`. Okno: `Credential.xaml` (pole „Zapamiętaj” domyślnie wyłączone, opis zagrożeń), `TargetEditor.xaml` (wskaźnik, „Zapomnij hasło”), `Settings.xaml` (przełącznik), `Get-MwpUiCredentialPlan`, `Get-MwpTargetCredentialText`, `Resume-MwpUiTargetWidget`, `Get-MwpConnectionStateInfo` z pamięcią procesu, `Connect-MwpUiInstance`/`Connect-MwpUiWidget`/`Invoke-MwpUiTargetTest`/`Remove-MwpUiTarget`/`Close-MwpUiSession`. Dokumentacja: `DECYZJE`, `ARCHITEKTURA` (uwierzytelnianie, ograniczenia, model procesów — wyjątek pamięci poświadczeń, testy architektoniczne, konfiguracja), `CONTEXT`, `SLOWNIK`, `PLAN_FAZ` i plik FAZY 18 (magazyn istnieje, RDP osobno), `FAZA_12_APLIKACJE` (sekcja korekty z listą weryfikacji), `STAN_PROJEKTU`.
- Testy: 5.1.26100.9711 — 0 uwag, 2051/2051; 7.6.7 — 0 uwag, 2051/2051 (+108: nowe CredentialStore.Tests.ps1 (36) i CredentialUi.Tests.ps1 (17), 3 testy architektoniczne, testy kodowania i eksportu nowych plików). Nowe: `tests/Modules/MWP.Remote/CredentialStore.Tests.ps1` (symulator magazynu zamiast P/Invoke i logowania z licznikiem prób: adapter, API, kolejność, zapis tylko za zgodą, blokada ponowień — 1 próba mimo 5 kontekstów, operacje w tle, generacje, izolacja komputerów, Disconnect, przełącznik, współbieżność w runspace'ach, brak wycieku hasła testowego), `tests/UI/CredentialUi.Tests.ps1`, 3 testy architektoniczne; mocki warstwy P/Invoke i czyszczenie pamięci procesu w dotychczasowych plikach testów z `MWP.Remote`.
- Niezrobione / odroczone: weryfikacja z prawdziwym komputerem zdalnym i Menedżerem poświadczeń (ręcznie); RDP w FAZIE 18; ograniczenia opisane w D-052 i w `STAN_PROJEKTU` (dług techniczny).
- Decyzje: D-052 (D-034 — zapis poświadczeń zastąpiony).
- Następna faza: FAZA 13 — Prywatność i tweaki

## Korekta po FAZIE 12 — winget na komputerze zdalnym (2026-10-29)
- Status: ZAKOŃCZONA (korekta, nie nowa faza; status FAZY 12 bez zmian; ręczna weryfikacja na komputerze zdalnym — lista w pliku FAZY 12, sekcja „Korekta D-051”)
- Commit: `FAZA 12 (korekta): winget na komputerze zdalnym przez zadanie harmonogramu — parytet z localhost (D-051)` — hash do uzupełnienia na starcie FAZY 13
- Start: FAZA 12 zamknięta (`6436379`), prompt korekty w `56b346b`; baza testów — 5.1.26100.9711: 0 uwag, 1913/1913; 7.6.7: 0 uwag, 1913/1913.
- Powód: wymaganie użytkownika — moduł Aplikacje ma działać tak samo dla `localhost` i komputera zdalnego; w sesji WinRM winget nie działa (D-050).
- Sonda (za zgodą użytkownika, 2 rundy, skrypt poza repozytorium, zadania i pliki usunięte i sprawdzone): SYSTEM uruchamia `winget.exe` z pakietu App Installer wszystkich użytkowników (`--version`, `list --source winget`, `search` — kod 0), bez `--source` — `0x8A150046` (umowa `msstore`), SYSTEM nie widzi programów użytkownika; zadanie `Interactive` zalogowanego użytkownika działa w jego sesji (jego programy); narzut ok. 3 s; zatrzymanie zadania działa.
- Decyzje użytkownika (2026-10-29): zgoda na umowy źródeł przy odinstalowaniu programu spoza repozytorium winget (w podglądzie); profil niezalogowanego właściciela — odmowa przed podglądem; parytet także lokalnie dla innych profili; instalacja zdalnie domyślnie jako SYSTEM (`--scope machine`) z wyborem użytkownika.
- Zrobiono: D-051; `MWP.Apps` 0.12.1 — `Invoke-MwpWinget` z planem uruchomienia (`Direct`/`System`/`User`), blok `WingetTask` (jednorazowe zadania `\MyWindowsPower\MWP-Winget-<GUID>`, stały skrypt `Get-MwpWingetTaskScript` z blokiem `Winget` w żądaniu, wynik JSON w `%ProgramData%\MyWindowsPower\winget` z ACL, limit, przerwanie z zatrzymaniem drzewa procesów, sprzątanie osieroconych zadań i plików), `-UserSid` w liście, instalacji, aktualizacji i odinstalowaniu, zestaw przebiegów w `Resolve-MwpWingetPackage`, kontekst w podglądzie, logu i wyniku, `0x8A150046` po polsku. Widok: kontekst winget, profil także na `localhost`, kolumna „Kontekst” aktualizacji, „Zainstaluj dla”. Dokumentacja: `DECYZJE` (D-051, status D-050), `ARCHITEKTURA` (Aplikacje, ograniczenia zdalne, testy architektoniczne), `FAZA_12_APLIKACJE` (korekta z tabelą parytetu i listą weryfikacji), `STAN_PROJEKTU`.
- Testy: 5.1.26100.9711 — 0 uwag, 1943/1943; 7.6.7 — 0 uwag, 1943/1943 (+30: `Apps.Tests.ps1` 34 → 47, `AppsView.Tests.ps1` 6 → 7, testy kodowania i eksportu nowych plików). Symulator harmonogramu w `Apps.Tests.ps1` (zadanie wykonuje skrypt ze swojego polecenia; tryby zawieszenia i awarii), nowe przypadki zdalne i lokalne (lista, aktualizacje, wyszukiwanie, profile, odinstalowanie SYSTEM i w sesji właściciela, instalacja, aktualizacja, limit i przerwanie, osierocone zadania, brak administratora, brak App Installer, OEM, Id ze spacją, sekrety i długość polecenia); `AppsView.Tests.ps1` — kontekst i profile.
- Niezrobione / odroczone: prawdziwe zmiany na komputerze zdalnym (weryfikacja ręczna); pakiety Appx zalogowanego użytkownika zdalnie (dług); anulowanie lokalnego `Direct` nadal nie zatrzymuje procesu winget (dług D-050).
- Decyzje: D-051 (D-050 — zakres zdalny zastąpiony).
- Uwaga: pliki nieśledzone sprzed fazy (`docs/04_PROMPTY/PROMPT_KOREKTA_D031.md`, `docs/scripts/`) pozostawione bez zmian i poza commitem.
- Następna faza: FAZA 13 — Prywatność i tweaki

## FAZA 12 — Aplikacje i winget (2026-10-29)
- Status: ZAKOŃCZONA (ręczna weryfikacja prawdziwej instalacji, aktualizacji i odinstalowania oraz komputera zdalnego — lista w pliku fazy)
- Commit: `FAZA 12: aplikacje i winget — programy z rejestru i Appx, winget z parsowaniem niezależnym od języka, aktualizacje, wyszukiwanie i instalacja, odinstalowanie z listą ochronną i widok modułu` — hash do uzupełnienia na starcie FAZY 13
- Start: uzupełniono hash FAZY 11 (`114d45e`); baza testów — 5.1.26100.9711: 0 uwag, 1803/1803; 7.6.7: 0 uwag, 1803/1803.
- Decyzje użytkownika (2026-10-29): odinstalowanie przez winget i Appx (bez `UninstallString`); potwierdzenie instalacji/aktualizacji = zgoda na umowy pakietu i źródła; środowiska uruchomieniowe tylko z ostrzeżeniem; sonda zdalna wykonana przez użytkownika.
- Zrobiono:
  - `MWP.Apps` 0.12.0: inwentarz rejestru i Appx z filtrami i sortowaniem, winget (wykrycie, lista, aktualizacje, wyszukiwanie) z parserem tabel niezależnym od języka i szerokości kolumn, instalacja i aktualizacja pojedyncza, odinstalowanie z podglądem, listą ochronną, logiem i cofnięciem przez ponowną instalację.
  - `MWP.Core` 0.12.0: kategorie listy ochronnej `App` i `AppxPackage`.
  - Okno: `Views/Apps.xaml` (Zainstalowane, Aktualizacje, Wyszukaj i zainstaluj, cofnięcia), logika prezentacji bez WPF, wpis w katalogu widoków, procent postępu kroków zmian.
  - Dokumentacja: `DECYZJE` (D-050), `ARCHITEKTURA` (sekcja „Aplikacje”, struktura, rdzeń, ograniczenia zdalne, testy architektoniczne), `PLAN_FAZ`, `FAZA_12_APLIKACJE`, `STAN_PROJEKTU`, `README`.
- Testy: 5.1.26100.9711 — 0 uwag, 1913/1913; 7.6.7 — 0 uwag, 1913/1913. Nowe: `tests/Modules/MWP.Apps/Apps.Tests.ps1` (34; atrapa winget.cmd w stronie OEM, atrapy inwentarza i Appx, ścieżka zdalna z mockiem transportu), `tests/UI/AppsView.Tests.ps1` (6); `PowerView.Tests.ps1` — moduł bez widoku: `Tweaks`. Test dymny okna w 5.1 i 7.6.7.
- Poprawione w trakcie: strona kodowa OEM wyjścia winget, stopki psujące kolumny, ujemne literały HRESULT, `@()` na `List[object]` w 5.1, wydajność inwentarza (7,6 s → 3,3 s), 4 uwagi PSScriptAnalyzer w testach.
- Niezrobione / odroczone: prawdziwe zmiany (weryfikacja ręczna); winget zdalnie dla konta bez App Installer (nowy ADR, kandydat FAZA 20); widget Dashboardu — poza zakresem.
- Decyzje: D-050.
- Do weryfikacji na Windows 11: lista 8 punktów w `docs/03_FAZY/FAZA_12_APLIKACJE.md`.
- Uwaga: pliki nieśledzone sprzed fazy (`docs/04_PROMPTY/PROMPT_KOREKTA_D031.md`, `docs/scripts/`) pozostawione bez zmian i poza commitem. Przy próbnym `winget list` na starcie fazy raz przekazano `--accept-source-agreements` (msstore nadal zgłasza brak zgody — nic się nie zapisało).
- Następna faza: FAZA 13 — Prywatność i tweaki

## FAZA 11 — Sieć (2026-10-28)
- Status: ZAKOŃCZONA (ręczna weryfikacja prawdziwych zmian jako administrator, automatycznego wycofania i komputera zdalnego — lista w pliku fazy)
- Commit: `FAZA 11: sieć — adaptery i konfiguracja IP, DNS z presetami, cofaniem i automatycznym wycofaniem przez zadanie na komputerze docelowym, DHCP, resety, testy łączności i widok modułu` — hash `114d45e` (uzupełniony na starcie FAZY 12)
- Start: uzupełniono hash FAZY 10 (`5b6daa4`); baza testów — 5.1.26100.9711: 0 uwag, 1698/1698; 7.6.7: 0 uwag, 1698/1698.
- Decyzje użytkownika (2026-10-28): automatyczne wycofanie przez jednorazowe zadanie harmonogramu na komputerze docelowym; limit 120 s; lokalnie i zdalnie; resety Winsock/IP dozwolone zdalnie z wpisaniem nazwy komputera.
- Zrobiono:
  - `MWP.Network` 0.11.0: `Get-MwpNetworkStatus`/`Resolve-MwpNetworkStatus`, `Get-MwpDnsPreset`, `Set-MwpDnsServer`, `Disable-`/`Enable-MwpNetAdapter`, `Approve-MwpNetworkChange`, `Clear-MwpDnsCache`, `Update-MwpDhcpLease`, `Reset-MwpNetworkStack`, `Test-MwpNetworkConnection`/`Resolve-MwpNetworkTest`; bloki komputera docelowego zgodne z 5.1, blok wycofania wbudowany w zadanie (stan w Base64, bez plików), odmowa zmiany adaptera z niezatwierdzoną zmianą, adapter połączenia rozpoznawany z połączeń WinRM.
  - `MWP.Core` 0.11.0 (wersja hosta, bez zmian funkcji).
  - Okno: `Views/Network.xaml`, `Initialize-`/`Update-MwpNetworkView`, `Invoke-MwpNetworkViewAction`, `Start-MwpUiNetworkRefresh`, logika prezentacji bez WPF (`Get-MwpNetworkRow`, `Get-MwpNetworkActionState`, `Get-MwpNetworkDetail`, `Get-MwpNetworkViewOption`), wpis w `Get-MwpModuleViewCatalog`.
  - Dokumentacja: `DECYZJE` (D-049), `ARCHITEKTURA` (sekcja „Sieć”, struktura, rdzeń, ograniczenia zdalne, testy architektoniczne), `PLAN_FAZ`, `FAZA_11_SIEC`, `STAN_PROJEKTU`, `README`.
- Testy: 5.1.26100.9711 — 0 uwag, 1803/1803; 7.6.7 — 0 uwag, 1803/1803 (baza 1698/1698). Nowe: `tests/Modules/MWP.Network/Network.Tests.ps1` (29; symulator sieci, rejestru i harmonogramu, wykonanie bloku wycofania z zadania, atrapa `netsh`, ping 127.0.0.1, lokalny `TcpListener`, ścieżka zdalna z mockiem transportu i zerwaniem połączenia), `tests/UI/NetworkView.Tests.ps1` (6). Zmieniony: `tests/UI/PowerView.Tests.ps1` (przykład modułu bez widoku: Apps zamiast Network). Test dymny okna w 5.1 i 7.6.7.
- Poprawione w trakcie: zagnieżdżona tablica statycznych DNS w bloku zmiany, skróty IPv4 akceptowane przez `IPAddress.TryParse`, przepełnienie `[int]` kodu `RenewDHCPLease`, 4 uwagi PSScriptAnalyzer.
- Niezrobione / odroczone: prawdziwe zmiany i zadanie wycofania na Windows 11 (weryfikacja ręczna); statyczne IP i zmiana profilu sieci (dług techniczny); widget Dashboardu — poza zakresem.
- Decyzje: D-049.
- Do weryfikacji na Windows 11: lista 8 punktów w `docs/03_FAZY/FAZA_11_SIEC.md`.
- Uwaga: pliki nieśledzone sprzed fazy (`docs/04_PROMPTY/PROMPT_KOREKTA_D031.md`, `docs/scripts/`) pozostawione bez zmian i poza commitem.
- Następna faza: FAZA 12 — Aplikacje i winget

## FAZA 10 — Windows Update (2026-10-28)
- Status: ZAKOŃCZONA (ręczna weryfikacja zmian jako administrator, instalacji i komputera zdalnego — lista w pliku fazy)
- Commit: `FAZA 10: Windows Update — stan i usługi, wyszukiwanie i historia przez COM, pauza jak Ustawienia z cofaniem, reset składników z kopiami folderów, instalacja lokalna i widok modułu` — hash `5b6daa4` (uzupełniony na starcie FAZY 11)
- Start: uzupełniono hash FAZY 9 (`9ceddba`); baza testów — 5.1.26100.9711: 0 uwag, 1572/1572; 7.6.7: 0 uwag, 1572/1572.
- Decyzje użytkownika (2026-10-28): instalacja lokalnie przez COM z potwierdzeniem (bez automatycznego restartu); instalacja zdalna odroczona z wpisem; pauza jak Ustawienia Windows 11, 1–5 tygodni.
- Zrobiono:
  - `MWP.Update` 0.10.0: `Get-MwpUpdateStatus`/`Resolve-MwpUpdateStatus` (usługi, restart, daty, pauza, zasady, kopie), `Find-MwpUpdate`/`Resolve-MwpUpdateSearch` (COM, stałe kryteria, instalowalność z powodem, HRESULT z opisem), `Get-MwpUpdateHistory`/`Resolve-MwpUpdateHistory`, `Suspend-MwpUpdate`/`Resume-MwpUpdate`/`Restore-MwpUpdatePause` (wartości `UX\Settings`, administrator, ponowny odczyt, cofnięcie), `Reset-MwpUpdateComponent`/`Get-MwpUpdateResetStep`/`Restore-MwpUpdateComponent` (Destrukcyjna, podgląd kroków, kopie folderów, wycofanie przy błędzie, dowiązania odrzucane, cofnięcie), `Install-MwpUpdate` (tylko lokalnie, administrator, po jednej aktualizacji z postępem i anulowaniem, pomijanie interakcji i licencji, bez restartu), `Open-MwpUpdatePage`, `Format-MwpUpdateSize`; wszystko z `-Context`, log z nazwą komputera.
  - `MWP.Core` 0.10.0 (wersja hosta, bez zmian funkcji).
  - Okno: `Views/Update.xaml`, `Initialize-`/`Update-MwpUpdateView`, `Invoke-MwpUpdateViewAction`, `Start-MwpUiUpdateRefresh`, `Start-MwpUiUpdateInstall`, logika prezentacji bez WPF (`Get-MwpUpdateRow`, `Get-MwpUpdateActionState`, `Get-MwpUpdateDetail`, `Get-MwpUpdateViewOption`, `Get-MwpUiUpdateScript`), wpis w katalogu widoków; `Invoke-MwpUiInstanceChange` z opcjonalnym `-ConfirmText`.
  - Dokumentacja: `DECYZJE` (D-048), `ARCHITEKTURA` (sekcja „Windows Update”, struktura, rdzeń, ograniczenia zdalne, testy architektoniczne), `FAZA_10_WINDOWS_UPDATE`, `STAN_PROJEKTU`, `README`.
- Testy: 5.1.26100.9711 — 0 uwag, 1698/1698; 7.6.7 — 0 uwag, 1698/1698 (baza 1572/1572). Nowe: `tests/Modules/MWP.Update/Update.Tests.ps1` (37; symulator COM Windows Update Agent, rejestr w `TestRegistry`, foldery w `TestDrive`, ścieżka zdalna z mockiem transportu), `tests/UI/UpdateView.Tests.ps1` (7); `PowerView.Tests.ps1` — moduł bez widoku: `Network` zamiast `Update`. Test dymny okna w 5.1 (jasny, z prawdziwym wyszukiwaniem) i 7.6.7 (ciemny) — kod wyjścia 0, brak zmian.
- Poprawione w trakcie: daty z `ConvertFrom-Json` w 7.x w zapisie pauzy, przełącznik `-RestartRequired`, rekurencja domyślnego mocka `New-Object` w zakresie pliku (Pester 6), uwagi PSScriptAnalyzer (`Set-ItemProperty -Type`, nazwy w liczbie mnogiej, `ShouldProcess` w funkcjach publicznych).
- Niezrobione / odroczone: instalacja na komputerze zdalnym (D-048, dług techniczny; kandydat FAZA 20); retencja kopii folderów z resetu (FAZA 20); widget Dashboardu — poza zakresem.
- Decyzje: D-048.
- Do weryfikacji na Windows 11: lista 8 punktów w `docs/03_FAZY/FAZA_10_WINDOWS_UPDATE.md` (pauza w Ustawieniach, reset i cofnięcie jako administrator, instalacja, komputer zdalny).
- Uwaga: pliki nieśledzone sprzed fazy (`docs/04_PROMPTY/PROMPT_KOREKTA_D031.md`, `docs/scripts/`) pozostawione bez zmian i poza commitem.
- Następna faza: FAZA 11 — Sieć

## FAZA 9 — Czyszczenie dysku (2026-10-28)
- Status: ZAKOŃCZONA (ręczna weryfikacja prawdziwego czyszczenia, uprawnień administratora, DISM i komputera zdalnego — lista w pliku fazy)
- Commit: `9ceddba` `FAZA 9: czyszczenie dysku — kategorie w pliku danych, skan, usuwanie z potwierdzeniem i raportem, ochrona przed dowiązaniami i ścieżkami spoza kategorii, analiza DISM i widok modułu`
- Start: uzupełniono hash FAZY 8 (`320362d`); baza testów — 5.1.26100.9711: 0 uwag, 1462/1462; 7.6.7: 0 uwag, 1462/1462.
- Zrobiono:
  - `MWP.Cleanup` 0.9.0: kategorie jako dane (`Data/cleanup-categories.json`, 8 kategorii z zakresu fazy, `Get-MwpCleanupCategory` z białą listą ścieżek), skan tylko do odczytu (`Measure-MwpCleanupCategory`), usuwanie (`Clear-MwpCleanupCategory`: Destrukcyjna, `ConfirmImpact High`, `-WhatIf`, skan przed potwierdzeniem, log początku i wyniku, bez wpisu cofnięcia), raport (`ConvertTo-MwpCleanupReport`), `Format-MwpCleanupSize`, analiza DISM (`Get-MwpComponentStoreAnalysis`, `Resolve-MwpComponentStoreAnalysis`; tylko analiza, `/English`); trzy linie obrony (walidacja definicji, `Test-MwpCleanupRoot`, blok `Process`: dowiązania, kanoniczność, lokalizacje chronione, pliki w użyciu, puste katalogi bez rekurencji); profile: zdalnie tylko po jawnym wyborze; postęp i anulowanie przez tabelę `-Progress`; wszystko z `-Context`.
  - `MWP.Core` 0.9.0 (wersja hosta, bez zmian funkcji).
  - Okno: `Views/Cleanup.xaml`, `Initialize-`/`Update-MwpCleanupView`, `Invoke-MwpCleanupViewAction`, `Start-MwpUiCleanupScan`, `Start-MwpUiCleanup`, `Start-MwpUiComponentStoreAnalysis`, logika prezentacji bez WPF (`Get-MwpCleanupRow`, `Get-MwpCleanupActionState`, `Get-MwpCleanupDetail`, `Get-MwpUiCleanupScript`), wpis w katalogu widoków.
  - Dokumentacja: `DECYZJE` (D-047), `ARCHITEKTURA` (sekcja „Czyszczenie dysku”, struktura, rdzeń, testy architektoniczne), `FAZA_9_CZYSZCZENIE`, `STAN_PROJEKTU`, `README`.
- Testy: 5.1.26100.9711 — 0 uwag, 1572/1572; 7.6.7 — 0 uwag, 1572/1572 (baza 1462/1462). Nowe: `tests/Modules/MWP.Cleanup/Cleanup.Tests.ps1` (46; wyłącznie katalogi w `TestDrive`, w tym kryterium „żadna operacja nie wychodzi poza zdefiniowane ścieżki”, junction, plik w użyciu, ścieżka zdalna z mockiem transportu, DISM bez uruchamiania), `tests/UI/CleanupView.Tests.ps1` (6); `PowerView.Tests.ps1` — moduł bez widoku: `Update` zamiast `Cleanup`. Test dymny okna w 5.1 (jasny) i 7.6.7 (ciemny) — kod wyjścia 0, okno potwierdzenia anulowane, brak zmian.
- Poprawione w trakcie: wydajność skanu w 5.1 (41 s → 7 s dla 9,4 tys. plików), brak pliku definicji = skan z błędem, pola opcjonalne JSON w trybie ścisłym, uwagi PSScriptAnalyzer (`$profile`, parametr w zagnieżdżonym bloku, nazwy funkcji pomocniczych testów).
- Niezrobione / odroczone: czyszczenie magazynu składników (`/StartComponentCleanup`) — świadomie poza aplikacją (D-047, dług techniczny); zatrzymywanie Windows Update przed czyszczeniem pamięci pobierania — ewentualnie FAZA 10; eksport raportu i widget — poza zakresem.
- Decyzje: D-047.
- Do weryfikacji na Windows 11: lista 8 punktów w `docs/03_FAZY/FAZA_9_CZYSZCZENIE.md` (kryterium na prawdziwym dysku, Kosz, kategorie systemowe jako administrator, anulowanie, DISM, komputer zdalny).
- Uwaga: pliki nieśledzone sprzed fazy (`docs/04_PROMPTY/PROMPT_KOREKTA_D031.md`, `docs/scripts/`) pozostawione bez zmian i poza commitem.
- Następna faza: FAZA 10 — Windows Update

## FAZA 8 — Autostart i harmonogram (2026-10-27)
- Status: ZAKOŃCZONA (ręczna weryfikacja prawdziwych zmian, zgodności z Menedżerem zadań i komputera zdalnego — lista w pliku fazy)
- Commit: `320362d` `FAZA 8: autostart i harmonogram — StartupApproved jak Menedżer zadań, zadania z eksportem XML, podpis wydawcy, lista ochronna zadań i widok modułu`
- Start: uzupełniono hashe FAZY 7 (`9871a0f`, korekta `8e0f73a`); baza testów — 5.1.26100.9711: 0 uwag, 1353/1353; 7.6.7: 0 uwag, 1353/1353.
- Decyzje użytkownika (2026-10-27): pozycje profilu użytkownika na komputerze zdalnym — profile zalogowanych użytkowników (bez ładowania `NTUSER.DAT`); lista ochronna zadań — usuwanie `\Microsoft\*` zablokowane, zadania krytyczne bez wyłączania; autostart bez listy ochronnej.
- Zrobiono:
  - `MWP.Startup` 0.8.0: `Get-MwpStartupItem` (Run/RunOnce z `WOW6432Node`, foldery Startup z celem skrótów, `StartupApproved` z datą wyłączenia, podpis i wydawca), `Resolve-`/`Select-MwpStartupItem`, `Set-MwpStartupItemState` (format Menedżera zadań, wpis zostaje, RunOnce tylko odczyt), `Get-MwpScheduledTask`, `Resolve-`/`Select-MwpScheduledTask`, `Set-MwpScheduledTaskState`, `Start-MwpScheduledTask`, `Remove-MwpScheduledTask` (eksport XML przed usunięciem), `Restore-MwpScheduledTask` (cofnięcie usunięcia), `Get-MwpSignatureRisk`, `Test-MwpScheduledTaskName`; wszystko z `-Context`, `-WhatIf`, uprawnieniami na komputerze docelowym, logiem i cofnięciem.
  - `MWP.Core` 0.8.0: lista ochronna — kategorie `Task` (10 wzorców zadań krytycznych) i `TaskRemoval` (`\Microsoft\*`).
  - Okno: `Views/Startup.xaml` (zakładki Autostart i Harmonogram), `Initialize-`/`Update-MwpStartupView`, `Invoke-MwpStartupViewAction`, `Start-MwpUiStartupRefresh`, logika prezentacji bez WPF (`Get-MwpStartupViewOption`, `Get-MwpStartupActionState`, `Get-MwpStartupDetail`), styl `TabControl`/`TabItem` w `Styles.xaml`.
  - Dokumentacja: `DECYZJE` (D-046), `ARCHITEKTURA` (sekcja „Autostart i harmonogram”, lista ochronna, rdzeń, struktura, testy architektoniczne), `FAZA_8_AUTOSTART_HARMONOGRAM`, `STAN_PROJEKTU`, `README`.
- Testy: 5.1.26100.9711 — 0 uwag, 1462/1462; 7.6.7 — 0 uwag, 1462/1462 (baza 1353/1353). Nowe: `tests/Modules/MWP.Startup/Startup.Tests.ps1` (symulator rejestru, folderów, skrótów, podpisów, zalogowanych użytkowników i harmonogramu; fikcyjne nazwy `MwpTest*`; ścieżka zdalna z mockiem transportu), `tests/UI/StartupView.Tests.ps1`; `PowerView.Tests.ps1` — moduł bez widoku: `Cleanup` zamiast `Startup`. Test dymny okna w 5.1 (jasny) i 7.6.7 (ciemny) — kod wyjścia 0.
- Znalezione i poprawione w trakcie: `.bat` (`UnknownError` bez certyfikatu) to plik niepodpisany, nie „podpis nieprawidłowy”; zadania z akcją COM — „nie dotyczy”; Pester 6: brak przejścia do oryginału przy niedopasowanym filtrze mocka, `-RemoveParameterType InputObject` dla poleceń CDXML, w trybie ścisłym mock widzi tylko przekazane parametry, `<Nazwa>` w nazwie testu to zmienna; skrypt testu dymnego uruchamiany z PowerShell 7 dziedziczy `PSModulePath` 7.x (5.1 nie znajduje `Import-PowerShellDataFile`).
- Niezrobione / odroczone: prawdziwe zmiany i komputer zdalny — weryfikacja ręczna; retencja eksportów XML, widget autostartu — dług techniczny w `STAN_PROJEKTU.md`.
- Decyzje: D-046
- Do weryfikacji na Windows 11: lista 8 punktów w `FAZA_8_AUTOSTART_HARMONOGRAM.md` (kryterium: wyłączenie i przywrócenie pozycji widoczne w Menedżerze zadań).
- Następna faza: FAZA 9 — Czyszczenie dysku
## FAZA 7 — Usługi Windows (2026-10-27)
- Status: ZAKOŃCZONA (ręczna weryfikacja prawdziwych zmian usług i komputera zdalnego — lista w pliku fazy)
- Commit: `9871a0f` `FAZA 7: usługi Windows — lista, start/stop/restart z zależnymi, typ uruchomienia, lista ochronna, profil i widok modułu`; korekta `8e0f73a` `FAZA 7 (korekta): przyciski akcji usług nad tabelą usług` (hashe uzupełnione na starcie FAZY 8)
- Start: uzupełniono hash FAZY 6 (`5087694`); baza testów — 5.1.26100.9711: 0 uwag, 1232/1232; 7.6.7: 0 uwag, 1232/1232.
- Decyzje użytkownika (2026-10-27): lista ochronna w istniejącym pliku `MWP.Core` + lokalny `protected.local.json` (tylko dodaje); usługa chroniona — dozwolone tylko uruchomienie i typ automatyczny; usługi zależne zatrzymywane razem po potwierdzeniu; import profilu zmienia tylko typy uruchomienia.
- Zrobiono:
  - `MWP.Services` 0.7.0: `Get-MwpService` (`Win32_Service`, opóźniony start, `Win32_DependentService`, `-AsOperation`), `Resolve-MwpServiceList`, `Select-MwpService`, `Start-`/`Stop-`/`Restart-MwpService` (usługi zależne od najdalszej, ponowne uruchomienie po błędzie, cofnięcie zatrzymania z zależnymi), `Set-MwpServiceStartupType` (`sc.exe config … start=`, ponowny odczyt, kody błędów po polsku), profil (`Export-`, `Read-`, `Compare-`, `Import-MwpServiceProfile`), `Test-MwpServiceName`, `Get-MwpServiceStartupTypeList`, widget `ServiceStatus` (`ConvertTo-MwpServiceStatusView`); wszystkie zmiany z `-Context`, `-WhatIf`, sprawdzeniem administratora na komputerze docelowym, logiem i cofnięciem.
  - `MWP.Core` 0.7.0: `Get-MwpProtectedItem` czyta też `protected.local.json` (pole `Source`); lista ochronna usług 15 → 33; `.gitignore`: `config/protected.local.json`.
  - Okno: `Views/Services.xaml` (lista z filtrami, szczegóły z zależnościami, przyciski z blokadą usług chronionych, profil z siatką różnic, lista ochronna do przeglądu, cofnięcia), `Initialize-`/`Update-MwpServicesView`, `Invoke-MwpServicesViewAction`, `Start-MwpUiServicesRefresh`, logika prezentacji bez WPF (`Get-MwpServiceViewOption`, `Get-MwpServiceActionState`, `Get-MwpServiceDetail`, `Get-MwpServiceProfileStep`).
  - Dokumentacja: `DECYZJE` (D-045), `ARCHITEKTURA` (sekcja „Usługi”, lista ochronna, rdzeń, struktura, testy architektoniczne), `FAZA_7_USLUGI`, `STAN_PROJEKTU`, `README`.
- Testy: 5.1.26100.9711 — 0 uwag, 1353/1353; 7.6.7 — 0 uwag, 1353/1353 (baza 1232/1232). Nowe: `tests/Modules/MWP.Services/Services.Tests.ps1` (symulator usług, fikcyjne nazwy `MwpTest*`, ścieżka zdalna z mockiem transportu), `tests/UI/ServicesView.Tests.ps1`; rozszerzone `ProtectedList.Tests.ps1`, `PowerView.Tests.ps1`. Test dymny okna w 5.1 (jasny) i 7.6.7 (ciemny) — kod wyjścia 0.
- Znalezione i poprawione w trakcie: nawiasy w nazwach usług (`Intel(R) TPM Provisioning Service`) — walidacja dopuszcza `( )`; emoji kłódki nie renderuje się w siatce WPF — ikona z czcionki aplikacji; Pester w 5.1 nie mockuje `sc.exe` (alias `sc`) — globalna funkcja-symulator; `Remove-Item 'Function:\global:…'` niczego nie usuwa — ścieżka bez kwalifikatora.
- Niezrobione / odroczone: edycja `protected.local.json` w GUI, ustawialny limit czasu operacji na usłudze — dług techniczny w `STAN_PROJEKTU.md`; prawdziwe zmiany usług i komputer zdalny — weryfikacja ręczna.
- Decyzje: D-045
- Do weryfikacji na Windows 11: lista 8 punktów w `FAZA_7_USLUGI.md`.
- Następna faza: FAZA 8 — Autostart i harmonogram

## FAZA 6 — Zasilanie (2026-10-27)
- Status: ZAKOŃCZONA (ręczna weryfikacja prawdziwych zmian, raportów i komputera zdalnego — lista w pliku fazy)
- Commit: `5087694` `FAZA 6: zasilanie — plany, ustawienia AC/DC, hibernacja, raporty powercfg i widok modułu` (hash uzupełniony na starcie FAZY 7)
- Start: uzupełniono hash FAZY 5 (`c4970e3`); baza testów — 5.1.26100.9711: 0 uwag, 1094/1094; 7.6.7: 0 uwag, 1094/1094.
- Zrobiono:
  - `MWP.Power` 0.6.0: odczyt stanu i planów, aktywacja, duplikowanie, „Najwyższa wydajność” (GUID `e9a42b02-…` zweryfikowany w systemie i Microsoft Q&A), zmiana nazwy, usuwanie (odmowa dla aktywnego i wbudowanych, eksport do cofnięcia), import, ustawienia AC/DC (ekran, uśpienie, hibernacja po, pokrywa, przyciski), hibernacja, szybkie uruchamianie, raporty `batteryreport`/`energy` (na komputerze docelowym, zapis i otwarcie lokalnie), widget `PowerStatus`; parsowanie `powercfg` po GUID-ach; `-Context`, `-WhatIf`, log, cofnięcie.
  - `MWP.Core` (dane): lista ochronna — kategoria `PowerPlan`.
  - Okno: katalog widoków modułów wbudowanych (`Get-MwpModuleViewCatalog`), `Views/Power.xaml` w widoku instancji (`ModuleHost`), `Invoke-MwpUiInstanceChange` (podgląd w tle → potwierdzenie → wykonanie w tle), lista zmian do cofnięcia, raporty z wyborem folderu.
  - Dokumentacja: `DECYZJE` (D-044), `ARCHITEKTURA` (sekcja „Zasilanie”, widok modułu wbudowanego, struktura, testy architektoniczne), `FAZA_6_ZASILANIE`, `STAN_PROJEKTU`.
- Testy: 5.1.26100.9711 — 0 uwag, 1232/1232; 7.6.7 — 0 uwag, 1232/1232 (baza 1094/1094). Nowe: `tests/Modules/MWP.Power/Power.Tests.ps1` (symulator `powercfg.exe`, polski i angielski, ścieżka zdalna z mockiem transportu), `tests/UI/PowerView.Tests.ps1`. Test dymny okna w 5.1 i 7.6.7 — kod wyjścia 0.
- Znalezione i poprawione w trakcie: polskie cudzysłowy „ ” jako ograniczniki tekstu w PowerShellu; mock `powercfg.exe` omijany przy bloku wywołanym poza `MWP.Remote` — pierwsza wersja testu zdalnego wywołała prawdziwy `powercfg` (jedna zmiana „Uśpij po (sieć)” z natychmiastowym cofnięciem; stan systemu sprawdzony — zgodny z wyjściowym); `Set-ItemProperty -Type` → `New-ItemProperty -PropertyType`.
- Niezrobione / odroczone: edycja opisu planu; ustawienia planów nieaktywnych w GUI; ogólny panel cofnięć — dług techniczny w `STAN_PROJEKTU.md`; prawdziwe zmiany, raporty i komputer zdalny — weryfikacja ręczna.
- Decyzje: D-044
- Do weryfikacji na Windows 11: lista 8 punktów w `FAZA_6_ZASILANIE.md`.
- Następna faza: FAZA 7 — Usługi Windows

## FAZA 5 — Dashboard (2026-10-27)
- Status: ZAKOŃCZONA (ręczna weryfikacja z prawdziwym komputerem zdalnym i porównanie danych z narzędziami systemowymi — lista w pliku fazy)
- Commit: `c4970e3` `FAZA 5: Dashboard z widgetami, informacje o systemie, eksport raportu i usuwanie widgetów odinstalowanego modułu` (hash uzupełniony na starcie FAZY 6)
- Start: uzupełniono hashe FAZY 4 (`c31a5bf`) i korekty D-042 (`e2db53d`); baza testów — 5.1.26100.9711: 0 uwag, 959/959; 7.6.7: 0 uwag, 959/959.
- Zrobiono:
  - `MWP.Dashboard` 0.5.0: `Get-MwpSystemInfo` (CIM i rejestr na komputerze kontekstu, blok zgodny z 5.1 zwracający JSON; system z wydaniem i UBR, uptime, CPU, RAM, GPU, dyski z typem SSD NVMe/SSD/HDD, płyta i BIOS, bateria, sieć; odporność na braki), `ConvertTo-MwpSystemInfoView`, `ConvertTo-MwpSystemReport`, `Export-MwpSystemReport`; kontrakt z RemoteTarget, DashboardWidget i widgetem `SystemInfo`.
  - Kontrakt widgetu (D-043): opcjonalne pole `Widgets` w `PrivateData.MWP` (walidacja w `Test-MwpModuleDefinition`), `Get-MwpWidgetDefinition`; `MWP.Core` 0.5.0: `Get-`/`Set-MwpDashboardConfiguration`, `Remove-MwpDashboardWidget`, `Repair-MwpDashboardConfiguration`, klucze szablonu `dashboardWidgets`, `dashboardAutoRefresh`, `dashboardMaxParallelRefresh`; `Uninstall-MwpModulePackage` usuwa widgety modułu (D-031).
  - `MWP.Remote` 0.5.0: `Data.ErrorKind` w wyniku błędu operacji.
  - Okno (`MWP.UI`): Pulpit z widgetami nad kartami komputerów i instancjami; widget = własna instancja modułu; stany (ładowanie, aktualne, brak danych, błąd, utrata połączenia, wymaga poświadczeń); odświeżanie ręczne i automatyczne z częstotliwością per widget i limitem równoczesnych odświeżeń; dodawanie, edycja (okno `WidgetEditor`), usuwanie, przesuwanie, „Połącz”, eksport; odinstalowanie modułu usuwa jego widgety; odtworzenie konfiguracji z banerem o pominiętych widgetach; zadania ciche (odświeżenia nie wstrzymują zamknięcia okna).
  - Paczka przykładowa `samples/MWP.Przyklad` 1.1.0 z widgetem „Komputer (przykład)”.
  - Dokumentacja: `DECYZJE` (D-043), `ARCHITEKTURA` (Dashboard i widgety, kontrakt, rdzeń, struktura, testy architektoniczne), `FAZA_5_DASHBOARD`, `STAN_PROJEKTU`, `README`, `samples/README.md`.
- Testy: 5.1.26100.9711 — 0 uwag, 1094/1094; 7.6.7 — 0 uwag, 1094/1094 (baza 959/959). Nowe: `tests/Modules/MWP.Dashboard/SystemInfo.Tests.ps1` (mocki CIM), `tests/Modules/MWP.Core/Dashboard.Tests.ps1`, `tests/UI/Widgets.Tests.ps1` (izolacja widgetów, testy architektoniczne 5–7 i 10); rozszerzone `ModulePackage.Tests.ps1`, `Samples.Tests.ps1`. Automatyczny test dymny okna w 5.1 i 7.6.7 (motyw jasny i ciemny) — kod wyjścia 0.
- Znalezione i poprawione w trakcie: błąd 5.1 z `@(...)` na `List[object]` z `New-Object` w tabeli (lista przez `::new()`, test regresji); pytanie o „zadania w tle” przy zamykaniu w trakcie odświeżania widgetu (zadania ciche); wiązanie `Width` kafelka (`[double]`); `DisplayMemberPath` w stylu ComboBox (`ItemTemplate`).
- Niezrobione / odroczone: przeciąganie widgetów (położenie = kolejność), odświeżanie automatyczne poza widocznym Pulpitem — dług techniczny w `STAN_PROJEKTU.md`; prawdziwy komputer zdalny i zgodność danych z narzędziami systemowymi — weryfikacja ręczna.
- Decyzje: D-043
- Do weryfikacji na Windows 11: lista 8 punktów w `FAZA_5_DASHBOARD.md` (dane, komputer zdalny, utrata połączenia, odtworzenie układu, eksport, paczka przykładowa z widgetem, motyw i DPI).
- Następna faza: FAZA 6 — Zasilanie

## Korekta po FAZIE 4 — dziennik startu aplikacji (2026-10-27)
- Status: ZAKOŃCZONA (korekta, nie nowa faza; status FAZY 4 bez zmian)
- Commit: `e2db53d` `FAZA 4 (korekta): dziennik startu aplikacji (D-042)` (hash uzupełniony na starcie FAZY 5)
- Powód: dane startowe launchera były tylko w konsoli (w wydaniu ukrytej), błędy importu modułów nie trafiały do logu ani do użytkownika, a między „Otwieranie okna aplikacji...” a oknem była kilkusekundowa przerwa bez informacji.
- Zrobiono: D-042; launcher: pomiar etapów startu, wpisy `Startup.Environment` (z ponownym uruchomieniem w STA i powodem — `Warning`), `Startup.Modules` (podsumowanie + szczegóły modułów w `Data`), `Startup.Module` (`Error`) dla każdego wadliwego modułu — przy zdrowym starcie 2 zapisy, trzeci (`Startup.Window`) zapisuje `MWP.UI` po `ContentRendered`; okno komunikatu przy błędzie modułu, `MWP.Core` i okna (bez `-NoGui`); awaryjny `mwp-startup-failure.log` w `%LOCALAPPDATA%\MyWindowsPower\logs` tylko przy nieudanym imporcie `MWP.Core`; okno startowe (`src/UI/Splash.ps1`, `Splash.xaml`) z krokowym paskiem, bo mediana startu > 2000 ms. `MWP.UI`: parametr `-StartupTiming` (`UI.ps1`, `Start-MwpUi`), `Write-MwpUiStartupEntry`, `Close-MwpUiSplash`; komunikat `UI.Start` bez wersji PowerShella; błąd przed pierwszym wyświetleniem okna jako `Startup.Window`. `Write-MwpLog` i `MWP.Core` bez zmian. Dokumentacja: `DECYZJE` (D-042), `ARCHITEKTURA` (launcher, logi, struktura `src/UI`), `FAZA_4_GUI_SZKIELET`, `STAN_PROJEKTU`.
- Pomiar (3 uruchomienia, nowy proces, kopia aplikacji): mediana od startu launchera do okna — 5.1: 8043 ms, 7.6.7: 7473 ms; po wdrożeniu okna startowego 7285 / 7348 ms, okno startowe widoczne po ok. 2,4 s. Zapis dziennika startu: 154–159 ms (5.1), 127–136 ms (7.6.7) — próg 150 ms przekroczony w 5.1, pamięć podręczna ustawień zaproponowana jako osobna korekta.
- Testy: `Launcher.Tests.ps1` przebudowany — każde uruchomienie na kopii aplikacji w `TestDrive` z przekierowanym `LOCALAPPDATA` (nowe: wpisy `Startup.*`, dane w `Data`, brak sekretów, wadliwe moduły z paczki → `Startup.Module` `Error` i kod 1, filtr ostrzeżeń, plik awaryjny przy uszkodzonym `MWP.Core`, ponowne uruchomienie w STA, okno startowe: kodowanie, XAML, brak przy `-NoGui`, motyw); `ModuleContract.Tests.ps1` liczy też moduły w `<katalog danych>\modules` (test padał przy zainstalowanej paczce przykładowej). `.\tests\Invoke-Checks.ps1`, każda wersja w nowym procesie: 5.1.26100.9711 — 0 uwag, 959/959; 7.6.7 — 0 uwag, 959/959 (baza 922/922).
- Niezrobione / odroczone: tryb „działaj bez uszkodzonego modułu” — nie wprowadzony (semantyka bez zmian); pamięć podręczna ustawień i skrócenie startu — propozycje w `STAN_PROJEKTU.md`.
- Decyzje: D-042
- Do weryfikacji na Windows 11 (ręcznie): panel „Dziennik operacji” po starcie, błąd modułu z paczki w oknie komunikatu i w filtrze błędów, okno startowe w motywie ciemnym i przy DPI 125–150%, `-Elevate`.
- Następna faza: FAZA 5 — Dashboard

## FAZA 4 — Szkielet GUI i host modułów (2026-10-26)
- Status: ZAKOŃCZONA (ręczna weryfikacja okna na Windows 11 — lista w pliku fazy)
- Commit: `c31a5bf` `FAZA 4: okno hosta WPF, instancje modułów, motywy, zadania w tle, widok Moduły i katalog danych` (hash uzupełniony na starcie FAZY 5)
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
