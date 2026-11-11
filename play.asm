; -----------------------------------------------------------
; play.asm - the game: the original's GameScene at a 0.4 scale
;
; world coordinates: x in pixels from the left edge (0-319,
; 16 bit), y in pixels from the top of tile row 3 (8 bit), so
; char row = y / 8 + 1 and a sprite sits at (x + 24, y + 58)
;
; the rules, as in the original:
;   - platforms are one-way: the hero lands on a tile top only
;     while falling and only if his feet were above it a frame
;     earlier; walls do not stop him
;   - a jump starts only from the ground, on a fresh press
;   - a disappearing run vanishes when the hero's center comes
;     within 44 px of the run's center (110 px)
;   - a tricky spike leaps 40 px away (100 px) when the hero is
;     within 22 px of it sideways (55 px), at any height
;   - a spike or the fall below the screen restarts the level,
;     the exit leads on to the next one
; -----------------------------------------------------------

; ============================================================
; level start (also the restart after a death)
; ============================================================
level_init:
    lda #0
    sta SPR_EN
    jsr clear_screen
    jsr gfx_colors
    jsr load_level
    jsr draw_level
    jsr draw_hud

    ; the hero: centered on the P cell, feet on its bottom edge
    lda spawnc
    jsr colx
    lda tmpl
    clc
    adc #(16 - PW) / 2
    sta pxl
    lda tmph
    adc #0
    sta pxh
    lda spawnr
    jsr rowy
    clc
    adc #16 - PH
    sta py
    lda #0
    sta pyf
    sta vyl
    sta vyh
    sta onground
    sta pstate
    lda #1
    sta facing           ; he starts on the right, facing the exit

    ; the exit door: 16x32, its bottom on the E cell's bottom
    lda exitc
    jsr colx
    lda tmpl
    sta exl
    clc
    adc #24
    sta spx_l
    lda tmph
    sta exh
    adc #0
    sta spx_h
    lda exitr
    jsr rowy
    sec
    sbc #16
    sta ey
    clc
    adc #58
    sta spy
    ldx #SP_EXIT
    jsr spr_put
    ldx #SP_FRAME
    jsr spr_put
    lda #SPR_EXIT
    sta SPRPTR+SP_EXIT
    lda #SPR_FRAME
    sta SPRPTR+SP_FRAME
    lda #SPR_BODY
    sta SPRPTR+SP_BODY
    lda #SPR_TEYE
    sta SPRPTR+SP_TEYE
    sta SPRPTR+SP_TEYE+2
    lda #SPR_TBODY
    sta SPRPTR+SP_TBODY
    sta SPRPTR+SP_TBODY+2

    ; sprites on: hero, exit, one pair per tricky spike
    lda #(1 << SP_EYES) | (1 << SP_BODY) | (1 << SP_EXIT) | (1 << SP_FRAME)
    ldx ntrick
    beq li_en
    ora #(1 << SP_TEYE) | (1 << SP_TBODY)
    dex
    beq li_en
    ora #(1 << (SP_TEYE + 2)) | (1 << (SP_TBODY + 2))
li_en:
    sta sprmask
    jsr place_actors
    lda sprmask
    sta SPR_EN

    ; a jump button still held from the title or the last
    ; level must not fire a jump on the first frame
    jsr read_input
    and #JOY_UP | JOY_FIRE
    sta jprev
    +setupd play_update
    rts

; ============================================================
; the frame update
; ============================================================
play_update:
    lda pstate
    beq pu_play
    cmp #1
    bne pu_n1
    jmp dying_update
pu_n1:
    cmp #2
    bne pu_n2
    jmp done_update
pu_n2:
    jmp allclear_update
pu_play:
    jsr read_input

    ; ---- run left / right at 2 px a frame, inside the screen ----
    lda joyall
    and #JOY_LEFT
    beq pu_right
    lda #1
    sta facing
    lda pxl
    sec
    sbc #MOVESPD
    sta pxl
    lda pxh
    sbc #0
    sta pxh
    bpl pu_jump
    lda #0
    sta pxl
    sta pxh
    jmp pu_jump
pu_right:
    lda joyall
    and #JOY_RIGHT
    beq pu_jump
    lda #0
    sta facing
    lda pxl
    clc
    adc #MOVESPD
    sta pxl
    lda pxh
    adc #0
    sta pxh
    cmp #>XMAX           ; past the right edge?
    bcc pu_jump
    lda pxl
    cmp #<XMAX
    bcc pu_jump
    lda #<XMAX
    sta pxl
    lda #>XMAX
    sta pxh

    ; ---- jump: a fresh press of up / fire, from the ground ----
pu_jump:
    lda joyall
    and #JOY_UP | JOY_FIRE
    tax
    lda jprev
    eor #$ff
    stx jprev
    sta rtmp
    txa
    and rtmp
    beq pu_grav
    lda onground
    beq pu_grav
    lda #<(-JUMPV)
    sta vyl
    lda #>(-JUMPV)
    sta vyh
    lda #SFX_JUMP
    jsr sfx_play

    ; ---- gravity, with a cap on the fall speed ----
pu_grav:
    lda vyl
    clc
    adc #GRAV
    sta vyl
    lda vyh
    adc #0
    sta vyh
    bmi pu_tops          ; still rising
    cmp #VMAX
    bcc pu_tops
    lda #VMAX
    sta vyh
    lda #0
    sta vyl

    ; ---- the first tile top at or below the feet, before the move ----
pu_tops:
    lda #$ff
    sta ttop             ; $ff = none
    lda py
    cmp #200             ; far below the last row: nothing to land on
    bcs pu_move
    clc
    adc #PH
    ldx pyf
    beq pu_t1
    adc #1               ; a fraction below the pixel: round down past it
pu_t1:
    clc
    adc #15
    and #$f0
    sta ttop

    ; ---- move ----
pu_move:
    lda pyf
    clc
    adc vyl
    sta pyf
    lda py
    adc vyh
    sta py
    ldx vyh
    bmi pu_up
    bcc pu_land          ; falling, no overflow
    lda #$ff             ; past the bottom of the byte: far gone
    sta py
    jmp pu_land
pu_up:
    bcs pu_land          ; rising, still on the playfield
    lda #0               ; the top of the world stops him
    sta py
    sta pyf
    sta vyl
    sta vyh

    ; ---- landing: falling through a tile top onto a solid cell ----
pu_land:
    lda #0
    sta onground
    lda vyh
    bmi pu_react
    lda ttop
    cmp #(LROWS - TOPROW) * 16
    bcs pu_react         ; no tile top within reach
    lda py
    cmp #200
    bcs pu_react
    clc
    adc #PH              ; the feet after the move
    cmp ttop
    bcc pu_react         ; still above the top
    bne pu_lcells
    lda pyf
    beq pu_react         ; exactly touching it: not through yet
pu_lcells:
    lda ttop
    lsr
    lsr
    lsr
    lsr
    clc
    adc #TOPROW
    sta trow
    jsr px_col           ; left edge column
    sta tcol
    jsr solid_at
    bcs pu_landed
    lda pxl              ; right edge column
    clc
    adc #PW - 1
    sta tmpl
    lda pxh
    adc #0
    sta tmph
    jsr tmp_col
    sta tcol
    jsr solid_at
    bcc pu_react
pu_landed:
    lda ttop
    sec
    sbc #PH
    sta py
    lda #0
    sta pyf
    sta vyl
    sta vyh
    lda #1
    sta onground

    ; ---- the traps react to the hero ----
pu_react:
    lda py
    cmp #200
    bcs pu_hazard        ; falling out of the world
    jsr react_runs
    jsr react_tricks

    ; ---- the exit, the spikes, the fall ----
pu_hazard:
    lda exl
    sta oxl
    lda exh
    sta oxh
    lda ey
    sta oy
    lda #16
    sta ow
    lda #32
    sta oh
    jsr overlap
    bcc pu_spikes
    jmp complete_level
pu_spikes:
    lda #16
    sta ow
    lda #8
    sta oh
    ldx #0
pu_sloop:
    cpx nspike
    beq pu_tricks
    lda spkxl,x
    sta oxl
    lda spkxh,x
    sta oxh
    lda spky,x
    sta oy
    stx rtmp2
    jsr overlap
    ldx rtmp2
    bcs pu_die
    inx
    jmp pu_sloop
pu_tricks:
    ldx #0
pu_tloop:
    cpx ntrick
    beq pu_fall
    lda trkxl,x
    sta oxl
    lda trkxh,x
    sta oxh
    lda trky,x
    sta oy
    stx rtmp2
    jsr overlap
    ldx rtmp2
    bcs pu_die
    inx
    jmp pu_tloop
pu_fall:
    lda py
    cmp #DIEY
    bcs pu_die
    jsr anim_runs
!ifdef DEBUG {
    jsr debug_vars
}
    jmp place_actors
pu_die:
    jmp kill_hero

; ============================================================
; the traps
; ============================================================

; disappearing runs: start crumbling when the hero's center is
; within VANISH_R of the run's center
react_runs:
    lda pxl              ; the hero's center
    clc
    adc #PW / 2
    sta pcxl
    lda pxh
    adc #0
    sta pcxh
    lda py
    clc
    adc #PH / 2
    sta pcy
    ldx #0
rr_loop:
    cpx nrun
    bne rr_one
    rts
rr_one:
    lda runt,x
    beq rr_go
    jmp rr_next          ; already going or gone
rr_go:
    lda pcxl             ; |dx|
    sec
    sbc runcxl,x
    sta tmpl
    lda pcxh
    sbc runcxh,x
    bpl rr_dxpos
    eor #$ff
    sta tmph
    lda tmpl
    eor #$ff
    clc
    adc #1
    sta tmpl
    lda tmph
    adc #0
rr_dxpos:
    bne rr_next          ; 256+ px away
    lda tmpl
    cmp #VANISH_R
    bcs rr_next
    sta rdx
    lda pcy              ; |dy|
    sec
    sbc runcy,x
    bcs rr_dypos
    eor #$ff
    adc #1               ; carry clear here: two's complement
rr_dypos:
    cmp #VANISH_R
    bcs rr_next
    tay
    lda sqlo,y           ; dx^2 + dy^2 < VANISH_R^2 ?
    sta tmpl
    lda sqhi,y
    sta tmph
    ldy rdx
    lda sqlo,y
    clc
    adc tmpl
    sta tmpl
    lda sqhi,y
    adc tmph
    cmp #>(VANISH_R * VANISH_R)
    bcc rr_hit
    bne rr_next
    lda tmpl
    cmp #<(VANISH_R * VANISH_R)
    bcs rr_next
rr_hit:
    lda #1
    sta runt,x           ; the collision is gone from this frame on
    stx rtmp2
    lda #SFX_VANISH
    jsr sfx_play
    ldx rtmp2
rr_next:
    inx
    jmp rr_loop

; a crumbling run steps through the two dither stages to empty
anim_runs:
    ldx #0
ar_loop:
    cpx nrun
    bne ar_one
    rts
ar_one:
    lda runt,x
    beq ar_next          ; intact
    cmp #$ff
    beq ar_next          ; gone
    inc runt,x
    lda runt,x
    ldy #CH_D1
    cmp #2
    beq ar_draw
    ldy #CH_D2
    cmp #FADE_T / 2 + 2
    beq ar_draw
    cmp #FADE_T + 1
    bne ar_next
    lda #$ff
    sta runt,x
    ldy #$20             ; empty
ar_draw:
    sty tbase
    stx rtmp2
    jsr draw_run
    ldx rtmp2
ar_next:
    inx
    jmp ar_loop

; draw run X with the 2x2 tile at tbase ($20 = blank)
draw_run:
    lda runrow,x
    sec
    sbc #TOPROW
    asl
    clc
    adc #1
    sta trow
    lda runc1,x
    sta rtmp
    lda runc0,x
    sta tcol
dr_loop:
    jsr draw_tile4
    lda tcol
    cmp rtmp
    beq dr_done
    inc tcol
    jmp dr_loop
dr_done:
    rts

; tricky spikes: leap TRICK_D away from the hero when he comes
; within TRICK_R sideways
react_tricks:
    ldx #0
rt_loop:
    cpx ntrick
    bne rt_one
    rts
rt_one:
    lda trkmoved,x
    beq rt_go
    jmp rt_next
rt_go:
    lda trkxl,x          ; dx = spike center - hero center
    clc
    adc #8
    sta tmpl
    lda trkxh,x
    adc #0
    sta tmph
    lda tmpl
    sec
    sbc pcxl
    sta tmpl
    lda tmph
    sbc pcxh
    sta tmph
    bpl rt_abs
    lda tmpl             ; |dx| of a negative distance
    eor #$ff
    clc
    adc #1
    sta rdx
    lda tmph
    eor #$ff
    adc #0
    jmp rt_test
rt_abs:
    lda tmpl
    sta rdx
    lda tmph
rt_test:
    bne rt_next
    lda rdx
    cmp #TRICK_R
    bcs rt_next
    lda #1
    sta trkmoved,x
    lda tmph             ; sign of dx (0 counts as positive)
    bmi rt_left
    lda trkxl,x
    clc
    adc #TRICK_D
    sta trkxl,x
    lda trkxh,x
    adc #0
    sta trkxh,x
    jmp rt_sfx
rt_left:
    lda trkxl,x
    sec
    sbc #TRICK_D
    sta trkxl,x
    lda trkxh,x
    sbc #0
    sta trkxh,x
rt_sfx:
    stx rtmp2
    lda #SFX_TRICK
    jsr sfx_play
    ldx rtmp2
rt_next:
    inx
    jmp rt_loop

; ============================================================
; the end of a try: death, exit, the last exit
; ============================================================
kill_hero:
    lda #1
    sta pstate
    lda #DIE_T
    sta ptimer
    lda #6
    sta bflash
    lda #RED
    sta bcolor
    lda #SFX_DIE
    jsr sfx_play
    jmp place_actors

dying_update:
    lda ptimer           ; the hero blinks, then the level restarts
    and #4
    beq du_off
    lda sprmask
    jmp du_set
du_off:
    lda sprmask
    and #$ff - (1 << SP_EYES) - (1 << SP_BODY)
du_set:
    sta SPR_EN
    dec ptimer
    bne du_done
    jmp level_init
du_done:
    rts

complete_level:
    lda level
    cmp #NLEVELS - 1
    beq cl_last
    lda #2
    sta pstate
    lda #DONE_T
    sta ptimer
    +prtext 12, 12, YELLOW, txt_done, 16
    lda #SFX_WIN
    jsr sfx_play
    jmp place_actors
cl_last:
    lda #3
    sta pstate
    lda #ALL_T
    sta ptimer
    lda #1
    sta fheld            ; the jump that won must not skip the screen
    +prtext 12, 9, YELLOW, txt_alldone, 21
    lda #SFX_ALLWIN
    jsr sfx_play
    jmp place_actors

done_update:
    dec ptimer
    bne du2_done
    inc level
    +fadeto level_init
du2_done:
    rts

allclear_update:
    lda ptimer
    beq au_wait
    dec ptimer
    bne au_done
    +prtext 14, 15, WHITE, txt_fire, 10
au_wait:
    jsr start_edge
    beq au_done
    lda #SFX_SELECT
    jsr sfx_play
    +fadeto title_init
au_done:
    rts

; ============================================================
; sprites: the hero and the tricky spikes follow the world
; ============================================================
place_actors:
    lda pxl
    clc
    adc #24
    sta spx_l
    lda pxh
    adc #0
    sta spx_h
    lda py
    cmp #HIDEY
    bcc pa_show
    lda sprmask          ; gone below the screen
    and #$ff - (1 << SP_EYES) - (1 << SP_BODY)
    sta SPR_EN
    jmp pa_tricks
pa_show:
    clc
    adc #58
    sta spy
    ldx #SP_EYES
    jsr spr_put
    ldx #SP_BODY
    jsr spr_put
    lda #SPR_EYER        ; the pupils look where he last ran
    ldx facing
    beq pa_eyes
    lda #SPR_EYEL
pa_eyes:
    sta SPRPTR+SP_EYES
pa_tricks:
    ldx #0
pa_tloop:
    cpx ntrick
    beq pa_done
    lda trkxl,x
    clc
    adc #24
    sta spx_l
    lda trkxh,x
    adc #0
    sta spx_h
    lda trky,x
    clc
    adc #58
    sta spy
    stx rtmp2
    txa
    asl
    clc
    adc #SP_TEYE
    tax
    jsr spr_put
    inx
    jsr spr_put
    ldx rtmp2
    inx
    jmp pa_tloop
pa_done:
    rts

!ifdef DEBUG {
; test builds: the key variables as hex in the status row
debug_vars:
    ldy #24
    ldx #0
dv_loop:
    lda dbgsrc_lo,x
    sta txtlo
    lda dbgsrc_hi,x
    sta txthi
    stx rdx
    ldx #0
    lda (txtlo,x)
    ldx rdx
    pha
    lsr
    lsr
    lsr
    lsr
    jsr dv_hex
    pla
    and #15
    jsr dv_hex
    iny
    inx
    cpx #5
    bne dv_loop
    rts
dv_hex:
    cmp #10
    bcc dv_dig
    sbc #9               ; a-f
    !byte $2c
dv_dig:
    ora #$30
    sta SCREEN,y
    lda #WHITE
    sta COLRAM,y
    iny
    rts
dbgsrc_lo: !byte <pxl, <py, <exl, <ey, <nrun
dbgsrc_hi: !byte >pxl, >py, >exl, >ey, >nrun
}

; ============================================================
; helpers
; ============================================================

; does box (oxl/oxh, oy, ow x oh) overlap the hero's box?
; carry set = yes (edges that only touch do not count)
overlap:
    lda pxl              ; dx = hero x - object x
    sec
    sbc oxl
    sta tmpl
    lda pxh
    sbc oxh
    beq ov_xpos
    cmp #$ff
    bne ov_no
    lda tmpl             ; dx < 0: needs dx > -PW
    cmp #256 - PW + 1
    bcc ov_no
    jmp ov_y
ov_xpos:
    lda tmpl             ; dx >= 0: needs dx < ow
    cmp ow
    bcs ov_no
ov_y:
    lda py               ; dy = hero y - object y
    sec
    sbc oy
    bcc ov_yneg
    cmp oh               ; dy >= 0: needs dy < oh
    bcs ov_no
    sec
    rts
ov_yneg:
    cmp #256 - PH + 1    ; dy < 0: needs dy > -PH
    bcc ov_no
    sec
    rts
ov_no:
    clc
    rts

; is map cell (trow, tcol) solid? carry set = yes
solid_at:
    ldx trow
    lda maprowlo,x
    sta mapp
    lda maprowhi,x
    sta mapp+1
    ldy tcol
    lda (mapp),y
    beq sa_no
    bpl sa_yes           ; a plain platform
    and #$7f
    tax
    lda runt,x           ; a disappearing run while it stands
    bne sa_no
sa_yes:
    sec
    rts
sa_no:
    clc
    rts

; tile column under the hero's left edge / under tmpl/tmph
px_col:
    lda pxl
    sta tmpl
    lda pxh
    sta tmph
tmp_col:
    lda tmph
    asl
    asl
    asl
    asl
    sta rtmp
    lda tmpl
    lsr
    lsr
    lsr
    lsr
    ora rtmp
    rts

; A = tile column -> tmpl/tmph = its left x (column * 16)
colx:
    sta tmpl
    lda #0
    sta tmph
    ldx #4
cx_shift:
    asl tmpl
    rol tmph
    dex
    bne cx_shift
    rts

; A = tile row (3-14) -> A = its top y
rowy:
    sec
    sbc #TOPROW
    asl
    asl
    asl
    asl
    rts

; ============================================================
; level loading: the ASCII rows of levels.asm become the map,
; the spike and tricky spike lists, the runs, the exit and the
; spawn point
; ============================================================
load_level:
    ldx #0               ; clear the map (300 bytes)
    lda #M_EMPTY
ll_clear:
    sta MAP,x
    sta MAP+LROWS*LCOLS-256,x
    inx
    bne ll_clear
    lda #0
    sta nspike
    sta ntrick
    sta nrun
    ldx level
    lda lvl_lo,x
    sta lvlp
    lda lvl_hi,x
    sta lvlp+1
    ldy #0
    lda (lvlp),y         ; row count; the rows fill the bottom
    sta rtmp
    lda #LROWS
    sec
    sbc rtmp
    sta lrow
    inc lvlp
    bne ll_rows
    inc lvlp+1
ll_rows:
    ldx lrow
    lda maprowlo,x
    sta mapp
    lda maprowhi,x
    sta mapp+1
    lda #0
    sta lcol
    sta intilde
ll_cell:
    ldy lcol
    lda (lvlp),y
    cmp #'#'
    bne ll_n1
    lda #M_SOLID
    sta (mapp),y
    jmp ll_plain
ll_n1:
    cmp #'~'
    bne ll_n2
    jsr ll_tilde
    jmp ll_next
ll_n2:
    cmp #'^'
    bne ll_n3
    jsr ll_spike
    jmp ll_plain
ll_n3:
    cmp #'T'
    bne ll_n4
    jsr ll_trick
    jmp ll_plain
ll_n4:
    cmp #'E'
    bne ll_n5
    lda lcol
    sta exitc
    lda lrow
    sta exitr
    jmp ll_plain
ll_n5:
    cmp #'P'
    bne ll_plain
    lda lcol
    sta spawnc
    lda lrow
    sta spawnr
ll_plain:
    lda #0
    sta intilde
ll_next:
    inc lcol
    lda lcol
    cmp #LCOLS
    bne ll_cell
    lda lvlp             ; next row
    clc
    adc #LCOLS
    sta lvlp
    bcc ll_rnext
    inc lvlp+1
ll_rnext:
    inc lrow
    lda lrow
    cmp #LROWS
    beq ll_rdone
    jmp ll_rows
ll_rdone:
    lda lvlp             ; the name follows the rows
    sta namep
    lda lvlp+1
    sta namep+1
    ; the centers of the runs
    ldx #0
ll_runs:
    cpx nrun
    beq ll_done
    lda runc0,x          ; center x = (c0 + c1 + 1) * 8
    clc
    adc runc1,x
    adc #1
    sta tmpl
    lda #0
    sta tmph
    asl tmpl
    rol tmph
    asl tmpl
    rol tmph
    asl tmpl
    rol tmph
    lda tmpl
    sta runcxl,x
    lda tmph
    sta runcxh,x
    lda runrow,x         ; center y = top + 8
    jsr rowy
    clc
    adc #8
    sta runcy,x
    inx
    jmp ll_runs
ll_done:
    rts

; a '~' cell: extend the run on its left or open a new one
ll_tilde:
    ldx nrun
    lda intilde
    beq lt_new
    dex                  ; the run of the cell on the left
    lda lcol
    sta runc1,x
    jmp lt_mark
lt_new:
    cpx #MAXRUN
    bcs lt_full
    lda lrow
    sta runrow,x
    lda lcol
    sta runc0,x
    sta runc1,x
    lda #0
    sta runt,x
    inc nrun
lt_mark:
    txa
    ora #M_RUN
    ldy lcol
    sta (mapp),y
    lda #1
    sta intilde
lt_full:
    rts

; a '^' cell: a spike sits in the lower half of the cell
ll_spike:
    ldx nspike
    cpx #MAXSPIKE
    bcs ls_full
    lda lcol
    sta spkc,x
    jsr colx
    ldx nspike
    lda tmpl
    sta spkxl,x
    lda tmph
    sta spkxh,x
    lda lrow
    sta spkr,x
    jsr rowy
    clc
    adc #8
    sta spky,x
    inc nspike
ls_full:
    rts

; a 'T' cell: the same box, but a sprite that can leap
ll_trick:
    ldx ntrick
    cpx #MAXTRICK
    bcs lk_full
    lda lcol
    jsr colx
    ldx ntrick
    lda tmpl
    sta trkxl,x
    lda tmph
    sta trkxh,x
    lda lrow
    jsr rowy
    clc
    adc #8
    sta trky,x
    lda #0
    sta trkmoved,x
    inc ntrick
lk_full:
    rts

; ============================================================
; drawing
; ============================================================

; the platforms (the plain ones and the runs look the same)
; and the spikes, from the map
draw_level:
    lda #TOPROW
    sta lrow
dl_row:
    ldx lrow
    lda maprowlo,x
    sta lvlp
    lda maprowhi,x
    sta lvlp+1
    txa
    sec
    sbc #TOPROW
    asl
    clc
    adc #1
    sta trow
    lda #0
    sta tcol
dl_cell:
    ldy tcol
    lda (lvlp),y
    beq dl_next
    jsr draw_plat
dl_next:
    inc tcol
    lda tcol
    cmp #LCOLS
    bne dl_cell
    inc lrow
    lda lrow
    cmp #LROWS
    bne dl_row
    lda #COL_SPIKE       ; the spikes: the lower char row of the cell
    sta pcolor
    ldx #0
dl_spike:
    cpx nspike
    beq dl_done
    stx rtmp2
    lda spkr,x
    sec
    sbc #TOPROW
    asl
    clc
    adc #2
    sta rtmp
    lda spkc,x
    asl
    sta rdx
    tay
    ldx rtmp
    lda #CH_SPL
    jsr put_char
    ldy rdx
    iny
    ldx rtmp
    lda #CH_SPR
    jsr put_char
    ldx rtmp2
    inx
    jmp dl_spike
dl_done:
    rts

; a platform tile at char row trow, tile column tcol
draw_plat:
    lda #CH_PTL
    sta tbase
; the 2x2 tile at tbase (four consecutive chars, or $20 = blank)
draw_tile4:
    ldx trow
    jsr row_ptr
    lda tcol
    asl
    tay
    ldx tbase
    lda #COL_PLAT
    sta (collo),y
    txa
    sta (scrlo),y
    iny
    lda #COL_PLAT
    sta (collo),y
    cpx #$20
    beq dt_r1
    inx
dt_r1:
    txa
    sta (scrlo),y
    tya                  ; down a row: 40 - 1 cells on
    clc
    adc #39
    tay
    cpx #$20
    beq dt_r2
    inx
dt_r2:
    lda #COL_PLAT
    sta (collo),y
    txa
    sta (scrlo),y
    iny
    lda #COL_PLAT
    sta (collo),y
    cpx #$20
    beq dt_r3
    inx
dt_r3:
    txa
    sta (scrlo),y
    rts

; the status row: LEVEL n/10 - NAME
draw_hud:
    +prtext 0, 1, WHITE, txt_level, 6
    lda #7
    sta pcol
    lda level
    clc
    adc #1
    jsr print_num
    lda #<txt_of
    sta txtlo
    lda #>txt_of
    sta txthi
    jsr print_z
    lda namep
    sta txtlo
    lda namep+1
    sta txthi
    jmp print_z

; ---- tables ----
maprowlo:
!for r, 0, LROWS - 1 {
    !byte <(MAP + r * LCOLS)
}
maprowhi:
!for r, 0, LROWS - 1 {
    !byte >(MAP + r * LCOLS)
}

sqlo:                    ; n^2 for n < VANISH_R
!for n, 0, VANISH_R - 1 {
    !byte <(n * n)
}
sqhi:
!for n, 0, VANISH_R - 1 {
    !byte >(n * n)
}

txt_level:   !scr "level "
txt_of:      !scr "/10 - ", 0
txt_done:    !scr "level completed!"
txt_alldone: !scr "all levels completed!"
txt_fire:    !scr "press fire"

; ---- game state ----
level:    !byte 0        ; 0-9
pstate:   !byte 0        ; 0 play, 1 dying, 2 level done, 3 all done
ptimer:   !byte 0        ; frames left in states 1-3
pxl:      !byte 0        ; the hero's box: x (16 bit), y (8.8)
pxh:      !byte 0
py:       !byte 0
pyf:      !byte 0
vyl:      !byte 0        ; vertical speed, 8.8 signed
vyh:      !byte 0
onground: !byte 0        ; landed this frame (the original's touching.down)
facing:   !byte 0        ; 0 right, 1 left
jprev:    !byte 0        ; jump buttons held last frame
pcxl:     !byte 0        ; the hero's center for the traps
pcxh:     !byte 0
pcy:      !byte 0
ttop:     !byte 0        ; the tile top the feet may cross
sprmask:  !byte 0        ; the sprites this level shows
exl:      !byte 0        ; exit box
exh:      !byte 0
ey:       !byte 0
exitc:    !byte 0        ; the E and P cells
exitr:    !byte 0
spawnc:   !byte 0
spawnr:   !byte 0
oxl:      !byte 0        ; overlap: the other box
oxh:      !byte 0
oy:       !byte 0
ow:       !byte 0
oh:       !byte 0
tmpl:     !byte 0        ; scratch, 16 bit
tmph:     !byte 0
rdx:      !byte 0
trow:     !byte 0        ; drawing: char row, tile column, first char
tcol:     !byte 0
tbase:    !byte 0
lrow:     !byte 0        ; loader
lcol:     !byte 0
intilde:  !byte 0
namep:    !byte 0, 0

nspike:   !byte 0        ; static spikes: cell, box
spkc:     !fill MAXSPIKE, 0
spkr:     !fill MAXSPIKE, 0
spkxl:    !fill MAXSPIKE, 0
spkxh:    !fill MAXSPIKE, 0
spky:     !fill MAXSPIKE, 0
ntrick:   !byte 0        ; tricky spikes: box, leapt yet
trkxl:    !fill MAXTRICK, 0
trkxh:    !fill MAXTRICK, 0
trky:     !fill MAXTRICK, 0
trkmoved: !fill MAXTRICK, 0
nrun:     !byte 0        ; disappearing runs
runrow:   !fill MAXRUN, 0
runc0:    !fill MAXRUN, 0
runc1:    !fill MAXRUN, 0
runcxl:   !fill MAXRUN, 0
runcxh:   !fill MAXRUN, 0
runcy:    !fill MAXRUN, 0
runt:     !fill MAXRUN, 0 ; 0 standing, 1..FADE_T crumbling, $ff gone
