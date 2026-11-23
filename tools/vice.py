"""Tiny VICE remote-monitor driver used for testing DEFUSE 64.

    v = Vice(); v.wait(3); v.press(B_FIRE); v.shot("title")
"""
import os, re, socket, subprocess, time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
B_UP, B_DOWN, B_LEFT, B_RIGHT, B_FIRE, B_BACK, B_FLIP = 1, 2, 4, 8, 16, 32, 64

def symbols():
    syms = {}
    for line in open(os.path.join(ROOT, "build", "main.sym")):
        m = re.match(r"\s*\.label\s+(\w+)=\$([0-9a-fA-F]+)", line)
        if m:
            syms[m.group(1)] = int(m.group(2), 16)
    return syms

class Vice:
    def __init__(self, prg="build/defuse64.prg", port=6510, warp=False):
        self.sym = symbols()
        args = ["x64sc", "-remotemonitor", "-remotemonitoraddress", "127.0.0.1:%d" % port,
                "-sounddev", "dummy", "-logfile", os.path.join(ROOT, "build", "vice.log"), "-autostart", os.path.join(ROOT, prg)]
        if warp:
            args.insert(1, "-warp")
        self.proc = subprocess.Popen(args, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        for _ in range(100):
            try:
                self.s = socket.create_connection(("127.0.0.1", port), timeout=5)
                break
            except OSError:
                time.sleep(0.2)
        self.s.settimeout(5)

    def cmd(self, c):
        self.s.sendall((c + "\n").encode())
        buf = b""
        deadline = time.time() + 10
        while time.time() < deadline:
            self.s.settimeout(0.2)
            try:
                chunk = self.s.recv(65536)
            except socket.timeout:
                if re.search(rb"\(C:\$[0-9a-f]{4}\) $", buf):
                    break
                continue
            if not chunk:
                break
            buf += chunk
        return buf.decode(errors="replace")

    def go(self):
        self.s.sendall(b"x\n")
        time.sleep(0.05)

    def wait(self, sec):
        time.sleep(sec)

    def peek(self, addr, n=1):
        if isinstance(addr, str):
            addr = self.sym[addr]
        out = self.cmd("m %04x %04x" % (addr, addr + n - 1))
        self.go()
        vals = []
        for line in out.splitlines():
            k = line.find(">C:")
            if k >= 0:
                line = line[k:]
                n_line = 0
                for t in line[8:].split():
                    if len(t) != 2 or any(ch not in "0123456789abcdef" for ch in t) or n_line == 16:
                        break
                    vals.append(int(t, 16)); n_line += 1
        return vals[:n]

    def poke(self, addr, *vals):
        if isinstance(addr, str):
            addr = self.sym[addr]
        self.cmd("> %04x %s" % (addr, " ".join("%02x" % v for v in vals)))
        self.go()

    def press(self, btn, frames=4, after=0.25):
        # writes inject then inject_frames (adjacent bytes)
        self.poke("inject", btn, frames)
        time.sleep(frames / 50.0)
        for _ in range(50):             # wait until the game has consumed it
            if self.peek("inject_frames")[0] == 0:
                break
            time.sleep(0.05)
        time.sleep(after)

    def shot(self, name):
        path = os.path.join(ROOT, "build", "shots", name + ".png")
        os.makedirs(os.path.dirname(path), exist_ok=True)
        if os.path.exists(path):
            os.remove(path)
        self.cmd('screenshot "%s" 2' % path.replace("\\", "/"))
        self.go()
        time.sleep(0.3)
        return path

    def screen_text(self):
        raw = self.peek(0xc000, 1000)
        out = []
        for r in range(25):
            line = ""
            for c in raw[r * 40:(r + 1) * 40]:
                c &= 0x7f
                if 1 <= c <= 26: line += chr(c + 64)
                elif 0x20 <= c <= 0x3f: line += chr(c)
                elif c == 0: line += "@"
                else: line += "."
            out.append(line)
        return "\n".join(out)

    def quit(self):
        try:
            self.cmd("quit")
        except Exception:
            pass
        time.sleep(0.5)
        self.proc.kill()
