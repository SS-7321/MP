#include <xc.inc>
; edited


extrn	btn, bt_setup, bt_read_cycle	; methods
extrn	LCD_Setup, LCD_Send_Byte_D
extrn	bt_dec_A
    
global	m_byte, do_send, enc_byte
    
psect	udata_acs   ; reserve data space in access ram
prev_cycle: ds	1
on_cycles:  ds	1
off_cycles: ds	1
bit_pos:    ds	1
enc_byte:   ds	1
rand_byte:  ds	1
do_send:    ds	1
m_byte:	    ds	1


psect	code, abs
rst:	org	0x0000	; reset vector
	
	bsf	GIE
	goto	start

int_hi:	org	0x0008	; high vector, no low vector
	return
	
start:	
        call	bt_setup
	call	LCD_Setup
	call	reset_vals
	goto	loop
	
	
reset_vals:
	movlw	0x01
	movwf	bit_pos, A
	clrf	enc_byte
	clrf	do_send
	return


loop:	movff	btn, prev_cycle	;   new read cycle, move current to prev
	call	bt_read_cycle	;   check current state
	call	check_cycle
	
	
	
	goto	loop

check_cycle:
        tstfsz	btn, A	    ;	check if the button is pressed
	goto	cycle_on    ;	pressed
	goto	cycle_off   ;	not pressed
	
	
cycle_on:
	incf	on_cycles
	setf	do_send, A
	return
	
	
cycle_off:
    	incf	off_cycles
;   was the prev cycle off?
	tstfsz	prev_cycle, A
;   if prev on:
	goto	check_on_length	    ;	just finished input, goto encode result
;   if prev off:
	goto	check_off_length    ;	prev cycle was not off, encode prev input
	return

check_off_length:
;   is pause long enough for new character?
	movlw	20
	cpfsgt	off_cycles, A
	return	;   return if not a new character
;   if long enough:
;   encrypted a byte before during this pause?
 	tstfsz	do_send, A
	goto	wrap
	return
	
wrap:
;   if not encrypted before:
	call	enc_finish
;	call	encrypt
;	call	UART_send
	clrf	enc_byte
	clrf	do_send, A
	return
	
check_on_length:
;   is prev input dot or dash?
	movlw	12  ;	dash if 12 cycles long (12x20ms)
	cpfsgt	on_cycles, A
	call	enc_dot
	call	enc_dash
	clrf	on_cycles
	return

enc_dash:
	movf	bit_pos, W, A
	xorwf	enc_byte, F, A
	rlncf	bit_pos, F, A
	return
enc_dot:
	rlncf	bit_pos, F, A
	return
	
enc_finish:
;   set the identifier bit
	movf	bit_pos, W, A
	xorwf	enc_byte, F, A
	rlncf	bit_pos, F, A

;   mov encoded byte to Wreg
	movf	enc_byte, W, A
	movff	enc_byte, m_byte, A
	call	bt_dec_A
	call	LCD_Send_Byte_D
	call	reset_vals
	return
end	rst


