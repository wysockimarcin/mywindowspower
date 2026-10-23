# FAZA 8 — Autostart i harmonogram

**Status:** DO ZROBIENIA

## Cel
Kontrola tego, co uruchamia się razem z systemem i użytkownikiem.

## Zależności
FAZY 2, 3 i 4 zakończone.

## Zakres
- Moduł `MWP.Startup`: źródła autostartu — `HKCU`/`HKLM` `Run` i `RunOnce` (także `WOW6432Node`), foldery Startup (użytkownika i wspólny), stan włączenia w `StartupApproved`.
- Włączanie i wyłączanie pozycji w sposób zgodny z Menedżerem zadań (`StartupApproved`), bez kasowania wpisu.
- Zadania harmonogramu: `Get-ScheduledTask`, `Get-ScheduledTaskInfo`; włącz/wyłącz; uruchom teraz; usunięcie tylko z potwierdzeniem i zapisem definicji (eksport XML) przed usunięciem.
- Informacje o wydawcy: podpis cyfrowy pliku (`Get-AuthenticodeSignature`), ścieżka, ocena ryzyka (podpisany / niepodpisany).
- Cofanie zmian.
- Widok `Startup.xaml` (dwie zakładki: Autostart, Harmonogram), operacje w tle.
- Testy Pester z mockami.
- Obsługa komputera docelowego (D-019): dla komputera zdalnego zakres to pozycje obejmujące cały system (HKLM Run/RunOnce, wspólny folder Startup, zadania harmonogramu). **Do zbadania i zapisania w `DECYZJE.md`:** pozycje profilu użytkownika (HKCU, folder Startup użytkownika) na komputerze zdalnym.

## Poza zakresem
Tworzenie nowych zadań harmonogramu.

## Checklista
- [ ] Odczyt wszystkich źródeł autostartu
- [ ] Włącz/wyłącz przez `StartupApproved`
- [ ] Lista zadań harmonogramu, włącz/wyłącz, uruchom
- [ ] Usunięcie zadania z eksportem XML przed operacją
- [ ] Informacja o podpisie wydawcy
- [ ] Cofanie
- [ ] Widok `Startup.xaml`
- [ ] Testy Pester, PSScriptAnalyzer
- [ ] Działa dla `localhost` i dla komputera zdalnego (kontekst wykonania `-Context`, błąd połączenia obsłużony na poziomie instancji)
- [ ] Dokumentacja zaktualizowana, commit `FAZA 8: ...`

## Kryteria ukończenia
Wyłączenie i przywrócenie pozycji autostartu działa i jest widoczne w Menedżerze zadań.

## Do weryfikacji na Windows 11
Zgodność ze stanem w Menedżerze zadań > Aplikacje startowe; zadania wymagające administratora. Dodatkowo test na komputerze zdalnym użytkownika (obsługa zdalna, utrata połączenia).

## Wyniki
(wypełnia Claude po zakończeniu fazy)

## Następna faza
FAZA 9 — Czyszczenie dysku. Prompt: `docs/04_PROMPTY/PROMPT_FAZA_9.md`.
