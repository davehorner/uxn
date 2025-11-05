# UXN - Windows Build Instructions

This directory contains the Windows build system for UXN using Microsoft Visual C++ and nmake.

## Prerequisites

- Microsoft Visual Studio 2022 (Community, Professional, or Enterprise) with C++ tools
- Git (for vcpkg dependency management)
- VS Code with Microsoft C/C++ Extension (recommended)

## Quick Start

1. **First-time setup** (installs vcpkg and SDL2):
   ```cmd
   nmake /f Makefile.mak setup
   ```

2. **Build everything**:
   ```cmd
   nmake /f Makefile.mak all
   ```

3. **Test the build**:
   ```cmd
   nmake /f Makefile.mak test
   ```

## Available Targets

### Build Targets
- `all` - Build all executables
- `bin\uxnasm.exe` - UXN Assembler only
- `bin\uxncli.exe` - UXN CLI Emulator only
- `bin\uxnemu.exe` - UXN GUI Emulator only (requires SDL2)

### Setup Targets
- `setup` - Install vcpkg and SDL2 dependencies
- `setup-vcpkg` - Install vcpkg only
- `install-sdl2` - Install SDL2 only

### Utility Targets
- `clean` - Remove built executables and objects
- `clean-all` - Remove everything including vcpkg
- `test` - Test CLI emulator with test.rom
- `test-gui` - Test GUI emulator with test.rom
- `help` - Show help information

### ROM Building
- `program.rom` - Assemble program.tal to program.rom (requires uxnasm)

## VS Code Integration

This project includes VS Code configuration for:
- **Build tasks** (Ctrl+Shift+P → "Tasks: Run Task")
- **IntelliSense** with proper include paths
- **Debugging** with Visual Studio debugger
- **Makefile Tools** extension support

### Available VS Code Tasks
- Build All (Ctrl+Shift+B)
- Setup Dependencies
- Build UXN Assembler
- Build UXN CLI
- Build UXN GUI
- Clean
- Test CLI
- Test GUI

## Project Structure

```
uxn/
├── Makefile.mak          # Main nmake build file
├── vcpkg.json           # vcpkg dependency configuration
├── src/                 # Source code
│   ├── uxn.c/h          # Core UXN implementation
│   ├── uxnasm.c         # UXN Assembler
│   ├── uxncli.c         # CLI Emulator
│   ├── uxnemu.c         # GUI Emulator
│   ├── cli_stubs.c      # Windows compatibility stubs
│   └── devices/         # Device implementations
│       └── file_win.c   # Windows file device implementation
├── bin/                 # Built executables
├── vcpkg_installed/    # vcpkg packages (auto-created)
└── .vscode/            # VS Code configuration
```

## Troubleshooting

### SDL2 Issues
If `uxnemu.exe` fails to build:
1. Run `nmake /f Makefile.mak setup` to ensure SDL2 is installed
2. Check that `vcpkg_installed\packages\sdl2_x64-windows\` exists
3. Clean and rebuild: `nmake /f Makefile.mak clean && nmake /f Makefile.mak all`

### Compiler Issues
- Ensure Visual Studio C++ tools are in PATH
- Use "Developer Command Prompt" or "Developer PowerShell"
- Check that `cl.exe` and `nmake.exe` are available

### VS Code Issues
- Install "Microsoft C/C++" extension
- Install "Makefile Tools" extension (optional but recommended)
- Reload window after installing extensions

## Command Line Examples

```cmd
# Complete setup from scratch
nmake /f Makefile.mak setup
nmake /f Makefile.mak all

# Build just the assembler and CLI
nmake /f Makefile.mak bin\uxnasm.exe
nmake /f Makefile.mak bin\uxncli.exe

# Test with the generated test files
nmake /f Makefile.mak test
nmake /f Makefile.mak test-gui

# Clean everything and start over
nmake /f Makefile.mak clean-all
nmake /f Makefile.mak setup
nmake /f Makefile.mak all
```