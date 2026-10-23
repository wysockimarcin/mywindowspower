# PROMPT — FAZA 11: Sieć

> Wklej całość poniżej linii do NOWEJ rozmowy w Claude Code uruchomionej w głównym folderze repozytorium `mywindowspower`.

---

Pracujesz nad projektem **mywindowspower**. Odpowiadaj wyłącznie po polsku. To jest **FAZA 11 — Sieć**. Nie pamiętasz poprzednich rozmów; ciągłość niesie dokumentacja w repozytorium.

## Start
1. Przeczytaj w kolejności: `CLAUDE.md`, `docs/02_STAN/STAN_PROJEKTU.md`, `docs/00_PROJEKT/CONTEXT.md`, `docs/00_PROJEKT/ARCHITEKTURA.md`, `docs/00_PROJEKT/DECYZJE.md`, `docs/03_FAZY/FAZA_11_SIEC.md`, `docs/05_PROCES/PROCEDURA_FAZY.md`.
2. Wykonaj `git status` i `git log --oneline -10`. Potwierdź, że FAZA 10 jest ZAKOŃCZONA (status, commit, wpis w `CHANGELOG_FAZ.md`). Jeśli nie, zatrzymaj się i zgłoś.
3. Uzupełnij w `CHANGELOG_FAZ.md` hash commita FAZY 10 i ustaw status FAZY 11 na `W TOKU` w `STAN_PROJEKTU.md`.

## Zadanie
Cel: diagnostyka i konfiguracja sieci z możliwością cofnięcia zmian. W szczególności:
- moduł `MWP.Network`: adaptery, konfiguracja IP, włącz/wyłącz adapter z ostrzeżeniem,
- DNS: presety (DHCP, Cloudflare, Google, Quad9) i własne adresy, zapis poprzednich ustawień, cofanie,
- flush DNS, odnowienie DHCP, resety Winsock i stosu IP z potwierdzeniem i informacją o restarcie,
- testy łączności (ping, `Resolve-DnsName`, test portu),
- widok `Network.xaml`, testy Pester z mockami,
- obsługa komputera docelowego (D-019): ochrona przed utratą łączności przy zmianie IP, DNS i adaptera użytego do połączenia (potwierdzenie, automatyczne wycofanie po limicie czasu).
Nie wykonuj pracy z innych faz.

## Zamknięcie
Zgodnie z `docs/05_PROCES/PROCEDURA_FAZY.md` (sekcja C): zweryfikuj checklistę, zaktualizuj dokumentację, wykonaj commit `FAZA 11: <krótki opis>` i napisz: „Następna faza: FAZA 12 — Aplikacje i winget. Prompt: `docs/04_PROMPTY/PROMPT_FAZA_12.md`. Otwórz nową rozmowę w Claude Code."
