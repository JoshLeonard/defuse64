.encoding "screencode_upper"
// ================================================================ helpers

// draws 5-row big text.  ptr1 = data, X = column, Y = row, tmp6 = width,
// pcol = colour
draw_big: {
    stx tmp4
    lda #5
    sta tmp7
row:
    ldx tmp4
    lda tmp6
    sta tmp5
    sty tmp3
    ldy #0
!:  lda (ptr1), y
    sty tmp2
    ldy tmp3
    jsr plot
    ldy tmp2
    iny
    inx
    dec tmp5
    bne !-
    tya                     // next row of data
    clc
    adc ptr1
    sta ptr1
    bcc !+
    inc ptr1 + 1
!:  ldy tmp3
    iny
    dec tmp7
    bne row
    rts
}

.macro Big(label, width, x, y, color) {
    lda #<label
    sta ptr1
    lda #>label
    sta ptr1 + 1
    lda #width
    sta tmp6
    lda #color
    sta pcol
    ldx #x
    ldy #y
    jsr draw_big
}

// black screen for menus
menu_screen: {
    lda #BLACK
    sta $d020
    sta $d021
    lda #WHITE
    jmp clear_screen
}

// prints level+1 as three digits at X/Y in pcol
print_level: {
    stx tmp0
    sty tmp1
    lda level
    clc
    adc #1
    jsr to_dec
    ldx tmp0
    ldy tmp1
    lda dec_h
    jsr plot
    inx
    lda dec_t
    jsr plot
    inx
    lda dec_o
    jmp plot
}

// waits for fire (carry clear) or back (carry set)
wait_fire_back: {
!:  jsr wait_frame
    jsr rand
    jsr scan_input
    lda btn_new
    and #B_FIRE
    bne fire
    lda btn_new
    and #B_BACK
    beq !-
    sec
    rts
fire:
    clc
    rts
}

// ================================================================ title

title: {
    lda #0
    sta timer_on
    jsr menu_screen
    Big(big_title, BIG_TITLE_W, 2, 2, LRED)
    lda #ORANGE
    sta pcol
    ldx #2
    ldy #8
!:  lda #$40
    jsr plot
    inx
    cpx #37
    bne !-
    Text(3, 10, WHITE, "A BOMB DEFUSAL GAME FOR 2+ PLAYERS")
    Text(3, 12, GREY, "ONE PLAYER DEFUSES THE BOMB. THE")
    Text(3, 13, GREY, "OTHERS READ THE MANUAL. NOBODY")
    Text(3, 14, GREY, "LOOKS AT THE OTHER SIDE. TALK!")
    Text(6, 17, YELLOW, "FIRE / SPACE  START LEVEL 1")
    Text(6, 19, YELLOW, "C             ENTER LEVEL CODE")
    Text(1, 22, DGREY, "WASD/CURSORS/JOY2  RETURN=USE  DEL=BACK")
    Text(10, 24, DGREY, "100 LEVELS  -  1 MANUAL")
loop:
    jsr wait_frame
    jsr rand
    jsr scan_input
    lda frame
    and #$10
    beq !+
    lda #ORANGE
    .byte $2c
!:  lda #RED
    sta $d020
    lda btn_new
    and #B_FIRE
    beq !+
    lda #0
    sta level
    jmp game
!:  jsr get_key
    cmp #20                 // C
    bne loop
    jmp code_entry
}

// ================================================================ level codes

code_entry: {
    jsr menu_screen
    Text(11, 8, WHITE, "ENTER LEVEL CODE")
    Text(6, 16, GREY, "TYPE 4 LETTERS, THEN RETURN")
    Text(8, 18, GREY, "DEL ERASES   ARROW QUITS")
reset:
    lda #0
    sta code_len
    jsr show
loop:
    jsr wait_frame
    jsr scan_input
    jsr get_key
    cmp #$ff
    beq loop
    cmp #57                 // left arrow
    bne !+
    jmp title
!:  cmp #0                  // DEL
    bne !+
    lda code_len
    beq loop
    dec code_len
    jsr show
    jmp loop
!:  cmp #1                  // RETURN
    beq enter
    tax
    lda keymap, x
    beq loop
    cmp #27                 // letters only
    bcs loop
    ldx code_len
    cpx #4
    beq loop
    sta code_buf, x
    inc code_len
    Sfx(SFX_CLICK)
    jsr show
    jmp loop
enter:
    lda code_len
    cmp #4
    bne loop
    lda #<lv_codes
    sta ptr1
    lda #>lv_codes
    sta ptr1 + 1
    ldx #0
try:
    ldy #3
!:  lda (ptr1), y
    cmp code_buf, y
    bne next
    dey
    bpl !-
    stx level
    Sfx(SFX_SOLVE)
    jmp game
next:
    lda ptr1
    clc
    adc #4
    sta ptr1
    bcc !+
    inc ptr1 + 1
!:  inx
    cpx #100
    bne try
    Sfx(SFX_STRIKE)
    Text(13, 13, LRED, "UNKNOWN CODE")
    jmp reset

show:
    lda #YELLOW
    sta pcol
    ldx #0
!:  lda #$2d
    cpx code_len
    bcs !+
    lda code_buf, x
!:  stx tmp0
    pha
    txa
    asl
    adc #16
    tax
    pla
    ldy #11
    jsr plot
    ldx tmp0
    inx
    cpx #4
    bne !--
    rts
}

// ================================================================ game flow

game: {
    jsr intro
    jsr play_level
    lda game_state
    cmp #2
    beq won
    jsr boom_screen
    bcc game                // try the same level again
    jmp title
won:
    jsr win_screen
    inc level
    lda level
    cmp #100
    bne game
    jmp final_screen
}

intro: {
    jsr menu_screen
    Text(14, 3, GREY, "LEVEL")
    lda #YELLOW
    sta pcol
    ldx #20
    ldy #3
    jsr print_level
    Text(9, 6, GREY, "MODULES")
    ldx level
    lda lv_count, x
    jsr to_dec
    lda #WHITE
    sta pcol
    ldx #24
    ldy #6
    lda dec_t
    cmp #$30
    beq !+
    jsr plot
!:  inx
    lda dec_o
    jsr plot
    ldx level
    lda lv_needy, x
    beq !+
    ora #$30
    pha
    Text(9, 7, GREY, "NEEDY MODULES")
    lda #WHITE
    sta pcol
    pla
    ldx #25
    ldy #7
    jsr plot
!:  Text(9, 8, GREY, "TIME")
    lda #WHITE
    sta pcol
    ldx level
    lda lv_min, x
    ldx #21
    ldy #8
    jsr print_bcd
    inx
    lda #$3a
    jsr plot
    inx
    ldy level
    lda lv_sec, y
    ldy #8
    jsr print_bcd
    Text(9, 9, GREY, "BOOM ON STRIKE")
    ldx level
    lda lv_strikes, x
    ora #$30
    ldx #25
    ldy #9
    jsr plot
    ldx level
    lda lv_forced, x
    bmi ready
    pha
    Text(9, 13, LGREEN, "NEW MODULE:")
    pla
    tax
    lda longname_ofs, x
    sta ptr1
    lda #>longnames
    sta ptr1 + 1
    lda #<longnames
    clc
    adc ptr1
    sta ptr1
    bcc !+
    inc ptr1 + 1
!:  lda #WHITE
    sta pcol
    ldx #9
    ldy #14
    jsr print
    Text(9, 15, GREY, "READ ITS PAGE IN THE MANUAL")
ready:
    Text(4, 20, YELLOW, "PRESS FIRE WHEN THE EXPERTS ARE")
    Text(4, 21, YELLOW, "READY WITH THEIR MANUALS")
    jmp wait_fire
}

longnames:
    .text "WIRES"
    .byte $ff
    .text "THE BUTTON"
    .byte $ff
    .text "KEYPAD"
    .byte $ff
    .text "SIMON SAYS"
    .byte $ff
    .text "MEMORY"
    .byte $ff
    .text "MAZE"
    .byte $ff
    .text "PASSWORD"
    .byte $ff
    .text "MORSE CODE"
    .byte $ff
    .text "COMPLEX WIRES"
    .byte $ff
    .text "VENT GAS (NEEDY)"
    .byte $ff
longname_ofs: .byte 0, 6, 17, 24, 35, 42, 47, 56, 67, 81

// carry clear = retry, carry set = back to title
boom_screen: {
    Sfx(SFX_BOOM)
    lda #60
    sta tmp7
flash:
    jsr wait_frame
    jsr rand
    and #$0f
    sta $d020
    lda tmp7
    and #3
    bne !+
    jsr rand
    and #1
    ora #$0a                // light red / orange flicker
    sta $d021
!:  dec tmp7
    bne flash
    jsr menu_screen
    Big(big_boom, BIG_BOOM_W, 10, 4, LRED)
    lda boom_reason
    cmp #2
    beq time
    Text(12, 12, WHITE, "TOO MANY STRIKES")
    jmp more
time:
    Text(14, 12, WHITE, "TIME RAN OUT")
more:
    Text(14, 14, GREY, "LEVEL")
    lda #GREY
    sta pcol
    ldx #20
    ldy #14
    jsr print_level
    Text(6, 19, YELLOW, "FIRE  TRY AGAIN (NEW BOMB)")
    Text(6, 21, YELLOW, "DEL   BACK TO TITLE")
    jmp wait_fire_back
}

win_screen: {
    Sfx(SFX_WIN)
    jsr menu_screen
    Big(big_defused, BIG_DEFUSED_W, 6, 3, LGREEN)
    Text(14, 10, GREY, "LEVEL")
    lda #WHITE
    sta pcol
    ldx #20
    ldy #10
    jsr print_level
    Text(12, 12, GREY, "TIME LEFT")
    lda #WHITE
    sta pcol
    lda tmin
    ldx #22
    ldy #12
    jsr print_bcd
    inx
    lda #$3a
    jsr plot
    inx
    lda tsec
    jsr print_bcd
    lda level
    cmp #99
    bne !+
    jmp last
!:  Text(7, 16, GREY, "CODE FOR NEXT LEVEL")
    lda level
    clc
    adc #1
    asl
    asl
    tay
    bcc !+                  // levels past 63 need the high half
    lda #<(lv_codes + 256)
    sta ptr1
    lda #>(lv_codes + 256)
    sta ptr1 + 1
    jmp got
!:  lda #<lv_codes
    sta ptr1
    lda #>lv_codes
    sta ptr1 + 1
got:
    lda #YELLOW
    sta pcol
    ldx #27
!:  lda (ptr1), y
    sty tmp0
    ldy #16
    jsr plot
    ldy tmp0
    iny
    inx
    cpx #31
    bne !-
    Text(7, 17, DGREY, "(WRITE IT IN YOUR MANUAL)")
last:
    Text(9, 21, YELLOW, "PRESS FIRE TO CONTINUE")
    jmp wait_fire
}

final_screen: {
    Sfx(SFX_WIN)
    jsr menu_screen
    Big(big_defused, BIG_DEFUSED_W, 6, 3, YELLOW)
    Text(6, 11, WHITE, "ALL 100 BOMBS ARE DEFUSED!")
    Text(5, 13, GREY, "THE CITY IS SAFE. THE BOMB SQUAD")
    Text(5, 14, GREY, "SALUTES YOU AND YOUR EXPERTS.")
    Text(9, 20, YELLOW, "PRESS FIRE FOR TITLE")
    jsr wait_fire
    jmp title
}
