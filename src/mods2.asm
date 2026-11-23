.encoding "screencode_upper"
// ================================================================ MAZE
.label zId = W + 0
.label zX  = W + 1
.label zY  = W + 2
.label zGX = W + 3
.label zGY = W + 4

maze_gen: {
    lda #9
    jsr randn
    sta zId
!:  jsr maze_rand_cell
    stx zX
    sty zY
!:  jsr maze_rand_cell
    stx zGX
    sty zGY
    cpx zX
    bne !+
    cpy zY
    beq !-
!:  rts
}

// random cell that is not a marker -> X, Y
maze_rand_cell: {
retry:
    lda #6
    jsr randn
    sta tmp1
    lda #6
    jsr randn
    sta tmp0
    lda zId
    asl
    asl
    tay
    lda maze_marks, y
    cmp tmp1
    bne !+
    lda maze_marks + 1, y
    cmp tmp0
    beq retry
!:  lda maze_marks + 2, y
    cmp tmp1
    bne !+
    lda maze_marks + 3, y
    cmp tmp0
    beq retry
!:  ldx tmp1
    ldy tmp0
    rts
}

// X, Y = cell -> A = wall bits (1 east, 2 south)
maze_wall: {
    stx tmp0
    tya
    asl
    sta tmp1
    asl
    adc tmp1                // y * 6
    adc tmp0
    sta tmp1
    ldx zId
    lda maze_lo, x
    sta ptr1
    lda maze_hi, x
    sta ptr1 + 1
    ldy tmp1
    lda (ptr1), y
    ldx tmp0
    rts
}
maze_lo: .fill 9, <(maze_walls + i * 36)
maze_hi: .fill 9, >(maze_walls + i * 36)

maze_draw: {
    lda #GREY
    sta pcol
    ldy #2
row:
    ldx #1
!:  lda #$7f
    jsr pplot
    inx
    inx
    cpx #13
    bne !-
    iny
    cpy #8
    bne row
    lda #LGREEN
    sta pcol
    lda zId
    asl
    asl
    tay
    lda maze_marks, y
    ldx maze_marks + 1, y
    jsr cell
    lda zId
    asl
    asl
    tay
    lda maze_marks + 2, y
    ldx maze_marks + 3, y
    jsr cell
    lda #LRED
    sta pcol
    lda zGX
    ldx zGY
    ldy #$7b
    jsr cellc
    lda #WHITE
    sta pcol
    lda zX
    ldx zY
    ldy #$51
    jmp cellc
cell:
    ldy #$57
cellc:                      // A = x, X = y, Y = char
    sty tmp2
    asl
    adc #1
    sta tmp3
    txa
    clc
    adc #2
    tay
    ldx tmp3
    lda tmp2
    jmp pplot
}

maze_input: {
    cmp #EV_FIRE
    bcs done
    sta tmp5
    ldx zX
    ldy zY
    lda tmp5
    cmp #EV_RIGHT
    bne !+
    cpx #5
    beq bump
    jsr maze_wall
    and #1
    bne bump
    inc zX
    jmp moved
!:  cmp #EV_LEFT
    bne !+
    cpx #0
    beq bump
    dex
    jsr maze_wall
    and #1
    bne bump
    dec zX
    jmp moved
!:  cmp #EV_DOWN
    bne !+
    cpy #5
    beq bump
    jsr maze_wall
    and #2
    bne bump
    inc zY
    jmp moved
!:  cpy #0                  // up
    beq bump
    dey
    jsr maze_wall
    and #2
    bne bump
    dec zY
moved:
    Redraw()
    lda zX
    cmp zGX
    bne !+
    lda zY
    cmp zGY
    bne !+
    jmp mod_solve
!:  Sfx(SFX_CLICK)
done:
    rts
bump:
    jmp do_strike
}

// ================================================================ PASSWORD
.label pL   = W + 0     // 5 columns x 6 letters
.label pIdx = W + 30    // 5 current indices
.label pCur = W + 35
.label pAns = W + 36

// A = word number -> ptr3 points at its letters
pw_ptr: {
    sta tmp0
    asl
    asl
    adc tmp0                // *5 (fits in a byte: 34*5 = 170)
    clc
    adc #<pw_words
    sta ptr3
    lda #>pw_words
    adc #0
    sta ptr3 + 1
    rts
}

pw_gen: {
retry:
    lda #PW_COUNT
    jsr randn
    sta pAns
    jsr pw_ptr
    ldx #0                  // column
col:
    stx tmp1
    txa
    asl
    sta tmp2
    asl
    adc tmp2
    sta tmp2                // column * 6 = base index
    txa
    tay
    lda (ptr3), y
    sta tmp3                // the real letter
    lda #6
    jsr randn
    clc
    adc tmp2
    sta tmp4                // where it goes
    ldx #0
slot:
    txa
    clc
    adc tmp2
    tay
    cpy tmp4
    bne decoy
    lda tmp3
    jmp put
decoy:
    lda #26
    jsr randn
    clc
    adc #1
    cmp tmp3
    beq decoy
    sty tmp5                // reject letters already in this column
    ldy tmp2
!:  cpy tmp5
    beq !+
    cmp pL, y
    beq decoy_y
    iny
    bne !-
!:
put:
    sta pL, y
    inx
    cpx #6
    bne slot
    ldx tmp1
    inx
    cpx #5
    bne col
    // make sure no other word can be spelled
    lda #0
    sta tmp6
word:
    lda tmp6
    cmp pAns
    beq next
    jsr pw_ptr
    ldx #0
wcol:
    stx tmp1
    txa
    asl
    sta tmp2
    asl
    adc tmp2
    tay                     // column base
    sty tmp2
    stx tmp7
    ldy tmp7
    lda (ptr3), y
    ldy tmp2
    ldx #6
!:  cmp pL, y
    beq found
    iny
    dex
    bne !-
    jmp next                // letter missing: word impossible
found:
    ldx tmp1
    inx
    cpx #5
    bne wcol
    jmp retry               // another word fits, start over
next:
    inc tmp6
    lda tmp6
    cmp #PW_COUNT
    bne word
    ldx #4
!:  lda #6
    jsr randn
    sta pIdx, x
    dex
    bpl !-
    lda #0
    sta pCur
    rts
decoy_y:
    ldy tmp5
    jmp decoy
}

pw_draw: {
    ldx #0
col:
    stx tmp4
    lda #LGREY
    ldy infocus
    beq !+
    cpx pCur
    bne !+
    lda #YELLOW
!:  sta pcol
    txa
    asl
    sta tmp5
    asl
    adc tmp5
    adc pIdx, x
    tay
    lda pL, y
    ora #$80
    pha
    txa
    asl
    adc #2
    tax
    pla
    ldy #4
    jsr pplot
    lda #$a0
    ldy #3
    jsr pplot
    ldy #5
    jsr pplot
    lda infocus
    beq !+
    lda tmp4
    cmp pCur
    bne !+
    lda #WHITE
    sta pcol
    lda #$1e                // up arrow
    ldy #2
    jsr pplot
    lda #$16                // V
    ldy #6
    jsr pplot
!:  ldx tmp4
    inx
    cpx #5
    bne col
    lda infocus
    beq !+
    PText(1, 8, GREY, "FIRE: SEND")
!:  rts
}

pw_input: {
    ldx pCur
    cmp #EV_LEFT
    bne !+
    cpx #0
    beq done
    dec pCur
    jmp redraw
!:  cmp #EV_RIGHT
    bne !+
    cpx #4
    beq done
    inc pCur
    jmp redraw
!:  cmp #EV_UP
    bne !+
    lda pIdx, x
    bne dec1
    lda #6
dec1:
    sec
    sbc #1
    sta pIdx, x
    jmp click
!:  cmp #EV_DOWN
    bne !+
    lda pIdx, x
    clc
    adc #1
    cmp #6
    bne set
    lda #0
set:
    sta pIdx, x
    jmp click
!:  cmp #EV_FIRE
    bne done
    lda pAns
    jsr pw_ptr
    ldx #0
cmpl:
    txa
    asl
    sta tmp5
    asl
    adc tmp5
    adc pIdx, x
    tay
    lda pL, y
    stx tmp5
    ldy tmp5
    cmp (ptr3), y
    bne wrong
    inx
    cpx #5
    bne cmpl
    jmp mod_solve
wrong:
    jmp do_strike
click:
    Sfx(SFX_CLICK)
redraw:
    Redraw()
done:
    rts
}

// ================================================================ MORSE CODE
.label oWord  = W + 0
.label oSel   = W + 1
.label oPtr   = W + 2
.label oT     = W + 3
.label oLight = W + 4
.label oGap   = W + 5

morse_gen: {
    lda #16
    jsr randn
    sta oWord
    tax
    lda morse_offs, x
    sta oPtr
    lda #0
    sta oSel
    sta oLight
    sta oGap
    lda fps
    sta oT
    rts
}

morse_update: {
    dec oT
    bne done
    lda oGap
    beq fetch
    lda #0
    sta oGap
    lda morse_unit
    sta oT
    lda #0
    jmp light
fetch:
    ldx oPtr
    inc oPtr
    lda morse_stream, x
    beq word_end
    cmp #3
    beq letter_end
    cmp #1
    beq dot
    lda morse_unit          // dash = 3 units
    asl
    adc morse_unit
    bne on
dot:
    lda morse_unit
on: sta oT
    lda #1
    sta oGap
    jmp light
letter_end:
    lda morse_unit
    asl
    sta oT
    rts
word_end:
    ldx oWord
    lda morse_offs, x
    sta oPtr
    lda morse_unit
    asl
    sta tmp0
    asl
    adc tmp0                // 6 units
    sta oT
    rts
light:
    sta oLight
    lda visible
    beq done
    jmp morse_draw_light
done:
    rts
}

morse_draw_light: {
    lda #BLACK
    ldx oLight
    beq !+
    lda #YELLOW
!:  sta pcol
    lda #$51
    ldx #8
    ldy #2
    jmp pplot
}

morse_draw: {
    jsr morse_draw_light
    PText(2, 2, GREY, "LIGHT")
    PText(2, 5, WHITE, "3.")
    lda oSel
    asl
    adc oSel
    tay
    ldx #4
!:  lda morse_freq, y
    jsr pplot_y5
    iny
    inx
    cpx #7
    bne !-
    PText(8, 5, GREY, "MHZ")
    lda #GREY
    sta pcol
    lda oSel
    beq !+
    lda #$3c                // <
    ldx #1
    ldy #5
    jsr pplot
!:  lda oSel
    cmp #15
    beq !+
    lda #$3e                // >
    ldx #11
    ldy #5
    jsr pplot
!:  lda #GREY
    ldx infocus
    beq !+
    lda #YELLOW
!:  sta pcol
    lda #$80
    sta rvs
    PTextC(4, 7, " TX ")
    lda #0
    sta rvs
    rts
}

// plot A at (X, 5) in white keeping Y
pplot_y5: {
    sty tmp0
    pha
    lda #WHITE
    sta pcol
    pla
    ldy #5
    jsr pplot
    ldy tmp0
    rts
}

morse_input: {
    cmp #EV_LEFT
    bne !+
    lda oSel
    beq done
    dec oSel
    jmp redraw
!:  cmp #EV_RIGHT
    bne !+
    lda oSel
    cmp #15
    beq done
    inc oSel
    jmp redraw
!:  cmp #EV_FIRE
    bne done
    lda oSel
    cmp oWord
    bne !+
    lda #0
    sta oLight
    jmp mod_solve
!:  jmp do_strike
redraw:
    Sfx(SFX_CLICK)
    Redraw()
done:
    rts
}

// ================================================================ COMPLEX WIRES
.label cN    = W + 0
.label cAttr = W + 1    // 6: bit3 red, bit2 blue, bit1 star, bit0 light
.label cMust = W + 7    // 6
.label cCut  = W + 13   // 6
.label cCur  = W + 19

cw_gen: {
    ldx tier
    lda cw_span, x
    jsr randn
    clc
    adc cw_base, x
    sta cN
retry:
    lda #0
    sta tmp1                // number of wires to cut
    ldx #0
!:  lda #16
    jsr randn
    sta cAttr, x
    tay
    lda cw_letter, y
    jsr cw_eval
    sta cMust, x
    clc
    adc tmp1
    sta tmp1
    lda #0
    sta cCut, x
    inx
    cpx cN
    bne !-
    lda tmp1
    beq retry
    lda #0
    sta cCur
    rts
}
cw_base: .byte 4, 4, 5, 6
cw_span: .byte 1, 2, 2, 1
// letter per attribute combination: 0 C, 1 D, 2 S, 3 P, 4 B
cw_letter: .byte 0, 1, 0, 4,  2, 3, 1, 3,  2, 4, 0, 4,  2, 2, 3, 1

// A = letter -> A = 1 if the wire must be cut
cw_eval: {
    cmp #0
    beq yes
    cmp #1
    beq no
    cmp #2
    bne !+
    lda serial_odd
    eor #1
    rts
!:  cmp #3
    bne !+
    lda has_par
    rts
!:  lda batteries
    cmp #2
    bcs yes
no: lda #0
    rts
yes:
    lda #1
    rts
}

cw_draw: {
    lda #7
    sec
    sbc cN
    sta tmp6                // x of first wire
    ldx #0
wire:
    stx tmp4
    lda tmp6
    sta tmp5
    // light
    lda #BLACK
    ldy cAttr, x
    tya
    and #1
    beq !+
    lda #YELLOW
!:  sta pcol
    lda #$51
    ldx tmp5
    ldy #1
    jsr pplot
    // wire body
    ldy #2
body:
    ldx tmp4
    lda cAttr, x
    lsr
    lsr
    and #3                  // 0 white, 1 blue, 2 red, 3 both
    tax
    lda cw_col, x
    cpx #3
    bne !+
    tya                     // striped: alternate rows
    and #1
    tax
    lda cw_stripe, x
!:  sta pcol
    lda #$7e
    ldx tmp4
    cpy #4
    bne !+
    ldx tmp4
    lda cCut, x
    beq !+
    lda #$20
    .byte $2c
!:  lda #$7e
    ldx tmp5
    jsr pplot
    iny
    cpy #7
    bne body
    // star
    ldx tmp4
    lda cAttr, x
    and #2
    beq !+
    lda #WHITE
    sta pcol
    lda #$2a
    ldx tmp5
    ldy #7
    jsr pplot
    // cursor
!:  lda infocus
    beq !+
    lda tmp4
    cmp cCur
    bne !+
    lda #YELLOW
    sta pcol
    lda #$1e
    ldx tmp5
    ldy #8
    jsr pplot
!:  inc tmp6
    inc tmp6
    ldx tmp4
    inx
    cpx cN
    beq !+
    jmp wire
!:  rts
}
cw_col:    .byte WHITE, LBLUE, RED, 0
cw_stripe: .byte RED, LBLUE

cw_input: {
    cmp #EV_LEFT
    bne !+
    lda cCur
    beq done
    dec cCur
    Redraw()
    rts
!:  cmp #EV_RIGHT
    bne !+
    ldx cCur
    inx
    cpx cN
    beq done
    stx cCur
    Redraw()
    rts
!:  cmp #EV_FIRE
    bne done
    ldx cCur
    lda cCut, x
    bne done
    lda #1
    sta cCut, x
    Redraw()
    Sfx(SFX_CUT)
    ldx cCur
    lda cMust, x
    bne !+
    jmp do_strike
!:  ldx cN                  // all required wires cut?
!:  dex
    bmi solved
    lda cMust, x
    beq !-
    lda cCut, x
    bne !-
done:
    rts
solved:
    jmp mod_solve
}

// ================================================================ VENT GAS (needy)
.label vAct   = W + 0
.label vQ     = W + 1   // 0 = VENT GAS?, 1 = DETONATE?
.label vSecs  = W + 2
.label vFr    = W + 3
.label vCur   = W + 4   // 0 = YES, 1 = NO
.label vSleep = W + 5

vent_gen: {
    lda #0
    sta vAct
    sta vCur
    lda fps
    sta vFr
    lda #20
    jsr randn
    clc
    adc #15
    sta vSleep
    rts
}

vent_update: {
    dec vFr
    bne done
    lda fps
    sta vFr
    lda vAct
    bne active
    dec vSleep
    bne done
    lda #1
    sta vAct
    lda #2
    jsr randn
    sta vQ
    ldx tier
    lda vent_time, x
    sta vSecs
    lda #0
    sta vCur
    Sfx(SFX_ALERT)
    Redraw()
    rts
active:
    dec vSecs
    Redraw()
    lda vSecs
    bne done
    jsr vent_sleep
    jmp do_strike
done:
    rts
}
vent_time: .byte 45, 40, 35, 30

vent_sleep: {
    lda #0
    sta vAct
    lda #25
    jsr randn
    clc
    adc #20
    sta vSleep
    Redraw()
    rts
}

vent_input: {
    ldx vAct
    beq done
    cmp #EV_LEFT
    bne !+
    lda #0
    sta vCur
    Redraw()
    rts
!:  cmp #EV_RIGHT
    bne !+
    lda #1
    sta vCur
    Redraw()
    rts
!:  cmp #EV_FIRE
    bne done
    lda vCur
    cmp vQ
    bne wrong
    Sfx(SFX_BEEP)
    jmp vent_sleep
wrong:
    jsr vent_sleep
    jmp do_strike
done:
    rts
}

vent_draw: {
    lda vAct
    bne active
    PText(5, 4, GREY, "--")
    rts
active:
    lda vQ
    bne det
    PText(1, 2, WHITE, "VENT GAS?")
    jmp count
det:
    PText(1, 2, WHITE, "DETONATE?")
count:
    lda vSecs
    jsr to_dec
    lda #LRED
    ldx vSecs
    cpx #10
    bcc !+
    lda #YELLOW
!:  sta pcol
    lda dec_t
    ldx #5
    ldy #4
    jsr pplot
    lda dec_o
    inx
    jsr pplot
    // YES / NO
    lda #0
    ldx infocus
    beq !+
    ldx vCur
    bne !+
    lda #$80
!:  sta rvs
    PText(2, 6, WHITE, "YES")
    lda #0
    ldx infocus
    beq !+
    ldx vCur
    beq !+
    lda #$80
!:  sta rvs
    PText(8, 6, WHITE, "NO")
    lda #0
    sta rvs
    rts
}
