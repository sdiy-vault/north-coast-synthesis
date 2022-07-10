.psize 44,144
.title "Module tests"
.sbttl "$Id: tests.s 9758 2022-01-08 17:01:16Z mskala $"
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

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "Entry point for tests"

.section .text

.global RUN_TESTS
RUN_TESTS:

.ifdef TEST_CALIBRATION
	bra	CALIBRATION_PROCEDURE
.endif

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "Test for CRC32 calculation"

; this test checks the CRC32 value of the standard test vector, which is
; ASCII '123456789' and should have CRC32 value 0xCBF43926.  LEDs go green
; (and it retries) if the value is correct, red (and it stops) if not.

.ifdef TEST_CRC32
  .pushsection mtbl, code
	; code 2540:  run the CRC-32 calculation test
	.word	0x2540, TEST_CRC32
  .popsection

  .global CRC32_TEST
CRC32_TEST:
  .equ crc_polynomial, 0x04C11DB7
  .equ crc_init, 0x46AF6449
  .equ crc_compare, ~0xCBF43926

	bclr	TRISB, #7	; LEDs on
	bclr	TRISB, #9

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

	mov	#0x3231, W0
	mov.b	WREG, CRCDATL
	swap	W0
	mov.b	WREG, CRCDATL

	; run CRC computation
	bclr	IFS4, #CRCIF
	bset	CRCCON1, #CRCGO
1:
	btss	IFS4, #CRCIF
	bra	1b
	bclr	CRCCON1, #CRCGO

  .pushsection .bss
crc_data:	.skip 6
  .popsection

	mov	#0x3433, W0
	mov	W0, crc_data
	mov	#0x3635, W0
	mov	W0, crc_data+2
	mov	#0x3837, W0
	mov	W0, crc_data+4

	mov	#crc_data, W1
	mov	#CRCDATL, W2

	repeat	#5
	mov.b	[W1++], [W2]
	rcall	run_crc

	mov	#'9', W0
	mov.b	WREG, CRCDATL
	rcall	run_crc

	mov	#(crc_compare & 0xFF), W0
	mov.b	WREG, CRCDATL
	rcall	run_crc

	mov	#((crc_compare >> 8) & 0xFF), W0
	mov.b	WREG, CRCDATL
	rcall	run_crc

	mov	#((crc_compare >> 16) & 0xFF), W0
	mov.b	WREG, CRCDATL
	rcall	run_crc

	mov	#((crc_compare >> 24) & 0xFF), W0
	mov.b	WREG, CRCDATL
	rcall	run_crc

	; get result
	mov	CRCWDATL, WREG
	mov	W0, W6
	mov	CRCWDATH, WREG
	mov	W0, W7

	cp0	W6		; check the result is okay
	bra	nz, 1f
	cp0	W7
	bra	nz, 1f

	setm	LATB		; LEDs go green
	bra	CRC32_TEST	; try again

1:
	clr	LATB		; LEDs go red
	pwrsav	#1		; wait for interrupt
	bra	1b		; and they will lean that way forever

run_crc:
	bclr	IFS4, #CRCIF
	bset	CRCCON1, #CRCGO
1:
	btss	IFS4, #CRCIF
	bra	1b
	bclr	CRCCON1, #CRCGO
	return

.endif

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "Test for LED blinker"

.ifdef TEST_LED_BLINKER
  .pushsection mtbl, code
	; code 3183:  run the LED blinker test
	.word	0x3183, LED_BLINKER_TEST
  .popsection

  .global LED_BLINKER_TEST
LED_BLINKER_TEST:
	rcall	LEDBLINK_INIT
	mov	#0xFF00, W0
	mov	W0, LEDBLINK_RB7
	mov	W0, LEDBLINK_RB9
	mov	#0xF0C0, W0
	mov	W0, LEDBLINK_TRIS7
	mov	#0xC3C0, W0
	mov	W0, LEDBLINK_TRIS9
1:
	pwrsav	#1
	bra	1b
.endif

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "Test MIDI stream decoding"

.ifdef TEST_MIDI_STREAM
  .pushsection mtbl, code
	; code 1001:  run the MIDI stream test
	.word	0x1001, MIDI_STREAM_TEST
  .popsection

midi_stream_data:
  .byte	0x90, 0x3C, 0x66
  .byte	0x80, 0x3C, 0x00
midi_stream_end:

  .global MIDI_STREAM_TEST
MIDI_STREAM_TEST:
	rcall	MIDI_INIT
1:
	mov	#tbloffset(midi_stream_data), W9
2:
	tblrdl.b	[W9++], W0
	rcall	MIDI_READ_BYTE
	mov	#150, W0
	rcall	USB_LOOP_WAIT
	mov	#tbloffset(midi_stream_end), W0
	cp	W9, W0
	bra	ltu, 2b
	bra	1b
.endif

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "Test PRNG"

.ifdef TEST_PRNG
  .pushsection mtbl, code
	; code 5879:  run the PRNG test
	.word	0x5879, PRNG_TEST
  .popsection

  .global PRNG_TEST
PRNG_TEST:
	rcall	START_CRC
1:
	rcall	PRNG_HASH_TIMERS
	; pwrsav	#1

	mov	#15360, W1
	rcall	PRNG_READ_INT
	mov	#0x2400, W1
	add	W0, W1, W0
	rcall	NOTENUM_TO_DAC1

	mov	#15360, W1
	rcall	PRNG_READ_INT
	mov	#0x2400, W1
	add	W0, W1, W0
	rcall	NOTENUM_TO_DAC2

	bra	1b

.endif

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "Test SPI transactions to SRAM and DAC"

; this hits, in sequence, the low 64K ("moby") of SRAM, DAC1, the high moby
; of SRAM, and DAC2, with addresses and DAC values that increment each time
; around the loop.  The idea is to generate signals on the SPI bus that can
; easily be checked with an oscilloscope.

.ifdef TEST_SPI
  .pushsection mtbl, code
	; code 9485:  run the SPI hardware test
	.word	0x9485, SPI_TEST
  .popsection

  .global SPI_TEST
SPI_TEST:
	inc	W10, W10

	; read low moby of SRAM
	bclr	LATA, #3	; start transaction
	mov	#0x03, W0	; send 0x03 (READ)
	mov.b	WREG, SPI1BUF
	clr.b	SPI1BUF		; low moby
	mov	W10, W0		; high byte of address
	swap	W0
	mov.b	WREG, SPI1BUF
	swap 	W0		; low byte of address
	mov.b	WREG, SPI1BUF
	neg	W0, W0		; filler byte to get result
	mov.b	WREG, SPI1BUF

	mov	#5, W1		; read and discard five bytes
1:
	btst	SPI1STAT, #SRXMPT
	bra	nz, 1b
	mov.b	SPI1BUF, WREG
	dec	W1, W1,
	bra	nz, 1b

	bset	LATA, #3	; end transaction

	; write DAC1
	bset	LATB, #5	; rising edge on test point
	mov	W10, W0
	rcall	WRITE_DAC1

	; read high moby of SRAM
	bclr	LATB, #5	; falling edge on test point
	bclr	LATA, #3	; start transaction
	mov	#0x03, W0	; send 0x03 (READ)
	mov.b	WREG, SPI1BUF
	mov	#0x01, W0	; high moby
	mov.b	WREG, SPI1BUF
	mov	W10, W0		; high byte of address
	swap	W0
	mov.b	WREG, SPI1BUF
	swap 	W0		; low byte of address
	mov.b	WREG, SPI1BUF
	neg	W0, W0		; filler byte to get result
	mov.b	WREG, SPI1BUF

	mov	#5, W1		; read and discard five bytes
1:
	btst	SPI1STAT, #SRXMPT
	bra	nz, 1b
	mov.b	SPI1BUF, WREG
	dec	W1, W1,
	bra	nz, 1b

	bset	LATA, #3	; end transaction

	; write DAC2
	neg	W10, W0
	rcall	WRITE_DAC2

	bra	SPI_TEST
.endif

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "USB eye pattern test"

; No maintenance code for this; it doesn't seem to work, and could possibly
; be damaging, so it should be restricted to those who go out of their way
; to invoke it with a hardware debugger.

.ifdef TEST_USB_EYE_PATTERN
  .global USB_EYE_PATTERN_TEST
USB_EYE_PATTERN_TEST:
	mov	#8, W0		; enable host mode
	mov	W0, U1CON
	mov	#1, W0		; enable USB operation
	mov	W0, U1PWRC
	mov	#0x80, W0	; enable eye pattern test
	mov	W0, U1CNFG1

	; LEDs yellow, output jacks oscillate
	mov	#0xBC5F, W0	; hit both LEDs and jacks with GPIO
	mov	W0, TRISB
1:
	pwrsav	#1
	setm	LATB
	pwrsav	#1
	clr	LATB
	bra	1b
.endif

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "Trap handlers"

.ifndef TRAP_HANDLERS
  .equ TRAP_HANDLERS, 0	; default to none
.endif

; these are not shared, despite being identical, so we can breakpoint
; them individually

.section .isr_traps, code

.if (TRAP_HANDLERS&2)
  .global __OscillatorFail
__OscillatorFail:
	nop	; target for debugger breakpoints
	nop
	nop
	bra	1f
.endif

.if (TRAP_HANDLERS&4)
  .global __AddressError
__AddressError:
	nop	; target for debugger breakpoints
	nop
	nop
	bra	1f
.endif

.if (TRAP_HANDLERS&8)
  .global __StackError
__StackError:
	nop	; target for debugger breakpoints
	nop
	nop
	bra	1f
.endif

.if (TRAP_HANDLERS&16)
  .global __MathError
__MathError:
	nop	; target for debugger breakpoints
	nop
	nop
	; FALL THROUGH
.endif

.if TRAP_HANDLERS
1:
	nop	; breakpoint here to catch all traps
	nop
	nop
	reset
.endif

.end
