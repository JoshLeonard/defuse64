.encoding "screencode_upper"
// ================================================================ hardware setup

// Finds the last raster line to tell PAL (50 Hz) from NTSC (60 Hz).
detect_video: {
w1: lda $d012
w2: cmp $d012
    beq w2
    bmi w1
    cmp #$20
    bcc ntsc
    lda #50
    ldx #10
    bne set
ntsc:
    lda #60
    ldx #12
set:
    sta fps
    stx morse_unit
    rts
}

init_vic: {
    lda $dd02
    ora #3
    sta $dd02
    lda $dd00
    and #$fc                // bank 3: $c000-$ffff
    sta $dd00
    lda #$02                // screen $c000, charset $c800
    sta $d018
    lda #$1b
    sta $d011
    lda #$08
    sta $d016
    lda #BLACK
    sta $d020
    lda #DGREY
    sta $d021
    lda #0
    sta $d015               // no sprites
    rts
}

// Copies the ROM character set to RAM and patches in the custom glyphs.
init_charset: {
    lda #$33
    sta $01
    ldx #0
copy:
    .for (var p = 0; p < 8; p++) {
        lda $d000 + p * 256, x
        sta CHARSET + p * 256, x
    }
    inx
    bne copy
    lda #$37
    sta $01

    lda #<glyph_data
    sta ptr3
    lda #>glyph_data
    sta ptr3 + 1
    ldx #0
glyph:
    lda glyph_codes, x
    sta tmp0
    asl
    asl
    asl
    sta ptr1
    sta ptr2
    lda tmp0
    lsr
    lsr
    lsr
    lsr
    lsr
    clc
    adc #>CHARSET
    sta ptr1 + 1
    adc #4                  // reversed copy is 128 chars later
    sta ptr2 + 1
    ldy #7
row:
    lda (ptr3), y
    sta (ptr1), y
    eor #$ff
    sta (ptr2), y
    dey
    bpl row
    lda ptr3
    clc
    adc #8
    sta ptr3
    bcc !+
    inc ptr3 + 1
!:  inx
    cpx #GLYPH_COUNT
    bne glyph
    rts
}

init_sid: {
    ldx #$18
    lda #0
!:  sta $d400, x
    dex
    bpl !-
    sta snd_dur
    sta snd_dur + 1
    sta snd_dur + 2
    lda #$0f
    sta $d418
    rts
}

init_irq: {
    lda #$7f
    sta $dc0d
    sta $dd0d
    lda $dc0d
    lda $dd0d
    lda #<irq
    sta $0314
    lda #>irq
    sta $0315
    lda #<nmi
    sta $0318
    lda #>nmi
    sta $0319
    lda #$1b
    sta $d011
    lda #$fa
    sta $d012
    lda #1
    sta $d01a
    lda #$ff
    sta $d019
    rts
}

nmi:
    rti

irq: {
    cld
    lda #$ff
    sta $d019
    inc frame
    jsr timer_irq
    jsr snd_irq
    jmp $ea81
}

// Counts the bomb timer down in BCD.  Sets sec_flag every second and
// time_up when it reaches 00:00.
timer_irq: {
    lda timer_on
    beq done
    dec tick
    bne done
    lda tick_reload
    sta tick
    lda tsec
    ora tmin
    beq out
    sed
    lda tsec
    sec
    sbc #1
    bcs store
    lda tmin
    sec
    sbc #1
    sta tmin
    lda #$59
store:
    sta tsec
    cld
    inc sec_flag
    lda tsec
    ora tmin
    bne done
out:
    lda #1
    sta time_up
done:
    rts
}

wait_frame: {
    lda frame
!:  cmp frame
    beq !-
    rts
}

// ================================================================ sound

// X = effect number
play_sfx: {
    txa
    asl
    asl
    asl
    tax
    ldy sfx_tab, x
    sei
    lda sfx_tab + 6, x
    sta snd_dur, y
    lda sfx_tab + 7, x
    sta snd_slide, y
    lda sfx_tab + 2, x
    sta snd_fhi, y
    lda sfx_tab + 3, x
    sta snd_wave, y
    lda voff, y
    tay
    lda #0
    sta $d404, y
    sta $d402, y
    lda sfx_tab + 1, x
    sta $d400, y
    lda sfx_tab + 2, x
    sta $d401, y
    lda #$08
    sta $d403, y
    lda sfx_tab + 4, x
    sta $d405, y
    lda sfx_tab + 5, x
    sta $d406, y
    lda sfx_tab + 3, x
    sta $d404, y
    cli
    rts
}

snd_irq: {
    ldx #2
loop:
    lda snd_dur, x
    beq next
    ldy voff, x
    dec snd_dur, x
    bne slide
    lda snd_wave, x
    and #$fe
    sta $d404, y
    jmp next
slide:
    lda snd_slide, x
    beq next
    clc
    adc snd_fhi, x
    sta snd_fhi, x
    sta $d401, y
next:
    dex
    bpl loop
    rts
}

voff: .byte 0, 7, 14

// voice, freq lo, freq hi, waveform, AD, SR, frames, slide
sfx_tab:
    .byte 0, $00, $50, $41, $00, $00, 2, 0      // tick
    .byte 1, $00, $06, $21, $00, $f8, 22, 0     // strike buzz
    .byte 1, $00, $50, $81, $00, $00, 3, 0      // wire cut
    .byte 1, $00, $22, $11, $00, $a4, 6, 0      // beep
    .byte 1, $00, $20, $11, $00, $a6, 14, 3     // solved chirp
    .byte 2, $00, $30, $81, $0b, $0b, 150, $ff  // explosion
    .byte 1, $00, $16, $11, $00, $f6, 14, 0     // simon red
    .byte 1, $00, $1d, $11, $00, $f6, 14, 0     // simon blue
    .byte 1, $00, $24, $11, $00, $f6, 14, 0     // simon green
    .byte 1, $00, $2c, $11, $00, $f6, 14, 0     // simon yellow
    .byte 1, $00, $18, $11, $00, $a8, 40, 1     // win
    .byte 1, $00, $38, $41, $00, $a4, 8, 0      // needy alert
    .byte 0, $00, $40, $11, $00, $00, 2, 0      // menu click
    .byte 0, $00, $80, $41, $00, $00, 2, 0      // urgent tick
    .byte 0, $00, $0c, $81, $00, $a5, 10, 6     // bomb turning

// ================================================================ random

// 16-bit xorshift, returns A
rand: {
    lda rng + 1
    lsr
    lda rng
    ror
    eor rng + 1
    sta rng + 1
    ror
    eor rng
    sta rng
    eor rng + 1
    sta rng + 1
    rts
}

// A = n, returns random 0..n-1 in A.  Preserves X and Y.
randn: {
    sta rn_n
    stx rn_x
    jsr rand
    sta rn_r
    lda #0
    ldx #8
    lsr rn_r
loop:
    bcc nb
    clc
    adc rn_n
nb: ror
    ror rn_r
    dex
    bne loop
    ldx rn_x
    rts
}

// ================================================================ input

scan_input: {
    ldx #7
scan:
    lda keys, x
    sta keys_old, x
    lda colsel, x
    sta $dc00
    lda $dc01
    eor #$ff
    sta keys, x
    eor keys_old, x
    and keys, x
    sta keys_new, x
    dex
    bpl scan
    lda #$ff
    sta $dc00
    lda $dc00
    eor #$ff
    and #$1f
    sta tmp0                // joystick bits match B_UP..B_FIRE

    lda keys + 1            // W
    and #$02
    beq !+
    lda #B_UP
    ora tmp0
    sta tmp0
!:  lda keys + 1            // A
    and #$04
    beq !+
    lda #B_LEFT
    ora tmp0
    sta tmp0
!:  lda keys + 1            // S
    and #$20
    beq !+
    lda #B_DOWN
    ora tmp0
    sta tmp0
!:  lda keys + 2            // D
    and #$04
    beq !+
    lda #B_RIGHT
    ora tmp0
    sta tmp0
!:  lda keys + 1            // shift state for cursor keys
    and #$80
    sta tmp1
    lda keys + 6
    and #$10
    ora tmp1
    sta tmp1
    lda keys                // CRSR down / up
    and #$80
    beq crsr_lr
    lda tmp1
    beq !+
    lda #B_UP
    .byte $2c
!:  lda #B_DOWN
    ora tmp0
    sta tmp0
crsr_lr:
    lda keys                // CRSR right / left
    and #$04
    beq fire
    lda tmp1
    beq !+
    lda #B_LEFT
    .byte $2c
!:  lda #B_RIGHT
    ora tmp0
    sta tmp0
fire:
    lda keys                // RETURN
    and #$02
    sta tmp1
    lda keys + 7            // SPACE
    and #$10
    ora tmp1
    beq back
    lda #B_FIRE
    ora tmp0
    sta tmp0
back:
    lda keys                // DEL
    and #$01
    sta tmp1
    lda keys + 7            // left arrow
    and #$02
    ora tmp1
    beq flip
    lda #B_BACK
    ora tmp0
    sta tmp0
flip:
    lda keys                // F1
    and #$10
    sta tmp1
    lda keys + 2            // F
    and #$20
    ora tmp1
    beq done
    lda #B_FLIP
    ora tmp0
    sta tmp0
done:
    lda inject_frames       // test hook: buttons forced from the monitor
    beq !+
    dec inject_frames
    lda inject
    ora tmp0
    sta tmp0
!:  lda btn
    eor #$ff
    and tmp0
    sta btn_new
    lda tmp0
    eor #$ff
    and btn
    sta btn_rel
    lda tmp0
    sta btn
    rts
}

// Returns the matrix index (0-63) of a newly pressed key, or $ff.
get_key: {
    ldx #7
find:
    lda keys_new, x
    bne found
    dex
    bpl find
    lda #$ff
    rts
found:
    ldy #0
!:  lsr
    bcs bit
    iny
    bne !-
bit:
    stx tmp0
    tya
    asl tmp0
    asl tmp0
    asl tmp0
    ora tmp0
    rts
}

// Waits for a fresh fire press (keyboard or joystick).  Stirs the RNG.
wait_fire: {
!:  jsr wait_frame
    jsr rand
    jsr scan_input
    lda btn_new
    and #B_FIRE
    beq !-
    rts
}

colsel: .byte $fe, $fd, $fb, $f7, $ef, $df, $bf, $7f

// matrix index -> screen code (letters and digits only)
keymap:
    .byte 0, 0, 0, 0, 0, 0, 0, 0
    .byte $33, $17, $01, $34, $1a, $13, $05, 0
    .byte $35, $12, $04, $36, $03, $06, $14, $18
    .byte $37, $19, $07, $38, $02, $08, $15, $16
    .byte $39, $09, $0a, $30, $0d, $0b, $0f, $0e
    .byte 0, $10, $0c, 0, 0, 0, 0, 0
    .byte 0, 0, 0, 0, 0, 0, 0, 0
    .byte $31, 0, 0, $32, 0, 0, $11, 0

// ================================================================ screen

rowlo: .fill 25, <(SCREEN + i * 40)
rowhi: .fill 25, >(SCREEN + i * 40)

// Drawing normally goes to the visible screen.  render_offscreen sends
// plot/print to the buffer at OFF_SCR/OFF_COL instead (used to build a
// bomb face before it slides into view).
render_screen: {
    lda #0
    sta scr_adj
    lda #COLOFS
    sta colofs
    rts
}

render_offscreen: {
    lda #((>NEW_SCR) - (>SCREEN)) & $ff
    sta scr_adj
    lda #(>NEW_COL) - (>NEW_SCR)
    sta colofs
    rts
}

// clears rows 4-23 of the current render target
clear_area: {
    ldx #4
row:
    lda rowlo, x
    sta ptr2
    lda rowhi, x
    clc
    adc scr_adj
    sta ptr2 + 1
    clc
    adc colofs
    sta ptr3 + 1
    lda ptr2
    sta ptr3
    ldy #39
!:  lda #$20
    sta (ptr2), y
    lda #DGREY
    sta (ptr3), y
    dey
    bpl !-
    inx
    cpx #24
    bne row
    rts
}

// A = colour.  Clears the whole screen.
clear_screen: {
    ldx #0
!:  sta COLRAM, x
    sta COLRAM + $100, x
    sta COLRAM + $200, x
    sta COLRAM + $2e8, x
    inx
    bne !-
    lda #$20
!:  sta SCREEN, x
    sta SCREEN + $100, x
    sta SCREEN + $200, x
    sta SCREEN + $2e8, x
    inx
    bne !-
    rts
}

// A = char, X = column, Y = row (absolute).  Colour from pcol.
// Preserves X and Y.
plot: {
    sta pl_c
    stx pl_x
    sty pl_y
    txa
    clc
    adc rowlo, y
    sta ptr2
    lda rowhi, y
    adc #0
    clc
    adc scr_adj
    sta ptr2 + 1
    jmp plot_tail
}

// Same as plot but X/Y are relative to the current panel (px0, py0).
pplot: {
    sta pl_c
    stx pl_x
    sty pl_y
    tya
    clc
    adc py0
    tay
    txa
    clc
    adc px0
    clc
    adc rowlo, y
    sta ptr2
    lda rowhi, y
    adc #0
    clc
    adc scr_adj
    sta ptr2 + 1
}
plot_tail: {
    ldy #0
    lda pl_c
    sta (ptr2), y
    lda ptr2 + 1
    clc
    adc colofs
    sta ptr2 + 1
    lda pcol
    sta (ptr2), y
    ldx pl_x
    ldy pl_y
    lda pl_c
    rts
}

// Prints the $ff-terminated string at ptr1 at absolute X/Y.  Chars are
// ORed with rvs (set rvs to $80 for reverse video).
print: {
    txa
    clc
    adc rowlo, y
    sta ptr2
    sta ptr3
    lda rowhi, y
    adc #0
    clc
    adc scr_adj
    sta ptr2 + 1
    clc
    adc colofs
    sta ptr3 + 1
    ldy #0
loop:
    lda (ptr1), y
    cmp #$ff
    beq done
    ora rvs
    sta (ptr2), y
    lda pcol
    sta (ptr3), y
    iny
    bne loop
done:
    rts
}

// print relative to the panel
pprint: {
    txa
    clc
    adc px0
    tax
    tya
    clc
    adc py0
    tay
    jmp print
}

// A = BCD byte, prints two digits at absolute X/Y
print_bcd: {
    pha
    lsr
    lsr
    lsr
    lsr
    ora #$30
    jsr plot
    inx
    pla
    and #$0f
    ora #$30
    jmp plot
}

// A = BCD byte, prints two digits relative to the panel
pprint_bcd: {
    pha
    lsr
    lsr
    lsr
    lsr
    ora #$30
    jsr pplot
    inx
    pla
    and #$0f
    ora #$30
    jmp pplot
}

// A = 0-255 binary -> dec_h, dec_t, dec_o as screen-code digits
to_dec: {
    ldx #$30
!:  cmp #100
    bcc !+
    sbc #100
    inx
    bne !-
!:  stx dec_h
    ldx #$30
!:  cmp #10
    bcc !+
    sbc #10
    inx
    bne !-
!:  stx dec_t
    ora #$30
    sta dec_o
    rts
}

// Fill a rectangle.  A = char, tmp4 = x, tmp5 = y, tmp6 = width,
// tmp7 = height (absolute), colour in pcol.
fill_rect: {
    sta tmp3
    ldy tmp5
rows:
    ldx tmp4
    lda tmp6
    sta tmp2
cols:
    lda tmp3
    jsr plot
    inx
    dec tmp2
    bne cols
    iny
    dec tmp7
    bne rows
    rts
}

// ---------------------------------------------------------------- macros

// print a literal at absolute position
.macro Text(x, y, color, txt) {
    lda #color
    sta pcol
    lda #<str
    sta ptr1
    lda #>str
    sta ptr1 + 1
    ldx #x
    ldy #y
    jsr print
    jmp over
str: .text txt
    .byte $ff
over:
}

// print a literal relative to the current panel
.macro PText(x, y, color, txt) {
    lda #color
    sta pcol
    lda #<str
    sta ptr1
    lda #>str
    sta ptr1 + 1
    ldx #x
    ldy #y
    jsr pprint
    jmp over
str: .text txt
    .byte $ff
over:
}

// print a literal relative to the panel in the current pcol
.macro PTextC(x, y, txt) {
    lda #<str
    sta ptr1
    lda #>str
    sta ptr1 + 1
    ldx #x
    ldy #y
    jsr pprint
    jmp over
str: .text txt
    .byte $ff
over:
}

.macro Sfx(n) {
    ldx #n
    jsr play_sfx
}
