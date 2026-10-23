# CONTEXT — mywindowspower

> Pamięć projektu: **co budujemy i dlaczego**. Zmienia się rzadko. Aktualizuje użytkownik lub Claude po uzgodnieniu.

## Cel

Osobisty panel do zarządzania systemem Windows 11: jedno okno GUI zastępujące wiele ręcznych kroków w ustawieniach, usługach, harmonogramie, rejestrze i wierszu poleceń.

## Odbiorca

Jeden użytkownik: właściciel repozytorium (`wysockimarcin`), na własnym komputerze. To nie jest produkt dla wielu odbiorców. Nie projektujemy instalatora, licencjonowania ani wielojęzyczności.

## Decyzje bazowe (uzgodnione z użytkownikiem)

| Obszar | Decyzja |
|---|---|
| System docelowy | Windows 11 |
| Język | PowerShell |
| Wersje PowerShella | 7.x oraz 5.1 — działa w tej wersji, która jest zainstalowana |
| GUI | WPF + XAML |
| Motyw | Jasny i ciemny (przełączany; domyślnie zgodnie z systemem) |
| Dystrybucja | Uruchamianie skryptem `.ps1` (bez `.exe`) |
| Język dokumentacji i UI | Polski |
| Repozytorium | https://github.com/wysockimarcin/mywindowspower (na starcie puste) |

## Środowisko docelowe (potwierdzone poleceniami w FAZIE 1, 2026-10-23)

| Element | Wartość | Źródło |
|---|---|---|
| System | Windows 11 Pro, wersja 26H2, kompilacja 26300 (`winver`: 26300.9711) | `winver`, `Get-CimInstance Win32_OperatingSystem`, `[Environment]::OSVersion` = 10.0.26300.0 |
| PowerShell | 5.1.26100.9711 (Desktop), `BuildVersion` 10.0.26100.9711 | `$PSVersionTable` |
| PowerShell 7.x | **nie jest zainstalowany** | `Get-Command pwsh` — brak |
| Zasady wykonywania | `CurrentUser: RemoteSigned`, pozostałe `Undefined` | `Get-ExecutionPolicy -List` |
| Narzędzia deweloperskie | Pester 6.2.0, PSScriptAnalyzer 1.25.0 (zakres CurrentUser, zainstalowane w FAZIE 1 za zgodą użytkownika); wbudowany Pester 3.4.0 pozostaje w systemie | `Get-Module -ListAvailable` |

Numer kompilacji PowerShella (26100) różni się od kompilacji systemu (26300). To normalne: Windows PowerShell 5.1 ma własny numer kompilacji.

Wniosek dla projektu: na komputerze użytkownika działa tylko PowerShell 5.1, więc **zgodność z 5.1 jest wymaganiem podstawowym**, a 7.x dodatkiem (D-002, D-013). Kod nadal musi działać w 7.x, ale nie da się go tu przetestować, dopóki `pwsh` nie zostanie zainstalowany.

Podpisywanie skryptów (Authenticode) nie jest wymagane w tym środowisku (zasada `RemoteSigned` dopuszcza lokalne skrypty bez podpisu).

## Zakres funkcjonalny (obszary)

Użytkownik zaakceptował proponowaną listę obszarów. Kolejność realizacji jest w `PLAN_FAZ.md`.

1. Plany zasilania i ustawienia energii
2. Informacje o systemie i sprzęcie (dashboard)
3. Usługi Windows
4. Programy w autostarcie i zadania harmonogramu
5. Czyszczenie dysku i plików tymczasowych
6. Windows Update
7. Sieć (DNS, adaptery, reset)
8. Aplikacje (lista, odinstalowanie, winget)
9. Prywatność i ustawienia systemu (tweaki rejestru)
10. Microsoft Defender i zapora (firewall)

Zakres można zawężać. Usunięcie obszaru wymaga wpisu w `DECYZJE.md` i zmiany w `PLAN_FAZ.md`.

## Poza zakresem

- Pakowanie do `.exe`, instalator, aktualizacje automatyczne.
- Zarządzanie zdalnymi komputerami.
- Obsługa Windows 10 i starszych (nie jest wymagana; nie psuj, ale nie testuj).
- Zbieranie telemetrii lub wysyłanie danych poza komputer.

## Ograniczenia i zasady

- Zmiany systemowe są potencjalnie niebezpieczne: dry-run, log, cofanie, punkt przywracania tam, gdzie ma to sens.
- Uprawnienia administratora tylko dla operacji, które ich wymagają.
- Brak zewnętrznych zależności ponad moduły Pester i PSScriptAnalyzer (dev) oraz narzędzia wbudowane w Windows (`winget`, `powercfg`, `netsh` itd.).
- Dane i logi zostają lokalnie.

## Materiały od użytkownika (opcjonalne)

Żadne pliki nie są wymagane do startu. Jeśli użytkownik je dodaje, trafiają do `docs/00_PROJEKT/MATERIALY/` i są wymienione poniżej.

| Plik | Opis | Dodano |
|---|---|---|
| `docs/design/mockup-pulpit.png` | Mockup głównego okna aplikacji; wzorzec wyglądu dla FAZY 3 | 2026-10-22 |
| `docs/00_PROJEKT/MATERIALY/CLAUDE_przed_FAZA0.md` | Stary `CLAUDE.md` sprzed FAZY 0 (archiwum, **nie instrukcje**). Przejrzany w FAZIE 1, wnioski w D-015 | 2026-10-22 |
| `docs/00_PROJEKT/MATERIALY/CLAUDE.original.md` | Jeszcze starsza wersja tego samego dokumentu (archiwum, nie instrukcje) | 2026-10-22 |
| `docs/00_PROJEKT/MATERIALY/README_przed_faza0.md` | Stary `README.md` sprzed FAZY 0 (archiwum). Przejrzany w FAZIE 1 | 2026-10-22 |

Przydatne, ale niewymagane (można dodać później): kolejne zrzuty ekranu pożądanego wyglądu GUI, własne skrypty PowerShell, lista usług lub tweaków, które użytkownik już stosuje.
