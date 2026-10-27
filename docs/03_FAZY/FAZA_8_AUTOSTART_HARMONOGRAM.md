# FAZA 8 — Autostart i harmonogram

**Status:** ZAKOŃCZONA (ręczna weryfikacja prawdziwych zmian, Menedżera zadań i komputera zdalnego — lista niżej)

## Cel
Kontrola tego, co uruchamia się razem z systemem i użytkownikiem.

## Zależności
FAZY 2, 3 i 4 zakończone.

## Zakres
- Moduł `MWP.Startup`: źródła autostartu — `HKCU`/`HKLM` `Run` i `RunOnce` (także `WOW6432Node`), foldery Startup (użytkownika i wspólny), stan włączenia w `StartupApproved`.
- Włączanie i wyłączanie pozycji w sposób zgodny z Menedżerem zadań (`StartupApproved`), bez kasowania wpisu.
- Zadania harmonogramu: `Get-ScheduledTask`, `Get-ScheduledTaskInfo`; włącz/wyłącz; uruchom teraz; usunięcie tylko z potwierdzeniem i zapisem definicji (eksport XML) przed usunięciem.
- Informacje o wydawcy: podpis cyfrowy pliku (`Get-AuthenticodeSignature`), ścieżka, ocena ryzyka (podpisany / niepodpisany).
- Cofanie zmian.
- Widok `Startup.xaml` (dwie zakładki: Autostart, Harmonogram), operacje w tle.
- Testy Pester z mockami.
- Obsługa komputera docelowego (D-019): dla komputera zdalnego zakres to pozycje obejmujące cały system (HKLM Run/RunOnce, wspólny folder Startup, zadania harmonogramu). **Do zbadania i zapisania w `DECYZJE.md`:** pozycje profilu użytkownika (HKCU, folder Startup użytkownika) na komputerze zdalnym — **zbadane i zapisane w D-046** (profile zalogowanych użytkowników).

## Poza zakresem
Tworzenie nowych zadań harmonogramu (odtworzenie usuniętego zadania z jego własnego eksportu XML jest cofnięciem, nie tworzeniem).

## Checklista
- [x] Odczyt wszystkich źródeł autostartu — `Get-MwpStartupItem` (blok `ItemList`): HKLM `Run`/`RunOnce` i `WOW6432Node\…\Run`/`RunOnce`, wspólny folder Startup (cel skrótów `.lnk`), użytkownik `Run`/`RunOnce` i folder Startup; stan z `StartupApproved` (`Run`, `Run32`, `StartupFolder`) z datą wyłączenia; filtry `Select-MwpStartupItem`
- [x] Włącz/wyłącz przez `StartupApproved` — `Set-MwpStartupItemState`: format Menedżera zadań (02… / 03 + FILETIME, wyższe bity zachowane), tworzy brakujący klucz, ponowny odczyt; wpis Run i plik zostają; RunOnce tylko do odczytu
- [x] Lista zadań harmonogramu, włącz/wyłącz, uruchom — `Get-MwpScheduledTask` (`Get-ScheduledTask` + `Get-ScheduledTaskInfo`: stan, akcje, wyzwalacze, konto, ostatnie/następne uruchomienie, wynik), `Set-MwpScheduledTaskState`, `Start-MwpScheduledTask`; lista ochronna `Task`/`TaskRemoval` (D-046)
- [x] Usunięcie zadania z eksportem XML przed operacją — `Remove-MwpScheduledTask`: `Export-ScheduledTask` → zapis UTF-16 w `<katalog danych>\exports\tasks` (sprawdzony odczytem) → `Unregister-ScheduledTask`; nieudany eksport/zapis przerywa; okno potwierdzenia wymaga wpisania nazwy zadania
- [x] Informacja o podpisie wydawcy — `Get-AuthenticodeSignature` na komputerze docelowym, `Get-MwpSignatureRisk` (podpisany, niepodpisany, podpis nieprawidłowy, brak pliku, nie sprawdzano, nie dotyczy) i wydawca z tematu certyfikatu; kolumny „Podpis” i „Wydawca” w obu zakładkach
- [x] Cofanie — wpisy cofnięcia: stan pozycji autostartu, stan zadania, usunięcie zadania (`Restore-MwpScheduledTask` z XML), odtworzenie (ponowne usunięcie); lista „Zmiany autostartu i harmonogramu do cofnięcia” w widoku
- [x] Widok `Startup.xaml` — `src/UI/Views/Startup.xaml` (zakładki Autostart i Harmonogram; styl zakładek w `Styles.xaml`), odczyt w tle (dwie operacje), zmiany przez podgląd → potwierdzenie → wykonanie w tle
- [x] Testy Pester, PSScriptAnalyzer — `tests/Modules/MWP.Startup/Startup.Tests.ps1` (43), `tests/UI/StartupView.Tests.ps1` (6); wynik niżej
- [x] Działa dla `localhost` i dla komputera zdalnego (kontekst `-Context`, błąd połączenia obsłużony na poziomie instancji) — localhost: odczyt, podgląd i test dymny okna; zdalnie: testy z mockiem transportu WinRM (profile zalogowanych użytkowników, uprawnienia w sesji, lista ochronna, eksport XML po stronie hosta, utrata połączenia, cofnięcie wymaga kontekstu); **prawdziwy komputer zdalny — DO WERYFIKACJI NA WINDOWS 11**
- [x] Dokumentacja zaktualizowana, commit `FAZA 8: ...`

## Kryteria ukończenia
Wyłączenie i przywrócenie pozycji autostartu działa i jest widoczne w Menedżerze zadań.

Częściowo potwierdzone: format `StartupApproved` sprawdzony na prawdziwych wartościach tego komputera (pozycje wyłączone w Menedżerze zadań — 03 + data wyłączenia, widoczne w widoku jako „Wyłączony” z datą), zapis odtwarza ten format (testy z symulatorem). **Prawdziwe wyłączenie i przywrócenie z porównaniem w Menedżerze zadań — DO WERYFIKACJI NA WINDOWS 11** (punkt 2 listy niżej; zasada 5 `CLAUDE.md` — bez zmian systemu podczas pisania kodu).

## Do weryfikacji na Windows 11
Zgodność ze stanem w Menedżerze zadań > Aplikacje startowe; zadania wymagające administratora. Dodatkowo test na komputerze zdalnym użytkownika (obsługa zdalna, utrata połączenia).

## Wyniki
Zakończona 2026-10-27.

- **Baza przed zmianami** (każda wersja w nowym procesie): 5.1.26100.9711 — 0 uwag, 1353/1353; 7.6.7 (`C:\Program Files\PowerShell\7\pwsh.exe`) — 0 uwag, 1353/1353.
- **Wynik końcowy:** `.\tests\Invoke-Checks.ps1`, każda wersja w nowym procesie: 5.1.26100.9711 — 0 uwag PSScriptAnalyzer, 1462/1462; 7.6.7 (`C:\Program Files\PowerShell\7\pwsh.exe`) — 0 uwag, 1462/1462 (baza 1353/1353; +109: `Startup.Tests.ps1` 43, `StartupView.Tests.ps1` 6, testy XAML i kodowania nowych plików).
- **Decyzje użytkownika (2026-10-27):** pozycje profilu użytkownika na komputerze zdalnym — profile użytkowników zalogowanych (HKEY_USERS\<SID>, folder Startup z ich profilu), bez ładowania `NTUSER.DAT`; lista ochronna zadań — usuwanie `\Microsoft\*` zablokowane, krótka lista zadań krytycznych bez wyłączania; autostart bez listy ochronnej (D-046).
- **`MWP.Startup` 0.8.0:** autostart (`Get-MwpStartupItem [-AsOperation] [-NoSignature]`, `Resolve-MwpStartupItemList`, `Select-MwpStartupItem`, `Set-MwpStartupItemState`), harmonogram (`Get-MwpScheduledTask [-AsOperation]`, `Resolve-MwpScheduledTaskList`, `Select-MwpScheduledTask`, `Set-MwpScheduledTaskState`, `Start-MwpScheduledTask`, `Remove-MwpScheduledTask [-ExportDirectory]`, `Restore-MwpScheduledTask`), `Get-MwpSignatureRisk`, `Test-MwpScheduledTaskName`; bloki komputera docelowego `ItemList`, `ItemState`, `TaskList`, `TaskControl` (5.1, JSON); kontrakt: Read, Change, Undo, RemoteTarget; Embedded, SeparateWindow.
- **`MWP.Core` 0.8.0:** lista ochronna — kategorie `Task` (10 wzorców: WindowsUpdate, UpdateOrchestrator, WaaSMedic, Windows Defender, SystemRestore, TaskScheduler, RecoveryEnvironment, BitLocker, Time Synchronization, CertificateServicesClient) i `TaskRemoval` (`\Microsoft\*`).
- **Sprawdzone na tym komputerze (tylko odczyt i podgląd, 5.1 i 7.6.7, bez administratora):** 18 pozycji autostartu w ok. 2,2 s (HKLM Run 3, `WOW6432Node` Run 8, wspólny folder 1, HKCU Run 5, folder użytkownika 1); trzy pozycje wyłączone w Menedżerze zadań (`03` + FILETIME) pokazane jako „Wyłączony” z datą 06.02.2024; `SecurityHealth` ma `06` (włączona); osierocone wartości `StartupApproved` bez wpisu są pomijane; 194 zadania w ok. 2,8 s (podpisy 9 zadań spoza `\Microsoft\`); 14 zadań chronionych, 185 bez możliwości usunięcia; podgląd wyłączenia pozycji HKCU; odmowy: pozycja HKLM i zmiany zadań bez administratora, wyłączenie i usunięcie `\Microsoft\Windows\SystemRestore\SR`.
- **Okno (`MWP.UI`):** `Views/Startup.xaml`, `Initialize-`/`Update-MwpStartupView`, `Invoke-MwpStartupViewAction`, `Start-MwpUiStartupRefresh`, logika prezentacji bez WPF: `Get-MwpStartupViewOption`, `Get-MwpStartupActionState`, `Get-MwpStartupDetail`; wpis w `Get-MwpModuleViewCatalog`; styl `TabControl`/`TabItem` w `Themes/Styles.xaml` (oba motywy).
- **Test dymny okna (automatyczny, kopia aplikacji w katalogu tymczasowym, bez zmian systemu)** w 5.1 (motyw jasny) i 7.6.7 (motyw ciemny): instancja „Autostart i harmonogram — localhost”, oba odczyty w tle (18 pozycji, 194 zadania), ostrzeżenie o braku administratora, przyciski pozycji HKLM wyłączone z uwagą, pozycja HKCU — „Wyłącz…” dostępne, szczegóły z wydawcą; zakładka Harmonogram: 9 zadań bez Microsoft / 194 wszystkie, `SR` z kłódką i wszystkimi przyciskami wyłączonymi; „Wyłącz…” → podgląd w tle → okno potwierdzenia („Komputer docelowy: localhost”, „Wpis nie jest kasowany”) → Anuluj; 0 wpisów cofnięcia, kod wyjścia 0; zrzuty obejrzane.
- **Znalezione i poprawione w trakcie:** (1) `.bat` ma status podpisu `UnknownError` (TRUST_E_SUBJECT_FORM_UNKNOWN) — bez certyfikatu oceniany jako niepodpisany, nie „nieprawidłowy”; (2) zadania z akcją COM nie mają pliku — „Nie dotyczy”; (3) Pester 6 nie przepuszcza wywołań niepasujących do filtra mocka — domyślne mocki wołają oryginał przez nazwę z modułem i `$PesterBoundParameters`; (4) w pełnym przebiegu (`Set-StrictMode`) ciało i filtr mocka widzą tylko przekazane parametry — odczyt przez `Get-Variable`; (5) Pester podstawia `<Nazwa>` w nazwie testu jako zmienną; (6) `CDXML` (`Enable-ScheduledTask` itp.) wymaga `-RemoveParameterType InputObject` w mockach; (7) PSScriptAnalyzer: `$profile` to zmienna automatyczna; (8) słownik kodów wyniku zadań — klucze `Int32` vs `Int64`.
- **Ograniczenia:** prawdziwe zmiany (`StartupApproved`, zadania) nie były wykonywane na komputerze deweloperskim (zasada 5 `CLAUDE.md`; sesja bez administratora) — tylko testy z symulatorem, odczyt i podgląd; zmienne środowiskowe w poleceniach innych użytkowników (zdalnie) są rozwijane w sesji konta połączenia; folder Startup innych użytkowników — ścieżka domyślna w profilu (bez przekierowania folderów); `HKCU\…\WOW6432Node\…\Run` nie jest czytany (Windows go nie używa).

## Do weryfikacji na Windows 11 — lista dla użytkownika
1. `.\Start-MyWindowsPower.ps1 -Elevate` (5.1 i 7.x) → Autostart i harmonogram → instancja localhost: zakładka Autostart zgodna z Menedżerem zadań → Aplikacje startowe (lista, stan „Włączony/Wyłączony”, wydawca) i z `shell:startup` / `shell:common startup`.
2. **Kryterium fazy:** pozycja testowa (np. własny wpis w `HKCU\…\Run` albo skrót w folderze Autostart): „Wyłącz…” → Menedżer zadań (F5) pokazuje „Wyłączone”; „Włącz…” → „Włączone”; cofnięcie z listy; wpis w rejestrze/plik nadal istnieje. To samo dla pozycji HKLM i 32-bitowej (`WOW6432Node`) jako administrator. Odwrotnie: zmiana w Menedżerze zadań → „Odśwież” w aplikacji.
3. Wpis `RunOnce` (jeśli jest): widoczny jako „Jednorazowo (RunOnce)”, bez przycisków.
4. Zakładka Harmonogram jako administrator: zgodność z `taskschd.msc` (stan, ostatnie/następne uruchomienie, wynik); zadanie testowe — „Wyłącz…”, „Włącz…”, „Uruchom teraz…”, cofnięcie wyłączenia.
5. Usunięcie zadania testowego (utworzonego ręcznie w `taskschd.msc`): okno wymaga wpisania nazwy, plik XML w `<katalog danych>\exports\tasks`, zadanie znika; cofnięcie odtwarza je (porównać w `taskschd.msc`); zadanie z „Uruchom niezależnie od tego, czy użytkownik jest zalogowany” (zapisane hasło) — ostrzeżenie w podglądzie, cofnięcie odmawia z instrukcją importu.
6. Zadanie `\Microsoft\Windows\SystemRestore\SR` — kłódka, „Wyłącz…” i „Usuń…” wyłączone; `Set-MwpScheduledTaskState -TaskPath '\Microsoft\Windows\SystemRestore\' -TaskName SR -Enabled $false` w konsoli — odmowa; zadanie `\Microsoft\…` niekrytyczne — można wyłączyć, nie można usunąć.
7. Komputer zdalny (Połącz, administrator): pozycje HKLM i wspólnego folderu, profile zalogowanych użytkowników (gdy ktoś jest zalogowany przy komputerze) i komunikat, gdy nikt nie jest zalogowany; zmiana pozycji z cofnięciem; harmonogram zdalny z usunięciem i odtworzeniem zadania testowego; odłączenie sieci w trakcie — błąd tylko w tej instancji.
8. Podpis: plik niepodpisany i skrypt `.bat` w autostarcie — „Niepodpisany”; brakujący plik — „Brak pliku”; wynik zgodny z właściwościami pliku (Podpisy cyfrowe).

## Następna faza
FAZA 9 — Czyszczenie dysku. Prompt: `docs/04_PROMPTY/PROMPT_FAZA_9.md`.
