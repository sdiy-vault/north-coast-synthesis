.psize 44,144
.title "Utility routines for MSK 014 Gracious Host"
.sbttl "$Id: utils.s 9758 2022-01-08 17:01:16Z mskala $"
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
.sbttl "Exceptions"

.section .bss
exception_frame:	.skip 2

.section .text

.global TRY, TRIED, THROW

; Start an exception-handling block.  W1 should point at the exception
; handler for this block.  W0 is trashed.
TRY:
	pop	W0	; pop and discard caller address high
	pop	W0	; pop and keep caller address low

	push	exception_frame		; save old exception frame
	push	W14			; save old local variable frame
	push	W1			; save exception handler
	mov	W15, exception_frame	; save new exception frame

	goto	W0	; return to caller

; End an exception-handling block.  W0 is trashed.
TRIED:
	pop	W0	; pop and discard caller address high
	pop	W0	; pop and keep caller address low

	pop	W14	; pop and discard exception handler
tried_tail:
	pop	W14	; restore pre-TRY local variable frame
	pop	exception_frame	; restore pre-TRY exception frame

	goto	W0	; return to caller

; Branch to the current exception handler, restoring the stack and exception
; frames that existed before the TRY.  Since this unwinds the stack, it's
; possible to branch to THROW instead of calling it.  W0 is trashed.
THROW:
	mov	exception_frame, W15	; restore stack to just after TRY
	pop	W0	; get exception handler
	bra	tried_tail	; share last three instructions
	; pop	W14	; restore pre-TRY local variable frame
	; pop	exception_frame	; restore pre-TRY exception frame

	; goto	W0	; jump to handler

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "Linked lists"

; Add one or more items to the end of a single-linked list, where W0 is a
; pointer to the item(s) to add and W1 is a pointer to a pointer to the head
; of the list.  Do it with interrupts turned off.  Items each start with a
; pointer to the next item; the last item (or [W1] if list is empty) is zero
; for NULL.  The input item in W0 needs to be properly NULL-terminated, and
; can be a list of more than one item itself.

.global LL_APPEND_ATOMIC
1:
	mov	[W1], W1
LL_APPEND_ATOMIC:
	disi	#5
	cp0	[W1]
	bra	nz, 1b
	mov	W0, [W1]
	return

; Add one item (exactly) to the start of a single-linked list, where W0 is a
; pointer to the item to add and W1 is a pointer to a pointer to the head
; of the list.  Do it with interrupts turned off.

; commented out because not used anywhere in the current version; kept for
; possible future use

; .global LL_INSERT_ATOMIC
; LL_INSERT_ATOMIC:
;	disi	#2
;	mov	[W1], [W0]
;	mov	W0, [W1]
;	return

; Remove one item from a single-linked list, where W0 is a pointer to the
; item to remove and W1 is a pointer to a pointer to the head of the list. 
; Do it with interrupts turned off.  Bad idea to call this if the item is
; not actually in the list.

; commented out because not used anywhere in the current version; kept for
; possible future use

; .global LL_REMOVE_ATOMIC
; 1:
;	mov	[W1], W1
; LL_REMOVE_ATOMIC:
;	disi	#5
;	cp	W0, [W1]
;	bra	nz, 1b
;	mov	[W0], [W1]
;	clr	[W0]
;	return

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "Pseudo-random number generator"

; NOT FOR CRYPTOGRAPHIC USE

; This PRNG implements a stirred entropy pool with 160 bits of state, using
; the PIC24's CRC32 hardware.  It is meant for use in the Gracious Host's
; random note arpeggiator.  It should work pretty well, because CRC32 is a
; decent linear mixing function and there's a bit of non-linearity in the
; pool update to prevent pathological modes, but no proof of desirable
; pseudorandomness properties is offered.

; call START_CRC from loader.s to initialize CRC hardware before use

.section .bss
prng_pool:	.skip 16

.section .text

.global PRNG_HASH_TIMERS, PRNG_READ_WORD, PRNG_READ_INT

; hash the current values of T3, T4, and T5, to gain some entropy
PRNG_HASH_TIMERS:
	mov	TMR3, WREG	; XOR together the three timer registers
	swap	W0		; swap because T3, T4 both count at 2MHz
	xor	TMR4, WREG
	xor	TMR5, WREG

	bra	CRC_W0_WORD	; hash it into CRC (tail call)

prng_stir:
	add	W0, [W2], [W2]
	ff1l	[W2], W0
	add	W0, [W2], W0
	rrnc	W0, [W2]
	ff1l	[W2], W0
	add	W0, [W2++], W0
	swap	W0
	swap.b	W0
	return

prng_stir4:
	rcall	prng_stir
	rcall	prng_stir
	rcall	prng_stir
	rcall	prng_stir
	return

prng_stir8:
	mov	#prng_pool, W2
	rcall	prng_stir4
	rcall	prng_stir4
	rrnc	W0, W0
	rcall	CRC_W0_WORD
	return

; return in W0 a uniformly distributed 16-bit word; trashes W2
PRNG_READ_WORD:
	mov	CRCWDATL, W0
	rcall	prng_stir8
	rcall	prng_stir8
	rcall	prng_stir8
	mov	CRCWDATL, WREG	; get result
	return

; return in W0 a value uniformly distributed in [0..W1]; trashes W2
PRNG_READ_INT:
	rcall	PRNG_READ_WORD	; get pseudorandom bits

	ff1l	W1, W2		; find how many bits we should remove
	dec	W2, W2
	lsr	W0, W2, W0	; remove high bits

	cp	W0, W1		; quick return if it's in range
	bra	leu, 2f

1:
	clr	W0		; just hash zeros for retry
	rcall	CRC_W0_WORD
	mov	CRCWDATL, W0

	lsr	W0, W2, W0	; trim bits and check as above
	cp	W0, W1
	bra	gtu, 1b

2:
	return

.end
