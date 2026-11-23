// ---------------------------------------------------------------- memory
.const SCREEN  = $c000          // VIC bank 3
.const CHARSET = $c800
.const COLRAM  = $d800
.const COLOFS  = $18            // COLRAM - SCREEN, high byte
.const NEW_SCR = $8000          // off-screen face being built
.const NEW_COL = $8400
.const OLD_SCR = $8800          // copy of the face being turned away from
.const OLD_COL = $8c00

// ---------------------------------------------------------------- colours
.const BLACK = 0
.const WHITE = 1
.const RED = 2
.const CYAN = 3
.const PURPLE = 4
.const GREEN = 5
.const BLUE = 6
.const YELLOW = 7
.const ORANGE = 8
.const BROWN = 9
.const LRED = 10
.const DGREY = 11
.const GREY = 12
.const LGREEN = 13
.const LBLUE = 14
.const LGREY = 15

// ---------------------------------------------------------------- input bits
.const B_UP = 1
.const B_DOWN = 2
.const B_LEFT = 4
.const B_RIGHT = 8
.const B_FIRE = 16
.const B_BACK = 32
.const B_FLIP = 64

// module events
.const EV_UP = 0
.const EV_DOWN = 1
.const EV_LEFT = 2
.const EV_RIGHT = 3
.const EV_FIRE = 4
.const EV_RELEASE = 5
.const EV_LEAVE = 6

// module functions
.const FN_GEN = 0
.const FN_DRAW = 1
.const FN_INPUT = 2
.const FN_UPDATE = 3

// module types
.const T_WIRES = 0
.const T_BUTTON = 1
.const T_KEYPAD = 2
.const T_SIMON = 3
.const T_MEMORY = 4
.const T_MAZE = 5
.const T_PASSWORD = 6
.const T_MORSE = 7
.const T_CWIRES = 8
.const T_VENT = 9

.const MAXMODS = 12
.const MDSIZE = 48              // bytes of state per module

// sound effects
.const SFX_TICK = 0
.const SFX_STRIKE = 1
.const SFX_CUT = 2
.const SFX_BEEP = 3
.const SFX_SOLVE = 4
.const SFX_BOOM = 5
.const SFX_SIMON = 6            // 6..9 = red, blue, green, yellow
.const SFX_WIN = 10
.const SFX_ALERT = 11
.const SFX_CLICK = 12
.const SFX_TICK2 = 13
.const SFX_TURN = 14

// bomb faces
.const F_FRONT = 0
.const F_BACK = 1
.const F_LEFT = 2
.const F_RIGHT = 3
.const F_TOP = 4
.const F_BOTTOM = 5
.const D_UP = 0
.const D_DOWN = 1
.const D_LEFT = 2
.const D_RIGHT = 3

// ---------------------------------------------------------------- zero page
.label ptr1 = $10
.label ptr2 = $12
.label ptr3 = $14
.label ptr4 = $16               // reserved for call_mod
.label pcol = $18
.label px0 = $19
.label py0 = $1a
.label rvs = $1b
.label rng = $1c                // 2 bytes
.label frame = $1e
.label tmp0 = $20
.label tmp1 = $21
.label tmp2 = $22
.label tmp3 = $23
.label tmp4 = $24
.label tmp5 = $25
.label tmp6 = $26
.label tmp7 = $27
.label pl_c = $28
.label pl_x = $29
.label pl_y = $2a
.label rn_n = $2b
.label rn_r = $2c
.label rn_x = $2d
.label scr_adj = $2e            // render target: screen high-byte adjustment
.label colofs = $2f             // render target: colour RAM - screen, high byte
