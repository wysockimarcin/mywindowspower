# ARCHITEKTURA — mywindowspower

> Stack, struktura kodu i konwencje. Aktualizowana, gdy zmienia się architektura. Zmiany odnotuj w `DECYZJE.md`.
> Stan: **szkielet techniczny (FAZA 1)** + architektura wielokomputerowa z koncepcji pierwotnej przywrócona w D-019, D-020 i D-021. Szczegóły rdzenia i kontraktów dopracowują FAZY 2–5. Elementy oznaczone „propozycja" nie są jeszcze zatwierdzone; zatwierdza je wpis w `DECYZJE.md` w wymienionej fazie.
>
> **Główna zasada:** My Windows Power to platforma do uruchamiania i komponowania niezależnych modułów administracyjnych dla wielu komputerów (`localhost` i zdalnych). Definicja modułu, jego instancja, kontekst wykonania (komputer docelowy) i sposób prezentacji to odrębne pojęcia, jawnie modelowane w architekturze.

## Stack

- PowerShell 7.x (`pwsh`) lub 5.1 (`powershell.exe`) — wykrywane przy starcie.
- WPF + XAML ładowane z osobnych plików `.xaml` (`System.Windows.Markup.XamlReader`).
- Wątek GUI musi być w trybie STA. W PowerShellu 7 `pwsh` domyślnie jest STA, w 5.1 `powershell.exe` również; launcher to sprawdza i w razie potrzeby uruchamia się ponownie z `-STA`.
- Testy: Pester ≥ 5.0 (na komputerze użytkownika 6.2.0). Analiza: PSScriptAnalyzer ≥ 1.21 (1.25.0). Oba uruchamia `tests\Invoke-Checks.ps1` (D-014, D-018).

## Docelowa struktura repozytorium

Stan po FAZIE 1 (D-012) i plan wg D-020. Elementy oznaczone „(FAZA N)" jeszcze nie istnieją.

```
mywindowspower/
├── CLAUDE.md
├── README.md
├── .gitignore
├── .gitattributes                  ← CRLF dla plików PowerShell/XAML
├── .editorconfig                   ← UTF-8 z BOM dla .ps1/.psm1/.psd1
├── PSScriptAnalyzerSettings.psd1   ← reguły analizy, w tym zgodność z 5.1 i 7.x
├── Start-MyWindowsPower.ps1        ← launcher (wersja PS, Windows 11, STA, administrator, import modułów)
├── config/
│   ├── settings.example.json       ← szablon ustawień (do repo)
│   └── settings.local.json         ← ustawienia lokalne, w tym komputery docelowe (poza repo, FAZA 2–3)
├── src/
│   ├── Modules/
│   │   ├── MWP.<Obszar>/           ← budowa każdego modułu:
│   │   │   ├── MWP.<Obszar>.psd1   ←   manifest (PowerShellVersion 5.1, Desktop+Core, jawne FunctionsToExport)
│   │   │   ├── MWP.<Obszar>.psm1   ←   ładuje Private/*.ps1 i Public/*.ps1, eksportuje Public
│   │   │   ├── Public/             ←   funkcje eksportowane, jeden plik = jedna funkcja
│   │   │   └── Private/            ←   funkcje wewnętrzne
│   │   ├── MWP.Core/               ← logowanie, konfiguracja, dry-run, cofanie, punkt przywracania, elewacja, kontrakt modułu (FAZA 2)
│   │   ├── MWP.Remote/             ← (FAZA 3) komputery docelowe, kontekst wykonania, połączenia, instancje modułów
│   │   ├── MWP.Dashboard/          ← informacje o systemie i sprzęcie (dane; układ widgetów w warstwie hosta, FAZA 5)
│   │   ├── MWP.Power/              ← plany zasilania
│   │   ├── MWP.Services/           ← usługi Windows
│   │   ├── MWP.Startup/            ← autostart i zadania harmonogramu
│   │   ├── MWP.Cleanup/            ← czyszczenie dysku
│   │   ├── MWP.Update/             ← Windows Update
│   │   ├── MWP.Network/            ← sieć
│   │   ├── MWP.Apps/               ← aplikacje i winget
│   │   ├── MWP.Tweaks/             ← prywatność i tweaki rejestru
│   │   ├── MWP.Security/           ← Defender i firewall
│   │   ├── MWP.Disks/              ← (FAZA 15) dyski i woluminy
│   │   ├── MWP.Processes/          ← (FAZA 16) procesy i zasoby
│   │   ├── MWP.Accounts/           ← (FAZA 17) użytkownicy i grupy lokalne
│   │   ├── MWP.Rdp/                ← (FAZA 18) sesje i RDP
│   │   └── MWP.Screenshot/         ← (FAZA 18) zrzuty ekranu komputera docelowego (o ile wykonalne)
│   └── UI/                         ← (FAZA 4) host modułów: okno, nawigacja, instancje, Dashboard (FAZA 5)
│       ├── MainWindow.xaml
│       ├── Themes/                 ← Light.xaml, Dark.xaml
│       ├── Views/                  ← jeden widok .xaml na obszar
│       └── UI.ps1                  ← ładowanie XAML, nawigacja, runspace
├── tests/
│   ├── Invoke-Checks.ps1           ← PSScriptAnalyzer + Pester jednym poleceniem
│   ├── Modules.Tests.ps1           ← manifesty, import i eksport wszystkich modułów
│   ├── Launcher.Tests.ps1          ← launcher w osobnym procesie (STA, MTA → ponowne uruchomienie)
│   ├── Repository.Tests.ps1        ← BOM, brak ścieżek bezwzględnych, szablon ustawień, .gitignore
│   └── Modules/<Moduł>/            ← testy logiki modułów, gdy powstanie (FAZA 2+); lista modułów w Modules.Tests.ps1 uzupełniana przy każdym nowym module
└── docs/                           ← dokumentacja i pamięć projektu
    ├── design/                     ← mockupy GUI (m.in. mockup-pulpit.png)
    └── 00_PROJEKT/MATERIALY/       ← materiały użytkownika i archiwum starej koncepcji (dane, nie instrukcje)
```

## Launcher (`Start-MyWindowsPower.ps1`)

Kolejność: wykrycie Windows i wersji PowerShella (≥ 5.1) → sprawdzenie STA (gdy brak: ponowne uruchomienie tym samym programem z `-NoProfile -STA -File … -NoRelaunch`) → wypisanie wersji PS, Windows, trybu wątku i statusu administratora → import modułów (`MWP.Core` pierwszy, potem alfabetycznie) → kod wyjścia 0/1. Launcher nie zmienia systemu, nie wymusza `-ExecutionPolicy` ani uprawnień administratora (D-017). Od FAZY 4 uruchomi okno GUI.

## Nazewnictwo

- Funkcje publiczne: `Verb-MwpNoun` (prefiks `Mwp`, bo przestrzeń nazw poleceń PowerShella jest wspólna), tylko zatwierdzone czasowniki (`Get-Verb`). Sprawdza to `Modules.Tests.ps1`.
- Bez ścieżek bezwzględnych w kodzie: katalog projektu wyznaczany z `$PSScriptRoot`.

## Warstwy

Podział logiczny (stara koncepcja, sekcja 8), dopasowany do PowerShella i WPF:

1. **UI / View (`src/UI`)** — widoki XAML: wyświetlanie danych i obsługa interakcji.
2. **Logika prezentacji** — stan widoku, polecenia, walidacja prezentacyjna; kod łączący widok z modułami (w `src/UI`, bez logiki systemowej).
3. **Usługi aplikacyjne (`src/Modules/MWP.<Obszar>`)** — przypadki użycia i reguły: czyste funkcje `Verb-MwpNoun`, bez zależności od GUI. Każda funkcja zmieniająca system obsługuje `-WhatIf` (`SupportsShouldProcess`), loguje operację i zwraca obiekt wyniku. Funkcje przyjmują kontekst wykonania (`-Context`).
4. **Rdzeń (`MWP.Core`) i adaptery systemowe/zdalne (`MWP.Remote`)** — logowanie, konfiguracja, punkt przywracania, rejestr cofnięć, kontrakt modułu; komputery docelowe, połączenia i wykonanie operacji lokalnie lub zdalnie.
5. **System operacyjny / komputer zdalny** — rzeczywisty system, na którym wykonywana jest operacja.
6. **Launcher** — przygotowuje środowisko i uruchamia GUI (albo launcher modułu `apprun`, FAZA 19).

Zakazane wzorce (D-015, D-019):
- wywoływanie poleceń systemowych wprost z obsługi kliknięcia w GUI,
- logika systemowa lub **logika połączeń zdalnych** w kodzie widoku,
- odczyt lub zmiana kontrolek GUI z modułów logiki,
- uzależnianie logiki aplikacyjnej od konkretnego okna lub widgetu,
- **globalny, zmienny „bieżący komputer"** używany niejawnie przez wszystkie moduły.

## Host i moduły (propozycja, FAZA 2–4)

Host (okno główne) odpowiada za: nawigację (`Pulpit` z Dashboardem, obszary, `Ustawienia`, `O programie`), wykrywanie, ładowanie i uruchamianie modułów, zarządzanie instancjami i ich cyklem życia, konfigurację i logowanie, zarządzanie komputerami docelowymi, umieszczanie widoków modułów (okno główne, osobne okno, Dashboard), zapis konfiguracji Dashboardu, obsługę błędów i statusów połączeń, kontrolę uprawnień i potwierdzeń. Host nie zawiera szczegółowej logiki obszarów.

Każdy moduł: ma unikalny identyfikator, nazwę i wersję; udostępnia kontrakt integracyjny (manifest); oddziela widok od logiki; deklaruje obsługiwane tryby prezentacji, wymagane uprawnienia i zależności; waliduje dane wejściowe i zgłasza czytelne błędy; jest testowalny bez hosta.

## Definicja modułu a instancja modułu

**Definicja modułu nie jest jego instancją.** Definicja opisuje funkcjonalność, instancja jest konkretnym uruchomieniem w określonym kontekście. Przykład: moduł `Services` ma jednocześnie dwie instancje, „Usługi — localhost" i „Usługi — komputer zdalny". Obie używają tej samej implementacji, ale mają niezależne konteksty, stan widoku, parametry, status połączenia i cykl życia.

Wymagania:
- jedna definicja, wiele instancji; każda instancja ma własny identyfikator i jawny kontekst wykonania,
- stan instancji nie jest przypadkowo współdzielony; zmiana komputera w jednej instancji nie zmienia kontekstu innych,
- zamknięcie jednej instancji nie zamyka pozostałych i zwalnia jej zasoby (zadania, sesje),
- instancje mogą współdzielić tylko bezpieczne, niemodyfikowalne zasoby o jawnie zdefiniowanych zasadach,
- sesje zdalne i zasoby zależne od uprawnień mają określony zakres i cykl życia.

## Kontekst wykonania i komputer docelowy (propozycja, FAZA 3)

Nie zakładaj, że moduł działa na komputerze lokalnym. Kontekst wykonania (`New-MwpExecutionContext`) określa co najmniej:
- komputer docelowy (`localhost` albo nazwa zdalnego komputera z rejestru komputerów),
- tryb: `Local` (bezpośrednio) lub `Remote` (przez transport),
- tożsamość lub odwołanie do poświadczeń (nigdy sam sekret),
- stan połączenia: `Connected`, `Connecting`, `Disconnected`, `Unauthorized`, `Error`,
- parametry specyficzne dla modułu,
- politykę limitów czasu i obsługi błędów.

Kontekst jest niezmienny w obrębie instancji. Nazwy pól do potwierdzenia w FAZIE 3.

Rozdzielone są: reprezentacja komputera docelowego, nawiązywanie i utrzymywanie połączenia, wykonywanie operacji, prezentacja stanu połączenia w UI. Rozdzielone są też uwierzytelnienie, autoryzacja i dostępność połączenia. Błędy połączenia obsługiwane są na poziomie kontekstu lub instancji, nigdy jako błąd całej aplikacji.

## Połączenia zdalne (propozycja, FAZA 3)

- Rejestr komputerów docelowych w `config/settings.local.json` (poza repozytorium); `localhost` zawsze obecny.
- Wykonanie operacji: `Invoke-MwpOnTarget -Context -ScriptBlock -ArgumentList` — lokalnie bezpośrednio, zdalnie przez sesję. Wynik w standardowym obiekcie `New-MwpResult`.
- Transport (ADR w FAZIE 3): propozycja — PowerShell Remoting (WinRM) dla operacji i sesje CIM dla odczytu; nie wszystkie moduły muszą używać tego samego transportu (kontrakt adaptera). Tylko kanały wbudowane w Windows, bez własnego agenta.
- Uwierzytelnianie (ADR w FAZIE 3): bez haseł i sekretów w jawnym tekście, w repozytorium i w logach; opcje: bieżący użytkownik, `Get-Credential` na życzenie, poświadczenia z ochroną DPAPI. Nie osłabiamy zabezpieczeń Windows (np. brak `TrustedHosts = *`).
- Izolacja: awaria, limit czasu lub brak uprawnień dla jednego komputera nie wpływa na pozostałe instancje i widgety; limit równoległych zadań; anulowanie i zwalnianie zasobów.
- Znane ograniczenia zdalne do zbadania w fazach obszarów: profil użytkownika (HKCU) i `winget` w sesji nieinteraktywnej, Windows Update Agent (COM) w sesji zdalnej, zrzuty ekranu i dostęp do pulpitu użytkownika, ryzyko utraty łączności przy zmianie sieci i zapory.

## Tryby prezentacji (propozycja, FAZA 4, 5, 19)

Moduł deklaruje, które tryby obsługuje (nie każdy musi wszystkie):

1. **Embedded** — widok w oknie głównym.
2. **SeparateWindow** — widok w osobnym oknie.
3. **DashboardWidget** — uproszczony widok danych na Dashboardzie.
4. **Standalone** — samodzielne uruchomienie bez hosta.
5. **CLI** — uruchomienie z linii poleceń.

Miejsce prezentacji nie określa logiki modułu. Widoki mogą się różnić, ale używają wspólnych usług aplikacyjnych. Tryb samodzielny nie omija zabezpieczeń, walidacji ani kontroli uprawnień.

## Dashboard i widgety (propozycja, FAZA 5)

Dashboard to konfigurowalna przestrzeń robocza z wieloma widokami modułów dla różnych komputerów jednocześnie (np. status usług na jednym komputerze, dyski na drugim, informacje o systemie lokalnym, status RDP). Dashboard jest kompozycją niezależnych widgetów, a nie zbiorem specjalnie napisanych ekranów.

- Widget to osobny kontrakt prezentacji danych (nie miniaturowe okno): własna konfiguracja, jawne powiązanie z instancją modułu lub źródłem danych i komputerem, wspólne usługi aplikacyjne z pełnym widokiem.
- Stany widgetu: ładowanie, błąd, brak danych, utrata połączenia. Odświeżanie ręczne i automatyczne z kontrolowaną częstotliwością; limit równoległych zadań w tle.
- Izolacja: błąd jednego widgetu lub utrata połączenia z jednym komputerem nie zatrzymuje pozostałych; usunięcie widgetu anuluje zadania i zwalnia zasoby.
- Konfiguracja Dashboardu (widgety, komputery, parametry, układ) jest zapisywana i odtwarzana po ponownym uruchomieniu (miejsce zapisu: ADR w FAZIE 5, propozycja — plik lokalny poza repozytorium).

## Kontrakt modułu (propozycja, FAZA 2)

Manifest opisuje tożsamość, zależności i możliwości modułu. Proponowane pola (miejsce w `.psd1`, np. `PrivateData`, i nazwy do potwierdzenia w FAZIE 2): `Id`, `Name`, `Version`, `Description`, `EntryPoint`, `MinimumHostVersion`, `Dependencies`, `Capabilities`, `SupportedPresentationModes`, `RequiredPermissions`, `ConfigurationSchema`.

Kontrakt określa: odkrywanie i ładowanie modułu (tylko `src/Modules`, bez instalatora), tworzenie, inicjalizację i zamykanie instancji, przekazywanie kontekstu wykonania, dostęp do usług hosta, udostępnianie pełnego widoku i widgetu, obsługę i walidację konfiguracji, zasady anulowania zadań i zwalniania zasobów, raportowanie błędów i statusów, zgodność wersji i brakujące zależności. Moduł nie zależy od prywatnych klas hosta bez jawnego kontraktu.

## Samodzielne uruchamianie (propozycja, FAZA 19)

Moduły deklarujące tryb Standalone lub CLI uruchamiają się bez głównego okna. Przykładowa składnia (nie jest zatwierdzona): `apprun "Services"`, `apprun "Services" -ComputerName "<nazwa>"`. Launcher znajduje i weryfikuje moduł, sprawdza zależności, przekazuje parametry i kontekst, uruchamia widok lub CLI, zachowuje walidację, autoryzację i logowanie i zwraca czytelne błędy. Nie powstaje osobna logika biznesowa na potrzeby trybu samodzielnego.

## Model procesów i współbieżność (ADR w FAZIE 2)

Do rozstrzygnięcia: moduły w procesie hosta, w osobnych procesach albo model mieszany. Nie zakładamy z góry osobnego procesu na moduł. Kryteria: izolacja awarii, koszt pamięci i uruchamiania, bezpieczeństwo i zakres uprawnień, współdzielenie usług i danych, integracja z UI, obsługa wielu instancji, uruchamianie bez hosta, komunikacja między procesami. Propozycja wyjściowa: moduły w procesie hosta, długie i zdalne operacje w runspace'ach z limitem równoległości, anulowaniem i limitami czasu. Każda operacja ma zasady anulowania, limitów czasu, obsługi błędów i zwalniania zasobów.

## Zasady bezpieczeństwa zmian

- Domyślnie **podgląd**: GUI pokazuje, co zostanie zmienione, zanim to zrobi.
- Każda zmiana: wpis w logu operacji (co, kiedy, stan przed, stan po).
- Cofanie: tam, gdzie możliwe, zapisujemy stan przed zmianą i oferujemy przywrócenie.
- Punkt przywracania systemu przed grupą ryzykownych zmian (np. tweaki rejestru).
- Operacje wymagające administratora są jawnie oznaczone; launcher potrafi poprosić o podniesienie uprawnień.
- Lista ochronna: elementy krytyczne dla działania systemu (np. wybrane usługi) są oznaczone i domyślnie zablokowane przed wyłączeniem.
- Walidacja parametrów przekazywanych do poleceń systemowych; żadnego budowania poleceń przez sklejanie tekstu wejściowego (D-015).
- Nie osłabiamy zabezpieczeń Windows dla wygody; w logach nie zapisujemy sekretów.
- Komputery zdalne (D-019): potwierdzenie operacji zmieniającej system zawiera nazwę komputera docelowego; log i wpis cofnięcia zapisują komputer; punkt przywracania tworzony na komputerze docelowym; operacje mogące odciąć łączność (sieć, zapora) mają dodatkowe ostrzeżenie i, gdzie się da, automatyczne wycofanie po limicie czasu.
- Uprawnienia: nie traktuj obecności użytkownika w aplikacji jako dowodu uprawnień administracyjnych; rozróżniaj uwierzytelnienie, autoryzację i dostępność połączenia; stosuj najmniejsze wymagane uprawnienia.
- Propozycja dla FAZY 2 (z archiwum, D-015): klasy operacji **Odczyt** (bez potwierdzenia), **Zmiana** (odwracalna: podgląd, log, cofanie), **Destrukcyjna** (trudna do cofnięcia: jawne potwierdzenie z nazwą celu); operacja o niejasnej klasie traktowana jak wyższa.

## Zgodność PowerShell 5.1 / 7.x

- Unikaj składni dostępnej tylko w 7.x (np. `??`, `?.`, ternary, `ForEach-Object -Parallel`) w kodzie, który ma działać w 5.1, albo zapewnij wariant.
- Zapisuj pliki `.ps1`/`.psm1`/`.psd1` jako UTF-8 z BOM (5.1 źle czyta polskie znaki bez BOM — potwierdzone w FAZIE 1: plik bez BOM nie parsuje się). Pliki JSON: UTF-8 bez BOM, czytane przez `Get-Content -Raw -Encoding UTF8`.
- Kontrolę zgodności wykonuje PSScriptAnalyzer (`PSUseCompatibleSyntax`, `PSUseCompatibleCommands`, `PSUseCompatibleTypes`, D-018). Testy (`tests\Invoke-Checks.ps1`) uruchamiane są w 5.1 i 7.x, każda wersja w nowym procesie (D-022).
- Kod wykonywany na komputerze zdalnym musi działać w Windows PowerShell 5.1: komputer zdalny nie ma PowerShell 7, a domyślny punkt końcowy WinRM (`Microsoft.PowerShell`) to 5.1. Nie zakładaj PowerShell 7 na komputerze docelowym.
- Cmdlety CIM zamiast WMI. Ścieżki przez `Join-Path`.
- Różnice wersji zbierz w jednym miejscu (`MWP.Core`).

## Logi i konfiguracja

- Logi: `%LOCALAPPDATA%\MyWindowsPower\logs\`
- Konfiguracja użytkownika: `config/settings.local.json` (poza repozytorium); szablon `config/settings.example.json` z polem `schemaVersion`. Od FAZY 3 zawiera sekcję `targets` (komputery docelowe: `localhost` i zdalne); nazwy prawdziwych komputerów, adresy i poświadczenia nigdy nie trafiają do repozytorium ani do szablonu.
- Zasady dla FAZY 2 (D-015): zapis atomowy (plik tymczasowy, potem podmiana); uszkodzony plik nie blokuje startu — aplikacja startuje z wartościami domyślnymi, informuje użytkownika i zachowuje uszkodzony plik pod inną nazwą; zmiana `schemaVersion` wymaga migracji.

## Testy

- Pester dla modułów logiki; GUI testowane ręcznie wg checklist w plikach faz.
- Testy nie mogą zmieniać realnego systemu: używaj mocków i `-WhatIf`.
- Uruchamianie: `.\tests\Invoke-Checks.ps1` (opcje `-SkipAnalyzer`, `-SkipTests`); kod wyjścia 0 = analiza bez uwag i wszystkie testy zaliczone.
- Pliki testów zaczynają się od `#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }` i atrybutu tłumiącego `PSUseDeclaredVarsMoreThanAssignments` (zakresy Pestera).

## Testy architektoniczne (FAZY 3–5 dodają je stopniowo, FAZA 20 domyka)

1. Uruchomienie modułu samodzielnie bez hosta.
2. Uruchomienie modułu wewnątrz hosta.
3. Dwie instancje tego samego modułu dla dwóch komputerów.
4. Instancje nie współdzielą przypadkowo zmiennego stanu.
5. Widgety różnych modułów na Dashboardzie.
6. Kilka widgetów powiązanych z różnymi komputerami.
7. Utrata połączenia z jednym komputerem bez zatrzymywania pozostałych widgetów.
8. Anulowanie długiej operacji i zwolnienie zasobów.
9. Zamknięcie jednej instancji bez wpływu na inne.
10. Odtworzenie konfiguracji Dashboardu po ponownym uruchomieniu.
11. Niezgodna wersja modułu lub brakująca zależność.
12. Weryfikacja wymaganych uprawnień przed operacją administracyjną.

Testy z komputerem zdalnym używają mocków; realne połączenie jest weryfikowane ręcznie na Windows 11 (punkty „DO WERYFIKACJI NA WINDOWS" w plikach faz).
