// ================================================================ variables

// timing
fps:          .byte 0
morse_unit:   .byte 0
timer_on:     .byte 0
tick:         .byte 0
tick_reload:  .byte 0
tmin:         .byte 0       // BCD
tsec:         .byte 0       // BCD
sec_flag:     .byte 0
time_up:      .byte 0

// sound
snd_dur:      .byte 0, 0, 0
snd_slide:    .byte 0, 0, 0
snd_fhi:      .byte 0, 0, 0
snd_wave:     .byte 0, 0, 0

// input
inject:       .byte 0
inject_frames: .byte 0
keys:         .fill 8, 0
keys_old:     .fill 8, 0
keys_new:     .fill 8, 0
btn:          .byte 0
btn_new:      .byte 0
btn_rel:      .byte 0

// printing
dec_h:        .byte 0
dec_t:        .byte 0
dec_o:        .byte 0

// game
level:        .byte 0
tier:         .byte 0
strikes:      .byte 0
max_strikes:  .byte 0
game_state:   .byte 0       // 0 playing, 1 exploded, 2 defused
boom_reason:  .byte 0       // 1 strikes, 2 time
flash_t:      .byte 0
code_len:     .byte 0
code_buf:     .fill 4, 0

// edgework
serial:       .fill 6, 0
serial_odd:   .byte 0
has_vowel:    .byte 0
batteries:    .byte 0
ports:        .byte 0       // bit0 PAR, bit1 SER, bit2 PS2, bit3 RJ45
has_par:      .byte 0
ind_count:    .byte 0
ind_label:    .fill 3, 0
ind_lit:      .fill 3, 0
lit_frk:      .byte 0
lit_sig:      .byte 0

// bomb layout
nmods:        .byte 0
m_type:       .fill MAXMODS, 0
m_slot:       .fill MAXMODS, 0
m_solved:     .fill MAXMODS, 0
slot_mod:     .fill MAXMODS, 0
side:         .byte 0
side_base:    .byte 0
cursor:       .byte 0
mode:         .byte 0       // 0 = choosing a module, 1 = working on one
focus_mod:    .byte 0

// module call state
cur_mod:      .byte 0
mfn:          .byte 0
mevt:         .byte 0
needdraw:     .byte 0
infocus:      .byte 0
visible:      .byte 0
loop_i:       .byte 0
upd_i:        .byte 0
ds_i:         .byte 0
nav_b:        .byte 0
foc_b:        .byte 0

// edgework on the edge faces
ed_n:         .byte 0
ed_type:      .fill 12, 0
ed_face:      .fill 12, 0
ed_x:         .fill 12, 0
face_used:    .fill 4, 0
ed_cur:       .byte 0
ed_base:      .byte 0
ed_i:         .byte 0
ed_wx:        .byte 0
ed_t:         .byte 0

// turning animation
tf_face:      .byte 0
tf_dir:       .byte 0
an_o:         .byte 0
an_i:         .byte 0
cs_sr:        .byte 0
cs_sc:        .byte 0
cs_dr:        .byte 0
cs_dc:        .byte 0
cs_len:       .byte 0
cs_sbs:       .byte 0
cs_sbc:       .byte 0
cs_dbs:       .byte 0
cs_dbc:       .byte 0

W:            .fill MDSIZE, 0
mdata:        .fill MAXMODS * MDSIZE, 0
