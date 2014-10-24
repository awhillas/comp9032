; It is assumed that the following connections on the board are made:
; LCD D0-D7 -> PD0-PD7
; LCD BE-RS -> PA0-PA3
; Keypad R0-C3 -> PB0-PB7
; These ports can be changed if required by replacing all references to the ports with a
; different port. This means replacing occurences of DDRx, PORTx and PINx.

;=====================================
; Some defs were changed to avoid clashes
;=====================================
.include "m64def.inc"
;LCD Defs
.def temp =r16
.def data =r17
.def del_lo = r18
.def del_hi = r19

;Keypad Defs
.def row =r26
.def col =r27
.def mask =r21
.def temp2 =r20
.equ PORTDDIR = 0xF0
.equ INITCOLMASK = 0xEF
.equ INITROWMASK = 0x01
.equ ROWMASK = 0x0F
.equ HASHCODE = 0x0A
.equ INVALID_INPUT = 0x0B

;Addition Defs
.def total =r22
.def currentNum =r23
.def hashCount =r24
.def currentNumExists =r25
.def digit =r28
.def prevNum = r29
.def keypadCount =r30

;====================================================================================
; LCD operations
;====================================================================================

;LCD protocol control bits
.equ LCD_RS = 3
.equ LCD_RW = 1
.equ LCD_E = 2

;LCD functions
.equ LCD_FUNC_SET = 0b00110000
.equ LCD_DISP_OFF = 0b00001000
.equ LCD_DISP_CLR = 0b00000001
.equ LCD_DISP_ON = 0b00001100
.equ LCD_ENTRY_SET = 0b00000100
.equ LCD_ADDR_SET = 0b10000000

;LCD function bits and constants
.equ LCD_BF = 7
.equ LCD_N = 3
.equ LCD_F = 2
.equ LCD_ID = 1
.equ LCD_S = 0
.equ LCD_C = 1
.equ LCD_B = 0
.equ LCD_LINE1 = 0
.equ LCD_LINE2 = 0x40

.cseg
	jmp RESET
RESET:
	ldi temp, low(RAMEND)
	out SPL, temp
	ldi temp, high(RAMEND)
	out SPH, temp
	ldi temp, PORTDDIR ; columns are outputs, rows are inputs
	out DDRB, temp
	ser temp
	clr total
	clr currentNum
	clr hashCount
	clr keypadCount
	clr prevNum
	clr currentNumExists
	out DDRC, temp ; Make PORTC all outputs
	rcall lcd_init
	rjmp main

;Function lcd_write_com: Write a command to the LCD. The data reg stores the value to be written.
lcd_write_com:
	out PORTD, data ; set the data port's value up
	clr temp
	out PORTA, temp ; RS = 0, RW = 0 for a command write
	nop ; delay to meet timing (Set up time)
	sbi PORTA, LCD_E ; turn on the enable pin
	nop ; delay to meet timing (Enable pulse width)
	nop
	nop
	cbi PORTA, LCD_E ; turn off the enable pin
	nop ; delay to meet timing (Enable cycle time)
	nop
	nop
	ret

;Function lcd_write_data: Write a character to the LCD. The data reg stores the value to be written.
lcd_write_data:
	out PORTD, data ; set the data port's value up
	ldi temp, 1 << LCD_RS
	out PORTA, temp ; RS = 1, RW = 0 for a data write
	nop ; delay to meet timing (Set up time)
	sbi PORTA, LCD_E ; turn on the enable pin
	nop ; delay to meet timing (Enable pulse width)
	nop
	nop
	cbi PORTA, LCD_E ; turn off the enable pin
	nop ; delay to meet timing (Enable cycle time)
	nop
	nop
	ret

;Function lcd_wait_busy: Read the LCD busy flag until it reads as not busy.
lcd_wait_busy:
	clr temp
	out DDRD, temp ; Make PORTD be an input port for now
	out PORTD, temp
	ldi temp, 1 << LCD_RW
	out PORTA, temp ; RS = 0, RW = 1 for a command port read
busy_loop:
	nop ; delay to meet timing (Set up time / Enable cycle time)
	sbi PORTA, LCD_E ; turn on the enable pin
	nop ; delay to meet timing (Data delay time)
	nop
	nop
	in temp, PIND ; read value from LCD
	cbi PORTA, LCD_E ; turn off the enable pin
	sbrc temp, LCD_BF ; if the busy flag is set
	rjmp busy_loop ; repeat command read
	clr temp ; else
	out PORTA, temp ; turn off read mode,
	ser temp
	out DDRD, temp ; make PORTD an output port again
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
	out DDRD, temp ; PORTD, the data port is usually all otuputs
	out DDRA, temp ; PORTA, the control port is always all outputs
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

; =========================================================================================
; =========================================================================================
; =========================================================================================
; =========================================================================================
; 											KEYPAD
; =========================================================================================
; =========================================================================================
; =========================================================================================
; =========================================================================================

; main keeps scanning the keypad to find which key is pressed.
read_num:
	ldi mask, INITCOLMASK ; initial column mask
	clr col ; initial column
	clr row

	colloop:
		out PORTB, mask ; set column to mask value
		; (sets column 0 off)
		ldi temp, 0xFF ; implement a delay so the
		; hardware can stabilize

	keypad_delay:
		dec temp
		brne keypad_delay
		in temp, PINB ; read PORTB
		andi temp, ROWMASK ; read only the row bits
		cpi temp, 0xF ; check if any rows are grounded
		breq nextcol ; if not go to the next column
		ldi mask, INITROWMASK ; initialise row check
		clr row ; initial row

	rowloop:
		mov temp2, temp
		and temp2, mask ; check masked bit
		brne skipconv ; if the result is non-zero,
		; we need to look again
		rjmp convert ; if bit is clear, convert the bitcode
		ret
		skipconv:
		inc row ; else move to the next row
		lsl mask ; shift the mask to the next bit
		jmp rowloop

increment_keypad:
	cpi keypadCount, 20
	brge end_increment_keypad
	inc keypadCount
	end_increment_keypad:
	ret

decrement_keypad:
	cpi keypadCount, 0
	breq end_decrement_keypad
	dec keypadCount
	end_decrement_keypad:
	ret

handle_invalid_input:
	rcall decrement_keypad
	ldi digit, INVALID_INPUT
	ret

nextcol:
	cpi col, 3 ; check if we�re on the last column
	brne nextcol_continue  ; if not, handle the next column
	; if so, return back to main after loading an invalid number into the return,
	; and setting the keypad as being okay to read from.
	jmp handle_invalid_input

	nextcol_continue:
	sec ; shift the column mask:
	; We must set the carry bit
	rol mask ; and then rotate left by a bit,
	; shifting the carry into
	; bit zero. We need this to make
	; sure all the rows have
	; pull-up resistors
	inc col ; increment column value
	jmp colloop ; and check the next column

	; convert function converts the row and column given to a
	; binary number and also outputs the value to PORTC.
	; Inputs come from registers row and col and output is in
	; temp.
convert:
	cpi col, 3 ; if column is 3 we have a letter
	breq letters
	cpi row, 3 ; if row is 3 we have a symbol or 0
	breq symbols
	rcall increment_keypad
	mov temp, row ; otherwise we have a number (1-9)
	lsl temp ; temp = row * 2
	add temp, row ; temp = row * 3
	add temp, col ; add the column address
	; to get the offset from 1
	inc temp ; add 1. Value of switch is
	; row*3 + col + 1.
	jmp convert_end

letters: ; invalid input
	ldi temp, INVALID_INPUT
	jmp convert_end

symbols:
	cpi col, 0 ; check if we have a star
	breq star
	rcall increment_keypad
	cpi col, 1 ; or if we have zero
	breq zero
	ldi temp, HASHCODE ; we'll output 0xF for hash
	jmp convert_end

star:   ; invalid input
	ldi temp, INVALID_INPUT
	jmp convert_end

zero:
	clr temp ; set to zero

convert_end:
	cpi keypadCount, 2 ; if the keypad was previously being pressed, ignore this input
	brlt keypad_valid
	ldi digit, INVALID_INPUT ; otherwise, load an invalid value into temp
	ret

keypad_valid:
	mov digit, temp
	ret ; return to caller

;==================================================================================
; Functions for addition
; TO-DO registers may have to be saved
; atoi from lab 1 can be simplified, since we are only dealing with 1 byte values here
;==================================================================================

;Function to read the current number, like the atoi conversion
add_num:
	;-------SIMILAR TO AtoI--------------
	; Multiply digit by 10, then add to currentNum
	; currentNum = (currentNum*10) + digit
	ldi currentNumExists, 1

	ldi temp, 10
	mul currentNum, temp
	add r0, digit ;Lower byte, since we are only dealing with 1 byte numbers
	mov currentNum, r0 ;The lower byte of the result. Put back into currentNum

	ret

;If # was pressed, re-calculate the total and display
calculate:
	inc hashCount
	cpi currentNumExists, 0
	breq add_prev_num
	mov prevNum, currentNum
	add total, currentNum ;Add the current number to the total
	clr currentNum
	clr currentNumExists
	ret

	add_prev_num:
	add total, prevNum

	ret

display_result:
	out PORTC, total
	rcall lcd_init
	rcall convert_num_to_print
	ret

;===================================================================================
; Main
; Scan the keypad for a number or # continually (Like in the keypad example)
; Pseudocode below
; TO-DO may need to convert numbers to their numeric values

.macro wait_one_ms
	clr temp2
	wait_one_ms_outer_loop:
		clr temp
		wait_one_ms_inner_loop:
			inc temp
			cpi temp, 255
			brne wait_one_ms_inner_loop
		inc temp2
		cpi temp2, 7
		brne wait_one_ms_outer_loop
.endmacro

main:
	;read number from keypad
	;if number -> read_num function
	;if # -> calculate function
	main_loop:
		wait_one_ms
		rcall read_num
		cpi digit, HASHCODE
		breq handle_hash
		cpi digit, 10
		brge main_loop
		rcall add_num
		jmp main_loop

		handle_hash:
			rcall calculate
			rcall display_result
			jmp main_loop


convert_num_to_print:
	;Converts the total into separate digits for printing.
	push r20;
	push r21;
	push r22;
	push r23;
	push data;


	mov r20, total ;Temporary total
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
    		rcall lcd_write_data            ; write the character to the screen

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

	; move the lcd pointer to the 2nd line
	rcall lcd_wait_busy
	ldi data, LCD_ADDR_SET | LCD_LINE2
	rcall lcd_write_com

	; display the number of times '#' has been pressed
	mov data, hashCount
	subi data, -'0'
	rcall lcd_wait_busy
	rcall lcd_write_data

	pop data
	pop r23
	pop r22
	pop r21
	pop r20
	ret
