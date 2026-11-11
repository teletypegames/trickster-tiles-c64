; -----------------------------------------------------------
; title.asm - the title screen, laid out like the original's
; boot scene: TRICKSTER / TILES in big gold letters, the
; subtitle, the hero between a spike and a tricky spike, the
; blinking prompt, the controls and a strip of ground
; -----------------------------------------------------------

title_init:
    jsr clear_screen
    jsr gfx_colors
    lda #0
    sta SPR_EN

    +prbig 1, 2, YELLOW, txt_title1, 9
    +prbig 7, 10, YELLOW, txt_title2, 5
    +prtext 13, 9, CYAN, txt_sub, 22
    +prtext 20, 9, BLUE, txt_hint1, 21
    +prtext 21, 7, BLUE, txt_hint2, 26

    ; the cast: the hero, a spike, a tricky spike, 32 px apart
    lda #COL_SPIKE
    sta pcolor
    ldx #16
    ldy #19
    lda #CH_SPL
    jsr put_char
    ldx #16
    ldy #20
    lda #CH_SPR
    jsr put_char

    lda #146             ; the hero: left edge at x 122
    sta spx_l
    lda #0
    sta spx_h
    lda #174             ; standing on the spike's base line
    sta spy
    ldx #SP_EYES
    jsr spr_put
    ldx #SP_BODY
    jsr spr_put
    lda #208             ; the tricky spike at x 184
    sta spx_l
    lda #178
    sta spy
    ldx #SP_TEYE
    jsr spr_put
    ldx #SP_TBODY
    jsr spr_put
    lda #SPR_EYER
    sta SPRPTR+SP_EYES
    lda #SPR_BODY
    sta SPRPTR+SP_BODY
    lda #SPR_TEYE
    sta SPRPTR+SP_TEYE
    lda #SPR_TBODY
    sta SPRPTR+SP_TBODY
    lda #(1 << SP_EYES) | (1 << SP_BODY) | (1 << SP_TEYE) | (1 << SP_TBODY)
    sta SPR_EN

    ; a strip of ground along the bottom, as on the original
    lda #23
    sta trow
    ldx #0
ti_floor:
    stx tcol
    jsr draw_plat
    ldx tcol
    inx
    cpx #LCOLS
    bne ti_floor

    lda #0
    sta washphase
    sta blinkt
    lda #1
    sta fheld            ; a fire still held from the intro must not start
    +setupd title_update
    rts

title_update:
    inc washphase
    ldx #1
    jsr wash_rows
    ldx #7
    jsr wash_rows

    ; the prompt pulses like the original's alpha tween (1.2 s)
    inc blinkt
    lda blinkt
    cmp #60
    bcc tu_blink
    lda #0
    sta blinkt
tu_blink:
    lsr
    lsr
    tax
    lda blinktbl,x
    sta pcolor
    lda #<txt_press
    sta txtlo
    lda #>txt_press
    sta txthi
    lda #18
    sta prow
    lda #10
    sta pcol
    lda #19
    sta plen
    jsr print_text

    jsr start_edge
    beq tu_done
    lda #SFX_SELECT
    jsr sfx_play
    lda #0
    sta level
    +fadeto level_init
tu_done:
    rts

; white, dimming to a quarter and back (15 steps of 4 frames)
blinktbl:
    !byte WHITE, WHITE, WHITE, WHITE, CYAN, CYAN, BLUE, BLUE
    !byte BLUE, CYAN, CYAN, WHITE, WHITE, WHITE, WHITE

txt_title1: !scr "trickster"
txt_title2: !scr "tiles"
txt_sub:    !scr "a pixel-art platformer"
txt_press:  !scr "press fire to start"
txt_hint1:  !scr "a d or joystick: move"
txt_hint2:  !scr "w, space, up or fire: jump"

blinkt:    !byte 0       ; prompt pulse phase
