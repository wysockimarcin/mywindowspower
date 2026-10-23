# CLAUDE.md — My Windows Power

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

1. **Separation of concerns** — oddzielaj UI, logikę aplikacyjną, dostęp do danych i integrację z systemem.
2. **Modularność** — funkcjonalności administracyjne powinny być niezależnymi modułami.
3. **Wieloinstancyjność** — jedna definicja modułu może mieć wiele niezależnych instancji.
4. **Jawny kontekst wykonania** — każda instancja powinna wiedzieć, dla jakiego komputera i z jakimi uprawnieniami działa.
5. **Niezależność od miejsca prezentacji** — logika modułu nie może zależeć od tego, czy moduł działa na Dashboardzie, w głównym oknie, czy w osobnym oknie.
6. **Wielokrotne wykorzystanie logiki** — te same usługi aplikacyjne powinny być używane przez UI, Dashboard i CLI.
7. **Odporność na błędy** — niedostępność jednego komputera lub modułu nie może blokować całej aplikacji.
8. **Bezpieczeństwo domyślne** — nie wykonuj uprzywilejowanych operacji bez jawnej autoryzacji i kontroli uprawnień.
9. **Brak blokowania UI** — operacje sieciowe, zdalne i długotrwałe wykonuj asynchronicznie.
10. **Minimalizacja sprzężeń** — moduły nie powinny zależeć bezpośrednio od wewnętrznych implementacji hosta ani innych modułów.

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

Host nie powinien zawierać szczegółowej logiki poszczególnych funkcji administracyjnych.

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

### 4.1. Definicja modułu a instancja modułu

**Definicja modułu nie jest jego instancją.** Definicja opisuje funkcjonalność, a instancja jest konkretnym uruchomieniem tej funkcjonalności w określonym kontekście.

Przykład: moduł `Services` może mieć jednocześnie dwie instancje:

- `Services — COMPUTER-01`
- `Services — COMPUTER-02`

Obie instancje korzystają z tej samej implementacji modułu, ale mają niezależne konteksty, stan widoku, parametry, status połączenia i cykl życia.

Wymagania:

- Jedna definicja modułu może mieć wiele instancji.
- Każda instancja musi mieć własny identyfikator.
- Instancja musi posiadać jawny kontekst wykonania.
- Stan instancji nie może być przypadkowo współdzielony z inną instancją.
- Zmiana komputera docelowego w jednej instancji nie może zmieniać kontekstu innych instancji.
- Zamknięcie jednej instancji nie może zamykać pozostałych.
- Instancje mogą współdzielić bezpieczne, niemodyfikowalne zasoby, jeśli zasady współdzielenia są jawnie zdefiniowane.
- Sesje zdalne i zasoby zależne od uprawnień muszą być zarządzane zgodnie z określonym zakresem i cyklem życia.

## 5. Kontekst wykonania i komputer docelowy

Nie zakładaj, że moduł zawsze działa na komputerze lokalnym.

Kontekst wykonania powinien umożliwiać określenie co najmniej:

- Komputera docelowego.
- Trybu lokalnego lub zdalnego.
- Tożsamości lub kontekstu uwierzytelnienia, jeśli jest wymagany.
- Stanu połączenia.
- Parametrów specyficznych dla modułu.
- Polityki czasu oczekiwania i obsługi błędów.

Sposób połączenia należy dobierać do wymagań funkcji. Nie wszystkie moduły muszą korzystać z tego samego transportu ani mechanizmu zdalnego wykonania.

Oddziel:

- Reprezentację komputera docelowego.
- Nawiązywanie i utrzymywanie połączenia.
- Wykonywanie operacji administracyjnych.
- Prezentację stanu połączenia w UI.

Błędy połączenia muszą być obsługiwane na poziomie konkretnego kontekstu lub instancji, a nie jako błąd całego hosta.

## 6. Tryby prezentacji i uruchamiania modułów

Moduł powinien deklarować, które tryby obsługuje:

1. **Embedded view** — widok wewnątrz głównego okna hosta.
2. **Separate window** — widok w osobnym oknie.
3. **Dashboard widget** — uproszczony widok danych na Dashboardzie.
4. **Standalone** — samodzielne uruchomienie bez hosta.
5. **CLI** — uruchomienie z linii poleceń, jeśli moduł obsługuje taki scenariusz.

Nie każdy moduł musi obsługiwać wszystkie tryby.

Ważne zasady:

- Miejsce prezentacji nie może określać logiki biznesowej modułu.
- Widoki mogą być różne dla poszczególnych trybów, ale powinny korzystać ze wspólnych usług aplikacyjnych.
- Moduł uruchamiany samodzielnie nie może wymagać załadowania całego hosta.
- Jeśli wymagane są usługi hosta, moduł powinien korzystać z jawnego kontraktu lub samodzielnej implementacji zgodności.
- Tryb samodzielny nie może niejawnie omijać zabezpieczeń, walidacji ani kontroli uprawnień.

## 7. Dashboard — kompozycja wielu widoków

Dashboard to konfigurowalna przestrzeń robocza, która pozwala użytkownikowi umieszczać wiele widoków modułów i monitorować różne komputery jednocześnie.

Przykładowy układ:

- Status usług na `COMPUTER-01`.
- Wykorzystanie dysków na `COMPUTER-02`.
- Informacje o systemie lokalnym.
- Status połączenia RDP z innym komputerem.

Każdy widget musi mieć własną konfigurację oraz jawne powiązanie z instancją modułu lub źródłem danych.

Dashboard powinien obsługiwać:

- Dodawanie i usuwanie widgetów.
- Konfigurację komputera docelowego dla każdego widgetu.
- Konfigurację parametrów modułu.
- Zmianę rozmiaru i położenia widgetów, jeśli obsługuje to wybrany model UI.
- Ręczne i automatyczne odświeżanie danych.
- Widok ładowania, błędu, braku danych i utraty połączenia.
- Zapisywanie i odtwarzanie konfiguracji użytkownika.
- Niezależne działanie widgetów.

### 7.1. Izolacja widgetów

- Błąd jednego widgetu nie może blokować pozostałych.
- Utrata połączenia z jednym komputerem nie może zatrzymywać odświeżania danych z innych komputerów.
- Każdy widget powinien mieć własny stan prezentacji i status operacji.
- Częstotliwość odświeżania musi być kontrolowana.
- Usuwany widget powinien zwalniać zasoby, anulować zbędne zadania i poprawnie kończyć subskrypcje.
- Nie wykonuj nieograniczonej liczby równoległych zadań w tle.
- Dashboard powinien korzystać z tych samych usług aplikacyjnych co pełne widoki modułów.

Nie zakładaj, że widget jest wyłącznie miniaturowym oknem. Powinien być osobnym kontraktem prezentacji danych, który może wykorzystywać logikę istniejącego modułu.

## 8. Separacja UI i backendu

Stosuj logiczny podział na warstwy:

1. **UI / View** — wyświetlanie danych i obsługa interakcji.
2. **Presentation Logic / ViewModel** — stan widoku, polecenia, walidacja prezentacyjna i reakcje na zdarzenia.
3. **Application Services** — przypadki użycia, orkiestracja operacji i reguły aplikacyjne.
4. **System / Remote Adapters** — integracja z PowerShell, Windows API, zdalnym komputerem i transportem.
5. **Operating System / Remote Target** — rzeczywisty system, na którym wykonywana jest operacja.

Dostosuj ten podział do możliwości wybranego frameworka, ale zachowaj separację odpowiedzialności.

Zabronione wzorce:

- Wywoływanie poleceń administracyjnych bezpośrednio z obsługi kliknięcia w UI.
- Umieszczanie logiki połączeń zdalnych w kodzie widoku.
- Bezpośrednie odczytywanie i modyfikowanie kontrolek UI z warstwy backendu.
- Uzależnianie logiki aplikacyjnej od konkretnego okna lub widgetu.
- Przechowywanie globalnego, zmiennego kontekstu komputera, który jest niejawnie używany przez wszystkie moduły.

## 9. Kontrakt modułu

Każdy moduł powinien mieć manifest opisujący jego tożsamość, zależności i możliwości.

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

Nazwy i typy pól należy potwierdzić w specyfikacji kontraktu przed wdrożeniem.

Kontrakt modułu powinien określać:

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

## 10. Samodzielne uruchamianie

Moduły powinny być możliwe do uruchamiania bez głównego hosta, jeśli deklarują obsługę tego trybu.

Docelowa składnia może wyglądać następująco:

```powershell
apprun "Services"
apprun "Services" -ComputerName "COMPUTER-01"
```

To przykładowy interfejs, a nie zatwierdzona implementacja.

Samodzielny launcher powinien:

- Znaleźć i zweryfikować moduł.
- Sprawdzić zależności.
- Przekazać parametry i kontekst wykonania.
- Uruchomić właściwy interfejs lub tryb CLI.
- Zachować walidację, autoryzację i logowanie.
- Zwracać czytelne błędy w przypadku braku modułu lub zależności.

Nie twórz osobnej implementacji logiki biznesowej wyłącznie na potrzeby samodzielnego uruchamiania.

## 11. Model procesów i współbieżność

Przed implementacją należy rozstrzygnąć, czy moduły będą wykonywane:

- W procesie hosta.
- W oddzielnym procesie.
- W modelu mieszanym, zależnym od wymagań modułu.

Nie zakładaj z góry, że każdy moduł musi działać w osobnym procesie.

Decyzja powinna uwzględniać:

- Izolację awarii.
- Koszt pamięci i uruchamiania.
- Bezpieczeństwo i zakres uprawnień.
- Współdzielenie usług i danych.
- Integrację z UI.
- Obsługę wielu instancji.
- Możliwość uruchomienia modułu bez hosta.
- Komunikację między procesami, jeśli jest potrzebna.

Długotrwałe zadania, odświeżanie Dashboardu i operacje zdalne muszą być wykonywane bez blokowania interfejsu.

Każda operacja powinna mieć określone zasady anulowania, limitów czasu, obsługi błędów i zwalniania zasobów.

## 12. Bezpieczeństwo

- Nie przechowuj haseł ani sekretów w jawnym tekście.
- Nie traktuj samej obecności użytkownika w aplikacji jako dowodu uprawnień administracyjnych.
- Stosuj najmniejsze wymagane uprawnienia.
- Weryfikuj parametry przekazywane do poleceń i operacji systemowych.
- Nie buduj poleceń PowerShell przez niekontrolowane łączenie tekstu wejściowego.
- Rozróżniaj uwierzytelnienie, autoryzację i dostępność połączenia.
- Informuj użytkownika o operacjach zmieniających konfigurację lub stan systemu.
- Wymagaj odpowiednich potwierdzeń dla operacji potencjalnie destrukcyjnych.
- Rejestruj istotne zdarzenia administracyjne bez zapisywania sekretów.
- Nie osłabiaj zabezpieczeń Windows w celu uproszczenia integracji.

## 13. UI i wybór technologii

Framework UI pozostaje decyzją architektoniczną, którą należy podjąć przed budową pełnego interfejsu.

Porównaj rozwiązania pod kątem:

- Integracji z PowerShell.
- Obsługi Windows 11.
- Wspierania wzorca MVVM lub równoważnego.
- Osadzania widoków modułów.
- Tworzenia osobnych okien.
- Komponowania Dashboardu.
- Dostępności i skalowania UI.
- Obsługi zadań asynchronicznych.
- Testowalności.
- Łatwości wdrażania i utrzymania.

Nie wiąż kontraktu modułu z konkretnym frameworkiem UI, dopóki nie zostanie on zatwierdzony.

## 14. Struktura repozytorium

Proponowana struktura początkowa:

```text
MyWindowsPower/
├── CLAUDE.md
├── README.md
├── docs/
│   ├── architecture/
│   ├── decisions/
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
│   ├── Integration/
│   └── ModuleContracts/
└── scripts/
```

To propozycja, którą można dostosować po zatwierdzeniu frameworka UI i modelu procesów.

## 15. Standardy PowerShell i jakość

- Stosuj czytelne nazwy funkcji i zmiennych.
- Używaj zatwierdzonych konwencji nazewniczych PowerShell.
- Dodawaj jawne typy tam, gdzie poprawiają czytelność i bezpieczeństwo.
- Rozdzielaj funkcje publiczne i wewnętrzne.
- Obsługuj błędy w sposób przewidywalny.
- Unikaj globalnego stanu i niejawnych zależności.
- Dokumentuj publiczne interfejsy.
- Wprowadzaj testy jednostkowe i integracyjne.
- Używaj Pester do testów i PSScriptAnalyzer do analizy statycznej.
- Testuj moduły niezależnie od hosta.
- Testuj wiele instancji tego samego modułu działających jednocześnie.
- Testuj awarie i utratę połączenia z komputerami docelowymi.

## 16. Testy architektoniczne

Co najmniej następujące scenariusze powinny zostać uwzględnione w testach:

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

## 17. Decyzje architektoniczne do zatwierdzenia

Przed rozpoczęciem pełnej implementacji udokumentuj decyzje w postaci ADR (Architecture Decision Records).

- **D-001:** Framework UI.
- **D-002:** Model wykonywania modułów — jeden proces, osobne procesy czy model mieszany.
- **D-003:** Kontrakt modułu i cykl życia instancji.
- **D-004:** Model kontekstu komputera docelowego i połączeń zdalnych.
- **D-005:** Kontrakt widgetów oraz zapis konfiguracji Dashboardu.
- **D-006:** Mechanizm odkrywania, instalowania, aktualizacji i usuwania modułów.
- **D-007:** Konfiguracja, logowanie i zarządzanie uprawnieniami.
- **D-008:** Kontrakt komunikacji między hostem i modułem uruchomionym w osobnym procesie.

Każda decyzja powinna zawierać problem, rozważane opcje, kryteria, wybraną opcję, uzasadnienie i konsekwencje.

## 18. Zalecana kolejność prac

1. Zatwierdź architekturę v1 i kluczowe decyzje ADR.
2. Wybierz framework UI oraz model wykonywania modułów.
3. Zdefiniuj kontrakt modułu, instancji, kontekstu wykonania i widgetu.
4. Przygotuj minimalny host z nawigacją, Dashboardem, ustawieniami i informacją o aplikacji.
5. Zaimplementuj jeden prosty moduł jako dowód koncepcji.
6. Uruchom dwie instancje tego samego modułu dla różnych komputerów testowych.
7. Udostępnij ten moduł jako pełny widok i widget Dashboardu.
8. Dodaj samodzielne uruchamianie tego modułu.
9. Przetestuj izolację stanu, obsługę błędów i odświeżanie asynchroniczne.
10. Dopiero potem rozbudowuj bibliotekę modułów administracyjnych.

## 19. Instrukcje dla Claude Code

Pracując nad projektem:

- Najpierw przeanalizuj istniejący kod i dokumentację.
- Nie zakładaj, że propozycje architektoniczne są już zaimplementowane.
- Przed wprowadzeniem dużej zmiany przedstaw jej wpływ na architekturę.
- Nie dodawaj zależności bez uzasadnienia.
- Nie implementuj całego projektu w jednym kroku.
- Preferuj małe, testowalne i spójne zmiany.
- Zachowuj separację UI, logiki aplikacyjnej i integracji systemowej.
- Nie twórz ukrytego globalnego kontekstu komputera.
- Zawsze uwzględniaj możliwość istnienia wielu instancji tego samego modułu.
- Nie zakładaj, że moduł ma tylko jeden widok lub jedno miejsce prezentacji.
- Traktuj Dashboard jako kompozycję niezależnych widgetów, a nie zbiór specjalnie napisanych ekranów.
- Utrzymuj kompatybilność kontraktów albo dokumentuj wymagane migracje.
- Nie oznaczaj zadania jako ukończonego bez odpowiednich testów lub jasnego wskazania ograniczeń.

**Główna zasada projektu:** My Windows Power ma być platformą do uruchamiania i komponowania niezależnych modułów administracyjnych. Definicja modułu, jego instancja, kontekst komputera i sposób prezentacji to odrębne pojęcia, które muszą być jawnie modelowane w architekturze.
