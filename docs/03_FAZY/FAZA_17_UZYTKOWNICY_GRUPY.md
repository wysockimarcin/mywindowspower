# FAZA 17 — Użytkownicy i grupy lokalne

**Status:** DO ZROBIENIA

## Cel
Przegląd i ostrożne zarządzanie lokalnymi użytkownikami i grupami (moduł z koncepcji pierwotnej, D-020).

## Zależności
FAZY 2, 3 i 4 zakończone.

## Zakres
- Moduł `MWP.Accounts`: lista lokalnych użytkowników (nazwa, pełna nazwa, stan, ostatnie logowanie, przynależność do grup) i lokalnych grup (członkowie).
- Operacje: włączenie i wyłączenie konta, dodanie i usunięcie członka grupy. Operacje **Zmiana** z podglądem, logiem i cofaniem.
- **Lista ochronna:** nie wyłączaj ostatniego aktywnego konta administratora, bieżącego konta ani kont wbudowanych krytycznych; nie usuwaj bieżącego użytkownika z grupy Administratorzy.
- Cmdlety `Microsoft.PowerShell.LocalAccounts` (sprawdź dostępność i zgodność w 5.1 i 7.x, w razie potrzeby wariant przez CIM/ADSI); dla komputera zdalnego przez `Invoke-MwpOnTarget`.
- Widok `Accounts.xaml`; testy Pester z mockami.
- Widget: nowy moduł dostaje widget (np. „Konta lokalne”: liczba kont, wyłączone, administratorzy) — widget Dashboardu wg D-053 — każdy moduł deklaruje co najmniej jeden widget (reguła kompletności w `tests/UI/ModuleWidgets.Tests.ps1`): parametry wyboru danych z minimalnymi wartościami domyślnymi, `DefaultRefreshSeconds = 0` dla odczytów kosztownych, `LocalOnly`/`Enabled` w razie potrzeby; użytkownik ukrywa typ i ustawia domyślne parametry w widoku „Moduły” (sekcja „Widżety”).

## Poza zakresem
Tworzenie i usuwanie kont, zmiana i reset haseł (sekrety), konta domenowe i Entra ID, polityki haseł.

## Checklista
- [ ] `Get-MwpLocalUser`, `Get-MwpLocalGroup` z członkostwem
- [ ] Włącz/wyłącz konto i zmiana członkostwa z podglądem i cofaniem
- [ ] Lista ochronna kont
- [ ] Moduł dopisany do listy w `tests/Modules.Tests.ps1`
- [ ] Widok `Accounts.xaml`
- [ ] Działa dla `localhost` i dla komputera zdalnego (kontekst wykonania `-Context`, błąd połączenia obsłużony na poziomie instancji)
- [ ] Widget Dashboardu zgodny z D-053 (parametry z minimum domyślnym, reguła kompletności)
- [ ] Testy Pester, PSScriptAnalyzer
- [ ] Dokumentacja zaktualizowana, commit `FAZA 17: ...`

## Kryteria ukończenia
Nie da się odciąć sobie dostępu administracyjnego z poziomu GUI; każda zmiana jest w logu i odwracalna.

## Do weryfikacji na Windows 11
Zmiana na koncie testowym (nie administratorskim), z uprawnieniami administratora; to samo na komputerze zdalnym.

## Wyniki
(wypełnia Claude po zakończeniu fazy)

## Następna faza
FAZA 18 — RDP, sesje i zrzuty ekranu. Prompt: `docs/04_PROMPTY/PROMPT_FAZA_18.md`.
