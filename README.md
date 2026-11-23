# DEFUSE 64

A cooperative bomb-defusal game for the Commodore 64, in the spirit of
*Keep Talking and Nobody Explodes*. One player sits at the C64 with the bomb.
Everyone else has the manual. Nobody sees both.

## Play

Everything below is also on the [latest release](../../releases/latest) page, one
download per file.

* [`dist/defuse64.prg`](dist/defuse64.prg) — autostart in VICE
  (`x64sc dist/defuse64.prg`), or
* [`dist/defuse64.d64`](dist/defuse64.d64) — disk image: `LOAD"*",8,1` then
  `RUN` on real hardware or an emulator.
* [`dist/manual.html`](dist/manual.html) — the defusal manual. Print it or open
  it on another screen for the experts.
* [`dist/manual.pdf`](dist/manual.pdf) — the same manual, typeset for US Letter
  and ready to print.

On GitHub each file page has a *Download* button; the HTML manual has to be
saved before a browser will render it, the PDF opens straight in a viewer.

Controls: WASD, the cursor keys or a joystick in port 2 to move. RETURN, SPACE or
fire to select, cut or press. DEL or `←` to back out of a module. Push past
the edge of the modules to turn the bomb; F1 or F swaps front and back.

## The game

* 100 levels. Bombs grow from 1 to 10 modules (plus up to 2 needy modules), the time per module shrinks, and
  the modules get harder. From level 70 the bomb explodes on the 2nd strike;
  from level 90 on the 1st.
* Modules: Wires, The Button, Keypad, Simon Says, Memory, Maze, Password,
  Morse Code, Complex Wires, plus the needy Vent Gas module (levels 50+).
* The bomb has six faces. Modules sit on the front and back. The serial number,
  batteries, indicators and ports are scattered over the left, right, top and
  bottom faces. Push past the edge of the modules to turn the bomb; the new
  face slides into view.
* Each bomb is randomly generated (serial number, batteries, ports,
  indicators, module contents), so replaying a level gives a new bomb.
* Defusing a bomb shows a 4-letter code for the next level. Enter it on the
  title screen with `C`.

## Build

Needs Python 3, Java, KickAssembler 5.x and VICE (`c1541` on PATH).
Chrome or Edge is also used, if present, to print `dist/manual.pdf`.

```powershell
./build.ps1                     # set $env:KICKASS_JAR if KickAss.jar is elsewhere
```

`tools/gen.py` generates both `src/data.asm` (keypad columns, mazes, words,
level table, codes) and `dist/manual.html` from the same tables, so the game and
the manual always agree. `tools/manual_pdf.ps1` then prints that HTML to
`dist/manual.pdf`, and can be run on its own after editing the manual template.

## Test bot

`tools/bot.py` drives the game through VICE's remote monitor and defuses bombs
using rules written independently from the manual text. A level passes only
when the bomb is defused with zero strikes.

```
python tools/bot.py 1 7 22 40 50 100
```

## Source layout

| File | Contents |
|------|----------|
| `src/main.asm` | entry point |
| `src/core.asm` | IRQ, timer, sound, input, RNG, screen routines |
| `src/bomb.asm` | bomb generation, edgework, panels, play loop |
| `src/mods1.asm` | Wires, Button, Keypad, Simon Says, Memory |
| `src/mods2.asm` | Maze, Password, Morse, Complex Wires, Vent Gas |
| `src/screens.asm` | title, level codes, intro, explosion and win screens |
| `src/data.asm` | generated tables |
