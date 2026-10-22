# CLAUDE.md — mywindowspower

Ten plik jest czytany automatycznie na początku każdej rozmowy w Claude Code.
Rozmowa nie pamięta poprzednich rozmów. **Całą ciągłość niesie dokumentacja w `docs/`.**

## Projekt w jednym zdaniu

Osobisty panel GUI (WPF/XAML) do zarządzania systemem Windows 11, napisany w PowerShellu (7.x i 5.1), uruchamiany skryptem `.ps1`. Repozytorium: https://github.com/wysockimarcin/mywindowspower

## Zasady bezwzględne

1. **Język:** wszystkie odpowiedzi, dokumentacja, komentarze w dokumentach i komunikaty commitów są **po polsku**. Identyfikatory w kodzie (funkcje, zmienne) mogą być po angielsku, zgodnie z konwencją PowerShella (`Verb-Noun`).
2. **Każda faza = nowa rozmowa.** Pracujesz wyłącznie nad jedną fazą naraz: tą wskazaną w `docs/02_STAN/STAN_PROJEKTU.md` (pole „Następna faza") lub w prompcie użytkownika. Nie wykonuj pracy z przyszłych faz.
3. **Dokumentacja jest pamięcią.** Aktualizujesz ją sam, na końcu każdej fazy, zgodnie z `docs/05_PROCES/PROCEDURA_FAZY.md`.
4. **Nie zgaduj.** Gdy brakuje informacji potrzebnej do decyzji, zapytaj użytkownika. Decyzje zapisuj w `docs/00_PROJEKT/DECYZJE.md`.
5. **Bezpieczeństwo systemu.** Projekt zmienia ustawienia Windows. Każda zmiana systemowa musi mieć tryb podglądu (dry-run), log operacji i możliwość cofnięcia, o ile to technicznie możliwe (szczegóły: `docs/00_PROJEKT/ARCHITEKTURA.md`). Nigdy nie wykonuj zmian systemowych na maszynie użytkownika podczas pisania kodu bez jego wyraźnej zgody.
6. **Sekrety.** Nigdy nie zapisuj w repozytorium haseł, tokenów ani kluczy. Nie wpisuj ich do żadnych pól.
7. **Zakres Windows.** Kod uruchamiany jest na Windows 11. Jeśli rozmowa działa w środowisku innym niż Windows (np. Linux), kodu WPF i operacji systemowych nie da się uruchomić. Wtedy pisz kod i testy statyczne (PSScriptAnalyzer, parsowanie składni), a w stanie projektu zaznacz, co wymaga weryfikacji na Windows 11.

## Kolejność czytania na starcie każdej rozmowy

1. `CLAUDE.md` (ten plik)
2. `docs/02_STAN/STAN_PROJEKTU.md` — źródło prawdy o postępie
3. `docs/00_PROJEKT/CONTEXT.md` — cel, zakres, ograniczenia
4. `docs/00_PROJEKT/ARCHITEKTURA.md` — stack, struktura kodu, konwencje
5. `docs/03_FAZY/FAZA_<N>_*.md` — plik bieżącej fazy (zakres + checklista)
6. `docs/00_PROJEKT/DECYZJE.md` — dotychczasowe decyzje
7. `docs/05_PROCES/PROCEDURA_FAZY.md` — procedura startu i zamknięcia fazy

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

- Jeden moduł na obszar, w `src/Modules/`. Logika oddzielona od GUI.
- Zgodność z PowerShell 5.1 i 7.x. Różnice obsługuj jawnie, nie zakładaj jednej wersji.
- Testy w Pester, analiza w PSScriptAnalyzer. Przed zamknięciem fazy oba muszą przejść (o ile da się je uruchomić).
- Długich operacji nie wykonuj w wątku UI (runspace / asynchronicznie).
