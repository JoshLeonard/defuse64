"""Generates src/data.asm (game tables) and dist/manual.html (defusal manual).

Both outputs come from the tables in this file so the game and the manual
can never disagree about keypad columns, mazes, words or level settings.
"""
import os, random

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# ---------------------------------------------------------------- glyphs
SYMBOLS = [
 ("OMEGA",    ["..####..",".#....#.","#......#","#......#",".#....#.","..#..#..","###..###","........"]),
 ("STAR",     ["...#....","...#....","#######.",".#####..","..###...",".##.##..",".#...#..","........"]),
 ("SMILE",    [".######.","#......#","#.#..#.#","#......#","#.#..#.#","#..##..#",".######.","........"]),
 ("TRIDENT",  ["#..#..#.","#..#..#.","#..#..#.",".#.#.#..","..###...","...#....","..###...","........"]),
 ("COPYRIGHT",["..####..",".#....#.","#..###.#","#.#....#","#..###.#",".#....#.","..####..","........"]),
 ("PILCROW",  ["..#####.",".###.#..",".###.#..","..##.#..","...#.#..","...#.#..","...#.#..","........"]),
 ("QUERY",    ["...##...","........","...##...","..##....",".##.....",".##..##.","..####..","........"]),
 ("LAMBDA",   ["###.....","...#....","...#....","..#.#...","..#.#...",".#...#..","#.....##","........"]),
 ("HEART",    [".##.##..","#######.","#######.",".#####..","..###...","...#....","........","........"]),
 ("SPADE",    ["...#....","..###...",".#####..","#######.","#######.",".#.#.#..","...#....","..###..."]),
 ("CLUB",     ["..###...","..###...","##.#.##.","#######.","##.#.##.","...#....","..###...","........"]),
 ("DIAMOND",  ["...#....","..#.#...",".#...#..","#.....#.",".#...#..","..#.#...","...#....","........"]),
 ("MOON",     ["..####..",".##.....","##......","##......","##......",".##.....","..####..","........"]),
 ("SUN",      ["#..#..#.",".#...#..","..###...","#.#.#.#.","..###...",".#...#..","#..#..#.","........"]),
 ("BELL",     ["...#....","..###...",".#...#..",".#...#..",".#...#..","#######.","...#....","........"]),
 ("KEY",      ["........",".##.....","#..#....","#..#####","#..#.#.#",".##.....","........","........"]),
 ("SKULL",    [".#####..","#######.","#..#..#.","#######.",".##.##..","..###...","..#.#...","........"]),
 ("EYE",      ["........","...##...",".##..##.","#..##..#",".##..##.","...##...","........","........"]),
 ("ANCHOR",   ["...#....","..#.#...","...#....","#######.","...#....","#..#..#.",".#####..","........"]),
 ("HOURGLASS",["#######.",".#...#..","..#.#...","...#....","..#.#...",".#...#..","#######.","........"]),
 ("BOLT",     ["....##..","...##...","..##....",".######.","....##..","...##...","..#.....","........"]),
 ("NOTE",     ["...##...","...#.#..","...#..#.","...#....",".###....","####....",".##.....","........"]),
 ("DAGGER",   ["...#....","...#....","#######.","...#....","...#....","...#....","...#....","........"]),
 ("PEAK",     ["...#....","..#.#...","..#.#...",".#.#.#..",".#...#..","#.....#.","#######.","........"]),
 ("ZHE",      ["#..#..#.","#..#..#.",".#.#.#..","..###...",".#.#.#..","#..#..#.","#..#..#.","........"]),
 ("LOOP",     ["........","........",".##..##.","#..##..#","#..##..#",".##..##.","........","........"]),
 ("YAT",      [".#......","####....",".#......",".####...",".#...#..",".#...#..",".####...","........"]),
]
SYMBASE = 0x60   # screen code of symbol 0

EXTRA = [  # (screen code, rows)
 (0x7B, ["...#....","...#....","..###...","..###...",".#####..",".#####..","#######.","........"]),  # maze goal
 (0x7C, ["........","........","........","########","########","........","........","........"]),  # thick h wire
 (0x7D, ["........","........","..####..","..####..","..####..","..####..","........","........"]),  # terminal
 (0x7E, ["...##...","...##...","...##...","...##...","...##...","...##...","...##...","...##..."]),  # thick v wire
 (0x7F, ["........","........","........","...##...","...##...","........","........","........"]),  # maze cell
]

# ---------------------------------------------------------------- keypad
def make_columns():
    rnd = random.Random(6464)
    while True:
        cols = [rnd.sample(range(27), 7) for _ in range(6)]
        used = set(s for c in cols for s in c)
        if len(used) != 27:
            continue
        ok = all(len(set(cols[a]) & set(cols[b])) <= 2 for a in range(6) for b in range(a + 1, 6))
        if ok:
            return cols
COLUMNS = make_columns()

# ---------------------------------------------------------------- mazes
def make_mazes():
    rnd = random.Random(1982)
    mazes = []
    used = set()
    while len(mazes) < 9:
        east = [[1] * 6 for _ in range(6)]   # wall to the east of (x,y)
        south = [[1] * 6 for _ in range(6)]  # wall to the south
        seen = {(0, 0)}
        stack = [(rnd.randrange(6), rnd.randrange(6))]
        seen = {stack[0]}
        while stack:
            x, y = stack[-1]
            nb = [(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
                  if 0 <= x + dx < 6 and 0 <= y + dy < 6 and (x + dx, y + dy) not in seen]
            if not nb:
                stack.pop(); continue
            nx, ny = rnd.choice(nb)
            if nx > x: east[y][x] = 0
            elif nx < x: east[y][nx] = 0
            elif ny > y: south[y][x] = 0
            else: south[ny][x] = 0
            seen.add((nx, ny)); stack.append((nx, ny))
        # knock out a few extra walls so there are loops (harder to guess)
        for _ in range(4):
            x, y = rnd.randrange(5), rnd.randrange(5)
            if rnd.random() < .5: east[y][x] = 0
            else: south[y][x] = 0
        free = [(x, y) for x in range(6) for y in range(6) if (x, y) not in used]
        m1, m2 = rnd.sample(free, 2)
        if m1[1] == m2[1] or m1[0] == m2[0]:
            continue
        used |= {m1, m2}
        mazes.append((east, south, m1, m2))
    return mazes
MAZES = make_mazes()

# ---------------------------------------------------------------- words
PASSWORDS = ("ALPHA BLAST BRAVO CABLE CHARM CLOCK CRANE DELTA DRIFT EMBER FAULT FLARE "
             "GHOST GRAIN HAVOC IVORY JUMBO KNACK LASER LEVER MANOR NERVE OCEAN PANIC "
             "PIXEL QUART RADAR SPARK TIGER ULTRA VAPOR WALTZ XENON YIELD ZEBRA").split()
assert len(PASSWORDS) == 35 and all(len(w) == 5 for w in PASSWORDS)

MORSE_WORDS = [("ALARM", 505), ("BLAZE", 512), ("BOOMS", 518), ("CRASH", 525), ("DOTS", 532),
               ("EARTH", 538), ("FLASH", 545), ("FUSE", 552), ("GRID", 558), ("HELIX", 565),
               ("LIGHT", 572), ("MOTOR", 578), ("PULSE", 585), ("RELAY", 592), ("SPARK", 595),
               ("TIMER", 600)]
MORSE = {'A': '.-', 'B': '-...', 'C': '-.-.', 'D': '-..', 'E': '.', 'F': '..-.', 'G': '--.',
         'H': '....', 'I': '..', 'J': '.---', 'K': '-.-', 'L': '.-..', 'M': '--', 'N': '-.',
         'O': '---', 'P': '.--.', 'Q': '--.-', 'R': '.-.', 'S': '...', 'T': '-', 'U': '..-',
         'V': '...-', 'W': '.--', 'X': '-..-', 'Y': '-.--', 'Z': '--..'}

# ---------------------------------------------------------------- levels
MODNAMES = ["WIRES", "THE BUTTON", "KEYPAD", "SIMON SAYS", "MEMORY", "MAZE", "PASSWORD",
            "MORSE CODE", "COMPLEX WIRES", "VENT GAS"]
UNLOCK = [1, 2, 4, 7, 11, 16, 22, 30, 40, 50]

def level(L):
    needy = 0 if L < UNLOCK[9] else (1 if L < 75 else 2)
    count = max(1, min(11, int(1 + (L - 1) * 10 / 99 + 0.5)))
    count = min(count, 12 - needy)
    spm = 120 - (L - 1) * 80 / 99
    secs = int(round((30 + count * spm) / 5.0)) * 5
    strikes = 3 if L < 70 else (2 if L < 90 else 1)
    tier = 0 if L < 20 else 1 if L < 45 else 2 if L < 70 else 3
    pool = sum(1 << t for t in range(9) if UNLOCK[t] <= L)
    forced = next((t for t in range(10) if UNLOCK[t] == L), 0xFF)
    return dict(count=count, needy=needy, secs=secs, strikes=strikes, tier=tier,
                pool=pool, forced=forced)
LEVELS = [level(L) for L in range(1, 101)]

def make_codes():
    rnd = random.Random(1541)
    alpha = "ABCDEFGHJKLMNPQRSTUVWXYZ"
    codes, seen = [], set()
    while len(codes) < 100:
        c = "".join(rnd.choice(alpha) for _ in range(4))
        if c not in seen:
            seen.add(c); codes.append(c)
    return codes
CODES = make_codes()

# ---------------------------------------------------------------- big text
FONT = {
 'D': ["##.", "#.#", "#.#", "#.#", "##."], 'E': ["###", "#..", "##.", "#..", "###"],
 'F': ["###", "#..", "##.", "#..", "#.."], 'U': ["#.#", "#.#", "#.#", "#.#", "###"],
 'S': ["###", "#..", "###", "..#", "###"], '6': ["###", "#..", "###", "#.#", "###"],
 '4': ["#.#", "#.#", "###", "..#", "..#"], 'B': ["##.", "#.#", "##.", "#.#", "##."],
 'O': ["###", "#.#", "#.#", "#.#", "###"], 'M': ["#.#", "###", "###", "#.#", "#.#"],
 '!': [".#.", ".#.", ".#.", "...", ".#."], ' ': ["...", "...", "...", "...", "..."],
}
BIGTEXT = [("big_title", "DEFUSE 64"), ("big_boom", "BOOM!"), ("big_defused", "DEFUSED")]

def big_rows(text):
    rows = []
    for r in range(5):
        rows.append("".join(FONT[ch][r] + "." for ch in text)[:-1])
    return rows

# ---------------------------------------------------------------- asm out
def sc(s):  # ascii upper -> C64 screen codes
    out = []
    for ch in s:
        if 'A' <= ch <= 'Z': out.append(ord(ch) - 64)
        else: out.append(ord(ch))
    return out

def bcd(n): return (n // 10) * 16 + n % 10

def rows_to_bytes(rows):
    return [int(r.replace('.', '0').replace('#', '1'), 2) for r in rows]

def hexs(bs): return ",".join("$%02x" % b for b in bs)

def write_asm():
    L = []
    w = L.append
    w("// generated by tools/gen.py -- do not edit")
    w(".label SYMBASE = $%02x" % SYMBASE)
    w("glyph_codes:")
    w("  .byte " + hexs([SYMBASE + i for i in range(len(SYMBOLS))] + [c for c, _ in EXTRA]))
    w(".label GLYPH_COUNT = %d" % (len(SYMBOLS) + len(EXTRA)))
    w("glyph_data:")
    for name, rows in SYMBOLS:
        w("  .byte " + hexs(rows_to_bytes(rows)) + "   // " + name)
    for c, rows in EXTRA:
        w("  .byte " + hexs(rows_to_bytes(rows)))
    w("keypad_cols:")
    for c in COLUMNS:
        w("  .byte " + hexs(c))
    w("maze_walls:   // per cell: bit0 = wall east, bit1 = wall south")
    for east, south, m1, m2 in MAZES:
        w("  .byte " + hexs([east[y][x] | (south[y][x] << 1) for y in range(6) for x in range(6)]))
    w("maze_marks:   // x1,y1,x2,y2")
    for east, south, m1, m2 in MAZES:
        w("  .byte " + hexs([m1[0], m1[1], m2[0], m2[1]]))
    w("pw_words:")
    for wd in PASSWORDS:
        w("  .byte " + hexs(sc(wd)) + "   // " + wd)
    w(".label PW_COUNT = %d" % len(PASSWORDS))
    # morse: 1=dot 2=dash 3=letter gap 0=end of word
    streams, offs = [], []
    for wd, f in MORSE_WORDS:
        offs.append(len(streams))
        for ch in wd:
            streams += [1 if s == '.' else 2 for s in MORSE[ch]] + [3]
        streams[-1] = 0
    w("morse_offs:  .byte " + hexs(offs))
    w("morse_stream:")
    for i in range(0, len(streams), 16):
        w("  .byte " + hexs(streams[i:i + 16]))
    w("morse_freq:   // three screen-code digits after '3.'")
    for wd, f in MORSE_WORDS:
        w("  .byte " + hexs(sc(str(f))) + "   // " + wd)
    for key in ("count", "needy", "strikes", "tier", "forced"):
        w("lv_%s:" % key)
        vals = [lv[key] for lv in LEVELS]
        for i in range(0, 100, 20):
            w("  .byte " + hexs(vals[i:i + 20]))
    w("lv_min:")
    w("  .byte " + hexs([bcd(lv['secs'] // 60) for lv in LEVELS]))
    w("lv_sec:")
    w("  .byte " + hexs([bcd(lv['secs'] % 60) for lv in LEVELS]))
    w("lv_pool_lo:")
    w("  .byte " + hexs([lv['pool'] & 255 for lv in LEVELS]))
    w("lv_pool_hi:")
    w("  .byte " + hexs([lv['pool'] >> 8 for lv in LEVELS]))
    w("lv_codes:")
    for i in range(0, 100, 10):
        w("  .byte " + hexs([b for c in CODES[i:i + 10] for b in sc(c)]))
    for label, text in BIGTEXT:
        rows = big_rows(text)
        w(".label %s_W = %d" % (label.upper(), len(rows[0])))
        w(label + ":")
        for r in rows:
            w("  .byte " + hexs([0xA0 if c == '#' else 0x20 for c in r]))
    with open(os.path.join(ROOT, "src", "data.asm"), "w") as f:
        f.write("\n".join(L) + "\n")

# ---------------------------------------------------------------- manual
def glyph_svg(rows, px=4, color="#222"):
    rects = []
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch == '#':
                rects.append('<rect x="%d" y="%d" width="%d" height="%d"/>' % (x * px, y * px, px, px))
    s = 8 * px
    return ('<svg class="glyph" width="%d" height="%d" viewBox="0 0 %d %d" fill="%s">%s</svg>'
            % (s, s, s, s, color, "".join(rects)))

def maze_svg(east, south, m1, m2, n):
    c = 34; pad = 10; size = 6 * c + 2 * pad
    p = ['<svg class="maze" width="%d" height="%d" viewBox="0 0 %d %d">' % (size, size, size, size)]
    p.append('<rect x="%d" y="%d" width="%d" height="%d" fill="none" stroke="currentColor" stroke-width="4"/>'
             % (pad, pad, 6 * c, 6 * c))
    for y in range(6):
        for x in range(6):
            cx, cy = pad + x * c + c // 2, pad + y * c + c // 2
            if (x, y) in (m1, m2):
                p.append('<circle cx="%d" cy="%d" r="11" fill="none" stroke="#1a8f3a" stroke-width="4"/>' % (cx, cy))
            else:
                p.append('<circle cx="%d" cy="%d" r="2.5" fill="currentColor" opacity=".55"/>' % (cx, cy))
            if x < 5 and east[y][x]:
                X = pad + (x + 1) * c
                p.append('<line x1="%d" y1="%d" x2="%d" y2="%d" stroke="currentColor" stroke-width="4" stroke-linecap="square"/>'
                         % (X, pad + y * c, X, pad + (y + 1) * c))
            if y < 5 and south[y][x]:
                Y = pad + (y + 1) * c
                p.append('<line x1="%d" y1="%d" x2="%d" y2="%d" stroke="currentColor" stroke-width="4" stroke-linecap="square"/>'
                         % (pad + x * c, Y, pad + (x + 1) * c, Y))
    p.append('</svg>')
    return "".join(p)

def write_manual():
    keycols = "".join(
        '<div class="kcol"><div class="khead">%d</div>%s</div>' % (
            i + 1, "".join('<div class="kcell">%s</div>' % glyph_svg(SYMBOLS[s][1]) for s in col))
        for i, col in enumerate(COLUMNS))
    mazes = "".join('<figure>%s<figcaption>Maze %d</figcaption></figure>' % (maze_svg(*m, i + 1), i + 1)
                    for i, m in enumerate(MAZES))
    pw = "".join("<span>%s</span>" % w for w in PASSWORDS)
    letters = sorted(set("".join(w for w, _ in MORSE_WORDS)))
    morse_tbl = "".join('<div class="mrow"><b>%s</b><span>%s</span></div>' % (
        ch, MORSE[ch].replace('.', '&#9679;').replace('-', '&#9644;')) for ch in letters)
    morse_words = "".join('<tr><td>%s</td><td>3.%d MHz</td></tr>' % (w, f) for w, f in MORSE_WORDS)
    milestones = "".join('<tr><td>%d</td><td>%s</td></tr>' % (UNLOCK[t], MODNAMES[t]) for t in range(10))
    codelog = "".join('<tr><td>%d</td><td></td><td>%d</td><td></td><td>%d</td><td></td><td>%d</td><td></td></tr>'
                      % (r + 1, r + 26, r + 51, r + 76) for r in range(25))
    html = MANUAL
    for k, v in dict(KEYCOLS=keycols, MAZES=mazes, PW=pw, MORSE_TBL=morse_tbl,
                     MORSE_WORDS=morse_words, MILESTONES=milestones, CODELOG=codelog).items():
        html = html.replace("@@%s@@" % k, v)
    with open(os.path.join(ROOT, "dist", "manual.html"), "w", encoding="utf-8") as f:
        f.write(html)

MANUAL = open(os.path.join(ROOT, "tools", "manual_template.html"), encoding="utf-8").read()

if __name__ == "__main__":
    write_asm()
    write_manual()
    print("ok: src/data.asm, dist/manual.html")
