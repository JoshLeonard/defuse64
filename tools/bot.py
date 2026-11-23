"""Plays DEFUSE 64 in VICE using only the rules as written in the manual.

    python tools/bot.py 1 7 22 50 100      # play these levels

A level passes when the bomb is defused with zero strikes.
"""
import sys, time
from collections import deque
from vice import *
import gen

MD = 48
DIR = {"U": B_UP, "D": B_DOWN, "L": B_LEFT, "R": B_RIGHT}
RED, BLUE, YELLOW, WHITE, BLACK = range(5)

class Bot:
    def __init__(self, v):
        self.v = v
        self.log = []

    # ------------------------------------------------------------ helpers
    def g(self, name, n=1, off=0):
        vals = self.v.peek(self.v.sym[name] + off, n)
        return vals if n > 1 else vals[0]

    def md(self, i):
        return self.v.peek(self.v.sym["mdata"] + i * MD, MD)

    def tap(self, b, n=1):
        for _ in range(n):
            self.v.press(b, 3, 0.12)

    def edge(self):
        e = {}
        serial = self.g("serial", 6)
        e["serial"] = "".join(chr(c + 64) if c < 27 else chr(c) for c in serial)
        e["odd"] = int(e["serial"][-1]) % 2 == 1
        e["vowel"] = any(c in "AEIOU" for c in e["serial"])
        e["bat"] = self.g("batteries")
        ports = self.g("ports")
        e["par"] = bool(ports & 1)
        n = self.g("ind_count")
        labels = self.g("ind_label", 3)
        lit = self.g("ind_lit", 3)
        names = ["CAR", "FRK", "SIG", "NSA", "BOB", "MSA", "TRN"]
        e["lit"] = {names[labels[k]] for k in range(n) if lit[k]}
        return e

    def strikes(self):
        return self.g("strikes")

    # ------------------------------------------------------------ navigation
    def goto(self, i):
        slot = self.g("m_slot", 1, i)
        side = self.g("side")
        if slot // 6 != side:
            self.tap(B_FLIP)
            time.sleep(0.6)             # let the turn animation finish
        cur = self.g("cursor")
        pos = slot % 6
        while cur // 3 != pos // 3:
            self.tap(B_DOWN if pos > cur else B_UP)
            cur = self.g("cursor")
        while cur != pos:
            self.tap(B_RIGHT if pos > cur else B_LEFT)
            cur = self.g("cursor")
        self.tap(B_FIRE)
        assert self.g("mode") == 1, "did not enter module"

    def leave(self):
        if self.g("mode") == 1:
            self.tap(B_BACK)

    # ------------------------------------------------------------ module solvers (manual rules)
    def wires(self, i, e):
        d = self.md(i)
        n, cols = d[0], d[1:1 + d[0]]
        c = lambda col: cols.count(col)
        last = lambda col: max(k for k in range(n) if cols[k] == col)
        first = lambda col: min(k for k in range(n) if cols[k] == col)
        if n == 3:
            if c(BLUE) == 0: a = 1
            elif cols[0] == WHITE: a = 2
            elif c(RED) == 1: a = first(RED)
            else: a = 0
        elif n == 4:
            if c(YELLOW) > 1 and not e["odd"]: a = last(YELLOW)
            elif cols[3] == BLACK and c(RED) == 0: a = 0
            elif c(BLUE) == 1: a = 3
            elif c(WHITE) > 1: a = first(WHITE)
            else: a = 1
        elif n == 5:
            if cols[4] == RED and e["odd"]: a = 3
            elif c(BLACK) == 0: a = 0
            elif c(YELLOW) == 1 and c(WHITE) > 1: a = 2
            elif e["bat"] > 2: a = 4
            else: a = 1
        else:
            if c(WHITE) == 0 and e["odd"]: a = 2
            elif c(RED) == 1 and c(BLUE) > 1: a = last(BLUE)
            elif c(YELLOW) == 0: a = 5
            elif "FRK" in e["lit"]: a = 0
            else: a = 3
        self.log.append("wires %s -> cut %d" % ("".join("RBYWK"[x] for x in cols), a + 1))
        self.tap(B_DOWN, a)
        self.tap(B_FIRE)

    def button(self, i, e):
        d = self.md(i)
        color, label = d[0], d[1]   # color 0 red 1 blue 2 yellow 3 white; label 0 abort 1 detonate 2 hold 3 press
        if label == 3 and color == 0: hold = False
        elif color == 1 and e["bat"] >= 2: hold = True
        elif label == 0 and "SIG" in e["lit"]: hold = False
        elif color == 3 and e["vowel"]: hold = True
        elif label == 2: hold = False
        elif color == 2 and e["bat"] == 0: hold = False
        else: hold = True
        self.log.append("button c%d l%d -> %s" % (color, label, "hold" if hold else "tap"))
        if not hold:
            self.v.press(B_FIRE, 3, 0.2)
            return
        self.v.poke("inject", B_FIRE, 255)
        time.sleep(1.0)
        strip = self.md(i)[5]
        digit = {0: 2, 1: 4, 2: 5, 3: 1}[strip]
        while True:
            m, s = self.g("tmin"), self.g("tsec")
            digits = "%02x%02x" % (m, s)
            if str(digit) in digits:
                self.v.poke("inject", 0, 0)
                break
            self.v.poke("inject", B_FIRE, 255)
            time.sleep(0.1)
        time.sleep(0.3)

    def keypad(self, i, e):
        d = self.md(i)
        syms = d[0:4]
        col = [c for c in gen.COLUMNS if all(s in c for s in syms)]
        assert len(col) == 1, "keypad: %d matching columns" % len(col)
        order = sorted(range(4), key=lambda k: col[0].index(syms[k]))
        cur = 0
        for k in order:
            if (k >> 1) != (cur >> 1): self.tap(B_DOWN if k > cur else B_UP)
            if (k & 1) != (cur & 1): self.tap(B_RIGHT if k & 1 else B_LEFT)
            cur = k
            self.tap(B_FIRE)
        self.log.append("keypad ok")

    SIMON = {  # (vowel, strikes) -> flash colour -> press, from the manual tables
        (True, 0): {"R": "B", "B": "Y", "G": "R", "Y": "G"},
        (True, 1): {"R": "Y", "B": "G", "G": "B", "Y": "R"},
        (True, 2): {"R": "G", "B": "R", "G": "Y", "Y": "B"},
        (False, 0): {"R": "Y", "B": "R", "G": "G", "Y": "B"},
        (False, 1): {"R": "R", "B": "B", "G": "Y", "Y": "G"},
        (False, 2): {"R": "B", "B": "G", "G": "R", "Y": "Y"},
    }
    def simon(self, i, e):
        names = "RBGY"
        press_dir = {"B": B_UP, "R": B_DOWN, "Y": B_LEFT, "G": B_RIGHT}
        while not self.g("m_solved", 1, i):
            d = self.md(i)
            tot, seq, stage = d[0], d[1:6], d[6]
            table = self.SIMON[(e["vowel"], min(self.strikes(), 2))]
            for k in range(stage + 1):
                want = table[names[seq[k]]]
                self.tap(press_dir[want])
                self.tap(B_FIRE)
        self.log.append("simon ok")

    MEM = [  # stage -> display -> rule, from the manual table
        [("pos", 3), ("pos", 1), ("lab", 4), ("pos", 2)],
        [("lab", 2), ("spos", 1), ("pos", 4), ("slab", 1)],
        [("slab", 2), ("pos", 1), ("lab", 1), ("spos", 1)],
        [("pos", 4), ("slab", 1), ("spos", 2), ("lab", 3)],
        [("slab", 3), ("slab", 4), ("slab", 2), ("spos", 4)],
    ]
    def memory(self, i, e):
        hist = []
        cur = 0
        for stage in range(5):
            d = self.md(i)
            disp, labs = d[1], d[2:6]
            kind, arg = self.MEM[stage][disp - 1]
            if kind == "pos": p = arg - 1
            elif kind == "lab": p = labs.index(arg)
            elif kind == "spos": p = hist[arg - 1][0]
            else: p = labs.index(hist[arg - 1][1])
            hist.append((p, labs[p]))
            self.tap(B_RIGHT if p > cur else B_LEFT, abs(p - cur))
            cur = p
            self.tap(B_FIRE)
        self.log.append("memory ok")

    def maze(self, i, e):
        d = self.md(i)
        mid, x, y, gx, gy = d[0:5]
        east, south, m1, m2 = gen.MAZES[mid]
        def nb(p):
            px, py = p
            if px < 5 and not east[py][px]: yield (px + 1, py), "R"
            if px > 0 and not east[py][px - 1]: yield (px - 1, py), "L"
            if py < 5 and not south[py][px]: yield (px, py + 1), "D"
            if py > 0 and not south[py - 1][px]: yield (px, py - 1), "U"
        prev = {(x, y): None}
        q = deque([(x, y)])
        while q:
            p = q.popleft()
            for n2, mv in nb(p):
                if n2 not in prev:
                    prev[n2] = (p, mv); q.append(n2)
        path, p = [], (gx, gy)
        while prev[p]:
            p, mv = prev[p]
            path.append(mv)
        for mv in reversed(path):
            self.tap(DIR[mv])
        self.log.append("maze %d: %d moves" % (mid, len(path)))

    def password(self, i, e):
        d = self.md(i)
        cols = [[chr(64 + c) for c in d[k * 6:k * 6 + 6]] for k in range(5)]
        idx = d[30:35]
        fits = [w for w in gen.PASSWORDS if all(w[k] in cols[k] for k in range(5))]
        assert len(fits) == 1, "password: %s" % fits
        w = fits[0]
        for k in range(5):
            target = cols[k].index(w[k])
            steps = (target - idx[k]) % 6
            self.tap(B_DOWN, steps)
            if k < 4: self.tap(B_RIGHT)
        self.tap(B_FIRE)
        self.log.append("password " + w)

    def morse(self, i, e):
        d = self.md(i)
        word = d[0]
        self.tap(B_RIGHT, word)
        self.tap(B_FIRE)
        self.log.append("morse " + gen.MORSE_WORDS[word][0])

    CW = "CDCBSPDPSBCBSSPD"  # manual table, rows red/blue/star/light
    def cwires(self, i, e):
        d = self.md(i)
        n, attrs = d[0], d[1:1 + d[0]]
        cur = 0
        for k, a in enumerate(attrs):
            red, blue, star, led = a >> 3 & 1, a >> 2 & 1, a >> 1 & 1, a & 1
            L = self.CW[red * 8 + blue * 4 + star * 2 + led]
            cut = L == "C" or (L == "S" and not e["odd"]) or (L == "P" and e["par"]) or (L == "B" and e["bat"] >= 2)
            if cut:
                self.tap(B_RIGHT, k - cur); cur = k
                self.tap(B_FIRE)
                if self.g("m_solved", 1, i):
                    break
        self.log.append("cwires ok")

    def vent(self, i, e):
        d = self.md(i)
        if not d[0]:
            return
        self.tap(B_LEFT if d[1] == 0 else B_RIGHT)
        self.tap(B_FIRE)
        self.log.append("vent answered")

    SOLVERS = ["wires", "button", "keypad", "simon", "memory", "maze", "password", "morse", "cwires"]

    def service_needy(self, e):
        n = self.g("nmods")
        types = self.g("m_type", n) if n > 1 else [self.g("m_type")]
        for i, t in enumerate(types):
            if t == 9 and self.md(i)[0]:
                self.goto(i); self.vent(i, e); self.leave()

    def play(self):
        e = self.edge()
        n = self.g("nmods")
        types = self.g("m_type", n) if n > 1 else [self.g("m_type")]
        self.log.append("bomb %s bat %d par %s lit %s modules %s" % (
            e["serial"], e["bat"], e["par"], sorted(e["lit"]), [gen.MODNAMES[t] for t in types]))
        for i, t in enumerate(types):
            if t == 9:
                continue
            self.service_needy(e)
            self.goto(i)
            getattr(self, self.SOLVERS[t])(i, e)
            time.sleep(0.2)
            if not self.g("m_solved", 1, i):
                self.log.append("!! module %d (%s) not solved" % (i, gen.MODNAMES[t]))
                self.leave()
            if self.g("game_state"):
                break

def run(levels):
    v = Vice()
    results = []
    try:
        v.wait(4)
        v.press(B_FIRE)                      # title -> intro
        for L in levels:
            v.wait(0.4)
            v.poke("level", L - 1)
            v.press(B_FIRE)                  # intro -> play
            v.wait(0.8)
            v.shot("start%03d" % L)
            b = Bot(v)
            b.play()
            v.wait(1.5)
            gs, st = b.g("game_state"), b.strikes()
            ok = gs == 2 and st == 0
            v.shot("level%03d" % L)
            results.append((L, ok, gs, st))
            print("LEVEL %d: %s (state %d, strikes %d)" % (L, "PASS" if ok else "FAIL", gs, st))
            for line in b.log:
                print("   ", line)
            sys.stdout.flush()
            if gs == 0:                      # still running: wait for it to blow
                while b.g("game_state") == 0:
                    v.wait(2)
                v.wait(2)
            v.press(B_FIRE)                  # result screen -> next intro
    finally:
        v.quit()
    return results

if __name__ == "__main__":
    run([int(a) for a in sys.argv[1:]] or [1])
