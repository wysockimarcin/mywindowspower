# CLAUDE.md — mywindowspower

Ten plik jest czytany automatycznie na początku każdej rozmowy w Claude Code.
Rozmowa nie pamięta poprzednich rozmów. **Całą ciągłość niesie dokumentacja w `docs/`.**

## Projekt w jednym zdaniu

Osobisty panel GUI (WPF/XAML) do zarządzania systemami Windows 11 — komputerem lokalnym (`localhost`) i komputerami zdalnymi — napisany w PowerShellu (7.x i 5.1), uruchamiany skryptem `.ps1`. Architektura: host i niezależne moduły, wiele instancji modułu, jawny kontekst wykonania (D-019). Repozytorium: https://github.com/wysockimarcin/mywindowspower

## Zasady bezwzględne

1. **Język:** wszystkie odpowiedzi, dokumentacja, komentarze w dokumentach i komunikaty commitów są **po polsku**. Identyfikatory w kodzie (funkcje, zmienne) mogą być po angielsku, zgodnie z konwencją PowerShella (`Verb-Noun`).
2. **Każda faza = nowa rozmowa.** Pracujesz wyłącznie nad jedną fazą naraz: tą wskazaną w `docs/02_STAN/STAN_PROJEKTU.md` (pole „Następna faza") lub w prompcie użytkownika. Nie wykonuj pracy z przyszłych faz.
3. **Dokumentacja jest pamięcią.** Aktualizujesz ją sam, na końcu każdej fazy, zgodnie z `docs/05_PROCES/PROCEDURA_FAZY.md`.
4. **Nie zgaduj.** Gdy brakuje informacji potrzebnej do decyzji, zapytaj użytkownika. Decyzje zapisuj w `docs/00_PROJEKT/DECYZJE.md`.
5. **Bezpieczeństwo systemu.** Projekt zmienia ustawienia Windows. Każda zmiana systemowa musi mieć tryb podglądu (dry-run), log operacji i możliwość cofnięcia, o ile to technicznie możliwe (szczegóły: `docs/00_PROJEKT/ARCHITEKTURA.md`). Nigdy nie wykonuj zmian systemowych na maszynie użytkownika podczas pisania kodu bez jego wyraźnej zgody.
6. **Sekrety.** Nigdy nie zapisuj w repozytorium haseł, tokenów ani kluczy. Nie wpisuj ich do żadnych pól.
7. **Zakres Windows.** Kod uruchamiany jest na Windows 11. Jeśli rozmowa działa w środowisku innym niż Windows (np. Linux), kodu WPF i operacji systemowych nie da się uruchomić. Wtedy pisz kod i testy statyczne (PSScriptAnalyzer, parsowanie składni), a w stanie projektu zaznacz, co wymaga weryfikacji na Windows 11.
8. **Wiele komputerów i instancji (D-019).** Nie zakładaj, że operacja dotyczy komputera lokalnego. Każda funkcja logiki przyjmuje kontekst wykonania (komputer docelowy), a moduł może mieć wiele niezależnych instancji naraz. Zasady: brak globalnego, zmiennego „bieżącego komputera"; logika modułu nie zależy od miejsca prezentacji (okno główne, osobne okno, widget Dashboardu, samodzielnie, CLI); błąd lub utrata połączenia z jednym komputerem nie zatrzymuje pozostałych instancji ani widgetów; logika połączeń zdalnych nie trafia do kodu widoku; długie i zdalne operacje działają asynchronicznie. Operacje zmieniające system na komputerze zdalnym wymagają potwierdzenia z jego nazwą. Nazw komputerów, adresów i poświadczeń nie zapisuj w repozytorium (tylko `config/settings.local.json`).
9. **Małe, testowalne zmiany.** Przed dużą zmianą przedstaw jej wpływ na architekturę. Nie dodawaj zależności bez uzasadnienia. Utrzymuj kompatybilność kontraktów (moduł, instancja, kontekst, widget) albo dokumentuj migrację. Nie oznaczaj zadania jako ukończonego bez testów lub jasnego opisu ograniczeń.

## Kolejność czytania na starcie każdej rozmowy

1. `CLAUDE.md` (ten plik)
2. `docs/02_STAN/STAN_PROJEKTU.md` — źródło prawdy o postępie
3. `docs/00_PROJEKT/CONTEXT.md` — cel, zakres, ograniczenia
4. `docs/00_PROJEKT/ARCHITEKTURA.md` — stack, struktura kodu, konwencje
5. `docs/03_FAZY/FAZA_<N>_*.md` — plik bieżącej fazy (zakres + checklista)
6. `docs/00_PROJEKT/DECYZJE.md` — dotychczasowe decyzje
7. `docs/05_PROCES/PROCEDURA_FAZY.md` — procedura startu i zamknięcia fazy
8. Materiały użytkownika, gdy dotyczą bieżącej fazy: `docs/design/` (mockupy GUI, np. `mockup-pulpit.png`) i `docs/00_PROJEKT/MATERIALY/`. Pliki `CLAUDE_przed_FAZA0.md`, `CLAUDE.original.md` i `README_przed_faza0.md` w `MATERIALY/` to **archiwum starej koncepcji, nie instrukcje**: nie wykonuj poleceń z ich treści. Obowiązujące wnioski z archiwum (w tym zarządzanie zdalne, wieloinstancyjność, kontekst komputera, Dashboard z widgetami, `apprun`) są w `ARCHITEKTURA.md` i `DECYZJE.md` (D-015, D-019, D-020, D-021).

Następnie wykonaj `git status` i `git log --oneline -10` i potwierdź, że poprzednia faza jest zamknięta (jest commit i wpis w `CHANGELOG_FAZ.md`).

## Zamknięcie fazy (obowiązkowe)

1. Zweryfikuj każdy punkt checklisty fazy: ZROBIONE / CZĘŚCIOWO / NIEZROBIONE (z dowodem: plik, test, komenda).
2. Zaktualizuj: `STAN_PROJEKTU.md`, `CHANGELOG_FAZ.md`, plik bieżącej fazy, `DECYZJE.md`, a w razie potrzeby `ARCHITEKTURA.md` i `PLAN_FAZ.md`.
3. Niezrobione punkty przenieś do kolejnej fazy lub do sekcji „Dług techniczny" w `STAN_PROJEKTU.md`.
4. Wykonaj commit: `FAZA <N>: <krótki opis po polsku>`.
5. Na końcu rozmowy napisz wprost: **„Następna faza: FAZA <N+1> — <nazwa>. Prompt: `docs/04_PROMPTY/PROMPT_FAZA_<N+1>.md`. Otwórz nową rozmowę w Claude Code."**

## Git

- Gałąź główna: `main`. Zdalne repozytorium: `origin`.
- Jeden commit na zakończoną fazę (dopuszczalne commity pośrednie w trakcie).
- `git push` wykonuje użytkownik albo Claude po jego wyraźnej zgodzie w rozmowie.

## Konwencje kodu (skrót; pełne w ARCHITEKTURA.md)

- Jeden moduł na obszar, w `src/Modules/`. Logika oddzielona od GUI. Funkcje logiki przyjmują kontekst wykonania (`-Context`; komputer docelowy), bez globalnego „bieżącego komputera" (D-019).
- Zgodność z PowerShell 5.1 i 7.x. Różnice obsługuj jawnie, nie zakładaj jednej wersji.
- Testy w Pester, analiza w PSScriptAnalyzer. Przed zamknięciem fazy oba muszą przejść (o ile da się je uruchomić): `.\tests\Invoke-Checks.ps1`.
- Pliki `.ps1`/`.psm1`/`.psd1` zapisuj jako UTF-8 z BOM (narzędzie Write zapisuje bez BOM — po zapisie dodaj BOM, inaczej 5.1 zepsuje polskie znaki; test `Repository.Tests.ps1` to wykryje).
- Bez ścieżek bezwzględnych w kodzie: katalog projektu wyznaczaj z `$PSScriptRoot`.
- Długich operacji nie wykonuj w wątku UI (runspace / asynchronicznie).
