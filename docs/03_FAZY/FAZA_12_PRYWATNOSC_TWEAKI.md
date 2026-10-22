# FAZA 12 — Prywatność i tweaki

**Status:** DO ZROBIENIA

## Cel
Katalog ustawień systemu (głównie rejestr) zdefiniowany danymi, z odczytem stanu, zastosowaniem i cofnięciem.

## Zależności
FAZY 2 i 3 zakończone.

## Zakres
- Moduł `MWP.Tweaks`: katalog tweaków w pliku danych (JSON lub `.psd1`): `id`, nazwa, opis, kategoria (prywatność, wygląd, wydajność, Eksplorator), klucz rejestru, nazwa i typ wartości, wartość „włączony"/„wyłączony", poziom ryzyka, czy wymaga administratora, czy wymaga restartu lub ponownego logowania.
- Odczyt bieżącego stanu każdego tweaka (włączony / wyłączony / niezgodny / brak klucza).
- Zastosowanie i cofnięcie tweaka; zapis poprzedniej wartości (także informacji, że klucza nie było) w rejestrze cofnięć.
- Profile (np. „Zalecane", „Minimalne"): zestawy tweaków z podglądem różnic.
- Punkt przywracania przed zastosowaniem grupy tweaków oraz eksport kopii zmienianych kluczy (`reg export`).
- Tylko ustawienia obsługiwane i udokumentowane; **żadnych tweaków osłabiających zabezpieczenia systemu** w katalogu domyślnym.
- Każdy tweak z wpisem „źródło/uzasadnienie" i oznaczeniem ryzyka.
- Widok `Tweaks.xaml`: lista z kategoriami, filtrowanie, przełączniki, podgląd zmian.
- Testy Pester z mockami rejestru (testowy klucz, nie realne gałęzie).

## Poza zakresem
Usuwanie wbudowanych aplikacji, wyłączanie Defendera i aktualizacji zabezpieczeń.

## Checklista
- [ ] Format katalogu tweaków i walidacja schematu
- [ ] Odczyt stanu tweaków
- [ ] Zastosuj/cofnij z zapisem poprzedniej wartości
- [ ] Profile z podglądem różnic
- [ ] Punkt przywracania i eksport kluczy przed grupą zmian
- [ ] Początkowy katalog tweaków (bezpiecznych) z ryzykiem i uzasadnieniem
- [ ] Widok `Tweaks.xaml`
- [ ] Testy Pester, PSScriptAnalyzer
- [ ] Dokumentacja zaktualizowana, commit `FAZA 12: ...`

## Kryteria ukończenia
Każdy tweak ma działające cofnięcie; test walidacji katalogu wykrywa niekompletne wpisy.

## Do weryfikacji na Windows 11
Każdy tweak z katalogu: zastosowanie, efekt w systemie, cofnięcie.

## Wyniki
(wypełnia Claude po zakończeniu fazy)

## Następna faza
FAZA 13 — Defender i firewall. Prompt: `docs/04_PROMPTY/PROMPT_FAZA_13.md`.
