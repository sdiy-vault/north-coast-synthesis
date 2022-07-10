.ifndef LIST_GLOBAL_INC
  .nolist
.endif
; Global include file for MSK 014 firmware
; $Id: global.inc 9764 2022-01-15 22:19:11Z mskala $
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

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; include Microchip's standard defines for our chip (not listed)
.nolist
.include "p24Fxxxx.inc"
.list

; include configuration settings
.include "config.inc"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.equ __common_size, 1542
.extern _common

.equ __common_loc, 0
.macro in_common sym, size
  .equ \sym, (_common+__common_loc)
  .equ __common_loc, __common_loc+\size
  .if (__common_loc>__common_size)
    .error "Too much stuff in common section"
  .endif
.endm

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; sizes of things

.equ ENDPOINT_SIZE, 14
.equ IRP_SIZE, 8
.equ SETUP_SIZE, 8	; mandated by USB

; Biggest descriptor we will allow is 1K-1, which corresponds to the biggest
; transfer allowed by full-speed USB.  Anything longer and we wouldn't be
; able to read it anyway.
.equ MAX_DESCRIPTOR_SIZE, 0x3FF

; The USB hardware has been observed to write as many as three extra bytes
; past the end of the buffer we told it to fill, while reporting that it
; only wrote the requested amount.  This is a probable silicon bug.  We
; work around it by giving the buffers a little extra size.
.equ BUFFER_SAFETY_MARGIN, 7	

; amount of stack the mass storage block allocator will not consume
.equ STACK_RESERVATION, 256

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; bit numbers for the SOFT_INT_FLAGS variable.  ISRs set these bits, much
; like the hardware interrupt bits, and then software can look for them
; after an idle to see if the desired interrupts have occurred.

.equ SI_ADC1, 0		; ADC data available
.equ SI_ADC2, 1
.equ SI_CM3, 2		; comparator events
.equ SI_CM1, 3
.equ SI_BLINK1, 4	; 65.536ms LED blinker tick
.equ SI_BLINK2, 5
.equ SI_1MS, 6		; USB 1ms tick
.equ SI_VBUS_TRIP, 7	; VBUS has been too low for too long
.equ SI_BEAT, 8		; quarter-note beat has occurred

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; bit numbers for the USB_FLAGS variable.

.equ UF_ATTACHED, 0	; there is a device attached
.equ UFM_ATTACHED, 1

.equ UF_LOW_SPEED, 1	; attached device is low speed
.equ UFM_LOW_SPEED, 2

.equ UF_SENT_CTRL, 2	; we've already sent a CTRL transaction this frame
.equ UFM_SENT_CTRL, 4

.equ UF_TRUST_AD_INT, 3	; use interrupts to detect attach/detach
.equ UFM_TRUST_AD_INT, 8

.equ UF_BUSY, 4		; we've got a token in progress
.equ UFM_BUSY, 16

.equ UF_MIDI_BKGND, 5	; call MIDI_BACKGROUND during wait loops
.equ UFM_MIDI_BKGND, 32

; no ping-pong
; .equ UF_PP_OUT, 10	; use the odd out buffer next
; .equ UFM_PP_OUT, 0x400
;
; .equ UF_PP_IN, 11	; use the odd in buffer next
; .equ UFM_PP_IN, 0x800

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; endpoint flags

.equ EPF_INPUT, 0	; needs to be bit 0 because of how we set it
.equ EPFM_INPUT, 1

.equ EPF_STALLED, 1	; endpoint can't be used right now
.equ EPFM_STALLED, 2

.equ EPF_DATA1, 2	; use DATA1 on next packet
.equ EPFM_DATA1, 4

.equ EPF_INFINITE_NAK, 3	; allow infinite NAKs
.equ EPFM_INFINITE_NAK, 8

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; IRP flags

.equ IRPF_CTRL, 0
.equ IRPFM_CTRL, 1

.equ IRPF_INTR, 1
.equ IRPFM_INTR, 2

.equ IRPF_BULK, 2
.equ IRPFM_BULK, 4

.equ IRPF_ISO, 3	; unimplemented, reserved
.equ IRPFM_ISO, 8

.equ IRPF_WRITE, 8	; direction of communication
.equ IRPFM_WRITE, 0x100

.equ IRPF_ACK, 9	; for CTRL transactions - are we doing final ACK?
.equ IRPFM_ACK, 0x200

.equ IRPFM_CTRL_R, IRPFM_CTRL
.equ IRPFM_CTRL_W, IRPFM_CTRL|IRPFM_WRITE
; CTRL with no data needs the write flag so it'll get the right ACK
.equ IRPFM_CTRL_Z, IRPFM_CTRL|IRPFM_WRITE

.equ IRPF_ERROR, 10
.equ IRPFM_ERROR, 0x400

.equ IRPF_UOWN, 15	; set if we own this IRP, else foreground does
.equ IRPFM_UOWN, 0x8000

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; error codes for IRP error field

.equ ERR_SUCCESS, 0
.equ ERR_TOO_MANY_NAKS, 1

.equ ERR_PID_MASK, 0x10	; set bit in hardware's (pseudo-)PID for error code
.equ ERR_PID_BUS_TIMEOUT, 0x10
.equ ERR_PID_STALL, 0x1E
.equ ERR_PID_DATA_ERROR, 0x1F

.equ ERR_DETACHED, 0xFFFF

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; USB packet identifiers, not all of which we really use or understand

.equ PID_OUT, 1
.equ PID_ACK, 2
.equ PID_DATA0, 3
.equ PID_PING, 4
.equ PID_SOF, 5
.equ PID_NYET, 6
.equ PID_DATA2, 7
.equ PID_SPLIT, 8
.equ PID_IN, 9
.equ PID_NAK, 10
.equ PID_DATA1, 11
.equ PID_PRE, 12
.equ PID_ERR, 12	; PRE/ERR are aliased
.equ PID_SETUP, 13
.equ PID_STALL, 14
.equ PID_MDATA, 15

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.ifndef LIST_GLOBAL_INC
  .list
.endif
