; General Controls:
; Space = jump, ESC = quit
;=====================================================================


;FOR THE LOVE OF GOD, LOOK AT DOCS FOR THE EXPLANATION OF THE CODE


;=====================================================================
org 100h

; ========== CONSTANTS ==========
ground equ 150        ; y level of the ground line, counted from the TOP of the screen
dinoX equ 30          ; dino's x level from the left edge
dinoStart equ 135     ; dino's y when standing (ground 150 - dino height 15)

; --- used for vertical movement calculation ---
jumpSpeed equ -10     ; starting speed, negative (explanation on docs/github. READ IT)
gravity equ 1         ; added to speed each pull

; --- Colors ---
white equ 15
gray equ 8
black equ 0


; ========== START ==========
Start:
    ; setting up the video mode and segment
    mov ax, 0013h     ; set video mode to 320x200
    int 10h
    mov ax, 0A000h    ; set video segment
    mov es, ax
    cld

    ; --- creating the frame ---
    ; refer to docs/github for what the registers mean in this context

    ; white background
    mov ax, 0
    mov bx, 0
    mov cx, 320
    mov dx, 200
    mov si, white   ; using white constant
    call Draw_Box

    ; top border
    mov ax, 0
    mov bx, 0
    mov cx, 320
    mov dx, 2
    mov si, black   ; using black constant
    call Draw_Box

    ; bottom border
    mov ax, 0
    mov bx, 198
    mov cx, 320
    mov dx, 2
    mov si, black
    call Draw_Box

    ; left border
    mov ax, 0
    mov bx, 0
    mov cx, 2
    mov dx, 200
    mov si, black
    call Draw_Box

    ; right border
    mov ax, 318
    mov bx, 0
    mov cx, 2
    mov dx, 200
    mov si, black
    call Draw_Box

    ; ground line
    mov ax, 2
    mov bx, ground
    mov cx, 316
    mov dx, 2
    mov si, gray
    call Draw_Box

    ; drawing dino for the first time
    mov si, gray
    call Draw_Dino


; ========== GAME LOOP (infinite runner style) ==========
Game_Loop:
    call Wait_Vsync      ; wait for one screen refresh
    call Wait_Vsync      ; wait again = half speed (about 35 FPS)

    ; --- check the keyboard ---
    mov ah, 1            ; is a key waiting?
    int 16h
    jz No_Key            ; no key, skip
    mov ah, 0            ; get the key
    int 16h
    cmp al, 27           ; ESC?
    je Exit_Game
    cmp al, ' '          ; SPACE?
    jne No_Key
    cmp byte [on_ground], 1   ; only jump if standing
    jne No_Key
    mov word [speed], jumpSpeed
    mov byte [on_ground], 0
No_Key:

    ; --- erase the dino (paint it white) ---
    mov si, white
    call Draw_Dino

    ; --- move the dino ---
    cmp byte [on_ground], 1
    je Skip_Move         ; standing, no movement

    mov ax, [speed]
    add [dino_y], ax     ; position = position + speed
    add word [speed], gravity   ; speed = speed + gravity

    cmp word [dino_y], dinoStart
    jl Skip_Move         ; still in the air
    mov word [dino_y], dinoStart   ; landed
    mov word [speed], 0
    mov byte [on_ground], 1
Skip_Move:

    ; --- draw the dino (paint it gray) ---
    mov si, gray
    call Draw_Dino

    jmp Game_Loop


; ========== EXIT ==========
Exit_Game:
    mov ax, 0003h        ; back to text mode
    int 10h
    mov ax, 4C00h        ; quit to DOS
    int 21h


; ========== PROCEDURES ==========

; ---------- Draw_Dino: draws the dino box, si = color ----------
Draw_Dino:
    mov ax, dinoX
    mov bx, [dino_y]
    mov cx, 10           ; width
    mov dx, 15           ; height
    call Draw_Box
    ret

; ---------- Draw_Box: draws a filled rectangle ----------
; ax = x, bx = y, cx = width, dx = height, si = color
Draw_Box:
    mov [box_width], cx
    imul di, bx, 320     ; di = y * 320
    add di, ax           ; di = y * 320 + x  (spot on screen)
    mov ax, si           ; al = color
Row_Loop:
    mov bx, di           ; remember where this row starts
    mov cx, [box_width]
    rep stosb            ; paint one row of pixels
    mov di, bx
    add di, 320          ; go down one row
    dec dx
    jnz Row_Loop         ; repeat until all rows are done
    ret

; ---------- Wait_Vsync: waits for one screen refresh ----------
Wait_Vsync:
    mov dx, 3DAh
Wait_End:
    in al, dx
    test al, 8
    jnz Wait_End         ; wait until the refresh ends
Wait_Start:
    in al, dx
    test al, 8
    jz Wait_Start        ; wait until the next one starts
    ret


; ========== VARIABLES ==========
box_width   dw 0
dino_y      dw dinoStart
speed       dw 0
on_ground   db 1