; -----------------------------------------------------------
; defs.asm - hardware registers, constants, zero page, macros
; included first by main.asm
; -----------------------------------------------------------

; ---- hardware registers ----
RASTER  = $d012          ; current raster line
BORDER  = $d020          ; border color register
BG      = $d021          ; background color register
BGMC1   = $d022          ; multicolor char color 1 (bit pair 01)
BGMC2   = $d023          ; multicolor char color 2 (bit pair 10)
SCREEN  = $0400          ; screen RAM (40x25 chars)
COLRAM  = $d800          ; color RAM
SCRCTL  = $d011          ; control 1: raster msb, y-scroll
SCRCTL2 = $d016          ; control 2: multicolor, 40 columns
SPR_EN  = $d015          ; sprite enable bits
SPRX0   = $d000          ; sprite 0 x (x/y pairs go up from here)
SPRY0   = $d001          ; sprite 0 y
SPRMSB  = $d010          ; 9th x position bit of each sprite
SPRDBLY = $d017          ; sprite y expand
VMCSB   = $d018          ; memory setup: screen + charset base
SPRPRI  = $d01b          ; sprite/background priority
SPRMCEN = $d01c          ; sprite multicolor enable
SPRDBLX = $d01d          ; sprite x expand
SPRMC1  = $d025          ; sprite multicolor 1 (bit pair 01)
SPRMC2  = $d026          ; sprite multicolor 2 (bit pair 11)
SPRCOL  = $d027          ; sprite colors, 8 registers
CPUPORT = $01            ; 6510 port: ROM/RAM banking
CIA1_PA = $dc00          ; CIA1 port A: keyboard columns / joystick 2
CIA1_PB = $dc01          ; CIA1 port B: keyboard rows / joystick 1
CIA1_TA = $dc04          ; CIA1 timer A low byte: free-running entropy

CHARSET = $3800          ; RAM charset: ROM font + the custom tiles
SPRPTR  = SCREEN + $3f8  ; sprite shape pointers

; ---- SID registers (voice 1 belongs to the SFX driver) ----
SID_V1FL = $d400         ; voice 1 frequency low
SID_V1FH = $d401         ; voice 1 frequency high
SID_V1PL = $d402         ; voice 1 pulse width low
SID_V1PH = $d403         ; voice 1 pulse width high
SID_V1CR = $d404         ; voice 1 control (waveform + gate)
SID_V1AD = $d405         ; voice 1 attack/decay
SID_V1SR = $d406         ; voice 1 sustain/release
SID_VOL  = $d418         ; filter mode + master volume

; ---- SFX IDs ----
SFX_JUMP   = 0           ; a hop: rising square
SFX_DIE    = 1           ; spiked or fallen: descending saw
SFX_VANISH = 2           ; a trap bridge crumbles: noise
SFX_TRICK  = 3           ; a tricky spike leaps aside: blip
SFX_WIN    = 4           ; through the exit: rising triangle
SFX_SELECT = 5           ; title start
SFX_ALLWIN = 6           ; the last exit: a long rise
NSFX       = 7

; ---- colors ----
BLACK   = 0
WHITE   = 1
RED     = 2
CYAN    = 3
PURPLE  = 4
GREEN   = 5
BLUE    = 6
YELLOW  = 7
ORANGE  = 8
BROWN   = 9
LRED    = 10
DGREY   = 11
MGREY   = 12
LGREEN  = 13
LBLUE   = 14
LGREY   = 15

; multicolor char mode is on for every screen, so a cell whose
; color RAM value is 8-15 is drawn in multicolor: text and the
; hires tiles use colors 0-7 only, the platform cells MC + GREEN
MC      = 8
COL_PLAT = MC + GREEN    ; bit pair 11 of the platform tile: grass
COL_DIRT = BROWN         ; bit pair 01 ($d022): the dirt
COL_TURF = LGREEN        ; bit pair 10 ($d023): the lit grass edge
COL_SPIKE = RED          ; static spikes (hires chars)

; ---- joystick bits (after read_joy / read_joy2, active high) ----
JOY_UP    = 1
JOY_DOWN  = 2
JOY_LEFT  = 4
JOY_RIGHT = 8
JOY_FIRE  = 16

; ---- the playfield ----
; the original is a 20x15 grid of 40 px tiles on an 800x600
; canvas; here a tile is 2x2 chars (16 px, a 0.4 scale), so the
; 20 columns fill the 40 char columns; only the lower 12 tile
; rows (3-14) fit under the status row and every level keeps
; its top three rows empty, so the world y used below is
; counted from the top of tile row 3 (= char row 1)
LCOLS    = 20
LROWS    = 15
TOPROW   = 3             ; first tile row on screen
NLEVELS  = 10
MAXSPIKE = 12            ; static spike slots
MAXTRICK = 2             ; tricky spike slots (two sprites each)
MAXRUN   = 8             ; disappearing platform runs

; map cell values
M_EMPTY  = 0
M_SOLID  = 1
M_RUN    = $80           ; + run index: a disappearing platform

; ---- physics, the original's numbers at the 0.4 scale and 50 fps:
; move 250 px/s -> 2 px/frame, jump 480 px/s -> 3.84 px/frame,
; gravity 1500 px/s^2 -> 0.24 px/frame^2 (8.8 fixed point) ----
PW       = 12            ; player box (32 px -> 12.8)
PH       = 12
MOVESPD  = 2
GRAV     = 61            ; 0.24 * 256
JUMPV    = 983           ; 3.84 * 256
VMAX     = $0f           ; fall speed cap, px/frame (keeps one tile top per step)
XMAX     = LCOLS * 16 - PW
DIEY     = 218           ; top y below which the fall is fatal (680 px)
HIDEY    = 198           ; the sprite has left the screen
VANISH_R = 44            ; disappearing platform trigger radius (110 px)
TRICK_R  = 22            ; tricky spike trigger distance (55 px)
TRICK_D  = 40            ; tricky spike leap (100 px)
FADE_T   = 10            ; frames a trap bridge takes to crumble (200 ms)

; ---- timing ----
DIE_T    = 30            ; frames of the death flash before the retry
DONE_T   = 60            ; frames of LEVEL COMPLETED (1200 ms)
ALL_T    = 100           ; frames before the final screen takes fire
RAS_SYNC = 251           ; raster line polled for the frame sync

; ---- characters (the custom tiles live in the RAM charset) ----
CH_PTL   = $e0           ; platform tile: top-left, top-right,
CH_PTR   = $e1           ; bottom-left, bottom-right
CH_PBL   = $e2
CH_PBR   = $e3
CH_SPL   = $e4           ; spike, left / right half (hires)
CH_SPR   = $e5
CH_D1    = $e8           ; crumbling platform, first stage (4 chars)
CH_D2    = $ec           ; and second stage (4 chars)

; ---- sprites ----
SP_EYES  = 0             ; player: eyes in front...
SP_BODY  = 1             ; ...of the red body
SP_EXIT  = 2             ; exit door: multicolor body in front...
SP_FRAME = 3             ; ...of the orange frame
SP_TEYE  = 4             ; tricky spikes: eye 4, body 5 (+2 for the second)
SP_TBODY = 5

; ---- RAM above the program (the VIC never looks here) ----
MAP      = $4000         ; 15 rows x 20 cells

; ---- zero page pointers ----
mapp   = $02             ; map row pointer (2 bytes)
lvlp   = $04             ; level data pointer (2 bytes)
txtlo  = $f5             ; text pointer for the print routines (2 bytes)
txthi  = $f6
updvec = $f9             ; state update vector (2 bytes)
scrlo  = $fb
scrhi  = $fc
collo  = $fd
colhi  = $fe

; ---- helper macros: print a normal / big text line ----
!macro prtext .row, .col, .color, .txt, .len {
    lda #<.txt
    sta txtlo
    lda #>.txt
    sta txthi
    lda #.row
    sta prow
    lda #.col
    sta pcol
    lda #.color
    sta pcolor
    lda #.len
    sta plen
    jsr print_text
}

!macro prbig .row, .col, .color, .txt, .len {
    lda #<.txt
    sta txtlo
    lda #>.txt
    sta txthi
    lda #.row
    sta bigrow
    lda #.col
    sta bigcol
    lda #.color
    sta bigcolor
    lda #.len
    sta biglen
    jsr draw_big
}

; ---- set the state update vector ----
!macro setupd .addr {
    lda #<.addr
    sta updvec
    lda #>.addr
    sta updvec+1
}

; ---- leave the current screen: fade to black, then run the
; init routine of the next one ----
!macro fadeto .addr {
    lda #<.addr
    sta fadevec
    lda #>.addr
    sta fadevec+1
    jmp fade_start
}
