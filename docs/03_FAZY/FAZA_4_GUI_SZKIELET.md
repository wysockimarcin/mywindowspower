# FAZA 4 — Szkielet GUI i host modułów

**Status:** DO ZROBIENIA

## Cel
Okno aplikacji WPF będące hostem modułów: nawigacja, motywy, bezpieczne wykonywanie operacji w tle oraz zarządzanie instancjami modułów dla komputera lokalnego i zdalnych. Bez funkcji obszarów (widoki-zaślepki).

## Zależności
FAZY 1, 2 i 3 zakończone.

## Zakres
- **Wzorzec wyglądu:** obejrzyj `docs/design/mockup-pulpit.png` (mockup głównego okna dostarczony przez użytkownika) i zaprojektuj układ zgodnie z nim. Odstępstwa od mockupu zapisz w `DECYZJE.md`. Jeśli pliku brakuje lub jest nieczytelny, zapytaj użytkownika.
- `src/UI/MainWindow.xaml`: lewy panel nawigacji (po jednej pozycji na obszar), kontener widoku, pasek stanu (administrator tak/nie, wersja PowerShella, wersja Windows), panel logu.
- `src/UI/UI.ps1`: ładowanie XAML (`XamlReader`), mapowanie nazwanych kontrolek, nawigacja między widokami.
- Motywy `Themes/Light.xaml` i `Themes/Dark.xaml` (słowniki zasobów), domyślnie zgodnie z systemem (`AppsUseLightTheme` w `HKCU\...\Themes\Personalize`), ręczny przełącznik zapamiętywany w konfiguracji.
- Pomocnik wykonywania w tle (runspace pool + `Dispatcher`): uruchomienie zadania, pasek postępu, anulowanie, bezpieczna aktualizacja UI z innego wątku.
- Widoki-zaślepki `.xaml` dla każdego obszaru.
- Wspólne style: przyciski, tabele (DataGrid), nagłówki, ostrzeżenia o zmianach systemowych, okno potwierdzenia ze „Podglądem zmian".
- Obsługa skalowania DPI i minimalnego rozmiaru okna.
- Zgodność z PS 5.1 i 7.x (różnice ładowania assembly `PresentationFramework`).
- **Host modułów (D-019, D-020):** pozycje nawigacji `Pulpit` (Dashboard, FAZA 5), obszary, `Ustawienia`, `O programie`. Host wykrywa i ładuje moduły (kontrakt z FAZY 2) i zarządza instancjami (model z FAZY 3): lista otwartych instancji, wielokrotne otwieranie tego samego modułu dla różnych komputerów (np. „Usługi — localhost" i „Usługi — komputer zdalny"), zamknięcie jednej instancji bez wpływu na inne. Host nie zawiera logiki obszarów.
- **Wybór komputera docelowego** z rejestru komputerów (FAZA 3) przy otwieraniu instancji — wspólny komponent; pasek stanu pokazuje komputer i stan połączenia instancji. Błąd lub utrata połączenia jest sygnalizowana w widoku danej instancji, nie jako błąd całej aplikacji.
- **Tryby prezentacji:** Embedded view (w oknie głównym) i Separate window (osobne okno instancji). Widget Dashboardu → FAZA 5, Standalone i CLI → FAZA 19. Logika modułu nie zależy od miejsca prezentacji.
- Widoki `Ustawienia` (motyw, lista komputerów docelowych: dodawanie, edycja, usuwanie, zgodnie z decyzją o uwierzytelnianiu z FAZY 3) i `O programie`.
- **Widok „Moduły" (D-031):** lista modułów wbudowanych i zainstalowanych (nazwa, `Id`, wersja, pochodzenie, stan walidacji); instalacja z pliku `.mwpmod` (wybór pliku, `Test-MwpModulePackage`, okno potwierdzenia z nazwą, wersją, `RequiredPermissions` i SHA-256 paczki, potem `Install-MwpModulePackage`); odinstalowanie modułu zainstalowanego z potwierdzeniem zawierającym jego nazwę (`Uninstall-MwpModulePackage`; zamyka otwarte instancje). Moduły bazowe i wbudowane bez przycisku odinstalowania. Logika instalacji jest w `MWP.Core` (FAZA 3), nie w kodzie widoku; długie operacje w tle.

## Poza zakresem
Logika i dane obszarów, widgety Dashboardu (FAZA 5), uruchamianie samodzielne (FAZA 19).

## Checklista
- [ ] Mockup `docs/design/mockup-pulpit.png` obejrzany, układ zgodny lub odstępstwa opisane w `DECYZJE.md`
- [ ] `MainWindow.xaml` z nawigacją i paskiem stanu
- [ ] `UI.ps1`: ładowanie XAML i nawigacja
- [ ] Motyw jasny i ciemny, wykrywanie motywu systemu, przełącznik
- [ ] Pomocnik zadań w tle z postępem i anulowaniem
- [ ] Widoki-zaślepki dla wszystkich obszarów
- [ ] Host: wykrywanie modułów, lista instancji, wielokrotne instancje tego samego modułu, zamknięcie bez wpływu na inne
- [ ] Wybór komputera docelowego per instancja, stan połączenia w pasku stanu i w widoku instancji
- [ ] Tryby Embedded i Separate window
- [ ] Widoki `Ustawienia` (w tym komputery docelowe) i `O programie`
- [ ] Widok „Moduły": lista wbudowanych i zainstalowanych, instalacja z `.mwpmod` z oknem potwierdzenia (nazwa, wersja, uprawnienia, SHA-256), odinstalowanie z potwierdzeniem nazwą modułu (D-031)
- [ ] Wspólne style i okno potwierdzenia z podglądem zmian
- [ ] Launcher uruchamia okno GUI
- [ ] Analiza statyczna i testy logiki (nie GUI) przechodzą
- [ ] Dokumentacja zaktualizowana, commit `FAZA 4: ...`

## Kryteria ukończenia
Okno startuje w 5.1 i 7.x, motyw się przełącza, długie zadanie testowe nie zawiesza GUI, dwie instancje tego samego widoku-zaślepki działają niezależnie dla dwóch komputerów, moduł z paczki `.mwpmod` da się zainstalować i odinstalować z widoku „Moduły".

## Do weryfikacji na Windows 11
Całe GUI (wygląd, motywy, responsywność, DPI, instancje i osobne okna, utrata połączenia z jednym komputerem, instalacja i odinstalowanie modułu w widoku „Moduły") — wymaga ręcznego uruchomienia na Windows 11.

## Wyniki
(wypełnia Claude po zakończeniu fazy)

## Następna faza
FAZA 5 — Dashboard. Prompt: `docs/04_PROMPTY/PROMPT_FAZA_5.md`.
