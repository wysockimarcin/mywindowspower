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
| Widok | Plik XAML z interfejsem jednego obszaru |
| STA | Single-Threaded Apartment — tryb wątku wymagany przez WPF |
| Runspace | Osobny wątek wykonania PowerShella, służy do operacji w tle bez zawieszania GUI |
| Lista ochronna | Elementy systemu domyślnie chronione przed zmianą |
| Komputer docelowy | Komputer, na którym wykonywana jest operacja: `localhost` albo komputer zdalny |
| `localhost` | Komputer lokalny; operacje wykonywane bezpośrednio, bez zdalnego wywołania |
| Kontekst wykonania | Niezmienny w obrębie instancji opis „gdzie i jak” działa moduł: komputer docelowy, tryb Local/Remote, tożsamość, stan połączenia, parametry, limity czasu |
| Definicja modułu | Opis funkcjonalności modułu (manifest, kod); nie jest uruchomieniem |
| Instancja modułu | Konkretne uruchomienie definicji modułu w jednym kontekście wykonania, z własnym stanem i cyklem życia |
| Host | Główna aplikacja: okno, nawigacja, ładowanie modułów, zarządzanie instancjami, konfiguracja |
| Widget | Uproszczony widok danych modułu na Dashboardzie; osobny kontrakt prezentacji, powiązany z instancją i komputerem |
| Tryb prezentacji | Sposób pokazania modułu: Embedded, SeparateWindow, DashboardWidget, Standalone, CLI |
| Transport | Mechanizm wykonania operacji na komputerze zdalnym (np. WinRM, CIM) |
| ADR | Zapis decyzji architektonicznej (problem, opcje, kryteria, wybór, uzasadnienie, konsekwencje); w projekcie wpisy w `DECYZJE.md` |
