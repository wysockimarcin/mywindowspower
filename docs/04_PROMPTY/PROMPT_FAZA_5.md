# PROMPT — FAZA 5: Dashboard

> Wklej całość poniżej linii do NOWEJ rozmowy w Claude Code uruchomionej w głównym folderze repozytorium `mywindowspower`.

---

Pracujesz nad projektem **mywindowspower**. Odpowiadaj wyłącznie po polsku. To jest **FAZA 5 — Dashboard**. Nie pamiętasz poprzednich rozmów; ciągłość niesie dokumentacja w repozytorium.

## Start
1. Przeczytaj w kolejności: `CLAUDE.md`, `docs/02_STAN/STAN_PROJEKTU.md`, `docs/00_PROJEKT/CONTEXT.md`, `docs/00_PROJEKT/ARCHITEKTURA.md`, `docs/00_PROJEKT/DECYZJE.md`, `docs/03_FAZY/FAZA_5_DASHBOARD.md`, `docs/05_PROCES/PROCEDURA_FAZY.md`.
2. Wykonaj `git status` i `git log --oneline -10`. Potwierdź, że FAZA 4 jest ZAKOŃCZONA (status, commit, wpis w `CHANGELOG_FAZ.md`). Jeśli nie, zatrzymaj się i zgłoś.
3. Uzupełnij w `CHANGELOG_FAZ.md` hash commita FAZY 4 i ustaw status FAZY 5 na `W TOKU` w `STAN_PROJEKTU.md`.

## Zadanie
Cel: pierwszy realny widok tylko do odczytu (informacje o systemie i sprzęcie) oraz Dashboard jako konfigurowalna kompozycja niezależnych widgetów dla wielu komputerów. W szczególności:
- moduł `MWP.Dashboard` z `Get-MwpSystemInfo` (przyjmuje kontekst wykonania; system, uptime, CPU, RAM, GPU, dyski, BIOS i płyta, bateria, podstawy sieci) na CIM, odporny na braki danych,
- kontrakt widgetu (własna konfiguracja, powiązanie z instancją modułu lub źródłem danych i komputerem, stany: ładowanie, błąd, brak danych, utrata połączenia),
- `Dashboard.xaml`: dodawanie i usuwanie widgetów, komputer i parametry per widget, odświeżanie ręczne i automatyczne z kontrolowaną częstotliwością i limitem zadań, zapis i odtworzenie konfiguracji,
- izolacja widgetów: awaria jednego lub utrata połączenia z jednym komputerem nie zatrzymuje pozostałych; usunięcie widgetu zwalnia zasoby,
- eksport raportu do JSON i tekstu,
- usuwanie widgetów odinstalowanego modułu z Dashboardu i z zapisanej konfiguracji (przy odinstalowaniu i przy odtwarzaniu konfiguracji, D-031),
- testy Pester z mockami CIM i testy izolacji widgetów.
Nie zmieniaj niczego w systemie. Nie wykonuj pracy z innych faz.

## Zamknięcie
Zgodnie z `docs/05_PROCES/PROCEDURA_FAZY.md` (sekcja C): zweryfikuj checklistę, zaktualizuj dokumentację, wykonaj commit `FAZA 5: <krótki opis>` i napisz: „Następna faza: FAZA 6 — Zasilanie. Prompt: `docs/04_PROMPTY/PROMPT_FAZA_6.md`. Otwórz nową rozmowę w Claude Code."
