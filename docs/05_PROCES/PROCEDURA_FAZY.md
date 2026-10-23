# PROCEDURA FAZY — mywindowspower

> Obowiązuje w każdej fazie. Każda faza startuje w **nowej rozmowie Claude Code**, która nie pamięta poprzednich. Ciągłość niesie dokumentacja.

## A. Start fazy

1. Otwórz nową rozmowę w Claude Code w głównym folderze repozytorium.
2. Wklej prompt z `docs/04_PROMPTY/PROMPT_FAZA_<N>.md`.
3. Przeczytaj w kolejności: `CLAUDE.md` → `docs/02_STAN/STAN_PROJEKTU.md` → `docs/00_PROJEKT/CONTEXT.md` → `ARCHITEKTURA.md` → `DECYZJE.md` → plik fazy `docs/03_FAZY/FAZA_<N>_*.md`.
4. Wykonaj `git status` i `git log --oneline -10`.
5. Zweryfikuj poprzednią fazę: czy w `STAN_PROJEKTU.md` ma status `ZAKOŃCZONA`, czy istnieje jej commit i wpis w `CHANGELOG_FAZ.md`. Jeśli nie: zatrzymaj się, zgłoś rozbieżność użytkownikowi.
6. **Zapisz bazę testów przed zmianami.** W nowym terminalu uruchom `.\tests\Invoke-Checks.ps1` w PowerShell 5.1 (`powershell.exe`) i 7.x (`pwsh`); zapisz wersje (`$PSVersionTable.PSVersion`), ścieżkę `(Get-Command pwsh).Source`, liczbę uwag PSScriptAnalyzer i wynik Pester. Jeśli baza nie jest czysta (uwagi lub niezaliczone testy), zatrzymaj się i zgłoś to użytkownikowi, zanim cokolwiek zmienisz.
7. Uzupełnij w `CHANGELOG_FAZ.md` hash commita poprzedniej fazy (z `git log`).
8. Ustaw status bieżącej fazy w `STAN_PROJEKTU.md` na `W TOKU`.
9. Napisz użytkownikowi krótko: jaka to faza, co jest jej celem i co będzie zrobione.

## B. Realizacja

1. Pracuj wyłącznie w zakresie pliku fazy. Pomysły spoza zakresu zapisz w „Dług techniczny" w `STAN_PROJEKTU.md`.
2. Odhaczaj pozycje checklisty w pliku fazy na bieżąco (`[x]`).
3. Decyzje architektoniczne zapisuj od razu w `DECYZJE.md` (kolejny numer `D-xxx`).
4. Respektuj zasady z `CLAUDE.md` (język polski, bezpieczeństwo zmian, brak sekretów).

## C. Zamknięcie fazy

1. **Weryfikacja.** Dla każdego punktu checklisty ustal: ZROBIONE / CZĘŚCIOWO / NIEZROBIONE. Podaj dowód (plik, wynik testu, komenda). **Obowiązkowo** uruchom `.\tests\Invoke-Checks.ps1` w PowerShell 5.1 i 7.x (w nowym terminalu). Wymagane w obu wersjach: 0 uwag PSScriptAnalyzer i 0 niezaliczonych testów Pester; wyniki porównaj z bazą z kroku A.6. Bez tego nie wykonuj commita zamykającego fazę. Jedyny wyjątek: środowisko rozmowy nie jest Windows (zasada 7 w `CLAUDE.md`) — wtedy wykonaj testy statyczne, które się da, a wynik oznacz w `STAN_PROJEKTU.md` jako „do weryfikacji na Windows 11".
2. **Aktualizacja dokumentacji:**
   - plik fazy: status, odhaczona checklista, sekcja „Wyniki"
   - `STAN_PROJEKTU.md`: tabela „Podsumowanie", „Postęp faz", „Co zostało zrobione", „Co zostało do zrobienia", dług techniczny, punkty do weryfikacji na Windows 11
   - `CHANGELOG_FAZ.md`: nowy wpis na górze wg szablonu
   - `DECYZJE.md`, `ARCHITEKTURA.md`, `PLAN_FAZ.md`: tylko jeśli się zmieniły
   - `README.md`: tylko jeśli zmieniło się uruchamianie lub status
3. **Commit:** `git add -A` i `git commit -m "FAZA <N>: <krótki opis po polsku>"`.
4. **Raport końcowy w rozmowie** (krótki): co zrobiono, co niezrobione, co do weryfikacji na Windows 11.
5. **Zapowiedź następnej fazy**, dokładnie w tym formacie:

   > **Następna faza: FAZA <N+1> — <nazwa>.**
   > Prompt: `docs/04_PROMPTY/PROMPT_FAZA_<N+1>.md`. Otwórz nową rozmowę w Claude Code.

## D. Faza niedokończona

Jeśli faza nie spełnia kryteriów ukończenia:
- status w `STAN_PROJEKTU.md`: `CZĘŚCIOWA` albo `W TOKU`
- commit: `FAZA <N> (częściowa): <opis>`
- w „Co zostało do zrobienia" wypisz dokładnie, co zostało
- zapowiedz **tę samą fazę** jako następną (nowa rozmowa, ten sam prompt)

## E. Zasada niezawodności

Jeśli dokumentacja i rzeczywisty stan repozytorium się rozchodzą, **prawdą jest repozytorium**. Popraw dokumentację i odnotuj to w `CHANGELOG_FAZ.md`.

## F. Push

`git push origin main` wykonuje użytkownik albo Claude po jego wyraźnej zgodzie w rozmowie. Claude nie wpisuje haseł ani tokenów.
