org 100h
jmp start

; ============================================================
; DATA
; ============================================================

title_text db 'TEXT VIEWPORT MANAGER', 0

line1 db 'The quick brown fox jumps over the lazy dog.', 0
line2 db 'Assembly language uses registers and memory.', 0
line3 db 'The keyword fox will be highlighted on screen.', 0
line4 db 'Scrolling moves text but preserves the border.', 0
line5 db 'String instructions help process blocks of data.', 0
line6 db 'The viewport displays a portion of a document.', 0
line7 db 'Search can find more than one occurrence of fox.', 0

; --- ADDED: extra document lines (copies of line1) so there is something to scroll in ---
line8  db 'The quick brown fox jumps over the lazy dog.', 0
line9  db 'The quick brown fox jumps over the lazy dog.', 0
line10 db 'The quick brown fox jumps over the lazy dog.', 0
line11 db 'The quick brown fox jumps over the lazy dog.', 0
line12 db 'The quick brown fox jumps over the lazy dog.', 0

; --- ADDED: table of document lines and index of next line to show ---
doc_table dw line1,line2,line3,line4,line5,line6,line7
          dw line8,line9,line10,line11,line12
doc_count equ 12
next_idx  dw 7

keyword db 'fox'
keyword_len dw 3

status_prefix db 'Total Matches Found: ', 0
status_suffix db ' | Viewport Status: ACTIVE', 0

match_count dw 0

; Buffer for the 63 interior characters of one row.
searchbuf times 63 db 0


; ============================================================
; MAIN PROGRAM
; ============================================================

start:
    push cs
    pop ds

    push word 0720h
    call clear_screen

    ; Arguments: top, left, bottom, right (pushed in reverse)
    push word 72
    push word 21
    push word 8
    push word 3
    call draw_window

    ; Arguments: string, row, column, maximum length, attribute
    push word 1Eh
    push word 40
    push word 30
    push word 4
    push word title_text
    call print_line

    push word 1Fh
    push word 61
    push word 10
    push word 5
    push word line1
    call print_line

    push word 1Fh
    push word 61
    push word 10
    push word 6
    push word line2
    call print_line

    push word 1Fh
    push word 61
    push word 10
    push word 7
    push word line3
    call print_line

    push word 1Fh
    push word 61
    push word 10
    push word 8
    push word line4
    call print_line

    push word 1Fh
    push word 61
    push word 10
    push word 9
    push word line5
    call print_line

    push word 1Fh
    push word 61
    push word 10
    push word 10
    push word line6
    call print_line

    push word 1Fh
    push word 61
    push word 10
    push word 11
    push word line7
    call print_line

    ; --- CHANGED: initial highlight + status bar, then a key loop ---
    call update_view

key_loop:
    mov ah, 0                 ; wait for a key
    int 16h
    cmp al, 27                ; ESC quits
    je quit

    ; Arguments: top, left, bottom, right, number of rows
    push word 1
    push word 72
    push word 21
    push word 8
    push word 3
    call scroll_window_up

    ; print the next document line into the vacated bottom row (row 20)
    mov bx, [next_idx]
    cmp bx, doc_count
    jae no_more_lines
    shl bx, 1
    mov ax, [doc_table + bx]
    push word 1Fh
    push word 61
    push word 10
    push word 20
    push ax
    call print_line
    inc word [next_idx]

no_more_lines:
    call update_view
    jmp key_loop

quit:
    mov ax, 0003h             ; clear screen on exit
    int 10h
    mov ax, 4C00h
    int 21h


; ============================================================
; update_view  (ADDED)
; Re-runs the highlighter and redraws the status bar.
; ============================================================

update_view:
    ; Arguments: keyword offset, keyword length, attribute
    push word 0CEh
    push word [keyword_len]
    push word keyword
    call find_and_highlight

    push word 07h
    push word 21
    push word 0
    push word 23
    push word status_prefix
    call print_line

    push word 0Eh
    push word 21
    push word 23
    push word [match_count]
    call printNum

    push word 07h
    push word 54
    push word 22
    push word 23
    push word status_suffix
    call print_line
    ret


; ============================================================
; clear_screen
;
; Parameter:
;   [bp+4] = character and attribute word
; ============================================================

clear_screen:
    push bp
    mov bp, sp

    push ax
    push cx
    push di
    push es

    mov ax, 0B800h
    mov es, ax

    xor di, di
    mov ax, [bp+4]
    mov cx, 2000

    cld
    rep stosw

    pop es
    pop di
    pop cx
    pop ax

    pop bp
    ret 2


; ============================================================
; draw_window
;
; Parameters:
;   [bp+4]  = top row
;   [bp+6]  = left column
;   [bp+8]  = bottom row
;   [bp+10] = right column
;
; Local variables:
;   [bp-2] = current row
;   [bp-4] = current column
;   [bp-6] = character to draw
; ============================================================

draw_window:
    push bp
    mov bp, sp
    sub sp, 6

    push ax
    push bx
    push dx
    push di
    push es

    mov ax, 0B800h
    mov es, ax

    mov ax, [bp+4]
    mov [bp-2], ax

draw_row:
    mov ax, [bp+6]
    mov [bp-4], ax

draw_column:
    mov byte [bp-6], 0CDh

    mov ax, [bp-2]
    cmp ax, [bp+4]
    je horizontal_row

    cmp ax, [bp+8]
    je horizontal_row

    mov ax, [bp-4]
    cmp ax, [bp+6]
    je vertical_side

    cmp ax, [bp+10]
    je vertical_side

    ; Interior cell: blank with the window attribute
    mov byte [bp-6], 20h
    jmp write_border

vertical_side:
    mov byte [bp-6], 0BAh
    jmp write_border

horizontal_row:
    mov ax, [bp-4]
    cmp ax, [bp+6]
    jne check_right_corner

    ; Top-left corner
    mov byte [bp-6], 0C9h

    mov ax, [bp-2]
    cmp ax, [bp+8]
    jne write_border

    ; Bottom-left corner
    mov byte [bp-6], 0C8h
    jmp write_border

check_right_corner:
    mov ax, [bp-4]
    cmp ax, [bp+10]
    jne write_border

    ; Top-right corner
    mov byte [bp-6], 0BBh

    mov ax, [bp-2]
    cmp ax, [bp+8]
    jne write_border

    ; Bottom-right corner
    mov byte [bp-6], 0BCh

write_border:
    mov ax, [bp-2]
    mov bx, 160
    mul bx
    mov di, ax

    mov ax, [bp-4]
    shl ax, 1
    add di, ax

    mov al, [bp-6]
    mov ah, 1Fh
    mov [es:di], ax

next_column:
    inc word [bp-4]

    mov ax, [bp-4]
    cmp ax, [bp+10]
    jbe draw_column

    inc word [bp-2]

    mov ax, [bp-2]
    cmp ax, [bp+8]
    jbe draw_row

    pop es
    pop di
    pop dx
    pop bx
    pop ax

    mov sp, bp
    pop bp
    ret 8


; ============================================================
; print_line
;
; Parameters:
;   [bp+4]  = string offset
;   [bp+6]  = row
;   [bp+8]  = column
;   [bp+10] = maximum number of characters
;   [bp+12] = attribute
; ============================================================

print_line:
    push bp
    mov bp, sp

    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es

    mov ax, 0B800h
    mov es, ax

    mov si, [bp+4]

    mov ax, [bp+6]
    mov bx, 160
    mul bx
    mov di, ax

    mov ax, [bp+8]
    shl ax, 1
    add di, ax

    mov cx, [bp+10]
    mov ah, [bp+12]

    cld

print_line_loop:
    cmp cx, 0
    je print_line_done

    lodsb

    cmp al, 0
    je print_line_done

    stosw
    dec cx

    jmp print_line_loop

print_line_done:
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax

    pop bp
    ret 10


; ============================================================
; scroll_window_up
;
; Parameters:
;   [bp+4]  = top border row
;   [bp+6]  = left border column
;   [bp+8]  = bottom border row
;   [bp+10] = right border column
;   [bp+12] = number of rows to scroll
;
; Local variables:
;   [bp-2] = effective scroll amount
;   [bp-4] = destination row
;   [bp-6] = last destination row
;
; Title row (top+1) is kept; rows top+2 to bottom-1 are scrolled.
; ============================================================

scroll_window_up:
    push bp
    mov bp, sp
    sub sp, 6

    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es

    mov ax, 0B800h
    mov es, ax

    ; Scrollable height = bottom - top - 2
    mov ax, [bp+8]
    sub ax, [bp+4]
    sub ax, 2

    cmp ax, 0
    jle scroll_done

    ; Effective scroll amount = min(N, height)
    mov bx, [bp+12]
    cmp bx, ax
    jbe scroll_amount_valid

    mov bx, ax

scroll_amount_valid:
    mov [bp-2], bx

    mov ax, [bp+4]
    add ax, 2
    mov [bp-4], ax

    ; Last destination row = bottom - 1 - N
    mov ax, [bp+8]
    dec ax
    sub ax, [bp-2]
    mov [bp-6], ax

scroll_copy_row:
    mov ax, [bp-4]
    cmp ax, [bp-6]
    ja scroll_blank_start

    add ax, [bp-2]

    mov bx, 160
    mul bx
    mov si, ax

    mov ax, [bp+6]
    inc ax
    shl ax, 1
    add si, ax

    mov ax, [bp-4]
    mov bx, 160
    mul bx
    mov di, ax

    mov ax, [bp+6]
    inc ax
    shl ax, 1
    add di, ax

    mov cx, [bp+10]
    sub cx, [bp+6]
    dec cx

    ; MOVSW reads from DS:SI, so DS must point to video memory here
    push ds
    mov ax, 0B800h
    mov ds, ax
    cld
    rep movsw
    pop ds

    inc word [bp-4]
    jmp scroll_copy_row

scroll_blank_start:
    mov ax, [bp+8]
    sub ax, [bp-2]
    mov [bp-4], ax

scroll_blank_row:
    mov ax, [bp-4]
    cmp ax, [bp+8]
    jae scroll_done

    mov bx, 160
    mul bx
    mov di, ax

    mov ax, [bp+6]
    inc ax
    shl ax, 1
    add di, ax

    mov ax, 1F20h

    mov cx, [bp+10]
    sub cx, [bp+6]
    dec cx

    cld
    rep stosw

    inc word [bp-4]
    jmp scroll_blank_row

scroll_done:
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax

    mov sp, bp
    pop bp
    ret 10


; ============================================================
; find_and_highlight
;
; Parameters:
;   [bp+4] = keyword offset
;   [bp+6] = keyword length
;   [bp+8] = highlight attribute
;
; Local variables:
;   [bp-2] = current row
;   [bp-4] = candidate position
;
; Each row's characters are copied into searchbuf first, because
; CMPSB cannot skip the attribute bytes in video memory.
; ============================================================

find_and_highlight:
    push bp
    mov bp, sp
    sub sp, 4

    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es

    mov word [match_count], 0

    mov ax, [bp+6]
    cmp ax, 0
    je search_finished

    cmp ax, 63
    ja search_finished

    mov word [bp-2], 4

search_row:
    cmp word [bp-2], 21
    jae search_finished

    mov ax, 0B800h
    mov es, ax

    mov ax, [bp-2]
    mov bx, 160
    mul bx
    mov di, ax

    add di, 18

    mov si, searchbuf
    mov cx, 63

copy_search_row:
    mov al, [es:di]
    mov [si], al

    add di, 2
    inc si
    dec cx

    jnz copy_search_row

    mov word [bp-4], 0

search_candidate:
    mov ax, 63
    sub ax, [bp+6]

    cmp word [bp-4], ax
    ja search_next_row

    mov si, searchbuf
    add si, [bp-4]

    push ds
    pop es

    mov di, [bp+4]
    mov cx, [bp+6]

    cld
    repe cmpsb
    jne search_candidate_next

    inc word [match_count]

    mov ax, 0B800h
    mov es, ax

    ; Attribute byte address = row*160 + (9 + candidate)*2 + 1
    mov ax, [bp-2]
    mov bx, 160
    mul bx
    mov di, ax

    mov ax, [bp-4]
    add ax, 9
    shl ax, 1
    add di, ax
    inc di

    mov cx, [bp+6]
    mov al, [bp+8]

highlight_match:
    mov [es:di], al
    add di, 2
    dec cx
    jnz highlight_match

search_candidate_next:
    inc word [bp-4]
    jmp search_candidate

search_next_row:
    inc word [bp-2]
    jmp search_row

search_finished:
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax

    mov sp, bp
    pop bp
    ret 6


; ============================================================
; printNum
;
; Parameters:
;   [bp+4]  = unsigned integer
;   [bp+6]  = row
;   [bp+8]  = column
;   [bp+10] = attribute
;
; Local variable:
;   [bp-2] = number of digits
; ============================================================

printNum:
    push bp
    mov bp, sp
    sub sp, 2

    push ax
    push bx
    push cx
    push dx
    push di
    push es

    mov word [bp-2], 0

    mov ax, [bp+4]
    mov bx, 10

    cmp ax, 0
    jne number_convert

    push word 0
    inc word [bp-2]
    jmp number_output

number_convert:
    xor dx, dx
    div bx

    push dx
    inc word [bp-2]

    cmp ax, 0
    jne number_convert

number_output:
    mov ax, 0B800h
    mov es, ax

    mov ax, [bp+6]
    mov bx, 160
    mul bx
    mov di, ax

    mov ax, [bp+8]
    shl ax, 1
    add di, ax

number_output_loop:
    cmp word [bp-2], 0
    je number_finished

    pop dx

    add dl, 30h

    mov al, dl
    mov ah, [bp+10]

    mov [es:di], ax
    add di, 2

    dec word [bp-2]
    jmp number_output_loop

number_finished:
    pop es
    pop di
    pop dx
    pop cx
    pop bx
    pop ax

    mov sp, bp
    pop bp
    ret 8