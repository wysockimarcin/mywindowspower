# FAZA 7 — Usługi Windows

**Status:** ZAKOŃCZONA (ręczna weryfikacja prawdziwych zmian i komputera zdalnego — lista niżej)

## Cel
Bezpieczny przegląd i zmiana usług Windows.

## Zależności
FAZY 2, 3 i 4 zakończone.

## Zakres
- Moduł `MWP.Services`: lista usług (`Get-Service` + `Win32_Service` dla typu uruchomienia, konta, ścieżki, opisu), filtry (stan, typ, wyszukiwanie), start/stop/restart.
- Zmiana typu uruchomienia: Automatic, Automatic (Delayed Start), Manual, Disabled; rozróżnienie opóźnionego startu (np. `sc.exe config ... start= delayed-auto`).
- **Lista ochronna** usług krytycznych (w osobnym pliku danych): GUI nie pozwala ich wyłączyć ani zatrzymać; lista możliwa do przeglądu.
- Wykrywanie zależności przed zatrzymaniem (usługi zależne) i ostrzeżenie.
- Zapis stanu przed zmianą i cofanie (rejestr cofnięć z FAZY 2).
- Eksport i import profilu usług (JSON) z podglądem różnic.
- Widok `Services.xaml`; operacje w tle.
- Testy Pester z mockami.
- Obsługa komputera docelowego (D-019): odczyt i zmiany usług przez kontekst wykonania; lista ochronna obowiązuje identycznie dla komputera zdalnego; nazwy usług walidowane przed użyciem w poleceniach. Widget „Status usług" dla Dashboardu.

## Poza zakresem
Edycja ścieżek binarnych usług, usuwanie usług.

## Checklista
- [x] Lista i filtry — `Get-MwpService` (`Win32_Service` + `Win32_DependentService`, opóźniony start z `DelayedAutoStart`), `Select-MwpService` (stan, typ, tekst, tylko chronione), `Resolve-MwpServiceList`; w widoku filtrowanie ostatniego odczytu bez ponownego odczytu
- [x] Start/stop/restart z obsługą zależności — `Start-MwpService`, `Stop-MwpService`, `Restart-MwpService`: działające usługi zależne (bezpośrednie i pośrednie) wymienione w podglądzie i zatrzymywane najpierw; po błędzie ponowne uruchomienie zatrzymanych
- [x] Zmiana typu uruchomienia (w tym opóźniony start) — `Set-MwpServiceStartupType` (`sc.exe config … start= auto|delayed-auto|demand|disabled`, argumenty jako tablica, ponowny odczyt typu)
- [x] Lista ochronna usług krytycznych — `MWP.Core\Data\protected-items.json` (33 usługi) + lokalne `protected.local.json` (tylko dodaje); blokada w funkcjach logiki i w GUI (przyciski, lista typów), lista do przeglądu w widoku (D-045)
- [x] Cofanie zmian — wpisy cofnięcia: start ↔ stop (z usługami zależnymi), typ uruchomienia; lista „Zmiany usług do cofnięcia” w widoku
- [x] Eksport/import profilu z podglądem różnic — `Export-`, `Read-`, `Compare-`, `Import-MwpServiceProfile`; w widoku siatka różnic i „Zastosuj zaznaczone/wszystkie różnice…”
- [x] Widok `Services.xaml` — `src/UI/Views/Services.xaml` (widok modułu wbudowanego, D-044) + widget Dashboardu `ServiceStatus` „Status usług”
- [x] Testy Pester, PSScriptAnalyzer — `tests/Modules/MWP.Services/Services.Tests.ps1`, `tests/UI/ServicesView.Tests.ps1`, rozszerzone `ProtectedList.Tests.ps1`; wynik niżej
- [x] Działa dla `localhost` i dla komputera zdalnego (kontekst `-Context`, błąd połączenia obsłużony na poziomie instancji) — localhost: test dymny okna i odczyt; zdalnie: testy z mockiem transportu WinRM (lista ochronna, uprawnienia w sesji, utrata połączenia, cofnięcie wymaga kontekstu); **prawdziwy komputer zdalny — DO WERYFIKACJI NA WINDOWS 11**
- [x] Dokumentacja zaktualizowana, commit `FAZA 7: ...`

## Kryteria ukończenia
Usług z listy ochronnej nie da się wyłączyć z GUI; każda zmiana jest w logu i odwracalna.

Spełnione: usługa chroniona ma w GUI wyłączone „Zatrzymaj” i „Uruchom ponownie”, a lista typów ma tylko typy automatyczne (sprawdzone w teście dymnym okna dla WinRM); funkcje logiki odmawiają tych zmian także z CLI i na komputerze zdalnym. Każda zmiana jest w logu; start, stop i typ uruchomienia mają wpis cofnięcia; restart nie zmienia stanu końcowego (bez wpisu, opis w wyniku); uruchomienie usługi chronionej nie ma wpisu cofnięcia, bo jej zatrzymanie jest zablokowane (D-045).

## Do weryfikacji na Windows 11
Zmiana typu uruchomienia i stanu na usłudze testowej (nie krytycznej), z uprawnieniami administratora. Dodatkowo test na komputerze zdalnym użytkownika (obsługa zdalna, utrata połączenia).

## Wyniki
Zakończona 2026-10-27.

- **Baza przed zmianami** (każda wersja w nowym procesie): 5.1.26100.9711 — 0 uwag, 1232/1232; 7.6.7 (`C:\Program Files\PowerShell\7\pwsh.exe`) — 0 uwag, 1232/1232.
- **Wynik końcowy:** `.\tests\Invoke-Checks.ps1`, każda wersja w nowym procesie: 5.1.26100.9711 — 0 uwag PSScriptAnalyzer, 1353/1353; 7.6.7 (`C:\Program Files\PowerShell\7\pwsh.exe`) — 0 uwag, 1353/1353 (baza 1232/1232). Nowe: `tests/Modules/MWP.Services/Services.Tests.ps1`, `tests/UI/ServicesView.Tests.ps1`; rozszerzone `tests/Modules/MWP.Core/ProtectedList.Tests.ps1` (plik lokalny), `tests/UI/PowerView.Tests.ps1` (katalog widoków).
- **Decyzje użytkownika (2026-10-27):** lista ochronna w istniejącym pliku `MWP.Core` + lokalny `protected.local.json` (tylko dodaje); blokada usługi chronionej: wszystko poza uruchomieniem i typem automatycznym; usługi zależne zatrzymywane razem po potwierdzeniu (odmowa, gdy któraś jest chroniona); import profilu zmienia tylko typy uruchomienia. Zapis: D-045.
- **`MWP.Services` 0.7.0:** odczyt (`Get-MwpService [-AsOperation] [-IncludeDependencies]`, `Resolve-MwpServiceList`, `Select-MwpService`, `Get-MwpServiceStartupTypeList`, `Test-MwpServiceName`), zmiany (`Start-`, `Stop-`, `Restart-MwpService`, `Set-MwpServiceStartupType`), profil (`Export-`, `Read-`, `Compare-`, `Import-MwpServiceProfile`), widget (`ConvertTo-MwpServiceStatusView`). Kontrakt: Read, Change, Undo, RemoteTarget; tryby Embedded, SeparateWindow, DashboardWidget; widget `ServiceStatus`.
- **`MWP.Core` 0.7.0:** `Get-MwpProtectedItem` czyta też `protected.local.json` obok `settings.local.json` (pole `Source`), lista ochronna usług rozszerzona z 15 do 33 (m.in. Harmonogram zadań, Klient zasad grupy, Appinfo/UAC, DHCP, DNS, NSI, NLA, lista sieci, Zabezpieczenia Windows); `.gitignore`: `config/protected.local.json`.
- **Sprawdzone na tym komputerze (tylko odczyt i podgląd, 5.1 i 7.6.7):** `Get-MwpService -IncludeDependencies` — 320 usług, 254 zależności, 1,3–1,7 s; `Win32_Service.DelayedAutoStart` dostępne w Windows 11 26300 (24 usługi z opóźnionym startem); podgląd odmów dla WinRM i RpcEptMapper, odmowa z braku administratora; eksport, wczytanie i porównanie profilu (0 różnic). Usługa `Intel(R) TPM Provisioning Service` ujawniła nawiasy w nazwach usług — walidacja dopuszcza `( )`.
- **Okno (`MWP.UI`):** `Views/Services.xaml`, `Initialize-`/`Update-MwpServicesView`, `Invoke-MwpServicesViewAction`, `Start-MwpUiServicesRefresh`, logika prezentacji bez WPF: `Get-MwpServiceViewOption`, `Get-MwpServiceActionState`, `Get-MwpServiceDetail`, `Get-MwpServiceProfileStep`; wpis w `Get-MwpModuleViewCatalog`.
- **Test dymny okna (automatyczny, kopia aplikacji w katalogu tymczasowym, bez zmian systemu)** w 5.1 (motyw jasny) i 7.6.7 (motyw ciemny): widget „Status usług” na Pulpicie (stan „Aktualne”, obserwowane usługi, brakująca usługa), instancja „Usługi — localhost” z odczytem w tle (320 usług), wyszukiwanie, filtry (automatyczne + zatrzymane: 7), WinRM: kłódka, baner ochrony, „Zatrzymaj”/„Uruchom ponownie” wyłączone, typy tylko automatyczne i bieżący; Spooler: wszystkie typy; lista ochronna (33) — kod wyjścia 0; zrzuty obejrzane.
- **Znalezione i poprawione w trakcie:** (1) emoji kłódki nie renderuje się w siatce WPF — ikona z czcionki `Mwp.Font.Icons` (E72E); (2) w testach tablice tablic w `@( … )` bez przecinków spłaszczają się — dane symulatora jako tekst `a|b|c`; (3) skrypty pomocnicze bez BOM psują się w 5.1 na polskich cudzysłowach „ ” (znane z FAZY 6).
- **Ograniczenia:** prawdziwe zmiany usług (start, stop, `sc.exe config`) nie były wykonywane na komputerze deweloperskim (zasada 5 `CLAUDE.md`; sesja bez administratora) — tylko testy z mockiem, odczyt i podgląd; to, że `sc.exe config … start= auto` czyści flagę opóźnionego startu, sprawdza ponowny odczyt (niezgodność = błąd z wpisem cofnięcia), ale wymaga potwierdzenia na prawdziwej usłudze; limit 30 s na usługę bez ustawienia; instancja na komputerze zdalnym — tylko mock transportu.

## Do weryfikacji na Windows 11 — lista dla użytkownika
1. `.\Start-MyWindowsPower.ps1 -Elevate` (5.1 i 7.x) → Usługi → instancja localhost: lista zgodna z przystawką `services.msc` (stan, typ uruchomienia, w tym „Automatyczny (opóźniony start)”), filtry i wyszukiwanie.
2. Usługa testowa niekrytyczna (np. „Bufor wydruku”/Spooler, jeśli drukarka nie jest używana): „Zatrzymaj…” → podgląd → potwierdzenie; „Uruchom”; „Uruchom ponownie…”; cofnięcie zatrzymania z listy „Zmiany usług do cofnięcia”.
3. Usługa z usługami zależnymi (np. „Stacja robocza”/LanmanWorkstation — tylko jeśli można chwilowo stracić udziały sieciowe): podgląd wymienia usługi zależne; po zatrzymaniu i cofnięciu wszystkie wracają.
4. Typ uruchomienia usługi testowej: Ręczny → Automatyczny (opóźniony start) → Automatyczny (sprawdzić w `services.msc`, że opóźnienie znika) → cofnięcie każdej zmiany.
5. Usługa chroniona (np. WinRM): kłódka, baner, wyłączone „Zatrzymaj”/„Uruchom ponownie”, brak typów Ręczny/Wyłączony; `Stop-MwpService -Name WinRM` w konsoli — odmowa.
6. Profil: „Eksportuj profil…”, zmiana typu jednej usługi testowej, „Wczytaj profil i porównaj…” → różnica „Do zmiany”, „Zastosuj zaznaczone…”, cofnięcie; plik `protected.local.json` z własną usługą (np. Spooler) → usługa oznaczona jako chroniona (źródło „lokalna”).
7. Komputer zdalny: instancja Usługi (Połącz, poświadczenia administratora), odczyt, zmiana typu i zatrzymanie usługi testowej z cofnięciem; lista ochronna działa tak samo; odłączenie sieci w trakcie — błąd tylko w tej instancji.
8. Widget „Status usług” na Pulpicie (localhost i komputer zdalny), edycja obserwowanych usług w oknie edycji widgetu.

## Następna faza
FAZA 8 — Autostart i harmonogram. Prompt: `docs/04_PROMPTY/PROMPT_FAZA_8.md`.
