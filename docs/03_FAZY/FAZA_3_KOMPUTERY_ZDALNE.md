# FAZA 3 — Komputery docelowe i połączenia zdalne

**Status:** DO ZROBIENIA

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
- [ ] Pytania o komputer zdalny zadane, odpowiedzi w `DECYZJE.md`
- [ ] Moduł `MWP.Remote` z manifestem i testem importu
- [ ] Rejestr komputerów, `localhost` zawsze dostępny, szablon `targets` w `settings.example.json`
- [ ] `New-MwpExecutionContext` (niezmienny kontekst)
- [ ] `New-MwpModuleInstance` i cykl życia instancji
- [ ] `Connect-`/`Disconnect-`/`Test-MwpTarget`, `Invoke-MwpOnTarget` (lokalnie i zdalnie)
- [ ] Decyzja o transporcie i uwierzytelnianiu w `DECYZJE.md`, opis w `ARCHITEKTURA.md`
- [ ] Izolacja błędów i stany połączenia
- [ ] `Test-MwpModulePackage`, `Install-MwpModulePackage`, `Uninstall-MwpModulePackage` (D-031)
- [ ] `Get-MwpModuleDefinition` skanuje `src/Modules` i `src/Modules/Installed` (zgodność wsteczna testów), launcher importuje moduły zainstalowane
- [ ] Rejestr zainstalowanych modułów w `settings.local.json`, zamykanie instancji przy odinstalowaniu, moduły bazowe i wbudowane nieusuwalne
- [ ] Testy paczek (wyjście poza folder, dwa foldery główne, kolizja `Id`, brak zależności, błąd w trakcie instalacji, odinstalowanie modułu bazowego i wbudowanego)
- [ ] Testy Pester (w tym dwie instancje i utrata połączenia) przechodzą, PSScriptAnalyzer bez uwag
- [ ] Dokumentacja zaktualizowana, commit `FAZA 3: ...`

## Kryteria ukończenia
Funkcja obszaru może wykonać operację dla `localhost` albo komputera zdalnego tym samym interfejsem, a awaria jednego komputera nie wpływa na pozostałe instancje. Moduł z poprawnej paczki `.mwpmod` instaluje się do `src/Modules/Installed/`, jest odkrywany i importowany przez launcher i daje się odinstalować bez śladów poza logami i rejestrem cofnięć; błędna paczka jest odrzucana i niczego nie zostawia.

## Do weryfikacji na Windows 11
Połączenie z komputerem zdalnym użytkownika (uwierzytelnienie, `Invoke-MwpOnTarget`, odczyt), test na `localhost`, zachowanie przy wyłączonym komputerze zdalnym i przy złych poświadczeniach. Instalacja i odinstalowanie przykładowej paczki `.mwpmod` na prawdziwym dysku (poza `TestDrive`) i import modułu przez launcher.

## Wyniki
(wypełnia Claude po zakończeniu fazy)

## Następna faza
FAZA 4 — Szkielet GUI i host modułów. Prompt: `docs/04_PROMPTY/PROMPT_FAZA_4.md`.
