# FAZA 10 — Sieć

**Status:** DO ZROBIENIA

## Cel
Diagnostyka i konfiguracja sieci z możliwością cofnięcia zmian.

## Zależności
FAZY 2 i 3 zakończone.

## Zakres
- Moduł `MWP.Network`: adaptery (`Get-NetAdapter`), konfiguracja IP (`Get-NetIPConfiguration`), profile sieci, włącz/wyłącz adapter (z ostrzeżeniem o utracie połączenia).
- DNS: odczyt i zmiana (`Set-DnsClientServerAddress`) z presetami (DHCP/automatyczny, Cloudflare, Google, Quad9) i własnymi adresami; zapis poprzednich ustawień i cofanie.
- `Clear-DnsClientCache`, odnowienie dzierżawy DHCP.
- Resety: `netsh winsock reset`, `netsh int ip reset` — tylko z potwierdzeniem i informacją o wymaganym restarcie.
- Testy łączności: ping do bramy i do hosta zewnętrznego, rozwiązywanie nazwy DNS (`Resolve-DnsName`), prosty test portu.
- Widok `Network.xaml`, operacje w tle.
- Testy Pester z mockami.

## Poza zakresem
VPN, konfiguracja Wi-Fi (hasła, profile), proxy.

## Checklista
- [ ] Lista adapterów i konfiguracji IP
- [ ] Zmiana DNS z presetami i cofaniem
- [ ] Flush DNS, odnowienie DHCP
- [ ] Resety Winsock i stosu IP z potwierdzeniem
- [ ] Testy łączności
- [ ] Widok `Network.xaml`
- [ ] Testy Pester, PSScriptAnalyzer
- [ ] Dokumentacja zaktualizowana, commit `FAZA 10: ...`

## Kryteria ukończenia
Zmianę DNS można cofnąć jednym kliknięciem; operacje ryzykowne wymagają potwierdzenia.

## Do weryfikacji na Windows 11
Zmiana DNS i testy łączności na realnym adapterze (administrator).

## Wyniki
(wypełnia Claude po zakończeniu fazy)

## Następna faza
FAZA 11 — Aplikacje i winget. Prompt: `docs/04_PROMPTY/PROMPT_FAZA_11.md`.
