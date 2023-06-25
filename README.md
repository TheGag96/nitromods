# nitromods

This is a project management tool for modding DS games. It's capable of unpacking ROMs, installing the necessary code to load a custom overlay, applying multiple self-contained mods (including compiling/assembling code files from source), and building ROMs together again.


## Setup

Firstly, you'll need to install [devkitARM](https://devkitpro.org/wiki/Getting_Started) so that you can assemble assembly and compile C code in mods from source. To be able to support mods written in the [D language](https://dlang.org), you'll need a copy of the [LLVM D Compiler (LDC)](https://github.com/ldc-developers/ldc#installation).

At the moment, there is an external dependency on the program [knarc](https://github.com/kr3nshaw/knarc) so that we can unpack and repack NARC files. Hopefully, this will be replaced with our own NARC library, but for now, **place the knarc executable in the same directory as the nitromods executable.**

Then, you can initalize your project like:

```sh
nitromods init your_rom_file.nds
```

This will create a `mods` folder and unpack your ROM's entire filesystem into `romfiles_original` and `romfiles`. The former folder is meant to preserve the original files of your base ROM, while the latter is what will be built into your final ROM when building the project. 

If your base ROM already has a custom overlay, it will use that as the basis for further code additions from mods.


## Building ROMs

If you do:

```sh
nitromods build
```

This will, using the `romfiles` folder, install the custom overlay support, compile or assemble all code files from mods, patch all the mods, and stitch them together into a new ROM called `build.nds`. (You can specify a different name for the output ROM if you'd like.)


## Mods

This tool envisions mods as each being contained as folders in the `mods` folder. In each folder is a `mod.yaml` that might look like:

```yaml
name: My Mod
author: Your name here!
version: 1.0
description: A mod that does something cool
rom_version: CPUE # Pokémon Platinum, english
free_ram: 0x24    # How much RAM in the custom overlay to reserve to use as free RAM

code:                      # The following files will be looked for in the `code` folder inside the mod folder.
  - file: some_assembly.s  # You can ask nitrmods to assemble assembly for you and put it in the custom overlay.
    destination: custom
    hijacks:               # If you need another piece of code to jump to yours, you can specify a hijack.
      - destination: arm9
        offset: 0x9018
  - file: some_c_code.c    # You can even write mods in C...
    destination: custom
  - file: some_d_code.d    # ...or even D!
    destination: custom
  - file: some_binary.bin  # You can inject a random binary blob as well.
    destination: overlay27 # Your destination can be anywhere...
    offset: 0xABC0
```

Nitrmods will hook everything together

## Games currently supported:

* Pokémon Diamond, Pearl & Platinum (English, Spanish)
* Pokémon HeartGold & SoulSilver (English, Spanish)
* Animal Crossing: Wild World (USA v1.0, v1.1, PAL)

I'd like to get to a state where support for games can be specified through configuration files and therefore expanded without recompiling the program.

**Note**: For games that make use of a compressed ARM9.bin and overlays, like HGSS and ACWW, you'll need to create a ROM that has them all compressed *before* invoking `nitromods init`. I'd like to get to the point where the tool could do this automatically! For ACWW specifically, you can find patches that decompress everything for you [here](https://github.com/TheGag96/acww-hax).


## Building nitromods from source

Install any [D compiler](https://dlang.org/download.html), and then if it didn't get installed already, install the `dub` build system. Then, it should (hopefully)  be as simple as:

```sh
dub build --build=release
```

## To do

* Make error handling better
* Add support for file replacement in mods
* Replace knarc with own NARC library
* Automatically decompress base ROM ARM9.bin and overlays
* Add game support through configuration files
* Implement basic linker and add system that lets people make bindings to known functions from the ROM