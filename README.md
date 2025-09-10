# Amiga NO CPU Tester
Tester for NO CPU demo development  
It is modified runner from https://github.com/askeksa/NoCpuChallenge to make testing easier.

There are two options for testing:
- Run copper list directly
- Run copper list file `chip.dat`
  - Build `chip.dat` and run it

Recommended [VSCode](https://code.visualstudio.com/) using extension https://github.com/prb28/vscode-amiga-assembly

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

## Run copper list file `chip.dat`
Run file requires copper data file `chip.dat` or `chip.zx0` in [uae/dh0/](./uae/dh0/)  
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

NOTE: `chip.dat` is Amiga Chip RAM image, loaded at `$0` and executed so needs to be absolute binary image.  
In order to support build of `chip.dat` source should have `org $0` at begging, check [parts/BlankVector.s](./parts/BlankVector.s) example for more information.

### Build `chip.dat` and run it
To support building of `chip.dat` task `amigaassembly: build copper` is added to [.vscode/tasks.json](./.vscode/tasks.json)
```json
// Copper build, run before executable build
{
	"type": "amigaassembly",
	"vasm": {
		"enabled": true,
		"command": "${config:amiga-assembly.binDir}/vasmm68k_mot",
		"args": [
			"-m68000",
			"-Fhunk",
			//"-rangewarnings",
			"-no-typechk"
		],
		"leaveWarnings": true
	},
	"vlink": {
		"enabled": true,
		"command": "${config:amiga-assembly.binDir}/vlink",
		// source to build chip.dat
		"includes": "parts/BlankVector.s",
		"excludes": "",
		"createStartupSequence": false,
		"createExeFileParentDir": false,
		// output name and location of chip.dat
		"exefilename": "../uae/dh0/chip.dat",
		"args": [
			"-Bstatic",
			"-b",
			"rawbin1"
		]
	},
	"problemMatcher": [],
	"label": "amigaassembly: build copper",
	"group": {
		"kind": "build",
		"isDefault": false
	}
}
```
By default `amigaassembly: build copper` task is executed before `amigaassembly: build` because `amigaassembly: build` depends on it.

To disable `chip.dat` build along with `amigaassembly: build` comment or remove:
```json
// Force building copper list first
"dependsOn":["amigaassembly: build copper"]
```
in `amigaassembly: build` task

You can trigger manual build in VSCode `Tasks: Run Task` and select `amigaassembly: build copper`

To configure source for building `chip.dat` modify
```json
"includes": "parts/BlankVector.s",
```
in `amigaassembly: build copper` task.
You can also configure output name if you want something other than `chip.dat` by modifying
```json
// output name and location of chip.dat
"exefilename": "../uae/dh0/chip.dat",
```
When you modify output name, remember to modify file names in [NoCpuTester.s](./NoCpuTester.s) or add another start.


## Project structure
- [Include](./Include/) Amiga System includes
- [parts](./parts/) Place your copper list sources for testing
- [runner](./runner/) No CPU Runner library
- [uae/dh0](./uae/dh0/) Amiga HDD to run in emulator 

## References
- https://github.com/askeksa/NoCpuChallenge
- https://github.com/askeksa/NoCpuDemo
- https://github.com/prb28/vscode-amiga-assembly
- http://amigadev.elowar.com/

