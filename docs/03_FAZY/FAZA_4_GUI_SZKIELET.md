# FAZA 4 — Szkielet GUI i host modułów

**Status:** ZAKOŃCZONA (ręczna weryfikacja okna na Windows 11 — u użytkownika)

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

- **Katalog danych (D-032):** w `Ustawieniach` edycja `dataPath` (pole z podglądem ścieżki wynikowej, sprawdzenie zapisywalności, ostrzeżenie o trybie zapasowym `%LOCALAPPDATA%\MyWindowsPower`) i przycisk „Przenieś dane” (przeniesienie `logs` i `undo` do nowego katalogu: klasa Zmiana, podgląd, log, potwierdzenie, w tle, błąd nie zostawia danych w połowie; bez automatycznej migracji przy starcie). Przeniesienie modułów z paczek z `src/Modules/Installed` do katalogu danych (skanowanie w `Get-MwpModuleDefinition` i launcherze, przeniesienie istniejących instalacji, aktualizacja `.gitignore` i testów). Stan katalogu danych (ścieżka, tryb zapasowy) w `O programie` lub pasku stanu przez funkcję publiczną `MWP.Core` (`Get-MwpDataPath` jest wewnętrzna). Wybór miejsca przy instalacji — dopiero z instalatorem aplikacji.

## Wejście z FAZY 3 (do uwzględnienia)
- API: `New-MwpModuleInstance`/`Initialize-`/`Close-`/`Get-MwpModuleInstance`, `New-MwpExecutionContext`, `Connect-`/`Disconnect-`/`Test-MwpTarget`, `Start-`/`Wait-`/`Stop-MwpOperation` (pula runspace'ów z limitem `remoteMaxParallelOperations`), stan połączenia w `Context.Connection.State` (opis: `ARCHITEKTURA.md`, D-033…D-037).
- Okno poświadczeń (`Get-Credential`) wyświetla GUI przy połączeniu z komputerem o uwierzytelnieniu `Credential`; logika go nie wyświetla (D-034). Stan `Unauthorized` z `ErrorKind = CredentialRequired` oznacza „poproś o poświadczenia".
- Instancja dla komputera zdalnego wymaga `RemoteTarget` w `Capabilities` modułu. Moduły obszarów mają dziś puste `Capabilities`, więc test „dwie instancje dla dwóch komputerów" w GUI wymaga modułu-zaślepki z `RemoteTarget` (albo dodania tej możliwości w fazie obszaru).
- Kontekst wykonania jest bezpieczny do odczytu w innych runspace'ach (bez kodu przy odczycie), ale sesja WinRM kontekstu należy do runspace'u, w którym powstała — operacje w tle uruchamiaj przez `Start-MwpOperation`.

## Poza zakresem
Logika i dane obszarów, widgety Dashboardu (FAZA 5), uruchamianie samodzielne (FAZA 19).

## Checklista
- [x] Mockup `docs/design/mockup-pulpit.png` obejrzany, układ zgodny lub odstępstwa opisane w `DECYZJE.md` — D-040
- [x] `MainWindow.xaml` z nawigacją i paskiem stanu — `src/UI/MainWindow.xaml` (pasek górny z wyszukiwaniem Ctrl+K, nawigacja, kontener widoku, panel logu, pasek stanu)
- [x] `UI.ps1`: ładowanie XAML i nawigacja — `src/UI/UI.ps1` (punkt wejścia) + moduł `MWP.UI` (`Import-MwpXaml`, `Show-MwpView`, `Update-MwpNavigation`; D-039)
- [x] Motyw jasny i ciemny, wykrywanie motywu systemu, przełącznik — `Themes/Light.xaml`, `Dark.xaml`, `Styles.xaml`, `Get-MwpSystemTheme`, `Resolve-MwpThemeName`, `Set-MwpUiTheme`; ustawienie `theme` (System/Light/Dark) zapisywane przez `Set-MwpSetting`
- [x] Pomocnik zadań w tle z postępem i anulowaniem — `New-MwpUiTaskPool`, `Start-`/`Stop-`/`Update-MwpUiTask`, `Register-MwpUiOperation`; `tests/UI/UiFunctions.Tests.ps1` (wynik w wątku wywołującego, postęp, anulowanie, błąd, operacja MWP.Remote)
- [x] Widoki-zaślepki dla wszystkich obszarów — `Views/Area.xaml` + katalog 14 obszarów (`Get-MwpAreaCatalog`), `Views/Instance.xaml`, `Views/Dashboard.xaml` (FAZA 5)
- [x] Host: wykrywanie modułów, lista instancji, wielokrotne instancje tego samego modułu, zamknięcie bez wpływu na inne — `Open-`/`Close-MwpUiInstance`, sekcja „Otwarte instancje"; test dymny okna (dwie instancje `Usługi — localhost`, niezależne notatki w `State`, zamknięcie obu → 0 instancji w `MWP.Remote`)
- [x] Wybór komputera docelowego per instancja, stan połączenia w pasku stanu i w widoku instancji — `Show-MwpTargetPicker`, `Get-MwpConnectionStateInfo`, `Update-MwpStatusInstance`, `Connect-MwpUiInstance` (okno poświadczeń, połączenie w tle); komputer zdalny: DO WERYFIKACJI NA WINDOWS (ręcznie, z paczką `samples/MWP.Przyklad`)
- [x] Tryby Embedded i Separate window — `Move-MwpUiInstance`, `Dialogs/InstanceWindow.xaml`, `Test-MwpPresentationMode`; test dymny (przeniesienie do osobnego okna i z powrotem)
- [x] Widoki `Ustawienia` (w tym komputery docelowe) i `O programie` — `Views/Settings.xaml` (motyw, komputery: dodanie/edycja/usunięcie/diagnostyka, `Set-MwpTarget` — D-041), `Views/About.xaml`
- [x] Widok „Moduły": lista wbudowanych i zainstalowanych, instalacja z `.mwpmod` z oknem potwierdzenia (nazwa, wersja, uprawnienia, SHA-256), odinstalowanie z potwierdzeniem nazwą modułu (D-031) — `Views/Modules.xaml`, `Install-`/`Uninstall-MwpUiModule`; instalacja w oknie: DO WERYFIKACJI NA WINDOWS (ręcznie)
- [x] Katalog danych (D-032): edycja `dataPath` w `Ustawieniach`, przycisk „Przenieś dane”, moduły z paczek w katalogu danych — `Get-MwpDataLocation`, `Move-MwpDataDirectory`, `Move-MwpInstalledModule` (D-038); `tests/Modules/MWP.Core/DataLocation.Tests.ps1`
- [x] Wspólne style i okno potwierdzenia z podglądem zmian — `Themes/Styles.xaml`, `Dialogs/Confirm.xaml`, `Show-MwpConfirmDialog`, `ConvertTo-MwpPreviewLine`
- [x] Launcher uruchamia okno GUI — `Start-MyWindowsPower.ps1` → `src/UI/UI.ps1`; `-NoGui` dla testów (`Launcher.Tests.ps1`)
- [x] Analiza statyczna i testy logiki (nie GUI) przechodzą — 5.1.26100.9711: 0 uwag, 922/922; 7.6.7: 0 uwag, 922/922
- [x] Dokumentacja zaktualizowana, commit `FAZA 4: ...`

## Kryteria ukończenia
Okno startuje w 5.1 i 7.x, motyw się przełącza, długie zadanie testowe nie zawiesza GUI, dwie instancje tego samego widoku-zaślepki działają niezależnie dla dwóch komputerów, moduł z paczki `.mwpmod` da się zainstalować i odinstalować z widoku „Moduły".

## Do weryfikacji na Windows 11
Całe GUI (wygląd, motywy, responsywność, DPI, instancje i osobne okna, utrata połączenia z jednym komputerem, instalacja i odinstalowanie modułu w widoku „Moduły") — wymaga ręcznego uruchomienia na Windows 11.

## Wyniki
Zakończona 2026-10-26.

- **Baza przed zmianami:** `.\tests\Invoke-Checks.ps1` w czystej kopii `228bf40` (worktree), w nowych procesach — 5.1.26100.9711: 0 uwag, 664/664; 7.6.7 (`C:\Program Files\PowerShell\7\pwsh.exe`): 0 uwag, 664/664.
- **Wynik końcowy:** 5.1.26100.9711 — 0 uwag, 922/922; 7.6.7 — 0 uwag, 922/922.
- **Korekta po FAZIE 4 (2026-10-27, D-042, status fazy bez zmian):** dziennik startu (`Startup.Environment`, `Startup.Modules`, `Startup.Window`, `Startup.Module` na poziomie `Error`), okno komunikatu przy błędzie startu, awaryjny `mwp-startup-failure.log`, pomiar czasu startu (mediana ok. 7,5–8 s) i okno startowe z krokowym paskiem; testy: 5.1.26100.9711 — 0 uwag, 959/959; 7.6.7 — 0 uwag, 959/959 (baza 922/922).
- **Okno hosta (`src/UI`, D-039):** `UI.ps1` + moduł prezentacji `MWP.UI` (`Functions/` — logika bez WPF, `Wpf/` — okna i zdarzenia), `MainWindow.xaml`, 6 widoków, 5 okien dialogowych, motywy jasny/ciemny i wspólne style (przyciski, pola, listy rozwijane, tabele, nawigacja, paski przewijania, banery, plakietki stanu). Nawigacja z katalogu obszarów, wyszukiwanie Ctrl+K, panel logu, pasek stanu z zadaniami w tle (postęp, anulowanie).
- **Instancje w GUI:** okno wyboru komputera i trybu (komputer zdalny tylko dla modułu z `RemoteTarget`), widok instancji z kontekstem wykonania, stanem połączenia, połączeniem/rozłączeniem w tle (okno poświadczeń UI), diagnostyką `Test-MwpTarget`, odczytem testowym `Get-MwpTargetInfo -AsOperation`, notatką w `State`; tryby w oknie głównym i w osobnym oknie.
- **`MWP.Core` 0.4.0 (D-038):** `Get-MwpDataLocation`, `Move-MwpDataDirectory`, `Move-MwpInstalledModule`; moduły z paczek w `<katalog danych>\modules` (dawny `src\Modules\Installed` nadal odkrywany); prywatne `Resolve-MwpDataPath`, `Copy-MwpDirectory`, `Test-MwpDirectoryWritable -NoCreate`.
- **`MWP.Remote` 0.4.0 (D-041):** `Set-MwpTarget`, `Get-MwpTargetInfo`.
- **Launcher:** importuje moduły według `Get-MwpModuleDefinition` (także z katalogu danych), otwiera okno, `-NoGui` bez okna.
- **Paczka przykładowa:** `samples/MWP.Przyklad` (RemoteTarget, Embedded, SeparateWindow) z instrukcją w `samples/README.md`; `tests/Samples.Tests.ps1`.
- **Testy:** nowe `tests/UI/UiFunctions.Tests.ps1`, `tests/UI/Xaml.Tests.ps1` (XAML, wczytanie wszystkich okien przez `XamlReader` w STA, granica warstw UI), `tests/Modules/MWP.Core/DataLocation.Tests.ps1`, `tests/Samples.Tests.ps1`; rozszerzone `Targets.Tests.ps1` (`Set-MwpTarget`, `Get-MwpTargetInfo`), `Launcher.Tests.ps1` (`-NoGui`, moduł z katalogu danych), `Architecture.Tests.ps1`.
- **Test dymny okna (automatyczny, bez zmian w ustawieniach i systemie)** w 5.1 i 7.6.7: przejście przez wszystkie widoki, dwie instancje `Usługi — localhost`, odczyt testowy (7.6.7: dane z komputera), osobne okno i powrót, motyw ciemny, podgląd `dataPath`, zadanie testowe z anulowaniem, panel logu, zamknięcie instancji (0 w `MWP.Remote`), kod wyjścia 0; zrzuty okien i okien dialogowych obejrzane (bez zapisu w repozytorium).
- **Decyzje:** D-038 (katalog danych, moduły z paczek w katalogu danych), D-039 (ADR okna hosta), D-040 (odstępstwa od mockupu), D-041 (`MWP.Remote` 0.4.0).
- **Znalezione i poprawione w trakcie:** polskie cudzysłowy „ ” w napisach w podwójnych cudzysłowach kończą napis w PowerShellu (tylko w napisach pojedynczych) — wykryte przez PSScriptAnalyzer; nazwa zmiennej pętli równa nazwie parametru (`$definition`/`$Definition`) nadpisywała parametr.
- **Ograniczenia:** wygląd i działanie okna przy ręcznym użyciu, DPI, połączenie z komputerem zdalnym z okna i instalacja paczki z okna — weryfikacja ręczna (niżej).

## Do weryfikacji na Windows 11 — lista dla użytkownika
1. `.\Start-MyWindowsPower.ps1` w 5.1 i 7.x: okno startuje, motyw zgodny z systemem; przełącznik motywu w pasku górnym i w Ustawieniach (zapamiętany po ponownym uruchomieniu).
2. Skalowanie 125–150% (DPI) i minimalny rozmiar okna (1000×640).
3. O programie → „Uruchom zadanie testowe”: w czasie 20 s okno reaguje (przełączanie widoków, motywu), „Anuluj” na pasku stanu przerywa zadanie.
4. Paczka przykładowa (instrukcja `samples/README.md`): Moduły → instalacja (okno z SHA-256, porównanie z `Get-FileHash`), moduł widoczny w nawigacji („Moduły z paczek”).
5. Dwie instancje `Moduł przykładowy` — localhost i komputer zdalny (okno poświadczeń, stan „Połączono”, odczyt testowy ze zdalnego komputera, diagnostyka); zamknięcie jednej nie wpływa na drugą; jedna w osobnym oknie.
6. Utrata połączenia z komputerem zdalnym (np. wyłączenie sieci po połączeniu): błąd tylko w widoku tej instancji, reszta działa.
7. Moduły → odinstalowanie modułu przykładowego (wpisanie nazwy, zamknięcie instancji).
8. Ustawienia → Katalog danych: podgląd ścieżki, „Przenieś dane” do innego folderu i z powrotem; po zmianie — ponowne uruchomienie.
9. Ustawienia → komputery: dodanie, edycja, usunięcie (podgląd i potwierdzenie).

## Następna faza
FAZA 5 — Dashboard. Prompt: `docs/04_PROMPTY/PROMPT_FAZA_5.md`.
