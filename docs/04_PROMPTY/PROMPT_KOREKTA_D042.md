# PROMPT — KOREKTA po FAZIE 4: dziennik startu aplikacji (D-042)

> Wklej całość poniżej linii do NOWEJ rozmowy w Claude Code uruchomionej w głównym folderze repozytorium `mywindowspower`. Uruchom **przed** FAZĄ 5. To nie jest faza: to korekta po FAZIE 4 (jak korekta D-032), z małą zmianą w launcherze i w warstwie UI. Nie zmieniaj statusu żadnej fazy i nie rób nic z zakresu FAZY 5 (Dashboard).

---

Pracujesz nad projektem **mywindowspower**. Odpowiadaj wyłącznie po polsku. Nie pamiętasz poprzednich rozmów; ciągłość niesie dokumentacja w repozytorium. To jest **korekta po FAZIE 4**, a nie nowa faza.

## Start
1. Przeczytaj: `CLAUDE.md`, `docs/02_STAN/STAN_PROJEKTU.md`, `docs/00_PROJEKT/CONTEXT.md`, `docs/00_PROJEKT/ARCHITEKTURA.md`, `docs/00_PROJEKT/DECYZJE.md`, `docs/05_PROCES/PROCEDURA_FAZY.md`, `docs/03_FAZY/FAZA_4_GUI_SZKIELET.md`, `docs/03_FAZY/FAZA_21_WYDANIE.md` oraz kod: `Start-MyWindowsPower.ps1`, `src/UI/UI.ps1`, `src/UI/Wpf/Start-MwpUi.ps1`, `src/UI/Wpf/Update-MwpLogPanel.ps1`, `src/UI/Functions/Read-MwpLogEntry.ps1`, `src/Modules/MWP.Core/Public/Write-MwpLog.ps1`, `tests/Launcher.Tests.ps1`.
2. `git status` i `git log --oneline -10`. Potwierdź, że ostatnim commitem jest FAZA 4 (`c31a5bf`) i że FAZA 4 ma status `ZAKOŃCZONA`. Jeśli `git status` pokazuje dużo zmian, sprawdź `git diff --ignore-cr-at-eol --stat`: jeśli to wyłącznie różnice końców linii (CRLF/LF), nie cofaj ich i nie dodawaj do commita; do commita trafiają tylko pliki zmienione przez tę korektę (`git add` po nazwach). Inne niezacommitowane zmiany zgłoś użytkownikowi, zanim zaczniesz.
3. Sprawdź, że `D-042` jest wolny (ostatni wpis to D-041). Jeśli nie, użyj następnego wolnego numeru i dostosuj odwołania.
4. Nie uzupełniaj hasha FAZY 4 w `CHANGELOG_FAZ.md` ani `STAN_PROJEKTU.md`: robi to start FAZY 5.

## Kontekst decyzji użytkownika (2026-10-26)
Dziś launcher wypisuje informacje startowe tylko w konsoli PowerShella (wersja PowerShella, Windows, tryb STA, administrator, lista modułów `[OK]`, „Zaimportowano moduły: 13.", „Otwieranie okna aplikacji..."). Dane te nie trafiają do dziennika operacji ani do pliku logu, a między „Otwieranie okna aplikacji..." a pojawieniem się okna jest przerwa bez żadnej informacji. Użytkownik zdecydował:
- Dane startowe mają trafiać do **pliku logu** (3 wpisy, żeby nie spowalniać startu) i tym samym do panelu **„Dziennik operacji"** w oknie (panel czyta dzisiejszy plik logu).
- Błędy importu modułów mają trafiać do dziennika z poziomem `Error` i być **widoczne dla użytkownika w oknie komunikatu**, a nie tylko w konsoli. To ważne, bo w wydaniu konsola będzie ukryta (skrót z `-WindowStyle Hidden`, FAZA 21).
- **Pasek postępu / okno startowe (splash)** tylko wtedy, gdy start jest zauważalnie wolny (powyżej ok. 2 s). Najpierw pomiar, potem decyzja.
- **Nie robimy** echa wpisów logu w konsoli ani ustawienia `developerMode`. Konsola launchera zostaje taka, jak dziś (to nie zmienia się w tej korekcie). Ukrycie konsoli w produkcji to sprawa skrótu uruchamiającego w FAZIE 21, nie kodu.
- **Nie zmieniaj `Write-MwpLog` ani innych funkcji `MWP.Core`.** Tylko ich używaj. Każdy zapis do logu czyta plik ustawień, bierze muteks i dopisuje do pliku, więc **liczba wywołań przy starcie ma być mała** (3 wpisy zamiast kilkunastu, patrz punkt 1). Jeśli uznasz, że zmiana w `MWP.Core` jest nieunikniona, zatrzymaj się i zapytaj użytkownika.

## Zadanie

### 1. Dziennik startu (plik logu → panel „Dziennik operacji")
- Launcher zbiera wpisy startowe w pamięci (lista), bo `Write-MwpLog` istnieje dopiero po imporcie `MWP.Core`. Po imporcie `MWP.Core` zapisuje je przez `Write-MwpLog` (źródło `Launcher`, operacje `Startup.*`), zachowując kolejność zdarzeń; jeśli `Write-MwpLog` nie pozwala przekazać czasu zdarzenia, wpisz czas zdarzenia w `Data`.
- Wpisy (poziom `Info`, o ile nie zaznaczono inaczej). **Stała liczba wywołań `Write-MwpLog` przy zdrowym starcie: 3**, plus po jednym wpisie `Error` na każdy moduł, który się nie załadował:
  1. `Startup.Environment` — jedno zdarzenie z `Data`: wersja i edycja PowerShella, wersja Windows, `IsWindows11`, tryb wątku (STA), administrator (tak/nie), `HostPath`, folder aplikacji, parametry launchera (`-Elevate`, `-NoGui`, `-NoRelaunch`), a jeśli launcher uruchomił się ponownie w trybie STA, także ten fakt i jego powód (`Warning` zamiast `Info` w takim przypadku). Użyj `Get-MwpEnvironment`, gdy `MWP.Core` jest już załadowany, a przed tym danych z `Get-LauncherEnvironment`.
  2. `Startup.Modules` — jedno podsumowanie. Komunikat czytelny w panelu, np. „Załadowano 13 modułów (1 z paczki) w 840 ms". W `Data` lista modułów: nazwa, wersja, źródło (`Built-in`/`Installed`), czas importu w ms, status.
  3. `Startup.Window` — czas od startu launchera do pokazania okna z podziałem na etapy (patrz punkt 3). Zapisywany po pokazaniu okna; to jedyny wpis zapisywany później niż reszta.
  - Dodatkowo `Startup.Module` na poziomie **`Error`** dla każdego modułu z błędem importu lub niepoprawnym kontraktem: nazwa modułu w komunikacie, treść błędu i lista błędów kontraktu w `Data`. Dzięki temu błąd jest osobnym wierszem w panelu i łapie go filtr „Tylko ostrzeżenia i błędy".
- Wpisy 1 i 2 zapisz jedną serią tuż po imporcie pozostałych modułów (opóźnienie względem zdarzeń jest rzędu setek milisekund, więc **nie dodawaj parametru czasu do `Write-MwpLog`**; jeśli chcesz, wpisz czas zdarzenia w `Data`).
- Istniejący wpis `UI.Start` w `Start-MwpUi` zostaje (skróć jego komunikat, jeśli dubluje wersję PowerShella).
- Panel logu: sprawdź, że wpisy startowe są w nim czytelne (kolumny: czas, poziom, komputer, źródło, operacja, komunikat; szczegóły modułów są w `Data`, a komunikat podsumowania musi wystarczyć w panelu) i że filtr „Tylko ostrzeżenia i błędy" pokazuje błędy importu modułów.
- Plik logu jako zabezpieczenie przed awarią: jeśli `MWP.Core` się nie zaimportuje, `Write-MwpLog` nie istnieje. W tym jednym przypadku launcher zapisuje minimalny wpis błędu (jedna linia JSON Lines: `timestamp`, `level`, `operation`, `message`) do `%LOCALAPPDATA%\MyWindowsPower\logs\mwp-startup-failure.log` (katalog zapasowy zgodnie z D-032), bez sekretów. Nie twórz tego pliku w innych sytuacjach.
- Koszt logowania: `Write-MwpLog` czyta ustawienia przy każdym wpisie (znany dług techniczny: brak pamięci podręcznej ustawień). Zmierz czas zapisu wpisów startowych (wchodzi do pomiaru w punkcie 3); jeśli przekracza 150 ms, zgłoś to użytkownikowi i zaproponuj osobną korektę z pamięcią podręczną ustawień, ale nie rób jej w tej korekcie.
- Bezpieczeństwo: wpisy startowe nie mogą zawierać sekretów, haseł ani poświadczeń; `Data` przechodzi przez istniejący filtr (`ConvertTo-MwpLogSafeData`), a nie omijaj go.

### 2. Błędy startu widoczne dla użytkownika
- Gdy import `MWP.Core` lub dowolnego modułu się nie powiedzie (dziś: komunikat w konsoli i `exit 1`), zachowaj kod wyjścia 1 i dotychczasową treść w konsoli, a dodatkowo (tylko gdy nie podano `-NoGui`) pokaż okno komunikatu systemowego (`System.Windows.MessageBox` po `Add-Type -AssemblyName PresentationFramework`) z nazwą modułu, treścią błędu i ścieżką pliku logu. W trybie `-NoGui` okno komunikatu się nie pojawia (testy).
- Nie zmieniaj semantyki „moduł z błędnym kontraktem nie jest ładowany" ani kodów wyjścia; nie wprowadzaj trybu „działaj bez uszkodzonego modułu". Jeśli uznasz go za sensowny, zapisz jako otwarte pytanie w `STAN_PROJEKTU.md`.
- Błąd uruchomienia samego okna („Nie udało się otworzyć okna aplikacji") trafia do logu na poziomie `Error` (`Startup.Window`) i do okna komunikatu.

### 3. Pomiar i warunkowe okno startowe (splash)
1. Dodaj do launchera pomiar czasu (`[Diagnostics.Stopwatch]`) i wpis `Startup.Window` z etapami: środowisko, import `MWP.Core`, import pozostałych modułów, budowa okna (do `ContentRendered` okna głównego). Czas „do okna" wylicz bez zmieniania sygnatur publicznych funkcji `MWP.UI` ponad konieczność (np. opcjonalny parametr `StartTicks` w `UI.ps1`/`Start-MwpUi` albo wpis zapisany w `Start-MwpUi` po pierwszym wyświetleniu okna).
2. Zmierz start trzy razy (nowy proces, `.\Start-MyWindowsPower.ps1`, okno zamykane ręcznie lub automatycznym testem dymnym z FAZY 4, bez zmian ustawień i systemu) w PowerShell 5.1 i 7.x. Podaj w raporcie etapy i medianę „do okna". Jeśli nie możesz uruchomić okna (brak Windows lub sesji interaktywnej), poproś użytkownika o trzy uruchomienia i odczyt `Startup.Window` z dzisiejszego pliku logu; do tego czasu nie wprowadzaj splasha.
3. **Reguła decyzji:** mediana ≤ 2000 ms → splash **nie jest wdrażany**; zapisz pomiar i decyzję w `D-042`. Mediana > 2000 ms → wdróż splash:
   - małe okno WPF bez ramki, na środku ekranu, z nazwą aplikacji, wersją hosta, paskiem postępu i linią statusu („Ładowanie modułów (7/13)…", „Przygotowanie okna…"), w motywie zgodnym z ustawieniem `theme`;
   - pokazane po sprawdzeniu STA, przed importem modułów, w tym samym wątku STA; postęp aktualizowany między krokami (kolejka dyspozytora w kodzie PowerShella), bez drugiego wątku WPF;
   - ograniczenie do opisania w `ARCHITEKTURA.md`: gdy jeden krok blokuje wątek (np. budowa XAML), animacja paska stoi, więc pasek ma być „krokowy" (wartość = liczba ukończonych kroków), a nie animowany;
   - zamykany po pierwszym wyświetleniu okna głównego (`ContentRendered`) albo przy błędzie; nie zostawia procesu ani okna w tle;
   - nie jest pokazywany z `-NoGui` ani w testach Pester;
   - błąd samego splasha nie blokuje startu aplikacji (tylko ostrzeżenie w logu).
   Dodaj testy statyczne (parsowanie XAML splasha, kodowanie UTF-8 z BOM, brak splasha przy `-NoGui`).

### 4. Dokumentacja
- **`DECYZJE.md`** — na końcu dodaj wpis w formacie tabeli (ID | Data | Faza | Decyzja | Uzasadnienie | Status), bez edycji starych:
  `D-042 | 2026-10-26 | 4 (korekta) | Dziennik startu aplikacji. Launcher zapisuje dane startowe (środowisko, STA, administrator, wersje; moduły z czasem importu i źródłem; czas do pokazania okna) w dzienniku operacji przez Write-MwpLog (źródło Launcher, operacje Startup.*), w trzech wpisach (Startup.Environment, Startup.Modules ze szczegółami modułów w Data, Startup.Window) plus osobny wpis Error na każdy wadliwy moduł, żeby ograniczyć liczbę zapisów (każdy zapis czyta ustawienia i bierze muteks); Write-MwpLog bez zmian, czas zdarzeń w Data. Dane są widoczne w panelu „Dziennik operacji”; błędy importu modułów mają poziom Error i pokazują okno komunikatu (potrzebne przy ukrytej konsoli w wydaniu). Awaryjny plik mwp-startup-failure.log w katalogu zapasowym (D-032) tylko gdy MWP.Core się nie zaimportuje. Okno startowe (splash) tylko przy medianie czasu startu > 2000 ms; pomiar: <wpisz wynik>, decyzja: <wdrożono / niewdrożono>. Odrzucone: echo wpisów logu w konsoli, ustawienie developerMode i zmiana Write-MwpLog (panel logu i plik wystarczają, zmiana w MWP.Core niewarta ryzyka); pamięć podręczna ustawień jako osobna korekta, jeśli koszt zapisu logu przekroczy 150 ms. Konsola launchera bez zmian; jej ukrycie w wydaniu załatwia skrót z -WindowStyle Hidden (FAZA 21). | Wymaganie użytkownika (2026-10-26) | Obowiązuje`
- **`ARCHITEKTURA.md`:** dopisz krótko w sekcji o launcherze/logowaniu: operacje `Startup.*`, plik awaryjny, okno komunikatu przy błędzie startu i (jeśli wdrożono) splash z jego ograniczeniami.
- **`FAZA_4_GUI_SZKIELET.md`:** w sekcji wyników dopisz jedną linię o tej korekcie (bez zmiany statusu). **`STAN_PROJEKTU.md`:** zaktualizuj datę, usuń lub oznacz jako zrobioną pozycję o korekcie dziennika startu w „Co zostało do zrobienia", dopisz korektę w „Co zostało zrobione" i wynik testów; dodaj do „Do weryfikacji na Windows 11": panel logu po starcie, błąd modułu z paczki widoczny w oknie komunikatu. **`CHANGELOG_FAZ.md`:** wpis korekty na górze (wzór: korekta D-032), bez zmiany numeracji faz.
- **`FAZA_21_WYDANIE.md`** zawiera już punkt o skrócie z ukrytą konsolą (dopisany przed tą korektą); nie duplikuj go, tylko sprawdź, że jest spójny z D-042.

### 5. Testy i weryfikacja
- Pester: (a) `Launcher.Tests.ps1`: z `-NoGui` konsola wypisuje dotychczasowe komunikaty (testy już na nich polegają), a w logu kopii aplikacji (w `TestDrive`, nie w prawdziwym `data\` ani `config\`) są wpisy `Startup.Environment` i `Startup.Modules` (odczyt przez `Read-MwpLogEntry`; w `Data` szczegóły modułów, dokładnie 2 wpisy `Startup.*` przy `-NoGui` bez błędów, bo `Startup.Window` powstaje dopiero przy oknie); (b) wadliwy moduł z paczki daje osobny wpis `Startup.Module` na poziomie `Error` i kod wyjścia 1; (c) brak sekretów w `Data` wpisów startowych; (d) awaryjny plik tylko przy nieudanym imporcie `MWP.Core` (kopia aplikacji z uszkodzonym `MWP.Core`, `LOCALAPPDATA` przekierowane na katalog tymczasowy testu).
- Testy nie mogą zapisywać do prawdziwego `data\`, `config\` ani `%LOCALAPPDATA%\MyWindowsPower` użytkownika (wzorzec z korekty D-032).
- Pliki `.ps1`/`.psm1`/`.psd1`/`.xaml` zapisuj w UTF-8 z BOM (test `Repository.Tests.ps1`).
- Uruchom `.\tests\Invoke-Checks.ps1` w PowerShell 5.1 i 7.x (nowy proces dla każdej wersji). Wymagane: 0 uwag analizatora i wszystkie testy zaliczone (baza: 922/922; podaj nową liczbę). Jeśli coś zawiedzie, napraw to, co wynika z tej korekty; nie ruszaj niezwiązanego kodu.
- Ręcznie lub testem dymnym (bez zmian w systemie): uruchom aplikację, otwórz panel „Dziennik operacji" i potwierdź, że wpisy `Startup.*` są widoczne; sprawdź filtr błędów na sztucznie uszkodzonym module z paczki w kopii aplikacji (nie w prawdziwym katalogu użytkownika).

## Zamknięcie
Wykonaj commit: `FAZA 4 (korekta): dziennik startu aplikacji (D-042)`. Nie wykonuj `git push` bez wyraźnej zgody użytkownika w rozmowie. Napisz krótki raport: co zmieniono, wyniki pomiaru czasu startu i decyzja o splashu, wynik testów (5.1 i 7.x), punkty do ręcznej weryfikacji. Zapowiedz: „Następna faza: FAZA 5 — Dashboard. Prompt: `docs/04_PROMPTY/PROMPT_FAZA_5.md`. Otwórz nową rozmowę w Claude Code."
