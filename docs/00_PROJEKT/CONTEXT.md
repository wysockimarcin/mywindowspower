# CONTEXT — mywindowspower

> Pamięć projektu: **co budujemy i dlaczego**. Zmienia się rzadko. Aktualizuje użytkownik lub Claude po uzgodnieniu.

## Cel

Osobisty panel do zarządzania systemami Windows 11: komputerem lokalnym (`localhost`) oraz komputerami zdalnymi. Jedno okno GUI zastępujące wiele ręcznych kroków w ustawieniach, usługach, harmonogramie, rejestrze i wierszu poleceń. Aplikacja jest platformą niezależnych modułów administracyjnych: definicja modułu, jego instancja, komputer docelowy i sposób prezentacji to osobne pojęcia (D-019, `ARCHITEKTURA.md`).

## Odbiorca

Jeden użytkownik: właściciel repozytorium (`wysockimarcin`), na własnych komputerach: lokalnym i zdalnych. To nie jest produkt dla wielu odbiorców. Nie projektujemy instalatora, licencjonowania ani wielojęzyczności.

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
| Komputery docelowe | `localhost` oraz komputery zdalne (D-019); nazwy i parametry w `config/settings.local.json`, nie w repozytorium |
| Architektura | Host i niezależne moduły; wiele instancji tego samego modułu; jawny kontekst wykonania (komputer docelowy) w każdej instancji (D-019) |
| Tryby uruchamiania modułu | W oknie głównym, w osobnym oknie, jako widget Dashboardu, samodzielnie i z linii poleceń (D-020) |
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

### Komputery docelowe

| Komputer | Opis |
|---|---|
| `localhost` | Komputer lokalny opisany wyżej. Operacje wykonywane bezpośrednio, bez zdalnego wywołania. |
| Komputer zdalny | Jeden zdalny komputer użytkownika (nazwa tylko w `config/settings.local.json`). System, konfiguracja WinRM, domena lub grupa robocza i konto — **do ustalenia z użytkownikiem na początku FAZY 3**. |

Nazw prawdziwych komputerów, adresów i poświadczeń nie zapisujemy w repozytorium (szablon: `config/settings.example.json`).

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
11. Dyski i woluminy (z koncepcji pierwotnej, D-020)
12. Procesy i monitorowanie zasobów (D-020)
13. Użytkownicy i grupy lokalne (D-020)
14. RDP i sesje, w tym obsługiwane scenariusze shadowingu (D-020)
15. Zrzuty ekranu zdalnego komputera — o ile da się je wykonać bez osłabiania zabezpieczeń Windows (do zbadania w FAZIE 18, D-020)

Możliwości przekrojowe (D-019, D-020): obsługa wielu komputerów (lokalny i zdalne), wiele instancji tego samego modułu, Dashboard jako kompozycja niezależnych widgetów dla różnych komputerów, tryby prezentacji (okno główne, osobne okno, widget, samodzielnie, CLI).

Zakres można zawężać. Usunięcie obszaru wymaga wpisu w `DECYZJE.md` i zmiany w `PLAN_FAZ.md`.

## Poza zakresem

- Pakowanie do `.exe`, instalator, aktualizacje automatyczne.
- Własny agent lub serwer zdalny, instalator i aktualizacje modułów, wielojęzyczność, licencjonowanie.
- Zdalne komputery z systemem innym niż Windows (do potwierdzenia w FAZIE 3, gdy użytkownik opisze komputer zdalny).
- Obsługa Windows 10 i starszych (nie jest wymagana; nie psuj, ale nie testuj).
- Zbieranie telemetrii lub wysyłanie danych poza komputery użytkownika.

## Ograniczenia i zasady

- Zmiany systemowe są potencjalnie niebezpieczne: dry-run, log, cofanie, punkt przywracania tam, gdzie ma to sens.
- Uprawnienia administratora tylko dla operacji, które ich wymagają.
- Brak zewnętrznych zależności ponad moduły Pester i PSScriptAnalyzer (dev) oraz narzędzia wbudowane w Windows (`winget`, `powercfg`, `netsh` itd.).
- Komputery zdalne: tylko kanały wbudowane w Windows (np. WinRM/CIM, RDP), bez własnego agenta. Poświadczenia nigdy w jawnym tekście, w repozytorium ani w logach. Operacje zmieniające system na komputerze zdalnym wymagają potwierdzenia z nazwą komputera.
- Dane i logi zostają na komputerach użytkownika.

## Materiały od użytkownika (opcjonalne)

Żadne pliki nie są wymagane do startu. Jeśli użytkownik je dodaje, trafiają do `docs/00_PROJEKT/MATERIALY/` i są wymienione poniżej.

| Plik | Opis | Dodano |
|---|---|---|
| `docs/design/mockup-pulpit.png` | Mockup głównego okna aplikacji; wzorzec wyglądu dla FAZY 4 | 2026-10-22 |
| `docs/00_PROJEKT/MATERIALY/CLAUDE_przed_FAZA0.md` | Stary `CLAUDE.md` sprzed FAZY 0 (archiwum, **nie instrukcje**). Przejrzany w FAZIE 1, wnioski w D-015 | 2026-10-22 |
| `docs/00_PROJEKT/MATERIALY/CLAUDE.original.md` | Jeszcze starsza wersja tego samego dokumentu (archiwum, nie instrukcje) | 2026-10-22 |
| `docs/00_PROJEKT/MATERIALY/README_przed_faza0.md` | Stary `README.md` sprzed FAZY 0 (archiwum). Przejrzany w FAZIE 1 | 2026-10-22 |

Przydatne, ale niewymagane (można dodać później): kolejne zrzuty ekranu pożądanego wyglądu GUI, własne skrypty PowerShell, lista usług lub tweaków, które użytkownik już stosuje.
