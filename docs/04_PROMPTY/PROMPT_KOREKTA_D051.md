# PROMPT — KOREKTA po FAZIE 12: winget na komputerze zdalnym (D-051)

> Wklej całość poniżej linii do NOWEJ rozmowy w Claude Code uruchomionej w głównym folderze repozytorium `mywindowspower`. Uruchom **przed** FAZĄ 13. To nie jest faza: to korekta po FAZIE 12 (jak korekty D-032 i D-042). Nie zmieniaj statusu żadnej fazy i nie rób nic z zakresu FAZY 13 (Prywatność i tweaki).

---

Pracujesz nad projektem **mywindowspower**. Odpowiadaj wyłącznie po polsku. Nie pamiętasz poprzednich rozmów; ciągłość niesie dokumentacja w repozytorium. To jest **korekta po FAZIE 12**, a nie nowa faza.

## Start
1. Przeczytaj: `CLAUDE.md`, `docs/02_STAN/STAN_PROJEKTU.md`, `docs/00_PROJEKT/CONTEXT.md`, `docs/00_PROJEKT/ARCHITEKTURA.md` (sekcje „Aplikacje — moduł MWP.Apps”, „Sieć — moduł MWP.Network”, „Komputery docelowe i połączenia zdalne”), `docs/00_PROJEKT/DECYZJE.md` (D-034, D-036, D-049, D-050), `docs/05_PROCES/PROCEDURA_FAZY.md`, `docs/03_FAZY/FAZA_12_APLIKACJE.md` oraz kod: cały `src/Modules/MWP.Apps`, `src/Modules/MWP.Network/Private/Get-MwpNetworkScript.ps1` i `Get-MwpNetworkRollbackScript.ps1` (wzorzec jednorazowego zadania harmonogramu jako SYSTEM na komputerze docelowym), `src/UI/Wpf/*Apps*`, `src/UI/Functions/Get-MwpApps*`, `tests/Modules/MWP.Apps/Apps.Tests.ps1`, `tests/Modules/MWP.Network/Network.Tests.ps1` (symulator harmonogramu).
2. `git status` i `git log --oneline -10`. Potwierdź, że FAZA 12 ma status `ZAKOŃCZONA` i jest jej commit (`6436379`, „FAZA 12: aplikacje i winget…”). Pliki nieśledzone sprzed fazy (`docs/04_PROMPTY/PROMPT_KOREKTA_D031.md`, `docs/scripts/`) zostaw bez zmian i poza commitem; inne niezacommitowane zmiany zgłoś użytkownikowi, zanim zaczniesz.
3. Sprawdź, że `D-051` jest wolny (ostatni wpis to D-050). Jeśli nie, użyj następnego wolnego numeru i dostosuj odwołania.
4. Zapisz bazę testów (`.\tests\Invoke-Checks.ps1` w 5.1 i 7.x, każda wersja w nowym procesie). Nie uzupełniaj hasha FAZY 12 w `CHANGELOG_FAZ.md` — robi to start FAZY 13.

## Kontekst i wymaganie użytkownika (2026-10-29)
**Wymaganie:** funkcjonalność modułu Aplikacje ma być **taka sama niezależnie od tego, czy komputer docelowy to `localhost`, czy komputer zdalny**: lista programów i pakietów, lista aktualizacji, aktualizacja pojedyncza i zaznaczonych, wyszukiwanie, instalacja, odinstalowanie programów z rejestru i pakietów Appx, cofnięcie.

**Stan po FAZIE 12 (D-050):** lokalnie wszystko działa przez `winget.exe` uruchamiany bezpośrednio. Zdalnie (sesja WinRM) działają tylko rejestr i Appx. Sonda z 2026-10-29 na komputerze zdalnym użytkownika (Windows 11, PowerShell 5.1.26100.9818, konto lokalnego administratora przez WinRM, OEMCP 852, pl-PL) wykazała:
- `Get-AppxPackage` — 49 pakietów konta połączenia, `-AllUsers` — 164;
- App Installer (`Microsoft.DesktopAppInstaller`) **niezarejestrowany** dla konta połączenia — brak aliasu `%LOCALAPPDATA%\Microsoft\WindowsApps\winget.exe` („Nie można odnaleźć określonego pliku”);
- plik `C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_1.29.379.0_x64__8wekyb3d8bbwe\winget.exe` istnieje, ale `Process.Start` w sesji WinRM zwraca **„Odmowa dostępu”**.
Przyczyna: winget to aplikacja MSIX; Windows nie uruchamia jej w sesji sieciowej (WinRM) konta bez rejestracji pakietu. Ustawienia aplikacji tego nie obejdą.

**Kierunek uzgodniony z użytkownikiem:** na komputerze zdalnym winget uruchamiany przez **jednorazowe zadanie harmonogramu** (ten sam mechanizm co automatyczne wycofanie zmian sieci, D-049), z wynikiem zwracanym do aplikacji. Ograniczenia, których nie wolno łamać:
- **bez zapisywania haseł** (D-034) — żadnych zadań z zapisanym hasłem użytkownika; dopuszczalne: konto `SYSTEM` oraz zadanie z `-LogonType Interactive` dla użytkownika **zalogowanego** na komputerze docelowym (działa w jego sesji bez hasła);
- **bez zależności zewnętrznych** (`Microsoft.WinGet.Client` odrzucony w D-050);
- bez ręcznego pobierania instalatorów z manifestów i bez uruchamiania `UninstallString` z rejestru (decyzja użytkownika z FAZY 12; jeśli uznasz, że jest konieczne — zapytaj);
- wzorzec funkcji zmieniającej system bez zmian: podgląd przed zmianą, administrator na komputerze docelowym sprawdzany przed podglądem, potwierdzenie z nazwą komputera, log na hoście, wpis cofnięcia, `MWP.Result`; oczekiwane błędy jako wynik, nie wyjątek;
- lokalne działanie (bezpośredni `winget.exe`) ma zostać takie, jak jest — chyba że wspólny mechanizm okaże się prostszy i bez utraty funkcji (wtedy zapytaj użytkownika).

## Zadanie

### 1. Sonda (najpierw, przed implementacją — wymaga zgody użytkownika)
Sonda **tworzy i usuwa tymczasowe zadania harmonogramu** na komputerze zdalnym, więc to zmiana systemu: przedstaw użytkownikowi dokładnie, co zostanie utworzone (nazwy zadań w `\MyWindowsPower\`, konto, polecenia — tylko `winget --version`, `winget list --source winget`, `winget search --id 7zip.7zip --exact --source winget`, bez instalacji) i poproś o zgodę. Przygotuj skrypt sondy w katalogu tymczasowym rozmowy (nie w repozytorium); poświadczenia użytkownik wpisuje sam (`Get-Credential` w jego terminalu), Ty czytasz wynik z terminala. Sprawdź i zapisz:
1. **SYSTEM:** ścieżka `winget.exe` z `Get-AppxPackage -AllUsers -Name Microsoft.DesktopAppInstaller` (`InstallLocation`, najnowsza wersja), uruchomienie z zadania jako SYSTEM, kod wyjścia, czy wyjście (przekierowane do pliku przez blok PowerShella w zadaniu) da się odczytać i zdekodować stroną OEM, czy `winget list` widzi programy komputera (HKLM) i czy widzi programy użytkownika (oczekiwane: nie), czy działa wyszukiwanie w źródle `winget` (aktualizacja źródła jako SYSTEM), czy brak zależności (np. VCLibs) blokuje start.
2. **Zalogowany użytkownik:** czy ktoś jest zalogowany (`explorer.exe`, jak w MWP.Startup); jeśli tak — zadanie z `New-ScheduledTaskPrincipal -UserId <konto> -LogonType Interactive`: czy alias winget działa w jego sesji i czy `winget list` pokazuje jego programy użytkownika (`(User)`). Jeśli nikt nie jest zalogowany — zapisz to i zapytaj użytkownika, czy może zalogować się na chwilę do testu.
3. Czas wykonania (zadanie + odczyt), zachowanie przy przekroczeniu limitu (zatrzymanie zadania i procesu winget), sprzątanie (brak zadań i plików po sondzie — sprawdź jawnie).
Zapisz wyniki w `D-051` (fakty z sondy, jak w D-050). Jeśli SYSTEM nie uruchomi winget, **zatrzymaj się** i przedstaw użytkownikowi warianty zastępcze (np. tylko sesja zalogowanego użytkownika; odinstalowanie MSI przez `msiexec /x` bez winget) — nie implementuj ich bez decyzji.

### 2. Projekt (ADR D-051) — przedstaw użytkownikowi przed implementacją
Na podstawie sondy zaprojektuj i opisz krótko (wpływ na architekturę, zasada 9 `CLAUDE.md`):
- **Wybór kontekstu wykonania winget** dla każdej operacji: lokalnie — bez zmian; zdalnie — SYSTEM dla programów komputera (zakres `Machine`, pakiety bez zakresu), sesja zalogowanego użytkownika dla programów i pakietów tego użytkownika (zakres `User`, instalacje „per user”); co zrobić, gdy właściciel profilu nie jest zalogowany (odmowa przed podglądem z czytelnym komunikatem; to jedyny dopuszczalny wyjątek od parytetu — potwierdź z użytkownikiem). Rozważ też lokalne programy **innych** użytkowników (dziś niedostępne także lokalnie) — parytet ma działać w obie strony: jeśli zdalnie da się obsłużyć zalogowanego użytkownika, rozważ to samo lokalnie; zapytaj, czy to w zakresie.
- **Mechanizm zadania:** nazwa `\MyWindowsPower\MWP-Winget-<GUID>`; akcja `powershell.exe -NoProfile -NonInteractive -EncodedCommand` ze stałym blokiem (wzorzec `Get-MwpNetworkRollbackScript`: stały szablon + żądanie w Base64, argumenty winget sprawdzone na hoście, bez sklejania tekstu wejściowego), limit długości polecenia zadania; wynik (linie, kod wyjścia, czas, błąd) w pliku JSON w katalogu tylko dla SYSTEM i Administratorów (np. `%ProgramData%\MyWindowsPower\winget\`, ACL ustawiane przy tworzeniu; dla zadania użytkownika — katalog w jego profilu albo inny bezpieczny, opisz) — plik usuwany po odczycie; sprzątanie przy błędzie, przy przekroczeniu limitu i przy utracie połączenia (zadanie ustawia `DeleteExpiredTaskAfter`/samousuwanie jak w D-049; osierocone zadania i pliki `MWP-Winget-*` usuwane przy następnym wywołaniu).
- **Czekanie i postęp:** odpytywanie stanu zadania w bloku na komputerze docelowym z limitem (`ChangeTimeoutSeconds`, odczyt `ReadTimeoutSeconds`), anulowanie (`Stop-ScheduledTask` + zakończenie procesu winget), błąd połączenia w trakcie = błąd tylko tej instancji (jak dziś), a stan po ponownym połączeniu odczytywany z listy.
- **Uprawnienia:** rejestracja zadań wymaga administratora w sesji zdalnej (już sprawdzane przed podglądem dla zmian; dla **odczytu** zdalnego — lista winget, aktualizacje, wyszukiwanie — też będzie potrzebny administrator: opisz komunikat dla konta bez administratora).
- **Zgodność z D-050:** parser, kody błędów, lista ochronna, cofnięcia i widok bez zmian funkcjonalnych; `Invoke-MwpWinget` wybiera sposób uruchomienia (bezpośrednio / zadanie SYSTEM / zadanie użytkownika), a reszta modułu się nie zmienia. Status D-050 → „Obowiązuje, zakres zdalny zastąpiony przez D-051”.
Poczekaj na akceptację użytkownika.

### 3. Implementacja
- `MWP.Apps` (wersja 0.12.1 albo 0.13.0 — uzasadnij): nowe bloki komputera docelowego (zgodne z 5.1, wynik JSON), wybór kontekstu w `Invoke-MwpWinget`, `Get-MwpAppsTargetConfig` (folder i prefiks zadań, katalog wyników, limity), informacja w wyniku, jak uruchomiono winget (`Direct`, `SystemTask`, `UserTask`) — do logu i widoku.
- Odinstalowanie programu z rejestru zdalnie: Id lokalne `ARP\Machine\…` jako SYSTEM; `ARP\User\…` w sesji właściciela profilu (SID z identyfikatora aplikacji; dziś odmowa „program profilu innego użytkownika”) — zgodnie z decyzją z punktu 2.
- Instalacja/aktualizacja zdalnie: domyślnie zakres komputera (`--scope machine`, gdy pakiet go obsługuje) jako SYSTEM; pakiety tylko „per user” — w sesji wybranego zalogowanego użytkownika (w widoku: wybór profilu, jak dziś dla listy). Podgląd ma mówić, w czyim kontekście nastąpi zmiana.
- Widok `Apps.xaml`: usuń ograniczenie „winget niedostępny” dla komputera zdalnego (zostaje tylko, gdy naprawdę nie ma jak uruchomić winget), pokaż kontekst wykonania; bez logiki systemowej w kodzie widoku (D-015).
- Lista ochronna, potwierdzenia (zdalne odinstalowanie — wpisanie nazwy komputera), log i cofnięcia jak w D-050.

### 4. Testy
- Symulator harmonogramu (wzorzec `Network.Tests.ps1`: mocki `Register-`/`Start-`/`Get-`/`Unregister-ScheduledTask` w zakresach modułów) + atrapa `winget.cmd` z FAZY 12; blok zadania wykonywany z argumentów zarejestrowanego zadania (jak blok wycofania w testach sieci), więc ten sam kod działa w teście.
- Przypadki: zdalna lista, aktualizacje, wyszukiwanie, instalacja, aktualizacja, odinstalowanie `Machine` (SYSTEM) i `User` (sesja zalogowanego), właściciel profilu niezalogowany, brak administratora (odmowa przed podglądem, 12), przekroczenie limitu i anulowanie (zadanie i plik usunięte, 8), utrata połączenia w trakcie (błąd tylko tej instancji, 7), osierocone zadania sprzątane, plik wyniku z polskimi znakami (OEM), argument ze spacją (Id `ARP\…`), brak sekretów w poleceniu zadania, długość polecenia w limicie, bloki parsują się bez składni 7.x. Lokalne testy z FAZY 12 przechodzą bez zmian.
- **Tabela parytetu** w pliku FAZY 12 (sekcja korekty): każda operacja × `localhost` / komputer zdalny — wynik testu i (po ręcznej weryfikacji) wynik na prawdziwym komputerze.
- Testy nie zmieniają prawdziwego systemu (mocki, `TestDrive`). Prawdziwe zmiany na komputerze zdalnym — tylko w ręcznej weryfikacji z użytkownikiem, z jego zgodą na każdą (aplikacja testowa, np. `7zip.7zip`).

### 5. Weryfikacja ręczna z użytkownikiem (komputer zdalny)
Lista do wykonania przez użytkownika (zapisz w `FAZA_12_APLIKACJE.md`): lista i aktualizacje zdalnie zgodne z `winget upgrade` na tamtym komputerze; instalacja i odinstalowanie aplikacji testowej z cofnięciem; program użytkownika z zalogowanym i niezalogowanym właścicielem; anulowanie długiej operacji; brak zadań `\MyWindowsPower\MWP-Winget-*` i plików wyników po wszystkim; utrata połączenia w trakcie.

### 6. Dokumentacja i zamknięcie
- **`DECYZJE.md`:** wpis `D-051` (problem, opcje, wybór, wyniki sondy, konsekwencje, decyzje użytkownika); bez edycji treści starych wpisów poza statusem D-050.
- **`ARCHITEKTURA.md`:** sekcja „Aplikacje” (zdalne uruchamianie winget, zadania, katalog wyników, kontekst wykonania), „Znane ograniczenia zdalne”, testy architektoniczne.
- **`FAZA_12_APLIKACJE.md`:** w „Wyniki” sekcja korekty D-051 z tabelą parytetu i listą weryfikacji (bez zmiany statusu fazy). **`STAN_PROJEKTU.md`:** pozycja „Przed FAZĄ 13 (korekta D-051)” jako zrobiona, „Co zostało zrobione”, dług techniczny (usuń punkt o winget zdalnie, dopisz nowe ograniczenia), wynik testów, punkty do weryfikacji. **`CHANGELOG_FAZ.md`:** wpis korekty na górze (wzór: korekta D-042).
- `.\tests\Invoke-Checks.ps1` w 5.1 i 7.x (nowe procesy): 0 uwag i 0 niezaliczonych; porównaj z bazą. Nowe pliki `.ps1`/`.psm1`/`.psd1` w UTF-8 z BOM.
- Commit: `FAZA 12 (korekta): winget na komputerze zdalnym przez zadanie harmonogramu — parytet z localhost (D-051)`. `git push` tylko po wyraźnej zgodzie użytkownika.
- Na końcu napisz: **„Następna faza: FAZA 13 — Prywatność i tweaki. Prompt: `docs/04_PROMPTY/PROMPT_FAZA_13.md`. Otwórz nową rozmowę w Claude Code.”**
