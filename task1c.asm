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

;Addition Defs
.def input =r28
.def keypadCount = r30
.def charCount = r22

;====================================================================================
; LCD operations
;====================================================================================

;LCD protocol control bits
.equ LCD_RS = 3
.equ LCD_RW = 1
.equ LCD_E = 2

;LCD functions
.equ LCD_FUNC_SET	= 0b00110000
.equ LCD_DISP_OFF	= 0b00001000
.equ LCD_DISP_CLR	= 0b00000001
.equ LCD_DISP_ON	= 0b00001100
.equ LCD_ENTRY_SET	= 0b00000100
.equ LCD_ADDR_SET	= 0b10000000

;LCD function bits and constants
.equ LCD_BF = 7
.equ LCD_N = 3
.equ LCD_F = 2
.equ LCD_ID = 1
.equ LCD_S = 0
.equ LCD_C = 1
.equ LCD_B = 0
.equ LCD_LINE1 = 0
.equ LCD_LINE2 = 0x40	; Set 

.cseg
	jmp RESET
RESET:
	ldi temp, low(RAMEND)
	out SPL, temp
	ldi temp, high(RAMEND)
	out SPH, temp
	
	; Init keypad
	ldi temp, PORTDDIR ; columns are outputs, rows are inputs
	out DDRB, temp
	ser temp
	clr keypadCount
	clr charCount
	
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
READ_KEYPAD:
	ldi mask, INITCOLMASK ; initial column mask
	clr col ; initial column
	clr row

	COLLOOP:
		out PORTB, mask ; set column to mask value
						; (sets column 0 off)
		
		; Delay
		ldi temp, 0xFF	; implement a delay so the
		KEYPAD_DELAY:	; hardware can stabilize
			dec temp
			brne KEYPAD_DELAY
			
		in temp, PINB ; read PORTB
		andi temp, ROWMASK ; read only the row bits
		cpi temp, 0xF ; check if any rows are grounded
		breq NEXTCOL ; if not go to the next column
		ldi mask, INITROWMASK ; initialise row check
		clr row ; initial row

	ROWLOOP:
		mov temp2, temp
		and temp2, mask ; check masked bit
		brne SKIPCONV	; if the result is non-zero we need to look again
		rjmp CONVERT 	; if bit is clear convert the bitcode
		ret
		SKIPCONV:
			inc row		; else move to the next row
			lsl mask	; shift the mask to the next bit
			jmp ROWLOOP

INCREMENT_KEYPAD:
	cpi keypadCount, 20
	brge END_INCREMENT_KEYPAD
	inc keypadCount
	END_INCREMENT_KEYPAD:
	ret

DECREMENT_KEYPAD:
	cpi keypadCount, 0
	breq END_DECREMENT_KEYPAD
	dec keypadCount
	END_DECREMENT_KEYPAD:
	ret

HANDLE_INVALID_INPUT:
	rcall DECREMENT_KEYPAD
	ret

NEXTCOL:
	cpi col, 3 				; check if we're on the last column
	brne NEXTCOL_CONTINUE	; if not, handle the next column
		; if so, return back to main after loading an invalid number into the return,
		; and setting the keypad as being okay to read from.
	jmp HANDLE_INVALID_INPUT

	NEXTCOL_CONTINUE:
		sec			; shift the column mask:
					; We must set the carry bit
		rol mask	; and then rotate left by a bit,
					; shifting the carry into
					; bit zero. We need this to make
					; sure all the rows have
					; pull-up resistors
		inc col		; increment column value
		jmp COLLOOP	; and check the next column

	; convert function converts the row and column given to a
	; binary number and also outputs the value to PORTC.
	; Inputs come from registers row and col and output is in
	; temp.
CONVERT:
	rcall INCREMENT_KEYPAD
	cpi col, 3 ; if column is 3 we have a letter
	breq letters
	cpi row, 3 ; if row is 3 we have a symbol or 0
	breq symbols
	;rcall INCREMENT_KEYPAD
	
	mov temp, row 	; otherwise we have a number (1-9)
	lsl temp 		; temp = row * 2
	add temp, row 	; temp = row * 3
	add temp, col 	; add the column address
	subi temp, -'1'
	jmp CONVERT_END

	LETTERS:
		;rcall INCREMENT_KEYPAD
		ldi temp, 'A'
		add temp, row
		jmp CONVERT_END

	SYMBOLS:
		cpi col, 0 ; check if we have a star
		breq STAR
		;rcall INCREMENT_KEYPAD
		cpi col, 1 ; or if we have zero
		breq zero
		ldi temp, '#'
		jmp CONVERT_END

	STAR:
		ldi temp, '*'
		jmp CONVERT_END

	ZERO:
		ldi temp, '0'

	CONVERT_END:
		cpi keypadCount, 2 ; if the keypad was previously being pressed, ignore this input
		brlt KEYPAD_VALID
		ret

	KEYPAD_VALID:
		mov input, temp
		rcall DISPLAY
		ret ; return to caller

;===================================================================================
; Main
; Scan the keypad for input

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

MAIN:
	;read number from keypad
	MAIN_LOOP:
		wait_one_ms
		rcall READ_KEYPAD
		jmp MAIN_LOOP
		
DISPLAY:
	cpi charCount, 16	; end of 1st line
	breq NEW_LINE
	cpi charCount, 32
	brne SHOW_CHAR
	
	; Clear screen
	rcall lcd_wait_busy
	ldi data, LCD_DISP_CLR
	rcall lcd_write_com
	; Reset to line 1
	rcall lcd_wait_busy
	ldi data, LCD_ADDR_SET | LCD_LINE1
	rcall lcd_write_com
	clr charCount
	jmp SHOW_CHAR
	
	NEW_LINE:
		; move the lcd pointer to the 2nd line
		rcall lcd_wait_busy
		ldi data, LCD_ADDR_SET | LCD_LINE2
		rcall lcd_write_com
	
	SHOW_CHAR:
		mov data, input
		rcall lcd_wait_busy
		rcall lcd_write_data
		inc charCount
	ret
