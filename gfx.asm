; -----------------------------------------------------------
; gfx.asm - the graphics layer:
;   - the ROM font is copied into RAM and the custom tiles are
;     stamped over it: the platform (multicolor, grass on dirt,
;     2x2 chars), its two crumbling stages, the spike (hires)
;   - the shared colors and a sprite placer
;   - fade to black: the transition between two screens
;   - the sprite shapes: the hero, the exit door, the tricky
;     spike, drawn after the original's SVGs at a 0.4 scale
; -----------------------------------------------------------

; ---- one-time setup: font to RAM, custom tiles, VIC ----
gfx_init:
    lda #$33             ; char ROM in at $d000 (I/O out briefly)
    sta CPUPORT
    lda #$d0
    sta txthi
    lda #>CHARSET
    sta scrhi
    lda #0
    sta txtlo
    sta scrlo
    ldx #8               ; 2 KB: the full uppercase set
gc_page:
    ldy #0
gc_byte:
    lda (txtlo),y
    sta (scrlo),y
    iny
    bne gc_byte
    inc txthi
    inc scrhi
    dex
    bne gc_page
    lda #$37             ; I/O back in
    sta CPUPORT
    ldx #6*8-1           ; the platform's four chars + the spike
gc_tiles:
    lda tile_gfx,x
    sta CHARSET+CH_PTL*8,x
    dex
    bpl gc_tiles
    ldx #4*8-1           ; the crumbling stages: the platform
gc_dither:               ; masked down to a checker, then specks
    txa
    and #3
    tay
    lda tile_gfx,x
    and dither2,y
    sta CHARSET+CH_D2*8,x
    txa
    and #1
    tay
    lda tile_gfx,x
    and dither1,y
    sta CHARSET+CH_D1*8,x
    dex
    bpl gc_dither
    ; VIC: screen at $0400, charset at $3800, multicolor chars
    lda #$1e
    sta VMCSB
    lda #$18
    sta SCRCTL2
    lda #0
    sta SPRDBLX
    sta SPRPRI           ; sprites in front of the chars
    sta SPRMSB
    rts

; ---- the shared colors (a fade darkens them, every screen
; sets them back) ----
gfx_colors:
    lda #BLACK
    sta BG
    lda #COL_DIRT
    sta BGMC1
    lda #COL_TURF
    sta BGMC2
    lda #BLACK
    sta SPRMC1
    lda #WHITE
    sta SPRMC2
    ldx #7
gcl_spr:
    lda sprcols,x
    sta SPRCOL,x
    dex
    bpl gcl_spr
    lda #1 << SP_EXIT
    sta SPRMCEN
    lda #(1 << SP_EXIT) | (1 << SP_FRAME)
    sta SPRDBLY          ; the door is 32 lines tall
    rts

sprcols:                 ; eyes, body, door, frame, two tricky spikes
    !byte WHITE, RED, YELLOW, ORANGE, WHITE, ORANGE, WHITE, ORANGE

; ---- put sprite X at spx_l/spx_h, spy ----
spr_put:
    txa
    asl
    tay
    lda spx_l
    sta SPRX0,y
    lda spy
    sta SPRY0,y
    lda spx_h
    and #1
    beq sp_low
    lda SPRMSB
    ora sprbit,x
    sta SPRMSB
    rts
sp_low:
    lda sprbit,x
    eor #$ff
    and SPRMSB
    sta SPRMSB
    rts

sprbit: !byte 1, 2, 4, 8, 16, 32, 64, 128

; ============================================================
; fade to black - six passes walk every color RAM cell (and
; the sprite and shared colors) down the luminance chains,
; half a screen per frame; then control jumps to the init
; routine the +fadeto macro left in fadevec
; ============================================================
fade_start:
    lda #0
    sta bflash
    sta fadecnt
    sta fadehalf
    +setupd fade_update
    rts

fade_update:
    lda fadehalf         ; half the color RAM per frame
    eor #1
    sta fadehalf
    bne fu_hi
    ldx #0
fu_lo:
    lda COLRAM,x
    and #15
    tay
    lda fadecell,y
    sta COLRAM,x
    lda COLRAM+$100,x
    and #15
    tay
    lda fadecell,y
    sta COLRAM+$100,x
    inx
    bne fu_lo
    rts
fu_hi:
    ldx #0
fu_hi2:
    lda COLRAM+$200,x
    and #15
    tay
    lda fadecell,y
    sta COLRAM+$200,x
    lda COLRAM+$2e8,x
    and #15
    tay
    lda fadecell,y
    sta COLRAM+$2e8,x
    inx
    bne fu_hi2
    ldx #7               ; the sprites sink with the screen
fu_spr:
    lda SPRCOL,x
    jsr fade_reg
    sta SPRCOL,x
    dex
    bpl fu_spr
    lda BGMC1            ; and so do the shared colors
    jsr fade_reg
    sta BGMC1
    lda BGMC2
    jsr fade_reg
    sta BGMC2
    lda SPRMC2
    jsr fade_reg
    sta SPRMC2
    inc fadecnt
    lda fadecnt
    cmp #6               ; the longest chain is black after 5
    bne fu_stay
    lda #0
    sta SPR_EN
    jmp (fadevec)        ; its rts returns to the main loop
fu_stay:
    rts

fade_reg:
    and #15
    tay
    lda fadetbl,y
    rts

; a color register, one step darker
fadetbl:
    !byte $00, $0f, $09, $0c, $0b, $0b, $00, $08
    !byte $02, $00, $02, $00, $0b, $05, $06, $0c

; a color RAM cell, one step darker - multicolor mode is on, so
; a hires cell (0-7) stays hires and a multicolor cell (8-15)
; stays multicolor while it darkens
fadecell:
    !byte BLACK, YELLOW, BLACK, GREEN, BLUE, BLUE, BLACK, RED
    !byte MC+BLACK, MC+YELLOW, MC+BLACK, MC+GREEN, MC+BLUE, MC+BLUE, MC+BLACK, MC+RED

; ---- graphics layer variables ----
spx_l:    !byte 0        ; spr_put input: x (9 bit), y
spx_h:    !byte 0
spy:      !byte 0
bflash:   !byte 0        ; border flash: frames left + color
bcolor:   !byte 0
fadevec:  !byte 0, 0     ; where fade_update jumps when done
fadecnt:  !byte 0        ; fade passes completed
fadehalf: !byte 0        ; which color RAM half is next

!if (fadevec & 255) = 255 { !error "fadevec must not straddle a page" }

; ---- the crumbling masks (multicolor pixels are bit pairs) ----
dither1: !byte %11001100, %00110011
dither2: !byte %11000000, %00001100, %00110000, %00000011

; ---- the custom tiles ----
; the platform after platform.svg: a lit grass edge (10, $d023),
; grass with dark tufts (11, the cell color), dirt (01, $d022)
; with dark stones; one 16x16 tile = 2x2 multicolor chars
tile_gfx:
                         ; CH_PTL: top-left
    !byte %10101010   ; LLLL
    !byte %11001100   ; G.G.
    !byte %11111111   ; GGGG
    !byte %01010101   ; BBBB
    !byte %01010101   ; BBBB
    !byte %01000101   ; B.BB
    !byte %01000101   ; B.BB
    !byte %01010101   ; BBBB
                         ; CH_PTR: top-right
    !byte %10101010   ; LLLL
    !byte %11110011   ; GG.G
    !byte %11111111   ; GGGG
    !byte %01010101   ; BBBB
    !byte %01010101   ; BBBB
    !byte %01010101   ; BBBB
    !byte %01010101   ; BBBB
    !byte %01010101   ; BBBB
                         ; CH_PBL: bottom-left
    !byte %01010101   ; BBBB
    !byte %01010101   ; BBBB
    !byte %01010101   ; BBBB
    !byte %01010001   ; BB.B
    !byte %01010001   ; BB.B
    !byte %01010101   ; BBBB
    !byte %01010101   ; BBBB
    !byte %01010101   ; BBBB
                         ; CH_PBR: bottom-right
    !byte %00010101   ; .BBB
    !byte %00010101   ; .BBB
    !byte %01010101   ; BBBB
    !byte %01010101   ; BBBB
    !byte %01010101   ; BBBB
    !byte %01010001   ; BB.B
    !byte %01010001   ; BB.B
    !byte %01010101   ; BBBB
                         ; CH_SPL / CH_SPR: a spike after
                         ; spike-normal.svg, hires (the lower
                         ; half of its cell)
    !byte %..#....#
    !byte %..#....#
    !byte %.###..##
    !byte %.###..##
    !byte %#####.##
    !byte %#####.##
    !byte %########
    !byte %########
    !byte %#....#..
    !byte %#....#..
    !byte %##..###.
    !byte %##..###.
    !byte %##.#####
    !byte %##.#####
    !byte %########
    !byte %########

; ---- sprite shapes; the VIC sees the char ROM shadow under
; $2000, so they never start below it ----
!if * < $2000 { !fill $2000 - *, 0 }
!align 63, 0

; the hero after player.svg: the red body...
spr_body:
    !byte %########, %####...., %........   ; RRRRRRRRRRRR
    !byte %########, %####...., %........   ; RRRRRRRRRRRR
    !byte %########, %####...., %........   ; RRRRRRRRRRRR
    !byte %###..##., %.###...., %........   ; RRRWWRRWWRRR
    !byte %###..##., %.###...., %........   ; RRRW.RRW.RRR
    !byte %###..##., %.###...., %........   ; RRRW.RRW.RRR
    !byte %########, %####...., %........   ; RRRRRRRRRRRR
    !byte %########, %####...., %........   ; RRRRRRRRRRRR
    !byte %####...., %####...., %........   ; RRRR....RRRR
    !byte %########, %####...., %........   ; RRRRRRRRRRRR
    !byte %########, %####...., %........   ; RRRRRRRRRRRR
    !byte %########, %####...., %........   ; RRRRRRRRRRRR
    !byte %........, %........, %........
    !byte %........, %........, %........
    !byte %........, %........, %........
    !byte %........, %........, %........
    !byte %........, %........, %........
    !byte %........, %........, %........
    !byte %........, %........, %........
    !byte %........, %........, %........
    !byte %........, %........, %........
    !byte 0
; ...his eyes, looking right...
spr_eyer:
    !byte %........, %........, %........   ; RRRRRRRRRRRR
    !byte %........, %........, %........   ; RRRRRRRRRRRR
    !byte %........, %........, %........   ; RRRRRRRRRRRR
    !byte %...##..#, %#......., %........   ; RRRWWRRWWRRR
    !byte %...#...#, %........, %........   ; RRRW.RRW.RRR
    !byte %...#...#, %........, %........   ; RRRW.RRW.RRR
    !byte %........, %........, %........   ; RRRRRRRRRRRR
    !byte %........, %........, %........   ; RRRRRRRRRRRR
    !byte %........, %........, %........   ; RRRR....RRRR
    !byte %........, %........, %........   ; RRRRRRRRRRRR
    !byte %........, %........, %........   ; RRRRRRRRRRRR
    !byte %........, %........, %........   ; RRRRRRRRRRRR
    !byte %........, %........, %........
    !byte %........, %........, %........
    !byte %........, %........, %........
    !byte %........, %........, %........
    !byte %........, %........, %........
    !byte %........, %........, %........
    !byte %........, %........, %........
    !byte %........, %........, %........
    !byte %........, %........, %........
    !byte 0
; ...and left
spr_eyel:
    !byte %........, %........, %........   ; RRRRRRRRRRRR
    !byte %........, %........, %........   ; RRRRRRRRRRRR
    !byte %........, %........, %........   ; RRRRRRRRRRRR
    !byte %...##..#, %#......., %........   ; RRRWWRRWWRRR
    !byte %....#..., %#......., %........   ; RRR.WRR.WRRR
    !byte %....#..., %#......., %........   ; RRR.WRR.WRRR
    !byte %........, %........, %........   ; RRRRRRRRRRRR
    !byte %........, %........, %........   ; RRRRRRRRRRRR
    !byte %........, %........, %........   ; RRRR....RRRR
    !byte %........, %........, %........   ; RRRRRRRRRRRR
    !byte %........, %........, %........   ; RRRRRRRRRRRR
    !byte %........, %........, %........   ; RRRRRRRRRRRR
    !byte %........, %........, %........
    !byte %........, %........, %........
    !byte %........, %........, %........
    !byte %........, %........, %........
    !byte %........, %........, %........
    !byte %........, %........, %........
    !byte %........, %........, %........
    !byte %........, %........, %........
    !byte %........, %........, %........
    !byte 0
; the exit door after exit.svg: the gold frame (y expanded)...
spr_frame:
    !byte %########, %########, %........   ; ################
    !byte %########, %########, %........   ; ################
    !byte %########, %########, %........   ; ################
    !byte %########, %########, %........   ; ################
    !byte %########, %########, %........   ; ################
    !byte %########, %########, %........   ; ################
    !byte %########, %########, %........   ; ################
    !byte %########, %########, %........   ; ################
    !byte %########, %########, %........   ; ################
    !byte %########, %########, %........   ; ################
    !byte %########, %########, %........   ; ################
    !byte %########, %########, %........   ; ################
    !byte %########, %########, %........   ; ################
    !byte %########, %########, %........   ; ################
    !byte %########, %########, %........   ; ################
    !byte %########, %########, %........   ; ################
    !byte %........, %........, %........
    !byte %........, %........, %........
    !byte %........, %........, %........
    !byte %........, %........, %........
    !byte %........, %........, %........
    !byte 0
; ...and the door in front of it, multicolor: yellow, a white
; highlight, a black knob
spr_exit:
    !byte %00000000, %00000000, %00000000   ; ........
    !byte %00000000, %00000000, %00000000   ; ........
    !byte %00101110, %10101000, %00000000   ; .YWYYYY.
    !byte %00101110, %10101000, %00000000   ; .YWYYYY.
    !byte %00101110, %10101000, %00000000   ; .YWYYYY.
    !byte %00101110, %10101000, %00000000   ; .YWYYYY.
    !byte %00101110, %10101000, %00000000   ; .YWYYYY.
    !byte %00101110, %10101000, %00000000   ; .YWYYYY.
    !byte %00101110, %10101000, %00000000   ; .YWYYYY.
    !byte %00101110, %10011000, %00000000   ; .YWYYKY.
    !byte %00101110, %10101000, %00000000   ; .YWYYYY.
    !byte %00101110, %10101000, %00000000   ; .YWYYYY.
    !byte %00101110, %10101000, %00000000   ; .YWYYYY.
    !byte %00101110, %10101000, %00000000   ; .YWYYYY.
    !byte %00101110, %10101000, %00000000   ; .YWYYYY.
    !byte %00101010, %10101000, %00000000   ; .YYYYYY.
    !byte %00000000, %00000000, %00000000
    !byte %00000000, %00000000, %00000000
    !byte %00000000, %00000000, %00000000
    !byte %00000000, %00000000, %00000000
    !byte %00000000, %00000000, %00000000
    !byte 0
; the tricky spike after spike-tricky.svg: orange spikes...
spr_tbody:
    !byte %..#....#, %#....#.., %........   ; ..#....##....#..
    !byte %..#....#, %#....#.., %........   ; ..#....##....#..
    !byte %.###..##, %##..###., %........   ; .###..####..###.
    !byte %.###..##, %##..###., %........   ; .###..####..###.
    !byte %#####..., %...#####, %........   ; #####.WWWW.#####
    !byte %#####..., %...#####, %........   ; #####.W..W.#####
    !byte %########, %########, %........   ; ################
    !byte %########, %########, %........   ; ################
    !byte %........, %........, %........
    !byte %........, %........, %........
    !byte %........, %........, %........
    !byte %........, %........, %........
    !byte %........, %........, %........
    !byte %........, %........, %........
    !byte %........, %........, %........
    !byte %........, %........, %........
    !byte %........, %........, %........
    !byte %........, %........, %........
    !byte %........, %........, %........
    !byte %........, %........, %........
    !byte %........, %........, %........
    !byte 0
; ...and the white of its eye
spr_teye:
    !byte %........, %........, %........   ; ..#....##....#..
    !byte %........, %........, %........   ; ..#....##....#..
    !byte %........, %........, %........   ; .###..####..###.
    !byte %........, %........, %........   ; .###..####..###.
    !byte %......##, %##......, %........   ; #####.WWWW.#####
    !byte %......#., %.#......, %........   ; #####.W..W.#####
    !byte %........, %........, %........   ; ################
    !byte %........, %........, %........   ; ################
    !byte %........, %........, %........
    !byte %........, %........, %........
    !byte %........, %........, %........
    !byte %........, %........, %........
    !byte %........, %........, %........
    !byte %........, %........, %........
    !byte %........, %........, %........
    !byte %........, %........, %........
    !byte %........, %........, %........
    !byte %........, %........, %........
    !byte %........, %........, %........
    !byte %........, %........, %........
    !byte %........, %........, %........
    !byte 0

SPR_BODY  = spr_body DIV 64
SPR_EYER  = spr_eyer DIV 64
SPR_EYEL  = spr_eyel DIV 64
SPR_FRAME = spr_frame DIV 64
SPR_EXIT  = spr_exit DIV 64
SPR_TBODY = spr_tbody DIV 64
SPR_TEYE  = spr_teye DIV 64

!if * > CHARSET { !error "the program ran into the charset at $3800" }
