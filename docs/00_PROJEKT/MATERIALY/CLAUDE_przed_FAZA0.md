# CLAUDE.md — My Windows Power

## 0. Katalog główny projektu i stan repozytorium

**Katalog główny projektu (root):** `MyWindowsPower`, na komputerze właściciela: `C:\Users\wysoc\Documents\Projects\PowerShell\MyWindowsPower`.

Zasady odwoływania się do roota:

- Wszystkie ścieżki w tym pliku, w dokumentacji, skryptach i kodzie są **względne wobec roota** (`./src/Core`, `./tests/Unit`).
- Kod nie zawiera zapisanych na stałe ścieżek bezwzględnych. Root jest ustalany w czasie działania (np. przez `$PSScriptRoot` i ścieżkę względną), a polecenia z sekcji 15 uruchamia się z roota.
- Wszystkie nowe pliki powstają wewnątrz roota. Nie zapisuj niczego poza nim bez wyraźnej zgody właściciela.
- Dane aplikacji (konfiguracja, układ Dashboardu, logi) leżą domyślnie w `./data/` w rootcie, a lokalizację można zmienić zgodnie z sekcją 14.1. Folder `data/` jest w `.gitignore`. Nie mieszaj danych z kodem i nie commituj ich.

**Stan repozytorium (2026-10-22):** istnieje dokumentacja (`CLAUDE.md`, kopia poprzedniej wersji `CLAUDE.original.md`), `.gitignore` oraz pliki celów testów integracyjnych w `./tests/Integration/` (szablon i lokalny plik, zob. 15.5). Nie ma jeszcze kodu hosta ani modułów, ani ADR. Istnieją też `README.md`, `PSScriptAnalyzerSettings.psd1`, skrypty w `./scripts/` (nieuruchomione, zob. 15.3) i pierwszy test struktury repozytorium w `./tests/Unit/`. Wszystko, co dotyczy `src/` i `docs/`, jest planem, dopóki odpowiednie pliki nie powstaną. Po utworzeniu pierwszego kodu zaktualizuj tę sekcję.

**Oznaczenia statusu używane w tym pliku:**

- **[Przyjęte]**: obowiązuje, można na tym polegać.
- **[Robocze]**: decyzja podjęta roboczo, żeby nie blokować prac. Wymaga potwierdzenia w ADR i dowodu koncepcji (sekcje 17 i 18). Do czasu ADR możesz na niej budować, ale izoluj ją tak, by dało się ją zmienić.
- **[Odroczone]**: świadomie odłożone do spełnienia warunku opisanego przy danej decyzji. Nie implementuj do tego czasu.
- **[Otwarte]**: nierozstrzygnięte. Nie zakładaj odpowiedzi, zapytaj właściciela.

## 1. Cel projektu

**My Windows Power** to modularna aplikacja desktopowa do lokalnego i zdalnego zarządzania komputerami z systemem Windows 11, oparta na PowerShell.

Aplikacja składa się z hosta oraz niezależnych modułów administracyjnych. Host zapewnia wspólne środowisko pracy, nawigację, konfigurację, logowanie i integrację modułów. Moduły dostarczają konkretne funkcje administracyjne.

Najważniejsze cele:

- Modularna, rozszerzalna architektura.
- Pełna separacja interfejsu użytkownika od logiki aplikacyjnej i operacji systemowych.
- Obsługa wielu komputerów lokalnych i zdalnych.
- Możliwość wielokrotnego uruchomienia tego samego modułu dla różnych komputerów.
- Możliwość prezentowania wielu modułów i komputerów jednocześnie na Dashboardzie.
- Możliwość uruchamiania modułów wewnątrz hosta, w osobnym oknie lub samodzielnie.
- Bezpieczne wykonywanie operacji administracyjnych.
- Łatwa diagnostyka, testowanie i rozwijanie projektu.

## 2. Zasady architektoniczne

1. **Separation of concerns**: oddzielaj UI, logikę aplikacyjną, dostęp do danych i integrację z systemem.
2. **Modularność**: funkcjonalności administracyjne są niezależnymi modułami.
3. **Wieloinstancyjność**: jedna definicja modułu może mieć wiele niezależnych instancji.
4. **Jawny kontekst wykonania**: każda instancja wie, dla jakiego komputera i z jakimi uprawnieniami działa.
5. **Niezależność od miejsca prezentacji**: logika modułu nie zależy od tego, czy moduł działa na Dashboardzie, w głównym oknie, czy w osobnym oknie.
6. **Wielokrotne wykorzystanie logiki**: te same usługi aplikacyjne są używane przez UI, Dashboard i CLI.
7. **Odporność na błędy**: niedostępność jednego komputera lub modułu nie blokuje całej aplikacji.
8. **Bezpieczeństwo domyślne**: żadnych uprzywilejowanych operacji bez jawnej autoryzacji i kontroli uprawnień.
9. **Brak blokowania UI**: operacje sieciowe, zdalne i długotrwałe są asynchroniczne.
10. **Minimalizacja sprzężeń**: moduły nie zależą bezpośrednio od wewnętrznych implementacji hosta ani innych modułów.

## 3. Host aplikacji

Host odpowiada za:

- Główne okno i nawigację.
- Pozycję `Pulpit` z widokiem `Dashboard`.
- `Ustawienia`.
- `O programie`.
- Wykrywanie, ładowanie i uruchamianie modułów.
- Zarządzanie instancjami modułów i ich cyklem życia.
- Wspólną konfigurację i logowanie.
- Zarządzanie kontekstami komputerów lokalnych i zdalnych.
- Umieszczanie widoków modułów w głównym oknie, osobnych oknach i na Dashboardzie.
- Zapisywanie konfiguracji Dashboardu.
- Obsługę błędów, statusów połączeń i komunikatów użytkownika.
- Kontrolę uprawnień i potwierdzeń operacji administracyjnych.

Host nie zawiera szczegółowej logiki poszczególnych funkcji administracyjnych.

## 4. Moduły administracyjne

Przykładowe moduły:

- Dyski i woluminy.
- Usługi Windows.
- Użytkownicy i grupy lokalne.
- RDP i zarządzanie sesjami, w tym obsługiwane scenariusze shadowingu.
- Zrzuty ekranu zdalnego komputera.
- Informacje o systemie i sprzęcie.
- Procesy i monitorowanie zasobów.

Każdy moduł powinien:

- Mieć unikalny identyfikator, nazwę i wersję.
- Udostępniać zdefiniowany kontrakt integracyjny.
- Oddzielać widok od logiki aplikacyjnej.
- Deklarować obsługiwane tryby uruchamiania.
- Określać wymagane uprawnienia i zależności.
- Udostępniać walidację danych wejściowych i czytelne błędy.
- Być testowalny bez uruchamiania całego hosta, jeśli to możliwe.

**Uwaga dla modułów RDP i shadowingu:** shadowing sesji podlega politykom Windows (m.in. zasadom grup dotyczącym zdalnego sterowania sesjami usług pulpitu zdalnego) oraz zgodzie użytkownika sesji, jeśli polityka tego wymaga. Moduł respektuje te ustawienia, nie zmienia ich w celu uproszczenia działania i jasno informuje użytkownika, gdy polityka blokuje operację (zob. sekcja 12).

### 4.1. Definicja modułu a instancja modułu

**Definicja modułu nie jest jego instancją.** Definicja opisuje funkcjonalność, a instancja jest konkretnym uruchomieniem tej funkcjonalności w określonym kontekście.

Przykład: moduł `Services` może mieć jednocześnie dwie instancje:

- `Services — COMPUTER-01`
- `Services — COMPUTER-02`

Obie instancje korzystają z tej samej implementacji modułu, ale mają niezależne konteksty, stan widoku, parametry, status połączenia i cykl życia.

Wymagania:

- Jedna definicja modułu może mieć wiele instancji.
- Każda instancja ma własny identyfikator.
- Instancja ma jawny kontekst wykonania.
- Stan instancji nie jest przypadkowo współdzielony z inną instancją.
- Zmiana komputera docelowego w jednej instancji nie zmienia kontekstu innych instancji.
- Zamknięcie jednej instancji nie zamyka pozostałych.
- Instancje mogą współdzielić bezpieczne, niemodyfikowalne zasoby, jeśli zasady współdzielenia są jawnie zdefiniowane.
- Sesje zdalne i zasoby zależne od uprawnień są zarządzane zgodnie z określonym zakresem i cyklem życia.

## 5. Kontekst wykonania i komputer docelowy

Nie zakładaj, że moduł zawsze działa na komputerze lokalnym.

Kontekst wykonania umożliwia określenie co najmniej:

- Komputera docelowego.
- Trybu lokalnego lub zdalnego.
- Tożsamości lub kontekstu uwierzytelnienia, jeśli jest wymagany.
- Stanu połączenia.
- Parametrów specyficznych dla modułu.
- Polityki czasu oczekiwania i obsługi błędów.

Sposób połączenia dobiera się do wymagań funkcji. Nie wszystkie moduły muszą korzystać z tego samego transportu ani mechanizmu zdalnego wykonania.

**[Robocze] Domyślny transport zdalny (D-004):** PowerShell Remoting (WinRM) dla poleceń i sesji oraz sesje CIM tam, gdzie wystarczy zapytanie o dane. Moduł może zadeklarować inny transport, jeśli funkcja tego wymaga (np. RDP). Zasady:

- Kod wykonywany na komputerze docelowym musi być zgodny z Windows PowerShell 5.1, bo Windows 11 ma ją wbudowaną, a PowerShell 7 nie musi być tam zainstalowany. Nie zakładaj PowerShell 7 na celu.
- Nie włączaj ani nie zmieniaj konfiguracji zdalnego zarządzania na komputerze docelowym bez jawnej zgody użytkownika (zob. sekcja 12).
- **Środowisko właściciela to grupa robocza w sieci LAN (bez domeny).** Nie zakładaj Kerberos ani usług domenowych. Uwierzytelnianie opiera się na kontach lokalnych na komputerach docelowych (szczegóły w 15.5).

Oddziel:

- Reprezentację komputera docelowego.
- Nawiązywanie i utrzymywanie połączenia.
- Wykonywanie operacji administracyjnych.
- Prezentację stanu połączenia w UI.

Błędy połączenia są obsługiwane na poziomie konkretnego kontekstu lub instancji, a nie jako błąd całego hosta.

## 6. Tryby prezentacji i uruchamiania modułów

Moduł deklaruje, które tryby obsługuje:

1. **Embedded view**: widok wewnątrz głównego okna hosta.
2. **Separate window**: widok w osobnym oknie.
3. **Dashboard widget**: uproszczony widok danych na Dashboardzie.
4. **Standalone**: samodzielne uruchomienie bez hosta.
5. **CLI**: uruchomienie z linii poleceń, jeśli moduł obsługuje taki scenariusz.

Nie każdy moduł musi obsługiwać wszystkie tryby.

Ważne zasady:

- Miejsce prezentacji nie określa logiki biznesowej modułu.
- Widoki mogą być różne dla poszczególnych trybów, ale korzystają ze wspólnych usług aplikacyjnych.
- Moduł uruchamiany samodzielnie nie wymaga załadowania całego hosta.
- Jeśli wymagane są usługi hosta, moduł korzysta z jawnego kontraktu lub samodzielnej implementacji zgodności.
- Tryb samodzielny nie omija niejawnie zabezpieczeń, walidacji ani kontroli uprawnień.

## 7. Dashboard — kompozycja wielu widoków

Dashboard to konfigurowalna przestrzeń robocza, w której użytkownik umieszcza wiele widoków modułów i monitoruje różne komputery jednocześnie.

Przykładowy układ:

- Status usług na `COMPUTER-01`.
- Wykorzystanie dysków na `COMPUTER-02`.
- Informacje o systemie lokalnym.
- Status połączenia RDP z innym komputerem.

Każdy widget ma własną konfigurację oraz jawne powiązanie z instancją modułu lub źródłem danych.

Dashboard obsługuje:

- Dodawanie i usuwanie widgetów.
- Konfigurację komputera docelowego dla każdego widgetu.
- Konfigurację parametrów modułu.
- Zmianę rozmiaru i położenia widgetów, jeśli obsługuje to wybrany model UI.
- Ręczne i automatyczne odświeżanie danych.
- Widok ładowania, błędu, braku danych i utraty połączenia.
- Zapisywanie i odtwarzanie konfiguracji użytkownika.
- Niezależne działanie widgetów.

### 7.1. Izolacja widgetów

- Błąd jednego widgetu nie blokuje pozostałych.
- Utrata połączenia z jednym komputerem nie zatrzymuje odświeżania danych z innych komputerów.
- Każdy widget ma własny stan prezentacji i status operacji.
- Częstotliwość odświeżania jest kontrolowana.
- Usuwany widget zwalnia zasoby, anuluje zbędne zadania i poprawnie kończy subskrypcje.
- Liczba równoległych zadań w tle jest ograniczona (limit konfigurowalny, wartość domyślna ustalana w D-005).
- Dashboard korzysta z tych samych usług aplikacyjnych co pełne widoki modułów.

Widget nie jest wyłącznie miniaturowym oknem. To osobny kontrakt prezentacji danych, który może wykorzystywać logikę istniejącego modułu.

## 8. Separacja UI i backendu

Logiczny podział na warstwy:

1. **UI / View**: wyświetlanie danych i obsługa interakcji.
2. **Presentation Logic / ViewModel**: stan widoku, polecenia, walidacja prezentacyjna i reakcje na zdarzenia.
3. **Application Services**: przypadki użycia, orkiestracja operacji i reguły aplikacyjne.
4. **System / Remote Adapters**: integracja z PowerShell, Windows API, zdalnym komputerem i transportem.
5. **Operating System / Remote Target**: rzeczywisty system, na którym wykonywana jest operacja.

Dostosuj podział do możliwości wybranego frameworka, ale zachowaj separację odpowiedzialności.

Zabronione wzorce:

- Wywoływanie poleceń administracyjnych bezpośrednio z obsługi kliknięcia w UI.
- Umieszczanie logiki połączeń zdalnych w kodzie widoku.
- Bezpośrednie odczytywanie i modyfikowanie kontrolek UI z warstwy backendu.
- Uzależnianie logiki aplikacyjnej od konkretnego okna lub widgetu.
- Przechowywanie globalnego, zmiennego kontekstu komputera, który jest niejawnie używany przez wszystkie moduły.

Adaptery (warstwa 4) są jedynym miejscem, które wywołuje polecenia systemowe. Dzięki temu w testach można je zastąpić atrapami (zob. sekcja 15).

## 9. Kontrakt modułu

Każdy moduł ma manifest opisujący jego tożsamość, zależności i możliwości.

**[Robocze] Format manifestu (D-003):** plik danych PowerShell (`.psd1`), ponieważ jest natywny dla PowerShell, czytelny i można go wczytać bez wykonywania kodu (np. `Import-PowerShellDataFile`). Manifest modułu administracyjnego jest oddzielony od standardowego manifestu modułu PowerShell. Standardowy manifest opisuje pakiet PowerShell, a manifest My Windows Power opisuje kontrakt z hostem. Schemat konfiguracji (`ConfigurationSchema`) jest osobnym plikiem, którego format ustala D-003.

Proponowane pola manifestu:

- `Id`
- `Name`
- `Version`
- `Description`
- `EntryPoint`
- `MinimumHostVersion`
- `Dependencies`
- `Capabilities`
- `SupportedPresentationModes`
- `RequiredPermissions`
- `ConfigurationSchema`

Nazwy i typy pól należy potwierdzić w specyfikacji kontraktu (`./docs/contracts/`) przed wdrożeniem.

Kontrakt modułu określa:

- Sposób odkrywania i ładowania modułu.
- Tworzenie, inicjalizację i zamykanie instancji.
- Przekazywanie kontekstu wykonania.
- Dostęp do usług hosta.
- Udostępnianie pełnego widoku i widgetu Dashboardu.
- Obsługę konfiguracji i jej walidację.
- Zasady anulowania zadań i zwalniania zasobów.
- Raportowanie błędów i statusów.
- Zgodność wersji i obsługę brakujących zależności.

Nie wprowadzaj zależności od prywatnych klas hosta bez jawnego kontraktu.

### 9.1. Odkrywanie i zarządzanie modułami (D-006)

**[Robocze]** Wersja 1 obsługuje wyłącznie moduły zaufane (własne). Pobieranie modułów z sieci jest poza zakresem i wymaga osobnego ADR (zasady podpisów, uprawnienia do folderów, weryfikacja źródła), bo moduł to wykonywany kod.

- **Miejsca odkrywania:** `./src/Modules/` (moduły dostarczone z aplikacją) oraz `Modules/` w folderze danych (sekcja 14.1, moduły użytkownika).
- **Wykrywanie:** host wczytuje manifesty `.psd1` bez wykonywania kodu modułu i sprawdza `Id`, `Version`, `MinimumHostVersion`, `Dependencies`. Moduł niezgodny lub z brakującą zależnością jest widoczny na liście wraz z przyczyną i nie jest ładowany (test nr 11).
- **Unikalność:** dwa moduły o tym samym `Id` to błąd. Host nie wybiera jednego po cichu, tylko zgłasza konflikt.
- **Instalacja:** skopiowanie folderu modułu do jednego z miejsc odkrywania.
- **Aktualizacja:** podmiana folderu po zamknięciu wszystkich instancji tego modułu. Konfiguracja użytkownika nie jest zmieniana, a ewentualna migracja jest opisana (sekcja 19).
- **Usunięcie:** po zamknięciu instancji. Dane i konfiguracja użytkownika nie są kasowane automatycznie.

## 10. Samodzielne uruchamianie

Moduły da się uruchamiać bez głównego hosta, jeśli deklarują obsługę tego trybu.

**[Robocze] Nazewnictwo (zgodne z sekcją 15):** właściwe polecenie nazywa się `Start-MwpModule`, a `apprun` jest jego aliasem. Alias zachowuje skrót użyty w założeniach projektu. Docelowa składnia:

```powershell
apprun "Services"
apprun "Services" -ComputerName "COMPUTER-01"
# równoważnie:
Start-MwpModule -Name "Services" -ComputerName "COMPUTER-01"
```

To przykładowy interfejs, a nie zatwierdzona implementacja. Parametry potwierdza D-003.

Samodzielny launcher:

- Znajduje i weryfikuje moduł.
- Sprawdza zależności.
- Przekazuje parametry i kontekst wykonania.
- Uruchamia właściwy interfejs lub tryb CLI.
- Zachowuje walidację, autoryzację i logowanie.
- Zwraca czytelne błędy w przypadku braku modułu lub zależności.

Nie twórz osobnej implementacji logiki biznesowej wyłącznie na potrzeby samodzielnego uruchamiania.

## 11. Model procesów i współbieżność

**[Robocze] Model mieszany (D-002):** domyślnie moduły działają w procesie hosta, a każda instancja we własnej, odizolowanej przestrzeni wykonania (osobny runspace PowerShell), co daje niezależny stan instancji bez kosztu osobnego procesu. Moduł wymagający izolacji awarii lub innego zakresu uprawnień może zadeklarować uruchomienie w osobnym procesie. W takim przypadku obowiązuje kontrakt komunikacji z D-008, którego jeszcze nie ma. **D-008 jest [Odroczone].** Wersja 1 działa w procesie hosta i nie wymaga komunikacji międzyprocesowej, więc jej nie implementuj. **Warunek wznowienia:** pojawia się pierwszy moduł, który naprawdę potrzebuje osobnego procesu (np. podwyższonych uprawnień). Wtedy preferowany kierunek to natywny mechanizm PowerShell (runspace poza procesem przez potok nazwany), a nie własny protokół, do zweryfikowania w dowodzie koncepcji, w tym anulowanie, limity czasu i wykrywanie martwego procesu. Gdyby własny protokół jednak był potrzebny, minimalna koperta komunikatu zawiera: `schemaVersion`, `instanceId`, `correlationId`, typ, ładunek i kod błędu.

Uzasadnienie i ryzyka (do weryfikacji w dowodzie koncepcji):

- Osobny runspace izoluje zmienne i stan, ale nie izoluje awarii całego procesu. Awaria w procesie hosta zatrzymuje wszystkie instancje.
- Dlatego moduły o podwyższonym ryzyku (zmiany systemu, uprawnienia podwyższone) są kandydatami do osobnego procesu.

Decyzja uwzględnia:

- Izolację awarii.
- Koszt pamięci i uruchamiania.
- Bezpieczeństwo i zakres uprawnień.
- Współdzielenie usług i danych.
- Integrację z UI.
- Obsługę wielu instancji.
- Możliwość uruchomienia modułu bez hosta.
- Komunikację między procesami, jeśli jest potrzebna.

Długotrwałe zadania, odświeżanie Dashboardu i operacje zdalne wykonuj bez blokowania interfejsu.

Każda operacja ma określone zasady anulowania, limitów czasu, obsługi błędów i zwalniania zasobów.

## 12. Bezpieczeństwo

- Nie przechowuj haseł ani sekretów w jawnym tekście.
- Nie traktuj samej obecności użytkownika w aplikacji jako dowodu uprawnień administracyjnych.
- Stosuj najmniejsze wymagane uprawnienia.
- Weryfikuj parametry przekazywane do poleceń i operacji systemowych.
- Nie buduj poleceń PowerShell przez niekontrolowane łączenie tekstu wejściowego.
- Rozróżniaj uwierzytelnienie, autoryzację i dostępność połączenia.
- Informuj użytkownika o operacjach zmieniających konfigurację lub stan systemu.
- Rejestruj istotne zdarzenia administracyjne bez zapisywania sekretów.
- Nie osłabiaj zabezpieczeń Windows w celu uproszczenia integracji.

### 12.1. Klasyfikacja operacji

**[Robocze]** Każda operacja administracyjna ma w kontrakcie modułu przypisaną klasę. Klasa decyduje o wymaganym potwierdzeniu:

| Klasa | Znaczenie | Przykłady | Wymagane |
|---|---|---|---|
| Odczyt | Nie zmienia stanu systemu | lista usług, użycie dysku, informacje o sprzęcie | Kontrola uprawnień |
| Zmiana | Zmienia konfigurację lub stan, da się to cofnąć | start/stop usługi, zmiana opisu konta | Kontrola uprawnień, informacja dla użytkownika, wpis w dzienniku |
| Destrukcyjna | Trudna lub niemożliwa do cofnięcia, albo o dużym wpływie | usunięcie konta, formatowanie lub zmiana woluminu, wymuszone zakończenie sesji | Jawne potwierdzenie z nazwą celu, kontrola uprawnień, wpis w dzienniku |

Operacja o niejasnej klasie traktowana jest jako klasa wyższa. Przypisanie konkretnych operacji do klas odbywa się w specyfikacjach modułów.

### 12.2. Zasady pracy agenta (Claude Code) z operacjami systemowymi

- Nie uruchamiaj operacji klasy Zmiana ani Destrukcyjna na komputerze deweloperskim ani na żadnym komputerze zdalnym bez wyraźnej zgody właściciela dla tej konkretnej operacji.
- Testy jednostkowe i kontraktowe używają atrap adapterów (warstwa 4). Nie zależą od realnego stanu systemu ani sieci.
- Testy integracyjne wolno uruchamiać tylko na komputerach testowych z lokalnego pliku celów (sekcja 15.5). Nie zgaduj nazw komputerów i nie uruchamiaj testów na celach spoza tego pliku.
- Nie zapisuj w repozytorium rzeczywistych nazw hostów, kont, haseł, tokenów, certyfikatów ani logów z danych produkcyjnych. W przykładach i testach używaj nazw fikcyjnych (`COMPUTER-01`, `COMPUTER-02`).
- Nie włączaj ani nie zmieniaj ustawień zdalnego zarządzania (WinRM, firewall, polityki) na żadnym komputerze bez wyraźnej zgody.

## 13. UI i wybór technologii

**[Robocze] Kierunek dla D-001:** WPF z widokami w XAML ładowanymi z PowerShell, w oparciu o wzorzec MVVM lub równoważny. Uzasadnienie: jest to technologia działająca na Windows 11, dobrze integruje się z PowerShell (ładowanie XAML, powiązania danych), wspiera osobne okna i kompozycję widoków. **Ta decyzja nie jest zatwierdzona.** Musi ją potwierdzić dowód koncepcji (sekcja 18, kroki 4–7), w szczególności:

- Czy asynchroniczne wykonywanie w osobnych runspace'ach współpracuje z wątkiem UI bez blokowania.
- Czy kompozycja widgetów na Dashboardzie i wielu okien jest wystarczająco prosta w utrzymaniu.
- Dostępność (accessibility) i skalowanie UI na Windows 11.

Nie wiąż kontraktu modułu z konkretnym frameworkiem UI. Kontrakt (sekcja 9) opisuje widok abstrakcyjnie, a framework jest szczegółem warstwy 1. Jeśli dowód koncepcji wykaże problemy, rozważ alternatywę, w tym aplikację hybrydową z częścią w .NET, i udokumentuj w ADR.

Porównując rozwiązania, oceniaj:

- Integrację z PowerShell.
- Obsługę Windows 11.
- Wspieranie wzorca MVVM lub równoważnego.
- Osadzanie widoków modułów.
- Tworzenie osobnych okien.
- Komponowanie Dashboardu.
- Dostępność i skalowanie UI.
- Obsługę zadań asynchronicznych.
- Testowalność.
- Łatwość wdrażania i utrzymania.

## 14. Struktura repozytorium

Proponowana struktura początkowa, liczona od roota projektu (`MyWindowsPower/`, zob. sekcja 0):

```text
MyWindowsPower/
├── CLAUDE.md
├── README.md
├── .gitignore            # m.in. data/, data.location, tests/Integration/targets.local.psd1
├── PSScriptAnalyzerSettings.psd1
├── data/                 # domyślny folder danych (sekcja 14.1), poza repozytorium
├── docs/
│   ├── architecture/
│   ├── decisions/        # ADR-001-*.md, ADR-002-*.md, ...
│   └── contracts/
├── src/
│   ├── Host/
│   ├── Core/
│   ├── ModuleContracts/
│   ├── Infrastructure/
│   └── Modules/
│       ├── Disks/
│       ├── Services/
│       ├── UsersGroups/
│       ├── Rdp/
│       └── RemoteScreenshot/
├── tests/
│   ├── Unit/
│   ├── Integration/      # targets.example.psd1 (szablon celów testów)
│   └── ModuleContracts/
└── scripts/
    ├── Invoke-MwpTests.ps1
    └── Invoke-MwpLint.ps1
```

To propozycja, którą można dostosować po zatwierdzeniu frameworka UI i modelu procesów. Katalog `data/` powstaje przy pierwszym uruchomieniu aplikacji. Pozostałe elementy drzewa, które nie istnieją (`src/`, `docs/` itd.), są planem.

### 14.1. Lokalizacja danych aplikacji

**[Robocze]** Wszystkie dane aplikacji (konfiguracja, układ Dashboardu, lista komputerów, logi, pamięć podręczna) leżą w jednym folderze danych. **Domyślnie jest to `./data/` w katalogu głównym projektu** (sekcja 0). Folder danych można przełączyć na inną lokalizację, np. `%APPDATA%\MyWindowsPower` albo katalog w `Program Files`, bez zmian w kodzie modułów.

Układ folderu danych:

```text
data/
├── config/     # ustawienia, układ Dashboardu, lista komputerów (JSON z polem schemaVersion)
├── logs/       # dzienniki, rotowane
└── cache/      # dane tymczasowe, bezpieczne do usunięcia
```

**Jedno miejsce wyznaczania ścieżki.** Folder danych ustala wyłącznie jedna funkcja (planowana nazwa: `Get-MwpDataPath`). Reszta kodu pyta o ścieżkę tę funkcję i nigdy nie buduje ścieżek ręcznie. Kolejność rozstrzygania (pierwsze źródło, które istnieje, wygrywa):

1. Parametr `-DataPath` (host, launcher lub tryb samodzielny).
2. Zmienna środowiskowa `MWP_DATA_DIR`.
3. Plik wskaźnika `./data.location` w katalogu głównym aplikacji, zawierający jedną ścieżkę. Tworzy go funkcja zmiany lokalizacji w `Ustawieniach`.
4. Wartość domyślna: `./data/`.

Zasady:

- **Brak cichej zmiany lokalizacji.** Jeśli wybrany folder danych nie jest zapisywalny (np. aplikacja leży w `Program Files`, a zwykły użytkownik nie ma tam praw zapisu), aplikacja nie przenosi danych sama gdzie indziej. Zgłasza czytelny błąd i proponuje ustawienie `%APPDATA%\MyWindowsPower`.
- **`Program Files` jest dozwolone jako wybór, ale niezalecane.** Wymaga nadania użytkownikom praw zapisu do folderu danych, co osłabia zabezpieczenia i kłóci się z zasadą najmniejszych uprawnień (sekcja 12). Nie osłabiaj uprawnień do folderu bez wyraźnej zgody właściciela. Zalecaną lokalizacją poza folderem aplikacji jest `%APPDATA%\MyWindowsPower`.
- **Zmiana lokalizacji** działa tak: skopiuj dane, zweryfikuj kopię, przełącz wskaźnik, a starych danych nie usuwaj automatycznie. Użytkownik usuwa je sam.
- **Sekrety nigdy nie trafiają do folderu danych.** Pliki zawierają tylko odwołania do poświadczeń (sekcja 12). Magazyn sekretów jest otwarty (D-007).
- **Zapis atomowy:** zapisz do pliku tymczasowego, potem podmień. Uszkodzony plik konfiguracji nie blokuje startu hosta. Host startuje z konfiguracją domyślną i informuje użytkownika, a uszkodzony plik zachowuje pod inną nazwą.
- **Wersjonowanie:** pliki mają pole `schemaVersion`. Zmiana schematu wymaga migracji lub opisu migracji (sekcja 19).
- **Aktualizacja aplikacji nie nadpisuje folderu danych.** Skrypt instalacyjny i aktualizacja podmieniają kod, a folder danych pomijają.
- **Folder danych jest w `.gitignore`.** Nie commituj nazw komputerów, układu pulpitu ani logów (sekcja 12.2).
- Moduł w trybie samodzielnym (sekcja 10) używa tej samej funkcji, więc dane hosta i trybu samodzielnego są spójne.

### 14.2. Dystrybucja aplikacji

**[Robocze]** Podejście etapowe, dopasowane do obecnego etapu projektu (jedna osoba, brak MVP).

1. **Teraz:** folder aplikacji (archiwum zip) oraz skrypt instalacyjny `scripts/Install-MwpApp.ps1` (planowany, nie istnieje), który kopiuje pliki, tworzy skrót i alias `apprun`. Bez instalatora, żeby nie blokować prac nad architekturą.
2. **Po pierwszym MVP:** ponowna ocena instalatora lub pakietu MSIX. Decyzja zależy od D-001 i od tego, czy aplikacja będzie używana poza komputerem właściciela.

Wymagania, które obowiązują od początku (bo później kosztują):

- Numer wersji aplikacji jest w jednym miejscu (manifest hosta).
- Brak ścieżek bezwzględnych w kodzie (sekcja 0).
- Kod aplikacji jest oddzielony od danych użytkownika (sekcja 14.1). Aktualizacja podmienia kod, a dane pomija.
- **Podpisywanie skryptów (Authenticode):** w środowisku właściciela nie jest wymagane, więc nie dodawaj kroku podpisywania. Nie zakładaj tego jednak dla innych środowisk. Jeśli aplikacja trafi tam, gdzie obowiązuje zasada wykonywania `AllSigned`, trzeba będzie dodać podpisywanie do procesu wydawania.

## 15. Standardy PowerShell, środowisko i jakość

### 15.1. Środowisko

- **[Robocze] Host i narzędzia deweloperskie:** PowerShell 7.6 (wydanie LTS, wsparcie do 14.11.2028 według strony cyklu życia PowerShell Microsoftu, sprawdzone 2026-10-22). Wersja 7.4 traci wsparcie 10.11.2026, więc nie jest wersją docelową. Przy kolejnym wydaniu LTS ponownie oceń wersję w ADR.
- **Kod uruchamiany na komputerach docelowych** musi działać w Windows PowerShell 5.1 (zob. sekcja 5). Takie fragmenty oznacz wyraźnie i testuj w obu wersjach, jeśli to możliwe.
- Moduły PowerShell deklarują `#Requires -Version` zgodnie z miejscem wykonania.
- System docelowy aplikacji: Windows 11. Nie zakładaj obsługi innych systemów, dopóki nie zostanie to ustalone.

### 15.2. Język i nazewnictwo

- **[Przyjęte] Język:** dokumentacja, komentarze i komunikaty interfejsu są po polsku. Identyfikatory w kodzie, nazwy poleceń, pola manifestu i nazwy plików są po angielsku. Teksty interfejsu trzymaj w zasobach (nie w kodzie logiki), żeby umożliwić tłumaczenie.
- **[Robocze] Lokalizacja interfejsu:** wersja 1 obsługuje tylko `pl-PL` (kultura domyślna), ale od początku z infrastrukturą: teksty w plikach zasobów w podkatalogach kultur (`pl-PL/`, `en-US/`) wczytywanych mechanizmem `Import-LocalizedData`. Nie przygotowuj tłumaczeń na zapas. `en-US` dodaj dopiero na wyraźną potrzebę. Daty, liczby i rozmiary formatuj przez kulturę, nie ręcznie.
- **[Robocze] Prefiks `Mwp`** (My Windows Power) dla nazw rzeczy publicznych, ponieważ przestrzeń nazw poleceń PowerShell jest wspólna. Format: `Verb-MwpNoun` (np. `Get-MwpServiceStatus`, `Start-MwpModule`). Czasowniki tylko zatwierdzone (`Get-Verb`).
- Stosuj czytelne nazwy funkcji i zmiennych.
- Dodawaj jawne typy tam, gdzie poprawiają czytelność i bezpieczeństwo.
- Rozdzielaj funkcje publiczne i wewnętrzne.
- Obsługuj błędy w sposób przewidywalny.
- Unikaj globalnego stanu i niejawnych zależności.
- Dokumentuj publiczne interfejsy (pomoc komentarzowa).

### 15.3. Polecenia budowania i testów

Pester (wersja 5.0 lub nowsza) i PSScriptAnalyzer są narzędziami projektu. Skrypty istnieją od 2026-10-22, ale **nie zostały jeszcze uruchomione** (przygotowano je w środowisku bez PowerShell). Pierwsze uruchomienie w PowerShell 7 na komputerze właściciela może wymagać poprawek. Uruchamiaj je z dowolnego katalogu, bo same ustalają root projektu:

```powershell
./scripts/Invoke-MwpTests.ps1                      # testy jednostkowe i kontraktowe
./scripts/Invoke-MwpTests.ps1 -Type Integration    # testy integracyjne (tylko cele z lokalnego pliku, zob. 15.5)
./scripts/Invoke-MwpLint.ps1                       # analiza statyczna, ustawienia w ./PSScriptAnalyzerSettings.psd1
```

Pierwsze uruchomienie lintowania może zgłosić fałszywe alarmy (np. dla zmiennych używanych między blokami Pestera). Oceń je i dostrój `PSScriptAnalyzerSettings.psd1`, zamiast wyłączać reguły globalnie. Po pierwszym uruchomieniu wpisz używane wersje Pester i PSScriptAnalyzer w `README.md`.

### 15.4. Testowanie

- Wprowadzaj testy jednostkowe i integracyjne.
- Testuj moduły niezależnie od hosta.
- Testuj wiele instancji tego samego modułu działających jednocześnie.
- Testuj awarie i utratę połączenia z komputerami docelowymi.
- W testach jednostkowych i kontraktowych używaj atrap adapterów (zob. 12.2).

### 15.5. Środowisko testów integracyjnych

**[Robocze]** Środowisko właściciela: komputery w grupie roboczej (bez domeny) w sieci LAN. Podpisywanie skryptów nie jest wymagane.

- **Cele testów integracyjnych:** `localhost` oraz jeden zdalny komputer testowy (NAS właściciela). Nazwa zdalnego komputera jest zapisana wyłącznie w lokalnym pliku celów, nie w repozytorium (zasada z sekcji 12.2).
- **Ten zdalny komputer to prawdziwa maszyna, nie wirtualna, bez punktu kontrolnego.** Prawdopodobnie przechowuje dane, więc traktuj go jak produkcyjny. Z tego wynika:
  - Domyślnie na obu celach wolno wykonywać wyłącznie operacje klasy **Odczyt**.
  - Operacje klasy **Zmiana** wolno uruchomić tylko za wyraźną zgodą właściciela na konkretną operację i konkretny cel.
  - Operacje klasy **Destrukcyjna** nie są uruchamiane w testach automatycznych. Sprawdzaj je atrapami adapterów (sekcja 12.2).
- **Plik celów leży poza repozytorium:** szablon `./tests/Integration/targets.example.psd1` jest w repozytorium, a właściwy `./tests/Integration/targets.local.psd1` jest w `.gitignore`. Każdy cel ma pole `AllowedClasses` (domyślnie tylko `Odczyt`). Plik nie zawiera haseł, tylko odwołania do poświadczeń (sekcja 14.1).
- **Brak pliku celów:** testy integracyjne są pomijane z czytelnym komunikatem. Nie szukaj komputerów w sieci i nie zgaduj nazw.
- **Uwierzytelnianie w grupie roboczej:** nie ma Kerberos, więc używa się lokalnego konta na komputerze docelowym. Zdalne połączenie WinRM w grupie roboczej zwykle wymaga transportu HTTPS albo dodania celu do listy `TrustedHosts` po stronie klienta. **To do zweryfikowania w dowodzie koncepcji.** Nie zmieniaj `TrustedHosts`, WinRM ani zapory na żadnym komputerze bez wyraźnej zgody (sekcja 12.2).
- **Niepotwierdzone założenia, które trzeba sprawdzić przed pierwszym użyciem zdalnego celu [Otwarte]:** system operacyjny tego komputera (aplikacja i kod z sekcji 5 zakładają Windows z PowerShell 5.1), to, czy ma włączone zdalne zarządzanie, oraz to, że jego nazwa zawiera podkreślnik, co bywa kłopotliwe w DNS i certyfikatach.
- **Maszyny wirtualne** (np. `MWP-TEST-01`) są opcjonalnym dodatkiem na przyszłość, gdyby trzeba było bezpiecznie testować operacje klasy Zmiana na prawdziwym systemie.

## 16. Testy architektoniczne

Co najmniej następujące scenariusze uwzględnij w testach (lokalizacja: `./tests/ModuleContracts/` i `./tests/Integration/`):

1. Uruchomienie modułu samodzielnie bez hosta.
2. Uruchomienie modułu wewnątrz hosta.
3. Otwarcie dwóch instancji tego samego modułu dla dwóch komputerów.
4. Potwierdzenie, że instancje nie współdzielą przypadkowo zmiennego stanu.
5. Umieszczenie widgetów różnych modułów na Dashboardzie.
6. Umieszczenie kilku widgetów powiązanych z różnymi komputerami.
7. Utrata połączenia z jednym komputerem bez zatrzymywania pozostałych widgetów.
8. Anulowanie długotrwałej operacji i poprawne zwolnienie zasobów.
9. Zamknięcie jednej instancji bez wpływu na inne.
10. Odtworzenie konfiguracji Dashboardu po ponownym uruchomieniu.
11. Obsługa niezgodnej wersji modułu lub brakującej zależności.
12. Weryfikacja wymaganych uprawnień przed operacją administracyjną.
13. Wymuszenie potwierdzenia dla operacji klasy Destrukcyjna (zob. 12.1).
14. Pominięcie testów integracyjnych z czytelnym komunikatem, gdy brak pliku celów (zob. 15.5).
15. Wykrycie konfliktu dwóch modułów o tym samym `Id` oraz modułu niezgodnego wersją (zob. 9.1).

## 17. Decyzje architektoniczne

Decyzje dokumentuj w postaci ADR w `./docs/decisions/`, w plikach `ADR-NNN-krótki-tytuł.md`. Numer ADR odpowiada numerowi decyzji (D-001 → ADR-001).

Każdy ADR zawiera: problem, rozważane opcje, kryteria, wybraną opcję, uzasadnienie, konsekwencje i status (Zaproponowany / Przyjęty / Zastąpiony).

| Decyzja | Temat | Status | Uwagi |
|---|---|---|---|
| D-001 | Framework UI | [Robocze] | Kierunek: WPF + XAML z PowerShell (sekcja 13). Wymaga dowodu koncepcji |
| D-002 | Model wykonywania modułów | [Robocze] | Model mieszany: runspace na instancję, osobny proces dla modułów wysokiego ryzyka (sekcja 11) |
| D-003 | Kontrakt modułu i cykl życia instancji | [Robocze] częściowo | Format manifestu `.psd1`; reszta kontraktu otwarta |
| D-004 | Model kontekstu komputera docelowego i połączeń zdalnych | [Robocze] | WinRM + CIM; cel zgodny z PowerShell 5.1 (sekcja 5). Grupa robocza, bez Kerberos; szczegóły uwierzytelniania do weryfikacji (15.5) |
| D-005 | Kontrakt widgetów i zapis konfiguracji Dashboardu | [Otwarte] | Lokalizacja i format plików: sekcja 14.1 [Robocze]. Kontrakt widgetów i schemat pliku układu do ustalenia |
| D-006 | Odkrywanie, instalowanie, aktualizacja i usuwanie modułów | [Robocze] | Manifesty `.psd1` w dwóch folderach, instalacja przez kopiowanie, tylko moduły zaufane (sekcja 9.1). Dystrybucja aplikacji: sekcja 14.2 |
| D-007 | Konfiguracja, logowanie i zarządzanie uprawnieniami | [Robocze] częściowo | Lokalizacja danych: sekcja 14.1. Magazyn sekretów, logowanie i uprawnienia otwarte |
| D-008 | Kontrakt komunikacji host ↔ moduł w osobnym procesie | [Odroczone] | Wersja 1 bez komunikacji międzyprocesowej. Warunek wznowienia i kierunek: sekcja 11 |

Dodatkowe pytania otwarte, które wymagają odpowiedzi właściciela (nie zgaduj):

- Jaki system operacyjny działa na zdalnym komputerze testowym (NAS) i czy ma włączone zdalne zarządzanie (WinRM). Bez tego nie wiadomo, czy aplikacja w ogóle może go obsłużyć (sekcja 15.5).
- Czy zdalny komputer testowy może być obciążany operacjami klasy Zmiana. Obecnie zakazane domyślnie, bo to prawdziwa maszyna z danymi.
- Czy dostępna jest wirtualizacja (np. Hyper-V, którego nie ma w Windows 11 Home) do bezpiecznego testowania operacji klasy Zmiana. Opcjonalne.

## 18. Zalecana kolejność prac

1. **[Przygotowane, niezweryfikowane]** `README.md`, `PSScriptAnalyzerSettings.psd1` i skrypty z sekcji 15.3 istnieją. Pozostaje uruchomić je w PowerShell 7 i potwierdzić, że Pester i PSScriptAnalyzer działają, a potem wpisać ich wersje w `README.md`.
2. Przekształć decyzje [Robocze] D-001–D-004 w ADR (status „Zaproponowany"), a po dowodzie koncepcji w „Przyjęty".
3. Zdefiniuj kontrakt modułu, instancji, kontekstu wykonania i widgetu (`./docs/contracts/`).
4. Przygotuj minimalny host z nawigacją, Dashboardem, ustawieniami i informacją o aplikacji.
5. Zaimplementuj jeden prosty moduł jako dowód koncepcji (propozycja: `Services` w trybie tylko odczyt, bo ma najniższe ryzyko).
6. Uruchom dwie instancje tego samego modułu dla różnych komputerów testowych (z użyciem atrap).
7. Udostępnij ten moduł jako pełny widok i widget Dashboardu.
8. Dodaj samodzielne uruchamianie tego modułu.
9. Przetestuj izolację stanu, obsługę błędów i odświeżanie asynchroniczne.
10. Dopiero potem rozbudowuj bibliotekę modułów administracyjnych.

## 19. Instrukcje dla Claude Code

Pracując nad projektem:

- Roota projektu używaj jako punktu odniesienia dla wszystkich ścieżek (sekcja 0).
- Najpierw przeanalizuj istniejący kod i dokumentację. Zacznij od sekcji 0 (stan repozytorium).
- Nie zakładaj, że propozycje architektoniczne są już zaimplementowane. Nie powołuj się na pliki, skrypty ani polecenia, których nie ma.
- Szanuj status decyzji z sekcji 17: nie traktuj [Roboczych] jako zatwierdzonych, a [Otwartych] rozstrzygaj tylko po pytaniu właściciela.
- Przed wprowadzeniem dużej zmiany przedstaw jej wpływ na architekturę.
- Nie dodawaj zależności bez uzasadnienia.
- Nie implementuj całego projektu w jednym kroku. Preferuj małe, testowalne i spójne zmiany.
- Zachowuj separację UI, logiki aplikacyjnej i integracji systemowej oraz zasady z sekcji 2 i 8.
- Zawsze uwzględniaj wiele instancji tego samego modułu i wiele miejsc prezentacji. Nie twórz ukrytego globalnego kontekstu komputera.
- Traktuj Dashboard jako kompozycję niezależnych widgetów, a nie zbiór specjalnie napisanych ekranów.
- Przestrzegaj zasad pracy z operacjami systemowymi z sekcji 12.2.
- Utrzymuj kompatybilność kontraktów albo dokumentuj wymagane migracje.
- Nie oznaczaj zadania jako ukończonego bez odpowiednich testów lub jasnego wskazania ograniczeń. Jeśli nie możesz uruchomić testów (np. brak PowerShell w środowisku), napisz to wprost.
- Gdy zmieniasz strukturę repozytorium lub status decyzji, zaktualizuj ten plik i dopisz wpis do historii zmian.

**Główna zasada projektu:** My Windows Power ma być platformą do uruchamiania i komponowania niezależnych modułów administracyjnych. Definicja modułu, jego instancja, kontekst komputera i sposób prezentacji to odrębne pojęcia, które muszą być jawnie modelowane w architekturze.

## 20. Historia zmian

- 2026-10-22: dodano katalog główny projektu i stan repozytorium (sekcja 0); statusy decyzji ([Przyjęte]/[Robocze]/[Otwarte]); wersję PowerShell, prefiks `Mwp`, język, format manifestu, transport zdalny, model procesów i kierunek UI jako decyzje robocze; klasyfikację operacji (12.1) i zasady pracy agenta (12.2); polecenia testów i lintowania (15.3) oznaczone jako planowane; test nr 13; skrócono powtórzenia. Poprzednia wersja: `CLAUDE.original.md`.
- 2026-10-22: dodano sekcję 14.1 (lokalizacja danych): domyślnie `./data/` w rootcie, z możliwością zmiany na `%APPDATA%` lub inny folder; zaktualizowano sekcję 0, drzewo w sekcji 14 i tabelę decyzji (D-005, D-007).
- 2026-10-22: przyjęto robocze rozwiązania dla: środowiska testów integracyjnych (15.5), dystrybucji (14.2), lokalizacji interfejsu (15.2), odkrywania modułów (9.1, D-006) i odroczenia D-008 (sekcja 11, nowy status [Odroczone]); dodano testy nr 14 i 15; zastąpiono pytania otwarte nowymi (wirtualizacja, domena, podpisywanie skryptów).
- 2026-10-22: zaktualizowano środowisko testowe (15.5) o dane właściciela: `localhost` i jeden zdalny komputer testowy (prawdziwa maszyna, domyślnie tylko klasa Odczyt), grupa robocza LAN bez domeny (sekcja 5, D-004), podpisywanie skryptów niewymagane (14.2); zaktualizowano pytania otwarte.
- 2026-10-22: dodano `README.md`, `PSScriptAnalyzerSettings.psd1`, `scripts/Invoke-MwpTests.ps1`, `scripts/Invoke-MwpLint.ps1` i `tests/Unit/Repository.Tests.ps1` (krok 1 z sekcji 18); nieuruchomione; zaktualizowano sekcje 0, 14, 15.3 i 18.
