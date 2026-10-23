# PLAN FAZ — mywindowspower

> Pełny plan projektu. Szczegółowa checklista każdej fazy jest w `docs/03_FAZY/`, a gotowy prompt startowy w `docs/04_PROMPTY/`.
> Status faz prowadzi `docs/02_STAN/STAN_PROJEKTU.md` (to ono jest źródłem prawdy o postępie, nie ten plik).

## Zasady podziału

- Jedna faza = jedna nowa rozmowa w Claude Code = jeden commit (`FAZA N: opis`).
- Faza kończy się, gdy spełnione są jej kryteria ukończenia, a dokumentacja jest zaktualizowana.
- Fazy wykonujemy w kolejności. Wyjątek wymaga wpisu w `DECYZJE.md`.
- Fazy 6–19 to w dużej mierze niezależne obszary funkcjonalne (po FAZACH 2–5) i można zmienić ich kolejność lub pominąć wybrane; FAZA 19 wymaga co najmniej jednego gotowego modułu.
- Aplikacja zarządza komputerem lokalnym i zdalnymi (D-019): każda faza obszaru obejmuje obsługę komputera docelowego.
- Numeracja została zmieniona w D-020 (2026-10-23): nowa FAZA 3, dotychczasowe FAZY 3–13 → 4–14, nowe FAZY 15–19, testy → 20, wydanie → 21. FAZY 0–2 bez zmian.

## Mapa faz

| FAZA | Nazwa | Efekt końcowy | Zależy od |
|---|---|---|---|
| **FAZA 0** | Fundament | Repo git, `CLAUDE.md`, pamięć projektu w `docs/`, plan i prompty | — |
| **FAZA 1** | Szkielet techniczny | Launcher, struktura kodu, manifesty modułów, Pester, PSScriptAnalyzer | 0 |
| **FAZA 2** | Rdzeń i bezpieczeństwo zmian | `MWP.Core`: logi, konfiguracja, dry-run, cofanie, punkt przywracania, elewacja, kontrakt modułu | 1 |
| **FAZA 3** | Komputery docelowe i połączenia zdalne | `MWP.Remote`: komputery docelowe (`localhost` i zdalne), kontekst wykonania, instancje, połączenia; instalacja i odinstalowanie modułów z paczek w `MWP.Core` | 1, 2 |
| **FAZA 4** | Szkielet GUI i host modułów | Okno WPF, host modułów, instancje, nawigacja, motyw jasny/ciemny, wykonywanie w tle, widok „Moduły" | 1, 2, 3 |
| **FAZA 5** | Dashboard | Informacje o systemie i sprzęcie, Dashboard z widgetami dla wielu komputerów | 2, 3, 4 |
| **FAZA 6** | Zasilanie | Plany zasilania i ustawienia energii | 2, 3, 4 |
| **FAZA 7** | Usługi Windows | Przegląd i zarządzanie usługami | 2, 3, 4 |
| **FAZA 8** | Autostart i harmonogram | Programy startowe, zadania harmonogramu | 2, 3, 4 |
| **FAZA 9** | Czyszczenie dysku | Skan i czyszczenie plików tymczasowych | 2, 3, 4 |
| **FAZA 10** | Windows Update | Podgląd i zarządzanie aktualizacjami | 2, 3, 4 |
| **FAZA 11** | Sieć | Adaptery, DNS, resety | 2, 3, 4 |
| **FAZA 12** | Aplikacje i winget | Lista, aktualizacja, odinstalowanie | 2, 3, 4 |
| **FAZA 13** | Prywatność i tweaki | Katalog tweaków rejestru z cofaniem | 2, 3, 4 |
| **FAZA 14** | Defender i firewall | Status, skan, reguły zapory | 2, 3, 4 |
| **FAZA 15** | Dyski i woluminy | Dyski i woluminy (odczyt), widget dla Dashboardu | 2, 3, 4 (widget: 5) |
| **FAZA 16** | Procesy i zasoby | Procesy i zasoby, zakończenie procesu z listą ochronną | 2, 3, 4 (widget: 5) |
| **FAZA 17** | Użytkownicy i grupy lokalne | Lokalni użytkownicy i grupy, lista ochronna kont | 2, 3, 4 |
| **FAZA 18** | RDP, sesje i zrzuty ekranu | Sesje, RDP, shadowing (do zbadania), zrzuty ekranu (do zbadania) | 2, 3, 4 (widget: 5) |
| **FAZA 19** | Samodzielne uruchamianie i CLI | `apprun`, tryby Standalone i CLI | 2, 3, 4 i co najmniej jeden moduł |
| **FAZA 20** | Testy i hardening | Przegląd całości, testy architektoniczne, zgodność 5.1/7, localhost/zdalnie, poprawki | 5–19 |
| **FAZA 21** | Dokumentacja i wydanie | README, instrukcja, tag `v1.0.0` | 20 |

## Opisy faz

### FAZA 0 — Fundament
Cel: przygotować proces pracy. Zakres: `git init`, remote, `.gitignore`, `CLAUDE.md`, `README.md`, struktura `docs/`, `CONTEXT`, `ARCHITEKTURA`, `DECYZJE`, plan faz, pliki stanu, procedura, prompty dla wszystkich faz. Kryterium: komplet dokumentacji i pierwszy commit.

### FAZA 1 — Szkielet techniczny
Cel: działający, pusty projekt, który da się uruchomić i sprawdzić. Zakres: `Start-MyWindowsPower.ps1` (wykrycie wersji PS, STA, import modułów), pusty szkielet modułów z manifestami `.psd1`, konfiguracja Pester i PSScriptAnalyzer (w tym reguły zgodności z 5.1), skrypt `tests/Invoke-Checks.ps1`, szablon ustawień. Kryterium: launcher startuje, testy i analiza przechodzą.

### FAZA 2 — Rdzeń i bezpieczeństwo zmian
Cel: wspólny fundament bezpiecznych zmian systemowych i kontrakt modułu, przygotowane na wiele komputerów. Zakres: logowanie, konfiguracja, wykrywanie administratora i elewacja, punkt przywracania, rejestr cofnięć, standardowy obiekt wyniku, wzorzec funkcji z `-WhatIf`, lista ochronna, pole komputera w API rdzenia, kontrakt modułu (manifest, odkrywanie, walidacja), ADR (model wykonywania i współbieżności, kontrakt i cykl życia, konfiguracja/logowanie/uprawnienia). Kryterium: testy Pester z mockami, wzorzec gotowy do użycia przez kolejne moduły.

### FAZA 3 — Komputery docelowe i połączenia zdalne
Cel: zarządzanie komputerem lokalnym (`localhost`) i zdalnymi (D-019). Zakres: moduł `MWP.Remote`, rejestr komputerów docelowych, kontekst wykonania, model instancji modułu (definicja ≠ instancja), połączenia i `Invoke-MwpOnTarget`, ADR o transporcie i uwierzytelnianiu, izolacja błędów. Paczki modułów w `MWP.Core` (D-031): `Test-MwpModulePackage`, `Install-MwpModulePackage`, `Uninstall-MwpModulePackage`, odkrywanie w `src/Modules` i `src/Modules/Installed`, import zainstalowanych modułów przez launcher, rejestr instalacji w `settings.local.json`, zamykanie instancji przy odinstalowaniu. Kryterium: ta sama funkcja obszaru działa dla `localhost` i komputera zdalnego, a awaria jednego komputera nie wpływa na inne instancje; moduł z poprawnej paczki instaluje się i odinstalowuje, a błędna paczka niczego nie zostawia.

### FAZA 4 — Szkielet GUI i host modułów
Cel: okno aplikacji bez funkcji obszarów, będące hostem modułów. Zakres: `MainWindow.xaml`, nawigacja (Pulpit, obszary, Ustawienia, O programie), motywy Light/Dark z wykrywaniem motywu systemu, pasek stanu, pomocnik wykonywania w tle (runspace), panel logu, zarządzanie instancjami modułów, wybór komputera docelowego, tryby Embedded i Separate window, widoki-zaślepki, widok „Moduły" (lista wbudowanych i zainstalowanych, instalacja z pliku `.mwpmod` z oknem potwierdzenia, odinstalowanie z potwierdzeniem nazwą modułu, D-031), katalog danych w Ustawieniach (edycja `dataPath`, „Przenieś dane”, moduły z paczek w katalogu danych, D-032). Kryterium: okno startuje w PS 5.1 i 7, motyw się przełącza, GUI się nie zawiesza, dwie instancje działają niezależnie dla dwóch komputerów.

### FAZA 5 — Dashboard
Cel: pierwszy realny widok, bezpieczny (tylko odczyt), oraz Dashboard jako kompozycja widgetów dla wielu komputerów. Zakres: moduł `MWP.Dashboard`, kafelki z danymi o systemie i sprzęcie, kontrakt widgetu, układ i konfiguracja widgetów (komputer i parametry per widget), odświeżanie w tle, izolacja widgetów, zapis i odtworzenie konfiguracji, eksport, usuwanie widgetów odinstalowanego modułu (D-031). Kryterium: dane poprawne na Windows 11, awaria jednego widgetu lub komputera nie zatrzymuje reszty.

### FAZA 6 — Zasilanie
Cel: zarządzanie planami i ustawieniami energii. Zakres: lista i przełączanie planów, tworzenie planu wysokiej wydajności, hibernacja, szybkie uruchamianie, ustawienia czasów, raport baterii. Kryterium: zmiany z podglądem, logiem i cofaniem. Zdalnie przez kontekst wykonania.

### FAZA 7 — Usługi Windows
Cel: bezpieczny przegląd i zmiana usług. Zakres: lista z filtrami, start/stop/restart, typ uruchomienia, lista ochronna, zapis stanu i cofanie, eksport profilu. Kryterium: usługi krytyczne nie do wyłączenia z GUI. Zdalnie przez kontekst wykonania; widget statusu usług.

### FAZA 8 — Autostart i harmonogram
Cel: kontrola tego, co uruchamia się z systemem. Zakres: Run/RunOnce, folder Startup, zadania harmonogramu, włącz/wyłącz, informacja o podpisie wydawcy, cofanie. Kryterium: wyłączenie i przywrócenie pozycji działa. Zdalnie pozycje systemowe; profil użytkownika do zbadania.

### FAZA 9 — Czyszczenie dysku
Cel: bezpieczne zwalnianie miejsca. Zakres: kategorie plików tymczasowych, wyliczenie rozmiaru, podgląd domyślny, czyszczenie z potwierdzeniem, analiza magazynu składników. Kryterium: nigdy nie dotyka plików użytkownika. Zdalnie tylko lokalizacje systemowe.

### FAZA 10 — Windows Update
Cel: kontrola nad aktualizacjami. Zakres: oczekujące aktualizacje i historia przez COM, stan usług, pauza, reset komponentów. Kryterium: bez zewnętrznych modułów. Zdalnie z ograniczeniami COM do zbadania.

### FAZA 11 — Sieć
Cel: diagnostyka i konfiguracja sieci. Zakres: adaptery, konfiguracja IP, DNS z presetami i cofaniem, flush DNS, resety, testy łączności. Kryterium: zmiana DNS jest odwracalna. Zdalnie z ochroną przed utratą łączności.

### FAZA 12 — Aplikacje i winget
Cel: porządek w zainstalowanych programach. Zakres: lista z rejestru i pakietów Appx, `winget` (lista, aktualizacje, odinstalowanie), lista ochronna aplikacji systemowych. Kryterium: odinstalowanie tylko z potwierdzeniem. Zdalnie z ograniczeniami `winget` do zbadania.

### FAZA 13 — Prywatność i tweaki
Cel: katalog ustawień rejestru. Zakres: tweaki zdefiniowane danymi (klucz, wartość, ryzyko, wymaga restartu), odczyt stanu, zastosuj/cofnij, profile, punkt przywracania przed grupą. Kryterium: każdy tweak ma cofnięcie. Zdalnie `HKLM`; `HKCU` tylko po jawnym wyborze profilu.

### FAZA 14 — Defender i firewall
Cel: przegląd i bezpieczne akcje ochronne. Zakres: status Defendera, aktualizacja sygnatur, skan, wyłączenia, profile i reguły zapory. Kryterium: GUI nie wyłącza ochrony bez ostrzeżenia. Zdalnie z ostrzeżeniem przy regułach zapory.

### FAZA 15 — Dyski i woluminy
Cel: przegląd dysków i woluminów (moduł `MWP.Disks`, D-020). Zakres: dyski, partycje, woluminy, pojemność, wolne miejsce, typ nośnika, stan zdrowia, widget „Wykorzystanie dysków", obsługa komputera zdalnego. Kryterium: dane zgodne z Zarządzaniem dyskami, tylko odczyt.

### FAZA 16 — Procesy i zasoby
Cel: procesy i zasoby (moduł `MWP.Processes`, D-020). Zakres: lista procesów, monitorowanie CPU/pamięci/dysku/sieci, zakończenie procesu z potwierdzeniem i listą ochronną, widget zużycia zasobów, obsługa komputera zdalnego. Kryterium: procesów krytycznych nie da się zakończyć z GUI.

### FAZA 17 — Użytkownicy i grupy lokalne
Cel: użytkownicy i grupy lokalne (moduł `MWP.Accounts`, D-020). Zakres: lista użytkowników i grup, włączanie/wyłączanie kont, członkostwo w grupach, lista ochronna kont, obsługa komputera zdalnego. Kryterium: nie da się odciąć sobie dostępu administracyjnego z GUI; zmiany są odwracalne.

### FAZA 18 — RDP, sesje i zrzuty ekranu
Cel: RDP, sesje i zrzuty ekranu (moduły `MWP.Rdp` i `MWP.Screenshot`, D-020). Zakres: lista sesji, stan RDP, rozłączenie i wylogowanie, uruchomienie `mstsc`, shadowing (do zbadania), zrzut ekranu komputera docelowego (ograniczenie sesji nieinteraktywnej do zbadania), widget statusu RDP. Kryterium: sesje widoczne i bezpiecznie zarządzane na komputerze lokalnym i zdalnym; ograniczenia jawnie opisane.

### FAZA 19 — Samodzielne uruchamianie i CLI
Cel: samodzielne uruchamianie modułów i tryb CLI (D-020). Zakres: `Invoke-MwpModule` z aliasem `apprun` (wyszukuje moduł wbudowany i zainstalowany, D-031), weryfikacja modułu i zależności, tryby Standalone i CLI, zachowanie walidacji, autoryzacji i logowania. Kryterium: co najmniej jeden moduł działa samodzielnie dla `localhost` i komputera zdalnego z tą samą logiką co w GUI.

### FAZA 20 — Testy i hardening
Cel: jakość całości. Zakres: pełny przegląd, testy architektoniczne (12 scenariuszy), macierz `localhost` / komputer zdalny, przegląd bezpieczeństwa zdalnego zarządzania, zgodność 5.1/7, pokrycie testami, PSScriptAnalyzer bez uwag, test ręczny na Windows 11, przegląd bezpieczeństwa, dług techniczny. Kryterium: lista usterek pusta lub świadomie odroczona.

### FAZA 21 — Dokumentacja i wydanie
Cel: zamknięcie projektu. Zakres: README (w tym komputery zdalne), instrukcja użytkownika, uruchamianie (ExecutionPolicy, `Unblock-File`), opcjonalny skrót, tag `v1.0.0`. Kryterium: obcy użytkownik uruchomi projekt wg README.
