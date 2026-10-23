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

## Poza zakresem
GUI (wybór komputera w oknie, statusy połączeń → FAZA 4), logika obszarów (FAZY 5–18), instalator i konfiguracja zdalnego komputera przez aplikację (tylko instrukcja).

## Checklista
- [ ] Pytania o komputer zdalny zadane, odpowiedzi w `DECYZJE.md`
- [ ] Moduł `MWP.Remote` z manifestem i testem importu
- [ ] Rejestr komputerów, `localhost` zawsze dostępny, szablon `targets` w `settings.example.json`
- [ ] `New-MwpExecutionContext` (niezmienny kontekst)
- [ ] `New-MwpModuleInstance` i cykl życia instancji
- [ ] `Connect-`/`Disconnect-`/`Test-MwpTarget`, `Invoke-MwpOnTarget` (lokalnie i zdalnie)
- [ ] Decyzja o transporcie i uwierzytelnianiu w `DECYZJE.md`, opis w `ARCHITEKTURA.md`
- [ ] Izolacja błędów i stany połączenia
- [ ] Testy Pester (w tym dwie instancje i utrata połączenia) przechodzą, PSScriptAnalyzer bez uwag
- [ ] Dokumentacja zaktualizowana, commit `FAZA 3: ...`

## Kryteria ukończenia
Funkcja obszaru może wykonać operację dla `localhost` albo komputera zdalnego tym samym interfejsem, a awaria jednego komputera nie wpływa na pozostałe instancje.

## Do weryfikacji na Windows 11
Połączenie z komputerem zdalnym użytkownika (uwierzytelnienie, `Invoke-MwpOnTarget`, odczyt), test na `localhost`, zachowanie przy wyłączonym komputerze zdalnym i przy złych poświadczeniach.

## Wyniki
(wypełnia Claude po zakończeniu fazy)

## Następna faza
FAZA 4 — Szkielet GUI i host modułów. Prompt: `docs/04_PROMPTY/PROMPT_FAZA_4.md`.
