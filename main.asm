.include "m328pbdef.inc"

.equ F_CPU = 16000000
.equ BAUD = 9600
.equ MYUBRR = F_CPU/16/BAUD-1

.equ EEPROM_ADDR = 0x00

; Initialize stack pointer
ldi r16, high(RAMEND)
out SPH, r16
ldi r16, low(RAMEND)
out SPL, r16

; UART initialization
uart_init:
    ldi r16, high(MYUBRR)
    sts UBRR0H, r16
    ldi r16, low(MYUBRR)
    sts UBRR0L, r16
    ldi r16, (1<<RXEN0)|(1<<TXEN0)
    sts UCSR0B, r16
    ldi r16, (1<<UCSZ01)|(1<<UCSZ00)
    sts UCSR0C, r16
    ret

; UART send byte
uart_send:
    cpi r16, 0
    breq uart_send_done
    sts UDR0, r16
uart_send_wait:
    sbis UCSR0A, UDRE0
    rjmp uart_send_wait
uart_send_done:
    ret

; UART receive byte
uart_receive:
    sbis UCSR0A, RXC0
    rjmp uart_receive
    lds r16, UDR0
    ret

; Write to EEPROM
eeprom_write:
    ; r18 - address, r19 - data
    ldi r20, (1<<EEMPE)
    out EECR, r20
    out EEDR, r19
    out EEARL, r18
    ldi r20, (1<<EEPE)
    out EECR, r20
    ret

; Read from EEPROM
eeprom_read:
    ; r18 - address, result in r19
    out EEARL, r18
    ldi r20, (1<<EERE)
    out EECR, r20
    in r19, EEDR
    ret

; Save string to EEPROM
save_string:
    ; r18 - address, r24 - length of string
    ; String bytes are in r30:r31 (Z register)
    eeprom_write_length:
        mov r19, r24
        rcall eeprom_write
    eeprom_write_loop:
        ld r19, Z+
        rcall eeprom_write
        dec r24
        brne eeprom_write_loop
    ret

; Read string from EEPROM
read_string:
    ; r18 - address, result in Z register
    ldi r30, 0
    ldi r31, 0
    eeprom_read_length:
        rcall eeprom_read
        mov r24, r19
    eeprom_read_loop:
        rcall eeprom_read
        st Z+, r19
        dec r24
        brne eeprom_read_loop
    ret

; Clear EEPROM
clear_eeprom:
    ; r18 - address
    ldi r19, 0
    rcall eeprom_write
    ret

; Main program
.org 0x00
    rjmp start

start:
    ; Initialize UART
    rcall uart_init

main_loop:
    ; Wait for input
    rcall uart_receive

    ; Process input
    cpi r16, 'o'
    breq output_string
    cpi r16, 'c'
    breq clear_string
    rcall save_string
    rjmp main_loop

output_string:
    ; Output stored string
    ldi r18, EEPROM_ADDR
    rcall read_string
    rjmp main_loop

clear_string:
    ; Clear stored string
    ldi r18, EEPROM_ADDR
    rcall clear_eeprom
    rjmp main_loop
