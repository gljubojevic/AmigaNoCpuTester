# Amiga NO CPU Tester
Tester for NO CPU demo development  
It is modified runner from https://github.com/askeksa/NoCpuChallenge to make testing easier.

There are two options for testing:
- Run copper list directly
- Run copper list file

Recommended [VSCode](https://code.visualstudio.com/) with extension https://github.com/prb28/vscode-amiga-assembly

## Run copper list directly
Place copper list source in [parts/](./parts/) folder, example copper source list [parts/CopperDefault.s](./parts/CopperDefault.s)  
In [NoCpuTester.s](./NoCpuTester.s) enable direct running copper list by setting
```asm
;Flag to select run file or direct copper
RUN_FORM_FILE	=	0
```
Add include for copper list source in [NoCpuTester.s](./NoCpuTester.s) under `DATA_C` section
```asm
; ****************************************
; Chip data area for direct testing copper lists
	section	"Chip data",DATA_C
;Include copper list for testing
	include	"parts/CopperDefault.s"
```
Setup start in [NoCpuTester.s](./NoCpuTester.s) like this
```asm
	; Run copper list directly
	movem.l	d0-a6,-(sp)
	lea	CopperDefault,a0
	bsr	RunCopper
	movem.l	(sp)+,d0-a6
```

## Run copper list file
Run file requires copper data file in [uae/dh0/](./uae/dh0/)
In [NoCpuTester.s](./NoCpuTester.s) enable file runner by setting
```asm
;Flag to select run file or direct copper
RUN_FORM_FILE	=	1
```
Optionally define file names so you can keep more than one test
```asm
; Default filenames for NO Cpu Runner
ChipDataFileName:
	dc.b	"chip.dat",0
ChipDataFileNameCompressed:
	dc.b	"chip.zx0",0
	even
```
Setup start in [NoCpuTester.s](./NoCpuTester.s) like this
```asm
; Run file from disk, default filenames
lea	ChipDataFileName(pc),a0
lea	ChipDataFileNameCompressed(pc),a1
bsr	RunFile
```

## Project structure
- [Include](./Include/) Amiga System incudes
- [parts](./parts/) Place your copper list sources for testing
- [runner](./runner/) No CPU Runner library
- [uae/dh0](./uae/dh0/) Amiga HDD to run in emulator 

## References
- https://github.com/askeksa/NoCpuChallenge
- https://github.com/askeksa/NoCpuDemo
- https://github.com/prb28/vscode-amiga-assembly

