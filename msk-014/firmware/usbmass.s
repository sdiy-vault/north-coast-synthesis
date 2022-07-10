.psize 44,144
.title "Mass storage device driver"
.sbttl "$Id: usbmass.s 10185 2022-06-29 15:36:33Z mskala $"
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
.ifdef SIMULATE_USB_MASS
  .include "simdrive.inc"
.endif

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "TPL entry"

.pushsection til_usbmass, code
	mov	#handle(usbmass_driver), W4
	mov	#0x0608, W5	; class 8 "mass storage", subclass 6 "SCSI"
	mov	#80, W6		; protocol 80 "bulk-only"
	rcall	TPL_MATCH_CLASS_AND_PROTOCOL
.popsection

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "Data structures"

; Memory layout to be compatible with FIND_IN_OUT_ENDPOINTS

in_common	in_ep_ptr, 2
in_common	out_ep_ptr, 2

in_common	ep_1, ENDPOINT_SIZE
in_common	ep_2, ENDPOINT_SIZE

; IRP and buffer for CBW (command sent to device before getting data)
in_common	cbw_irp, IRP_SIZE
in_common	cbw_buffer, (31+BUFFER_SAFETY_MARGIN+1)&0xFFFE

; IRP and buffer for CSW (result block returned by device after data)
in_common	csw_irp, IRP_SIZE
in_common	csw_buffer, (13+BUFFER_SAFETY_MARGIN+1)&0xFFFE

; IRP for data transfers
in_common	data_irp, IRP_SIZE

; 32-bit number passed in CBW and returned in CSW
in_common	xaction_tag, 4

; block sizes for the drive and the buffer pool
in_common	drive_block_size, 2
in_common	buffer_size, 2
in_common	fat_block_size, 2

; block size ratios
in_common	drive_blocks_per_buffer, 2
in_common	fat_blocks_per_buffer, 2
in_common	fat_blocks_per_cluster, 2

; points to buffer_info structure for the buffer that we plan to overwrite
; next.  On loading a buffer from the drive we set this to point at the next
; one after the one we loaded; on using an already-loaded buffer, if it's
; pointed to by this variable, then we also set the pointer to the next one.
; This way we do something close to FIFO, but never evict the one most
; recently used buffer (unless we only have one).
in_common	next_victim, 2

; each buffer_info structure is six bytes:  two for the buffer address in
; data memory and then four for the (first) block number.  Buffer address is
; zero after the last one that actually exists, and we reserve two extra
; bytes at the end for this sentinel in case of hitting the max.
.equ MAX_BLOCK_BUFFERS, 24
in_common	buffer_info, MAX_BLOCK_BUFFERS*6+2

; offset of the current partition table entry in the MBR
in_common	partition_entry, 2

; drive's block index for first block of this partition, 32 bits
in_common	partition_start, 4

; FAT format we're currently trying to read.  Constants are powers of 2 for
; easy testing with bit test instructions.
.equ FAT12, 1
.equ FAT12_B, 0
.equ FAT16, 2
.equ FAT16_B, 1
.equ FAT32, 4
.equ FAT32_B, 2
in_common	fat_type, 2

; FAT block index at which first FAT begins (16 bits; equal to "reserved
; sector count" field from superblock)
in_common	fat_start, 2

; FAT block index at which hypothetical "cluster 0" would begin, 32 bits.
; real clusters start at index 2 and therefore at FAT block index
;   clusters_start+2*fat_blocks_per_cluster
in_common	clusters_start, 4

; first invalid cluster number (= actual number of clusters+2)
in_common	cluster_limit, 4

; byte offset of directory entry within current FAT block
in_common	dirent_in_block, 2

; number of (remaining) root directory entries for FAT12 and FAT16
in_common	num_dirents, 2

; CABA structure if FAT32, or 32-bit FAT block index and one unused word
; if FAT12 or FAT16
in_common	rootdir_block, 6

; CABA structure for reading file data
in_common	file_caba, 6

; address to write to in SRAM
in_common	sram_pointer, 4

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "Driver init"

.section .text

usbmass_driver:
	; look for one input and one output endpoint
	mov	#ep_1, W8
	mov	#2, W9
	rcall	USB_CONFIGURE_DEVICE
	rcall	FIND_IN_OUT_ENDPOINTS

	cp0	in_ep_ptr	; we must have an input and an output
	bra	z, THROW
	cp0	out_ep_ptr
	bra	z, THROW

.ifdef SIMULATE_USB_MASS
  .global _USB_MASS_ENTRY
_USB_MASS_ENTRY:
	; jump to here early in boot if we are faking USB mass storage
.endif

	rcall	START_CRC	; be ready to generate random numbers
	rcall	PRNG_HASH_TIMERS

	; allow infinite NAKs for both endpoints
	bset	ep_1+2, #EPF_INFINITE_NAK
	bset	ep_2+2, #EPF_INFINITE_NAK

	; FIXME do "Get Max LUN"?

ready_loop:
	mov	#100, W0	; pause to let the drive get ready
	rcall	USB_WAIT

	; CBW and CDB for SCSI TEST UNIT READY command:
	;
	;   55 53 42 43 xx xx xx xx
	;   00 00 00 00 00 00 06 00
	;   00 00 00 00 00 00 00 00
	;   00 00 00 00 00 00 00
	;
	; laid out like this:
	; CBW:
	;   00:  55 53 42 43 is magic number for a CBW
	;   04:  xx xx xx xx is 32-bit "tag" (can be arbitrary?)
	;   08:  00 00 00 00 expecting no response data
	;   0C:  00          flags for host to device
	;   0D:  00          for logical unit 0 (assumed)
	;   0E:  06          indicates CDB is six bytes long
	; CDB:
	;   0F:  00          operation code for TEST UNIT READY
	;   10:  00 00 00 00 reserved bytes
	;   14:  00          control field, no "auto contingent allocation"
	; CBW padding:
	;   15:  00 00 00 00 to make 0x1F [sic] bytes total
	;        00 00 00 00
	;        00 00 00

	mov	#0x0006, W6	; code 0x00 is TEST UNIT READY
	mov	#0, W7		; no data return (only status byte)
	rcall	set_up_cbw	; set up the CBW
	bclr	cbw_buffer+0x0C, #7	; direction flag
	rcall	wait_and_hash	; send it to device

	mov	#handle(not_ready), W1	; be ready to catch failure
	rcall	TRY
	rcall	check_csw	; THROW if CSW wasn't success
	rcall	TRIED

	bra	read_capacity

not_ready:
	cp0.b   csw_buffer+12	; check that it really was not-ready
	bra	z, THROW

	; CBW and CDB for SCSI REQUEST SENSE command:
	;
	;   55 53 42 43 xx xx xx xx
	;   08 00 00 00 80 00 06 03
	;   00 00 00 12 00 00 00 00
	;   00 00 00 00 00 00 00
	;
	; laid out like this:
	; CBW:
	;   00:  55 53 42 43 is magic number for a CBW
	;   04:  xx xx xx xx is 32-bit "tag" (can be arbitrary?)
	;   08:  08 00 00 00 expecting eight bytes data (little endian)
	;   0C:  80          is flags for data in from device to host
	;   0D:  00          for logical unit 0 (assumed)
	;   0E:  06          indicates CDB is six bytes long
	; CDB:
	;   0F:  03          operation code for REQUEST SENSE
	;   10:  00          fixed format sense data
	;   11:  00 00       reserved bytes
	;   13:  12          allocation length 18 (0x12) bytes
	;   14:  00          control field, no "auto contingent allocation"
	; CBW padding:
	;   15:  00 00 00 00 to make 0x1F [sic] bytes total
	;        00 00 00 00
	;        00 00 00

	mov	#0x0306, W6	; code 0x03 is REQUEST SENSE
	mov	#18, W7		; eighteen bytes of data
	rcall	set_up_cbw	; set up the CBW
	mov	#18, W0		; set up allocation length
	mov.b	WREG, cbw_buffer+0x13
	rcall	wait_and_hash	; send it to device

	lnk	#18		; temp buffer for sense data return

	mov	in_ep_ptr, W4	; get pointers to buffer, EP, and IRP
	mov	#data_irp, W5

	mov	W14, [W5+4]	; point IRP at buffer

	mov	#IRPFM_UOWN|IRPFM_BULK, W1	; do data read
	mov	#18, W2
	rcall	transfer_and_check_csw

	ulnk			; throw away the buffer

	bra	ready_loop

read_capacity:
	; CBW and CDB for SCSI READ CAPACITY (10) command:
	;
	;   55 53 42 43 xx xx xx xx
	;   08 00 00 00 80 00 0A 25
	;   00 00 00 00 00 00 00 00
	;   00 00 00 00 00 00 00
	;
	; laid out like this:
	; CBW:
	;   00:  55 53 42 43 is magic number for a CBW
	;   04:  xx xx xx xx is 32-bit "tag" (can be arbitrary?)
	;   08:  08 00 00 00 expecting eight bytes data (little endian)
	;   0C:  80          is flags for data in from device to host
	;   0D:  00          for logical unit 0 (assumed)
	;   0E:  0A          indicates CDB is ten bytes long
	; CDB:
	;   0F:  25          operation code for READ CAPACITY (10)
	;   10:  00          reserved/obsolete byte in SCSI command
	;   11:  00 00 00 00 obsolete "logical block address" field
	;   15:  00 00       reserved/obsolete byte in SCSI command
	;   17:  00          obsolete "PMI" field
	;   18:  00          control field, no "auto contingent allocation"
	; CBW padding:
	;   19:  00 00 00 00 00 00    to make 0x1F [sic] bytes total

	mov	#0x250A, W6	; code 0x25 is READ CAPACITY (10)
	mov	#8, W7		; eight bytes of data
	rcall	set_up_cbw	; set up the CBW
	rcall	wait_and_hash	; send it to device

	lnk	#16		; temp buffer for capacity return

	mov	in_ep_ptr, W4	; get pointers to buffer, EP, and IRP
	mov	#data_irp, W5

	mov	W14, [W5+4]	; point IRP at buffer

	mov	#IRPFM_UOWN|IRPFM_BULK, W1	; do data read
	mov	#8, W2
	rcall	transfer_and_check_csw

	; data returned for SCSI READ CAPACITY (10):
	;
	;   xx xx xx xx yy yy yy yy
	;
	; laid out like this:
	;   00:  xx xx xx xx is 32-bit index of last block, or FF...F if
	;                       it doesn't fit, BIG ENDIAN
	;   04:  yy yy yy yy is size of each block in bytes, BIG ENDIAN

.ifdef SIMULATE_USB_MASS
	; fill [W14..W14+6] with simulated data

	mov	#(_DRIVE_CAPACITY>>16), W0	; high word of capacity
	swap	W0
	mov	W0, [W14++]

	mov	#(_DRIVE_CAPACITY&0xFFFF), W0	; low word of capacity
	swap	W0
	mov	W0, [W14++]

	clr	[W14++]			; block size high is always zero

	mov	#_BLOCK_SIZE, W0	; block size low
	swap	W0
	mov	W0, [W14++]

	sub	W14, #8, W14	; return W14 to start of frame
.endif

	com	[W14], W0	; check for drive too large
	bra	nz, 1f
	mov	[W14+2], W0
	com	W0, W0
	bra	z, THROW
1:

	mov	[W14+4], W0	; make sure block size <64K
	cp	W0, #0
	bra	nz, THROW

	mov	[W14+6], W2	; get block size, convert byte order
	swap	W2
	mov	W2, drive_block_size

	rcall	init_buffer_pool	; set up the buffer data structure	

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "Read FAT superblock"

	mov	#0x01AE, W0	; offset that will increment to first entry
	mov	W0, partition_entry

	; first we look for a filesystem written directly into the MBR

	clr	W2		; read block 0
	clr	W3
	clr	partition_start
	clr	partition_start+2
	rcall	get_drive_block

; entry point for attempting to read a FAT filesystem that starts in the
; drive block whose index is stored in partition_start, and whose data is in
; a buffer pointed to by W4.

try_fat_superblock:
	mov	#0xAA55, W0	; check for "boot signature"
	mov	[W4+0x01FE], W1
	cp	W0, W1
	bra	neq, try_next_partition

	com	[W4], W0	; check for EB xx 90 magic number
	cp.b	W0, #0x14
	bra	neq, 1f
	mov	[W4+2], W0
	swap.b	W0
	cp.b	W0, #9
	bra	2f

1:
	cp.b	W0, #0x16	; check for E9 magic number
2:
	bra	neq, try_next_partition

	mov.b	[W4+0x0C], W0	; get FAT block size
	swap	W0
	mov.b	[W4+0x0B], W0
	mov	W0, fat_block_size

	clr	W0		; get FAT blocks per cluster
	mov.b	[W4+0x0D], W0
	mov	W0, fat_blocks_per_cluster

	mov	[W4+0x0E], W2	; get count of reserved FAT blocks
	mov	W2, fat_start

	mov	[W4+0x10], W3	; get number of FATs
	clr.b	WREG3H

	mov.b	[W4+0x12], W0	; get number of root dir entries
	swap	W0
	mov.b	[W4+0x11], W0

	cp0	W0		; use this to recognize FAT32
	bra	z, fat32_read_metadata
	mov	W0, num_dirents	; else just save it

	; at this point we believe we have FAT12 or FAT16

	mov.b	[W4+0x14], W6	; get total number of FAT blocks
	swap	W6
	mov.b	[W4+0x13], W6
	clr	W7

	cp0	W6		; if it's zero, get 32-bit total blocks
	bra	nz, 1f
	mov	[W4+0x20], W6
	mov	[W4+0x22], W7
1:

	mov	[W4+0x16], W8	; get number of FAT blocks per FAT

	; at this point:
	; W2 is number of reserved FAT blocks
	; W3 is number of FATs
	; W4 is pointer to superblock in buffer
	; W7:W6 is total number of FAT blocks
	; W8 is number of FAT blocks per FAT

	; we want to compute the clusters_start value, which is equal to:
	;     W2 + W3*W8 + ceil(num_dirents*32/fat_block_size)
	;        - 2*fat_blocks_per_cluster

	mov	num_dirents, W0	; W0 = num_dirents

	lsr	W0, #11, W1	; W1:W0 = num_dirents*32
	sl	W0, #5, W0

	mov	fat_block_size, W5	; W5 = fat_block_size
	add	W0, W5, W0	; W1:W0 = num_dirents*32 + W5 - 1
	addc	W1, #0, W1
	sub	W0, #1, W0
	subb	W1, #0, W1
	repeat	#17		; W0 = ceil(num_dirents*32/fat_block_size)
	div.ud	W0, W5

	mul.uu	W3, W8, W8	; W9:W8 = W3*W8' (prime means old value)

	add	W2, W8, W8	; W9:W8 = W2 + W3*W8'
	addc	W9, #0, W9

	mov	W8, rootdir_block	; this is the root dir location
	mov	W9, rootdir_block+2

	add	W0, W8, W8	; W9:W8 = W2 + W3*W8' + ceil(etc.)
	addc	W9, #0, W9

	sl	fat_blocks_per_cluster, WREG	; W9:W8 = clusters_start
	sub	W8, W0, W8
	subb	W9, #0, W9

	mov	W8, clusters_start	; save clusters_start
	mov	W9, clusters_start+2

	sub	W6, W8, W6	; measure area indexed by cluster numbers
	subb	W7, W9, W7

	mov	fat_blocks_per_cluster, W9	; find first invalid index
	repeat	#17
	div.ud	W6, W9
	mov	W0, cluster_limit
	clr	cluster_limit+2

	; Microsoft's document titled "Microsoft Extensible Firmware
	; Initiative FAT32 File System Specification" version 1.03 dated
	; December 6, 2000 is written in such an obnoxious, unprofessional,
	; and patronizing tone on this subject that they ought to be
	; embarrassed to have it on the record as an official publication,
	; but what it says eliding the smarm is that filesystems with
	; "CountOfClusters" strictly less than 4085 are FAT12, otherwise
	; FAT16 or FAT32.  The "CountOfClusters" value is the number of
	; *valid* cluster indices, which range from 2 to CountOfClusters+1,
	; because index values 0 and 1 are used for other purposes.  We have
	; calculated in W0 the smallest *invalid* index value after the
	; valid range, which is CountOfClusters+2.  The smallest FAT16
	; filesystem, per Microsoft, has CountOfCluster=4085, therefore
	; W0=4087, and we test for W0>4086 below, therefore following the
	; rule Microsoft has documented.  We do not follow Microsoft for the
	; FAT16/FAT32 determination, but use rootdir entry count instead,
	; because we need to already know whether it's FAT32 before we can
	; properly read the metadata that is used to find CountOfClusters.

	mov	#FAT16, W9	; distinguish FAT12 and FAT16
	mov	#4086, W1
	cp	W0, W1
	bra	gtu, 1f
	mov	#FAT12, W9
1:
	mov	W9, fat_type

	mov	fat_block_size, W2	; make sure buffers are big enough
	rcall	init_buffer_pool

fat1216_rootdir_block_loop:
	mov	rootdir_block, W4	; get next block of root dir
	mov	rootdir_block+2, W5
	rcall	get_fat_block

	clr	dirent_in_block	; start at start of block

1:
	rcall	look_at_dirent	; loop over directory entries
	bra	gtu, 1b

	inc	rootdir_block	; go to next FAT block
	btsc	SR, #C
	inc	rootdir_block+2

	bra	fat1216_rootdir_block_loop

fat32_read_metadata:
	mov	#FAT32, W9	; we have FAT32
	mov	W9, fat_type

	add	W4, #0x1E, W0	; prepare for mov instructions
	mov	#WREG6, W1
	repeat	#7		; move block of data into registers
	mov	[++W0], [W1++]

	; at this point:
	; W2 is number of reserved FAT blocks
	; W3 is number of FATs
	; W4 is pointer to superblock in buffer
	; W7:W6 is total number of FAT blocks
	; W9:W8 is number of FAT blocks per FAT
	; W10 is drive description/mirroring flags (ignored)
	; W11 is FAT32 version
	; W13:W12 is cluster number of root directory start

	cp0	W11		; make sure version is zero
	bra	nz, try_next_partition

	clr	rootdir_block	; set up CABA for root dir read
	mov	W12, rootdir_block+2
	mov	W13, rootdir_block+4

	; we want to compute the clusters_start value, which is equal to:
	;     W2 + W3*(W9:W8) - 2*fat_blocks_per_cluster

	mul.uu	W3, W8, W0	; W1:W0 + W8:0 = W3*(W9':W8')
	mul.uu	W3, W9, W8

	add	W2, W0, W2	; W3:W2 = W2' + W3'*(W9':W8')
	addc	W8, W1, W3

	sl	fat_blocks_per_cluster, WREG	; W3:W2 = clusters_start
	sub	W2, W0, W2
	subb	W3, #0, W3

	mov	W2, clusters_start	; save clusters_start
	mov	W3, clusters_start+2

	sub	W6, W2, W6	; measure area indexed by cluster numbers
	subb	W7, W3, W7

	mov	fat_blocks_per_cluster, W9	; find first invalid index
	repeat	#17		; high part of division
	div.uw	W7, W9
	exch	W0, W6
	repeat	#17		; low part
	div.ud	W0, W9
	mov	W0, cluster_limit	; save result
	mov	W6, cluster_limit+2

	mov	fat_block_size, W2	; make sure buffers are big enough
	rcall	init_buffer_pool

fat32_rootdir_block_loop:
	mov	#rootdir_block, W2	; get next block of root dir
	rcall	get_caba

	clr	dirent_in_block	; start at start of block
	setm	num_dirents	; disable check for number of dirents

1:
	rcall	look_at_dirent	; loop over directory entries
	bra	gtu, 1b

	mov	#rootdir_block, W2	; go to next FAT block
	rcall	increment_caba

	bra	gtu, fat32_rootdir_block_loop

	; FALL THROUGH

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "Handle partition table"

try_next_partition:
	mov	#16, W0		; go to next entry
	add	partition_entry

	mov	#0x01FE, W0	; THROW if we've tried them all
	cp	partition_entry
	bra	geu, THROW

	clr	W2		; read block 0
	clr	W3
	rcall	get_drive_block

	mov	[W4+0x01FE], W0	; partition table must have boot signature
	mov	#0xAA55, W1
	cp	W0, W1
	bra	neq, THROW

	mov	partition_entry, W5	; find current partition entry
	add	W4, W5, W5

	mov.b	[W5+4], W0	; make sure "type" is nonzero
	cp.b	W0, #0
	bra	eq, try_next_partition

	mov	[W5+8], W2	; get start of partition
	mov	[W5+10], W3

	cp0	W2		; partition start must be nonzero
	bra	neq, 1f
	cp0	W3
	bra	eq, try_next_partition
1:

	mov	W2, partition_start	; save partition start
	mov	W3, partition_start+2

	rcall	get_drive_block	; read superblock

	bra	try_fat_superblock

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "Handle a directory entry"

look_at_dirent:
	mov	dirent_in_block, W0	; index into block
	add	W0, W4, W1

.pushsection *, code
firmware_fn:
	.ascii	"FIRMWAREFRM\xFF"
.popsection

	mov	#tbloffset(firmware_fn), W0	; look at filename

1:
	mov	[W1++], W2	; loop over filename
	tblrdl	[W0++], W3

	btst	W3, #15		; high bit means last word
	bra	nz, 2f

	cp	W2, W3		; if not last word, check for match
	bra	eq, 1b

	; FALL THROUGH

look_at_next_dirent:
	mov	#32, W0		; increment dirent by 32 bytes
	add	dirent_in_block, WREG
	mov	W0, dirent_in_block

	dec	num_dirents	; check against length of root dir
	bra	z, try_next_partition

	cp	fat_block_size	; check whether still in same FAT block
	bra	gtu, 1f

	clr	dirent_in_block	; go to next FAT block of root dir
1:
	return

2:
	; filename matches, except possibly last byte

	cp.b	W2, W3		; check last byte
	bra	neq, look_at_next_dirent

	bclr	LATA, #3	; sent RSTIO to put SRAM in known state
	setm	SPI1BUF
	rcall	SPI1_READ_BYTE
	bset	LATA, #3

	clr	file_caba	; block zero in cluster
	mov	[W1+14], W0	; low word of cluster
	mov	W0, file_caba+2
	clr	W0		; high word of cluster
	btsc	fat_type, #FAT32_B
	mov	[W1+8], W0
	mov	W0, file_caba+4

	clr	sram_pointer	; we will start at the start of SRAM
	clr	sram_pointer+2

	bclr	LATA, #3	; send WRMR to put SRAM in sequential mode
	mov	#0x4001, W0	; low WRMR, high sequential mode
	mov.b	WREG, SPI1BUF
	swap	W0
	mov.b	WREG, SPI1BUF
	rcall	SPI1_READ_BYTE
	rcall	SPI1_READ_BYTE
	bset	LATA, #3

1:
	mov	#file_caba, W2	; get next block of file
	rcall	get_caba

	mov	fat_block_size, W1
	mov	sram_pointer, W2
	mov	sram_pointer+2, W3

	bclr	LATA, #3	; start SPI transaction

	mov	#2, W0		; WRITE command
	mov.b	WREG, SPI1BUF
	mov.b	W3, W0		; high byte of address
	mov.b	WREG, SPI1BUF
	mov.b	WREG2H, WREG	; middle byte of address
	mov.b	WREG, SPI1BUF
	mov.b	W2, W0		; low byte of address
	mov.b	WREG, SPI1BUF
	rcall	SPI1_READ_BYTE	; read and discard four bytes
	rcall	SPI1_READ_BYTE
	rcall	SPI1_READ_BYTE
	rcall	SPI1_READ_BYTE

2:
	mov.b	[W4++], W0	; send one byte to SRAM
	mov.b	WREG, SPI1BUF
	rcall	SPI1_READ_BYTE

	dec	W1, W1		; loop until end of block
	bra	nz, 2b

	bset	LATA, #3	; end SPI transation

	mov	fat_block_size, W0	; move up SRAM pointer
	add	sram_pointer
	clr	W0
	addc	sram_pointer+2

	mov	#file_caba, W2	; go to the next FAT block of file
	rcall	increment_caba
	bra	gtu, 1b

	ulnk			; remove stack frame

	bra	LOADER_INIT	; flash program memory and recalibrate

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "Follow FAT chain"

; These subroutines deal with 6-byte "cluster and block addresses" pointed
; to by W2 on entry, where [W2] is the index of the FAT block within a
; cluster (range 0 to blocks per sector-1) and [W2+4]:[W2+2] is the 32-bit
; cluster number (where 2 is the first cluster, per FAT definition).

; returns "LEU" status iff end of file
increment_caba:
	inc	[W2], [W2]	; increment block within cluster

	mov	fat_blocks_per_cluster, W0	; still in same cluster?
	mov	[W2], W1
	cp	W0, W1
	bra	gtu, RETURN_INSN

	push	W2		; we'll need W2 again later

	mov	[W2+2], W4	; get cluster number into W5:W4
	mov	[W2+4], W5

	btst	fat_type, #FAT12_B	; check for FAT12
	bra	z, 1f

	mul.uu	W5, #3, W0	; FAT12:  multiply by 3
	mul.uu	W4, #3, W2
	add	W0, W3, W3

	lsr	W3, W3		; divide by 2
	rrc	W2, W2

	bra	2f

1:
	sl	W4, W2		; FAT16 or FAT32:  multiply by 2
	rlc	W5, W3

	btst	fat_type, #FAT16_B	; check for FAT16
	bra	nz, 2f

	sl	W2, W2		; FAT32:  multiply by 2 again
	rlc	W3, W3

2:
	; at this point W3:W2 is byte index of entry within FAT

	mov	fat_block_size, W4	; get block size
	repeat	#17		; high part of division
	div.uw	W3, W4
	mov	W0, W3		; save high part result
	mov	W2, W0		; set up low part
	repeat	#17		; low part of division
	div.ud	W0, W4
	push	W1		; save remainder

	; at this point block number within FAT is in W3:W0

	mov	fat_start, W4	; find block number within partition
	add	W0, W4, W4
	addc	W3, #0, W5

	rcall	get_fat_block	; get block (index in W5:W4) into a buffer

	pop	W1		; restore byte index in buffer
	pop	W2		; restore CABA pointer

	add	W1, W4, W4	; find byte where entry starts

	clr	[W2++]		; set block within cluster to zero

	btst	fat_type, #FAT12_B	; test for FAT12
	bra	z, 1f

	mov.b	[++W4], W0	; get first byte of entry

	btss	[W2], #0	; assemble 12-bit entry
	and	W0, #0xF, W0
	swap	W0
	mov.b	[--W4], W0
	btsc	[W2], #0
	lsr	W0, #4, W0

	mov	W0, [W2++]	; save entry in CABA
	clr	[W2]

	bra	3f
1:
	; FAT16 or FAT32

	mov	[W4++], [W2++]	; get first 16 bits of entry
	clr	W0		; high word defaults to zero
	btss	fat_type, #FAT16_B	; check for FAT32
	mov	[W4], W0	; get high word
	mov	#0x0FFF, W1	; clear top 4 bits
	and	W0, W1, [W2]

3:
	mov	[--W2], W0	; compare against 1
	cp	W0, #1
	mov	[++W2], W0
	cpb	W0, #0
	bra	leu, THROW	; cluster <= 1 means bad FAT

	mov	[--W2], W0	; compare against cluster limit
	cp	cluster_limit
	mov	[++W2], W0
	cpb	cluster_limit+2	; limit <= index means EOF

	return

; return pointer to data in W4
get_caba:
	mov	fat_blocks_per_cluster, W0	; do 32x16->32 multiply
	mul.uu	W0, [++W2], W4
	mul.uu	W0, [++W2], W0
	add	W0, W5, W5

	mov	[W2-4], W0	; add block within cluster
	mov	clusters_start+2, W1
	add	clusters_start, WREG
	addc	W1, #0, W1

	add	W0, W4, W4	; finish FAT block calculation
	addc	W1, W5, W5

	; bra	get_fat_block	; tail call
	; FALL THROUGH

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "FAT-level block loading"

; get the FAT block at index W5:W4 into a cache buffer and return its
; address.  Note this guarantees to get all of the FAT block (even if it is
; more than one drive block) but does not guarantee to get any more than
; that (if a buffer happens to be bigger than one FAT block); the returned
; pointer in W4 may be into the middle of a buffer.
get_fat_block:
	mov	fat_blocks_per_buffer, W2	; check block size
	cp	W2, #1
	bra	leu, 1f

	; FAT block is smaller than drive block

	; do 32x16->32 divide to find drive block offset into partition
	repeat	#17		; high part of division
	div.uw	W5, W2
	exch	W0, W4		; save result, prepare low part
	repeat	#17		; low part of division
	div.ud	W0, W2

	mov	fat_block_size, W2	; figure out offset into block
	mul.uu	W1, W2, W8 		; note W9 ends up zero

	mov	W4, W1		; put in saved high part

	bra	2f

1:
	; FAT block is at least as big as drive block

	; do 32x16->32 multiply to find drive block offset into partition
	mov	drive_blocks_per_buffer, W2
	mul.uu	W4, W2, W0	; low part of multiplication
	mul.uu	W5, W2, W2	; high part of multiplication
	add	W1, W2, W1	; combine them

	clr	W8		; offset into drive block is zero

2:
	; at this point W1:W0 is drive block offset into partition
	; W8 is offset of FAT block inside drive block

	; add partition start (32+32->32 unsigned) to obtain drive block
	mov	partition_start, W2
	mov	partition_start+2, W3
	add	W0, W2, W2
	addc	W1, W3, W3

	rcall	get_drive_block	; read drive block

	add	W4, W8, W4	; find FAT block inside drive block

	return

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "Drive-level buffer pool"

; takes FAT block size in W2.  Should be even, up to 4096 allowed.
; buffers actually get BUFFER_SAFETY_MARGIN (rounded up) extra bytes to
; accommodate hardware overrun.  Trashes W0, W1, W3, W4.
; This replaces the existing lnk/ulnk stack frame; caller must create one
; before entry.
init_buffer_pool:
	; figure out a buffer size that works, and save associated ratios

	mov	drive_block_size, W3	; check for buffer < drive block
	cp	W3, W2
	bra	leu, 1f

	; drive block is > FAT block

	repeat	#17		; find FAT blocks per drive block
	div.u	W3, W2
	mov	W0, fat_blocks_per_buffer

	mov	W3, W2		; expand buffer to one drive block
	mov	#1, W0
	mov	W0, drive_blocks_per_buffer

	bra	2f

1:
	; drive block is =< FAT block

	repeat	#17		; find drive blocks per FAT block
	div.u	W2, W3
	mov	W0, drive_blocks_per_buffer

	mov	#1, W0		; one FAT block per buffer
	mov	W0, fat_blocks_per_buffer

2:
	mov	W2, buffer_size	; save buffer size

	pop	W3		; get return address into W3
	pop	W3

	ulnk			; discard existing stack frame
	lnk	#0		; establish a new stack frame

	; figure out how many buffers we can safely allocate
	; assembler and linker will allow us to use __DATA_BASE
	; or __DATA_LENGTH but not both, so we hardcode the value
	; of __DATA_BASE here; it is 0x0800.
	mov	#(0x0800+__DATA_LENGTH-STACK_RESERVATION), W0
	sub	W0, W15, W0
	add	W2, #((BUFFER_SAFETY_MARGIN+1)&0xFFFE), W2
	repeat	#17
	div.u	W0, W2

	cp	W0, #MAX_BLOCK_BUFFERS	; limit buffer count to maximum
	bra	leu, 1f
	mov	#MAX_BLOCK_BUFFERS, W0
1:

	cp	W0, #0		; we must have at least one buffer
	bra	z, THROW

	mov	#buffer_info, W4	; prepare to loop over buffers
	mov	W4, next_victim		; reset cache replacement policy

1:
	dec	W0, W0		; update loop counter

	mov	W15, [W4++]	; allocate buffer on stack, save address
	add	W15, W2, W15

	setm	[W4++]		; init block number to FF...F
	setm	[W4++]

	cp	W0, #0		; loop again
	bra	nz, 1b

	clr	[W4]		; sentinel after last allocated buffer

	goto	W3		; return from subroutine

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Get the block at drive index W3:W2 into a cache buffer and return the
; address of the buffer in W4.  Trashes W0-W7.  Note that this fills the
; buffer even if it's more than one block, but always arranges to have the
; requested block at the start of the buffer (even if we have some other
; buffer that happens to contain it by starting at some other block a little
; before).

get_drive_block:
	mov	#(buffer_info-6), W4	; prepare to scan cache

1:
	add	W4, #6, W4	; go to next cached buffer

	cp0	[W4]		; check for end of cache sentinel
	bra	z, 1f

	; we have a cached block to look at

	mov	[W4+2], W0	; compare first word of block index
	cp	W0, W2
	bra	neq, 1b
	mov	[W4+4], W0	; compare second word of block index
	cp	W0, W3
	bra	neq, 1b

	; cached block is the one we're looking for

find_new_victim:
	mov	next_victim, W0	; this block gets a reprieve if it's next
	cp	W0, W4
	bra	neq, 2f

	add	W0, #6, W0	; move the "next victim" pointer to next block

	cp0	[W0]		; and make sure that block exists
	bra	nz, 3f

	mov	#buffer_info, W0	; if not, go back to first block

3:
	mov	W0, next_victim	; save the new "next victim" value

2:
	inc2	W4, W0		; W0 will point at place to save block index
	mov	[W4], W4	; return buffer address in W4
	return

1:
	; can't find block in cache; must evict one

	mov	next_victim, W4	; reuse code, gat buffer address
	rcall	find_new_victim
	mov	W4, data_irp+4	; save buffer address before we lose it

	mov.d	W2, [W0]	; set block index for this buffer
	push	W2		; save block index for use in CBW
	push	W3

	; CBW and CDB for SCSI READ (10) command:
	;
	;   55 53 42 43 xx xx xx xx
	;   yy yy yy yy 80 00 0A 28
	;   00 zz zz zz zz 00 ww ww
	;   00 00 00 00 00 00 00
	;
	; laid out like this:
	; CBW:
	;   00:  55 53 42 43 is magic number for a CBW
	;   04:  xx xx xx xx is 32-bit "tag" (can be arbitrary?)
	;   08:  yy yy yy yy 32-bit data length expected, little endian
	;   0C:  80          is flags byte indicating data-in from device
	;                       to host
	;   0D:  00          for logical unit 0 (assumed)
	;   0E:  0A          indicates CDB is ten bytes long
	; CDB:
	;   0F:  28          operation code for READ (10)
	;   10:  00          no protection or special caching features
	;   11:  zz zz zz zz 32-bit block index to start at, UNALIGNED
	;                       BIG ENDIAN
	;   15:  00          no "group"
	;   16:  ww ww       16-bit number of blocks to transfer, BIG ENDIAN
	;   18:  00          control field, no "auto contingent allocation"
	; CBW padding:
	;   19:  00 00 00 00 00 00    to make 0x1F [sic] bytes total

	mov	buffer_size, W7		; we will fill the buffer
	mov	drive_block_size, W6	; find drive blocks per buffer

	mov	#0x280A, W6	; code 0x28 is READ (10)
	rcall	set_up_cbw	; set up the CBW

	mov	drive_blocks_per_buffer, W0	; block count to CBW buffer
	swap	W0
	mov	W0, cbw_buffer+0x16

	pop	W0		; write block index into CBW buffer
	mov.b	WREG, cbw_buffer+0x12
	swap	W0
	mov.b	WREG, cbw_buffer+0x11
	pop	W0
	mov.b	WREG, cbw_buffer+0x14
	swap	W0
	mov.b	WREG, cbw_buffer+0x13

	rcall	wait_and_hash	; send it to device

	mov	in_ep_ptr, W4	; get pointers to EP and IRP
	mov	#data_irp, W5
	; pointer to buffer is already in place

	mov	#IRPFM_UOWN|IRPFM_BULK, W1	; do data read
	mov	buffer_size, W2
	rcall	transfer_and_check_csw

	mov	data_irp+4, W4	; recover and return the buffer address

.ifdef SIMULATE_USB_MASS
	rcall	simulate_block_read
.endif

	return

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "USB communication"

wait_and_hash:
.ifndef SIMULATE_USB_MASS
	rcall	USB_WAIT_ON_IRP
.endif
	bra	PRNG_HASH_TIMERS	; tail call

set_up_cbw:
	mov	#cbw_buffer, W3	; get pointers to buffer, EP, and IRP
	mov	out_ep_ptr, W4
	mov	#cbw_irp, W5

	mov	W3, [W5+4]	; point IRP at buffer

	mov	#0x5355, W0	; store magic number in buffer
	mov	W0, [W3++]
	mov	#0x4342, W0
	mov	W0, [W3++]

	rcall	PRNG_READ_WORD	; store a pseudorandom tag 
	mov	W0, [W3++]
	mov	W0, xaction_tag
	rcall	PRNG_READ_WORD
	mov	W0, [W3++]
	mov	W0, xaction_tag+2

	repeat	#11		; zero out the rest of buffer
	clr	[W3++]

	mov	W7, cbw_buffer+0x08	; data length expected
	bset	cbw_buffer+0x0C, #7	; direction flag
	mov	W6, (cbw_buffer+0x0E)	; operation code and CDB length

	mov	#IRPFM_UOWN|IRPFM_BULK|IRPFM_WRITE, W1	; do CBW write
	mov	#31, W2
	return

transfer_and_check_csw:
	rcall	wait_and_hash	; do data transfer

check_csw:
	mov	#IRPFM_UOWN|IRPFM_BULK, W1	; flags for BULK IN
	mov	#13, W2		; 13 bytes to transfer
	mov	#csw_buffer, W3	; buffer address
	mov	in_ep_ptr, W4	; endpoint
	mov	#csw_irp, W5	; IRP

	mov	W3, [W5+4]	; point IRP at buffer

	rcall	wait_and_hash	; do the transfer

	; CSW returned for each SCSI command:
	;
	;   55 53 42 53 xx xx xx xx
	;   yy yy yy yy zz
	;
	; laid out like this:
	;   00:  55 53 42 53 is magic number for a CSW
	;   04:  xx xx xx xx is 32-bit "tag"
	;   08:  yy yy yy yy is missing byte count, little endian
	;   0C:  zz          is result code:  00 success, 01 failure,
	;                       02 phase error

.ifndef SIMULATE_USB_MASS
	mov	#0x5355, W0	; check magic number
	cp	csw_buffer
	bra	neq, THROW
	mov	#0x5342, W0
	cp	csw_buffer+2
	bra	neq, THROW

	mov	xaction_tag, W0	; check tag value
	cp	csw_buffer+4
	bra	neq, THROW
	mov	xaction_tag+2, W0
	cp	csw_buffer+6
	bra	neq, THROW

	cp0	csw_buffer+8	; check for no missing bytes
	bra	nz, THROW
	cp0	csw_buffer+10
	bra	nz, THROW

	cp0.b	csw_buffer+12	; check result code
	bra	nz, THROW
.endif

	return

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "Simulate USB device"

.ifdef SIMULATE_USB_MASS

simulate_block_read:

	; read unaligned big endian block index into W7:W6
	mov.b	cbw_buffer+0x11, WREG
	swap	W0
	mov.b	cbw_buffer+0x12, WREG
	mov	W0, W7
	mov.b	cbw_buffer+0x13, WREG
	swap	W0
	mov.b	cbw_buffer+0x14, WREG
	mov	W0, W6

	; register usage:
	; W0 scratch
	; W1 address of table entry
	; W3:W2 block index from table entry
	; W4 destination buffer
	; W5 data address from table entry
	; W7:W6 block address caller asked for

	mov	#tbloffset(_block_tbl), W1	; start of table

1:
	tblrdl	[W1++], W2	; get table entry
	tblrdl	[W1++], W3
	tblrdl	[W1++], W5

	cp	W2, W6		; check for matching block number
	bra	neq, 2f
	cp	W3, W7
	bra	eq, 1f

2:
	; check for end of table
	mov	#tbloffset(_block_tbl)+6*_NUM_BLOCKS, W0
	cp	W1, W0
	bra	ltu, 1b	; not finished, try next table entry

2:
	bra	2b	; no match, loop forever

1:
	repeat	#(_BUFFER_SIZE/2-1)	; copy data into buffer
	tblrdl	[W5++], [W4++]

	mov	#_BUFFER_SIZE, W0	; return W4 to start of buffer
	sub	W4, W0, W4

	return

.endif

.end
