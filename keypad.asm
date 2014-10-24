;------------------------------------------------------------------------------
; Generic Keypad functions
; ========================
; To use you must define a ON_KEY_PRESS function. The value of the 'input'
; register will have the latest key pressed in ASCii.
;
; Usage
; -----
; .include "m64def.inc"
; .include "keypad.inc"		; see for wiring config.
; ...
; .cseg
; ...
; .include "keypad.asm"
; ...
; RESET:
; 	rcall KEYPAD_INIT
; 	...
; MAIN:
; 	rcall READ_KEYPAD	; calls ON_KEY_PRESS ... on key press
; 	jmp MAIN
; 	...
; ON_KEY_PRESS:
; 	cpi input, '1'	; results of a key press stored in input
; 	breq KEY_ONE_PRESSED
; 	; etc...
;------------------------------------------------------------------------------

KEYPAD_INIT:
	; Initialise keypad registers.
	ldi temp, PORTDDIR ; columns are outputs, rows are inputs
	out KP_DDR, temp
	ser temp
	clr keypadCount
	clr LcdCharCount

; main keeps scanning the keypad to find which key is pressed.
READ_KEYPAD:
	ldi mask, INITCOLMASK ; initial column mask
	clr col ; initial column
	clr row

	COLLOOP:
		out KP_PORT, mask ; set column to mask value
						; (sets column 0 off)
		
		; Delay
		ldi temp, 0xFF	; implement a delay so the
		KEYPAD_DELAY:	; hardware can stabilize
			dec temp
			brne KEYPAD_DELAY
			
		in temp, KP_PIN ; read KP_PORT
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
		rcall ON_KEY_PRESS
		ret ; return to caller
