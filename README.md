# ZyBank

A personal ledger written in Zymbol — income and expenses, in four languages,
over SQLite.

It is an **LDV project** (`interpreter/LDV.md`): an application built to find
out what the language cannot yet say. The program is the instrument; the
finding is the product. Twenty-five of them are in
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

### The words are the trade's, not the dictionary's

Writing the program in Spanish is not translating it: it is writing it in the
Spanish **of accounting**. An everyday word standing in for a term of the trade
lies about what the code does, and it lies in the language that was supposed to
make it plain.

| Term | Is | Is not |
|---|---|---|
| **Abono** | credit — raises the balance | "ingreso" (income): that is the nature, not the effect |
| **Cargo** | debit — lowers the balance | "descontar" (to discount): discounting marks a price down, and is not the opposite of crediting |
| **Importe** | the amount of a movement | "monto", the loose word for it |
| **Glosa** | the text explaining a movement | "note", "description" |
| **Asiento** | the whole entry | one of its halves |
| **Partida** | each half of an entry | an entry of its own |
| **Traspaso** | moving money between one's own accounts | a transfer to a third party |
| **Apertura** | the entry an account starts with | "opening balance", which sounds like a property of the account rather than a dated fact |

And they are **two axes, not one**. The **naturaleza** — income, expense,
adjustment — says what the movement is about and lives in the category's key and
group. The **sentido** — abono or cargo — says which way it moves the balance and
lives in a column of its own. Conflating them is what the old `tipo` column did,
holding "ingreso"/"gasto" in the place that decides the sign: which is why an
adjustment did not fit — it is neither — and had to hang off one of them
pretending it was.

## Running it

Needs a `zymbol` binary with `std/db` (a source build, or Windows) and an ODBC
DSN named `zymbol_sqlite` — see `zyquality/corpus/stdlib/README-odbc.md`.

### Full screen

```bash
zymbol run zybank_tui.zy
```

Where the ledger is actually operated: opening accounts, recording movements,
correcting and deleting them, and **crediting or debiting a balance**. Two things
exist only here:

- **Validation happens while typing, and it is numeric, not textual.** The
  amount field does not accept a letter — it does not type it — and the decimal
  point only enters if the currency has decimals: in Chilean pesos the point key
  does nothing, in dollars it takes two digits, in Kuwaiti dinars three. No
  invalid state is ever reached. The amount is shown formatted as it is typed.

  The **date** field follows the same rule: digits are typed and the field puts
  the dashes, so "2026-08-2100" cannot be written — and ENTER does not confirm a
  `2026-02-31`, since eight well-placed digits can still fail to be a day. A
  ledger sorts by date and summarises by period, so a date that does not exist
  does not disarrange the screen: it disarranges the money.
- **A digit is not "0".."9".** A Hindi keyboard sends «२», a Bengali one «২», and
  both are two. The field takes them — thirteen scripts — and stores the
  **value**, not the key, so one account accepts Devanagari today and ASCII
  tomorrow. What is painted follows the chosen locale's script. Accepting only
  ASCII would localise the output and leave the input unlocalised, which is worse
  than localising nothing: it shows the user a script it then refuses.
- **The locale changes live**, digits included, with nothing reloaded.

Keys: `↑↓` or `jk` move · `→` or `⏎` open · `←` or `⏎` back · `n` new ·
`e` edit · `x` delete · `+` credit · `-` debit · `t` transfer · `c` new account ·
`r` summary · `i` locale · `q` quit.

**The arrows work, and for a while they did not.** `<<|` hands over an arrow
already decoded — `'↓'` is one character, not `ESC`+`[`+`B` — and a bare ESC
still arrives as ESC, so taking them costs nothing. The application ignored them
because a finding said it was impossible without a timer; the finding reasoned
about what the terminal sends rather than about what the language delivers:
[GAP-ZYB-011](HALLAZGOS.md#gap-zyb-011), withdrawn. `jk` stays alongside, for
whoever comes from `vi`.

**A transfer is one entry of two legs, not two loose movements.** `t` moves
money from the account being looked at to another: a **debit** leaves the source
and a **credit** enters the destination, paired by a mark, categoryless and in
one transaction — half a transfer is not a state the database may hold. They are
not edited separately (changing one half leaves the other lying) and deleting one
deletes both. The summary excludes them: moving your own money between your own
accounts is neither expense nor income, and counting it would inflate both
columns at once.

Across currencies the program **asks for the amount that arrives** rather than
inventing a rate: whoever moves 100,000 CLP into a dollar account knows what they
were given for it, and guessing would be falsifying an entry.

**No money figure lives outside the ledger.** An account's balance is the sum of
its movements and nothing else — there is no balance column for anything to
contradict. Opening an account with an amount writes its **opening entry**: a
line with its date, its "Apertura" category and its amount, in the same
transaction that creates the account. Half an opening — account created, line not
— is not a state the database may hold.

There was a `saldo_inicial` column, and it was the only money in the program that
no line explained. It was defended as "what was there when the account was
opened", but that is precisely an entry: it has a date and it has a counterpart.
If a ledger whose balance **changes** without a trace is not a ledger, neither is
one whose balance **starts** without a trace.

The opening entry **does not count in the summary**, for the same reason a
transfer does not: its counterpart is equity, not a result account. Opening an
account with twenty million is not having earned twenty million that month. Nor
is it offered in the picker when recording — what the summary excludes must not
be in the picker, or it is an invisible category: the expense is stored, the
balance moves, and the line shows up in no summary. **Adjustments** are offered,
because they do count.

**Crediting and debiting are movements, not a balance that changes.** An
adjustment leaves its own line, with its date and note.

### By command

```bash
zymbol run zybank.zy iniciar                      # create the schema, seed categories
zymbol run zybank.zy nueva Corriente CLP 500000   # an account
zymbol run zybank.zy anotar Corriente gasto.alimentación 25990 "Feria" 2026-08-01
zymbol run zybank.zy cuentas
zymbol run zybank.zy resumen Corriente 2026-08-01 2026-08-31
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
| `pantalla/` | the full-screen application: key constants, input fields, screens |
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
