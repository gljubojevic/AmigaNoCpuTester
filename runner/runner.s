; ****************************************
; NO CPU Demo runner library

	incdir	"Include/"
	include "dos/dos.i"
	include	"exec/execbase.i"
	include	"exec/memory.i"
	include	"graphics/gfxbase.i"
	include	"hardware/custom.i"
	include	"hardware/dmabits.i"
	include "LVO3.1/dos_lib.i"
	include "LVO3.1/exec_lib.i"
	include "LVO3.1/graphics_lib.i"
	incdir	""

	IFND	NO_CPU_RUNNER_S
NO_CPU_RUNNER_S	SET	1

; Default chip memory address
	IFND	CHIP_MEMORY_ADDRESS
CHIP_MEMORY_ADDRESS	SET	$000000
	ENDIF

; Default initial copper start address
	IFND	INITIAL_COPPER_ADDRESS
INITIAL_COPPER_ADDRESS	SET	$000000
	ENDIF

; Default demo text buffer size
	IFND	TEXT_BUFFER_SIZE
TEXT_BUFFER_SIZE	SET	3000
	ENDIF


; Run copper list directly
; a0.l	copper list address
RunCopper:
	; setup
	move.l	a0,Copper_Start
	move.l	a0,Copper_Start_Bootstrap
	; Run
	bsr	SysLibsOpen
	lea	$dff000,a3
	bsr	CloseSystem
	; Run the core in supervisor mode
.restart:
	lea	SupervisorCoreCopperOnly(pc),a5
	CALLEXEC	Supervisor
	; Restart on RMB
	; TODO: Restart since copper is possibly trashed
	;move.l	RestartFlag(pc),d0
	;bne.s	.restart
	;bsr	WaitLMBReleased
	bsr	OpenSystem
	bsr	SysLibsClose
	moveq	#0,d0	;Sys return code
	rts


; Load and run copper list file from disk
; a0.l	uncompressed file name
; a1.l	compressed file name
RunFile:
	move.l	a0,DataFileName
	move.l	a1,DataFileNameCompressed
	; setup Copper and Chip defaults
	move.l	#CHIP_MEMORY_ADDRESS,d0
	move.l	d0,ChipMemoryStart
	move.l	#INITIAL_COPPER_ADDRESS,d0
	move.l	d0,Copper_Start
	move.l	d0,Copper_Start_Bootstrap

	bsr	SysLibsOpen
	bsr	PrintDemoText

	bsr	AllocFileMem
	move.l	ReturnCode(pc),d0
	bne.s	.exit

	; Load memory image
	bsr	LoadChipDataFile
	move.l	ReturnCode(pc),d0
	bne.s	.exit

	lea	$dff000,a3
	bsr	CloseSystem

	; If only chip, copy and run bootstrap code
	move.l	OnlyChip(pc),d1
	bne.s	OnlyChipMain

.restart:
	; Run the core in supervisor mode
	lea	SupervisorCore(pc),a5
	CALLEXEC	Supervisor
	; Reload and restart on RMB
	move.l	RestartFlag(pc),d0
	beq.s	.noRestart
	bsr	LoadChipDataFile
	move.l	ReturnCode(pc),d0
	beq.s	.restart

.noRestart:
	bsr	WaitLMBReleased
	bsr	OpenSystem

.exit:	bsr	FreeFileMem
	bsr	SysLibsClose
	; Exit
	move.l	ReturnCode(pc),d0	;Sys return code
	rts


OnlyChipMain:
	; Do Not Disturb
	move.w	#$4000,intena(a3)
	; Copy bootstrap code
	lea	Bootstrap_End(pc),a0
	move.l	ChipMemorySize(pc),a1
	lea	BootstrapSupervisorCore-Bootstrap_End(a1),a5
	moveq	#BOOTSTRAP_SIZE/4-1,d1
.copy:	move.l	-(a0),-(a1)
	dbf	d1,.copy
	; Run bootstrap code
	move.l	$4.w,a6
	cmp.w	#37,LIB_VERSION(a6)
	blt.b	.noFlush
	CALLEXEC	CacheClearU
.noFlush:
	CALLEXEC	Supervisor
	; No return to here


AllocFileMem:
	; Get chip memory size
	move.l	$4.w,a6
	move.l	MaxLocMem(a6),ChipMemorySize
	; Detect only-chip memory available
	moveq	#0,d0
	cmp.l	#RunFile,ChipMemorySize
	sgt.b	d0
	neg.b	d0
	move.l	d0,OnlyChip
	; Allocate largest available chip memory chunk
	CALLEXEC	Forbid
	lea	MemList(a6),a0
	moveq	#0,d0
.findChip:
	move.l	(a0),a0
	btst.b	#MEMB_CHIP,MH_ATTRIBUTES+1(a0)
	beq.s	.findChip
	lea	MH_FIRST(a0),a0
.findLargest:
	move.l	(a0),a0
	cmp.l	MC_BYTES(a0),d0
	bgt.s	.notLargest
	move.l	a0,a1
	move.l	MC_BYTES(a0),d0
.notLargest:
	tst.l	(a0)
	bne.s	.findLargest

	move.l	OnlyChip(pc),d1
	beq.s	.full
	sub.l	#BOOTSTRAP_SIZE,d0
.full:	move.l	d0,ChipBufferSize
	CALLEXEC	AllocAbs
	move.l	d0,ChipBuffer
	CALLEXEC	Permit

	; Check that chip buffer is at least as big as low memory
	move.l	ChipBufferSize(pc),d0
	cmp.l	ChipBuffer(pc),d0
	blt.s	.errExit
	; Allocate extra buffer for saving used chip memory
	move.l	OnlyChip(pc),d1
	bne.s	.skip
	move.l	ChipMemorySize(pc),d0
	sub.l	ChipBufferSize(pc),d0
	move.l	d0,ExtraBufferSize
	moveq	#0,d1
	CALLEXEC	AllocMem
	move.l	d0,ExtraBuffer
	beq.s	.errExit
.skip:	rts
.errExit:
	move.l	#-1,ReturnCode
	rts


FreeFileMem:
	; Free extra buffer
	move.l	ExtraBuffer(pc),d0
	beq.s	.noBuffer
	move.l	d0,a1
	move.l	ExtraBufferSize(pc),d0
	CALLEXEC FreeMem
.noBuffer:
	; Free chip
	move.l	ChipBuffer(pc),d0
	beq.b	.noChip
	move.l	d0,a1
	move.l	ChipBufferSize(pc),d0
	CALLEXEC FreeMem
.noChip:
	rts


SysLibsOpen:
	lea	DosName(pc),a1
	CALLEXEC	OldOpenLibrary
	move.l	d0,_DOSBase
	lea	GfxName(pc),a1
	CALLEXEC	OldOpenLibrary
	move.l	d0,_GfxBase
	rts


SysLibsClose:
	move.l	_GfxBase(pc),a1
	CALLEXEC	CloseLibrary
	move.l	_DOSBase(pc),a1
	CALLEXEC	CloseLibrary
	rts

DosName:
	DOSNAME
GfxName:
	GRAFNAME
	even
_DOSBase:
	dc.l	0
_GfxBase:
	dc.l	0


PrintDemoText:
	; Get output
	CALLDOS	Output
	move.l	d0,d5
	beq.s	.no_txt
	; Open file
	move.l	#DemoTextFileName,d1
	move.l	#MODE_OLDFILE,d2
	CALLDOS	Open
	move.l	d0,d4
	beq.s	.no_txt
	; Allocate buffer on stack
	lea	-TEXT_BUFFER_SIZE(sp),sp
	; Read text
.print:	move.l	d4,d1
	move.l	sp,d2
	move.l	#TEXT_BUFFER_SIZE,d3
	CALLDOS	Read
	move.l	d0,d3
	ble.s	.done
	; Print text
	move.l	d5,d1
	move.l	sp,d2
	CALLDOS	Write
	cmp.l	#TEXT_BUFFER_SIZE,d3
	beq.s	.print
	; Deallocate buffer
.done:	lea	TEXT_BUFFER_SIZE(sp),sp
	; Close file
	move.l	d4,d1
	CALLDOS	Close
.no_txt:
	rts

DemoTextFileName:
	dc.b	"demo.txt",0
	EVEN


LoadChipDataFile:
	; Open chip ram data file
	moveq	#0,d5
	move.l	DataFileName(pc),d1
	move.l	#MODE_OLDFILE,d2
	CALLDOS	Open
	move.l	d0,d4
	bne.b	.openOk
	; Try compressed
	moveq	#1,d5
	move.l	DataFileNameCompressed(pc),d1
	move.l	#MODE_OLDFILE,d2
	CALLDOS	Open
	move.l	d0,d4
	bne.b	.openOk
	; Open failed - set return code
	CALLDOS	IoErr
	move.l	d0,ReturnCode
	rts
.openOk:
	move.l	d5,Compressed
	; Read low memory contents
	move.l	d4,d1
	move.l	ChipBufferSize(pc),d2
	move.l	ChipBuffer(pc),d3
	CALLDOS	Read
	move.l	d0,ChipDataSize
	; Read mid memory contents
	move.l	d4,d1
	move.l	ChipBuffer(pc),d2
	move.l	ChipBufferSize(pc),d3
	sub.l	ChipBuffer(pc),d3
	CALLDOS	Read
	add.l	d0,ChipDataSize
	; Stop here if only chip
	move.l	OnlyChip(pc),d1
	beq.b	.extra
	cmp.l	d3,d0
	blt.b	.close
	move.l	#ERROR_NO_FREE_STORE,ReturnCode
	bra.b	.close
	; Read high memory contents
.extra:	move.l	d4,d1
	move.l	ExtraBuffer(pc),d2
	move.l	ExtraBufferSize(pc),d3
	CALLDOS	Read
	add.l	d0,ChipDataSize
	; Close file
.close:	move.l	d4,d1
	CALLDOS	Close
	rts

DataFileName:
	dc.l	0
DataFileNameCompressed:
	dc.l	0


CloseSystem:
	; Reserve blitter
	CALLGRAF	OwnBlitter
	CALLGRAF	WaitBlit
	CALLGRAF	WaitBlit
	; Reset view
	move.l	_GfxBase(pc),a6
	move.l	gb_ActiView(a6),SystemView
	suba.l	a1,a1
	CALLGRAF	LoadView
	CALLGRAF	WaitTOF
	CALLGRAF	WaitTOF
	; Disable DMA
	move.w	dmaconr(a3),SystemDMA
	move.w	#$01bf,dmacon(a3)
	rts

SystemView:
	dc.l	0
SystemDMA:
	dc.w	0

OpenSystem:
	; Restore system copper list
	move.l	_GfxBase(pc),a6
	move.l	gb_copinit(a6),cop1lc(a3)
	; Wait for vblank before enabling DMA to prevent copper from
	; executing (now nonexistent) instructions from where it left off.
	bsr	WaitVbl
	; Enable DMA
	move.w	SystemDMA(pc),d0
	or.w	#DMAF_SETCLR,d0
	move.w	d0,dmacon(a3)
	;move.w	#$83e0,dmacon(a3)
	; Restore system view
	move.l	SystemView(pc),a1
	CALLGRAF	LoadView
	CALLGRAF	WaitTOF
	CALLGRAF	WaitTOF
	; Release blitter
	CALLGRAF	WaitBlit
	CALLGRAF	WaitBlit
	CALLGRAF	DisownBlitter
	rts


SupervisorCore:
	; Set interrupt level to 7 to prevent the demo from hijacking the CPU.
	or.w	#$0700,sr
	; Switch stack, in case the supervisor stack is in chip memory.
	move.l	a7,a6
	lea	Stack(pc),a7
	; run demo
	bsr	SetInitialState
	bsr	SwapChipMemoryIn
	bsr	StartDemo
	bsr	WaitForExitSignal
	bsr	WaitVbl
	bsr	StopDemo
	bsr	SetInitialState
	bsr	WaitBlit
	bsr	SwapChipMemoryOut
	; Restore stack and return
	move.l	a6,a7
	rte


SupervisorCoreCopperOnly:
	; Set interrupt level to 7 to prevent the demo from hijacking the CPU.
	or.w	#$0700,sr
	; Switch stack, in case the supervisor stack is in chip memory.
	move.l	a7,a6
	lea	Stack(pc),a7
	; run demo
	bsr	SetInitialState
	bsr	StartDemo
	bsr	WaitForExitSignal
	bsr	WaitVbl
	bsr	StopDemo
	bsr	SetInitialState
	bsr	WaitBlit
	; Restore stack and return
	move.l	a6,a7
	rte


SetInitialState:
	; Turn off audio filter and modulations
	bset.b	#1,$bfe001
	move.w	#$000f,adkcon(a3)
	; PAL mode, long frames
	move.w	#$0020,beamcon0(a3)
	move.w	#$8000,vposw(a3)
	; Set OCS defaults
	move.w	#$0200,bplcon0(a3)
	move.w	#$0000,bplcon1(a3)
	move.w	#$0024,bplcon2(a3)
	move.w	#$0c00,bplcon3(a3)
	move.w	#$0011,bplcon4(a3)
	move.w	#$0000,fmode(a3)
	; Black background
	move.w	#$000,color+0*2(a3)
	rts


StartDemo:
	; Set initial copper start address
	move.l	Copper_Start(pc),cop1lc(a3)
	; Set copper danger flag
	move.w	#$0002,copcon(a3)
	; Wait for vblank before enabling DMA to prevent copper from
	; executing (now nonexistent) instructions from where it left off.
	bsr	WaitVbl
	; Enable bitplane, copper and blitter DMA. Set Blitter Nasty to
	; prevent the CPU from interfering with the demo.
	move.w	#$87c0,dmacon(a3)
	rts

Copper_Start:
	dc.l	0

StopDemo:
	; Disable all DMA except blitter
	move.w	#$05bf,dmacon(a3)
	move.w	#$8240,dmacon(a3)
	; Restore system default interrupt enable mask
	move.w	#$1fd3,intena(a3)
	move.w	#$e02c,intena(a3)
	; Clear copper danger flag
	move.w	#$0000,copcon(a3)
	rts


SwapChipMemoryIn:
	move.l	ChipBufferSize(pc),a0
	move.l	ChipMemoryStart(pc),a1
	move.l	ChipBuffer(pc),d1
	bsr	BlitSwap

	move.l	ExtraBuffer(pc),a0
	move.l	ChipBufferSize(pc),a1
	move.l	ExtraBufferSize(pc),d1
	bsr	SwapMemory

	move.l	ChipMemorySize(pc),a0
	bsr	Decompress

	move.l	ChipDataSize(pc),a1
	move.l	ChipMemorySize(pc),d1
	sub.l	a1,d1
	bsr	BlitClear
	rts


SwapChipMemoryOut:
	move.l	ExtraBuffer(pc),a0
	move.l	ChipBufferSize(pc),a1
	move.l	ExtraBufferSize(pc),d1
	bsr	CopyMemory

	move.l	ChipBufferSize(pc),a0
	move.l	ChipMemoryStart(pc),a1
	move.l	ChipBuffer(pc),d1
	bsr	BlitCopy
	rts

ChipMemoryStart:
	dc.l	0

CopyMemory:
	; A0 = Source
	; A1 = Dest
	; D1 = Size
	bra.s	.in
.loop:	move.l	(a0)+,(a1)+
.in:	subq.l	#4,d1
	bge.s	.loop
	rts


SwapMemory:
	; A0 = Source
	; A1 = Dest
	; D1 = Size
	bra.s	.in
.loop:	move.l	(a0),d0
	move.l	(a1),(a0)+
	move.l	d0,(a1)+
.in:	subq.l	#4,d1
	bge.s	.loop
	rts


WaitForExitSignal:
	moveq	#0,d0
	; Exit on LMB
.wait:	btst.b	#6,$bfe001
	beq.s	.exit
	; Exit if Blitter Nasty is cleared.
	btst.b	#10-8,dmaconr(a3)
	beq.s	.exit
	; Restart on RMB
	btst.b	#10-8,potinp(a3)
	bne.s	.wait
	moveq	#1,d0
.exit:	move.l	d0,RestartFlag
	rts

WaitLMBReleased:
.wait:	btst.b	#6,$bfe001
	beq.b	.wait
	rts


Bootstrap_Begin:

BootstrapSupervisorCore:
	; Set interrupt level to 7 to prevent the demo from hijacking the CPU.
	or.w	#$0700,sr
	; Switch stack
	lea	Stack(pc),a7

	jsr	SetInitialState

	; Copy low memory data
	move.l	ChipBufferSize(pc),a0
	move.l	#CHIP_MEMORY_ADDRESS,a1
	move.l	ChipBuffer(pc),d1
	bsr.s	BlitCopy
	; Decompress if compressed
	move.l	ChipMemorySize(pc),a0
	lea	-BOOTSTRAP_SIZE(a0),a0
	bsr	Decompress
	; Clear until bootstrap code
	move.l	ChipDataSize(pc),a1
	move.l	ChipMemorySize(pc),d1
	sub.l	#BOOTSTRAP_SIZE,d1
	sub.l	a1,d1
	bsr.s	BlitClear
	; Set dummy copper start address and wait for copper to latch it
	lea	DummyCopper(pc),a0
	move.l	a0,cop1lc(a3)
	bsr	WaitVbl
	; Enable DMAs.
	move.w	#$87c0,dmacon(a3)
	; Set copper danger flag
	move.w	#$0002,copcon(a3)
	; Clear bootstrap code
	move.w	#(BOOTSTRAP_SIZE<<(6-3))+4,bltsize(a3)
	; Set initial copper start address
	move.l	Copper_Start_Bootstrap(pc),cop1lc(a3)
	; Stop
	stop	#$2700

Copper_Start_Bootstrap:
	dc.l	0


BlitClear:
	; A1 = Destination
	; D1 = Size in bytes (must be even)
	move.w	#$0100,d0
	bra.s	Blit

BlitCopy:
	; A0 = Source
	; A1 = Destination
	; D1 = Size in bytes (must be even)
	move.w	#$09f0,d0
	bra.s	Blit

BlitSwap:
	; A0 = Source
	; A1 = Destination
	; D1 = Size in bytes (must be even)
	move.w	#$0b5a,d0
	bsr.s	Blit
	exg.l	a0,a1
	bsr.s	Blit
	exg.l	a0,a1
Blit:
	; A0 = Source
	; A1 = Destination
	; D1 = Size in bytes (must be even)
	; D0 = BLTCON0
	bsr.s	WaitBlit
	move.w	d0,bltcon0(a3)
	move.w	#$0000,bltcon1(a3)
	move.l	#$ffffffff,bltafwm(a3)
	move.l	a1,bltcpt(a3)
	move.l	a0,bltapt(a3)
	move.l	a1,bltdpt(a3)
	move.w	#0,bltcmod(a3)
	move.w	#0,bltamod(a3)
	move.w	#0,bltdmod(a3)

	move.l	d1,d2
	asr.l	#1,d2
	bra.s	.bigIn
.big:	move.w	#0,bltsize(a3)
	bsr	WaitBlit
.bigIn:	sub.l	#$10000,d2
	bge.s	.big
	moveq	#-64,d3
	and.w	d2,d3
	beq.s	.no1
	move.w	d3,bltsize(a3)
	bsr	WaitBlit
.no1:	sub.w	d3,d2
	beq.s	.no2
	or.w	#64,d2
	move.w	d2,bltsize(a3)
	bsr	WaitBlit
.no2:	rts


WaitVbl:
	btst.b	#0,vposr+1(a3)
	beq.s	WaitVbl
.wait:	btst.b	#0,vposr+1(a3)
	bne.s	.wait
	rts


WaitBlit:
	btst.b	#14-8,dmaconr(a3)
	bne.s	WaitBlit
	rts


Decompress:
	; A0 = End of space
	move.l	Compressed(pc),d0
	beq.s	.not
	; move compressed to end of chip ram
	move.l	ChipDataSize(pc),d0
	addq.l	#3,d0
	and.w	#-4,d0
	move.l	d0,a1
.move:	move.l	-(a1),-(a0)
	move.l	a1,d0
	bne.s	.move
	; decompress
	bsr	zx0_decompress
	lea	ChipDataSize(pc),a0
	move.l	a1,(a0)
.not:	rts

	include	"runner/unzx0_68000.s"

DummyCopper:
	dc.w	$ffff,$fffe
	dc.w	$ffff,$fffe

ChipMemorySize:
	dc.l	0
ChipBuffer:
	dc.l	0
ChipBufferSize:
	dc.l	0
ChipDataSize:
	dc.l	0
Compressed:
	dc.l	0

	ds.l	5
Stack:

Bootstrap_End:

BOOTSTRAP_SIZE	=	(Bootstrap_End-Bootstrap_Begin+7)&-8


ReturnCode:
	dc.l	0
RestartFlag:
	dc.l	0
OnlyChip:
	dc.l	0
ExtraBuffer:
	dc.l	0
ExtraBufferSize:
	dc.l	0

	ENDC  !NO_CPU_RUNNER_S
