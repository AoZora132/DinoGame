# Dino in Assembly: Code Guide

This guide explains how the code works in simple terms. You do not need to know assembly to follow it. Read it top to bottom, or jump to the part you need.

## Contents

1. [The big picture](#1-the-big-picture)
2. [Assembly basics you need](#2-assembly-basics-you-need)
3. [How the screen works](#3-how-the-screen-works)
4. [Constants](#4-constants)
5. [Start: setting up the screen](#5-start-setting-up-the-screen)
6. [What the registers mean](#6-what-the-registers-mean)
7. [The game loop](#7-the-game-loop)
8. [How the jump works](#8-how-the-jump-works)
9. [Procedures](#9-procedures)
10. [Variables](#10-variables)
11. [Exit](#11-exit)
12. [How to change things](#12-how-to-change-things)
13. [Common mistakes](#13-common-mistakes)
14. [Glossary](#14-glossary)

---

## 1. The big picture

The program draws a white screen with a border and a ground line. A gray box (the dino) stands on the ground. Press **SPACE** to make it jump. Press **ESC** to quit.

The program does two things:

1. **Setup (runs once):** switch to graphics mode and draw the frame and the dino.
2. **Game loop (repeats forever):** every frame, check the keyboard, erase the dino, move it, and draw it again.

```
Setup
  |
  v
+-> Wait for the screen refresh (twice)
|     |
|     v
|   Check the keyboard (ESC = quit, SPACE = jump)
|     |
|     v
|   Erase the dino
|     |
|     v
|   Move the dino (only if it is in the air)
|     |
|     v
|   Draw the dino
|     |
+-----+
```

This is how animation works: draw something, wait a moment, erase it, draw it in a new spot, repeat. It looks like movement because it happens many times per second.

---

## 2. Assembly basics you need

### Registers

A register is a tiny storage slot inside the CPU. Think of them as the CPU's hands: it can only work with what it is holding.

| Register | Common use in this program |
|---|---|
| `ax` | General purpose. Holds an x position, colors, and function numbers. |
| `bx` | General purpose. Holds a y position. |
| `cx` | A counter. Holds a width. |
| `dx` | General purpose. Holds a height. |
| `si` | Carries the color to the drawing routine. |
| `di` | Points at a pixel in video memory. |
| `es` | Says which part of memory `di` points into (the screen). |

`ax` is 16 bits. It is split into two 8-bit halves: `ah` (high half) and `al` (low half).

### Instructions used

| Instruction | What it does | Example |
|---|---|---|
| `mov a, b` | Copies `b` into `a` | `mov ax, 5` |
| `add a, b` | `a = a + b` | `add [dino_y], ax` |
| `dec a` | `a = a - 1` | `dec dx` |
| `imul di, bx, 320` | `di = bx * 320` | |
| `cmp a, b` | Compares two values (remembers the result) | `cmp al, 27` |
| `jmp label` | Always jump to a label | `jmp Game_Loop` |
| `je` / `jne` | Jump if equal / not equal (after `cmp`) | `je Exit_Game` |
| `jz` / `jnz` | Jump if zero / not zero | `jnz Row_Loop` |
| `jl` | Jump if less than (signed) | `jl Skip_Move` |
| `call label` | Run a procedure, then come back | `call Draw_Box` |
| `ret` | Return to where `call` was used | |
| `int number` | Ask the BIOS or DOS to do a job | `int 10h` |
| `in al, dx` | Read a byte from a hardware port | |
| `test a, b` | Checks bits without changing anything | `test al, 8` |
| `rep stosb` | Repeat: write `al` to memory, move `di` forward | |

### Other syntax

| Syntax | Meaning |
|---|---|
| `;` | A comment. Ignored by the computer. |
| `Name:` | A **label**: a name for a spot in the code. Jumps and calls use it. |
| `name equ 5` | A **constant**: NASM replaces `name` with `5` while building. It uses no memory. |
| `dw` / `db` | Create a 2-byte / 1-byte variable. |
| `[name]` | The **value stored** in variable `name`. Without brackets it means the variable's address. |
| `word` / `byte` | The size of a memory write, used when NASM can't tell. |
| `0A000h` | A hex number (`h` at the end). If it starts with a letter, add a leading `0`. |
| `org 100h` | Says the program loads at address 256. Required for `.COM` files. |

### Calling a procedure

`call Draw_Box` jumps to `Draw_Box`. When that code reaches `ret`, execution continues on the line after the `call`. A procedure is just a label that ends with `ret`.

### Signed numbers

A negative number like `-10` is stored in two's complement form. The CPU adds it like any other number. The only place it matters is **comparing**: `jl` treats numbers as signed (can be negative). That is why the code uses `jl` and not an unsigned jump.

---

## 3. How the screen works

### Video mode 13h

The code switches to **mode 13h**:

- 320 pixels wide, 200 pixels tall
- 256 colors
- **One byte per pixel**

The whole screen is 320 x 200 = 64,000 bytes of memory. Writing a byte into that memory changes a pixel. There are no drawing commands. You just write numbers.

### Where the screen lives

The screen's memory starts at segment `A000h`. The code loads that into the `es` register, so `es:di` means "the pixel at offset `di`".

### Coordinates

```
(0,0) ----------------> x grows right
  |
  |
  v
  y grows DOWN
```

- **(0, 0) is the top-left corner.**
- **y grows downward.** The bottom row is y = 199.
- So moving **up** means y gets **smaller**.

### Finding a pixel

Each screen row is 320 bytes wide, so the pixel at (x, y) is at:

```
offset = y * 320 + x
```

| Pixel | Offset |
|---|---|
| (0, 0), top-left | 0 |
| (1, 0) | 1 |
| (0, 1), start of 2nd row | 320 |
| (30, 135), the dino's top-left | 135 * 320 + 30 = 43,230 |
| (319, 199), bottom-right | 63,999 |

### Colors

Each pixel's byte is a palette index. This program uses three:

| Constant | Value | Color |
|---|---|---|
| `white` | 15 | White |
| `gray` | 8 | Dark gray |
| `black` | 0 | Black |

---

## 4. Constants

```nasm
ground equ 150
dinoX equ 30
dinoStart equ 135

jumpSpeed equ -10
gravity equ 1

white equ 15
gray equ 8
black equ 0
```

| Constant | Meaning |
|---|---|
| `ground` | The y row of the ground line (counted from the **top**). |
| `dinoX` | The dino's left edge. It never changes, because the dino only moves up and down. |
| `dinoStart` | The dino's top edge while standing. The dino is 15 tall, so 135 + 15 = 150 puts its feet on the ground. |
| `jumpSpeed` | The speed at the start of a jump. Negative means up. |
| `gravity` | How much the speed changes each frame. Positive means down. |
| `white`, `gray`, `black` | Palette colors. |

Constants cost nothing at runtime. Using names instead of numbers means you change a value in one place.

---

## 5. Start: setting up the screen

```nasm
Start:
    mov ax, 0013h
    int 10h
    mov ax, 0A000h
    mov es, ax
    cld
```

| Line | What it does |
|---|---|
| `mov ax, 0013h` | Prepares the request "set video mode 13h". |
| `int 10h` | Calls the BIOS video service to do it. The screen clears. |
| `mov ax, 0A000h` / `mov es, ax` | Points `es` at the screen's memory. (A segment register can't be loaded with a number directly, so it goes through `ax`.) |
| `cld` | Makes `rep stosb` move forward through memory. |

### Drawing the frame

Next the code draws the frame with `Draw_Box`. Each box is five register values and a call. In order:

1. White background (320 x 200), covering the whole screen
2. Top border (black, 2 pixels thick)
3. Bottom border
4. Left border
5. Right border
6. Ground line (gray)
7. The dino, using `Draw_Dino`

Later boxes are painted on top of earlier ones. That is why the white background comes first.

---

## 6. What the registers mean

Before calling `Draw_Box`, the code fills in five registers:

| Register | Meaning | Example (top border) |
|---|---|---|
| `ax` | x: left edge of the box | 0 |
| `bx` | y: top edge of the box | 0 |
| `cx` | width in pixels | 320 |
| `dx` | height in pixels | 2 |
| `si` | color | `black` |

Example:

```nasm
mov ax, 0        ; x
mov bx, 0        ; y
mov cx, 320      ; width
mov dx, 2        ; height
mov si, black    ; color
call Draw_Box
```

This draws a black bar across the top of the screen.

---

## 7. The game loop

```nasm
Game_Loop:
    call Wait_Vsync
    call Wait_Vsync
    ...
    jmp Game_Loop
```

Every pass through the loop is one **frame**. The loop has five steps.

### Step 1: Wait for the screen refresh

`Wait_Vsync` pauses until the monitor finishes one refresh (about 70 per second). It is called **twice**, so each game frame lasts two refreshes. That makes the game run at about **35 frames per second**, which gives it a chunky retro feel. Without it, the loop would run as fast as the CPU allows and the game would be unplayable.

### Step 2: Check the keyboard

```nasm
    mov ah, 1
    int 16h
    jz No_Key
    mov ah, 0
    int 16h
    cmp al, 27
    je Exit_Game
    cmp al, ' '
    jne No_Key
    cmp byte [on_ground], 1
    jne No_Key
    mov word [speed], jumpSpeed
    mov byte [on_ground], 0
No_Key:
```

In plain words:

1. Is a key waiting? If not, skip all of this. (This check does not wait, so the game keeps running when you press nothing.)
2. Read the key. Its ASCII code is in `al`.
3. If it is ESC (27), go to `Exit_Game`.
4. If it is not SPACE, skip.
5. If the dino is not on the ground, skip. (This prevents double jumps.)
6. Otherwise, **start the jump**: set the speed to `jumpSpeed` and mark the dino as in the air.

`No_Key` is only a **label**: a place to jump to. It does not turn input off. Input is checked again on the next frame.

### Step 3: Erase the dino

```nasm
    mov si, white
    call Draw_Dino
```

The dino is painted white at its **old** position, which hides it. This must happen before the position changes. Only the 10 x 15 box is repainted, not the whole screen, which is fast.

### Step 4: Move the dino

```nasm
    cmp byte [on_ground], 1
    je Skip_Move

    mov ax, [speed]
    add [dino_y], ax
    add word [speed], gravity

    cmp word [dino_y], dinoStart
    jl Skip_Move
    mov word [dino_y], dinoStart
    mov word [speed], 0
    mov byte [on_ground], 1
Skip_Move:
```

1. If the dino is standing, there is nothing to move. Skip.
2. Add the speed to the position: `dino_y = dino_y + speed`.
3. Add gravity to the speed: `speed = speed + gravity`.
4. If `dino_y` is less than `dinoStart`, the dino is still in the air. Done for this frame.
5. Otherwise it has landed: put it exactly on the ground, set the speed to 0, and mark it as standing so it can jump again.

(Snapping to `dinoStart` matters because a step can overshoot the ground slightly.)

### Step 5: Draw the dino

```nasm
    mov si, gray
    call Draw_Dino
    jmp Game_Loop
```

The dino is painted gray at its **new** position, then the loop starts over.

---

## 8. How the jump works

### Two variables

| Variable | What it is | Real-life comparison |
|---|---|---|
| `dino_y` | Where the dino is | A car's position |
| `speed` | How fast it moves, and which way | A car's speedometer |

Two rules run every frame while the dino is in the air:

1. **Speed moves the dino:** `dino_y = dino_y + speed`
2. **Gravity changes the speed:** `speed = speed + gravity`

Gravity never moves the dino directly. It only changes the speed, and the speed moves the dino.

### Why `jumpSpeed` is negative

y = 0 is the **top** of the screen, and y grows **downward**. To move the dino up, y must get **smaller**. Adding a negative number makes a number smaller, so:

| Speed | Effect on y | Dino moves |
|---|---|---|
| negative (-10) | y gets smaller | **up** |
| zero | y stays | stays |
| positive (+10) | y gets bigger | **down** |

Gravity is **positive** because down is the positive direction. Adding it every frame pulls the speed from negative, through zero, to positive:

```
-10 -> -9 -> -8 -> ... -> -1 -> 0 -> +1 -> ... -> +10
 rising, slowing down      peak     falling, speeding up
```

One simple `add` handles the whole arc.

### One jump, frame by frame

Start: `dino_y = 135`, standing. SPACE is pressed, so `speed = -10`.

| Frame | y moves by | New y | Speed after gravity |
|---|---|---|---|
| 1 | -10 | 125 | -9 |
| 2 | -9 | 116 | -8 |
| 3 | -8 | 108 | -7 |
| 4 | -7 | 101 | -6 |
| 5 | -6 | 95 | -5 |
| ... | ... | ... | ... |
| 10 | -1 | 80 | 0 (peak) |
| 11 | 0 | 80 | 1 |
| 12 | +1 | 81 | 2 |
| ... | ... | ... | ... |
| 21 | +10 | 135 | landed |

### The numbers with the default settings

- **Height:** 10 + 9 + ... + 1 = **55 pixels** (the peak is at y = 80)
- **Time in the air:** **21 frames**, which is about 0.6 seconds at 35 FPS

For other values: if `n` is the size of `jumpSpeed` and `gravity` is 1, the height is `n * (n + 1) / 2` pixels and the air time is `2n + 1` frames.

---

## 9. Procedures

A procedure is a reusable chunk of code ending with `ret`.

### `Draw_Dino`

```nasm
Draw_Dino:
    mov ax, dinoX
    mov bx, [dino_y]
    mov cx, 10
    mov dx, 15
    call Draw_Box
    ret
```

A shortcut. It fills in the registers for the dino and calls `Draw_Box`:

- x = `dinoX` (always 30)
- y = the **current** `dino_y`, so the box follows the dino
- width 10, height 15

The color comes from `si`, set by whoever calls it: `white` erases the dino and `gray` draws it. So one procedure does both jobs.

### `Draw_Box`

```nasm
Draw_Box:
    mov [box_width], cx
    imul di, bx, 320
    add di, ax
    mov ax, si
Row_Loop:
    mov bx, di
    mov cx, [box_width]
    rep stosb
    mov di, bx
    add di, 320
    dec dx
    jnz Row_Loop
    ret
```

This draws every rectangle. It works in two parts.

**Part 1: find the first pixel**

1. Save the width in memory, because `cx` is needed as a counter.
2. `di = y * 320`, the start of row y.
3. `di = di + x`, now `di` points at the top-left pixel.
4. Copy the color into `ax`, so `al` holds it. (`ax` can be reused because x is already used.)

**Part 2: paint one row at a time** (`Row_Loop`)

1. Remember where this row starts (`bx = di`).
2. Set the number of pixels to the width (`cx`).
3. `rep stosb` writes the color into `width` pixels in a row, moving forward each time.
4. Go back to the row's start, then add 320 to move down one row.
5. Subtract 1 from the height. If rows remain, repeat.

Example: a 20 x 20 box at (30, 135) starts at offset 135 * 320 + 30 = 43,230. Row 1 fills 43,230 to 43,249. Row 2 starts at 43,550. After 20 rows, the square is complete.

`Draw_Box` changes `ax`, `bx`, `cx`, `dx` and `di`, but **not** `si`.

### `Wait_Vsync`

```nasm
Wait_Vsync:
    mov dx, 3DAh
Wait_End:
    in al, dx
    test al, 8
    jnz Wait_End
Wait_Start:
    in al, dx
    test al, 8
    jz Wait_Start
    ret
```

The monitor redraws the screen about 70 times a second. After each pass there is a short gap called the **vertical retrace**. The VGA card reports it through port `3DAh`: bit 3 of that byte is 1 during the gap.

1. **`Wait_End`:** if a retrace is already happening, wait for it to finish.
2. **`Wait_Start`:** wait for the next retrace to begin.
3. Return. The code now continues exactly once per refresh.

It works like a metronome for the game.

---

## 10. Variables

```nasm
box_width   dw 0
dino_y      dw dinoStart
speed       dw 0
on_ground   db 1
```

| Variable | Size | Purpose |
|---|---|---|
| `box_width` | 2 bytes | A temporary copy of the width inside `Draw_Box`. |
| `dino_y` | 2 bytes | The dino's top edge. Starts at `dinoStart` (135). |
| `speed` | 2 bytes | The current vertical speed. Can be negative. |
| `on_ground` | 1 byte | 1 = standing, 0 = in the air. |

Variables sit at the end of the file. The program quits before the CPU could run into them.

---

## 11. Exit

```nasm
Exit_Game:
    mov ax, 0003h
    int 10h
    mov ax, 4C00h
    int 21h
```

1. Switch back to normal text mode (mode 03h).
2. Ask DOS to end the program (function `4Ch`, exit code 0).

---

## 12. How to change things

| I want to... | Change |
|---|---|
| Jump higher | Make `jumpSpeed` more negative, for example `-12` |
| Jump lower | Make `jumpSpeed` less negative, for example `-8` |
| Snappier or floatier jump | Change `gravity` (bigger is snappier) |
| Faster or slower game | Add or remove a `call Wait_Vsync` in `Game_Loop` |
| Change the dino's size | Change the width and height in `Draw_Dino`, then update `dinoStart` |
| Change a color | Change `white`, `gray` or `black` (palette values 0 to 255) |
| Move the ground | Change `ground` and update `dinoStart` to `ground` minus the dino height |

If you make the jump higher, make sure the peak (`dinoStart` minus the height) stays below the top border (about y = 4).

---

## 13. Common mistakes

| Mistake | What happens |
|---|---|
| Using `Draw_box` when the label is `Draw_Box` | NASM error. **Names are case-sensitive.** |
| Forgetting `org 100h` | Everything is off by 256 bytes and the program misbehaves. |
| Building without `-f bin` | The output is not a `.COM` file and nothing runs. |
| Changing the dino's height without changing `dinoStart` | The dino floats above or sinks into the ground. |
| Forgetting brackets: `mov ax, dino_y` | Loads the variable's **address**, not its value. Use `[dino_y]`. |
| Forgetting the size: `mov [speed], 5` | NASM can't tell if you mean 1 or 2 bytes. Write `mov word [speed], 5`. |
| Copying memory to memory: `mov [a], [b]` | Not allowed. Go through a register. |
| Erasing after moving | The old position is never cleaned, leaving a trail. |

---

## 14. Glossary

| Term | Meaning |
|---|---|
| **Register** | A small storage slot inside the CPU. |
| **Label** | A name for a spot in the code, ending with `:`. |
| **Procedure** | A label that ends with `ret`, used with `call`. |
| **Constant** | A name replaced by a number at build time (`equ`). |
| **Variable** | A named spot in memory (`dw` / `db`). |
| **Segment** | Part of a memory address. Here `es` selects the screen. |
| **Offset** | The position inside a segment. Here `di` is the pixel. |
| **BIOS / DOS** | Built-in services the program calls with `int`. |
| **Interrupt (`int`)** | A request to the BIOS or DOS to do a job. |
| **Flag** | A bit the CPU sets after `cmp`, `test` or `dec`, used by jumps. |
| **Frame** | One pass through the game loop. |
| **Vsync / vertical retrace** | The brief gap between screen refreshes, used for timing. |
| **Two's complement** | How the CPU stores negative numbers. |
| **`.COM` file** | The simplest DOS program format, loaded at address 100h. |
