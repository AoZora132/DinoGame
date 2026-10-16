; ------------------------------------------------------------
; bg.asm - looping parallax background (terminal, x86-64 Linux)
;
; Build: nasm -f elf64 bg.asm -o bg.o && ld bg.o -o bg
; Run:   ./bg        (Ctrl+C to quit)
;
; Idea: each layer is a "tile" stored TWICE back to back.
; We print a window (VIEW columns) starting at an offset.
; The offset grows each frame. When it reaches the tile
; length, it resets to 0. The reset is invisible because
; the second copy of the tile looks identical to the first.
; ------------------------------------------------------------

%define VIEW 60              ; visible columns (tile length must be >= VIEW)
%define DELAY_NS 50000000    ; 50 ms per frame (about 20 FPS)

; ---- tile data (each string below is exactly 10 characters) ----
%macro CLOUD_TILE 0
    db "   .--.   "
    db "          "
    db "  .---.   "
    db "          "
    db "    .--.  "
    db "          "
    db " .----.   "
%endmacro

%macro GROUND_TILE 0
    db "____._____"
    db "__^_______"
    db "_______.__"
    db "_____^____"
    db "__..______"
    db "_______^__"
    db "____.___._"
%endmacro

; ---- helper: write(1, ptr, len) ----
%macro WRITE_OUT 2
    mov rax, 1               ; sys_write
    mov rdi, 1               ; stdout
    lea rsi, [%1]            ; pointer
    mov rdx, %2              ; length
    syscall
%endmacro

section .data
clear:      db 27, "[2J"             ; ANSI: clear screen
clear_len   equ $ - clear
home:       db 27, "[H"              ; ANSI: cursor to top-left
home_len    equ $ - home
gap:        db 10, 10, 10            ; end cloud row + 2 empty rows
newline:    db 10
delay:      dq 0, DELAY_NS           ; timespec {seconds, nanoseconds}

; each layer = tile + same tile again
clouds:
    CLOUD_TILE
CLOUD_LEN   equ $ - clouds           ; length of ONE tile
    CLOUD_TILE

ground:
    GROUND_TILE
GROUND_LEN  equ $ - ground
    GROUND_TILE

section .text
global _start

_start:
    WRITE_OUT clear, clear_len       ; clear the screen once

    xor r12, r12                     ; r12 = frame counter
    xor r13, r13                     ; r13 = ground offset
    xor r14, r14                     ; r14 = cloud offset

main_loop:
    WRITE_OUT home, home_len         ; redraw from the top (no flicker)

    ; --- sky layer ---
    WRITE_OUT clouds + r14, VIEW
    WRITE_OUT gap, 3

    ; --- ground layer ---
    WRITE_OUT ground + r13, VIEW
    WRITE_OUT newline, 1

    ; --- update ground offset (moves every frame) ---
    inc r13
    cmp r13, GROUND_LEN
    jl  .ground_ok
    xor r13, r13                     ; wrap to 0 = the loop
.ground_ok:

    ; --- update cloud offset (moves every 2nd frame = slower) ---
    inc r12
    test r12, 1
    jnz .clouds_done
    inc r14
    cmp r14, CLOUD_LEN
    jl  .clouds_done
    xor r14, r14                     ; wrap to 0 = the loop
.clouds_done:

    ; --- wait one frame: nanosleep(&delay, NULL) ---
    mov rax, 35
    lea rdi, [delay]
    xor rsi, rsi
    syscall

    jmp main_loop                    ; endless loop