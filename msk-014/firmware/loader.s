.psize 44,144
.title "Firmware-reflashing loader"
.sbttl "$Id: loader.s 9798 2022-01-28 00:21:54Z mskala $"
; Copyright (C) 2022  Matthew Skala
;
; This program is free software: you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation, version 3.
;
; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.
;
; You should have received a copy of the GNU General Public License
; along with this program.  If not, see <http://www.gnu.org/licenses/>.
;
; Matthew Skala
; https://northcoastsynthesis.com/
; mskala@northcoastsynthesis.com
;

.include "global.inc"

; constants for CRC-32, including "not direct" initialization vector
.equ crc_polynomial, 0x04C11DB7
.equ crc_init, 0x46AF6449

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "Double assembly"

; This code is meant to be assembled twice, once with and once without
; the symbol loader_high_copy defined.  The mkloaddr Perl program scans
; the object file from the "low" copy to find out how long the loader
; is, and then writes the file "loader-addr.inc" with an appropriate
; section declaration to place the "high" copy at the end of program
; memory.
;
.ifdef loader_high_copy
  .include "loader-addr.inc"
.else
  .section loader_lo, code, address(0x200)
.endif

; Start of the loader section.  This label is examined by mkloaddr
; to calculate the length of the section.
loader_start:

; Track the number of words of difference between low and high copies as a
; result of any conditional assembly that gives them different lengths
.equ loader_delta, 0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "Data memory"

in_common	b_record_page, 2
in_common	b_record_crc, 4
in_common	b_record_data, 1536

.equ __common_loc, 0

in_common	c_record_addra, 4
in_common	c_record_addrz, 4
in_common	c_record_crc, 4

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "SRAM simulation stub"

; We want to be able to test the loader in the MPLAB simulator, which
; simulates the SPI hardware but not the SRAM chip on the other end; and we
; don't want to have to write a Java plugin for the MPLAB simulator, nor tie
; our code too tightly to non-free software.  So instead, we have this code. 
; Calls to the SRAM go through macros, which by default will assemble the
; PIC24 instructions we actually want to use for talking to real hardware,
; but if the SIMULATE_SRAM flag is on then those macros will instead be
; calls to a stub that returns test data for the loader.

.ifdef SIMULATE_SRAM

  ; data used by the simulator should only be created once
  .ifndef loader_high_copy
    ; writable data for simulator variables
    .pushsection .bss

.global write_index, write_cmd, write_addr, sram_buffered
write_index:	.skip 2
write_cmd:	.skip 2
write_addr:	.skip 2
sram_buffered:	.skip 2

    .popsection

    ; image of the virtual SRAM contents
    .pushsection .text
      ; four bytes reserved for pre-roll when reading from address 0
	.long 0x0DF0ADBA

      ; the actual SRAM image (which is read-only)
.global sram_data
sram_data:
	; SRAM offset 0:  0x100 bytes of fill
	.fill 0x40, 4, 0xEFBEADDE

	; start of loader records
	; 0100 i-record:  check hardware ID
	.byte 'I', 0x0C, 0x01, 0x00
	.ascii "MSK 014",<1>

	; 010C c-record:  check CRC-32 of a block of SRAM
	.byte 'C', 0x26, 0x01, 0x00
	.word 0x011c, 0
	.word 0x0125, 0
	.long 0xCBF43926	; test CRC-32 value of the following string
	.ascii "123456789",<0>

	; 0126 j-record:  jump to top of loader loop
	.byte 'J', 0x2C, 0x01, 0x00
	.word 0x0200

	; 012C b-record:  burn a page of flash
	.byte 'B', 0x36, 0x07, 0x00
	.word 0x44
	.long 0x5402032F	; change this to test CRC32 failure
	.fill 0x60, 4, 0x0DF0ADBA
	.fill 0x60, 4, 0xFFFFFFFF
	.fill 0xC0, 4, 0x0DF0ADBA

	; 0736 b-record:  burn same page again to test duplicate detection
	.byte 'B', 0x40, 0x0D, 0x00
	.word 0x44
	.long 0x5402032F
	.fill 0x60, 4, 0x0DF0ADBA
	.fill 0x60, 4, 0xFFFFFFFF
	.fill 0xC0, 4, 0x0DF0ADBA

	; 0D40 s-record:  terminate with success
	.byte 'S', 0, 0, 0

; shared subroutines

.global _mov_to_sp1buf
_mov_to_sp1buf:
	mov	write_index, W1
	cp0	W1
	bra	nz, 8f

	mov	W0, write_cmd

8:
	cp	W1, #1
	bra	nz, 8f

	; no op; ignore the high byte of address

8:
	cp	W1, #2
	bra	nz, 8f

	; middle byte of address
	mov.b	WREG, write_addr+1

8:
	cp	W1, #3
	bra	nz, 9f

	; low byte of address
	mov.b	WREG, write_addr

9:
	inc	write_index
	inc	sram_buffered
	return

.global _mov_b_from_spi1buf
_mov_b_from_spi1buf:
	exch	W0, W4
	push.s

	mov	#psvpage(sram_data), W0
	mov	W0, _PSVPAG

	mov	#psvoffset(sram_data-4), W0
	add	write_index, WREG
	add	write_addr, WREG
	subr	sram_buffered, WREG

	mov	#0xFFFE, W2
	and	W0, W2, W1
	mov	[W1], W2

	btst	W0, #0
	bra	z, 8f
	swap	W2
8:
	mov.b	W2, W4

	dec	sram_buffered

	mov	#psvpage(HARDWARE_ID), W0
	mov	W0, _PSVPAG

	pop.s
	exch	W0, W4
	return
    .popsection
  .endif

  .macro assert_cs2
	bclr	LATA, #3
	clr	write_index
	clr	write_cmd
	clr	write_addr
	clr	sram_buffered
  .endm

  .macro retract_cs2
	bset	LATA, #3
  .endm

  .macro mov_to_spi1buf reg
	mov	\reg, SPI1BUF
	push.s
	mov	\reg, W0
	rcall	_mov_to_sp1buf
	pop.s
  .endm

  .macro clr_spi1buf
	push	W0
	clr	W0
	mov_to_spi1buf	W0
	pop	W0
  .endm

  .macro setm_spi1buf
	push	W0
	setm	W0
	mov_to_spi1buf	W0
	pop	W0
  .endm

  .macro mov_b_from_spi1buf
	rcall	_mov_b_from_spi1buf
  .endm

  .macro btst_srxmpt
	push	W0
	mov	sram_buffered, W0
	cp	W0, #0
	bra	z, 8f
	mov	#0xFFFF, W0
8:
	inc	W0, W0
	cp	W0, #0
	pop	W0	
  .endm

.else

  ; non-simulated versions of the macros

  .macro assert_cs2
	bclr	LATA, #3
  .endm

  .macro retract_cs2
	bset	LATA, #3
  .endm

  .macro mov_to_spi1buf reg
	mov	\reg, SPI1BUF
  .endm

  .macro clr_spi1buf
	clr	SPI1BUF
  .endm

  .macro setm_spi1buf
	setm	SPI1BUF
  .endm

  .macro mov_b_from_spi1buf
	mov.b	SPI1BUF, WREG
  .endm

  .macro btst_srxmpt
	btst	SPI1STAT, #SRXMPT
  .endm

.endif

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "Initialization"

; Initialization routine.  This doesn't need to be duplicated because it's
; only called when something else, such as the USB firmware, decides to go
; into firmware-loading mode.  So it's not actually in the "loader" section
; - we drop back into "text" for a while - and it's assembled conditionally.

.ifndef loader_high_copy
.pushsection .text

.global LOADER_INIT
LOADER_INIT:

	; we'll want to look at the hardware ID later
	; and this needs to be set up before we talk to the SRAM, because
	; the simulator stub also uses it (though the real SRAM doesn't)
	mov	#psvpage(HARDWARE_ID), W0
	mov	W0, _PSVPAG
	bset	CORCON, #PSV
	clr	TBLPAG

	rcall	config_timers_for_tunes

	bset	TRISB, #7	; LEDs off
	bset	TRISB, #9

	; RSTIO transaction to SRAM, to make sure it's not in a bad state
	assert_cs2
	setm_spi1buf		; send 0xFF (RSTIO)
	rcall	spi1_read_byte	; read and discard a byte
	retract_cs2

	; set the starting address for loader records
	; do this here to create a gap between SRAM transactions
	mov	#0, W3
	mov	#0x0100, W2

	; WRMR transaction to SRAM
	assert_cs2
	mov	#0x01, W0	; send 0x01 (WRMR)
	mov_to_spi1buf W0
	mov	#0x40, W0	; send 0x40 (sequential mode)
	mov_to_spi1buf W0
	rcall	spi1_read_byte	; read and discard a byte
	rcall	spi1_read_byte	; read and discard a byte
	retract_cs2

	bra	LOADER_LO_ENTRY

; configure timers and PPS as needed for success/failure tunes.  Made a
; subroutine so it can be called in the globally-visible entry points
; for those.
config_timers_for_tunes:
	; interrupt disable is here so it runs on global tune entry points
	mov	#0xE0, W0	; disable all maskable interrupts
	ior	SR

	; configure timer 1 to run free with 62.5kHz input, max period
	setm	PR1
	mov	#0x8030, W0
	mov	W0, T1CON

	; configure timer 3 to use 1:8 prescaling, for use by OC1
	setm	PR3
	mov	#0x8010, W0
	mov	W0, T3CON

	; configure output compare 1, edge-aligned PWM, 0% duty cycle
	clr	OC1R
	clr	OC1RS
	mov	#0x0406, W0	; use T3 prescaler, edge-aligned PWM
	mov	W0, OC1CON1
	mov	#0x001F, W0	; sync this OC module from itself
	mov	W0, OC1CON2

	rcall	UNLOCK_PPS	; unlock PPS config

	mov	#0x0012, W0	; PPS map output compare 1 to RP8, RP14
	mov	W0, RPOR4
	mov	W0, RPOR7

	rcall	LOCK_PPS	; lock PPS config

	return

; global entry point for the success tune, calls setup above then jumps
.global SUCCESS_TUNE
SUCCESS_TUNE:
	rcall	config_timers_for_tunes
	bra	success_tune

.popsection

.pushsection mtbl, code
	; code 4935:  play the "success" tune
	.word	0x4935, SUCCESS_TUNE
.popsection
.endif

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "Loader loop start"

; Main loop of the loader.  This reads loader records from SRAM, and
; executes them one by one.

.org 0
loader_entry:
.ifdef loader_high_copy
  .global LOADER_HI_ENTRY
  .equ LOADER_HI_ENTRY, loader_entry
.else
  .global LOADER_LO_ENTRY
  .equ LOADER_LO_ENTRY, loader_entry
.endif

; W0, W1 are general-use registers in this loop
; W3:W2 is 32-bit address (top 15 bits expected to be zeroes) of next record

	clrwdt

	; start an SRAM transaction to read current loader record
	assert_cs2

	; send a read request
	mov	#0x03, W0	; send 0x03 (READ)
	mov_to_spi1buf W0
	mov_to_spi1buf W3
	mov	W2, W0
	swap	W0
	mov_to_spi1buf W0
	mov_to_spi1buf W2

	; skip four bytes for the command, then read one for real
	mov	#5, W1
1:
	clr_spi1buf	; send another byte to keep up the flow
	rcall	spi1_read_byte
	dec	W1, W1
	bra	nz, 1b
	mov.b	W0, W1	; keep last byte in W1, it is the command

	; read new address
	rcall	spi1_read_byte
	rcall	spi1_read_byte
	swap	W0
	mov	W0, W2
	rcall	spi1_read_byte
	mov.b	W0, W3

	clr_spi1buf	; request another byte

	; going into command decoding, we still have two bytes on the way

	mov	#_common, W4	; buffer for rest of record

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "B-record - burn a page of flash memory"

	sub.b	#'B', W1
	bra	nz, 1f

	; read 1541 more bytes to buffer at W4
	mov	#1542, W5
	rcall	spi1_finish_transaction

	; do the CRC check
	rcall	start_crc
	mov	#b_record_data, W1
2:
	mov	[W1++], W0
	rcall	crc_w0_word
	mov	#(b_record_data+1536), W0
	cp	W0, W1
	bra	nz, 2b
	mov	#b_record_crc, W1
	rcall	check_crc_result

	; check that the page does not already contain this identical data

	; check_crc_result leaves W1 pointing after the CRC, at data in RAM
	; point W4 at the data in flash
	mov	b_record_page, W4
	swap	W4
	clr.b	W4
	mov	W4, W6		; save starting program address

brec_compare_loop:
	tblrdl	[W4], W0
	cp.b	W0, [W1++]
	bra	nz, brec_difference_found

	swap	W0
	cp.b	W0, [W1++]
	bra	nz, brec_difference_found

	tblrdh	[W4++], W0
	cp.b	W0, [W1++]
	bra	nz, brec_difference_found

	mov	W4, W7
	and	#0x3FF, W7	; check for page (512-insn) boundary
	bra	nz, brec_compare_loop

	; if loop finishes, we have no difference and don't need to burn
	bra	loader_entry

	; if we found a difference, we'll have to actually burn the page
brec_difference_found:
	mov	#0x4042, W0	; select flash page erase mode
	mov	W0, NVMCON
	tblwtl	W6, [W6]	; one write to establish target address

	rcall	perform_flash_operation

	; set up to do the programming
	mov	#b_record_data, W1
	setm	W8	; comparison value for blank flash word

brec_program_row_loop:
	mov	#0x4001, W0
	mov	W0, NVMCON
	clr	W9	; we "setm" this if we find row is non-blank

brec_program_insn_loop:
	mov.b	[W1++], W0	; doing a non-aligned word load here
	swap	W0
	mov.b	[W1++], W0
	swap	W0
	tblwtl	W0, [W6]
	cpseq	W0, W8		; check whether word was 0xFFFF
	setm	W9		; and set the flag in W9 if it wasn't
	mov.b	[W1++], W0
	tblwth	W0, [W6++]
	cpseq.b	W0, W8		; similar check with low byte
	setm	W9

	mov	W6, W7
	and	#0x7F, W7	; check for row (64-insn) boundary
	bra	nz, brec_program_insn_loop

	cpsne	W8, W9		; skip if flag not set, no data to program
	rcall	perform_flash_operation

	mov	W6, W7
	and	#0x3FF, W7	; check for page (512-insn) boundary
	bra	nz, brec_program_row_loop

	bra	loader_entry

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "C-record - do CRC check on a range of SRAM"

1:
	cp.b	W1, #('C'-'B')
	bra	nz, 1f

	; read 12 more bytes to buffer already named by W4
	mov	#12, W5
	rcall	spi1_finish_transaction

	rcall	start_crc	; warm up the CRC module

	; start an SRAM transaction to read the range we'll be checking
	assert_cs2

	; send a read request
	mov	#0x03, W0	; send 0x03 (READ)
	mov_to_spi1buf W0
	mov	c_record_addra+2, W5
	mov_to_spi1buf W5
	mov.b	c_record_addra+1, WREG
	mov_to_spi1buf W0
	mov	c_record_addra, W4
	mov_to_spi1buf W4

	; skip the four bytes we sent, but request new ones to replace them
	mov	#4, W1
2:
	clr_spi1buf
	rcall	spi1_read_byte
	dec	W1, W1
	bra	nz, 2b

	; double-precision subtract start from end address to count the
	; number of bytes we want to put through CRC
	mov	c_record_addra, W0
	sub	c_record_addrz
	mov	c_record_addra+2, W0
	subb	c_record_addrz+2

	; number of bytes to request from SRAM is now four less than that;
	; put it in W5:W4
	mov	c_record_addrz, W4
	mov	c_record_addrz+2, W5
	sub	#4, W4
	subb	#0, W5

	; loop while we want to process more input
crec_input_loop:
	cp0	c_record_addrz
	bra	nz, 2f
	mov	#0, W0
	cpb	c_record_addrz+2
	bra	z, crec_finished_input

2:
	; check whether to request more bytes
	cp0	W4
	bra	nz, crec_request_more	; yes, if count low word nonzero
	cp0	W5
	bra	z, crec_process_byte	; no, if both words of count zero

crec_request_more:
	clr_spi1buf	; request another byte
	dec	W4, W4	; and decrement the byte count
	subb	#0, W5

crec_process_byte:
	rcall	spi1_read_byte	; wait for one of the incoming bytes
	mov.b	WREG, CRCDATL	; send it to the CRC
	rcall	run_crc		; run the CRC (more terse if unconditional)

	; count bytes sent to CRC to control this loop
	dec	c_record_addrz
	mov	#0, W0
	subb	c_record_addrz+2
	bra	crec_input_loop

crec_finished_input:
	; at this point we have sent all bytes from SRAM through the CRC
	retract_cs2

	; check the CRC-32 is right, and finish if it is
	mov	#c_record_crc, W1
	rcall	check_crc_result
	bra	loader_entry

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "I-record - check ID of hardware platform"

1:
	cp.b	W1, #('I'-'B')
	bra	nz, 1f

	; read eight more bytes to buffer already named by W4
	mov	#8, W5
	rcall	spi1_finish_transaction
	; subroutine leaves W4 pointing just after the bytes

	; get ready for comparison loop
	mov	#psvoffset(HARDWARE_ID)+8, W5
	mov	#4, W6

2:
	mov	[--W4], W0	; check one word of ID
	cp	W0, [--W5]
	bra	nz, failure_tune

	dec	W6, W6
	bra	nz, 2b

	bra	loader_entry	

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "J-record - jump to an arbitrary address"

1:
	cp.b	W1, #('J'-'B')
	bra	nz, 1f

	rcall	spi1_read_byte	; read two-byte address already requested
	rcall	spi1_read_byte
	swap	W0		; deal with fact it was in little-endian
	retract_cs2
	goto	W0		; jump (computed absolute)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "S-record - succeed"

1:
	cp.b	W1, #('S'-'B')
	bra	nz, failure_tune	; it's an error if no known command

; play the "success tune" for one minute, LEDs solid green, then reset

success_tune:
	bset	LATB, #7	; LED1 green
	bset	LATB, #9	; LED2 green
	bclr	TRISB, #7	; LEDs on
	bclr	TRISB, #9

	mov	TMR1, W4	; W4 stores timing target
	mov	#30, W1		; run 30 two-second loops
2:
	mov	#15625, W3	; 250ms/16us

	; frequencies shown are the actual frequencies after rounding off
	; W2 values, and targeting just intonation, not 12-EDO concert pitch

	mov	#6809, W2	; d'    293.686 Hz
	rcall	play_note
	mov	#5447, W2	; fis'  367.107 Hz
	rcall	play_note
	mov	#4539, W2	; a'    440.529 Hz
	rcall	play_note
	mov	#3404, W2	; d''   587.372 Hz
	rcall	play_note
	mov	#2723, W2	; fis'' 734.214 Hz
	rcall	play_note
	mov	#2269, W2	; a''   881.057 Hz
	rcall	play_note

	clr	OC1R	; silence audio
	clr	OC1RS

	mov	#31250, W3	; 500ms/16us
	rcall	wait_ticks

	dec	W1, W1
	bra	gt, 2b
	reset

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "F-record (or unrecognized) - fail"

; command "F" is "fail," but actually any command we haven't recognized
; yet will trigger failure

; play the "failure tune" for one minute, LEDs blinking red, then reset

; global entry point for this has to call the setup first
.ifndef loader_high_copy
  .pushsection mtbl, code
	; code 6697:  play the "failure" tune
	.word	0x6697, FAILURE_TUNE
  .popsection

  .global FAILURE_TUNE
FAILURE_TUNE:
	rcall	config_timers_for_tunes
.endif
.equ loader_delta, loader_delta-2
failure_tune:

	mov	TMR1, W4	; W4 stores timing target
	mov	#31250, W3	; 500ms/16us note duration

	mov	#30, W1	; run 30 two-second loops

	bclr	LATB, #7	; LED1 red
	bclr	LATB, #9	; LED2 red

2:
	; frequencies shown are the actual frequencies after rounding off
	; W2 values, not the original 12-EDO targets

	mov	#17160, W2		; bes,  116.543 Hz
	rcall	play_failure_notes	; b,    123.472 Hz
	mov	#15288, W2		; bis,  130.813 Hz
	rcall	play_failure_notes	; b,    123.472 Hz

	dec	W1, W1
	bra	gt, 2b

.ifndef loader_high_copy
  .global RESET_INSN
RESET_INSN:
.endif
	reset

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "Subroutines needed in the loader"

; read a byte from SPI1 after waiting for one to arrive, into W0.b
; previous W0.b is preserved by swapping it into high byte
; we use this in enough places it deserves a subroutine to save bytes
; also available globally; useful outside of loader
.ifndef loader_high_copy
  .global SPI1_READ_BYTE
SPI1_READ_BYTE:
.endif
spi1_read_byte:
	swap	W0
1:
	btst_srxmpt	; wait for incoming byte
	bra	nz, 1b
	mov_b_from_spi1buf
	return

; read W5 bytes from SPI1, assuming two of those have already been
; requested, into data memory starting at address in W4, and then end
; the SRAM transaction.  Don't touch W2 or W3.  Do leave W4 pointing
; just after the end of the buffer.

spi1_finish_transaction:
	dec2	W5, W6	; two bytes already requested

1:
	cp0	W6	; check whether we need more bytes
	bra	z, 2f

	clr_spi1buf	; request one if desired
	dec	W6, W6

2:
	rcall	spi1_read_byte	; read a byte
	mov.b	W0, [W4++]	; store it

	dec	W5, W5	; and loop
	bra	nz, 1b

	retract_cs2
	return

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; play two notes while blinking the LEDs once
play_failure_notes:
	bset	TRISB, #7	; LEDs off
	bset	TRISB, #9
	rcall	play_note
	bclr	TRISB, #7	; LEDs on
	bclr	TRISB, #9
	mov	#16197, W2	; b,    123.472 Hz
	; tail call to play_note

; play a note specified in W2 for a duration in W3
; for frequency f, W2 = (2MHz/f)-1
play_note:
	lsr	W2, W0
	mov	W0, OC1R
	mov	W2, OC1RS
	; tail call to wait_ticks

; wait for a duration of W3 ticks, using W4 as reference time
wait_ticks:
	clrwdt
	add	W3, W4, W0
1:
	cp	TMR1
	bra	nz, 1b
	mov	W0, W4
	return

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; prepare the CRC module to do CRC-32 on bytes
.ifndef loader_high_copy
  .global START_CRC
START_CRC:
.endif
start_crc:
	; set up CRC module
	mov	#0x8008, W0	; enable CRC module, little endian, etc.
	mov	W0, CRCCON1
	mov	#0x071F, W0	; 8-bit data, 32-bit polynomial
	mov	W0, CRCCON2

	; set CRC polynomial
	mov	#(crc_polynomial & 0xFFFF), W0	; low 16 bits of polynomial
	mov	W0, CRCXORL
	mov	#(crc_polynomial >> 16), W0	; high 16 bits of polynomial
	mov	W0, CRCXORH

	; set CRC initialization vector
	mov	#(crc_init & 0xFFFF), W0	; low 16 bits of init vector
	mov	W0, CRCWDATL
	mov	#(crc_init >> 16), W0		; high 16 bits of init vector
	mov	W0, CRCWDATH

	return

; run the two bytes of W0 through the CRC module.  The hardware *may* be able
; to automatically do this with a single move instruction but at least in
; Microchip's simulator, that is not reliable and seems to depend on
; idiomatic use of different equivalent forms of the instruction (i.e. it's
; different depending on whether you say W0 or WREG).  I don't trust it, and
; doing the bytes separately works and seems safer.
.ifndef loader_high_copy
  .global CRC_W0_WORD
CRC_W0_WORD:
.endif
crc_w0_word:
	mov.b	WREG, CRCDATL
	swap	W0
	mov.b	WREG, CRCDATL
	; bra	run_crc		; tail call
	; FALL THROUGH

; run the CRC module until it empties its buffer
.ifndef loader_high_copy
  .global RUN_CRC
RUN_CRC:
.endif
run_crc:
	bclr	IFS4, #CRCIF
	bset	CRCCON1, #CRCGO
1:
	btss	IFS4, #CRCIF
	bra	1b
	bclr	CRCCON1, #CRCGO
	return

; check that W1 points at the correct CRC-32 of whatever has recently been
; through the CRC hardware; go to the failure tune if it is not
check_crc_result:
	; run four bytes through CRC module
	mov	[W1++], W0
	rcall	crc_w0_word
	mov	[W1++], W0
	rcall	crc_w0_word

	; check that result is 0xFFFF
	com	CRCWDATL, WREG
	bra	nz, failure_tune
	com	CRCWDATH, WREG
	bra	nz, failure_tune
	return

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; code specified by the processor data sheet
; global version includes an interrupt-disable which we don't actually need
; inside the loader
.ifndef loader_high_copy
  .global PERFORM_FLASH_OPERATION
PERFORM_FLASH_OPERATION:
	disi	#5
.equ loader_delta, loader_delta-2
.endif

perform_flash_operation:
	mov	#0x55, W0	; arming sequence
	mov	W0, NVMKEY
	mov	#0xAA, W0
	mov	W0, NVMKEY

	bset	NVMCON, #WR	; pull the trigger

	nop			; two NOPs required after pulling trigger
	nop

2:
	btsc	NVMCON, #WR
	bra	2b

	return

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; End of the loader section.  This label is examined by mkloaddr
; to calculate the length of the section.
loader_end:

.end
