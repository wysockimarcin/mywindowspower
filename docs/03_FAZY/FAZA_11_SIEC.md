# FAZA 11 — Sieć

**Status:** ZAKOŃCZONA (ręczna weryfikacja zmian jako administrator, automatycznego wycofania i komputera zdalnego — lista niżej)

## Cel
Diagnostyka i konfiguracja sieci z możliwością cofnięcia zmian.

## Zależności
FAZY 2, 3 i 4 zakończone.

## Zakres
- Moduł `MWP.Network`: adaptery (`Get-NetAdapter`), konfiguracja IP (`Get-NetIPConfiguration`), profile sieci, włącz/wyłącz adapter (z ostrzeżeniem o utracie połączenia).
- DNS: odczyt i zmiana (`Set-DnsClientServerAddress`) z presetami (DHCP/automatyczny, Cloudflare, Google, Quad9) i własnymi adresami; zapis poprzednich ustawień i cofanie.
- `Clear-DnsClientCache`, odnowienie dzierżawy DHCP.
- Resety: `netsh winsock reset`, `netsh int ip reset` — tylko z potwierdzeniem i informacją o wymaganym restarcie.
- Testy łączności: ping do bramy i do hosta zewnętrznego, rozwiązywanie nazwy DNS (`Resolve-DnsName`), prosty test portu.
- Widok `Network.xaml`, operacje w tle.
- Testy Pester z mockami.
- Obsługa komputera docelowego (D-019): **ryzyko utraty łączności** — zmiana IP, DNS albo adaptera użytego do połączenia zdalnego może odciąć aplikację od komputera. Wymagane: ostrzeżenie z nazwą komputera, dodatkowe potwierdzenie dla adaptera używanego przez połączenie, automatyczne wycofanie zmiany po limicie czasu bez potwierdzenia (do zaprojektowania w tej fazie).

## Poza zakresem
VPN, konfiguracja Wi-Fi (hasła, profile), proxy.

## Checklista
- [x] Lista adapterów i konfiguracji IP — `Get-MwpNetworkStatus` (adaptery także wyłączone, IPv4/IPv6, bramy, DNS statyczne i w użyciu, DHCP z dzierżawą, profil sieci — odczyt), sprawdzone na tym komputerze (6 adapterów)
- [x] Zmiana DNS z presetami i cofaniem — `Set-MwpDnsServer` (DHCP, Cloudflare, Google, Quad9, własne), wpis cofnięcia przywraca tryb sprzed zmiany, automatyczne wycofanie bez zatwierdzenia (D-049); testy z symulatorem
- [x] Flush DNS, odnowienie DHCP — `Clear-MwpDnsCache`, `Update-MwpDhcpLease`
- [x] Resety Winsock i stosu IP z potwierdzeniem — `Reset-MwpNetworkStack` (Destrukcyjna, `RestartRequired`, w oknie wpisanie nazwy komputera)
- [x] Testy łączności — `Test-MwpNetworkConnection` (ping bramy i hosta, DNS, port TCP), sprawdzone na tym komputerze
- [x] Widok `Network.xaml` — test dymny okna w 5.1 (jasny) i 7.6.7 (ciemny)
- [x] Testy Pester, PSScriptAnalyzer — 0 uwag, 1803/1803 w 5.1 i 7.6.7
- [x] Działa dla `localhost` i dla komputera zdalnego (kontekst wykonania `-Context`, błąd połączenia obsłużony na poziomie instancji) — localhost: odczyt, testy, podgląd i odmowy bez administratora, test dymny okna; zdalnie: testy z mockiem transportu WinRM (adapter połączenia, zmiana DNS, zerwanie połączenia przy wyłączeniu adaptera i wycofanie zadaniem); **prawdziwy komputer zdalny i prawdziwe zmiany — DO WERYFIKACJI NA WINDOWS 11**
- [x] Dokumentacja zaktualizowana, commit `FAZA 11: ...`

## Kryteria ukończenia
Zmianę DNS można cofnąć jednym kliknięciem; operacje ryzykowne wymagają potwierdzenia.

## Do weryfikacji na Windows 11
Zmiana DNS i testy łączności na realnym adapterze (administrator). Dodatkowo test na komputerze zdalnym użytkownika (obsługa zdalna, utrata połączenia).

## Wyniki
Zakończona 2026-10-28.

- **Baza przed zmianami** (każda wersja w nowym procesie): 5.1.26100.9711 — 0 uwag, 1698/1698; 7.6.7 (`C:\Program Files\PowerShell\7\pwsh.exe`) — 0 uwag, 1698/1698.
- **Wynik końcowy:** `.\tests\Invoke-Checks.ps1`, każda wersja w nowym procesie: 5.1.26100.9711 — 0 uwag PSScriptAnalyzer, 1803/1803; 7.6.7 — 0 uwag, 1803/1803 (+105: `Network.Tests.ps1` 29, `NetworkView.Tests.ps1` 6, testy XAML, kodowania i eksportu nowych plików i funkcji). Po pierwszym przebiegu 4 uwagi analizatora (zmienna `$sender`, układ klamer w teście) i 1 test do poprawy (`PowerView.Tests.ps1` zakładał, że Sieć nie ma widoku) — poprawione.
- **Decyzje użytkownika (2026-10-28):** automatyczne wycofanie przez jednorazowe zadanie harmonogramu na komputerze docelowym; limit 120 s; lokalnie i zdalnie; resety dozwolone zdalnie z wpisaniem nazwy komputera. **ADR:** D-049.
- **`MWP.Network` 0.11.0:** `Get-MwpNetworkStatus`, `Resolve-MwpNetworkStatus`, `Get-MwpDnsPreset`, `Set-MwpDnsServer`, `Disable-MwpNetAdapter`, `Enable-MwpNetAdapter`, `Approve-MwpNetworkChange`, `Clear-MwpDnsCache`, `Update-MwpDhcpLease`, `Reset-MwpNetworkStack`, `Test-MwpNetworkConnection`, `Resolve-MwpNetworkTest`; prywatne: bloki `Get-MwpNetworkScript` (Status, Change, Approve, FlushDns, RenewDhcp, ResetStack, Test), blok wycofania `Get-MwpNetworkRollbackScript`, `Invoke-MwpNetworkChange`, `Get-MwpNetworkAdapterTarget`, `Test-MwpNetworkAdmin`, `Get-MwpNetworkTargetConfig`, walidacja adresów i nazw. Kontrakt: `Read`, `Change`, `Destructive`, `Undo`, `RemoteTarget`; tryby `Embedded`, `SeparateWindow`. `MWP.Core` 0.11.0 (wersja hosta, bez zmian funkcji).
- **Okno (`MWP.UI`):** `Views/Network.xaml`, `Initialize-`/`Update-MwpNetworkView`, `Invoke-MwpNetworkViewAction`, `Start-MwpUiNetworkRefresh`; logika prezentacji bez WPF: `Get-MwpNetworkRow`, `Get-MwpNetworkActionState`, `Get-MwpNetworkDetail`, `Get-MwpNetworkViewOption`; wpis w `Get-MwpModuleViewCatalog`. Zmiany przez `Invoke-MwpUiInstanceChange` (wyłączenie adaptera połączenia i resety — wpisanie nazwy komputera); baner zmian oczekujących z odliczaniem i „Zatwierdź”; 15 s po terminie widok sam czyta stan ponownie.
- **Sprawdzone na tym komputerze (tylko odczyt i podgląd, 5.1 i 7.6.7, bez administratora):** `Get-MwpNetworkStatus` (ok. 6 s przy pierwszym ładowaniu modułów NetAdapter): 6 adapterów, DNS z DHCP, brama, dzierżawa, profil „Prywatna”; `Test-MwpNetworkConnection` 4/4 (brama, 1.1.1.1, `www.microsoft.com`, port 443); odmowy zmian bez administratora przed podglądem, podgląd flush DNS i zatwierdzenia, odrzucenie adresu multicast i niepoprawnej nazwy.
- **Test dymny okna (automatyczny, kopia aplikacji w katalogu tymczasowym, bez zmian systemu)** w 5.1 (jasny) i 7.6.7 (ciemny): instancja „Sieć — localhost”, 6 adapterów, szczegóły zaznaczonego, baner o braku administratora, przyciski zmian wyłączone, testy łączności 3/3; kod wyjścia 0, brak ostrzeżeń i błędów w logu; zrzuty obejrzane.
- **Znalezione i poprawione w trakcie:** (1) odczyt statycznych DNS w bloku `Change` zwracał tablicę zagnieżdżoną (wpis cofnięcia zapisałby adresy sklejone spacją); (2) `IPAddress.TryParse` przyjmuje skrót `1.1.1` jako 1.1.0.1 — IPv4 tylko w pełnej postaci; (3) kod wyniku `RenewDHCPLease` nie mieści się w `[int]` — `[long]`; (4) wywołania `Disable-`/`Enable-NetAdapter` z `-InputObject` zamiast potoku.
- **Ograniczenia:** prawdziwe zmiany (DNS, adaptery, DHCP, resety, zadanie wycofania jako SYSTEM) nie były wykonywane na komputerze deweloperskim (zasada 5 `CLAUDE.md`, brak administratora) — tylko symulator, odczyt i podgląd; do potwierdzenia na Windows 11: `New-ScheduledTaskPrincipal -UserId 'SYSTEM'` w polskim systemie, `Set-DnsClientServerAddress` z samymi adresami IPv4 nie zmienia DNS IPv6 (po resecie zostaje DHCP), czas odpowiedzi przy wyłączeniu adaptera połączenia (limit 90 s). Konfiguracja statycznego IP i zmiana kategorii profilu sieci — poza zakresem (dług techniczny). Brak widgetu Dashboardu (nie było w zakresie).

## Do weryfikacji na Windows 11 — lista dla użytkownika
1. CLI, bez administratora: `(Get-MwpNetworkStatus).Data.Adapters | Format-Table Name, StatusText, IPv4Text, GatewayText, DnsText, CategoryText` — porównać z `ipconfig /all` i Ustawienia → Sieć.
2. Jako administrator (`.\Start-MyWindowsPower.ps1 -Elevate`) → Sieć → zaznaczyć adapter → preset Cloudflare → „Zmień DNS…”: `ipconfig /all` pokazuje 1.1.1.1; w Harmonogramie zadań jest `\MyWindowsPower\MWP-NetworkRollback-…` (konto SYSTEM); „Zatwierdź” usuwa zadanie; „Cofnij wybraną…” wraca do DHCP.
3. Jak 2, ale bez zatwierdzenia: po 2 minutach DNS wraca sam, zadanie znika, widok po odświeżeniu nie pokazuje zmiany oczekującej.
4. Adapter z ręcznym DNS (np. 192.168.x.1): zmiana na Google i cofnięcie — wraca dokładnie poprzedni adres (także IPv6, jeśli był ustawiony).
5. Wyłączenie nieużywanego adaptera (np. Wi‑Fi) i zatwierdzenie; potem „Włącz adapter…”. Wyłączenie bez zatwierdzenia — adapter włącza się sam po limicie.
6. „Opróżnij pamięć DNS…”, „Odnów dzierżawę DHCP…” (adres w wyniku), testy łączności z portem (np. host `example.com`, port 443).
7. Komputer zdalny (Połącz, konto administratora): stan z oznaczeniem adaptera połączenia; zmiana DNS z zatwierdzeniem; „Wyłącz adapter…” na adapterze połączenia — okno wymaga wpisania nazwy komputera, połączenie zostaje przerwane (błąd tylko w tej instancji), po ok. 2 minutach adapter wraca, „Połącz” działa ponownie.
8. Reset Winsock (najlepiej na maszynie testowej): okno z wpisaniem nazwy komputera, komunikat o restarcie; po restarcie sieć działa.

## Następna faza
FAZA 12 — Aplikacje i winget. Prompt: `docs/04_PROMPTY/PROMPT_FAZA_12.md`.
