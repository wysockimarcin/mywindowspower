# FAZA 9 — Czyszczenie dysku

**Status:** ZAKOŃCZONA (ręczna weryfikacja prawdziwego czyszczenia, uprawnień administratora, DISM i komputera zdalnego — lista niżej)

## Cel
Bezpieczne zwalnianie miejsca na dysku. To jedyny obszar z trwałym usuwaniem plików, więc bezpieczeństwo ma pierwszeństwo przed funkcjonalnością.

## Zależności
FAZY 2, 3 i 4 zakończone.

## Zakres
- Moduł `MWP.Cleanup`: definicje kategorii (dane, nie kod): pliki tymczasowe użytkownika (`%TEMP%`), `Windows\Temp`, kosz, pamięć podręczna miniatur, raporty błędów (WER), pamięć podręczna `SoftwareDistribution\Download`, Delivery Optimization, logi.
- Skanowanie tylko do odczytu: liczba plików i rozmiar na kategorię.
- **Tryb podglądu domyślny**; usuwanie dopiero po wyraźnym potwierdzeniu użytkownika w GUI, z listą kategorii i rozmiarem.
- Zasady bezpieczeństwa: tylko ścieżki z definicji kategorii, żadnego usuwania poza nimi, pomijanie plików w użyciu, brak podążania za dowiązaniami (junction/symlink), nigdy dokumenty i pulpit użytkownika.
- Raport: ile zwolniono, ile pominięto i dlaczego.
- Analiza magazynu składników: `DISM /Online /Cleanup-Image /AnalyzeComponentStore` (tylko analiza w tej fazie, czyszczenie opcjonalnie z ostrzeżeniem).
- Widok `Cleanup.xaml`, operacje w tle z postępem i anulowaniem.
- Testy Pester na katalogach tymczasowych utworzonych w teście (nigdy na realnych ścieżkach systemu).
- Obsługa komputera docelowego (D-019): dla komputera zdalnego tylko lokalizacje systemowe (np. `Windows\Temp`, pamięć podręczna Windows Update); profile użytkowników zdalnych tylko po jawnym wyborze. Zasada „nigdy nie dotyka plików użytkownika" obowiązuje bezwzględnie; potwierdzenie czyszczenia zawiera nazwę komputera.

## Poza zakresem
Czyszczenie przeglądarek, rejestru, duplikatów plików.

## Checklista
- [x] Definicje kategorii w pliku danych — `src/Modules/MWP.Cleanup/Data/cleanup-categories.json` (8 kategorii z zakresu), `Get-MwpCleanupCategory` z walidacją białej listy ścieżek (D-047)
- [x] Skan (odczyt) z rozmiarami — `Measure-MwpCleanupCategory`: liczba plików, rozmiar, pominięcia z powodem na kategorię, lokalizacje niedostępne z powodem
- [x] Usuwanie z potwierdzeniem i podglądem — `Clear-MwpCleanupCategory` (klasa Destrukcyjna, `ConfirmImpact High`, `-WhatIf`); w oknie: okno potwierdzenia z listą kategorii, liczbą plików, rozmiarem i wpisaniem nazwy komputera
- [x] Zabezpieczenie przed junction/symlink i ścieżkami spoza definicji — trzy linie obrony: walidacja definicji, `Test-MwpCleanupRoot` na hoście, kontrola w bloku `Process` (ReparsePoint katalogu głównego, przodków i wpisów, kanoniczność, lokalizacje chronione, usuwanie pojedynczych plików, puste katalogi bez rekurencji)
- [x] Raport po czyszczeniu — `ConvertTo-MwpCleanupReport` (zwolniono, pominięto według powodu, kategorie, tekst), log początku i wyniku każdej kategorii z nazwą komputera
- [x] Analiza składników DISM — `Get-MwpComponentStoreAnalysis` (`/AnalyzeComponentStore /English`, administrator, `-AsOperation`), `Resolve-MwpComponentStoreAnalysis`; czyszczenie magazynu świadomie poza aplikacją (D-047): widok pokazuje zalecenie i polecenie z ostrzeżeniem
- [x] Widok `Cleanup.xaml`, postęp i anulowanie — `src/UI/Views/Cleanup.xaml`, skan i czyszczenie w tle z paskiem postępu i „Anuluj” (skan — natychmiast; czyszczenie — po bieżącym pliku albo kategorii, z raportem tego, co usunięto), DISM jako operacja w tle (pasek stanu)
- [x] Testy Pester na katalogach testowych — `tests/Modules/MWP.Cleanup/Cleanup.Tests.ps1` (46, wyłącznie `TestDrive`), `tests/UI/CleanupView.Tests.ps1` (6)
- [x] Działa dla `localhost` i dla komputera zdalnego (kontekst wykonania `-Context`, błąd połączenia obsłużony na poziomie instancji) — localhost: skan, podgląd i test dymny okna; zdalnie: testy z mockiem transportu WinRM (domyślnie tylko lokalizacje systemowe, profile po jawnym wyborze, nazwa komputera w wyniku i logu, utrata połączenia); **prawdziwy komputer zdalny — DO WERYFIKACJI NA WINDOWS 11**
- [x] Dokumentacja zaktualizowana, commit `FAZA 9: ...`

## Kryteria ukończenia
Test sprawdza, że żadna operacja nie wychodzi poza zdefiniowane ścieżki; domyślnie nic nie jest usuwane bez potwierdzenia.

Spełnione testami: „kryterium: żadna operacja nie wychodzi poza zdefiniowane ścieżki” (wszystkie kategorie i profile na fikcyjnym komputerze w `TestDrive`: każdy usunięty plik leży w katalogu kategorii; junction do katalogu spoza kategorii, lokalizacja chroniona, dokumenty, pliki niepasujące do wzorca i młodsze od progu zostają), dowiązanie w ścieżce katalogu głównego blokuje lokalizację, ścieżka niekanoniczna i chroniona są odrzucane przez blok; `ConfirmImpact High` (bez `-Confirm:$false` funkcja zawsze pyta), `-WhatIf` niczego nie usuwa ani nie loguje, w oknie usuwanie dopiero po oknie potwierdzenia z wpisaniem nazwy komputera (test dymny: anulowanie okna = brak zadania i zmian).

## Do weryfikacji na Windows 11
Skan i czyszczenie realnych kategorii, najpierw `-WhatIf`. Dodatkowo test na komputerze zdalnym użytkownika (obsługa zdalna, utrata połączenia).

## Wyniki
Zakończona 2026-10-28.

- **Baza przed zmianami** (każda wersja w nowym procesie): 5.1.26100.9711 — 0 uwag, 1462/1462; 7.6.7 (`C:\Program Files\PowerShell\7\pwsh.exe`) — 0 uwag, 1462/1462.
- **Wynik końcowy:** `.\tests\Invoke-Checks.ps1`, każda wersja w nowym procesie: 5.1.26100.9711 — 0 uwag PSScriptAnalyzer, 1572/1572; 7.6.7 (`C:\Program Files\PowerShell\7\pwsh.exe`) — 0 uwag, 1572/1572 (baza 1462/1462; +110: `Cleanup.Tests.ps1` 46, `CleanupView.Tests.ps1` 6, testy XAML, kodowania i eksportu nowych plików i funkcji).
- **Decyzja:** D-047 (kategorie jako dane, trzy linie obrony, profile — zdalnie tylko po jawnym wyborze, bez wpisu cofnięcia, anulowanie przez tabelę postępu, DISM tylko analiza).
- **`MWP.Cleanup` 0.9.0:** `Get-MwpCleanupCategory`, `Measure-MwpCleanupCategory`, `Clear-MwpCleanupCategory`, `ConvertTo-MwpCleanupReport`, `Format-MwpCleanupSize`, `Get-MwpComponentStoreAnalysis`, `Resolve-MwpComponentStoreAnalysis`; prywatne: `Get-MwpCleanupScript` (bloki `Environment`, `Process`, `ComponentStore`), `Get-MwpCleanupEnvironment`, `Resolve-MwpCleanupRoot`, `Test-MwpCleanupRoot`, `Invoke-MwpCleanupProcess`, `New-MwpCleanupCategoryResult`; kontrakt: Read, Destructive, RemoteTarget; Embedded, SeparateWindow. `MWP.Core` 0.9.0 (wersja hosta, bez zmian funkcji).
- **Okno (`MWP.UI`):** `Views/Cleanup.xaml`, `Initialize-`/`Update-MwpCleanupView`, `Invoke-MwpCleanupViewAction`, `Start-MwpUiCleanupScan`, `Start-MwpUiCleanup`, `Start-MwpUiComponentStoreAnalysis`; logika prezentacji bez WPF: `Get-MwpCleanupRow`, `Get-MwpCleanupActionState`, `Get-MwpCleanupDetail`, `Get-MwpUiCleanupScript`; wpis w `Get-MwpModuleViewCatalog`.
- **Sprawdzone na tym komputerze (tylko odczyt i podgląd, 5.1 i 7.6.7, bez administratora):** skan 8 kategorii — pliki tymczasowe użytkownika 1983 pliki (3,8 GB; 7,4–8 tys. plików młodszych niż 7 dni pominiętych), Kosz 83 pliki (3,6 MB), miniatury 15 (8,1 MB), kategorie systemowe oznaczone „wymaga uprawnień administratora”; czas skanu ok. 7 s (5.1 i 7.6.7; przed optymalizacją pętli 41 s w 5.1); `Clear-MwpCleanupCategory -WhatIf` — podgląd z liczbą plików, rozmiarem i komputerem, kategoria systemowa odrzucona przed podglądem, nieznana kategoria — błąd; DISM bez administratora — czytelny komunikat, DISM nie jest uruchamiany.
- **Test dymny okna (automatyczny, kopia aplikacji w katalogu tymczasowym, bez usuwania plików)** w 5.1 (motyw jasny) i 7.6.7 (motyw ciemny): instancja „Czyszczenie dysku — localhost”, skan w tle z panelem postępu, tabela 8 kategorii z uwagami, „Wyczyść zaznaczone…” wyłączone bez zaznaczenia, zaznaczenie 2 kategorii (1998 plików, 3,9 GB) → okno potwierdzenia „Operacja destrukcyjna” z listą kategorii, sumą, komputerem docelowym i polem „Aby potwierdzić, wpisz: localhost” → Anuluj: brak zadania czyszczenia, brak raportu; analiza DISM → komunikat o administratorze; kod wyjścia 0; zrzuty obejrzane.
- **Znalezione i poprawione w trakcie:** (1) skan 9,4 tys. plików trwał 41 s w 5.1 — sprawdzanie lokalizacji chronionych przeniesione z każdego pliku na wejście do katalogu, liczenie „nowszych niż próg” bez wywołań bloków (ok. 7 s); (2) brak pliku definicji dawał „udany” skan z 0 kategorii — teraz skan kończy się błędem z przyczyną (wykryte testem dymnym, gdy kopia aplikacji pominęła folder `Data`); (3) tryb ścisły: pola opcjonalne JSON (`exclude`) czytane bez błędu, `if` zwracający jeden profil rozwijał tablicę; (4) błędy lokalizacji przy pustym skanie dają wynik z błędem zamiast „Nic do usunięcia”; (5) PSScriptAnalyzer: `$profile` to zmienna automatyczna, parametr używany tylko w zagnieżdżonym bloku, nazwy funkcji pomocniczych testów (`New-*` → `Write-`/`Get-`/`Initialize-*`).
- **Ograniczenia:** prawdziwe usuwanie nie było wykonywane na komputerze deweloperskim (zasada 5 `CLAUDE.md`) — tylko testy na `TestDrive`, skan i podgląd; skan nie wykrywa plików w użyciu (wykrywa je usuwanie, raport); anulowanie zdalnie działa między kategoriami (lokalnie także w trakcie); czyszczenie magazynu składników (`/StartComponentCleanup`) nie jest wykonywane przez aplikację; pliki pobrane przez Windows Update usuwane bez zatrzymania usługi (pliki w użyciu pomijane; zarządzanie usługą — FAZA 10).

## Do weryfikacji na Windows 11 — lista dla użytkownika
1. CLI, bez administratora: `Measure-MwpCleanupCategory` i `(Measure-MwpCleanupCategory).Data.Categories | Format-Table Name, FileCount, SizeText, SkippedCount`; porównać rozmiar plików tymczasowych z Ustawienia → System → Magazyn → Pliki tymczasowe (różnica: próg 7 dni). Potem `Clear-MwpCleanupCategory -Category UserTemp -WhatIf`.
2. **Kryterium fazy na prawdziwym dysku:** w `%TEMP%` utworzyć folder testowy z plikiem starszym niż 7 dni (`(Get-Item plik).LastWriteTime = (Get-Date).AddDays(-30)` oraz `CreationTime`), plik otwarty w programie (np. dokument w edytorze) i junction do folderu testowego poza `%TEMP%` z plikiem (`New-Item -ItemType Junction`); okno → Czyszczenie dysku → zaznaczyć „Pliki tymczasowe użytkownika” → „Wyczyść zaznaczone…” → wpisać nazwę komputera: stary plik usunięty, otwarty — pominięty „w użyciu”, folder docelowy junction i jego plik nienaruszone; raport w widoku i wpis w Dzienniku operacji.
3. Kosz: przenieść plik testowy do Kosza → „Skanuj” pokazuje go w kategorii Kosz → czyszczenie → Kosz w Eksploratorze pusty.
4. `.\Start-MyWindowsPower.ps1 -Elevate`: kategorie systemowe (Windows\Temp, WER, Windows Update, Optymalizacja dostarczania, logi CBS/DISM) dostępne; czyszczenie wybranych; potem Ustawienia → Windows Update → „Sprawdź aktualizacje” działa.
5. Anulowanie: czyszczenie kategorii z dużą liczbą plików → „Anuluj” w widoku → raport z dopiskiem „przerwane”; anulowanie skanu (widok i pasek stanu).
6. Jako administrator: „Analizuj magazyn składników” — wynik zgodny z `DISM /Online /Cleanup-Image /AnalyzeComponentStore` w konsoli (rozmiary, data ostatniego czyszczenia, zalecenie); anulowanie z paska stanu.
7. Komputer zdalny (Połącz, konto administratora): skan — tylko lokalizacje systemowe, kategorie użytkownika z uwagą „profile użytkowników nie zostały wybrane”; zaznaczenie „Uwzględnij profile wszystkich użytkowników” → ponowny skan obejmuje profile; czyszczenie `Windows\Temp` z wpisaniem nazwy komputera zdalnego; odłączenie sieci w trakcie skanu — błąd tylko w tej instancji.
8. Pliki lokalne: dokumenty, pulpit i OneDrive nie pojawiają się w żadnej kategorii (szczegóły kategorii pokazują lokalizacje).

## Następna faza
FAZA 10 — Windows Update. Prompt: `docs/04_PROMPTY/PROMPT_FAZA_10.md`.
