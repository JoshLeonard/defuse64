.encoding "screencode_upper"
// Module code works on the copy of its state in W.  px0/py0 point at the
// panel, `infocus` is set while the defuser is working on it, and
// `needdraw` (via Redraw) asks the framework to repaint the panel.

.macro Redraw() {
    lda needdraw
    ora #1
    sta needdraw
}

// ================================================================ WIRES
.label wN   = W + 0
.label wCol = W + 1     // 6 colours: 0 red, 1 blue, 2 yellow, 3 white, 4 black
.label wCut = W + 7     // 6 flags
.label wCur = W + 13
.label wAns = W + 14
.const C_RED = 0
.const C_BLU = 1
.const C_YEL = 2
.const C_WHT = 3
.const C_BLK = 4

wires_gen: {
    ldx tier
    lda wire_span, x
    jsr randn
    clc
    adc wire_base, x
    sta wN
    ldx #0
!:  lda #5
    jsr randn
    sta wCol, x
    lda #0
    sta wCut, x
    inx
    cpx #6
    bne !-
    lda #0
    sta wCur
    jmp wires_solve
}
wire_base: .byte 3, 3, 4, 5
wire_span: .byte 2, 3, 3, 2

// A = colour -> A = number of wires with it
wcount: {
    sta tmp0
    ldx #0
    ldy #0
loop:
    cpx wN
    beq done
    lda wCol, x
    cmp tmp0
    bne !+
    iny
!:  inx
    bne loop
done:
    tya
    rts
}

// A = colour -> A = index of last wire with it
wlast: {
    sta tmp0
    ldx wN
!:  dex
    lda wCol, x
    cmp tmp0
    bne !-
    txa
    rts
}

// A = colour -> A = index of first wire with it
wfirst: {
    sta tmp0
    ldx #$ff
!:  inx
    lda wCol, x
    cmp tmp0
    bne !-
    txa
    rts
}

wires_solve: {
    lda wN
    cmp #3
    beq w3
    cmp #4
    beq w4
    cmp #5
    bne !+
    jmp w5
!:  jmp w6
w3:
    lda #C_BLU
    jsr wcount
    bne !+
    lda #1
    jmp set
!:  lda wCol
    cmp #C_WHT
    bne !+
    lda #2
    jmp set
!:  lda #C_RED
    jsr wcount
    cmp #1
    bne !+
    lda #C_RED
    jsr wfirst
    jmp set
!:  lda #0
    jmp set
w4:
    lda #C_YEL
    jsr wcount
    cmp #2
    bcc !+
    lda serial_odd
    bne !+
    lda #C_YEL
    jsr wlast
    jmp set
!:  lda wCol + 3
    cmp #C_BLK
    bne !+
    lda #C_RED
    jsr wcount
    bne !+
    lda #0
    jmp set
!:  lda #C_BLU
    jsr wcount
    cmp #1
    bne !+
    lda #3
    jmp set
!:  lda #C_WHT
    jsr wcount
    cmp #2
    bcc !+
    lda #C_WHT
    jsr wfirst
    jmp set
!:  lda #1
    jmp set
w5:
    lda wCol + 4
    cmp #C_RED
    bne !+
    lda serial_odd
    beq !+
    lda #3
    jmp set
!:  lda #C_BLK
    jsr wcount
    bne !+
    lda #0
    jmp set
!:  lda #C_YEL
    jsr wcount
    cmp #1
    bne !+
    lda #C_WHT
    jsr wcount
    cmp #2
    bcc !+
    lda #2
    jmp set
!:  lda batteries
    cmp #3
    bcc !+
    lda #4
    jmp set
!:  lda #1
    jmp set
w6:
    lda #C_WHT
    jsr wcount
    bne !+
    lda serial_odd
    beq !+
    lda #2
    jmp set
!:  lda #C_RED
    jsr wcount
    cmp #1
    bne !+
    lda #C_BLU
    jsr wcount
    cmp #2
    bcc !+
    lda #C_BLU
    jsr wlast
    jmp set
!:  lda #C_YEL
    jsr wcount
    bne !+
    lda #5
    jmp set
!:  lda lit_frk
    beq !+
    lda #0
    jmp set
!:  lda #3
set:
    sta wAns
    rts
}

wires_draw: {
    ldx wN
    lda wire_y0 - 3, x
    sta tmp5                // row of first wire
    ldx #0
loop:
    stx tmp4
    ldy tmp5
    // cursor
    lda #WHITE
    sta pcol
    lda #$20
    ldx infocus
    beq !+
    ldx tmp4
    cpx wCur
    bne !+
    lda #$3e                // >
!:  ldx #1
    jsr pplot
    // colour letter
    ldx tmp4
    lda wCol, x
    tax
    lda wire_letter, x
    pha
    lda wire_c64, x
    sta tmp6
    lda #LGREY
    sta pcol
    pla
    ldx #2
    jsr pplot
    lda #GREY
    sta pcol
    lda #$7d
    ldx #3
    jsr pplot
    ldx #11
    jsr pplot
    lda tmp6
    sta pcol
    ldx #4
!:  lda #$7c
    jsr pplot
    inx
    cpx #11
    bne !-
    ldx tmp4
    lda wCut, x
    beq !+
    lda #$20
    ldx #7
    jsr pplot
!:  inc tmp5
    ldx tmp4
    inx
    cpx wN
    bne loop
    rts
}
wire_y0:     .byte 3, 3, 2, 2
wire_letter: .text "RBYWK"
wire_c64:    .byte RED, LBLUE, YELLOW, WHITE, BLACK

wires_input: {
    cmp #EV_UP
    bne !+
    lda wCur
    beq done
    dec wCur
    Redraw()
    rts
!:  cmp #EV_DOWN
    bne !+
    ldx wCur
    inx
    cpx wN
    bcs done
    stx wCur
    Redraw()
    rts
!:  cmp #EV_FIRE
    bne done
    ldx wCur
    lda wCut, x
    bne done
    lda #1
    sta wCut, x
    Redraw()
    Sfx(SFX_CUT)
    lda wCur
    cmp wAns
    bne !+
    jmp mod_solve
!:  jmp do_strike
done:
    rts
}

// ================================================================ THE BUTTON
.label bColor   = W + 0     // 0 red, 1 blue, 2 yellow, 3 white
.label bLabel   = W + 1     // 0 abort, 1 detonate, 2 hold, 3 press
.label bHold    = W + 2     // 1 = must be held
.label bPressed = W + 3
.label bFrames  = W + 4
.label bStrip   = W + 5     // $ff = off
.label bDigit   = W + 6
.const HOLDT = 30

button_gen: {
    lda #4
    jsr randn
    sta bColor
    lda #4
    jsr randn
    sta bLabel
    lda #0
    sta bPressed
    lda #$ff
    sta bStrip
    // rule 1: red + PRESS -> tap
    lda bLabel
    cmp #3
    bne !+
    lda bColor
    beq tap
    // rule 2: blue + 2 or more batteries -> hold
!:  lda bColor
    cmp #1
    bne !+
    lda batteries
    cmp #2
    bcs hold
    // rule 3: ABORT + lit SIG -> tap
!:  lda bLabel
    bne !+
    lda lit_sig
    bne tap
    // rule 4: white + vowel -> hold
!:  lda bColor
    cmp #3
    bne !+
    lda has_vowel
    bne hold
    // rule 5: HOLD -> tap
!:  lda bLabel
    cmp #2
    beq tap
    // rule 6: yellow + no batteries -> tap
    lda bColor
    cmp #2
    bne hold
    lda batteries
    beq tap
hold:
    lda #1
    sta bHold
    rts
tap:
    lda #0
    sta bHold
    rts
}

button_draw: {
    ldx bColor
    lda btn_c64, x
    sta pcol
    ldy #2
    lda bPressed
    beq !+
    iny                     // pressed: button looks pushed in
!:  sty tmp5
    lda #4
    sec
    sbc bPressed
    sbc bPressed
    sta tmp6                // rows
rows:
    ldx #1
!:  lda #$a0
    ldy tmp5
    jsr pplot
    inx
    cpx #10
    bne !-
    inc tmp5
    dec tmp6
    bne rows
    // label
    ldx bLabel
    lda lbl_ofs, x
    tay
    lda lbl_x, x
    tax
    lda #WHITE
    sta pcol
!:  lda lbl_text, y
    cmp #$ff
    beq strip
    sty tmp4
    ldy #4
    jsr pplot
    ldy tmp4
    iny
    inx
    bne !-
strip:
    lda bStrip
    bmi off
    tax
    lda btn_c64, x
    sta pcol
    lda #$a0
    bne put
off:
    lda #BLACK
    sta pcol
    lda #$5d
put:
    ldx #11
    ldy #1
!:  jsr pplot
    iny
    cpy #9
    bne !-
    rts
}
btn_c64:  .byte RED, LBLUE, YELLOW, WHITE
lbl_text: .text "ABORT"
          .byte $ff
          .text "DETONATE"
          .byte $ff
          .text "HOLD"
          .byte $ff
          .text "PRESS"
          .byte $ff
lbl_ofs:  .byte 0, 6, 15, 20
lbl_x:    .byte 3, 1, 3, 3
strip_digit: .byte 2, 4, 5, 1

button_input: {
    cmp #EV_FIRE
    bne !+
    lda #1
    sta bPressed
    lda #0
    sta bFrames
    Redraw()
    Sfx(SFX_BEEP)
    rts
!:  cmp #EV_LEAVE
    bne !+
    lda #0
    sta bPressed
    lda #$ff
    sta bStrip
    Redraw()
    rts
!:  cmp #EV_RELEASE
    bne done
    lda bPressed
    beq done
    lda #0
    sta bPressed
    lda #$ff
    sta bStrip
    Redraw()
    lda bFrames
    cmp #HOLDT
    bcs held
    lda bHold               // tapped
    bne bad
good:
    jmp mod_solve
held:
    lda bHold
    beq bad
    lda bDigit
    jsr timer_has_digit
    bcs good
bad:
    jmp do_strike
done:
    rts
}

button_update: {
    lda bPressed
    beq done
    lda bFrames
    cmp #255
    beq done
    inc bFrames
    lda bFrames
    cmp #HOLDT
    bne done
    lda #4
    jsr randn
    sta bStrip
    tax
    lda strip_digit, x
    sta bDigit
    Redraw()
done:
    rts
}

// A = digit.  Carry set if the timer currently shows it.
timer_has_digit: {
    sta tmp0
    lda tmin
    jsr two
    bcs yes
    lda tsec
two:
    pha
    and #$0f
    cmp tmp0
    beq hit
    pla
    lsr
    lsr
    lsr
    lsr
    cmp tmp0
    beq yes
    clc
    rts
hit:
    pla
yes:
    sec
    rts
}

// ================================================================ KEYPAD
.label kSym  = W + 0    // 4 symbols
.label kRank = W + 4    // 4 press order
.label kCur  = W + 8
.label kNext = W + 9
.label kDone = W + 10   // 4 flags
.label kPos  = W + 14   // 4 positions in column (temp)

keypad_gen: {
    lda #6
    jsr randn
    sta tmp0
    asl
    asl
    asl
    sec
    sbc tmp0
    sta tmp1                // column * 7
    ldx #0
    stx tmp2
pick:
    lda #7
    jsr randn
    ldy #0
!:  cpy tmp2
    beq ok
    cmp kPos, y
    beq pick
    iny
    bne !-
ok: sta kPos, x
    inx
    stx tmp2
    cpx #4
    bne pick
    ldx #3
sym:
    lda kPos, x
    clc
    adc tmp1
    tay
    lda keypad_cols, y
    sta kSym, x
    // rank = how many chosen positions are smaller
    lda #0
    sta tmp3
    ldy #3
!:  lda kPos, y
    cmp kPos, x
    bcs !+
    inc tmp3
!:  dey
    bpl !--
    lda tmp3
    sta kRank, x
    lda #0
    sta kDone, x
    dex
    bpl sym
    lda #0
    sta kCur
    sta kNext
    rts
}

keypad_draw: {
    ldx #0
key:
    stx tmp4
    lda key_x, x
    sta tmp5
    lda key_y, x
    sta tmp6
    lda #GREY
    ldy kDone, x
    beq !+
    lda #LGREEN
    bne set
!:  ldy infocus
    beq set
    cpx kCur
    bne set
    lda #YELLOW
set:
    sta pcol
    ldx tmp5
    ldy tmp6
    lda #$55
    jsr pplot
    inx
    lda #$40
    jsr pplot
    inx
    lda #$49
    jsr pplot
    iny
    lda #$5d
    jsr pplot
    ldx tmp5
    jsr pplot
    iny
    lda #$4a
    jsr pplot
    inx
    lda #$40
    jsr pplot
    inx
    lda #$4b
    jsr pplot
    lda #WHITE
    sta pcol
    ldx tmp4
    lda kSym, x
    clc
    adc #SYMBASE
    ldx tmp5
    inx
    ldy tmp6
    iny
    jsr pplot
    ldx tmp4
    inx
    cpx #4
    bne key
    rts
}
key_x: .byte 3, 7, 3, 7
key_y: .byte 1, 1, 5, 5

keypad_input: {
    cmp #EV_UP
    bne !+
    lda kCur
    and #1
    sta kCur
    Redraw()
    rts
!:  cmp #EV_DOWN
    bne !+
    lda kCur
    ora #2
    sta kCur
    Redraw()
    rts
!:  cmp #EV_LEFT
    bne !+
    lda kCur
    and #2
    sta kCur
    Redraw()
    rts
!:  cmp #EV_RIGHT
    bne !+
    lda kCur
    ora #1
    sta kCur
    Redraw()
    rts
!:  cmp #EV_FIRE
    bne done
    ldx kCur
    lda kDone, x
    bne done
    lda kRank, x
    cmp kNext
    beq !+
    jmp do_strike
!:  lda #1
    sta kDone, x
    inc kNext
    Redraw()
    Sfx(SFX_BEEP)
    lda kNext
    cmp #4
    bne done
    jmp mod_solve
done:
    rts
}

// ================================================================ SIMON SAYS
.label sTot   = W + 0
.label sSeq   = W + 1   // 5 colours: 0 red, 1 blue, 2 green, 3 yellow
.label sStage = W + 6   // sequence length - 1
.label sPos   = W + 7
.label sCur   = W + 8
.label sLit   = W + 9   // $ff = none
.label sLitT  = W + 10
.label sPlay  = W + 11
.label sPbIdx = W + 12
.label sPbT   = W + 13
.label sPbOn  = W + 14
.label sWait  = W + 15

simon_gen: {
    ldx tier
    lda simon_span, x
    jsr randn
    clc
    adc simon_base, x
    sta sTot
    ldx #4
!:  lda #4
    jsr randn
    sta sSeq, x
    dex
    bpl !-
    lda #0
    sta sStage
    sta sPos
    sta sPlay
    sta sLitT
    lda #1
    sta sCur
    lda #$ff
    sta sLit
    lda #60
    sta sWait
    rts
}
simon_base: .byte 3, 3, 4, 5
simon_span: .byte 1, 2, 2, 1

// A = colour: light it and play its tone when on screen
simon_flash: {
    sta sLit
    tax
    Redraw()
    lda visible
    beq !+
    txa
    clc
    adc #SFX_SIMON
    tax
    jsr play_sfx
!:  rts
}

simon_update: {
    lda sLitT
    beq play
    dec sLitT
    bne play
    lda #$ff
    sta sLit
    Redraw()
play:
    lda sPlay
    beq waiting
    dec sPbT
    bne done
    lda sPbOn
    beq next
    lda #0
    sta sPbOn
    lda #$ff
    sta sLit
    lda #10
    sta sPbT
    Redraw()
    rts
next:
    inc sPbIdx
    lda sPbIdx
    cmp sStage
    beq more
    bcc more
    lda #0
    sta sPlay
    lda #100
    sta sWait
    rts
more:
    ldx sPbIdx
    jmp start_flash
waiting:
    lda sWait
    beq done
    dec sWait
    bne done
    lda #1
    sta sPlay
    ldx #0
    stx sPbIdx
start_flash:
    lda #1
    sta sPbOn
    lda #18
    sta sPbT
    lda sSeq, x
    jmp simon_flash
done:
    rts
}

simon_input: {
    cmp #EV_FIRE
    beq press
    cmp #EV_RELEASE
    bcs done
    tax
    lda dir_color, x
    sta sCur
    Redraw()
done:
    rts
press:
    lda #0
    sta sPlay
    lda #12
    sta sLitT
    lda sCur
    jsr simon_flash
    // expected colour for the current flash
    ldx sPos
    lda sSeq, x
    sta tmp0
    lda strikes
    cmp #3
    bcc !+
    lda #2
!:  asl
    asl
    adc tmp0
    ldx has_vowel
    beq !+
    clc
    adc #12
!:  tax
    lda simon_map, x
    cmp sCur
    bne wrong
    inc sPos
    lda sPos
    cmp sStage
    beq ok
    bcc ok
    lda #0
    sta sPos
    inc sStage
    lda sStage
    cmp sTot
    bne next
    lda #$ff
    sta sLit
    lda #0
    sta sLitT
    jmp mod_solve
next:
    lda #45
    sta sWait
    rts
ok:
    lda #150
    sta sWait
    rts
wrong:
    lda #0
    sta sPos
    lda #70
    sta sWait
    jmp do_strike
}
// up, down, left, right -> blue, red, yellow, green
dir_color: .byte 1, 0, 3, 2
// [vowel][strikes][flash] -> colour to press
simon_map:
    .byte 3, 0, 2, 1,  0, 1, 3, 2,  1, 2, 0, 3     // no vowel
    .byte 1, 3, 0, 2,  3, 2, 1, 0,  2, 0, 3, 1     // vowel

simon_draw: {
    ldx #3
btn:
    stx tmp4
    lda sim_dim, x
    cpx sLit
    bne !+
    lda sim_lit, x
!:  sta pcol
    lda sim_x, x
    sta tmp5
    lda sim_y, x
    tay
    ldx tmp5
    jsr row3
    iny
    jsr row3
    // selection marker
    lda infocus
    beq !+
    lda tmp4
    cmp sCur
    bne !+
    ldx tmp5
    inx
    dey
    lda #$d1                // reversed ball
    jsr pplot
!:  ldx tmp4
    dex
    bpl btn
    rts
row3:
    ldx tmp5
    lda #$a0
    jsr pplot
    inx
    jsr pplot
    inx
    jmp pplot
}
sim_x:   .byte 5, 5, 9, 1
sim_y:   .byte 7, 1, 4, 4
sim_dim: .byte RED, BLUE, GREEN, BROWN
sim_lit: .byte LRED, LBLUE, LGREEN, YELLOW

// ================================================================ MEMORY
.label mStage = W + 0
.label mDisp  = W + 1
.label mLab   = W + 2   // 4 labels by position
.label mPos   = W + 6   // 5 pressed positions
.label mLbl   = W + 11  // 5 pressed labels
.label mCur   = W + 16

memory_gen: {
    lda #0
    sta mStage
    sta mCur
}
mem_new: {
    lda #4
    jsr randn
    clc
    adc #1
    sta mDisp
    ldx #3
!:  txa
    clc
    adc #1
    sta mLab, x
    dex
    bpl !-
    ldx #3                  // shuffle
shuf:
    txa
    clc
    adc #1
    jsr randn
    tay
    lda mLab, x
    pha
    lda mLab, y
    sta mLab, x
    pla
    sta mLab, y
    dex
    bne shuf
    rts
}

// returns X = position that must be pressed now
mem_expect: {
    lda mStage
    asl
    asl
    clc
    adc mDisp
    sec
    sbc #1
    asl
    tax
    lda mem_rules + 1, x
    sta tmp0                // argument
    lda mem_rules, x
    beq pos
    cmp #1
    beq label
    cmp #2
    beq pos_of
    ldx tmp0                // 3: label pressed in stage n
    lda mLbl - 1, x
    sta tmp0
label:
    ldx #3
!:  lda mLab, x
    cmp tmp0
    beq !+
    dex
    bne !-
!:  rts
pos:
    ldx tmp0
    dex
    rts
pos_of:
    ldx tmp0
    lda mPos - 1, x
    tax
    rts
}
// type, arg: 0 position n, 1 label n, 2 position of stage n, 3 label of stage n
mem_rules:
    .byte 0,3, 0,1, 1,4, 0,2
    .byte 1,2, 2,1, 0,4, 3,1
    .byte 3,2, 0,1, 1,1, 2,1
    .byte 0,4, 3,1, 2,2, 1,3
    .byte 3,3, 3,4, 3,2, 2,4

memory_input: {
    cmp #EV_LEFT
    bne !+
    lda mCur
    beq done
    dec mCur
    Redraw()
    rts
!:  cmp #EV_RIGHT
    bne !+
    lda mCur
    cmp #3
    beq done
    inc mCur
    Redraw()
    rts
!:  cmp #EV_FIRE
    bne done
    jsr mem_expect
    cpx mCur
    bne wrong
    ldy mStage
    txa
    sta mPos, y
    lda mLab, x
    sta mLbl, y
    inc mStage
    Redraw()
    lda mStage
    cmp #5
    bne !+
    jmp mod_solve
!:  Sfx(SFX_BEEP)
    jmp mem_new
wrong:
    lda #0
    sta mStage
    Redraw()
    jsr mem_new
    jmp do_strike
done:
    rts
}

memory_draw: {
    lda #GREEN
    sta pcol
    ldy #1
row:
    ldx #3
!:  lda #$a0
    jsr pplot
    inx
    cpx #8
    bne !-
    iny
    cpy #4
    bne row
    lda mDisp
    ora #$b0                // reversed digit
    ldx #5
    ldy #2
    jsr pplot
    // buttons
    ldx #0
btn:
    stx tmp4
    lda #LGREY
    ldy infocus
    beq !+
    cpx mCur
    bne !+
    lda #YELLOW
!:  sta pcol
    lda mem_bx, x
    tax
    ldy #5
    lda #$a0
    jsr pplot
    ldy #7
    jsr pplot
    ldy tmp4
    lda mLab, y
    ora #$b0
    ldy #6
    jsr pplot
    ldx tmp4
    inx
    cpx #4
    bne btn
    // stage lights
    ldx #0
st: lda #BLACK
    cpx mStage
    bcs !+
    lda #LGREEN
!:  sta pcol
    stx tmp4
    lda #5
    sec
    sbc tmp4
    tay
    ldx #11
    lda #$51
    jsr pplot
    ldx tmp4
    inx
    cpx #5
    bne st
    rts
}
mem_bx: .byte 2, 4, 6, 8
