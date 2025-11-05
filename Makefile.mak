# UXN - Top-level Makefile for Windows (Microsoft Visual C++)
# Use with VS Code Microsoft C/C++ extension

# Compiler and flags
CC = cl
CFLAGS = /nologo /O2 /W3
SRCDIR = src
BINDIR = bin
BUILDDIR = build

# vcpkg integration
VCPKG_ROOT = vcpkg
VCPKG_INSTALLED = $(VCPKG_ROOT)\packages\sdl2_x64-windows

# Device sources (excluding POSIX-only file.c)
DEVICES = $(SRCDIR)\devices\audio.c $(SRCDIR)\devices\controller.c $(SRCDIR)\devices\datetime.c $(SRCDIR)\devices\mouse.c $(SRCDIR)\devices\screen.c $(SRCDIR)\devices\system.c $(SRCDIR)\devices\console.c

# CLI-specific stubs for Windows
CLI_STUBS = $(SRCDIR)\cli_stubs.c $(SRCDIR)\devices\file_win.c

# SDL2 paths when available
!IF EXIST("$(VCPKG_INSTALLED)\include\SDL2\SDL.h")
SDL2_INCLUDE = /I"$(VCPKG_INSTALLED)\include" /I"$(VCPKG_INSTALLED)\include\SDL2"
SDL2_LIB = /LIBPATH:"$(VCPKG_INSTALLED)\lib" /LIBPATH:"$(VCPKG_INSTALLED)\lib\manual-link" SDL2.lib SDL2main.lib shell32.lib
CFLAGS_EMU = $(CFLAGS) $(SDL2_INCLUDE)
DEVICES_EMU = $(DEVICES) $(SRCDIR)\devices\file_win.c
!ELSE
CFLAGS_EMU = $(CFLAGS)
DEVICES_EMU = 
!ENDIF

# Targets
all: $(BINDIR) $(BUILDDIR) $(BINDIR)\uxnasm.exe $(BINDIR)\uxncli.exe $(BINDIR)\uxnemu.exe

# Create directories
$(BINDIR):
	@if not exist "$(BINDIR)" mkdir $(BINDIR)

$(BUILDDIR):
	@if not exist "$(BUILDDIR)" mkdir $(BUILDDIR)

# UXN Assembler (no dependencies)
$(BINDIR)\uxnasm.exe: $(SRCDIR)\uxnasm.c $(SRCDIR)\uxn.h
	$(CC) $(CFLAGS) $(SRCDIR)\uxnasm.c /Fe$@

# UXN CLI Emulator (with stubs for Windows compatibility)
$(BINDIR)\uxncli.exe: $(SRCDIR)\uxn.c $(SRCDIR)\uxncli.c $(SRCDIR)\uxn.h $(DEVICES) $(CLI_STUBS)
	$(CC) $(CFLAGS) $(SRCDIR)\uxn.c $(SRCDIR)\uxncli.c $(DEVICES) $(CLI_STUBS) /Fe$@

# UXN GUI Emulator (requires SDL2)
$(BINDIR)\uxnemu.exe: $(SRCDIR)\uxn.c $(SRCDIR)\uxnemu.c $(SRCDIR)\uxn.h $(DEVICES_EMU)
!IF EXIST("$(VCPKG_INSTALLED)\include\SDL2\SDL.h")
	$(CC) $(CFLAGS_EMU) $(SRCDIR)\uxn.c $(SRCDIR)\uxnemu.c $(DEVICES_EMU) /Fe$@ /link $(SDL2_LIB) /SUBSYSTEM:CONSOLE
!ELSE
	@echo SDL2 not found. Run 'nmake setup' to install dependencies.
	@echo Building stub version without SDL2...
	$(CC) $(CFLAGS) $(SRCDIR)\uxnemu_stub.c /Fe$@
!ENDIF

# Development and setup targets
setup: setup-vcpkg install-sdl2
	@echo Setup complete! You can now build with 'nmake all'

setup-vcpkg:
	@echo Setting up vcpkg...
	@if not exist "vcpkg" (git clone https://github.com/Microsoft/vcpkg.git)
	@if not exist "vcpkg\vcpkg.exe" (cd vcpkg && .\bootstrap-vcpkg.bat)
	cd vcpkg && .\vcpkg integrate install

install-sdl2: setup-vcpkg
	@echo Installing SDL2...
	cd vcpkg && .\vcpkg install

# Clean targets
clean:
	@if exist "$(BINDIR)\*.exe" del $(BINDIR)\*.exe
	@if exist "$(BUILDDIR)\*.obj" del $(BUILDDIR)\*.obj
	@if exist "src\*.obj" del src\*.obj

clean-all: clean
	@if exist "vcpkg" rmdir /s /q vcpkg
	@if exist "$(BUILDDIR)" rmdir /s /q $(BUILDDIR)

# ROM building (requires uxnasm)
%.rom: %.tal $(BINDIR)\uxnasm.exe
	$(BINDIR)\uxnasm.exe $< $@

# Test ROM building
test-cli.rom: test-cli.tal $(BINDIR)\uxnasm.exe
	$(BINDIR)\uxnasm.exe test-cli.tal test-cli.rom

test-gui.rom: test-gui.tal $(BINDIR)\uxnasm.exe
	$(BINDIR)\uxnasm.exe test-gui.tal test-gui.rom

# Create default test files if they don't exist
test-cli.tal:
	@if not exist "test-cli.tal" powershell -Command "& {$$content = @('( hello world - CLI test )', '', '|0100 ( -> )', '	;hello-txt print-str', '	BRK', '', '@print-str ( str* -> )', '	&loop', '		LDAk #18 DEO', '		INC2 LDAk ?&loop', '	POP2 JMP2r', '', '@hello-txt \"hello 20 \"world! 0a 00', ''); [System.IO.File]::WriteAllLines('test-cli.tal', $$content, [System.Text.Encoding]::ASCII); Write-Host 'Created test-cli.tal'}"

test-gui.tal:
	@if not exist "test-gui.tal" powershell -Command "& {$$content = @('( GUI Hello World )', '', '|00 @System &vector $$2 &wst $$1 &rst $$1 &eaddr $$2 &ecode $$1 &pad $$1 &r $$2 &g $$2 &b $$2 &debug $$1 &halt $$1', '|20 @Screen &vector $$2 &width $$2 &height $$2 &auto $$1 &pad $$1 &x $$2 &y $$2 &addr $$2 &pixel $$1 &sprite $$1', '', '( variables )', '', '|0000', '', '( program )', '', '|0100', '	', '	( theme )', '	#f05d .System/r DEO2', '	#f0cd .System/g DEO2', '	#f0ad .System/b DEO2', '', '	( draw hello world )', '	#0010 .Screen/x DEO2', '	#0010 .Screen/y DEO2', '	;hello-txt #01 ;draw-uf1 JSR2', '', 'BRK', '', '@draw-uf1 ( string* color -- )', '', '	#01 .Screen/auto DEO', '	STH', '	&while', '		( get sprite ) LDAk #20 SUB #00 SWP #30 SFT2 ;font ADD2 .Screen/addr DEO2', '		( draw ) STHkr .Screen/sprite DEO', '		INC2 LDAk ,&while JCN', '	POPr', '	POP2', '', 'JMP2r', '', '@hello-txt \"Hello 20 \"World! 00', '', '@font ( bbcmicro )', '	0000 0000 0000 0000 1818 1818 1800 1800', '	6c6c 6c00 0000 0000 3636 7f36 7f36 3600', '	0c3f 683e 0b7e 1800 6066 0c18 3066 0600', '	386c 6c38 6d66 3b00 0c18 3000 0000 0000', '	0c18 3030 3018 0c00 3018 0c0c 0c18 3000', '	0018 7e3c 7e18 0000 0018 187e 1818 0000', '	0000 0000 0018 1830 0000 007e 0000 0000', '	0000 0000 0018 1800 0006 0c18 3060 0000', '	3c66 6e7e 7666 3c00 1838 1818 1818 7e00', '	3c66 060c 1830 7e00 3c66 061c 0666 3c00', '	0c1c 3c6c 7e0c 0c00 7e60 7c06 0666 3c00', '	1c30 607c 6666 3c00 7e06 0c18 3030 3000', '	3c66 663c 6666 3c00 3c66 663e 060c 3800', '	0000 1818 0018 1800 0000 1818 0018 1830', '	0c18 3060 3018 0c00 0000 7e00 7e00 0000', '	3018 0c06 0c18 3000 3c66 0c18 1800 1800', '	3c66 6e6a 6e60 3c00 3c66 667e 6666 6600', '	7c66 667c 6666 7c00 3c66 6060 6066 3c00', '	786c 6666 666c 7800 7e60 607c 6060 7e00', '	7e60 607c 6060 6000 3c66 606e 6666 3c00', '	6666 667e 6666 6600 7e18 1818 1818 7e00', '	3e0c 0c0c 0c6c 3800 666c 7870 786c 6600', '	6060 6060 6060 7e00 6377 7f6b 6b63 6300', '	6666 767e 6e66 6600 3c66 6666 6666 3c00', '	7c66 667c 6060 6000 3c66 6666 6a6c 3600', '	7c66 667c 6c66 6600 3c66 603c 0666 3c00', '	7e18 1818 1818 1800 6666 6666 6666 3c00', '	6666 6666 663c 1800 6363 6b6b 7f77 6300', '	6666 3c18 3c66 6600 6666 663c 1818 1800', '	7e06 0c18 3060 7e00 7c60 6060 6060 7c00', '	0060 3018 0c06 0000 3e06 0606 0606 3e00', '	183c 6642 0000 0000 0000 0000 0000 00ff', '	1c36 307c 3030 7e00 0000 3c06 3e66 3e00', '	6060 7c66 6666 7c00 0000 3c66 6066 3c00', '	0606 3e66 6666 3e00 0000 3c66 7e60 3c00', '	1c30 307c 3030 3000 0000 3e66 663e 063c', '	6060 7c66 6666 6600 1800 3818 1818 3c00', '	1800 3818 1818 1870 6060 666c 786c 6600', '	3818 1818 1818 3c00 0000 367f 6b6b 6300', '	0000 7c66 6666 6600 0000 3c66 6666 3c00', '	0000 7c66 667c 6060 0000 3e66 663e 0607', '	0000 6c76 6060 6000 0000 3e60 3c06 7c00', '	3030 7c30 3030 1c00 0000 6666 6666 3e00', '	0000 6666 663c 1800 0000 636b 6b7f 3600', '	0000 663c 183c 6600 0000 6666 663e 063c', '	0000 7e0c 1830 7e00 0c18 1870 1818 0c00', '	1818 1800 1818 1800 3018 180e 1818 3000', '	316b 4600 0000 0000 ffff ffff ffff ffff'); [System.IO.File]::WriteAllLines('test-gui.tal', $$content, [System.Text.Encoding]::ASCII); Write-Host 'Created test-gui.tal'}"

# Test targets
test: $(BINDIR)\uxncli.exe test-cli.tal test-cli.rom
	@echo Testing CLI emulator...
	$(BINDIR)\uxncli.exe test-cli.rom

test-gui: $(BINDIR)\uxnemu.exe test-gui.tal test-gui.rom
	@echo Testing GUI emulator...
	$(BINDIR)\uxnemu.exe test-gui.rom

# Help target
help:
	@echo UXN Build System for Windows
	@echo.
	@echo Targets:
	@echo   all       - Build all executables
	@echo   setup     - Install vcpkg and SDL2 dependencies
	@echo   clean     - Remove built executables and objects
	@echo   clean-all - Remove everything including vcpkg
	@echo   test      - Test CLI emulator with test.rom
	@echo   test-gui  - Test GUI emulator with test.rom
	@echo   help      - Show this help
	@echo.
	@echo Individual targets:
	@echo   $(BINDIR)\uxnasm.exe - UXN Assembler
	@echo   $(BINDIR)\uxncli.exe - UXN CLI Emulator
	@echo   $(BINDIR)\uxnemu.exe - UXN GUI Emulator (requires SDL2)
	@echo.
	@echo ROM building:
	@echo   nmake program.rom    - Assemble program.tal to program.rom
	@echo.
	@echo First time setup:
	@echo   nmake setup
	@echo   nmake all

.PHONY: all setup setup-vcpkg install-sdl2 clean clean-all test test-gui help