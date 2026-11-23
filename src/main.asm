// DEFUSE 64 - a cooperative bomb defusal game for the Commodore 64
// Build with KickAssembler 5.x (see build.ps1)

.encoding "screencode_upper"
#import "defs.asm"

BasicUpstart2(start)

start:
    sei
    cld
    ldx #$ff
    txs
    lda #$37
    sta $01
    jsr detect_video
    jsr init_vic
    jsr init_charset
    jsr init_sid
    jsr init_irq
    lda $d012               // seed the random generator
    eor #$5a
    sta rng
    lda #$a7
    sta rng + 1
    lda #0
    sta btn
    sta rvs
    jsr render_screen
    ldx #7
!:  sta keys, x
    dex
    bpl !-
    cli
    jmp title

#import "core.asm"
#import "bomb.asm"
#import "faces.asm"
#import "mods1.asm"
#import "mods2.asm"
#import "screens.asm"
#import "data.asm"
#import "vars.asm"

.print "program end: $" + toHexString(*)
.assert "program must end below the face buffers at $8000", * < NEW_SCR, true
