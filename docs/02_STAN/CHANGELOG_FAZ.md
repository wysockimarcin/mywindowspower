# CHANGELOG FAZ — mywindowspower

> Raport po każdej zakończonej fazie. Najnowsze wpisy na górze. Hash commita fazy uzupełnia następna faza na swoim starcie (nie da się go znać przed wykonaniem commita).

## Szablon wpisu

```
## FAZA N — <nazwa> (<data>)
- Status: ZAKOŃCZONA | CZĘŚCIOWA
- Commit: <hash> `FAZA N: opis`
- Zrobiono: ...
- Niezrobione / odroczone: ... (dokąd przeniesione)
- Decyzje: D-xxx, D-yyy
- Do weryfikacji na Windows 11: ...
- Następna faza: FAZA N+1 — <nazwa>
```

---

## FAZA 0 — Fundament (2026-10-22)
- Status: ZAKOŃCZONA
- Commit: `FAZA 0: fundament projektu, dokumentacja i plan faz` — hash do uzupełnienia w FAZIE 1
- Zrobiono: `git init` (gałąź `main`), remote `origin` → https://github.com/wysockimarcin/mywindowspower, `.gitignore`, `README.md`, `CLAUDE.md`, struktura `docs/` (`00_PROJEKT`, `01_PLAN`, `02_STAN`, `03_FAZY`, `04_PROMPTY`, `05_PROCES`), plan 16 faz, pliki faz i prompty.
- Niezrobione / odroczone: `git push` (wymaga uwierzytelnienia użytkownika).
- Decyzje: D-001 … D-008
- Do weryfikacji na Windows 11: nic (brak kodu).
- Następna faza: FAZA 1 — Szkielet techniczny
