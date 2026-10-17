;=====================================================================
; General Controls:
; Space = jump, ESC = quit
;=====================================================================


;FOR THE LOVE OF GOD, LOOK AT DOCS FOR THE EXPLANATION OF THE CODE


;=====================================================================
org 100h

; ========== CONSTANTS ==========
; ---- colors: default VGA palette in mode 13h ----
colorBlack  equ 0           ; palette index 0  = black
colorLight  equ 7           ; palette index 7  = light gray
colorGray   equ 8           ; palette index 8  = dark gray (dino color)
colorWhite  equ 15          ; palette index 15 = white (background / eraser)
 
; ---- ground scrolling settings ----
groundRows  equ 8           ; height of the ground tile in rows (pixels)
tileW       equ 64          ; width of the ground tile in columns (pixels)
fieldLeft   equ 2           ; first x we draw on. Set it just INSIDE your border
fieldWidth  equ 316         ; how many columns we draw (320 - 8 - 8)
 
; ---- size checker (used by the tile data and the sprites) ----
%macro Check_Size 2
    times ($ - %1) - (%2) db 0      ; error here = data is too SHORT
    times (%2) - ($ - %1) db 0      ; error here = data is too LONG
%endmacro

ground equ 150        ; y level of the ground line, counted from the TOP of the screen
dinoX equ 30          ; dino's x level from the left edge
dinoStart equ 135     ; dino's y when standing (ground 150 - dino height 15)

; ----- Moving Cloud -----
cloudW       equ 40     ; cloud sprite width
cloudH       equ 8      ; cloud sprite height
cloudStartX  equ 296    ; x where a new cloud appears (right side)
cloudEndX    equ 4      ; at or below this x, the cloud is removed
cloudSpeed   equ 1      ; pixels per frame

maxClouds      equ 3
cloudLevels    equ 4
cloudTopY      equ 10
cloudLevelGap  equ 14
spawnMin       equ 30
spawnRange     equ 90

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
    call Init_Random 

    ; ----- creating the frame -----
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
    call Update_Ground   ; move the scroll position
    call Draw_Ground     ; redraw the ground at that position
    call Spawn_Cloud     ; Spawns a moving cloud that moves left 
    call Move_Clouds     ; Moves The Clouds
    

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

; ----- Udates the Ground -----
Update_Ground:
    push ax                     ; save ax so the caller's value survives
 
    mov ax, [ground_scroll]     ; ax = current scroll position
    add ax, [scroll_speed]      ; move it by the speed (pixels per frame)
 
    cmp ax, tileW               ; did we go past the end of the tile?
    jb .Store                   ; no  -> keep the value as it is
    sub ax, tileW               ; yes -> wrap around (keeps the leftover pixels,
                                ;        so the speed stays smooth)
.Store:
    mov [ground_scroll], ax     ; save the new scroll position
 
    pop ax                      ; restore ax
    ret

; ----- Draws The Ground -----
Draw_Ground:
    push ax                     ; save every register we change
    push bx
    push cx
    push dx
    push si
    push di
    push es
 
    mov ax, 0A000h              ; segment of VGA video memory
    mov es, ax                  ; es:di now points at screen pixels
 
    mov di, ground * 320 + fieldLeft ; di = offset of the first ground pixel
                                ;        (offset = y * 320 + x)
    mov si, ground_tile         ; si = first text row of the tile
    mov dl, groundRows          ; dl = number of rows still to draw
 
.Row_Loop:                      ; ----- one text row of the tile per pass -----
    mov bx, [ground_scroll]     ; bx = tile column where this row starts
    mov cx, fieldWidth          ; cx = how many pixels to draw in this row
 
.Pixel_Loop:                    ; ----- one pixel per pass -----
    mov al, [si + bx]           ; al = the character at tile column bx
    call Char_To_Color          ; al = palette color for that character
    mov [es:di], al             ; write the pixel to the screen
    inc di                      ; next pixel to the right on screen
 
    inc bx                      ; next tile column
    cmp bx, tileW               ; ran off the right edge of the tile?
    jb .No_Wrap                 ; no  -> carry on
    xor bx, bx                  ; yes -> jump back to tile column 0 (the loop!)
.No_Wrap:
    loop .Pixel_Loop            ; cx = cx - 1, repeat until cx is 0
 
    add di, 320 - fieldWidth    ; di: back to the row start, then one line down
    add si, tileW               ; si: next text row of the tile
    dec dl                      ; one row finished
    jnz .Row_Loop               ; more rows left? go again
 
    pop es                      ; restore registers in REVERSE order
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ----- For Randomization -----
Init_Random:
    mov ah, 0                   ; BIOS function 0 = read the clock
    int 1Ah                     ; cx:dx = clock ticks since midnight
    mov [rand_seed], dx         ; use the low part as the seed
    ret
    
Get_Random:
    mov ax, [rand_seed]         ; ax = old seed
    mov dx, 25173               ; the multiplier
    mul dx                      ; dx:ax = ax * 25173 (we keep only ax)
    add ax, 13849               ; add the increment
    mov [rand_seed], ax         ; save as the new seed
    ret
    
Random_Range:
    push dx                     ; Get_Random and div change dx, so save it
    call Get_Random             ; ax = random 16-bit number
    mov al, ah                  ; use the HIGH byte (better random than the low)
    xor ah, ah                  ; ax = 0..255
    xor dx, dx                  ; clear dx before dividing (dx:ax / bx)
    div bx                      ; ax = quotient, dx = remainder (0..n-1)
    mov ax, dx                  ; the remainder is our result
    pop dx                      ; restore dx
    ret
    
; ----- Cloud Spawning -----
Spawn_Cloud:
    cmp word [spawn_timer], 0   ; has the countdown finished?
    je .Time_To_Spawn           ; yes -> make a cloud
    dec word [spawn_timer]      ; no  -> count one frame down
    ret                         ; (nothing was pushed yet, so plain ret)
 
.Time_To_Spawn:
    push ax                     ; save the registers we change
    push bx
    push cx
    push dx
 
    xor bx, bx                  ; bx = slot offset (0, 2, 4 ... words are 2 bytes)
.Find_Slot:
    cmp word [clouds_on + bx], 0 ; is this slot free?
    je .Found                   ; yes -> use it
    add bx, 2                   ; no  -> try the next slot
    cmp bx, maxClouds * 2       ; checked all slots?
    jb .Find_Slot               ; no  -> keep looking
    jmp .Reset_Timer            ; all slots full: skip this spawn
 
.Found:
    mov word [clouds_on + bx], 1        ; mark the slot as used
    mov word [clouds_x + bx], cloudStartX ; start at the right side
 
    push bx                     ; Random_Range needs bx, so save the slot offset
    mov bx, cloudLevels         ; n = number of levels
    call Random_Range           ; ax = random level 0 .. cloudLevels-1
    mov cx, cloudLevelGap       ; cx = pixels between levels
    mul cx                      ; ax = level * gap (dx is destroyed, we do not care)
    add ax, cloudTopY           ; ax = y of that level
    pop bx                      ; bx = slot offset again
    mov [clouds_y + bx], ax     ; remember this cloud's y
 
.Reset_Timer:
    mov bx, spawnRange          ; n = size of the random extra time
    call Random_Range           ; ax = random 0 .. spawnRange-1
    add ax, spawnMin            ; add the minimum wait
    mov [spawn_timer], ax       ; frames until the next cloud
 
    pop dx                      ; restore registers in REVERSE order
    pop cx
    pop bx
    pop ax
    ret
; ----- Move_Cloud: erase, move, draw the cloud ------
Move_Clouds:
    push ax                     ; save the registers we change
    push bx
    push cx
    push dx
    push si
    push di
 
    ; erases all clouds
    xor bx, bx                  ; bx = slot offset, start at slot 0
.Erase_Loop:
    cmp word [clouds_on + bx], 0 ; is the slot used?
    je .Erase_Next              ; no  -> nothing to erase
    push bx                     ; Draw_Box will destroy bx, so save it
    mov ax, [clouds_x + bx]     ; ax = x of this cloud
    mov cx, cloudW              ; cx = width
    mov dx, cloudH              ; dx = height
    mov bx, [clouds_y + bx]     ; bx = y of this cloud (read BEFORE bx changes)
    mov si, white               ; erase color
    call Draw_Box               ; paint a white box over the old cloud
    pop bx                      ; bx = slot offset again
.Erase_Next:
    add bx, 2                   ; next slot
    cmp bx, maxClouds * 2       ; went through all slots?
    jb .Erase_Loop              ; no  -> continue
 
    ; ===== PASS 2: move and draw all clouds =====
    xor bx, bx                  ; back to slot 0
.Move_Loop:
    cmp word [clouds_on + bx], 0 ; is the slot used?
    je .Move_Next               ; no  -> skip it
 
    mov ax, [clouds_x + bx]     ; ax = current x
    sub ax, cloudSpeed          ; move left
    cmp ax, cloudEndX           ; still on screen?
    jg .Still_On                ; yes -> keep it
    mov word [clouds_on + bx], 0 ; no  -> free the slot (it was already erased)
    jmp .Move_Next              ; and draw nothing
 
.Still_On:
    mov [clouds_x + bx], ax     ; save the new x
    push bx                     ; Draw_Sprite needs bx = y, so save the slot offset
    mov bx, [clouds_y + bx]     ; bx = y of this cloud
    mov cx, cloudW              ; cx = width
    mov dx, cloudH              ; dx = height
    mov si, cloud_sprite        ; si = the sprite to draw (ax already = x)
    call Draw_Sprite            ; draw the cloud at its new place
    pop bx                      ; bx = slot offset again
 
.Move_Next:
    add bx, 2                   ; next slot
    cmp bx, maxClouds * 2       ; went through all slots?
    jb .Move_Loop               ; no  -> continue
 
    pop di                      ; restore registers in REVERSE order
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

Draw_Sprite:
    push ax                     ; save every register we change
    push bx
    push cx
    push dx
    push si
    push di
    push bp
    push es

    cld                         ; make lodsb move si FORWARD
    mov di, ax                  ; di = x (for now)
    mov ax, bx                  ; ax = y
    mov bp, dx                  ; bp = height (mul destroys dx, so park it)
    mov dx, 320                 ; one screen row = 320 bytes
    mul dx                      ; ax = y * 320
    add di, ax                  ; di = y * 320 + x = first pixel on screen
    mov dx, bp                  ; dx = height again (rows left to draw)
    mov bp, cx                  ; bp = width (needed again for every row)

    mov ax, 0A000h              ; segment of VGA video memory
    mov es, ax                  ; es:di now points at screen pixels

.Row_Loop:                      ; ----- one sprite row per pass -----
    mov cx, bp                  ; cx = pixels in this row
    push di                     ; remember where this screen row starts

.Pixel_Loop:                    ; ----- one pixel per pass -----
    lodsb                       ; al = next sprite character, then si = si + 1
    cmp al, ' '                 ; is it a space?
    je .Skip                    ; yes -> transparent, leave the screen alone
    call Char_To_Color          ; al = palette color
    mov [es:di], al             ; write the pixel
.Skip:
    inc di                      ; next pixel to the right
    loop .Pixel_Loop            ; cx = cx - 1, repeat until the row is done

    pop di                      ; di = start of the row we just drew
    add di, 320                 ; move down one screen row
    dec dx                      ; one sprite row finished
    jnz .Row_Loop               ; more rows? go again

    pop es                      ; restore registers in REVERSE order
    pop bp
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ----- Converts Character into color -----
Char_To_Color:
    cmp al, '#'                 ; is it a body pixel?
    je .Gray
    cmp al, '@'                 ; is it a black detail pixel?
    je .Black
    cmp al, ':'                 ; is it a light gray pixel?
    je .Light
    mov al, colorWhite          ; anything else (space) = background white
    ret
.Gray:
    mov al, colorGray
    ret
.Black:
    mov al, colorBlack
    ret
.Light:
    mov al, colorLight
    ret

; ========== VARIABLES ==========
box_width   dw 0
dino_y      dw dinoStart
speed       dw 0
on_ground   db 1

ground_scroll   dw 0            ; current scroll position (0 .. tileW-1)
scroll_speed    dw 3            ; pixels the ground moves per frame

rand_seed      dw 0                     ; current random number (set by Init_Random)
spawn_timer    dw 0                     ; frames until the next cloud (0 = spawn now)
clouds_x       times maxClouds dw 0     ; x of each cloud slot
clouds_y       times maxClouds dw 0     ; y of each cloud slot
clouds_on      times maxClouds dw 0     ; 1 = slot used, 0 = slot free

; Ground Sprite
ground_tile:
    db "################################################################"
    db "         ##                           ###                       "
    db "    ::                :::                    :                  "
    db "              :                ::                         ::    "
    db "       :                   :                     :              "
    db "                  ::                :                        :  "
    db "  :                                      ::                     "
    db "            :                                        :          "
    Check_Size ground_tile, tileW * groundRows

; Cloud Sprite
cloud_sprite:
    db "            ::::::::                    "
    db "            ::    ::                    "
    db "      ::::::::    ::::::::::            "
    db "      ::                  ::            "
    db "  ::::::                  ::::::::      "
    db "  ::                            ::      "
    db "    ::                          ::      "
    db "    ::::::::::::::::::::::::::::        "
    Check_Size cloud_sprite, cloudW * cloudH