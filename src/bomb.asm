.encoding "screencode_upper"
// ================================================================ bomb setup

// Builds a fresh random bomb for `level` (0-99).
setup_bomb: {
    ldx level
    lda lv_min, x
    sta tmin
    lda lv_sec, x
    sta tsec
    lda lv_strikes, x
    sta max_strikes
    lda lv_tier, x
    sta tier
    lda #0
    sta strikes
    sta time_up
    sta sec_flag
    sta timer_on
    sta game_state
    sta mode
    sta side
    sta flash_t
    sta nmods
    sta side_base
    jsr set_tick_rate
    lda tick_reload
    sta tick
    jsr gen_edgework

    ldx #MAXMODS - 1
    lda #$ff
!:  sta slot_mod, x
    dex
    bpl !-

    ldx level
    lda lv_forced, x
    cmp #T_VENT
    bcs !+                  // none, or the needy module (added below)
    jsr add_module
!:
fill:
    ldx level
    lda nmods
    cmp lv_count, x
    bcs needy
pick:
    lda #9
    jsr randn
    tay
    ldx level
    cpy #8
    bcc low
    lda lv_pool_hi, x
    and #1
    beq pick
    bne got
low:
    lda lv_pool_lo, x
    and bit_tab, y
    beq pick
got:
    tya
    jsr add_module
    jmp fill
needy:
    ldx level
    lda lv_needy, x
    sta loop_i
!:  lda loop_i
    beq gen
    lda #T_VENT
    jsr add_module
    dec loop_i
    jmp !-
gen:
    ldx #0
!:  stx loop_i
    lda #FN_GEN
    jsr call_mod
    ldx loop_i
    inx
    cpx nmods
    bne !-
    // start the cursor on the first occupied front slot
    ldx #0
!:  lda slot_mod, x
    bpl !+
    inx
    cpx #5
    bne !-
!:  stx cursor
    rts
}

// A = module type.  Places a new module in a random free slot (front first).
add_module: {
    ldx nmods
    sta m_type, x
    lda #0
    sta m_solved, x
    lda #0
    cpx #6
    bcc !+
    lda #6
!:  sta tmp0
retry:
    lda #6
    jsr randn
    clc
    adc tmp0
    tay
    lda slot_mod, y
    bpl retry
    txa
    sta slot_mod, y
    tya
    sta m_slot, x
    inc nmods
    rts
}

// Timer runs faster after each strike.
set_tick_rate: {
    ldx strikes
    cpx #4
    bcc !+
    ldx #3
!:  lda fps
    cmp #60
    beq ntsc
    lda rate_pal, x
    bne set
ntsc:
    lda rate_ntsc, x
set:
    sta tick_reload
    rts
}
rate_pal:  .byte 50, 40, 33, 28
rate_ntsc: .byte 60, 48, 40, 34

gen_edgework: {
    ldx #0
!:  lda #35
    jsr randn
    tay
    lda serial_chars, y
    sta serial, x
    inx
    cpx #5
    bne !-
    lda #10
    jsr randn
    sta tmp0
    ora #$30
    sta serial + 5
    lda tmp0
    and #1
    sta serial_odd
    lda #0
    sta has_vowel
    ldx #5
vow:
    lda serial, x
    cmp #$01                // A
    beq yes
    cmp #$05                // E
    beq yes
    cmp #$09                // I
    beq yes
    cmp #$15                // U
    bne nxt
yes:
    lda #1
    sta has_vowel
nxt:
    dex
    bpl vow

    lda #5
    jsr randn
    sta batteries

    lda #16
    jsr randn
    sta ports
    and #1
    sta has_par

    lda #4
    jsr randn
    sta ind_count
    lda #0
    sta lit_frk
    sta lit_sig
    ldx #0
ind:
    stx tmp0
    cpx ind_count
    beq done
again:
    lda #7
    jsr randn
    ldy #0                  // reject duplicates
dup:
    cpy tmp0
    beq unique
    cmp ind_label, y
    beq again
    iny
    bne dup
unique:
    sta ind_label, x
    lda #2
    jsr randn
    sta ind_lit, x
    beq !+
    lda ind_label, x
    cmp #1                  // FRK
    bne notfrk
    sta lit_frk
notfrk:
    cmp #2                  // SIG
    bne !+
    sta lit_sig
!:  inx
    jmp ind
done:
    jmp layout_edges
}

serial_chars: .text "ABCDEFGHIJKLMNPQRSTUVWXYZ0123456789"
ind_names:    .text "CARFRKSIGNSABOBMSATRN"
bit_tab:      .byte 1, 2, 4, 8, 16, 32, 64, 128

// ================================================================ module dispatch

// X = module index, A = function, Y = event (for FN_INPUT)
call_mod: {
    stx cur_mod
    sta mfn
    sty mevt
    lda mdata_lo, x
    sta ptr4
    lda mdata_hi, x
    sta ptr4 + 1
    ldy #MDSIZE - 1
!:  lda (ptr4), y
    sta W, y
    dey
    bpl !-
    lda m_slot, x
    jsr set_panel
    ldx cur_mod
    lda #0
    sta needdraw
    sta infocus
    lda mode
    beq !+
    cpx focus_mod
    bne !+
    inc infocus
!:  lda m_type, x
    asl
    asl
    ora mfn
    ldy mevt
    jsr dispatch
    lda needdraw
    beq copyout
    lda visible
    beq copyout
    lda needdraw
    and #2
    beq !+
    jsr draw_frame
!:  jsr draw_interior
copyout:
    ldx cur_mod
    lda mdata_lo, x
    sta ptr4
    lda mdata_hi, x
    sta ptr4 + 1
    ldy #MDSIZE - 1
!:  lda W, y
    sta (ptr4), y
    dey
    bpl !-
    rts
}

// A = type * 4 + function, Y passed through, A = event on entry to module
dispatch: {
    asl
    tax
    lda modfn + 1, x
    pha
    lda modfn, x
    pha
    tya
    rts
}

modfn:
    .word wires_gen - 1, wires_draw - 1, wires_input - 1, no_op - 1
    .word button_gen - 1, button_draw - 1, button_input - 1, button_update - 1
    .word keypad_gen - 1, keypad_draw - 1, keypad_input - 1, no_op - 1
    .word simon_gen - 1, simon_draw - 1, simon_input - 1, simon_update - 1
    .word memory_gen - 1, memory_draw - 1, memory_input - 1, no_op - 1
    .word maze_gen - 1, maze_draw - 1, maze_input - 1, no_op - 1
    .word pw_gen - 1, pw_draw - 1, pw_input - 1, no_op - 1
    .word morse_gen - 1, morse_draw - 1, morse_input - 1, morse_update - 1
    .word cw_gen - 1, cw_draw - 1, cw_input - 1, no_op - 1
    .word vent_gen - 1, vent_draw - 1, vent_input - 1, vent_update - 1

// which types need a per-frame update
has_update: .byte 0, 1, 0, 1, 0, 0, 0, 1, 0, 1

no_op:
    rts

mdata_lo: .fill MAXMODS, <(mdata + i * MDSIZE)
mdata_hi: .fill MAXMODS, >(mdata + i * MDSIZE)

// A = slot (0-11).  Sets px0/py0/visible.
set_panel: {
    tax
    lda #0
    cpx #6
    bcc !+
    lda #1
!:  cmp side
    bne hidden
    lda #1
    sta visible
    bne pos
hidden:
    lda #0
    sta visible
pos:
    lda panel_x, x
    sta px0
    lda panel_y, x
    sta py0
    rts
}
panel_x: .byte 0, 13, 26, 0, 13, 26, 0, 13, 26, 0, 13, 26
panel_y: .byte 4, 4, 4, 14, 14, 14, 4, 4, 4, 14, 14, 14

// called by modules
mod_solve: {
    ldx cur_mod
    lda #1
    sta m_solved, x
    lda needdraw
    ora #2
    sta needdraw
    Sfx(SFX_SOLVE)
    rts
}

do_strike: {
    inc strikes
    Sfx(SFX_STRIKE)
    lda #12
    sta flash_t
    lda #RED
    sta $d020
    jsr set_tick_rate
    jsr draw_strikes
    lda strikes
    cmp max_strikes
    bcc !+
    lda #1
    sta game_state
    sta boom_reason
!:  rts
}

// ================================================================ drawing

// border colour for the panel whose slot is in tmp0
draw_frame: {
    ldx cur_mod
    lda m_slot, x
    sta tmp0
    jmp frame_slot
}

// draws the casing frame of panel at px0/py0 for slot tmp0
frame_slot: {
    lda #GREY
    ldx tmp0
    ldy slot_mod, x
    bpl !+
    lda #BLACK
!:  sta pcol
    lda tmp0
    sec
    sbc side_base
    cmp cursor
    bne used
    lda #YELLOW
    ldx mode
    beq !+
    lda #LGREEN
!:  sta pcol
used:
    ldx #0
    ldy #0
    lda #$55
    jsr pplot
    ldx #12
    lda #$49
    jsr pplot
    ldy #9
    lda #$4b
    jsr pplot
    ldx #0
    lda #$4a
    jsr pplot
    ldx #1
!:  lda #$40
    ldy #0
    jsr pplot
    ldy #9
    jsr pplot
    inx
    cpx #12
    bne !-
    ldy #1
!:  lda #$5d
    ldx #0
    jsr pplot
    ldx #12
    jsr pplot
    iny
    cpy #9
    bne !-
    // title and status light
    ldx tmp0
    lda slot_mod, x
    bmi empty
    tax
    lda m_type, x
    tay
    lda m_solved, x
    sta tmp1
    lda modname_ofs, y
    tay
    ldx #1
    lda #WHITE
    sta pcol
!:  lda modnames, y
    cmp #$ff
    beq led
    sty tmp2
    ldy #0
    jsr pplot
    ldy tmp2
    iny
    inx
    bne !-
led:
    ldx tmp0
    lda slot_mod, x
    tax
    lda m_type, x
    cmp #T_VENT
    beq empty
    lda #BLACK
    ldy tmp1
    beq !+
    lda #LGREEN
!:  sta pcol
    lda #$51
    ldx #11
    ldy #0
    jsr pplot
empty:
    rts
}

modnames:
    .text "WIRES"
    .byte $ff
    .text "BUTTON"
    .byte $ff
    .text "KEYPAD"
    .byte $ff
    .text "SIMON"
    .byte $ff
    .text "MEMORY"
    .byte $ff
    .text "MAZE"
    .byte $ff
    .text "PASSWORD"
    .byte $ff
    .text "MORSE"
    .byte $ff
    .text "COMPLEX"
    .byte $ff
    .text "VENT GAS"
    .byte $ff
modname_ofs: .byte 0, 6, 13, 20, 26, 33, 38, 47, 53, 61

// clears the 11x8 inside of the panel and calls the module's draw routine
draw_interior: {
    lda #DGREY
    sta pcol
    ldy #1
row:
    ldx #1
!:  lda #$20
    jsr pplot
    inx
    cpx #12
    bne !-
    iny
    cpy #9
    bne row
    ldx cur_mod
    lda m_type, x
    asl
    asl
    ora #FN_DRAW
    jmp dispatch
}

// draws all six panels of the current side
draw_side: {
    lda #0
    sta ds_i
loop:
    lda ds_i
    jsr draw_slot
    inc ds_i
    lda ds_i
    cmp #6
    bne loop
    rts
}

// A = position on current side (0-5)
draw_slot: {
    clc
    adc side_base
    sta tmp0
    jsr set_panel
    lda tmp0
    pha
    jsr frame_slot
    pla
    tax
    lda slot_mod, x
    bmi blank
    tax
    lda #FN_DRAW
    jsr call_mod_draw
    rts
blank:
    // empty plate: a few screws
    lda #BLACK
    sta pcol
    ldy #1
row:
    ldx #1
!:  lda #$20
    jsr pplot
    inx
    cpx #12
    bne !-
    iny
    cpy #9
    bne row
    lda #$57
    ldx #2
    ldy #2
    jsr pplot
    ldx #10
    jsr pplot
    ldy #7
    jsr pplot
    ldx #2
    jsr pplot
    rts
}

// X = module.  Full draw (frame already done).
call_mod_draw: {
    stx cur_mod
    lda mdata_lo, x
    sta ptr4
    lda mdata_hi, x
    sta ptr4 + 1
    ldy #MDSIZE - 1
!:  lda (ptr4), y
    sta W, y
    dey
    bpl !-
    lda #0
    sta infocus
    lda mode
    beq !+
    cpx focus_mod
    bne !+
    inc infocus
!:  jmp draw_interior
}

draw_header: {
    lda #DGREY
    sta $d021
    lda #BLACK
    sta $d020
    jsr clear_screen
    Text(0, 0, GREY, "LEVEL")
    lda level
    clc
    adc #1
    jsr to_dec
    lda #WHITE
    sta pcol
    ldy #0
    ldx #6
    lda dec_h
    jsr plot
    inx
    lda dec_t
    jsr plot
    inx
    lda dec_o
    jsr plot
    Text(12, 0, GREY, "TIME")
    Text(25, 0, GREY, "STRIKES")
    lda #GREY
    sta pcol
    ldx #0
    ldy #3
!:  lda #$40
    jsr plot
    inx
    cpx #32
    bne !-
    jsr draw_timer
    jsr draw_strikes
    rts
}

draw_timer: {
    lda #YELLOW
    ldx tmin
    bne !+
    lda #LRED
!:  sta pcol
    ldy #0
    ldx #17
    lda tmin
    jsr print_bcd
    inx
    lda #$3a
    jsr plot
    inx
    lda tsec
    jmp print_bcd
}

draw_strikes: {
    ldx #33
    ldy #0
    lda #0
    sta tmp3
loop:
    lda tmp3
    clc
    adc #1
    cmp max_strikes
    bcs done
    lda tmp3
    cmp strikes
    bcs safe
    lda #LRED
    sta pcol
    lda #$18                // X
    bne put
safe:
    lda #GREY
    sta pcol
    lda #$2d                // -
put:
    jsr plot
    inx
    inc tmp3
    bne loop
done:
    // clear leftovers (strike limit can be 1)
!:  cpx #36
    beq !+
    lda #$20
    jsr plot
    inx
    bne !-
!:  rts
}

draw_help: {
    lda mode
    beq !+
    jmp focus
!:
    lda side
    cmp #2
    bcs edge
    Text(0, 24, GREY, " MOVE:WASD/JOY  USE:RETURN  TURN:EDGES ")
    rts
edge:
    Text(0, 24, GREY, " WASD/JOY: TURN THE BOMB   F1: FRONT  ")
    rts
focus:
    Text(0, 24, LGREEN, " WORKING ON MODULE - DEL: BACK TO BOMB ")
    rts
}

// ================================================================ play loop

play_level: {
    jsr setup_bomb
    jsr draw_header
    jsr draw_face
    jsr draw_face_header
    lda #1
    sta timer_on

loop:
    jsr wait_frame
    jsr scan_input

    lda flash_t
    beq !+
    dec flash_t
    bne !+
    lda #BLACK
    sta $d020
!:
    lda sec_flag
    beq !+
    lda #0
    sta sec_flag
    jsr draw_timer
    ldx #SFX_TICK
    lda tmin
    bne tk
    lda tsec
    cmp #$11
    bcs tk
    ldx #SFX_TICK2
tk: jsr play_sfx
!:
    lda time_up
    beq !+
    lda #2                  // 2 = out of time
    sta boom_reason
    lda #1
    sta game_state
    jmp end
!:
    // per-frame module updates
    ldx #0
upd:
    cpx nmods
    beq upd_done
    lda m_solved, x
    bne upd_next
    ldy m_type, x
    lda has_update, y
    beq upd_next
    stx upd_i
    lda #FN_UPDATE
    jsr call_mod
    ldx upd_i
upd_next:
    inx
    bne upd
upd_done:
    jsr check_state
    bcs end

    lda mode
    bne focused
    jsr nav_input
    jmp check
focused:
    jsr focus_input
check:
    jsr check_state
    bcs end
    jmp loop
end:
    lda #0
    sta timer_on
    lda #BLACK
    sta $d020
    rts
}

// Carry set when the level is over (game_state set, bomb exploded or defused)
check_state: {
    lda game_state
    beq !+
    sec
    rts
!:  ldx #0
all:
    cpx nmods
    beq won
    lda m_type, x
    cmp #T_VENT
    beq nx
    lda m_solved, x
    beq notyet
nx: inx
    bne all
won:
    lda #0
    sta timer_on
    lda #2
    sta game_state
    sec
    rts
notyet:
    clc
    rts
}

nav_input: {
    lda btn_new
    sta nav_b
    lda side
    cmp #2
    bcc grid
    // on an edge face every direction turns the bomb
    ldx #0
!:  lda nav_b
    and dir_bits, x
    bne turn
    inx
    cpx #4
    bne !-
    lda nav_b
    and #B_FLIP
    bne !+
    rts
!:  ldx side
    lda home_dir - 2, x
    tax
    lda #F_FRONT
    jmp turn_to
turn:                       // X = direction
    stx tmp0
    lda side
    asl
    asl
    ora tmp0
    tay
    lda face_next, y
    jmp turn_to

grid:
    lda nav_b
    and #B_UP
    beq !+
    lda cursor
    cmp #3
    bcc up_edge
    sbc #3
    jmp move_cursor
up_edge:
    ldx #D_UP
    jmp turn
!:  lda nav_b
    and #B_DOWN
    beq !+
    lda cursor
    cmp #3
    bcs down_edge
    adc #3
    jmp move_cursor
down_edge:
    ldx #D_DOWN
    jmp turn
!:  lda nav_b
    and #B_LEFT
    beq !+
    ldx cursor
    lda col_of, x
    bne left_ok
    ldx #D_LEFT
    jmp turn
left_ok:
    dex
    txa
    jmp move_cursor
!:  lda nav_b
    and #B_RIGHT
    beq !+
    ldx cursor
    lda col_of, x
    cmp #2
    bne right_ok
    ldx #D_RIGHT
    jmp turn
right_ok:
    inx
    txa
    jmp move_cursor
!:  lda nav_b
    and #B_FLIP
    beq !+
    lda side
    eor #1
    ldx #D_RIGHT
    jmp turn_to
!:  lda nav_b
    and #B_FIRE
    beq done
    lda cursor
    clc
    adc side_base
    tax
    lda slot_mod, x
    bmi done
    tax
    lda m_solved, x
    bne done
    stx focus_mod
    lda #1
    sta mode
    Sfx(SFX_CLICK)
    lda cursor
    jsr draw_slot
    jsr draw_help
done:
    rts
}
col_of:   .byte 0, 1, 2, 0, 1, 2
dir_bits: .byte B_UP, B_DOWN, B_LEFT, B_RIGHT
// F1 on an edge face: direction that leads back to the front
home_dir: .byte D_RIGHT, D_LEFT, D_DOWN, D_UP

// A = new cursor position on this side
move_cursor: {
    pha
    lda cursor
    sta tmp5
    pla
    sta cursor
    Sfx(SFX_CLICK)
    lda tmp5
    jsr draw_slot
    lda cursor
    jmp draw_slot
}

focus_input: {
    lda btn_new
    and #B_BACK
    beq !+
    ldx focus_mod
    lda #FN_INPUT
    ldy #EV_LEAVE
    jsr call_mod
    jmp leave
!:  lda btn_new
    sta foc_b
    ldy #EV_UP
    and #B_UP
    jsr send
    ldy #EV_DOWN
    lda foc_b
    and #B_DOWN
    jsr send
    ldy #EV_LEFT
    lda foc_b
    and #B_LEFT
    jsr send
    ldy #EV_RIGHT
    lda foc_b
    and #B_RIGHT
    jsr send
    ldy #EV_FIRE
    lda foc_b
    and #B_FIRE
    jsr send
    ldy #EV_RELEASE
    lda btn_rel
    and #B_FIRE
    jsr send
    // leave automatically once solved
    ldx focus_mod
    lda m_solved, x
    beq done
leave:
    lda #0
    sta mode
    lda cursor
    jsr draw_slot
    jsr draw_help
done:
    rts

send:
    beq !+
    lda game_state          // stop after an explosion or a solve
    bne !+
    ldx focus_mod
    lda m_solved, x
    bne !+
    lda #FN_INPUT
    jmp call_mod
!:  rts
}
