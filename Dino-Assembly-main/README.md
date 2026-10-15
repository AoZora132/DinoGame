# Dino (x86 Assembly)

A recreation of the Google Chrome offline Dino game in 16-bit x86 assembly (NASM), running in DOS / DOSBox. The whole game lives in a single `.asm` file.

## Status

| Feature | State |
|---|---|
| Game frame (background, border, ground) | Done |
| Dino jump (velocity + gravity) | Done |
| Fixed frame rate (about 35 FPS) | Done |
| Scrolling ground | Planned |
| Cacti obstacles | Planned |
| Birds | Planned |
| Health system | Planned |
| Power-ups | Planned |

The dino is currently a plain gray rectangle. Sprites come later.

## Planned features

- Endless runner with jump-only controls, speeding up over time
- **Cacti:** small (1 HP damage) and big (2 HP damage)
- **Birds:** high and low, only appearing after a certain score
- **Health:** 3 HP cap, stored in a memory variable
- **Power-ups:** shield (one hit, one pickup), 2x score multiplier, 6 seconds of invincibility, heart (+1 HP)
- Possible limits: score cap, speed cap

## Controls

| Key | Action |
|---|---|
| `SPACE` | Jump (only while standing) |
| `ESC` | Quit to DOS |

## Requirements

- [NASM](https://www.nasm.us/)
- [DOSBox](https://www.dosbox.com/), or an online emulator such as dosasm.com (the code has been tested there)

## Build and run

The program is a 16-bit `.COM` file (`org 100h`), so there is no linker step.

```
mkdir -Force build
nasm -f bin src/dino.asm -o build/dino.com
dosbox build/dino.com
```

Replace `dino.asm` with the name of the source file. On Windows, make sure NASM and DOSBox are on your `PATH`, or call them with their full paths.

To run without installing anything, paste the source into an online DOS assembler.

## How it works

### Video

The game uses VGA mode `13h`: 320x200 pixels, 256 colors, one byte per pixel. Video memory starts at segment `A000h`, so the pixel at (x, y) is at offset:

```
offset = y * 320 + x
```

**The origin (0,0) is the top-left corner. y grows downward.** Moving up means y gets smaller.

### Drawing

Everything is a filled rectangle drawn by one routine, `Draw_Box`. It takes its inputs in registers:

| Register | Meaning |
|---|---|
| `ax` | x (left edge) |
| `bx` | y (top edge) |
| `cx` | width |
| `dx` | height |
| `si` | color (palette index) |

`Draw_Box` changes `ax`, `bx`, `cx`, `dx` and `di`. It does not change `si`.

`Draw_Dino` is a shortcut that fills those registers for the dino. The caller only sets `si`: white to erase, gray to draw.

### Game loop

Each frame runs these steps in order:

1. `Wait_Vsync` twice (about 35 FPS)
2. Read the keyboard without blocking (`int 16h`)
3. Erase the dino at its old position
4. Update physics (only while airborne)
5. Draw the dino at its new position

Only the dino's 10x15 box is redrawn each frame. The background is drawn once at startup.

### Jump physics

Two variables drive the jump: `dino_y` (position) and `speed` (vertical velocity). Every airborne frame:

```
dino_y = dino_y + speed
speed  = speed + gravity
```

Pressing `SPACE` while on the ground sets `speed = jumpSpeed`. Because y grows downward, `jumpSpeed` is **negative** (up) and `gravity` is **positive** (down). When `dino_y` reaches `dinoStart`, the dino snaps back to the ground and `on_ground` is set again.

With the default values (`jumpSpeed = -10`, `gravity = 1`) the jump rises 55 px and lasts 21 frames, about 0.6 seconds.

### Timing

`Wait_Vsync` waits for the VGA vertical retrace (port `3DAh`, bit 3). The loop calls it twice per frame to halve the refresh rate (about 70 Hz to 35 FPS). Add or remove a call to change the speed.

## Tuning constants

| Constant | Default | Effect |
|---|---|---|
| `ground` | 150 | y of the ground line |
| `dinoStart` | 135 | Dino's y when standing. Must equal `ground` minus the dino's height |
| `dinoX` | 30 | Dino's x position |
| `jumpSpeed` | -10 | Starting speed. A bigger magnitude gives a higher jump |
| `gravity` | 1 | Speed change per frame. Bigger gives a shorter, snappier jump |

If you change the dino's height in `Draw_Dino`, update `dinoStart` to match, or the dino will float or sink.

## Code layout

| Section | Contents |
|---|---|
| Constants | Positions, physics values, colors |
| `Start` | Video mode setup and frame drawing |
| `Game_Loop` | Input, erase, update, draw |
| `Exit_Game` | Restore text mode and return to DOS |
| `Draw_Dino` | Draws the dino box |
| `Draw_Box` | Draws any filled rectangle |
| `Wait_Vsync` | Waits for one screen refresh |
| Variables | `box_width`, `dino_y`, `speed`, `on_ground` |

## Code conventions

- **NASM is case-sensitive.** `Draw_Box` and `draw_box` are different names.
- Constants: `camelCase` (`jumpSpeed`, `dinoStart`)
- Procedures and labels: `Capitalized_Snake` (`Draw_Box`, `Game_Loop`, `No_Key`)
- Variables: `lower_snake` (`dino_y`, `on_ground`)
- Comment every block, and explain any non-obvious register use.

## Troubleshooting

| Problem | Likely cause |
|---|---|
| `symbol not defined` from NASM | A name differs in capitalization from its definition |
| Black screen | Built without `-f bin`, or the output is not named `.com` |
| Dino sinks or floats | `dinoStart` does not match `ground` minus the dino height |
| Game runs too fast or too slow | Number of `Wait_Vsync` calls in `Game_Loop` |

## Roadmap

1. Scrolling ground
2. Cactus obstacles and collision
3. Health system and score
4. Birds, speed increase, and caps
5. Power-ups
6. Sprites

## Contributing

1. Keep everything in the single `.asm` file.
2. Follow the naming conventions above.
3. Test in DOSBox before opening a pull request.
4. Describe what changed and which constants or registers it affects.
