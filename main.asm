; -----------------------------------------------------------
; main.asm - TRICKSTER TILES C64
;   the Commodore 64 port of Trickster Tiles, the small Phaser
;   platformer: hop, jump and outwit moving spikes and
;   disappearing tiles across ten levels; the levels, the
;   physics and the traps follow the original at a 0.4 scale
;
; Files:
;   defs.asm    - constants, zero page, macros
;   intro.asm   - TTG boot logo (ported from rabbitc64)
;   title.asm   - title screen
;   play.asm    - the game itself: physics, traps, level flow
;   levels.asm  - the ten levels, as in the original
;   common.asm  - shared routines, input, texts, big font
;   sound.asm   - single-voice SFX driver
;   gfx.asm     - RAM charset, tiles, sprites, fades
;   script.asm  - test builds only: scripted joystick
;
; Build: acme -f cbm -o trickster-tiles-c64.prg main.asm
; -----------------------------------------------------------

* = $0801

; ---- BASIC stub: 10 SYS 2064 ----
!byte $0c, $08          ; address of next line
!byte $0a, $00          ; line number: 10
!byte $9e               ; SYS token
!byte $20, $32, $30, $36, $34   ; " 2064"
!byte $00               ; end of line
!byte $00, $00          ; end of program

* = $0810                ; = 2064 in decimal

!src "defs.asm"

start:
    sei                  ; no KERNAL IRQ - raster polling must not jitter
    cld
    ldx #$ff
    txs
    lda #BLACK
    sta BORDER
    sta BG
    lda #0
    sta SPR_EN
    sta framectr
    sta fheld
    jsr gfx_init         ; RAM charset + VIC + sprite registers
    jsr sfx_init

!ifdef AUTOLEVEL {       ; test builds boot straight into a level
    lda #AUTOLEVEL - 1
    sta level
    jsr level_init
} else {
!ifdef AUTOTITLE {
    jsr title_init
} else {
    jsr intro_init       ; TTG logo, then the title screen
}
}

; ============================================================
; main loop - one state update per PAL frame, synced to the
; raster beam in the lower border
; ============================================================
main:
    jsr wait_frame       ; raster line RAS_SYNC, once a frame
    lda bflash           ; border: flash, else black
    beq mb_base
    dec bflash
    lda bcolor
    jmp mb_border
mb_base:
    lda #BLACK
mb_border:
    cmp bshown           ; a write to a color register can leave
    beq mb_same          ; a grey dot on the newer VIC chips:
    sta BORDER           ; only touch it when the color changes
    sta bshown
mb_same:
    inc framectr
    jsr sfx_update
!ifdef SCRIPT {
    jsr script_tick      ; test builds: the scripted joystick
}
    jsr call_update
    jmp main

call_update:
    jmp (updvec)         ; each update runs exactly one frame, ends with rts

bshown: !byte BLACK      ; the border color on screen

; ---- wait for raster line RAS_SYNC (leave it first, so a
; fast update cannot run twice in the same frame) ----
wait_frame:
    lda RASTER
    cmp #RAS_SYNC
    beq wait_frame
wf_hit:
    lda RASTER
    cmp #RAS_SYNC
    bne wf_hit
    rts

; ============================================================
; the states and everything they share
; ============================================================
!src "intro.asm"
!src "title.asm"
!src "play.asm"
!src "levels.asm"
!src "common.asm"
!src "sound.asm"
!ifdef SCRIPT {
!src "script.asm"
}
!src "gfx.asm"
