;------------------------------------------------------------------------------
; LCD generic functions
; =====================
; Usage
; -----
; .include "m64def.inc"
; .include "lcd.inc"	; see for wiring config.
; ...
; RESET:
; 	rcall lcd_init
; 	...
; MAIN:
; 	...
; 	rcall LCD_DISPLAY_NUMBER
;------------------------------------------------------------------------------


;Function lcd_write_com: Write a command to the LCD. The data reg stores the value to be written.
lcd_write_com:
	out LCD_DATA_PORT, data ; set the data port's value up
	clr temp
	out LCD_CTRL_PORT, temp ; RS = 0, RW = 0 for a command write
	nop ; delay to meet timing (Set up time)
	sbi LCD_CTRL_PORT, LCD_E ; turn on the enable pin
	nop ; delay to meet timing (Enable pulse width)
	nop
	nop
	cbi LCD_CTRL_PORT, LCD_E ; turn off the enable pin
	nop ; delay to meet timing (Enable cycle time)
	nop
	nop
	ret

;Function lcd_write_data: Write a character to the LCD. The data reg stores the value to be written.
lcd_write_data:
	out LCD_DATA_PORT, data ; set the data port's value up
	ldi temp, 1 << LCD_RS
	out LCD_CTRL_PORT, temp ; RS = 1, RW = 0 for a data write
	nop ; delay to meet timing (Set up time)
	sbi LCD_CTRL_PORT, LCD_E ; turn on the enable pin
	nop ; delay to meet timing (Enable pulse width)
	nop
	nop
	cbi LCD_CTRL_PORT, LCD_E ; turn off the enable pin
	nop ; delay to meet timing (Enable cycle time)
	nop
	nop
	ret

;Function lcd_wait_busy: Read the LCD busy flag until it reads as not busy.
lcd_wait_busy:
	clr temp
	out LCD_DATA_DDR, temp ; Make LCD_DATA_PORT be an input port for now
	out LCD_DATA_PORT, temp
	ldi temp, 1 << LCD_RW
	out LCD_CTRL_PORT, temp ; RS = 0, RW = 1 for a command port read
	busy_loop:
		nop ; delay to meet timing (Set up time / Enable cycle time)
		sbi LCD_CTRL_PORT, LCD_E ; turn on the enable pin
		nop ; delay to meet timing (Data delay time)
		nop
		nop
		in temp, LCD_DATA_PIN ; read value from LCD
		cbi LCD_CTRL_PORT, LCD_E ; turn off the enable pin
		sbrc temp, LCD_BF ; if the busy flag is set
		rjmp busy_loop ; repeat command read
	clr temp ; else
	out LCD_CTRL_PORT, temp ; turn off read mode,
	ser temp
	out LCD_DATA_DDR, temp ; make LCD_DATA_PORT an output port again
	ret ; and return

; Function delay: Pass a number in registers r18:r19 to indicate how many microseconds
; must be delayed. Actual delay will be slightly greater (~1.08us*r18:r19).
; r18:r19 are altered in this function.
lcd_delay:
	nop ;to make 7 instructions ~= one microsecond
	subi del_lo, 1
	sbci del_hi, 0
	cpi r19, 0
	brne lcd_delay
	cpi r18, 0
	brne lcd_delay
	ret

;Function lcd_init Initialisation function for LCD.
lcd_init:
	ser temp
	out LCD_DATA_DDR, temp ; LCD_DATA_PORT, the data port is usually all otuputs
	out LCD_CTRL_DDR, temp ; LCD_CTRL_PORT, the control port is always all outputs
	ldi del_lo, low(15000)
	ldi del_hi, high(15000)
	rcall lcd_delay ; delay for > 15ms
	; Function set command with N = 1 and F = 0
	ldi data, LCD_FUNC_SET | (1 << LCD_N)
	rcall lcd_write_com ; 1st Function set command with 2 lines and 5*7 font
	ldi del_lo, low(4100)
	ldi del_hi, high(4100)
	rcall lcd_delay ; delay for > 4.1ms
	rcall lcd_write_com ; 2nd Function set command with 2 lines and 5*7 font
	ldi del_lo, low(100)
	ldi del_hi, high(100)
	rcall lcd_delay ; delay for > 100us
	rcall lcd_write_com ; 3rd Function set command with 2 lines and 5*7 font
	rcall lcd_write_com ; Final Function set command with 2 lines and 5*7 font
	rcall lcd_wait_busy ; Wait until the LCD is ready
	ldi data, LCD_DISP_OFF
	rcall lcd_write_com ; Turn Display off
	rcall lcd_wait_busy ; Wait until the LCD is ready
	ldi data, LCD_DISP_CLR
	rcall lcd_write_com ; Clear Display
	rcall lcd_wait_busy ; Wait until the LCD is ready
	; Entry set command with I/D = 1 and S = 0
	ldi data, LCD_ENTRY_SET | (1 << LCD_ID)
	rcall lcd_write_com ; Set Entry mode: Increment = yes and Shift = no
	rcall lcd_wait_busy ; Wait until the LCD is ready
	; Display on command with C = 0 and B = 1
	ldi data, LCD_DISP_ON | (1 << LCD_C)
	rcall lcd_write_com ; Trun Display on with a cursor that doesn't blink
	ret
	
LCD_CLEAR:
	; Clear screen
	rcall lcd_wait_busy
	ldi data, LCD_DISP_CLR
	rcall lcd_write_com
	ret

LCD_GOTO_LINE1:
	; Reset to line 1
	rcall lcd_wait_busy
	ldi data, LCD_ADDR_SET | LCD_LINE1
	rcall lcd_write_com
	clr LcdCharCount
	ret

LCD_GOTO_LINE2:
	; move the lcd pointer to the 2nd line
	rcall lcd_wait_busy
	ldi data, LCD_ADDR_SET | LCD_LINE2
	rcall lcd_write_com
	ldi LcdCharCount, 17
	ret

LCD_RESET:
	rcall LCD_CLEAR
	rcall LCD_GOTO_LINE1
	ret

LCD_DISPLAY_NUMBER:
	;Converts the total into separate digits for printing.
	push r20;
	push r21;
	push r22;
	push r23;
	push data;

	mov r20, number ;Temporary total
	clr r21; Hundreds
	clr r22; Tens
	clr r23; Ones

	;Extract Hundreds
	extract_100s:
		cpi r20, 100
		brlo extract_10s
		inc r21;
		subi r20, 100
		jmp extract_100s

	;Ectract Tens
	extract_10s:
		cpi r20, 10
		brlo extract_1s
		inc r22
		subi r20, 10
		rjmp extract_10s

	;Extract Ones
	extract_1s:
		cpi r20, 1
		brlo display_digits
		inc r23
		subi r20, 1
		rjmp extract_1s

	display_digits:
		mov data, r21
		cpi data, 0
		breq display_digits_two
		subi data, -'0'
		;data contains the value in ascii to be written
		rcall lcd_wait_busy
		rcall lcd_write_data	; write the character to the screen

		display_digits_two:

			cpi r22, 0
			brne display_digits_two_continue
			cpi r21, 0
			breq display_digits_one

			display_digits_two_continue:
			mov data, r22
    		subi data, -'0'
    		;data contains the value in ascii to be written
    		rcall lcd_wait_busy
    		rcall lcd_write_data	; write the character to the screen

		display_digits_one:
			mov data, r23
    		subi data, -'0'
    		;data contains the value in ascii to be written
    		rcall lcd_wait_busy
    		rcall lcd_write_data	; write the character to the screen

	pop data
	pop r23
	pop r22
	pop r21
	pop r20
	ret