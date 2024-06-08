.include "m328pbdef.inc" ; Включаем файл с определениями регистров ATmega328PB

.equ F_CPU = 16000000     ; Частота процессора 16 МГц
.equ BAUD = 9600          ; Скорость передачи данных через UART (бит/с)
.equ MYUBRR = F_CPU/16/BAUD-1 ; Расчет значения UBRR для заданной скорости

.equ EEPROM_ADDR = 0x00   ; Начальный адрес в EEPROM для хранения данных

; Инициализация указателя стека
ldi r16, high(RAMEND)
out SPH, r16
ldi r16, low(RAMEND)
out SPL, r16

; Инициализация UART
uart_init:
    ldi r16, high(MYUBRR)    ; Загрузка старшего байта UBRR
    sts UBRR0H, r16          ; Установка старшего байта UBRR
    ldi r16, low(MYUBRR)     ; Загрузка младшего байта UBRR
    sts UBRR0L, r16          ; Установка младшего байта UBRR
    ldi r16, (1<<RXEN0)|(1<<TXEN0)  ; Включение приемника и передатчика UART
    sts UCSR0B, r16
    ldi r16, (1<<UCSZ01)|(1<<UCSZ00)  ; Установка формата кадра: 8 бит данных, 1 стоп-бит
    sts UCSR0C, r16
    ret

; Отправка байта через UART
uart_send:
    cpi r16, 0               ; Проверка, не равен ли r16 0
    breq uart_send_done      ; Если равен, завершаем передачу
    sts UDR0, r16            ; Отправка байта через UART
uart_send_wait:
    sbis UCSR0A, UDRE0       ; Ожидание освобождения буфера передачи
    rjmp uart_send_wait
uart_send_done:
    ret

; Прием байта через UART
uart_receive:
    sbis UCSR0A, RXC0        ; Проверка наличия принятых данных
    rjmp uart_receive        ; Если нет данных, продолжаем ожидать
    lds r16, UDR0            ; Считывание принятого байта из буфера UART
    ret

; Запись в EEPROM
eeprom_write:
    ; r18 - адрес, r19 - данные
    ldi r20, (1<<EEMPE)      ; Разрешение записи в EEPROM
    out EECR, r20
    out EEDR, r19            ; Помещение данных в регистр данных EEPROM
    out EEARL, r18           ; Установка адреса записи
    ldi r20, (1<<EEPE)       ; Запуск записи
    out EECR, r20
    ret

; Чтение из EEPROM
eeprom_read:
    ; r18 - адрес, результат в r19
    out EEARL, r18           ; Установка адреса чтения
    ldi r20, (1<<EERE)       ; Запуск чтения
    out EECR, r20
    in r19, EEDR             ; Считывание данных из регистра данных EEPROM
    ret

; Сохранение строки в EEPROM
save_string:
    ; r18 - адрес, r24 - длина строки
    ; Байты строки находятся в регистрах Z (r30:r31)
    eeprom_write_length:
        mov r19, r24          ; Копирование длины строки в регистр данных
        rcall eeprom_write    ; Запись длины строки в EEPROM
    eeprom_write_loop:
        ld r19, Z+            ; Считывание байта строки из памяти
        rcall eeprom_write    ; Запись байта строки в EEPROM
        dec r24               ; Уменьшение счетчика длины строки
        brne eeprom_write_loop ; Повторение, пока не достигнут конец строки
    ret

; Чтение строки из EEPROM
read_string:
    ; r18 - адрес, результат в регистре Z

    ldi r30, 0               ; Инициализация указателя Z (r30:r31) на начало памяти
    ldi r31, 0

    ; Цикл чтения длины строки из EEPROM
    eeprom_read_length:
        rcall eeprom_read     ; Чтение длины строки из EEPROM в регистр r19
        mov r24, r19          ; Сохранение длины строки

    ; Цикл чтения байтов строки из EEPROM
    eeprom_read_loop:
        rcall eeprom_read     ; Чтение байта из EEPROM в регистр r19
        st Z+, r19            ; Сохранение байта строки в памяти, инкремент указателя Z
        dec r24               ; Уменьшение счетчика длины строки
        brne eeprom_read_loop ; Повторение, пока не достигнут конец строки

    ret                       ; Возврат из функции
; Очистка EEPROM
clear_eeprom:
    ; r18 - адрес
    ldi r19, 0               ; Запись 0 в EEPROM
    rcall eeprom_write       ; Запись данных в EEPROM
    ret                       ; Возврат из функции

; Основная программа
.org 0x00
    rjmp start

start:
    ; Инициализация UART
    rcall uart_init

main_loop:
    ; Ожидание ввода
    rcall uart_receive

    ; Обработка ввода
    cpi r16, 'o'             ; Проверка на команду "o" (output)
    breq output_string
    cpi r16, 'c'             ; Проверка на команду "c" (clear)
    breq clear_string
    rcall save_string        ; Сохранение введенной строки
    rjmp main_loop

output_string:
    ; Вывод сохраненной строки
    ldi r18, EEPROM_ADDR     ; Загрузка адреса EEPROM
    rcall read_string        ; Чтение строки из EEPROM
    rjmp main_loop

clear_string:
    ; Очистка сохраненной строки
    ldi r18, EEPROM_ADDR     ; Загрузка адреса EEPROM
    rcall clear_eeprom       ; Очистка EEPROM
    rjmp main_loop
