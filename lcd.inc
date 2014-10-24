; LCD header file

;LCD Defs
.def temp =r16
.def data =r17
.def del_lo = r18
.def del_hi = r19
.def number = r25
.def LcdCharCount = r22

;====================================================================================
; Port mappings so can change wiring
;====================================================================================

; Data port
.equ LCD_DATA_DDR = DDRC
.equ LCD_DATA_PORT = PORTC
.equ LCD_DATA_PIN = PINC
; Control port 
; Note: if using PORTE you need to change the "LCD protocol control bits" bellow
.equ LCD_CTRL_DDR = DDRE
.equ LCD_CTRL_PORT = PORTE


;====================================================================================
; LCD operations
;====================================================================================

; LCD protocol control bits
; .equ LCD_RS = 3
; .equ LCD_RW = 1
; .equ LCD_E = 2 ; E => DS
.equ LCD_RS = 5 ; Special map for PORTE :(
.equ LCD_RW = 3
.equ LCD_E = 4 ; E => DS


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
