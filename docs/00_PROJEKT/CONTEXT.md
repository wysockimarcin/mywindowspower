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
| (brak) | | |

Przydatne, ale niewymagane: zrzuty ekranu pożądanego wyglądu GUI, własne skrypty PowerShell, lista usług lub tweaków, które użytkownik już stosuje, wynik `$PSVersionTable` i `winver` z komputera docelowego.
