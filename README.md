# ZyBank

A personal ledger written in Zymbol — income and expenses, in four languages,
over SQLite.

It is an **LDV project** (`interpreter/LDV.md`): an application built to find
out what the language cannot yet say. The program is the instrument; the
finding is the product. Nineteen of them are in
[HALLAZGOS.md](HALLAZGOS.md) — including **two engine divergences in behaviour**
(each engine breaks a different way of passing a function between modules) and a
third in diagnostics, in a language whose gate reports zero divergences over 616
corpus files.

The code is written in Spanish, like `serpiente` and `Zofía`. What is new here
is the domain, which is what LDV § 6 says the method actually scales with.

---

## What it is for

Money is the one domain where a rounding error is not a rounding error. So:

**An amount is one integer in the minor unit of its currency — never a float.**
And the number of decimals is **configuration, not a constant**: the Chilean
peso has no minor unit in circulation (exponent 0), the dollar and the euro have
two, the Kuwaiti dinar has three. `1050` is `$1.050`, `$10.50` or `1.050 د.ك`
depending on which currency it is in, and the stored integer never changes.

That single requirement is what exposed the first finding: `#.N|…|` needs a
**literal** precision, so a formatter whose precision arrives at run time cannot
use it at all — and `#.2|10.5|` prints `10.5`, not `10.50`.

## Running it

Needs a `zymbol` binary with `std/db` (a source build, or Windows) and an ODBC
DSN named `zymbol_sqlite` — see `zyquality/corpus/stdlib/README-odbc.md`.

```bash
zymbol run zybank.zy iniciar                      # create the schema, seed categories
zymbol run zybank.zy nueva Corriente CLP 500000   # an account
zymbol run zybank.zy anotar Corriente gasto.alimentación 25990 "Feria" 2026-08-01
zymbol run zybank.zy cuentas
zymbol run zybank.zy resumen Corriente 2026-08-01 2026-08-31
zymbol run zybank_tui.zy                          # full-screen browser
```

**The verbs are accepted in all four languages, always** — `zybank 口座`,
`zybank accounts`, `zybank खाते`, `zybank cuentas` are the same command. Only
the *output* follows the configured locale. Translating the verb according to
the active locale would mean a command that works today and fails tomorrow
because someone changed a preference.

Configuration follows one rule: **the file outranks, the database remembers.**
`zybank.json` may itself be written in the user's language —
`{"言語": "hi", "通貨": "KWD"}` configures it — via `json::decode_map`.

## Layout

| Directory | What lives there |
|---|---|
| `núcleo/` | money arithmetic, the schema and `std/db`, the seed, the dictionary helper |
| `configuración/` | the currency table, and where locale and currency come from |
| `idioma/` | the dispatcher and four catalogues (es · en · ja · hi) |
| `presentación/` | columns measured with `std/term`, never with `$#` |
| `interfaz/` | the verbs and the command application |
| `pantalla/` | the full-screen browser |
| `pruebas/` | five suites, registered in `zyquality/project/apps.toml` |

## Testing

```bash
bash pruebas/todas.sh                     # all five, both engines
cd ../zyquality && bash project/run.sh --only zybank    # the gate
```

Four suites are pure Zymbol judged against goldens by `zyq expect`; the fifth
drives the TUI through a real pty and compares the two engines byte for byte.
The browser engine does not take part: `std/db` does not exist there, and it has
neither a terminal nor a filesystem.

## Documents

- [HALLAZGOS.md](HALLAZGOS.md) — the findings. **The point of the project.**
- [README_ES.md](README_ES.md) — this, in Spanish.
