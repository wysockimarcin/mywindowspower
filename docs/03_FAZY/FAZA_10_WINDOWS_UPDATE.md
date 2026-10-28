# FAZA 10 — Windows Update

**Status:** ZAKOŃCZONA (ręczna weryfikacja zmian jako administrator, instalacji i komputera zdalnego — lista niżej)

## Cel
Kontrola nad aktualizacjami Windows bez zewnętrznych modułów.

## Zależności
FAZY 2, 3 i 4 zakończone.

## Zakres
- Moduł `MWP.Update` oparty o wbudowane API COM (`Microsoft.Update.Session`): wyszukiwanie oczekujących aktualizacji, historia aktualizacji, informacja o wymaganym restarcie.
- Stan usług `wuauserv`, `bits`, `cryptsvc`, `usosvc`.
- Pauza aktualizacji (ustawienia rejestru/polityki) z cofaniem; sprawdź, które klucze są obsługiwane w Windows 11 przed użyciem.
- Reset komponentów Windows Update (zatrzymanie usług, zmiana nazw `SoftwareDistribution` i `catroot2`, restart usług) — wyłącznie z potwierdzeniem i podglądem kroków.
- Instalacja aktualizacji: tylko jeśli da się to zrobić bezpiecznie przez COM, z potwierdzeniem; w przeciwnym razie odeślij do Ustawień Windows i zapisz w `DECYZJE.md`.
- Widok `Update.xaml`, operacje w tle z postępem.
- Testy Pester z mockami COM.
- Obsługa komputera docelowego (D-019): **ograniczenie do zbadania** — metody pobierania i instalacji Windows Update Agent (COM) bywają niedostępne w sesji zdalnej. Odczyt stanu, historia, stan usług i reset komponentów zdalnie; instalację zdalną dodaj tylko, jeśli da się ją wykonać bez osłabiania zabezpieczeń (np. przez zadanie harmonogramu), inaczej odrocz z wpisem.

## Poza zakresem
Ukrywanie sterowników, zarządzanie WSUS, moduł `PSWindowsUpdate` (zewnętrzna zależność).

## Checklista
- [x] Wyszukiwanie oczekujących aktualizacji (COM) — `Find-MwpUpdate` (`IUpdateSearcher.Search`, stałe kryteria, `-Type All|Software|Driver`, `-AsOperation`), `Resolve-MwpUpdateSearch`; prawdziwe wyszukiwanie na komputerze deweloperskim: 6 aktualizacji (57 s w 5.1)
- [x] Historia aktualizacji — `Get-MwpUpdateHistory` (`QueryHistory`, `-First`), `Resolve-MwpUpdateHistory` (operacja, wynik, HRESULT z opisem, KB); na komputerze deweloperskim: 200 z 1218 wpisów (ok. 0,2 s)
- [x] Stan usług Windows Update — `Get-MwpUpdateStatus` (usługi `wuauserv`, `bits`, `cryptsvc`, `usosvc` z typem uruchomienia, restart z WUA i kluczy rejestru, ostatnie wyszukiwanie i instalacja, pauza, zasady grupy, kopie z resetu)
- [x] Pauza aktualizacji z cofaniem — `Suspend-MwpUpdate -Weeks 1–5`, `Resume-MwpUpdate`, `Restore-MwpUpdatePause` (wpis cofnięcia); klucze sprawdzone przed użyciem: `HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings` istnieje w Windows 11 26H2 (wartości jak przycisk „Wstrzymaj” w Ustawieniach, D-048)
- [x] Reset komponentów z podglądem kroków — `Reset-MwpUpdateComponent` (Destrukcyjna, `ConfirmImpact High`), `Get-MwpUpdateResetStep`, `Restore-MwpUpdateComponent` (cofnięcie); stare foldery zachowane
- [x] Decyzja o instalacji aktualizacji zapisana w `DECYZJE.md` — D-048: lokalnie przez COM z potwierdzeniem (`Install-MwpUpdate`), zdalnie odroczona
- [x] Widok `Update.xaml` — `src/UI/Views/Update.xaml`, wyszukiwanie i historia w tle (pasek stanu), instalacja w tle z postępem i „Anuluj”, pauza, reset z podglądem i wpisaniem nazwy komputera, cofnięcia
- [x] Testy Pester, PSScriptAnalyzer — `tests/Modules/MWP.Update/Update.Tests.ps1` (37, symulator COM), `tests/UI/UpdateView.Tests.ps1` (7); `.\tests\Invoke-Checks.ps1` w 5.1 i 7.6.7 (wyniki niżej)
- [x] Działa dla `localhost` i dla komputera zdalnego (kontekst wykonania `-Context`, błąd połączenia obsłużony na poziomie instancji) — localhost: odczyt, wyszukiwanie, historia, podgląd i test dymny okna; zdalnie: testy z mockiem transportu WinRM (odczyt, pauza i reset zdalnie z nazwą komputera, instalacja odrzucona, 0x80070005 opisany, utrata połączenia); **prawdziwy komputer zdalny — DO WERYFIKACJI NA WINDOWS 11**
- [x] Dokumentacja zaktualizowana, commit `FAZA 10: ...`

## Kryteria ukończenia
Wszystko działa bez dodatkowych modułów; reset jest odwracalny (zachowane stare foldery).

Spełnione: moduł używa wyłącznie wbudowanego COM Windows Update Agent, rejestru i `ServiceController` (brak `PSWindowsUpdate` i innych zależności); reset zmienia nazwy folderów na `*.mwp-RRRRMMDD-GGmmss` bez usuwania, a cofnięcie (`Restore-MwpUpdateComponent`, wpis w rejestrze cofnięć) przywraca je pod dawną nazwą — test „zatrzymuje usługi, zmienia nazwy folderów (stare zostają)… cofnięcie przywraca foldery” na `TestDrive`, także wycofanie przy błędzie zmiany nazwy i odrzucenie dowiązania.

## Do weryfikacji na Windows 11
Wyszukiwanie przez COM, pauza, reset komponentów (administrator). Dodatkowo test na komputerze zdalnym użytkownika (obsługa zdalna, utrata połączenia).

## Wyniki
Zakończona 2026-10-28.

- **Baza przed zmianami** (każda wersja w nowym procesie): 5.1.26100.9711 — 0 uwag, 1572/1572; 7.6.7 (`C:\Program Files\PowerShell\7\pwsh.exe`) — 0 uwag, 1572/1572.
- **Wynik końcowy:** `.\tests\Invoke-Checks.ps1`, każda wersja w nowym procesie: 5.1.26100.9711 — 0 uwag PSScriptAnalyzer, 1698/1698; 7.6.7 (`C:\Program Files\PowerShell\7\pwsh.exe`) — 0 uwag, 1698/1698 (baza 1572/1572; +126: `Update.Tests.ps1` 37, `UpdateView.Tests.ps1` 7, testy XAML, kodowania i eksportu nowych plików i funkcji). Po pierwszym przebiegu 1 uwaga analizatora (nazwa funkcji pomocniczej testu `New-FakeUpdate` → `Get-FakeUpdate`), potem czysto.
- **Decyzje użytkownika (2026-10-28):** instalacja lokalnie przez COM (z potwierdzeniem, bez automatycznego restartu); instalacja zdalna odroczona z wpisem; pauza jak Ustawienia Windows 11, 1–5 tygodni. **ADR:** D-048.
- **`MWP.Update` 0.10.0:** `Get-MwpUpdateStatus`, `Resolve-MwpUpdateStatus`, `Find-MwpUpdate`, `Resolve-MwpUpdateSearch`, `Get-MwpUpdateHistory`, `Resolve-MwpUpdateHistory`, `Suspend-MwpUpdate`, `Resume-MwpUpdate`, `Restore-MwpUpdatePause`, `Reset-MwpUpdateComponent`, `Get-MwpUpdateResetStep`, `Restore-MwpUpdateComponent`, `Install-MwpUpdate`, `Open-MwpUpdatePage`, `Format-MwpUpdateSize`; prywatne: `Get-MwpUpdateScript` (bloki `Status`, `Search`, `History`, `PauseWrite`, `Install`, `Reset`), `Get-MwpUpdateTargetConfig`, `Get-MwpUpdateSearchFilter`, `Test-MwpUpdateAdmin`, `Test-MwpUpdatePauseAccess`, `Write-MwpUpdatePause`, `Invoke-MwpUpdatePauseChange`, `Resolve-MwpUpdatePause`, `Invoke-MwpUpdateReset`, konwersje dat i tekstów; kontrakt: Read, Change, Destructive, Undo, RemoteTarget; Embedded, SeparateWindow. `MWP.Core` 0.10.0 (wersja hosta, bez zmian funkcji).
- **Okno (`MWP.UI`):** `Views/Update.xaml`, `Initialize-`/`Update-MwpUpdateView`, `Invoke-MwpUpdateViewAction`, `Start-MwpUiUpdateRefresh` (stan, wyszukiwanie, historia), `Start-MwpUiUpdateInstall`; logika prezentacji bez WPF: `Get-MwpUpdateRow`, `Get-MwpUpdateActionState`, `Get-MwpUpdateDetail`, `Get-MwpUpdateViewOption`, `Get-MwpUiUpdateScript`; wpis w `Get-MwpModuleViewCatalog`; `Invoke-MwpUiInstanceChange -ConfirmText` (opcjonalny, zgodnie wstecz).
- **Sprawdzone na tym komputerze (tylko odczyt i podgląd, 5.1 i 7.6.7, bez administratora):** `Get-MwpUpdateStatus` (ok. 1,9 s): 4 usługi z typem uruchomienia, „Restart nie jest wymagany”, ostatnie wyszukiwanie 2026-10-28 07:37 i instalacja 2026-10-24 17:54, brak pauzy i zasad; `Get-MwpUpdateHistory` — wpisy zgodne z historią w Ustawieniach (KB, wynik); `Find-MwpUpdate` (COM, 57 s): 6 oczekujących (.NET, Defender, PowerShell, 2 sterowniki — sterowniki oznaczone jako wymagające instalacji w Ustawieniach); `Suspend-MwpUpdate -WhatIf`, `Reset-MwpUpdateComponent -WhatIf`, `Install-MwpUpdate -WhatIf` — odmowa „wymaga uprawnień administratora” przed podglądem; `Get-MwpUpdateResetStep` — 5 kroków.
- **Test dymny okna (automatyczny, kopia aplikacji w katalogu tymczasowym, bez zmian systemu)** w 5.1 (motyw jasny, z wyszukiwaniem) i 7.6.7 (motyw ciemny): instancja „Windows Update — localhost”, stan i 4 usługi, baner o braku administratora, przyciski pauzy, resetu i instalacji wyłączone, historia 200 wpisów (75 niepowodzeń), wyszukiwanie 6 aktualizacji, zaznaczenie — szczegóły i „Instalacja wymaga uprawnień administratora”; kod wyjścia 0, brak błędów i ostrzeżeń w logu; zrzuty obejrzane.
- **Znalezione i poprawione w trakcie:** (1) `ConvertFrom-Json` w PowerShell 7 zamienia daty ISO 8601 z żądania na `[datetime]`, więc zapis pauzy w 7.x dawał tekst w formacie kultury — blok `PauseWrite` i odczyt na hoście wracają do `yyyy-MM-ddTHH:mm:ssZ` (`ConvertTo-MwpUpdatePauseText`); (2) `New-MwpResult -RestartRequired $false` ustawiało przełącznik — `-RestartRequired:$x`; (3) w Pester 6 domyślny mock przekazujący `New-Object` w zakresie pliku daje nieskończoną rekurencję (nazwa z modułem nie omija mocka z zakresu pliku) — mocki tylko w zakresach modułów; (4) PSScriptAnalyzer: `Set-ItemProperty -Type` (niezgodny profil), nazwy w liczbie mnogiej (`Open-MwpUpdatePage`, `Get-MwpUpdateSearchFilter`), `ShouldProcess` w funkcjach publicznych zamiast przekazywania `$PSCmdlet`.
- **Ograniczenia:** prawdziwe zmiany (pauza, reset, instalacja) nie były wykonywane na komputerze deweloperskim (zasada 5 `CLAUDE.md`, brak administratora) — tylko symulator, odczyt i podgląd; instalacja zdalna odroczona (D-048); anulowanie instalacji działa między aktualizacjami; pauza zastępuje trwającą (bez sumowania z poprzednią); brak widgetu Dashboardu (nie było w zakresie).

## Do weryfikacji na Windows 11 — lista dla użytkownika
1. CLI, bez administratora: `(Get-MwpUpdateStatus).Data | Format-List RebootText, LastSearchText, LastInstallText, PauseText` i `(Get-MwpUpdateHistory -First 20).Data.Entries | Format-Table DateText, ResultText, KBText, Title` — porównać z Ustawienia → Windows Update → Historia aktualizacji.
2. `(Find-MwpUpdate).Data.Updates | Format-Table Title, KBText, SizeText, RebootText, IsInstallable` — porównać z listą w Ustawieniach po „Sprawdź aktualizacje”.
3. Jako administrator (`.\Start-MyWindowsPower.ps1 -Elevate`) → Windows Update → „Wstrzymaj…” (1 tydzień): Ustawienia → Windows Update pokazują „Aktualizacje wstrzymane do …” z tą samą datą; „Wznów…” — Ustawienia pokazują wznowione; „Cofnij wybraną…” przywraca poprzedni stan. Sprawdzić też 5 tygodni.
4. Jako administrator: „Resetuj składniki…” → okno pokazuje 5 kroków i wymaga wpisania nazwy komputera → po resecie w `C:\Windows` jest `SoftwareDistribution.mwp-*`, w `C:\Windows\System32` — `catroot2.mwp-*`; usługi działają jak przed resetem; „Wyszukaj aktualizacje” działa (Windows odtwarza foldery); „Cofnij wybraną…” przywraca stare foldery (bieżące → `*.mwp-replaced-*`). Stare kopie usuwa się ręcznie, gdy niepotrzebne.
5. Jako administrator: zaznaczyć małą aktualizację (np. analiza zabezpieczeń Defendera) → „Zainstaluj zaznaczone…” → okno z listą → postęp i wynik w „Wyniku ostatniej instalacji”, wpis w historii (aplikacja `MyWindowsPower`); aktualizacja wymagająca restartu — komunikat bez automatycznego restartu; „Anuluj” w trakcie kilku aktualizacji kończy po bieżącej.
6. Sterowniki i aktualizacje z licencją: oznaczone „zainstaluj w Ustawieniach”, „Otwórz Ustawienia Windows Update” otwiera właściwą stronę.
7. Komputer zdalny (Połącz, konto administratora): stan, wyszukiwanie (jeśli WUA odmówi — komunikat z 0x80070005), historia, pauza i reset z nazwą komputera zdalnego w potwierdzeniu; „Zainstaluj zaznaczone…” wyłączone z wyjaśnieniem; odłączenie sieci w trakcie resetu — błąd tylko w tej instancji.
8. Zasady grupy: jeśli na którymś komputerze są ustawione zasady Windows Update dotyczące pauzy — baner z ostrzeżeniem.

## Następna faza
FAZA 11 — Sieć. Prompt: `docs/04_PROMPTY/PROMPT_FAZA_11.md`.
