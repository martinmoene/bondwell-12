;	ADUMP - a program that reads any file
;		and dumps it 16 bytes at a line
;		in hex and ascii.

;	Version 1.1	Drivename in error mess. corrected
;	   87/02/01
;	Version 1.0	Setup
;	   85/-----

	org	100h	; start of all cp/m programs

	jmp	init	; pass variable / data area

;	some useful symbolic constants

bdos	equ	0005h	; bdos entry point
creadf	equ	1	; console read function
typef	equ	2	; 	  type function
printf	equ	9	; print a buffer ending in '$'
brkf	equ	11	; break key function (true if any char)
openf	equ	15	; open a file
readf	equ	20	; read a file

fcb	equ	5ch	; file control block address
fcbdn	equ	fcb+0	; disk name
fcbfn	equ	fcb+1	; file name
fcbft	equ	fcb+9	; file type
fcbcr	equ	fcb+32	; current record number

buff	equ	80h	; input buffer address

cr	equ	0dh	; carriage return char
lf	equ	0ah	; line feed char

;	message area

signon:	db	'file hex and ascii dump - version 1.1$'
openerr:db	'd:filename.ext not found$'

;	variable area

oldsp:	ds	2	; entry sp value from ccp
ifp:	ds	2	; input file pointer
	ds	64	; reserve 32 level stack
stktop:

;	start of code area

;	subroutines

;	copych - copy characters from (de) to (hl) until b = 0

copych:
	ldax	d	; get next char of
	mov	m,a	; file name and store it
	inx	d	; increment
	inx	h	;  pointers
	dcr	b	; count down
	jnz	copych	; not done yet
	ret

;	phex -	prints value of a hexadecimally

phex:
	push	psw	; save a temporarily
	rrc		; get
	rrc		;  first
	rrc		;   nibble
	rrc		; and
	call	pnib	; print it
	pop	psw	; restore a

pnib:
	ani	0fh	; be sure to have a nibble
	cpi	10	; is it a digit ?
	jnc	letter	; no, it is a letter
	adi	'0'	; make ascii '0'..'9'
	jmp	pchar	; show it
letter:
	adi	'A'-10	; make ascii 'a'..'f'
	jmp	pchar	; show it

;	crlf -	issue carriage return, line feed

crlf:
	mvi	a,cr	; issue carriage
	call	pchar	; return character
	mvi	a,lf	; and line feed

;	pchar -	show character in a

pchar:
	push	b	; save
	push	d	;  current
	push	h	;   environment
	mvi	c,typef	; type function
	mov	e,a	; e has to contain char
	call	bdos	; for bdos
	pop	h	; restore
	pop	d	;  environment
	pop	b
	ret

;	pspec -	prints as pchar in case of a
;		printable character, otherwise
;		prints a dot (.)

pspec:
	cpi	128	; printable ?
	jnc	pdot	; no, print dot
	cpi	' '	; printable ?
	jnc	pchar	; yes, do it
pdot:
	mvi	a,'.'	; print
	jmp	pchar	;  a dot (.)


;	error and normal return

error:
	call	crlf	; end previous line
	mvi	c,printf ; print error message
	call	bdos	; (de contains address)

normal:
	call	crlf	; end previous line

;	restore ccp stack pointer

	lhld	oldsp	; ccp sp in hl
	sphl		; load sp with ccp sp
	ret		; return to ccp


;	main line

init:

;	print sign on message

        call	crlf	 ; skip 1 line
	lxi	d,signon ; start address of message
	mvi	c,printf ; print function
	call	bdos	; requested from bdos
	call	crlf	; skip 1 line

;	save ccp stack pointer and define new sp

	lxi	h,0	; entry 
	dad	sp	;  ccp sp in hl
	shld	oldsp	; save ccp sp
	lxi	sp,stktop ; load local sp, restore ccp sp at error, normal

;	enter file name in error message

	lxi	d,fcb	; address of file name
	lxi	h,openerr ; place to store
	ldax	d	; get drive name
	cpi	0	;   default drive?
	adi	'A'-1	;
	jnz	defdrv	;     no: print drivename
	mvi	a,'@'	;     yes: print '@'
defdrv:	mov	m,a	; store it
	inx	d	; first byte of file name
	inx	h	; also in
	inx	h	; message

	mvi	b,8	; nr of chars in file name
	call	copych	; copy characters
	inx	h	; update to extension

	mvi	b,3	; nr of chars in file ext
	call	copych	; copy characters

;	open file for input

	xra	a	; clear
	sta	fcbcr	; current record number
	lxi	d,fcb	; get address of fcb
	mvi	c,openf	; and code for open
	call	bdos	; function of bdos
	cpi	255	; indicates open error ?
	jnz	openok	; no, continue
	lxi	d,openerr ; yes, get address of 
	jmp	error	; error message and quit

openok:
	lxi	h,-16	; indicate
	shld	ifp	;  start of file

nextln:
	call	crlf	; fresh line

;	break and hold function
 
	mvi	c,brkf	; test for key pressed
	call	bdos	; to exit, or hold screen: ^c,^s
	rrc		; lsb of a = 1 if char ready
	jnc	incifp	; no char ready
	mvi	c,creadf ; test if
	call	bdos	;   character
	cpi	03h	;    is ^C
	jz	normal	; if so, exit

incifp:
	lhld	ifp	; increment file pointer
	lxi	d,16	; to next line
	dad	d	; and store
	shld	ifp	; it again

	mov	a,l	; see if buffer pointer
	ani	7fh	; zero - 	
	jnz	noread	; no, buffer not dumped completely

	push	h	; yes, save file pointer
	lxi	d,fcb	; read next
	mvi	c,readf	;  record from
	call	bdos	;   file
	pop	h	; restore file pointer
	ora	a	; successfully read ?
	jnz	normal	; no, indicates eof

noread:
	mov	a,h	; print
	call	phex	; current
	mov	a,l	; file pointer
	call	phex	; in hex
	mvi	a,':'	; print
	call	pchar	; seperators
	mvi	a,' '
	call	pchar

	mvi	h,0	; translate
	mov	a,l	; current file
	ani	7fh	; pointer to character
	adi	buff	; pointer in 
	mov	l,a	; input buffer

	push	h	; save current buffer pointer
	mvi	b,16	; display hex
hexlp:
	mvi	a,' '	; seperate
	call	pchar	; hex values
	mov	a,m	; get next byte
	call	phex	; show it
	inx	h	; increment buffer pointer
	dcr	b	; count down
	jnz	hexlp	; not done yet
	pop	h	; restore buffer pointer

	mvi	a,' '	; seperate
	call	pchar	; by
	mvi	a,' '	; two
	call	pchar	; spaces

	mvi	b,16	; display ascii
asclp:
	mov	a,m	; get character
	call	pspec	; and print it specially
	inx	h	; increment buffer pointer
	dcr	b	; count down
	jnz	asclp	; not done yet

	jmp	nextln	; show next line

	end
