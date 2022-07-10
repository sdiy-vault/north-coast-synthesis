; Contents of simulated mass storage device
; $Id: simdrive.inc 9818 2022-02-06 04:37:51Z mskala $
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

; This is split into six sections for different sample filesystem contents
; to test different cases in the reading code.  Each should define the
; following symbols:

;   _DRIVE_CAPACITY - capacity to be reported by simulated SCSI READ
;   CAPACITY (10).  Note this is properly the zero-based index of the last
;   block, hence one less than the number of blocks

;   _BLOCK_SIZE - block size reported by simulated SCSI READ CAPACITY (10)

;   _BUFFER_SIZE - buffer size to be filled when reading simulated drive;
;   should be whatever our driver will calculate, normally max of drive
;   block size and FAT block ("logical sector") size described in the FAT
;   superblock

.pushsection *, code

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.if SIMULATE_USB_MASS==1

; Simulation option 1:  32G USB stick, FAT32 in a partition, 512-byte blocks
; for both, 16K cluster size, somewhat weird FAT32 because formatted by
; Windows 10 upgrade, target file pretty deep into partition so that high
; word of FAT32 entry gets tested.

.equ _DRIVE_CAPACITY, 0x039CFFFF
.equ _BLOCK_SIZE, 0x200
.equ _BUFFER_SIZE, 0x200

_block_tbl:
	; partition table
	.long 0
	.word tbloffset(_block_0)

	; FAT32 superblock
	.long 0x20
	.word tbloffset(_block_0)+0x200

	; relevant block in the FAT per se
	.long 0x105C
	.word tbloffset(_block_0)+0x400

	; root directory
	.long 0x8020
	.word tbloffset(_block_0)+0x600

	; 64 blocks for file data, mapped to repeat over the 8K we actually
	; have
.equ _i, 0
.rept 64
	.long 0x3D6500+_i
	.word tbloffset(_file_data)+0x200*(_i&15)
  .equ _i, _i+1
.endr

_block_tbl_end:

; Original source of this test data is a drive image of a 32G drive that was
; formatted by Windows 10 during a failed upgrade attempt.  As a result it's
; formatted a bit oddly, with a big gap at the start of the filesystem where
; apparently the upgrade process included boot recovery code or something. 
; Not everything is in the location where a FAT32 filesystem would normally
; expect it to be; we have to really read the data structures to find things
; properly, not just assume standard layout.  The file we're interested in
; is FIRMWARE.FRM, which is positioned in two consecutive clusters deep
; enough into the filesystem that its index doesn't fit in 16 bits -
; important because we used this test data to debug a problem with correct
; handling of nonzero high words in cluster indices.

; _block_0:
;	.incbin "/mnt/assets/current/key.img", 0, 0x200
; _block_20:
;	.incbin "/mnt/assets/current/key.img", 0x20*0x200, 0x200
; _block_105C:
;	.incbin "/mnt/assets/current/key.img", 0x105C*0x200, 0x200
; _block_8020:
;	.incbin "/mnt/assets/current/key.img", 0x8020*0x200, 0x200
; _block_3D6500:
;	.incbin "/mnt/assets/current/key.img", 0x3D6500*0x200, 0x200*40

; selected blocks from the drive image - should be exactly the ones that
; the FAT32 driver tries to look at - have been manually prepared in
; fat32a.bin, reproducing the layout above, to avoid both the size and
; privacy exposure of sharing the entire 32G image.

_block_0:
	.incbin "fat32a.bin"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.elseif SIMULATE_USB_MASS==2

; Simulation option 2:  80M drive, FAT32, 512-byte blocks for drive and
; filesystem, 1 block per cluster, target file fragmented all over the drive

.equ _DRIVE_CAPACITY, 0x27FFF
.equ _BLOCK_SIZE, 0x200
.equ _BUFFER_SIZE, 0x200

_block_tbl:
	; FAT32 superblock
	.long 0x0
	.word tbloffset(_block_0)

	; root directory
	.long 0x09FA
	.word tbloffset(_block_9fa)

	; blocks in the FAT per se
	.long 0x6C
	.word tbloffset(_block_6c)
	.long 0xC5
	.word tbloffset(_block_c5)
	.long 0x11E
	.word tbloffset(_block_11e)
	.long 0x177
	.word tbloffset(_block_177)
	.long 0x1D0
	.word tbloffset(_block_1d0)
	.long 0x229
	.word tbloffset(_block_229)
	.long 0x282
	.word tbloffset(_block_282)
	.long 0x2DB
	.word tbloffset(_block_2db)
	.long 0x334
	.word tbloffset(_block_334)
	.long 0x38d
	.word tbloffset(_block_38d)
	.long 0x3e6
	.word tbloffset(_block_3e6)
	.long 0x440
	.word tbloffset(_block_440)
	.long 0x499
	.word tbloffset(_block_499)
	.long 0x4F2
	.word tbloffset(_block_4f2)

	; file data blocks
	.long 0x300B
	.word tbloffset(_file_data)
	.long 0x300C
	.word tbloffset(_file_data)+0x200
	.long 0x5C95
	.word tbloffset(_file_data)+0x400
	.long 0x5C96
	.word tbloffset(_file_data)+0x600
	.long 0x891F
	.word tbloffset(_file_data)+0x800
	.long 0x8920
	.word tbloffset(_file_data)+0xA00
	.long 0xB5A9
	.word tbloffset(_file_data)+0xC00
	.long 0xB5AA
	.word tbloffset(_file_data)+0xE00
	.long 0xE233
	.word tbloffset(_file_data)+0x1000
	.long 0xE234
	.word tbloffset(_file_data)+0x1200
	.long 0x10EBD
	.word tbloffset(_file_data)+0x1400
	.long 0x10EBE
	.word tbloffset(_file_data)+0x1600
	.long 0x13B47
	.word tbloffset(_file_data)+0x1800
	.long 0x13B48
	.word tbloffset(_file_data)+0x1A00
	.long 0x167D2
	.word tbloffset(_file_data)+0x1C00
	.long 0x167D3
	.word tbloffset(_file_data)+0x1E00
	.long 0x1945C
	.word tbloffset(_file_data)
	.long 0x1945D
	.word tbloffset(_file_data)+0x200
	.long 0x1C0E6
	.word tbloffset(_file_data)+0x400
	.long 0x1C0E7
	.word tbloffset(_file_data)+0x600
	.long 0x1ED70
	.word tbloffset(_file_data)+0x800
	.long 0x1ED71
	.word tbloffset(_file_data)+0xA00
	.long 0x219FA
	.word tbloffset(_file_data)+0xC00
	.long 0x219FB
	.word tbloffset(_file_data)+0xE00
	.long 0x24684
	.word tbloffset(_file_data)+0x1000
	.long 0x24685
	.word tbloffset(_file_data)+0x1200
	.long 0x2730E
	.word tbloffset(_file_data)+0x1400
	.long 0x2730F
	.word tbloffset(_file_data)+0x1600

_block_tbl_end:

_block_0:
	.incbin "fat32b.bin",0,0x200
_block_6c:
	.incbin "fat32b.bin",0x200*0x6C,0x200
_block_c5:
	.incbin "fat32b.bin",0x200*0xC5,0x200
_block_11e:
	.incbin "fat32b.bin",0x200*0x11E,0x200
_block_177:
	.incbin "fat32b.bin",0x200*0x177,0x200
_block_1d0:
	.incbin "fat32b.bin",0x200*0x1D0,0x200
_block_229:
	.incbin "fat32b.bin",0x200*0x229,0x200
_block_282:
	.incbin "fat32b.bin",0x200*0x282,0x200
_block_2db:
	.incbin "fat32b.bin",0x200*0x2db,0x200
_block_334:
	.incbin "fat32b.bin",0x200*0x334,0x200
_block_38d:
	.incbin "fat32b.bin",0x200*0x38d,0x200
_block_3e6:
	.incbin "fat32b.bin",0x200*0x3e6,0x200
_block_440:
	.incbin "fat32b.bin",0x200*0x440,0x200
_block_499:
	.incbin "fat32b.bin",0x200*0x499,0x200
_block_4f2:
	.incbin "fat32b.bin",0x200*0x4F2,0x200
_block_9fa:
	.incbin "fat32b.bin",0x200*0x09FA,0x200

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.elseif SIMULATE_USB_MASS==3

; Simulation option 3:  20M drive, FAT16, 512-byte blocks for drive and
; filesystem, 2 blocks per cluster

.equ _DRIVE_CAPACITY, 0x9FFF
.equ _BLOCK_SIZE, 0x200
.equ _BUFFER_SIZE, 0x200

_block_tbl:
	; FAT16 superblock
	.long 0x0
	.word tbloffset(_block_0)

	; relevant block in the FAT per se
	.long 0x2
	.word tbloffset(_block_2)

	; root directory
	.long 0xA2
	.word tbloffset(_block_a2)

	; 64 blocks for file data, mapped to repeat over the 8K we actually
	; have
.equ _i, 0
.rept 64
	.long 0xC4+_i
	.word tbloffset(_file_data)+0x200*(_i&15)
  .equ _i, _i+1
.endr

_block_tbl_end:

_block_0:
	.incbin "fat16a.bin",0,0x200
_block_2:
	.incbin "fat16a.bin",0x2*0x200,0x200
_block_a2:
	.incbin "fat16a.bin",0x200*0xA2,0x200

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.elseif SIMULATE_USB_MASS==4

; Simulation option 4:  80M drive, FAT16, 512-byte blocks for drive, 2048
; bytes for filesystem, 4 blocks per cluster

.equ _DRIVE_CAPACITY, 0x27FFF
.equ _BLOCK_SIZE, 0x200
.equ _BUFFER_SIZE, 0x800

_block_tbl:
	; FAT16 superblock
	.long 0x0
	.word tbloffset(_block_0)

	; relevant block in the FAT per se
	.long 0x10
	.word tbloffset(_block_10)

	; root directory
	.long 0x70
	.word tbloffset(_block_70)

	; 64 blocks for file data, mapped to repeat over the 8K we actually
	; have
.equ _i, 0
.rept 64
	.long 0xA0+_i
	.word tbloffset(_file_data)+0x200*(_i&15)
  .equ _i, _i+1
.endr

_block_tbl_end:

_block_0:
	.incbin "fat16b.bin",0,0x200
_block_10:
	.incbin "fat16b.bin",0x10*0x200,0x800
_block_70:
	.incbin "fat16b.bin",0x70*0x200,0x800

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.elseif SIMULATE_USB_MASS==5

; Simulation option 5:  FAT12, 360K, simulating a floppy, 512-byte blocks
; for drive and filesystem, 2 blocks per cluster

.equ _DRIVE_CAPACITY, 0x2CF
.equ _BLOCK_SIZE, 0x200
.equ _BUFFER_SIZE, 0x200

_block_tbl:
	; FAT12 superblock
	.long 0x0
	.word tbloffset(_block_0)

	; relevant block in the FAT per se
	.long 0x1
	.word tbloffset(_block_1)

	; root directory
	.long 0x05
	.word tbloffset(_block_5)

	; 64 blocks for file data, mapped to repeat over the 8K we actually
	; have
.equ _i, 0
.rept 64
	.long 0x0E+_i
	.word tbloffset(_file_data)+0x200*(_i&15)
  .equ _i, _i+1
.endr

_block_tbl_end:

_block_0:
	.incbin "fat12a.bin",0,0x200
_block_1:
	.incbin "fat12a.bin",1*0x200,0x200
_block_5:
	.incbin "fat12a.bin",5*0x200,0x200

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.elseif SIMULATE_USB_MASS==6

; Simulation option 6:  FAT12, 1440K, 1024-byte blocks for filesystem,
; 2048-byte blocks for drive, one block per cluster

.equ _DRIVE_CAPACITY, 0x2CF
.equ _BLOCK_SIZE, 0x800
.equ _BUFFER_SIZE, 0x800

_block_tbl:
	; FAT12 superblock
	.long 0x0
	.word tbloffset(_block_0)

	; first block of FAT per se in second half of drive block 0 above

	; root directory
	.long 0x03
	.word tbloffset(_block_3)

	; 16 blocks for file data, mapped to repeat over the 8K we actually
	; have
.equ _i, 0
.rept 16
	.long 0x07+_i
	.word tbloffset(_file_data)-0x400+0x800*(_i&3)
  .equ _i, _i+1
.endr

_block_tbl_end:

_block_0:
	.incbin "fat12b.bin",0,0x800
_block_3:
	.incbin "fat12b.bin",3*0x800,0x800

.endif

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.equ _NUM_BLOCKS, (_block_tbl_end-_block_tbl)/6

; Look at previous firmware image to get plausible data for demo purposes. 
; We only really use the first 8K of the file, so as not to overflow memory. 
; There would already be a problem with the image trying to include an
; entire copy of itself, but we also have to deal with the fact it expands
; 50% by being stored "unpacked" with one 16-bit word in each 24-bit word of
; program memory, and also the linker may have trouble finding a large
; contiguous block for the image given the calibration page as an obstacle
; at some random address in the middle of program memory even if the byte
; count would suggest it should fit.  Only keeping 8K means the simulated
; drive image will not really contain a valid firmware image suitable for
; flashing, but we can't flash in the software debugger anyway because no
; SRAM chip, and we should still have enough of an image to run in the
; hardware debugger and get past at least one CRC check even if not all the
; way to flashing.

_file_data:
	.incbin "simdrive.bin",0,8192
.popsection
