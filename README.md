# mywindowspower

Osobisty panel do zarządzania systemami Windows 11 — komputerem lokalnym (`localhost`) i komputerami zdalnymi — napisany w PowerShellu z interfejsem graficznym WPF/XAML.

- **Platforma:** Windows 11
- **Język:** PowerShell (działa w 7.x i w wbudowanym 5.1)
- **GUI:** WPF + XAML, motyw jasny/ciemny
- **Uruchamianie:** skryptem `.ps1`
- **Komputery:** `localhost` i komputery zdalne; niezależne moduły, wiele instancji modułu, Dashboard z widgetami (zob. `docs/00_PROJEKT/ARCHITEKTURA.md`)

## Status

Projekt jest prowadzony fazami. Aktualny stan: [`docs/02_STAN/STAN_PROJEKTU.md`](docs/02_STAN/STAN_PROJEKTU.md).
Plan faz: [`docs/01_PLAN/PLAN_FAZ.md`](docs/01_PLAN/PLAN_FAZ.md).

## Dokumentacja

Cała dokumentacja i pamięć projektu znajdują się w folderze [`docs/`](docs/).
Zasady pracy w Claude Code opisuje [`CLAUDE.md`](CLAUDE.md).

## Uruchomienie

Wymagania: Windows 11, Windows PowerShell 5.1 (wbudowany) lub PowerShell 7.x.

W katalogu repozytorium:

```powershell
.\Start-MyWindowsPower.ps1
```

Launcher sprawdza wersję PowerShella, system i tryb STA (w razie potrzeby uruchamia się ponownie z `-STA`), wypisuje status administratora, importuje moduły (wbudowane z `src/Modules` i zainstalowane z paczek z katalogu danych), sprawdzając kontrakt każdego modułu (wersja, zależności), i otwiera okno aplikacji (FAZA 4). Pulpit to Dashboard z widgetami (FAZA 5): informacje o systemie i sprzęcie dla `localhost` i komputerów zdalnych, odświeżanie ręczne i automatyczne, eksport raportu do JSON lub tekstu; układ widgetów jest zapisywany w `config/settings.local.json`. Obszar **Zasilanie** (FAZA 6): plany zasilania, czasy wygaszania i uśpienia (sieć/bateria), przyciski i pokrywa, hibernacja, szybkie uruchamianie, raporty baterii i energii — dla `localhost` i komputerów zdalnych; każda zmiana ma podgląd, potwierdzenie z nazwą komputera, wpis w logu i możliwość cofnięcia. Obszar **Usługi** (FAZA 7): lista usług z filtrami, uruchamianie, zatrzymywanie i ponowne uruchamianie razem z usługami zależnymi, typ uruchomienia (także opóźniony start), profil usług (eksport i import z podglądem różnic) — usług krytycznych z listy ochronnej nie da się zatrzymać ani wyłączyć; listę można rozszerzyć plikiem `config/protected.local.json`. Obszar **Autostart i harmonogram** (FAZA 8): programy uruchamiane z systemem (rejestr Run/RunOnce, foldery Autostart) z podpisem wydawcy — włączanie i wyłączanie jak w Menedżerze zadań, bez kasowania wpisów; zadania harmonogramu: włączanie, wyłączanie, uruchamianie i usuwanie z zapisem definicji XML (zadań systemowych Microsoft nie da się usunąć, a krytycznych — wyłączyć). Obszar **Czyszczenie dysku** (FAZA 9): skan kategorii (pliki tymczasowe użytkownika i Windows, Kosz, miniatury, raporty błędów, pobrane pliki Windows Update, Optymalizacja dostarczania, logi CBS/DISM) z rozmiarami, usuwanie zaznaczonych kategorii dopiero po potwierdzeniu z wpisaniem nazwy komputera i raport (ile zwolniono, ile pominięto i dlaczego); usuwane są wyłącznie pliki z lokalizacji kategorii — pliki w użyciu i dowiązania są pomijane, a dokumenty i pulpit nigdy nie są usuwane; analiza magazynu składników DISM (tylko analiza). Obszar **Windows Update** (FAZA 10): stan usług i wymaganego restartu, wyszukiwanie oczekujących aktualizacji i historia (wbudowany Windows Update Agent, bez modułów zewnętrznych), pauza na 1–5 tygodni taka sama jak w Ustawieniach, reset składników (stare foldery `SoftwareDistribution` i `catroot2` zostają, cofnięcie je przywraca) i instalacja zaznaczonych aktualizacji na tym komputerze po potwierdzeniu, bez automatycznego restartu; na komputerze zdalnym instalację wykonuje się w Ustawieniach tamtego komputera. Obszar **Sieć** (FAZA 11): adaptery z konfiguracją IP, DNS, DHCP i profilem, włączanie i wyłączanie adapterów, zmiana DNS (DHCP, Cloudflare, Google, Quad9 albo własne adresy) z cofaniem jednym kliknięciem, opróżnienie pamięci DNS, odnowienie dzierżawy DHCP, reset Winsock i stosu IP (z potwierdzeniem, wymagają restartu) oraz testy łączności (ping, DNS, port TCP); zmianę DNS i wyłączenie adaptera trzeba zatwierdzić w ciągu 2 minut — inaczej komputer sam przywróci poprzedni stan, także gdy zmiana odetnie połączenie z komputerem zdalnym. Obszar **Aplikacje** (FAZA 12): lista programów i pakietów Appx z filtrami, aktualizacje przez winget (pojedynczo albo zaznaczone), wyszukiwanie i instalacja pakietów z repozytorium winget, odinstalowanie po potwierdzeniu z możliwością ponownej instalacji; składników systemu (Microsoft Store, Edge, Instalator aplikacji, biblioteki) nie da się usunąć. Sam start aplikacji niczego nie zmienia w systemie. Uprawnienia administratora tylko na życzenie: `.\Start-MyWindowsPower.ps1 -Elevate` (monit UAC); bez okna (tylko import modułów): `.\Start-MyWindowsPower.ps1 -NoGui`. Dane aplikacji (logi, rejestr cofnięć, moduły z paczek): domyślnie folder `data` obok aplikacji, zmiana w oknie: **Ustawienia → Katalog danych**. Wymagania po stronie komputera zdalnego: `docs/00_PROJEKT/ARCHITEKTURA.md`, sekcja „Konfiguracja komputera zdalnego” (pełny opis w FAZIE 21).

Jeśli PowerShell blokuje skrypty, ustaw dla swojego konta `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`.

## Testy i analiza (dla dewelopera)

Jednorazowo:

```powershell
Install-Module Pester -MinimumVersion 5.0.0 -Scope CurrentUser -SkipPublisherCheck
Install-Module PSScriptAnalyzer -Scope CurrentUser
```

Sprawdzenie (PSScriptAnalyzer + Pester):

```powershell
.\tests\Invoke-Checks.ps1
```

Używane wersje: Pester 6.2.0, PSScriptAnalyzer 1.25.0.
