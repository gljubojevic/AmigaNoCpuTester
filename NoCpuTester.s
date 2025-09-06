	section	"NoCPUTester",CODE_P

;Flag to select run file or direct copper
RUN_FORM_FILE	=	0

NoCPUTester:
	IF	RUN_FORM_FILE=1
	; Run file from disk, default filenames
	lea	ChipDataFileName(pc),a0
	lea	ChipDataFileNameCompressed(pc),a1
	bsr	RunFile
	ELSE
	; Run copper list directly
	movem.l	d0-a6,-(sp)
	lea	CopperDefault,a0
	bsr	RunCopper
	movem.l	(sp)+,d0-a6
	ENDIF
	rts

; Default filenames for NO Cpu Runner
ChipDataFileName:
	dc.b	"chip.dat",0
ChipDataFileNameCompressed:
	dc.b	"chip.zx0",0
	even

; ****************************************
; Override Runner defaults, valid only when
; running file
;CHIP_MEMORY_ADDRESS	SET	$000000
;INITIAL_COPPER_ADDRESS	SET	$000000
; ****************************************
; NO CPU Runner lib
	include	"runner/runner.s"

; ****************************************
; Chip data area for direct testing copper lists
	section	"Chip data",DATA_C
;Include copper list for testing
	include	"parts/CopperDefault.s"