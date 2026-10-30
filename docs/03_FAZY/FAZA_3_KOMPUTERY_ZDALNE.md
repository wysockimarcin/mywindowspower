# FAZA 3 — Komputery docelowe i połączenia zdalne

**Status:** ZAKOŃCZONA (2026-10-23; połączenie z prawdziwym komputerem zdalnym — do weryfikacji ręcznej na Windows 11)

## Cel
Aplikacja zarządza komputerem lokalnym (`localhost`) i komputerami zdalnymi (D-019). Ta faza dostarcza model komputera docelowego, jawny kontekst wykonania, warstwę połączeń i model instancji modułu. Korzystają z nich wszystkie późniejsze moduły. Nie istnieje globalny „bieżący komputer": każda instancja modułu ma własny kontekst.

## Zależności
FAZY 1 i 2 zakończone.

## Zakres
- Nowy moduł `MWP.Remote` (manifest, `Public/`, `Private/`, testy w `tests/Modules/MWP.Remote/`); dopisanie go do listy modułów w `tests/Modules.Tests.ps1`.
- **Pytania do użytkownika na początku fazy** (nie zgaduj): jaki system działa na komputerze zdalnym, czy ma włączony WinRM, czy komputery są w domenie czy w grupie roboczej (TrustedHosts, HTTPS), jakim kontem ma się odbywać logowanie. Odpowiedzi zapisz w `DECYZJE.md`.
- Rejestr komputerów docelowych w `config/settings.local.json` (poza repozytorium): `Get-MwpTarget`, `Add-MwpTarget`, `Remove-MwpTarget`. `localhost` jest zawsze obecny i działa bez zdalnego wywołania. Nazwy prawdziwych komputerów nie trafiają do repozytorium; szablon `config/settings.example.json` dostaje sekcję `targets` z `localhost` i nazwą zastępczą, z podniesieniem `schemaVersion` i migracją (D-015).
- Obiekt kontekstu wykonania `New-MwpExecutionContext`: identyfikator instancji, komputer docelowy, tryb Local/Remote, tożsamość lub poświadczenia, stan połączenia, parametry modułu, polityka limitów czasu i błędów. W obrębie instancji kontekst jest niezmienny (zmiana komputera = nowa instancja albo nowy kontekst).
- Model instancji modułu: **definicja modułu ≠ instancja**. `New-MwpModuleInstance` (z kontraktem z FAZY 2): własny identyfikator, własny kontekst i stan, cykl życia (utworzenie, inicjalizacja, zamknięcie, zwolnienie zasobów); zamknięcie jednej instancji nie wpływa na inne; stan nie jest współdzielony przypadkowo.
- Warstwa połączeń: `Connect-MwpTarget`, `Disconnect-MwpTarget`, `Test-MwpTarget` (rozdziela: dostępność sieciowa, uwierzytelnienie, autoryzacja), `Invoke-MwpOnTarget -Context -ScriptBlock -ArgumentList` — wykonanie lokalne bezpośrednio albo zdalne przez sesję; zwraca standardowy obiekt wyniku (`New-MwpResult`). Rozdziel: reprezentację komputera, nawiązywanie połączenia, wykonywanie operacji i prezentację stanu w UI.
- Decyzja o transporcie (ADR, wpis w `DECYZJE.md`): propozycja do zatwierdzenia — PowerShell Remoting (WinRM) dla operacji, sesje CIM dla odczytu; kontrakt adaptera pozwala dobrać inny transport do wybranej funkcji. Po wyborze zapisz konsekwencje (np. wymagana konfiguracja po stronie zdalnego komputera) w `ARCHITEKTURA.md`.
- Uwierzytelnianie: bez haseł i sekretów w jawnym tekście, w repozytorium i w logach. Opcje do wyboru w `DECYZJE.md`: bieżący użytkownik (Kerberos/NTLM), `Get-Credential` na życzenie, poświadczenia zapisane lokalnie z ochroną DPAPI (powiązane z kontem i komputerem). Nie osłabiaj zabezpieczeń Windows dla wygody (np. nie ustawiaj `TrustedHosts` na `*`).
- Izolacja błędów: niedostępność jednego komputera, limit czasu albo brak uprawnień kończy się stanem połączenia w danym kontekście (`Connected`, `Connecting`, `Disconnected`, `Unauthorized`, `Error`) i nie zatrzymuje innych instancji; limit równoległych zadań, anulowanie, zwalnianie sesji przy zamknięciu instancji.
- Operacje zmieniające system dla komputera zdalnego respektują wzorzec z FAZY 2: `-WhatIf`, log z nazwą komputera, wpis cofnięcia powiązany z komputerem, klasy operacji (Odczyt / Zmiana / Destrukcyjna) z potwierdzeniem zawierającym nazwę komputera docelowego.
- Testy Pester z mockami (bez realnych połączeń): kontekst, rejestr komputerów, instancje (dwie instancje tego samego modułu dla dwóch komputerów nie współdzielą stanu), utrata połączenia z jednym komputerem, anulowanie i zwalnianie zasobów.
- **Paczki modułów (D-031, w `MWP.Core`; opis w `ARCHITEKTURA.md`, sekcja „Paczki modułów"):**
  - `Test-MwpModulePackage` (Odczyt): walidacja paczki `.mwpmod` rozpakowanej do katalogu tymczasowego — dokładnie jeden folder główny `MWP.<Obszar>`, żadna ścieżka nie wychodzi poza folder docelowy, manifest i pola kontraktu, `MinimumHostVersion`, zależności, kolizja `Id` i nazwy folderu z modułem wbudowanym lub zainstalowanym; zwraca też SHA-256 paczki, nazwę, wersję i `RequiredPermissions` (dane do okna potwierdzenia).
  - `Install-MwpModulePackage` (Zmiana: `-WhatIf`, log): po walidacji atomowe przeniesienie do `src/Modules/Installed/` i wpis w rejestrze; błąd na dowolnym etapie nie zostawia niczego w połowie (katalog tymczasowy usunięty, brak folderu i wpisu); paczka z `Id` już zainstalowanego modułu jest odrzucana.
  - `Uninstall-MwpModulePackage` (Destrukcyjna: `ConfirmImpact = 'High'`, potwierdzenie z nazwą modułu): zamknięcie instancji modułu, usunięcie folderu, sekcji konfiguracji modułu i wpisu w rejestrze; logi i rejestr cofnięć zostają; moduły bazowe (`MWP.Core`, `MWP.Remote`) i wbudowane są nieusuwalne (wynik z błędem). Usuwanie widgetów z Dashboardu → FAZA 5.
  - `Get-MwpModuleDefinition` skanuje `src/Modules` i `src/Modules/Installed` (parametr z listą katalogów zamiast jednego `-ModulesRoot`; zachowaj zgodność wsteczną istniejących testów); definicja ma informację, czy moduł jest wbudowany, czy zainstalowany.
  - Launcher importuje poprawne moduły zainstalowane (po wbudowanych); `src/Modules/Installed/` jest w `.gitignore`.
  - Rejestr zainstalowanych modułów (`Id`, wersja, data, SHA-256) w `config/settings.local.json` — klucz w szablonie `settings.example.json` (pusta lista) razem z migracją `schemaVersion` tej fazy.
  - Tylko lokalnie: na komputerach zdalnych nic się nie instaluje.
  - Testy Pester (paczki tworzone w `TestDrive`): ZIP z wyjściem poza folder (`..\`), dwa foldery główne, kolizja `Id`, brak zależności, błąd w trakcie instalacji niczego nie zostawia, odinstalowanie modułu bazowego i wbudowanego odrzucone, `-WhatIf` niczego nie zmienia, odinstalowanie zamyka instancje i usuwa wpis w rejestrze.

## Poza zakresem
GUI (wybór komputera w oknie, statusy połączeń, widok „Moduły" → FAZA 4), logika obszarów (FAZY 5–18), instalator i konfiguracja zdalnego komputera przez aplikację (tylko instrukcja; dotyczy konfiguracji komputera zdalnego, nie instalacji modułów — ta jest w zakresie, D-031), aktualizacja modułów przez host (poza projektem, D-031), usuwanie widgetów odinstalowanego modułu (FAZA 5).

## Checklista
- [x] Pytania o komputer zdalny zadane, odpowiedzi w `DECYZJE.md` — D-033 (Windows 11, WinRM HTTP 5985, grupa robocza, Get-Credential na żądanie)
- [x] Moduł `MWP.Remote` z manifestem i testem importu — `src/Modules/MWP.Remote/`, `tests/Modules.Tests.ps1` (lista oczekiwanych modułów)
- [x] Rejestr komputerów, `localhost` zawsze dostępny, szablon `targets` w `settings.example.json` — `Get-`/`Add-`/`Remove-MwpTarget`, `schemaVersion` 2 z migracją; `Targets.Tests.ps1`, `Settings.Tests.ps1`
- [x] `New-MwpExecutionContext` (niezmienny kontekst) — `ExecutionContext.Tests.ps1`
- [x] `New-MwpModuleInstance` i cykl życia instancji — `Initialize-`/`Close-`/`Get-MwpModuleInstance`; `Instances.Tests.ps1`
- [x] `Connect-`/`Disconnect-`/`Test-MwpTarget`, `Invoke-MwpOnTarget` (lokalnie i zdalnie) — zdalnie z mockami adaptera transportu; `Connection.Tests.ps1`; prawdziwe połączenie: DO WERYFIKACJI NA WINDOWS
- [x] Decyzja o transporcie i uwierzytelnianiu w `DECYZJE.md`, opis w `ARCHITEKTURA.md` — D-034, sekcje „Kontekst wykonania…", „Komputery docelowe i połączenia zdalne", instrukcja konfiguracji
- [x] Izolacja błędów i stany połączenia — D-036; `Connection.Tests.ps1` (utrata połączenia z jednym komputerem), `Instances.Tests.ps1`, `Operations.Tests.ps1` (limit równoległości, limit czasu, anulowanie)
- [x] `Test-MwpModulePackage`, `Install-MwpModulePackage`, `Uninstall-MwpModulePackage` (D-031) — oraz `Get-MwpInstalledModule`; `ModulePackage.Tests.ps1`
- [x] `Get-MwpModuleDefinition` skanuje `src/Modules` i `src/Modules/Installed` (zgodność wsteczna testów), launcher importuje moduły zainstalowane — `ModuleContract.Tests.ps1`, `Launcher.Tests.ps1` (kopia aplikacji na TestDrive)
- [x] Rejestr zainstalowanych modułów w `settings.local.json`, zamykanie instancji przy odinstalowaniu, moduły bazowe i wbudowane nieusuwalne — `ModulePackage.Tests.ps1`
- [x] Testy paczek (wyjście poza folder, dwa foldery główne, kolizja `Id`, brak zależności, błąd w trakcie instalacji, odinstalowanie modułu bazowego i wbudowanego) — `ModulePackage.Tests.ps1`
- [x] Testy Pester (w tym dwie instancje i utrata połączenia) przechodzą, PSScriptAnalyzer bez uwag — 5.1.26100.9711 i 7.6.7: 0 uwag, 660/660
- [x] Dokumentacja zaktualizowana, commit `FAZA 3: ...`

## Kryteria ukończenia
Funkcja obszaru może wykonać operację dla `localhost` albo komputera zdalnego tym samym interfejsem, a awaria jednego komputera nie wpływa na pozostałe instancje. Moduł z poprawnej paczki `.mwpmod` instaluje się do `src/Modules/Installed/`, jest odkrywany i importowany przez launcher i daje się odinstalować bez śladów poza logami i rejestrem cofnięć; błędna paczka jest odrzucana i niczego nie zostawia.

## Do weryfikacji na Windows 11
Połączenie z komputerem zdalnym użytkownika (uwierzytelnienie, `Invoke-MwpOnTarget`, odczyt), test na `localhost`, zachowanie przy wyłączonym komputerze zdalnym i przy złych poświadczeniach. Instalacja i odinstalowanie przykładowej paczki `.mwpmod` na prawdziwym dysku (poza `TestDrive`) i import modułu przez launcher.

## Wyniki
Zakończona 2026-10-23.

- **Baza przed zmianami:** `.\tests\Invoke-Checks.ps1` w nowych procesach — 5.1.26100.9711: 0 uwag, 420/420; 7.6.7 (`C:\Program Files\PowerShell\7\pwsh.exe`): 0 uwag, 420/420.
- **Wynik końcowy:** 5.1.26100.9711 — 0 uwag, 660/660; 7.6.7 — 0 uwag, 660/660 (+240 testów).
- **`MWP.Remote` 0.3.0 (moduł bazowy):** rejestr komputerów (`Get-`/`Add-`/`Remove-MwpTarget`), kontekst wykonania (`New-MwpExecutionContext`, pola tylko do odczytu, obiekt połączenia ze stanem), połączenia (`Connect-`/`Disconnect-`/`Test-MwpTarget`), wykonanie (`Invoke-MwpOnTarget`, `Get-MwpCimSessionParameter`), operacje asynchroniczne w puli runspace'ów (`Start-`/`Wait-`/`Stop-MwpOperation`), instancje modułów (`New-`/`Initialize-`/`Close-`/`Get-MwpModuleInstance`), adapter transportu WinRM/CIM w funkcjach prywatnych.
- **`MWP.Core` 0.3.0:** paczki modułów (`Test-`/`Install-`/`Uninstall-MwpModulePackage`, `Get-MwpInstalledModule`), odkrywanie w dwóch katalogach (`Source`, `IsBase`), `-Context` w `New-MwpRestorePoint` (punkt na komputerze zdalnym) i `Invoke-MwpUndo`, wspólny zapis ustawień lokalnych (`Write-MwpLocalSetting`), szablon ustawień w schemacie 2 z migracją zachowującą `dataPath`.
- **Launcher:** importuje moduły z `src/Modules/Installed` po wbudowanych.
- **Decyzje:** D-033 (komputer zdalny), D-034 (transport i uwierzytelnianie), D-035 (kontekst i instancje; rozstrzyga dług D-024 i przejściowe `-ComputerName`), D-036 (wykonanie zdalne, izolacja, pula), D-037 (paczki, schemat 2).
- **Test dymny (tylko odczyt) na localhost w 5.1:** `Invoke-MwpOnTarget` i `Start-`/`Wait-MwpOperation` zwróciły wersję PowerShella i nazwę systemu.
- **Ograniczenia:** połączenie z prawdziwym komputerem zdalnym nie było wykonywane w tej rozmowie (wymaga poświadczeń i wpisu `TrustedHosts`, które wykonuje użytkownik); ścieżki zdalne są pokryte testami z mockami adaptera transportu.

### Korekta D-054 — nazwa komputera i adres połączenia rozdzielone (2026-10-30)
Korekta po FAZIE 12 (status FAZY 3 i FAZY 12 bez zmian; dotyczy rejestru komputerów i połączeń z tej fazy). Zgłoszenie użytkownika: kolumna „Nazwa” w informacjach o komputerze zdalnym zawierała adres IP. Rozwiązanie (D-054): `name` = faktyczna nazwa komputera i identyfikator, opcjonalne `address` = adres połączenia (mapowanie tylko w `settings.local.json`), weryfikacja nazwy po połączeniu (`NameMismatch` blokuje cały kontekst), adres LAN `localhost` tylko informacyjnie, zmiana nazwy z przeniesieniem hasła, widgetów i wpisów cofnięcia, wspólna etykieta komputera w oknie.

- **Decyzje użytkownika:** z promptu korekty (pkt 0) oraz odpowiedzi 1–5 zgodnie z rekomendacjami (blokada całego kontekstu; pierwszy człon nazwy bez wielkości liter, bez wyłączania weryfikacji; przeniesienie interaktywne z banerem; przepisanie wpisów cofnięcia; HTTPS po nazwie).
- **Weryfikacja automatyczna:** `tests/Modules/MWP.Remote/TargetAddress.Tests.ps1` (model, adres w adapterach, `NameMismatch` w sesji, operacji w tle i CIM, diagnostyka, reguła adresu LAN, „ten komputer”, zmiana nazwy z symulatorem magazynu), `tests/UI/TargetUi.Tests.ps1`, test statyczny etykiet w `tests/UI/Xaml.Tests.ps1`, test architektoniczny adresu LAN w `tests/Modules/MWP.Core/Architecture.Tests.ps1`.

**Do weryfikacji na Windows 11 — korekta D-054 (prawdziwa aplikacja; hasła wpisujesz tylko w oknie aplikacji, nigdy w rozmowie; prawdziwych nazw i adresów nie zapisuj w dokumentacji):**
1. Ustawienia → „Komputery docelowe”: siatka pokazuje się od razu; wiersz `localhost` ma w kolumnie „Nazwa” nazwę tego komputera, a w „Adres IP” po chwili adres w sieci LAN (porównaj z `ipconfig`: karta z bramą domyślną); podpowiedź (najechanie na komórkę) pokazuje kartę i inne adresy; okno się nie zamraża; „Odśwież” odczytuje adres ponownie.
2. Komputer zapisany pod adresem IP: widoczny baner „Komputer zapisany pod adresem IP — ustaw nazwę”; „Ustaw nazwę…” → edytor → „Odczytaj nazwę z komputera” (okno poświadczeń, jeśli hasło nie jest w pamięci) → w polu „Nazwa” nazwa komputera, a w „Adres” dotychczasowy adres IP → „Dalej…” → podsumowanie (widgety, wpisy cofnięcia, zapisane hasło) → zapis. W siatce: nazwa w „Nazwa”, adres w „Adres IP”, baner znika.
3. Po zmianie nazwy: wpis w Menedżerze poświadczeń Windows ma nazwę `MWP:<nowa nazwa>` (stary znika), widgety tego komputera działają dalej (odtworzone pod nową nazwą), a instancja łączy się bez ponownego pytania o hasło (jeśli było zapamiętane albo w pamięci).
4. Instancja „Usługi Windows” (i jednego innego modułu) dla tego komputera: tytuł „Usługi Windows — <NAZWA>”, podtytuł „komputer <NAZWA> (<adres>, zdalnie, WinRM)”, wiersz stanu „Komputer <NAZWA> · …”; dla `localhost` — nazwa hosta i „(ten komputer, lokalnie)”. To samo na kartach komputerów Pulpitu (adres w opisie połączenia), w tytułach widgetów i na liście zadań w tle.
5. Diagnostyka połączenia (Ustawienia): adres połączenia, nazwa zgłoszona przez komputer („zgodna”), adresy wykryte i wartość do `TrustedHosts` (przy łączeniu po IP — adres IP, tylko NTLM).
6. Symulacja niezgodności: tymczasowo wpisz w „Adres” adres innego komputera z WinRM (albo nazwę innego komputera) → „Połącz”: stan „Inny komputer pod adresem”, komunikat z obiema nazwami; odczyty i zmiany zablokowane (także widgety); przywróć adres.
7. Dodanie komputera zdalnego z nazwą albo adresem tego komputera: ostrzeżenie „To ten komputer … użyj localhost” (bez blokady); usuń ten wpis.
8. HTTPS z wpisanym adresem: ostrzeżenie w edytorze, że adres jest pomijany (połączenie po nazwie).
9. Stary wpis bez `address` (inny komputer zapisany po nazwie): łączy się jak wcześniej.

## Następna faza
FAZA 4 — Szkielet GUI i host modułów. Prompt: `docs/04_PROMPTY/PROMPT_FAZA_4.md`.
