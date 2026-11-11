; -----------------------------------------------------------
; script.asm - test builds only (-DSCRIPT=n): the joystick is
; fed from a table instead of the CIA, so a headless VICE run
; plays a fixed sequence; an entry is (frames, bits), a zero
; closes the table and the last input is held from there on
; -----------------------------------------------------------

script_tick:
    lda scr_left
    bne sc_count
    ldy scr_pos
    lda script_tbl,y
    beq sc_done
    sta scr_left
    lda script_tbl+1,y
    sta scr_j1
    iny
    iny
    sty scr_pos
sc_count:
    dec scr_left
sc_done:
    rts

L  = JOY_LEFT
R  = JOY_RIGHT
LJ = JOY_LEFT + JOY_FIRE
RJ = JOY_RIGHT + JOY_FIRE
J  = JOY_FIRE

; a full jump while running left: 2 frames pressed, 33 in all,
; so the next press is a fresh one on the ground (a jump on
; the flat lands on its 32nd frame)
!macro hopl { !byte 2, LJ, 31, L }
; a hop one tile up the stairs lands sooner
!macro hopu { !byte 2, LJ, 29, L }

; SCRIPT = 1..10 solves that level (build with -DAUTOLEVEL=n),
; 11 runs into the first spike, 12 walks under the tricky spike,
; 13 starts the game from the title, 14 = 10 + back to the title
script_tbl:
!if SCRIPT = 1 {         ; spike hop
    !byte 20, 0, 58, L
    +hopl
    !byte 120, L
}
!if SCRIPT = 2 {         ; trap bridge: hop before the bridge goes
    !byte 20, 0, 66, L
    +hopl
    !byte 120, L
}
!if SCRIPT = 3 {         ; trickster stairs: onto the block, then up
    !byte 20, 0, 2, RJ, 29, R
    +hopu
    +hopu
    +hopu
    +hopu
    +hopu
    !byte 60, 0
}
!if SCRIPT = 4 {         ; spike field: three hops in a row
    !byte 20, 0, 24, L
    +hopl
    +hopl
    +hopl
    !byte 80, L
}
!if SCRIPT = 5 {         ; pit crossing
    !byte 20, 0, 22, L
    +hopl
    !byte 44, L
    +hopl
    !byte 80, L
}
!if SCRIPT = 6 {         ; trickster: let it leap, then hop it
    !byte 20, 0, 60, L
    +hopl
    !byte 120, L
}
!if SCRIPT = 7 {         ; bridge hopping
    !byte 20, 0, 36, L
    +hopl
    !byte 30, L
    +hopl
    !byte 80, L
}
!if SCRIPT = 8 {         ; mixed hazards
    !byte 20, 0, 8, L
    +hopl
    !byte 26, L
    +hopl
    +hopl
    !byte 80, L
}
!if SCRIPT = 9 {         ; vanishing bridges
    !byte 20, 0, 39, L
    +hopl
    !byte 23, L
    +hopl
    !byte 80, L
}
!if (SCRIPT = 10) | (SCRIPT = 14) {  ; final gauntlet
    !byte 20, 0, 34, L
    +hopl
    !byte 26, L
    +hopl
    !byte 80, L
}
!if SCRIPT = 14 {        ; ...then fire on the last screen: the title
    !byte 150, 0, 3, J, 10, 0
}
!if SCRIPT = 11 {        ; level 1: straight into the spike
    !byte 20, 0, 80, L
}
!if SCRIPT = 13 {        ; title: fire starts level 1 (-DAUTOTITLE)
    !byte 30, 0, 3, J, 10, 0
}
!if SCRIPT = 12 {        ; level 6: the tricky spike leaps away
    !byte 20, 0, 40, L
}
    !byte 0

scr_left: !byte 0        ; frames left of the current entry
scr_pos:  !byte 0        ; offset of the next entry
scr_j1:   !byte 0        ; the scripted joystick bits
