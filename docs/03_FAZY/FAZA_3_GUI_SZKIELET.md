# FAZA 3 — Szkielet GUI

**Status:** DO ZROBIENIA

## Cel
Okno aplikacji WPF z nawigacją, motywami i bezpiecznym wykonywaniem operacji w tle. Bez funkcji obszarów (widoki-zaślepki).

## Zależności
FAZY 1 i 2 zakończone.

## Zakres
- `src/UI/MainWindow.xaml`: lewy panel nawigacji (po jednej pozycji na obszar), kontener widoku, pasek stanu (administrator tak/nie, wersja PowerShella, wersja Windows), panel logu.
- `src/UI/UI.ps1`: ładowanie XAML (`XamlReader`), mapowanie nazwanych kontrolek, nawigacja między widokami.
- Motywy `Themes/Light.xaml` i `Themes/Dark.xaml` (słowniki zasobów), domyślnie zgodnie z systemem (`AppsUseLightTheme` w `HKCU\...\Themes\Personalize`), ręczny przełącznik zapamiętywany w konfiguracji.
- Pomocnik wykonywania w tle (runspace pool + `Dispatcher`): uruchomienie zadania, pasek postępu, anulowanie, bezpieczna aktualizacja UI z innego wątku.
- Widoki-zaślepki `.xaml` dla każdego obszaru.
- Wspólne style: przyciski, tabele (DataGrid), nagłówki, ostrzeżenia o zmianach systemowych, okno potwierdzenia ze „Podglądem zmian".
- Obsługa skalowania DPI i minimalnego rozmiaru okna.
- Zgodność z PS 5.1 i 7.x (różnice ładowania assembly `PresentationFramework`).

## Poza zakresem
Logika i dane obszarów.

## Checklista
- [ ] `MainWindow.xaml` z nawigacją i paskiem stanu
- [ ] `UI.ps1`: ładowanie XAML i nawigacja
- [ ] Motyw jasny i ciemny, wykrywanie motywu systemu, przełącznik
- [ ] Pomocnik zadań w tle z postępem i anulowaniem
- [ ] Widoki-zaślepki dla wszystkich obszarów
- [ ] Wspólne style i okno potwierdzenia z podglądem zmian
- [ ] Launcher uruchamia okno GUI
- [ ] Analiza statyczna i testy logiki (nie GUI) przechodzą
- [ ] Dokumentacja zaktualizowana, commit `FAZA 3: ...`

## Kryteria ukończenia
Okno startuje w 5.1 i 7.x, motyw się przełącza, długie zadanie testowe nie zawiesza GUI.

## Do weryfikacji na Windows 11
Całe GUI (wygląd, motywy, responsywność, DPI) — wymaga ręcznego uruchomienia na Windows 11.

## Wyniki
(wypełnia Claude po zakończeniu fazy)

## Następna faza
FAZA 4 — Dashboard. Prompt: `docs/04_PROMPTY/PROMPT_FAZA_4.md`.
