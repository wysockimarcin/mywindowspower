# PLAN FAZ — mywindowspower

> Pełny plan projektu. Szczegółowa checklista każdej fazy jest w `docs/03_FAZY/`, a gotowy prompt startowy w `docs/04_PROMPTY/`.
> Status faz prowadzi `docs/02_STAN/STAN_PROJEKTU.md` (to ono jest źródłem prawdy o postępie, nie ten plik).

## Zasady podziału

- Jedna faza = jedna nowa rozmowa w Claude Code = jeden commit (`FAZA N: opis`).
- Faza kończy się, gdy spełnione są jej kryteria ukończenia, a dokumentacja jest zaktualizowana.
- Fazy wykonujemy w kolejności. Wyjątek wymaga wpisu w `DECYZJE.md`.
- Fazy 5–13 to niezależne obszary funkcjonalne i można zmienić ich kolejność lub pominąć wybrane.

## Mapa faz

| FAZA | Nazwa | Efekt końcowy | Zależy od |
|---|---|---|---|
| **FAZA 0** | Fundament | Repo git, `CLAUDE.md`, pamięć projektu w `docs/`, plan i prompty | — |
| **FAZA 1** | Szkielet techniczny | Launcher, struktura kodu, manifesty modułów, Pester, PSScriptAnalyzer | 0 |
| **FAZA 2** | Rdzeń i bezpieczeństwo zmian | `MWP.Core`: logi, konfiguracja, dry-run, cofanie, punkt przywracania, elewacja | 1 |
| **FAZA 3** | Szkielet GUI | Okno WPF, nawigacja, motyw jasny/ciemny, wykonywanie w tle | 1, 2 |
| **FAZA 4** | Dashboard | Informacje o systemie i sprzęcie | 2, 3 |
| **FAZA 5** | Zasilanie | Plany zasilania i ustawienia energii | 2, 3 |
| **FAZA 6** | Usługi Windows | Przegląd i zarządzanie usługami | 2, 3 |
| **FAZA 7** | Autostart i harmonogram | Programy startowe, zadania harmonogramu | 2, 3 |
| **FAZA 8** | Czyszczenie dysku | Skan i czyszczenie plików tymczasowych | 2, 3 |
| **FAZA 9** | Windows Update | Podgląd i zarządzanie aktualizacjami | 2, 3 |
| **FAZA 10** | Sieć | Adaptery, DNS, resety | 2, 3 |
| **FAZA 11** | Aplikacje i winget | Lista, aktualizacja, odinstalowanie | 2, 3 |
| **FAZA 12** | Prywatność i tweaki | Katalog tweaków rejestru z cofaniem | 2, 3 |
| **FAZA 13** | Defender i firewall | Status, skan, reguły zapory | 2, 3 |
| **FAZA 14** | Testy i hardening | Przegląd całości, zgodność 5.1/7, poprawki | 4–13 |
| **FAZA 15** | Dokumentacja i wydanie | README, instrukcja, tag `v1.0.0` | 14 |

## Opisy faz

### FAZA 0 — Fundament
Cel: przygotować proces pracy. Zakres: `git init`, remote, `.gitignore`, `CLAUDE.md`, `README.md`, struktura `docs/`, `CONTEXT`, `ARCHITEKTURA`, `DECYZJE`, plan faz, pliki stanu, procedura, prompty dla wszystkich faz. Kryterium: komplet dokumentacji i pierwszy commit.

### FAZA 1 — Szkielet techniczny
Cel: działający, pusty projekt, który da się uruchomić i sprawdzić. Zakres: `Start-MyWindowsPower.ps1` (wykrycie wersji PS, STA, import modułów), pusty szkielet modułów z manifestami `.psd1`, konfiguracja Pester i PSScriptAnalyzer (w tym reguły zgodności z 5.1), skrypt `tests/Invoke-Checks.ps1`, szablon ustawień. Kryterium: launcher startuje, testy i analiza przechodzą.

### FAZA 2 — Rdzeń i bezpieczeństwo zmian
Cel: wspólny fundament bezpiecznych zmian systemowych. Zakres: logowanie, konfiguracja, wykrywanie administratora i elewacja, punkt przywracania, rejestr cofnięć, standardowy obiekt wyniku, wzorzec funkcji z `-WhatIf`, lista ochronna. Kryterium: testy Pester z mockami, wzorzec gotowy do użycia przez kolejne moduły.

### FAZA 3 — Szkielet GUI
Cel: okno aplikacji bez funkcji obszarów. Zakres: `MainWindow.xaml`, nawigacja, motywy Light/Dark z wykrywaniem motywu systemu, pasek stanu, pomocnik wykonywania w tle (runspace), panel logu, widoki-zaślepki. Kryterium: okno startuje w PS 5.1 i 7, motyw się przełącza, GUI się nie zawiesza.

### FAZA 4 — Dashboard
Cel: pierwszy realny widok, bezpieczny (tylko odczyt). Zakres: moduł `MWP.Dashboard`, kafelki z danymi o systemie i sprzęcie, odświeżanie w tle, eksport. Kryterium: dane poprawne na Windows 11.

### FAZA 5 — Zasilanie
Cel: zarządzanie planami i ustawieniami energii. Zakres: lista i przełączanie planów, tworzenie planu wysokiej wydajności, hibernacja, szybkie uruchamianie, ustawienia czasów, raport baterii. Kryterium: zmiany z podglądem, logiem i cofaniem.

### FAZA 6 — Usługi Windows
Cel: bezpieczny przegląd i zmiana usług. Zakres: lista z filtrami, start/stop/restart, typ uruchomienia, lista ochronna, zapis stanu i cofanie, eksport profilu. Kryterium: usługi krytyczne nie do wyłączenia z GUI.

### FAZA 7 — Autostart i harmonogram
Cel: kontrola tego, co uruchamia się z systemem. Zakres: Run/RunOnce, folder Startup, zadania harmonogramu, włącz/wyłącz, informacja o podpisie wydawcy, cofanie. Kryterium: wyłączenie i przywrócenie pozycji działa.

### FAZA 8 — Czyszczenie dysku
Cel: bezpieczne zwalnianie miejsca. Zakres: kategorie plików tymczasowych, wyliczenie rozmiaru, podgląd domyślny, czyszczenie z potwierdzeniem, analiza magazynu składników. Kryterium: nigdy nie dotyka plików użytkownika.

### FAZA 9 — Windows Update
Cel: kontrola nad aktualizacjami. Zakres: oczekujące aktualizacje i historia przez COM, stan usług, pauza, reset komponentów. Kryterium: bez zewnętrznych modułów.

### FAZA 10 — Sieć
Cel: diagnostyka i konfiguracja sieci. Zakres: adaptery, konfiguracja IP, DNS z presetami i cofaniem, flush DNS, resety, testy łączności. Kryterium: zmiana DNS jest odwracalna.

### FAZA 11 — Aplikacje i winget
Cel: porządek w zainstalowanych programach. Zakres: lista z rejestru i pakietów Appx, `winget` (lista, aktualizacje, odinstalowanie), lista ochronna aplikacji systemowych. Kryterium: odinstalowanie tylko z potwierdzeniem.

### FAZA 12 — Prywatność i tweaki
Cel: katalog ustawień rejestru. Zakres: tweaki zdefiniowane danymi (klucz, wartość, ryzyko, wymaga restartu), odczyt stanu, zastosuj/cofnij, profile, punkt przywracania przed grupą. Kryterium: każdy tweak ma cofnięcie.

### FAZA 13 — Defender i firewall
Cel: przegląd i bezpieczne akcje ochronne. Zakres: status Defendera, aktualizacja sygnatur, skan, wyłączenia, profile i reguły zapory. Kryterium: GUI nie wyłącza ochrony bez ostrzeżenia.

### FAZA 14 — Testy i hardening
Cel: jakość całości. Zakres: pełny przegląd, zgodność 5.1/7, pokrycie testami, PSScriptAnalyzer bez uwag, test ręczny na Windows 11, przegląd bezpieczeństwa, dług techniczny. Kryterium: lista usterek pusta lub świadomie odroczona.

### FAZA 15 — Dokumentacja i wydanie
Cel: zamknięcie projektu. Zakres: README, instrukcja użytkownika, uruchamianie (ExecutionPolicy, `Unblock-File`), opcjonalny skrót, tag `v1.0.0`. Kryterium: obcy użytkownik uruchomi projekt wg README.
