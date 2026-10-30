# SŁOWNIK — mywindowspower

| Termin | Znaczenie w projekcie |
|---|---|
| FAZA | Samodzielna część projektu realizowana w jednej, nowej rozmowie Claude Code |
| Pamięć projektu | Pliki w `docs/` niosące ciągłość między rozmowami |
| STAN_PROJEKTU | Plik z aktualnym postępem; źródło prawdy |
| Dry-run / podgląd | Pokazanie zmian bez ich wykonania (`-WhatIf`) |
| Punkt przywracania | Punkt przywracania systemu Windows tworzony przed ryzykowną zmianą |
| Rejestr cofnięć | Zapis stanu przed zmianą umożliwiający jej cofnięcie |
| Moduł MWP.* | Moduł PowerShell z logiką jednego obszaru |
| Paczka modułu (`.mwpmod`) | Archiwum ZIP z jednym folderem głównym `MWP.<Obszar>` (manifest, `.psm1`, `Public/`, `Private/`), z którego host instaluje moduł (D-031) |
| Moduł wbudowany | Moduł w repozytorium, w `src/Modules/`; nie da się go odinstalować z hosta |
| Moduł zainstalowany | Moduł zainstalowany z paczki `.mwpmod` do `<katalog danych>\modules\` (poza repozytorium; w FAZIE 3 — `src/Modules/Installed/`, D-038); można go odinstalować, co usuwa wszystko, co go dotyczy, poza logami i rejestrem cofnięć (D-031) |
| Katalog danych | Folder z danymi aplikacji: `logs`, `undo`, `modules`; domyślnie `data` obok aplikacji, zmieniany kluczem `dataPath` albo „Przenieś dane” (D-032, D-038) |
| Widok-zaślepka | Widok obszaru lub instancji bez funkcji obszaru (do fazy obszaru); pokazuje kontekst wykonania i stan połączenia (D-039) |
| Zadanie w tle (GUI) | Blok wykonywany w puli runspace'ów okna z `MWP.Core`/`MWP.Remote`; postęp przez tabelę `Progress`, wynik odbierany zegarem okna (`Start-`/`Update-`/`Stop-MwpUiTask`, D-039) |
| Widok | Plik XAML z interfejsem jednego obszaru |
| STA | Single-Threaded Apartment — tryb wątku wymagany przez WPF |
| Runspace | Osobny wątek wykonania PowerShella, służy do operacji w tle bez zawieszania GUI |
| Lista ochronna | Elementy systemu domyślnie chronione przed zmianą |
| Komputer docelowy | Komputer, na którym wykonywana jest operacja: `localhost` albo komputer zdalny |
| Menedżer poświadczeń | Menedżer poświadczeń Windows (Credential Manager, Panel sterowania → Menedżer poświadczeń → Poświadczenia systemu Windows): magazyn haseł konta Windows chroniony DPAPI; aplikacja zapisuje w nim hasło komputera zdalnego jako wpis generic `MWP:<komputer>` (D-052) |
| Poświadczenie zapamiętane | Hasło komputera zdalnego zapisane w Menedżerze poświadczeń po zaznaczeniu „Zapamiętaj” i udanym połączeniu; używane po jawnym „Połącz” (także po restarcie), potem wspólne w pamięci procesu dla instancji i widgetów tego komputera; po odmowie dostępu unieważnione do końca uruchomienia, usuwane przez „Zapomnij hasło” albo usunięcie komputera (D-052) |
| Blokada ponowień | Po pierwszej odmowie dostępu dla hasła wspólnego żadna instancja ani widget komputera nie próbuje logowania do czasu podania nowego hasła przez użytkownika — ochrona konta przed blokadą (D-052) |
| `localhost` | Komputer lokalny; operacje wykonywane bezpośrednio, bez zdalnego wywołania |
| Kontekst wykonania | Niezmienny w obrębie instancji opis „gdzie i jak” działa moduł: komputer docelowy, tryb Local/Remote, tożsamość, stan połączenia, parametry, limity czasu |
| Definicja modułu | Opis funkcjonalności modułu (manifest, kod); nie jest uruchomieniem |
| Instancja modułu | Konkretne uruchomienie definicji modułu w jednym kontekście wykonania, z własnym stanem i cyklem życia |
| Host | Główna aplikacja: okno, nawigacja, ładowanie modułów, zarządzanie instancjami, konfiguracja |
| Widget | Uproszczony widok danych modułu na Dashboardzie; osobny kontrakt prezentacji, powiązany z instancją i komputerem |
| Typ widgetu | Widget zadeklarowany w manifeście modułu (`<Id modułu>.<Id widgetu>`); od D-053 każdy moduł ma co najmniej jeden. Użytkownik może ukryć typ na liście „Dodaj widżet” i ustawić domyślne parametry nowych widgetów (widok „Moduły”, sekcja „Widżety”) |
| Katalog do dodawania | Typy widgetów widoczne w oknie „Dodaj widżet” (`Get-MwpWidgetDefinition -Addable`); katalog pełny (bez filtra) służy do odtwarzania Pulpitu, więc ukryty typ nadal działa (D-053) |
| Widget-zalążek | Widget modułu-zalążka (`Security`, `Tweaks`) pokazujący tylko wersję modułu; zadeklarowany z `Enabled = $false`, zastępuje go faza obszaru (D-053) |
| Tryb prezentacji | Sposób pokazania modułu: Embedded, SeparateWindow, DashboardWidget, Standalone, CLI |
| Transport | Mechanizm wykonania operacji na komputerze zdalnym (np. WinRM, CIM) |
| Adapter transportu | Prywatne funkcje `MWP.Remote`, jedyne miejsce z poleceniami WinRM/CIM (`New-MwpPSSession`, `Invoke-MwpSessionCommand`, `New-MwpCimSession`…); w testach podmieniane mockami (D-034) |
| Rejestr komputerów docelowych | Klucz `targets` w `config/settings.local.json` z komputerami zdalnymi; `localhost` jest zawsze obecny bez wpisu (`Get-`/`Add-`/`Remove-MwpTarget`) |
| Stan połączenia | Pole `Context.Connection.State`: `Connected`, `Connecting`, `Disconnected`, `Unauthorized`, `Error`; jedyny zmienny element kontekstu wykonania (D-035) |
| Operacja asynchroniczna | Blok wykonywany w puli runspace'ów (`Start-`/`Wait-`/`Stop-MwpOperation`) z limitem równoległości, limitem czasu i anulowaniem (D-036) |
| ADR | Zapis decyzji architektonicznej (problem, opcje, kryteria, wybór, uzasadnienie, konsekwencje); w projekcie wpisy w `DECYZJE.md` |
| Adres połączenia | Adres, pod który aplikacja łączy się z komputerem zdalnym (WinRM/CIM): pole `address` z rejestru, a gdy puste — nazwa; przy HTTPS zawsze nazwa (`MWP.Target.ConnectionAddress`, `Context.Address`; D-054). Nazwa (`name`) pozostaje identyfikatorem komputera w aplikacji |
| Adres wykryty | Adres LAN zgłoszony przez komputer po połączeniu (reguła `Select-MwpNetworkAddress`); pokazywany w podpowiedziach, a adres IP połączenia spoza adresów wykrytych daje tylko ostrzeżenie (D-054) |
| Adres LAN localhost | Adres tego komputera w sieci LAN pokazywany w Ustawieniach (`Get-MwpLocalNetworkAddress`) — wyłącznie informacyjnie, nie zapisywany i nigdy nieużywany do łączenia ani operacji (D-054) |
| NameMismatch | Rodzaj błędu połączenia: pod adresem odpowiada komputer o innej nazwie niż w rejestrze (np. DHCP nadał adres innemu komputerowi); blokuje wszystkie operacje kontekstu do poprawienia adresu (D-054) |
