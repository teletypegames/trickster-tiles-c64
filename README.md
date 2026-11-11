# Trickster Tiles C64

The Commodore 64 port of [Trickster Tiles](../trickster-tiles), the small
Phaser pixel-art platformer (ACME + VICE, in the footsteps of
[Thread of Ariadne](../thread-of-ariadne)).

Hop, jump, and outwit moving spikes and disappearing tiles across ten
levels: Spike Hop, Trap Bridge, Trickster Stairs, Spike Field, Pit
Crossing, Trickster, Bridge Hopping, Mixed Hazards, Vanishing Bridges and
the Final Gauntlet. A spike or a fall restarts the level, the golden door
leads on to the next one.

## Controls

Joystick in either port, or the keyboard:

| action | keys                          |
|--------|-------------------------------|
| move   | `a` `d`, joystick left/right  |
| jump   | `w`, `space`, joystick up/fire |
| start  | fire, `space`, `return`       |

## The port

The levels, the physics and the traps follow the original, scaled from
its 800x600 canvas to the C64 at 0.4: a 40 px tile is 2x2 characters
(16 px), so the 20 tile columns fill the 40 character columns.

- **Screen:** the original's 15 tile rows don't fit in 25 character
  rows, but every level keeps its top three rows empty, so the lower 12
  rows sit under the status row (`LEVEL n/10 - NAME`). The platforms are
  multicolor characters after `platform.svg` (a lit grass edge, grass
  with dark tufts, dirt with stones), the static spikes hires
  characters; the hero, the exit door and the tricky spikes are
  sprites drawn after their SVGs. The hero's pupils look the way he last
  ran.
- **Physics:** at 50 frames a second the original's 250 px/s run,
  480 px/s jump and 1500 px/s² gravity become 2 px a frame, 3.84 px a
  frame and 0.24 px a frame² (8.8 fixed point), so a jump is just under
  two tiles high and four tiles long, as in the original. The platforms
  are one-way, as there: the hero lands on a tile top only while
  falling, and walls do not stop him.
- **Traps:** a disappearing run vanishes when the hero's center comes
  within 44 px of the run's center (110 px), crumbling through two
  dither stages in 200 ms; a tricky spike leaps 40 px (100 px) away from
  the hero when he is within 22 px of it sideways (55 px).
- **Additions:** the original is silent and restarts at once; the port
  has sound effects (jump, crumble, leap, death, exit), a short death
  flash before the retry, the TTG boot logo, fades between the screens,
  and after the last level `PRESS FIRE` returns to the title.

## Build

```sh
make deps    # macOS: brew install acme vice
make         # trickster-tiles-c64.prg
make run     # in VICE (x64sc)
```

The CI (`.woodpecker.yaml`, `platform: c64`) gets its pipeline from the
update server: it assembles `main.asm` with ACME, packs the browser and
native players, and publishes a release on every push to `master`. A new
version is a `metadata.json` version bump and a push.

## Testing

Test builds take ACME defines:

| define          | effect                                              |
|-----------------|-----------------------------------------------------|
| `-DAUTOLEVEL=n` | boot straight into level `n` (`make level L=n`)     |
| `-DAUTOTITLE=1` | boot straight into the title screen                 |
| `-DSCRIPT=n`    | the joystick plays a table from `script.asm`        |
| `-DDEBUG=1`     | the hero's x and y, the exit and the run count as hex in the status row |

`SCRIPT=1`..`10` solves that level (`make solve L=n`), `11` runs into
the first spike, `12` walks under the tricky spike of level 6, `13`
starts the game from the title (with `AUTOTITLE`), `14` finishes level
10 and returns to the title. Headless, a run ends in a screenshot:

```sh
acme -DAUTOLEVEL=4 -DSCRIPT=4 -f cbm -o t.prg main.asm
x64sc -default -autostartprgmode 1 -autostart t.prg \
      -limitcycles 11000000 -exitscreenshot t.png +sound -warp
```

A solved level shows the next level's name in the status row.

## Files

| file         | contents                                         |
|--------------|--------------------------------------------------|
| `main.asm`   | BASIC stub, setup, main loop                     |
| `defs.asm`   | registers, constants, zero page, macros          |
| `intro.asm`  | the TTG boot logo                                |
| `title.asm`  | the title screen                                 |
| `play.asm`   | physics, traps, level loading and drawing        |
| `levels.asm` | the ten levels as ASCII rows, as in the original |
| `common.asm` | input, text printing, the big block font         |
| `sound.asm`  | the SFX driver                                   |
| `gfx.asm`    | charset, tiles, sprites, fades                   |
| `script.asm` | test builds only: the scripted joystick          |

## License

MIT
