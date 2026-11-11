; -----------------------------------------------------------
; levels.asm - the ten levels of the original, row for row
;
; each level: the row count, the ASCII rows (20 cells, bottom
; aligned: the rows above them are empty), then the name as
; zero-terminated screen codes
;   .  empty          #  platform        P  player spawn
;   E  exit           ~  disappearing    ^  static spike
;   T  tricky spike (leaps away when the hero comes close)
; -----------------------------------------------------------

!macro level .rows {
    !byte .rows
    !if .rows > LROWS - TOPROW { !error "a level may use the lower 12 rows only" }
}

lvl_lo:
    !byte <lvl01, <lvl02, <lvl03, <lvl04, <lvl05
    !byte <lvl06, <lvl07, <lvl08, <lvl09, <lvl10
lvl_hi:
    !byte >lvl01, >lvl02, >lvl03, >lvl04, >lvl05
    !byte >lvl06, >lvl07, >lvl08, >lvl09, >lvl10

lvl01:
    +level 3
    !raw ".E........^........P"
    !raw "####################"
    !raw "####################"
    !scr "spike hop", 0

lvl02:
    +level 3
    !raw ".E.................P"
    !raw "#######~~~##########"
    !raw "#######~~~##########"
    !scr "trap bridge", 0

lvl03:
    +level 8
    !raw ".E.................."
    !raw "#####..............."
    !raw "....#####..........."
    !raw "........#####......."
    !raw "............#####..."
    !raw "...............####."
    !raw ".........T........P#"
    !raw "####################"
    !scr "trickster stairs", 0

lvl04:
    +level 3
    !raw ".E....^...^...^....P"
    !raw "####################"
    !raw "####################"
    !scr "spike field", 0

lvl05:
    +level 3
    !raw ".E.................P"
    !raw "####...######...####"
    !raw "####^^^######^^^####"
    !scr "pit crossing", 0

lvl06:
    +level 3
    !raw ".E..........T......P"
    !raw "####################"
    !raw "####################"
    !scr "trickster", 0

lvl07:
    +level 3
    !raw ".E.................P"
    !raw "####...#####...#####"
    !raw "####...#####...#####"
    !scr "bridge hopping", 0

lvl08:
    +level 3
    !raw ".E..^......T....^..P"
    !raw "####################"
    !raw "####################"
    !scr "mixed hazards", 0

lvl09:
    +level 3
    !raw ".E.................P"
    !raw "####~~~####~~~######"
    !raw "####~~~####~~~######"
    !scr "vanishing bridges", 0

lvl10:
    +level 3
    !raw ".E......T..........P"
    !raw "####...####~~~######"
    !raw "####^^^####...######"
    !scr "final gauntlet", 0
