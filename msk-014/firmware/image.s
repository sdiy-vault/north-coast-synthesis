.psize 44,144
.title "SRAM update image generator"
.sbttl "$Id: image.s 9798 2022-01-28 00:21:54Z mskala $"
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

; include symbols that tell us which flash pages need to be programmed
.include "fw-pages.inc"

; include symbols that tell us the CRC values we should look for and
; addresses to jump to
.include "image-syms.inc"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "Introduction and CRC checks"

; declare user-defined memory spaces for the SRAM.  It is cool that the
; assembler and linker allow us to define memory spaces for hardware we have
; that's not built into the MPU, but not so cool that they are apparently
; limited to 64K each so the 128K SRAM needs to be split into two of what we
; call "mobies," which need special handling throughout.
.memory _sram_lo, size(0x10000), origin(0)
.memory _sram_hi, size(0x10000), origin(0)

; size of the largest possible loader record
.equ max_record, 1546

; start assembling into the first moby
.section sram_lo, memory(_sram_lo)

; Macro:  detect the moby boundary and start a new section.  Separate macro
; to work around assembler listing bug.  That is, if we assemble bytes into
; a section inside a macro after the section started inside the same macro,
; then the bytes don't appear in the listing.  Anyway, this macro will start
; a new section if there isn't room in the current one for the largest
; possible loader record.
.macro check_moby
  .if (__location >= 0x10000-max_record)
    .section sram_hi, memory(_sram_hi)
  .endif
.endm

; Macro:  assemble a loader record header, jumping to the next moby if we
; couldn't assemble a maximum-size record here.  We do that even if the
; current record actually could fit, because we need to be able to predict
; whether the next record will fit too, and we don't know the size of the
; next record yet.  So we pretend all records are maximum-size for the
; purposes of deciding whether they will move to the next moby.

; The loader record header looks like an 8-bit record type identifier
; followed by a 24-bit little endian address of the next record.

.macro loader_record type, name, size
  .if (__location >= 0x10000-max_record)
    ; we don't fit in this moby
    .org 0
    .equ __moby, __moby+1
    .equ __location, \size
\name:
    .ascii "\type"
    .byte __location & 0xFF, __location >> 8
    .byte __moby

  .elseif (__location >= 0x10000-(\size)-max_record)
    ; we fit but the next record won't
    .org __location
    .equ __location, __location+\size
\name:
    .ascii "\type"
    .byte 0, 0
    .byte __moby+1

  .else
    ; both we and the next record fit
    .org __location
    .equ __location, __location+\size
\name:
    .ascii "\type"
    .byte __location & 0xFF, __location >> 8
    .byte __moby

  .endif
.endm

; Start assembling.
; We maintain a shadow location counter because the assembler won't let us
; use its own as constant data so flexibly as we want to.
.org 0
.equ __moby, 0
.equ __location, 0x100

; start of "lo" overall CRC
__crc_start__overall_lo:
.equ __moby__crc_start__overall_lo, __moby

; First 0x100 bytes are skipped by the loader but included in CRC checks. 
; Good place for a human-readable identification of what the firmware file
; is, because the people of the future may find these files in unexpected
; places without context.

.ascii "MSK 014 firmware\n"
.ascii "Copyright (C) 2022  Matthew Skala\n"
.ascii "production version\n"
.include "image-id.inc"
.ascii "\n"

; relocated to 0x100, where the loader records begin
.org 0x100
.equ __location, 0x100

; "I" record:  tells the loader that it should stop reading if it does not
; self-identify as an MSK 014 module, version 1.  Eight bytes of ID
; information after the record header are meant to be compared for equality
; with the module's ID.
loader_record "I", check_id, 12
.ascii "MSK 014",<1>

; Macro:  store a CRC value, which is 32 bits word-aligned.  We hope to pick
; it up from the include file, but will use 0xDEADBEEF if we don't have one. 
; Since this CRC may be included in other CRCs, changing it changes them,
; but the Makefile will keep re-running the assembly with updated values
; until it stops changing.  And if it never stops changing because somebody
; defined a CRC to include itself, that's their own silly fault.
.macro store_crc name
  .ifndef __crc__\name
    .equ __crc__\name, 0xEFBEADDE
  .endif
  .long __crc__\name
.endm

; "hi" CRC; covers everything after the CRC field of the "lo" CRC (next)

; Format for the "C" loader record is the four-byte header ("C" and address
; of next record); then 32-bit little endian pointers to the start (first
; byte) and end (byte after last) of the region to check; then the 32-bit
; CRC value.

check_moby
loader_record "C", crc_mid, 16
.ifndef __crc_addra__overall_hi
  .equ __crc_addra__overall_hi, 0x332211
.endif
.long __crc_addra__overall_hi
.ifndef __crc_addrz__overall_hi
  .equ __crc_addrz__overall_hi, 0x998877
.endif
.long __crc_addrz__overall_hi
store_crc overall_hi

; "lo" CRC; covers everything up to but not including its own CRC field.
check_moby
loader_record "C", crc_lo, 16
.ifndef __crc_addra__overall_lo
  .equ __crc_addra__overall_lo, 0x332211
.endif
.long __crc_addra__overall_lo
.ifndef __crc_addrz__overall_lo
  .equ __crc_addrz__overall_lo, 0x998877
.endif
.long __crc_addrz__overall_lo
__crc_end__overall_lo:
.equ __moby__crc_end__overall_lo, __moby
store_crc overall_lo
__crc_start__overall_hi:
.equ __moby__crc_start__overall_hi, __moby

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "Flash page burning"

; Macro:  generate a "B" record telling the loader to burn a page of flash
; memory, if we have loaded a symbol from the include file telling us that
; we actually want to burn this particular page.

; format for the "B" loader record is four-byte header ("B" and three bytes
; of pointer to the next record), one byte page number representing the high
; byte of the start address of the page in PIC24 program memory, four bytes
; CRC of the page data, then 1536 (that is 512 words of 3 bytes) of raw page
; data.  Total 1545 bytes.  Note all fields are word-aligned.  Page data is
; read from the appropriate offset in the file "firmware.bin," which ought
; to be a binary dump of the PIC24 program memory starting from address 0.

.macro burn_page num
  .ifdef __page_exists__\num
    loader_record "B", burn_page_\num, 1546
    .word 0x\num	; page number
    store_crc burn_page_\num
__crc_start__burn_page_\num:
.equ __moby__crc_start__burn_page_\num, __moby
    .incbin "firmware.bin",(0x\num)*384,1536
__crc_end__burn_page_\num:
.equ __moby__crc_end__burn_page_\num, __moby
  .endif
.endm

; we burn pages in descending order on the theory that we will start out
; with the "low" loader (which lives in low addresses), then once we get
; past the halfway mark we can assume we have burned a new "high" copy of
; the loader from our new firmware image (instead of depending on whatever
; was there before), then we jump to that and continue burning, eventually
; overwriting the original "low" loader.  This is how it's possible for the
; loader to completely replace itself with reasonably small overhead.

; don't burn page a8, it isn't safely self-programmable

; burn pages a4 down to 50, using assembler loops to abbreviate the code. 

check_moby
burn_page a4
check_moby
burn_page a0

.irpc x, 98765
  .irpc y, c840
    check_moby
    burn_page \x\y
  .endr
.endr

; halfway point!  jump to the high loader, which ought to have been in one
; of those pages we just burned.

; format of the "J" loader record is four bytes header followed by two
; bytes for the little endian address in PIC24 program memory to jump to.
; In this image (though an image could be designed to do other things), it's
; assumed that the place we are jumping to is actually another copy of the
; loader's main loop, so it will really just continue to interpret loader
; records after this one.

check_moby
loader_record "J", jump_high, 6
.ifndef __psym__LOADER_HI_ENTRY
  .equ __psym__LOADER_HI_ENTRY, 0x1723
.endif
.word __psym__LOADER_HI_ENTRY

; generate more burn records for all desired pages from 4c down to 00.

.irpc x, 43210
  .irpc y, c840
    check_moby
    burn_page \x\y
  .endr
.endr

; "J" record:  jump to the calibration.  The module jumps to the success
; routine and then resets after doing this, but we'll include an "S" record
; afterward anyway, just in case.

check_moby
loader_record "J", jump_calibration, 6
.ifndef __psym__CALIBRATION_PROCEDURE
  .equ __psym__CALIBRATION_PROCEDURE, 0x1723
.endif
.word __psym__CALIBRATION_PROCEDURE

; "S" record:  run the "success" routine, which turns the LEDs green and
; plays a cheery tune through one of the output jacks for 60 seconds before
; resetting the microcontroller.  This implicitly ends the loading process.

; format of the "S" record is just a header with the "S" type id.  In
; principle the header includes a 24-bit address of where the next record
; would be, but that'll be ignored.

check_moby
loader_record "S", success, 4

; this is the end of the section, and where the "hi" checksum ends.
__crc_end__overall_hi:
.equ __moby__crc_end__overall_hi, __moby

.end
