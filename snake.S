/*
 * ``SuperRetroSnakeBox'' AVR GAs code
 * (c) 2020, Maksymilian Mruszczak <u at one u x dot o r g>
 * AVR GNU Assembly implementation of snake game for `atmega328p'
 *
 */


; constants
.set PINB,	0x03
.set DDRB,	0x04
.set PORTB,	0x05
.set PINA,	0x06
.set DDRA,	0x07
.set PORTA,	0x08
.set PIND,	0x09
.set DDRD,	0x0a
.set PORTD,	0x0b
.set RS,	0x00
.set RW,	0x01
.set EN,	0x02
.set D_LEFT,	0x00
.set D_DOWN,	0x01
.set D_UP,	0x02
.set D_RIGHT,	0x03
.set TCNT0,	0x26
.set SPH,	0x3E  
.set SPL,	0x3D  

.set LCD_CTL,	PORTA
.set LCD_DAT,	PORTD
.set DPAD,	PINB

; playable area size
.set AREA_W,	0x05
.set AREA_H,	0x08

; variable aliases
.equ xpos,	18
.equ ypos,	19
.equ snake_len,	20
.equ points,	21
.equ dispmt,	22
.equ dice,	3	; randomness factor; user input delay counter
			; TODO find other noise sources

; addr
.set DIGITS,	0x0000
.set SNAKE,	0x0620
.set RAMEND,	0x08FF
;DIGITS:	.byte 3
;SNAKE:	.byte 32

.text
gomsg:	.ascii "GameOver"
.global main

main:
	; init stack
	ldi r16, lo8(RAMEND)
	out SPL, r16
	ldi r16, hi8(RAMEND)
	out SPH, r16

	; init snake segments
	ldi snake_len, 3
	ldi points, 0
	ldi dispmt, 0xff	; move up
	ldi r28, lo8(SNAKE)
	ldi r29, hi8(SNAKE)
	ldi r16, 0x31
	st Y+, r16
	ldi r16, 0x33
	st Y+, r16
	ldi r16, 0x34
	st Y+, r16
	ldi r16, 0x35
	st Y+, r16
	ldi r16, 0x36
	st Y+, r16
	ldi r16, 0x37
	st Y+, r16

	; init ports
	ldi r16, 0xff
	out DDRA, r16
	out DDRD, r16
	ldi r16, 0x00
	out PORTA, r16
	out PORTD, r16
	out DDRB, r16	; input
	out PORTB, r16	; input
	cbi PORTA, RS
	cbi PORTA, RW
	cbi PORTA, EN

	; wait a bit ;P
	call delay
	call delay
	call delay
	call delay
	call delay
	call delay
	call delay
	call delay

	; init lcd
	ldi r16, 0x38
	call send
	ldi r16, 0x0c ;0x0f
	call send
	ldi r16, 0x06
	call send
	ldi r16, 0x01
	call send
	ldi r16, 0x02
	call send

	; first cycle
	mov r16, snake_len
	call render
	ldi r16, 0
	call print

live:	mov r16, dispmt
	call poll
	mov r17, snake_len
	call move
	mov dispmt, r16
	call eat
	call collision
	mov r16, snake_len
	call render
	mov r16, points
	call print
	rjmp live

	/*
	ldi r16, 0x10
	ldi r17, snake_len
	call move
	inc points
	ldi r16, snake_len
	call render
	mov r16, points
	call print
	ldi r16, 0x01
	ldi r17, snake_len
	call move
	ldi r16, snake_len
	call render
	ldi r16, 0x01
	ldi r17, snake_len
	call move
	inc points
	ldi r16, snake_len
	call render
	ldi r16, 0x01
	ldi r17, snake_len
	call move
	ldi r16, snake_len
	call render
	inc points
	ldi r16, 0x01
	ldi r17, snake_len
	call move
	ldi r16, snake_len
	call render
	ldi r16, 0xf0
	ldi r17, snake_len
	call move
	ldi r16, snake_len
	call render
	ldi r16, 0xf0
	ldi r17, snake_len
	call move
	ldi r16, snake_len
	call render
	inc points
	ldi r16, 0xff
	ldi r17, snake_len
	call move
	ldi r16, snake_len
	*/
	call render
	ldi r16, 1
	mov r16, points
	call print
	ldi r16, 0xff
stop2:	call poll
	push r16
	mov r17, snake_len
	call move
	call eat
	mov r16, snake_len
	call render
	mov r16, points
	call print
	call collision
	pop r16
	rjmp stop2
stop:	sbic DPAD, D_LEFT
	rjmp main
	rjmp stop


; displace snake position by r16
; input:
;   uint8 displacement (r16)
;   uint8 snake_len (r17)

move:
	push r16
	push snake_len
	push r17
	push r28
	push r29
	mov snake_len, r17
	ldi r28, lo8(SNAKE)
	ldi r29, hi8(SNAKE)
	subi r28, 0xff	; add 1 to skip food
	ld r17, Y
	add r16, r17
	st Y+, r16
shfsn:	ld r16, Y
	st Y+, r17
	mov r17, r16
	dec snake_len
	brne shfsn
	pop r29
	pop r28
	pop r17
	pop snake_len
	pop r16
	ret


; check if snake head collides with food
; if so add point and respawn food
; input:
;   uint8 snake_len (r20)
;   uint8 points (r21)
; output:
;   uint8 snake_len (r20)
;   uint8 points (r21)

eat:
	push r16
	push r17
	push r28
	push r29
	ldi r28, lo8(SNAKE)
	ldi r29, hi8(SNAKE)
	ld r16, Y+ ; food
	ld r17, Y ; snake head
	cp r16, r17
	brne noeat
	inc points
	inc snake_len
	rcall placef
noeat:	pop r29
	pop r28
	pop r17
	pop r16
	ret


; place food in random place

placef:
	push r16
	push r17
	push r28
	push r29
	ldi r28, lo8(SNAKE)
	ldi r29, hi8(SNAKE)
	ldi r16, AREA_H ; height
	call rand
	mov r17, r16
	ldi r16, AREA_W ; width
	call rand
	swap r16
	add r16, r17
	st Y, r16
	pop r29
	pop r28
	pop r17
	pop r16
	ret


; generate pseudorandom integer
; take some noise > multiply by upper_bound > divide by 256
; input:
;   unit8 upper_bound (r16)
; output:
;   unit8 random_int (r16)

rand:
	push r0
	push r1
	push r17
	mov r17, dice
	;in r17, TCNT0
	mul r16, r17
	ldi r17, 8
randiv:	lsr r1
	ror r0
	dec r17
	brne randiv
	mov r16, r0
	pop r17
	pop r1
	pop r0
	ret


; render snake and food glyph to LCD RAM
; input:
;   uint8 snake_len (r16)

render:
	push r16
	push r17
	push r18
	push r19
	push r20
	push r21
	push r22
	push r28
	push r29
	;mov snake_len, r16
	inc snake_len
	cbi PORTA, RS
	ldi r16, 0x40
	call send
	sbi PORTA, RS
	ldi r21, 0x00
rrow:	ldi r28, lo8(SNAKE)
	ldi r29, hi8(SNAKE)
	mov r22, snake_len
	ldi r16, 0x00
rcol:	ld xpos, Y+
	mov ypos, xpos
	andi ypos, 0x0f
	cp ypos, r21
	breq addpx
rcont:	dec r22
	brne rcol
	call send
	inc r21
	cpi r21, AREA_H
	brlo rrow
	pop r29
	pop r28
	pop r22
	pop r21
	pop r20
	pop r19
	pop r18
	pop r17
	pop r16
	ret

; to be reworked
addpx:	ldi r17, 0x01
	swap xpos
	andi xpos, 0x0f
	cpi xpos, 0x00
	breq retpx
shfpx:	lsl r17
	dec xpos
	brne shfpx
retpx:	or r16, r17
	rjmp rcont


; print points and graphics on LCD
; input:
;   unit8 points (r16)

print:
	push r16
	push r17
	push r18
	push r28
	push r29
	mov r18, r16
	ldi r28, lo8(DIGITS)
	ldi r29, hi8(DIGITS)
	mov r16, r28
	mov r17, r19
	call ddbl
	ldi r17, 0x02
	cbi PORTA, RS
	ldi r16, 0x80
	call send
	sbi PORTA, RS
prdig:	ld r16, Y+
	subi r16, 0xd0
	ldi r16, 31	; DELET DIS
	call send
	dec r17
	brne prdig

	; DEBUG
	;mov r16, r24
	;subi r16, 0xd0
	;call send
	;mov r16, r25
	;subi r16, 0xd0
	;call send
	mov r16, r18
	subi r16, 0xd0
	call send
	; ENDEBUG

	ldi r16, 0x00
	call send
	pop r29
	pop r28
	pop r18
	pop r17
	pop r16
	ret


; double dabble (2digits)
; input:
;   char * dst (r17:r16)
;   uint8 num (r18)

ddbl:
	push r29
	push r28
	push r21
	push r17
	push r16
	push r18
	mov r28, r16
	mov r29, r17
	mov r16, r18
	mov r17, r19
	ldi r18, 0x00
	mov r21, r16
	andi r21, 0x01
	brne shift
	subi r16, 0xff	; add 1 if even
shift:	mov r21, r18
	andi r21, 0x0f
	cpi r21, 0x05
	brlo skip1
	subi r18, 0xfd
skip1:	mov r21, r18
	andi r21, 0xf0
	cpi r21, 0x50
	brlo skip2
	subi r18, 0xd0	; end r18 check
skip2:	lsl r16
	rol r17
	rol r18
	cpi r17, 0x00
	brne shift
	cpi r16, 0x00
	brne shift
	mov r21, r18
	swap r21
	andi r21, 0x0f
	st Y+, r21	; digit #1
	mov r24, r21	; TMP debug
	andi r18, 0x0f
	pop r16
	mov r21, r16
	andi r21, 0x01
	brne lastd
	subi r18, 0x01	; substract 1 if was even
lastd:	st Y, r18	; digit #2
	mov r25, r18	; TMP debug
	mov r18, r16
	pop r16
	pop r17
	pop r21
	pop r28
	pop r29
	ret


; poll input
; input:
;   uint8 current_displacement (r16)
; output:
;   uint8 new_displacement (r16)

poll:
	push r17	; current displacement dim
	push r18	; counter
	push r19
	push r20
	ldi r18, 0xff
	ldi r19, 0xff
	ldi r20, 0x20
	mov r17, r16
	andi r17, 0x0f
	breq pdown	; if cur dis horizontal go to vertical
pleftc:	dec r18
	brne pleft
	ldi r18, 0xff
	dec r19
	brne pleft
	ldi r19, 0xff
	dec r20
	breq pexit
pleft:	sbis DPAD, D_LEFT
	rjmp pright
	ldi r16, 0x10
	rjmp pnull
pright:	sbis DPAD, D_RIGHT
	rjmp pleftc
	ldi r16, 0xf0
	rjmp pnull
pdownc:	dec r18
	brne pdown
	ldi r18, 0xff
	dec r19
	brne pleft
	ldi r19, 0xff
	dec r20
	breq pexit
pdown:	sbis DPAD, D_DOWN
	rjmp pup
	ldi r16, 0x01
	rjmp pnull
pup:	sbis DPAD, D_UP
	rjmp pdownc
	ldi r16, 0xff
	rjmp pnull
pnull:	nop
	nop
	nop
	nop
	inc dice
	dec r18
	brne pnull
	ldi r18, 0xff
	dec r19
	brne pnull
	ldi r19, 0xff
	dec r20
	brne pnull
pexit:	pop r20
	pop r19
	pop r18
	pop r17
	ret


; check for wall and self collision
; input:
;   uint8 snake_len

collision:
	push r16
	push r17
	push snake_len
	push r28
	push r29
	ldi r28, lo8(SNAKE)
	ldi r29, hi8(SNAKE)
	;ldi r16, 0x00
	;subi r28, 0xff
	;sbc r29, r16
	ld r16, Y+	; first smgt is food
	ld r16, Y
	andi r16, 0x0f
	cpi r16, AREA_H
	brge die
	ld r16, Y
	andi r16, 0xf0
	swap r16
	cpi r16, AREA_W
	brge die
	ld r16, Y+
cself:	ld r17, Y+
	cp r16, r17
	breq die
	dec snake_len
	brne cself
	pop r29
	pop r28
	pop snake_len
	pop r17
	pop r16
	ret
die:	jmp gameover


send:
	out PORTD, r16
	rcall delay
	sbi PORTA, EN
	rcall delay
	cbi PORTA, EN
	ret

delay:
	push r21
	push r22
	push r23
	ldi r21, 32
loop1:	ldi r22, 16
loop2:	ldi r23, 8
loop3:	nop
	dec r23
	brne loop3
	dec r22
	brne loop2
	dec r21
	brne loop1
	pop r23
	pop r22
	pop r21
	ret


gameover:
	ldi r30, lo8(gomsg)
	ldi r31, hi8(gomsg)
	ldi r17, 8
	cbi LCD_CTL, RS
	ldi r16, 0xc0
	call send
	sbi LCD_CTL, RS
gowr:	lpm r16, Z+
	call send
	dec r17
	brne gowr
	jmp stop
