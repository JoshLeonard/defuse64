.encoding "screencode_upper"
// The bomb has six faces.  Front and back hold modules; left, right, top
// and bottom carry the edgework (serial sticker, battery holders,
// indicators and ports) which is spread randomly over them.

// [face][direction up, down, left, right] -> face that comes into view
face_next:
    .byte F_TOP, F_BOTTOM, F_LEFT, F_RIGHT      // front
    .byte F_BOTTOM, F_TOP, F_RIGHT, F_LEFT      // back
    .byte F_TOP, F_BOTTOM, F_BACK, F_FRONT      // left
    .byte F_TOP, F_BOTTOM, F_FRONT, F_BACK      // right
    .byte F_BACK, F_FRONT, F_LEFT, F_RIGHT      // top
    .byte F_FRONT, F_BACK, F_LEFT, F_RIGHT      // bottom

// ================================================================ edgework layout

// item types: 0 serial, 1/2 holder with 1/2 batteries, 3-5 indicator,
// 6-9 port (parallel, serial, ps/2, rj-45)
item_w: .byte 12, 9, 9, 7, 7, 7, 10, 10, 10, 10

add_item: {
    ldx ed_n
    sta ed_type, x
    inc ed_n
    rts
}

// Builds the item list (widest first) and scatters it over the 4 edge faces.
layout_edges: {
    lda #0
    sta ed_n
    jsr add_item            // serial sticker
    ldx #0
port:
    lda ports
    and bit_tab, x
    beq !+
    txa
    clc
    adc #6
    stx tmp1
    jsr add_item
    ldx tmp1
!:  inx
    cpx #4
    bne port
    lda batteries
    sta tmp1
bat:
    lda tmp1
    beq inds
    cmp #2
    bcc one
    jsr rand
    and #1
    beq one
    lda #2
    jsr add_item
    dec tmp1
    dec tmp1
    jmp bat
one:
    lda #1
    jsr add_item
    dec tmp1
    jmp bat
inds:
    ldx #0
!:  cpx ind_count
    beq place
    txa
    clc
    adc #3
    stx tmp1
    jsr add_item
    ldx tmp1
    inx
    bne !-
place:
    lda #0
    ldx #3
!:  sta face_used, x
    dex
    bpl !-
    ldx #0
item:
    cpx ed_n
    beq done
    ldy ed_type, x
    lda item_w, y
    sta tmp2
    lda #4
    jsr randn
    tay
try:
    lda face_used, y
    clc
    adc tmp2
    cmp #39                 // used + width <= 38
    bcc fits
    iny
    tya
    and #3
    tay
    jmp try
fits:
    tya
    sta ed_face, x
    lda face_used, y
    sta ed_x, x
    sec                     // + 1 gap
    adc tmp2
    sta face_used, y
    inx
    bne item
done:
    rts
}

// ================================================================ drawing faces

draw_face: {
    lda side
    cmp #2
    bcs !+
    jmp draw_side
!:  jmp draw_edge
}

// box outline: tmp4 = x, tmp5 = y, tmp6 = width, tmp7 = height, pcol
draw_box: {
    ldx tmp4
    ldy tmp5
    lda #$55
    jsr plot
    txa
    clc
    adc tmp6
    sta tmp3                // right edge + 1
    dec tmp3
    lda tmp5
    clc
    adc tmp7
    sta tmp2                // bottom edge + 1
    dec tmp2
    inx
!:  lda #$40
    ldy tmp5
    jsr plot
    ldy tmp2
    jsr plot
    inx
    cpx tmp3
    bne !-
    lda #$49
    ldy tmp5
    jsr plot
    lda #$4b
    ldy tmp2
    jsr plot
    ldx tmp4
    lda #$4a
    jsr plot
    ldy tmp5
!:  iny
    cpy tmp2
    beq !+
    lda #$5d
    ldx tmp4
    jsr plot
    ldx tmp3
    jsr plot
    jmp !-
!:  rts
}

// A = string number, X/Y = absolute position, pcol
wprint: {
    pha
    stx tmp0
    tax
    lda wstr_lo, x
    sta ptr1
    lda wstr_hi, x
    sta ptr1 + 1
    ldx tmp0
    pla
    jmp print
}

.var wstrs = List()
.macro WStr(txt) {
    .eval wstrs.add(*)
    .text txt
    .byte $ff
}
wstr_data:
    WStr("SERIAL NO.")
    WStr("PARALLEL")
    WStr("SERIAL")
    WStr("PS/2")
    WStr("RJ-45")
    WStr("::::::::")
    WStr("(:::::)")
    WStr("(O)")
    WStr("[==]")
    WStr("FRONT")
    WStr("BACK")
    WStr("LEFT SIDE")
    WStr("RIGHT SIDE")
    WStr("TOP")
    WStr("BOTTOM")
    WStr("NOTHING ON THIS SIDE")
wstr_lo: .fill wstrs.size(), <wstrs.get(i)
wstr_hi: .fill wstrs.size(), >wstrs.get(i)
.const WS_SERIALNO = 0
.const WS_PORTNAME = 1
.const WS_PORTPIC = 5
.const WS_FACENAME = 9
.const WS_NOTHING = 15

.const EDGE_Y = 10          // top row of the widgets

draw_edge: {
    // the casing seen edge-on
    lda #0
    sta tmp4
    lda #7
    sta tmp5
    lda #40
    sta tmp6
    lda #10
    sta tmp7
    lda #GREY
    sta pcol
    jsr draw_box
    lda side
    clc
    adc #WS_FACENAME
    ldx #2
    ldy #7
    jsr wprint
    lda side
    sec
    sbc #2
    sta ed_cur
    tax
    lda face_used, x
    bne items
    lda #GREY
    sta pcol
    lda #WS_NOTHING
    ldx #10
    ldy #11
    jmp wprint
items:
    // centre the row: base = 1 + (39 - used) / 2
    sta tmp0
    lda #39
    sec
    sbc tmp0
    lsr
    clc
    adc #1
    sta ed_base
    ldx #0
loop:
    cpx ed_n
    beq done
    lda ed_face, x
    cmp ed_cur
    bne next
    stx ed_i
    lda ed_x, x
    clc
    adc ed_base
    sta ed_wx
    lda ed_type, x
    jsr draw_widget
    ldx ed_i
next:
    inx
    bne loop
done:
    rts
}

// A = item type, drawn at ed_wx, EDGE_Y
draw_widget: {
    sta ed_t
    lda ed_wx
    sta tmp4
    lda #EDGE_Y
    sta tmp5
    ldx ed_t
    lda item_w, x
    sta tmp6
    lda ed_t
    bne !+
    jmp serial_w
!:  cmp #3
    bcs !+
    jmp holder
!:  cmp #6
    bcs port
    // indicator
    lda #3
    sta tmp7
    lda #GREY
    sta pcol
    jsr draw_box
    lda ed_t
    sec
    sbc #3
    tax
    lda #BLACK
    ldy ind_lit, x
    beq !+
    lda #YELLOW
!:  sta pcol
    lda ind_label, x
    sta tmp1
    asl
    adc tmp1
    sta tmp1                // offset into ind_names
    lda #$51
    ldx ed_wx
    inx
    ldy #EDGE_Y + 1
    jsr plot
    lda #WHITE
    sta pcol
    inx
    inx
    lda #3
    sta tmp2
!:  ldy tmp1
    lda ind_names, y
    inc tmp1
    ldy #EDGE_Y + 1
    jsr plot
    inx
    dec tmp2
    bne !-
    rts
port:
    lda #4
    sta tmp7
    lda #LBLUE
    sta pcol
    jsr draw_box
    lda #WHITE
    sta pcol
    lda ed_t
    sec
    sbc #6 - WS_PORTNAME
    ldx ed_wx
    inx
    ldy #EDGE_Y + 1
    jsr wprint
    lda #GREY
    sta pcol
    lda ed_t
    clc
    adc #WS_PORTPIC - 6
    ldx ed_wx
    inx
    ldy #EDGE_Y + 2
    jmp wprint
serial_w:
    lda #4
    sta tmp7
    lda #WHITE
    sta pcol
    jsr draw_box
    lda #LGREY
    sta pcol
    lda #WS_SERIALNO
    ldx ed_wx
    inx
    ldy #EDGE_Y + 1
    jsr wprint
    lda #YELLOW
    sta pcol
    lda ed_wx
    clc
    adc #3
    tax
    ldy #0
!:  sty tmp1
    lda serial, y
    ldy #EDGE_Y + 2
    jsr plot
    ldy tmp1
    inx
    iny
    cpy #6
    bne !-
    rts
holder:
    lda #4
    sta tmp7
    lda #GREY
    sta pcol
    jsr draw_box
    ldy #EDGE_Y + 1
    jsr battery
    lda ed_t
    cmp #2
    bne !+
    ldy #EDGE_Y + 2
    jsr battery
!:  rts
battery:                    // Y = row
    lda #ORANGE
    sta pcol
    ldx ed_wx
    inx
    inx
    lda #$a0
    jsr plot
    inx
    jsr plot
    inx
    jsr plot
    inx
    jsr plot
    inx
    lda #LGREY
    sta pcol
    lda #$7d
    jmp plot
}

// face name and the little map of the bomb in the header
draw_face_header: {
    lda #LBLUE
    sta pcol
    ldx #0
    ldy #1
!:  lda #$20
    jsr plot
    inx
    cpx #12
    bne !-
    lda side
    clc
    adc #WS_FACENAME
    ldx #0
    ldy #1
    jsr wprint
    ldx #5
!:  lda #BLACK
    cpx side
    bne !+
    lda #YELLOW
!:  sta pcol
    stx tmp0
    lda map_y, x
    tay
    lda map_x, x
    tax
    lda #$51
    jsr plot
    ldx tmp0
    dex
    bpl !--
    jmp draw_help
}
map_x: .byte 35, 39, 33, 37, 35, 35
map_y: .byte 2, 2, 2, 2, 1, 3

// ================================================================ turning

// A = new face, X = direction the bomb turns
turn_to: {
    sta tf_face
    stx tf_dir
    Sfx(SFX_TURN)
    jsr save_old
    lda side
    sta tmp1                // face we came from
    lda tf_face
    sta side
    ldx #0
    cmp #F_BACK
    bne !+
    ldx #6
!:  stx side_base
    // arriving on a module face from an edge: enter at the near side
    lda side
    cmp #2
    bcs render
    lda tmp1
    cmp #2
    bcc render
    ldx cursor
    lda col_of, x
    sta tmp0
    ldx tf_dir
    cpx #D_RIGHT
    bne !+
    lda cursor
    sec
    sbc tmp0
    jmp setc
!:  cpx #D_LEFT
    bne !+
    lda cursor
    sec
    sbc tmp0
    clc
    adc #2
    jmp setc
!:  cpx #D_DOWN
    bne !+
    lda tmp0
    jmp setc
!:  lda tmp0
    clc
    adc #3
setc:
    sta cursor
render:
    jsr render_offscreen
    jsr clear_area
    jsr draw_face
    jsr render_screen
    jsr animate
    jmp draw_face_header
}

// copies cs_len bytes (screen and colour) from (cs_sr, cs_sc) in the
// buffer at cs_sbs/cs_sbc to (cs_dr, cs_dc) in the buffer at cs_dbs/cs_dbc
copy_seg: {
    ldy cs_sr
    lda rowlo, y
    clc
    adc cs_sc
    sta ptr1
    sta ptr3
    lda rowhi, y
    adc #0
    and #3
    sta tmp0
    clc
    adc cs_sbs
    sta ptr1 + 1
    lda tmp0
    clc
    adc cs_sbc
    sta ptr3 + 1
    ldy cs_dr
    lda rowlo, y
    clc
    adc cs_dc
    sta ptr2
    sta ptr4
    lda rowhi, y
    adc #0
    and #3
    sta tmp0
    clc
    adc cs_dbs
    sta ptr2 + 1
    lda tmp0
    clc
    adc cs_dbc
    sta ptr4 + 1
    ldy cs_len
    beq done
    dey
!:  lda (ptr1), y
    sta (ptr2), y
    lda (ptr3), y
    sta (ptr4), y
    dey
    bpl !-
done:
    rts
}

.macro CopySrc(scr, col) {
    lda #>scr
    sta cs_sbs
    lda #>col
    sta cs_sbc
}

// keeps a copy of the face on screen for the animation
save_old: {
    lda #>OLD_SCR
    sta cs_dbs
    lda #>OLD_COL
    sta cs_dbc
    CopySrc(SCREEN, COLRAM)
    lda #0
    sta cs_sc
    sta cs_dc
    lda #40
    sta cs_len
    ldx #4
!:  stx cs_sr
    stx cs_dr
    jsr copy_seg
    ldx cs_sr
    inx
    cpx #24
    bne !-
    rts
}

animate: {
    lda #>SCREEN
    sta cs_dbs
    lda #>COLRAM
    sta cs_dbc
    lda #0
    sta an_o
loop:
    jsr wait_frame
    ldx tf_dir
    lda an_o
    clc
    adc an_step, x
    cmp an_max, x
    bcc !+
    lda an_max, x
!:  sta an_o
    lda tf_dir
    cmp #D_UP
    bne !+
    jsr slide_up
    jmp next
!:  cmp #D_DOWN
    bne !+
    jsr slide_down
    jmp next
!:  cmp #D_LEFT
    bne !+
    jsr slide_left
    jmp next
!:  jsr slide_right
next:
    ldx tf_dir
    lda an_o
    cmp an_max, x
    bne loop
    rts
}
an_step: .byte 2, 2, 4, 4
an_max:  .byte 20, 20, 40, 40

// new face enters from the right
slide_right: {
    ldx #4
row:
    stx cs_sr
    stx cs_dr
    lda #40
    sec
    sbc an_o
    sta cs_len
    CopySrc(OLD_SCR, OLD_COL)
    lda an_o
    sta cs_sc
    lda #0
    sta cs_dc
    jsr copy_seg
    CopySrc(NEW_SCR, NEW_COL)
    lda cs_len
    sta cs_dc
    lda an_o
    sta cs_len
    lda #0
    sta cs_sc
    jsr copy_seg
    ldx cs_sr
    inx
    cpx #24
    bne row
    rts
}

// new face enters from the left
slide_left: {
    ldx #4
row:
    stx cs_sr
    stx cs_dr
    lda #40
    sec
    sbc an_o
    sta cs_len
    CopySrc(OLD_SCR, OLD_COL)
    lda #0
    sta cs_sc
    lda an_o
    sta cs_dc
    jsr copy_seg
    CopySrc(NEW_SCR, NEW_COL)
    lda cs_len
    sta cs_sc
    lda #0
    sta cs_dc
    lda an_o
    sta cs_len
    jsr copy_seg
    ldx cs_sr
    inx
    cpx #24
    bne row
    rts
}

// new face enters from the bottom
slide_down: {
    lda #40
    sta cs_len
    lda #0
    sta cs_sc
    sta cs_dc
    ldx #0
row:
    stx an_i
    txa
    clc
    adc #4
    sta cs_dr
    txa
    clc
    adc an_o                // k = i + o
    cmp #20
    bcs new
    adc #4
    sta cs_sr
    CopySrc(OLD_SCR, OLD_COL)
    jmp copy
new:
    sec
    sbc #16                 // k - 20 + 4
    sta cs_sr
    CopySrc(NEW_SCR, NEW_COL)
copy:
    jsr copy_seg
    ldx an_i
    inx
    cpx #20
    bne row
    rts
}

// new face enters from the top
slide_up: {
    lda #40
    sta cs_len
    lda #0
    sta cs_sc
    sta cs_dc
    ldx #0
row:
    stx an_i
    txa
    clc
    adc #4
    sta cs_dr
    txa
    sec
    sbc an_o                // k = i - o
    bcc new
    adc #3                  // carry set: + 4
    sta cs_sr
    CopySrc(OLD_SCR, OLD_COL)
    jmp copy
new:
    clc
    adc #24                 // k + 20 + 4
    sta cs_sr
    CopySrc(NEW_SCR, NEW_COL)
copy:
    jsr copy_seg
    ldx an_i
    inx
    cpx #20
    bne row
    rts
}
