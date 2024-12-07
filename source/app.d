module nitromods.app;

import std.stdio, std.algorithm, std.process, std.file, std.path, std.conv, std.array, std.bitmanip, std.format, std.regex, std.functional, std.string;
import nitromods.util, nitromods.narc, nitromods.arena;

enum MODS_FOLDER               = "mods";
enum MOD_INFO_FILE             = "mod.yaml";
enum PROJECT_INFO_FILE         = "project.yaml";
enum ROM_FILES_FOLDER          = "romfiles";
enum ROM_FILES_ORIGINAL_FOLDER = "romfiles_original";
enum TEMP_FOLDER               = "tmp_nitromods";
enum CUSTOM_OVERLAY_FILE       = "overlay_custom.bin";
enum CUSTOM_OVERLAY_PATH       = buildPath(ROM_FILES_FOLDER,          "overlay", "overlay_custom.bin");
enum CUSTOM_OVERLAY_ORIG_PATH  = buildPath(ROM_FILES_ORIGINAL_FOLDER, "overlay", "overlay_custom.bin");
enum CUSTOM_OVERLAY_TAG        = "NITROMOD";
enum PREPROCESS_SOURCE_PATH    = buildPath(TEMP_FOLDER, "preprocessed");

enum CUSTOM_OVERLAY_FILE_SIZE   = 1024*96;
enum CUSTOM_OVERLAY_HEADER_SIZE = 0x20;

string gDevkitproPath, gDevkitarmPath;

Arena tTempStorage;

struct CustomOverlayGameData {
  uint loadAddress;

  uint initSubOffset;
  ubyte[] initSubCode;

  uint branchOffset;
  ubyte[] branchCode;

  string hostFile;
  short hostSubfile;
  enum USE_WHOLE_FILE = -1;
}

struct GameVer {
  GameCode code;
  ubyte revision;
}

enum GameCode {
  DiamondEng,       // ADAE
  PearlEng,         // APAE
  PlatinumEng,      // CPUE
  HeartGoldEng,     // IPKE
  SoulSilverEng,    // IPGE
  DiamondSpa,       // ADAS
  PearlSpa,         // APAS
  PlatinumSpa,      // CPUS
  HeartGoldSpa,     // IPKS
  SoulSilverSpa,    // IPGS

  WildWorldUsa,     // ADME
  WildWorldPal,     // ADMP
}

// Thanks to: Mikelan98, Nomura: ARM9 Expansion Subroutine (pokehacking.com/r/20041000)
static immutable CustomOverlayGameData[][GameCode.max+1] CO_GAME_INFO = [
  GameCode.DiamondEng       : [ { 0x023C8000, 0x1064EC, hex!"FC B5 05 48 C0 46 41 21 09 22 02 4D A8 47 00 20 03 21 FC BD F1 64 00 02 00 80 3C 02", 0xC80, hex!"05 F1 34 FC", "data/weather_sys.narc", 9 } ],
  GameCode.PearlEng         : [ { 0x023C8000, 0x1064EC, hex!"FC B5 05 48 C0 46 41 21 09 22 02 4D A8 47 00 20 03 21 FC BD F1 64 00 02 00 80 3C 02", 0xC80, hex!"05 F1 34 FC", "data/weather_sys.narc", 9 } ],
  GameCode.PlatinumEng      : [ { 0x023C8000, 0x100E20, hex!"FC B5 05 48 C0 46 41 21 09 22 02 4D A8 47 00 20 03 21 FC BD A5 6A 00 02 00 80 3C 02", 0xCB4, hex!"00 F1 B4 F8", "data/weather_sys.narc", 9 } ],
  GameCode.HeartGoldEng     : [ { 0x023C8000, 0x110334, hex!"FC B5 05 48 C0 46 1C 21 00 22 02 4D A8 47 00 20 03 21 FC BD 09 75 00 02 00 80 3C 02", 0xCD0, hex!"0F F1 30 FB", "a/0/2/8",               0 } ],
  GameCode.SoulSilverEng    : [ { 0x023C8000, 0x110334, hex!"FC B5 05 48 C0 46 1C 21 00 22 02 4D A8 47 00 20 03 21 FC BD 09 75 00 02 00 80 3C 02", 0xCD0, hex!"0F F1 30 FB", "a/0/2/8",               0 } ],
  GameCode.DiamondSpa       : [ { 0x023C8000, 0x10668C, hex!"FC B5 05 48 C0 46 41 21 09 22 02 4D A8 47 00 20 03 21 FC BD F1 64 00 02 00 80 3C 02", 0xC80, hex!"05 F1 04 FD", "data/weather_sys.narc", 9 } ],
  GameCode.PearlSpa         : [ { 0x023C8000, 0x10668C, hex!"FC B5 05 48 C0 46 41 21 09 22 02 4D A8 47 00 20 03 21 FC BD F1 64 00 02 00 80 3C 02", 0xC80, hex!"05 F1 04 FD", "data/weather_sys.narc", 9 } ],
  GameCode.PlatinumSpa      : [ { 0x023C8000, 0x10101C, hex!"FC B5 05 48 C0 46 41 21 09 22 02 4D A8 47 00 20 03 21 FC BD B9 6A 00 02 00 80 3C 02", 0xCB4, hex!"00 F1 B2 F9", "data/weather_sys.narc", 9 } ],
  GameCode.HeartGoldSpa     : [ { 0x023C8000, 0x110354, hex!"FC B5 05 48 C0 46 1C 21 00 22 02 4D A8 47 00 20 03 21 FC BD 09 75 00 02 00 80 3C 02", 0xCD0, hex!"0F F1 40 FB", "a/0/2/8",               0 } ],
  GameCode.SoulSilverSpa    : [ { 0x023C8000, 0x110354, hex!"FC B5 05 48 C0 46 1C 21 00 22 02 4D A8 47 00 20 03 21 FC BD 09 75 00 02 00 80 3C 02", 0xCD0, hex!"0F F1 40 FB", "a/0/2/8,",              0 } ],
  GameCode.WildWorldUsa     : [
    // USA Revision 0
    0 : {
      0x022C1000, 0xFC0, hex!(
        "00 B5 FF B4 8F B0 68 46 09 A1 04 22 00 23 10 4F B8 47 68 46 0F 49 0A 9A 09 9B D2 1A 0E 4F B8 47 68 46 0E 4F B8 47 0F B0 FF BC 0D 48 01 43 00 BD 2F 73" ~
        "6B 79 2F 64 5F 32 64 5F 77 65 61 74 68 65 72 5F 74 65 73 74 5F 6E 63 6C 2E 62 69 6E 00 00 1D 43 06 02 00 10 2C 02 34 93 11 02 60 94 11 02 00 00 01 00"
      ),
      0x6D554, makeBl(0xFC0-0x6D554).nativeToLittleEndian, "sky/d_2d_weather_test_ncl.bin", CustomOverlayGameData.USE_WHOLE_FILE
    },
    // USA Revision 1
    1 : {
      0x022C1000, 0xFC0, hex!(
        "00 B5 FF B4 8F B0 68 46 09 A1 04 22 00 23 10 4F B8 47 68 46 0F 49 0A 9A 09 9B D2 1A 0E 4F B8 47 68 46 0E 4F B8 47 0F B0 FF BC 0D 48 01 43 00 BD 2F 73" ~
        "6B 79 2F 64 5F 32 64 5F 77 65 61 74 68 65 72 5F 74 65 73 74 5F 6E 63 6C 2E 62 69 6E 00 00 98 43 06 02 00 10 2C 02 B4 98 11 02 E0 99 11 02 00 00 01 00"
      ),
      0x6D61C, makeBl(0xFC0-0x6D61C).nativeToLittleEndian, "sky/d_2d_weather_test_ncl.bin", CustomOverlayGameData.USE_WHOLE_FILE
    }
  ],
  GameCode.WildWorldPal     : [
    {
      0x022D1000, 0xFC0, hex!(
        "00 B5 FF B4 8F B0 68 46 09 A1 04 22 00 23 10 4F B8 47 68 46 0F 49 0A 9A 09 9B D2 1A 0E 4F B8 47 68 46 0E 4F B8 47 0F B0 FF BC 0D 48 01 43 00 BD 2F 73" ~
        "6B 79 2F 64 5F 32 64 5F 77 65 61 74 68 65 72 5F 74 65 73 74 5F 6E 63 6C 2E 62 69 6E 00 00 3D 46 06 02 00 10 2D 02 98 CC 11 02 C4 CD 11 02 00 00 01 00"
      ),
      0x6D944, makeBl(0xFC0-0x6D944).nativeToLittleEndian, "sky/d_2d_weather_test_ncl.bin", CustomOverlayGameData.USE_WHOLE_FILE
    }
  ],
];

ref const(CustomOverlayGameData) coGameInfo(GameVer gameVer) {
  return CO_GAME_INFO[gameVer.code][gameVer.revision];
}

static immutable FOLLOWING_PLAT_CO_BRANCH = hex!"E9 F0 D0 FF";
enum FOLLOWING_PLAT_CO_FREE_SPACE_START = 0x13CD0; //subject to change if the mod is updated
enum FOLLOWING_PLAT_CO_SUBFILE          = 65;

int main(string[] args) {
  tTempStorage = arenaMake(16 * 1024 * 1024);

  if (args.length < 2) {
    stderr.writeln("Ways to invoke this program: ");
    stderr.writeln("  nitromods init base_rom.nds");
    stderr.writeln("  This takes a base ROM, extracts the whole filesystem, and sets up a basic project folder structure.");
    stderr.writeln();
    stderr.writeln("  nitromods build [output_rom.nds]");
    stderr.writeln("  This builds an output ROM from the project in the current directory, applying all mods and");
    stderr.writeln("  inserting the hijacks that make custom overlays work.");
    stderr.writeln("  If no ROM file is specified, the output is called `build.nds`.");
    return 1;
  }

  gDevkitproPath = environment.get("DEVKITPRO");
  gDevkitarmPath = environment.get("DEVKITARM");

  if (!gDevkitproPath || !gDevkitarmPath) {
    stderr.writeln("Error: DEVKITPRO and DEVKITARM must be in your PATH.\n",
                   "Ensure DevkitARM is installed and try again.");
    return 1;
  }

  switch (args[1]) {
    case "init":  
      if (args.length < 3) {
        stderr.writeln("Error: The init commands needs a ROM filename to start the project with.");
        return 1;
      }
      return init(args[2]);
    
    case "build": 
      string newRomFile = args.length < 3 ? "build.nds" : args[2];
      return build(newRomFile);

    default: 
      stderr.writeln("Error: Unrecognized command.");
      return 1;
  }
}

int init(string romFile) {
  if (exists(PROJECT_INFO_FILE)) {
    stderr.writeln("Error: A project already exists in this folder.");
    return 1;
  }

  foreach (folder; [ROM_FILES_FOLDER, ROM_FILES_ORIGINAL_FOLDER]) {
    if (exists(folder)) {
      stderr.writeln("Error: `", folder, "` already exists. Please move/remove it and try again.");
      return 1;
    }   
  }

  mkdirRecurse(ROM_FILES_ORIGINAL_FOLDER);

  if (exists(TEMP_FOLDER)) {
    stderr.writeln("Error: The temporary working folder `", TEMP_FOLDER, "` exists. Please move/delete it manually.");
    return 1;
  }

  mkdirRecurse(TEMP_FOLDER);
  scope (exit) rmdirRecurse(TEMP_FOLDER);

  mkdirRecurse(MODS_FOLDER);

  auto cmdResult = execute([
    "ndstool", "-x", romFile, 
    "-d",  buildPath(ROM_FILES_ORIGINAL_FOLDER, "data"),
    "-9",  buildPath(ROM_FILES_ORIGINAL_FOLDER, "arm9.bin"),
    "-7",  buildPath(ROM_FILES_ORIGINAL_FOLDER, "arm7.bin"),
    "-y",  buildPath(ROM_FILES_ORIGINAL_FOLDER, "overlay"),
    "-y9", buildPath(ROM_FILES_ORIGINAL_FOLDER, "arm9ovltable.bin"),
    "-y7", buildPath(ROM_FILES_ORIGINAL_FOLDER, "arm7ovltable.bin"),
    "-t",  buildPath(ROM_FILES_ORIGINAL_FOLDER, "banner.bin"),
    "-h",  buildPath(ROM_FILES_ORIGINAL_FOLDER, "header.bin"),
    "-o",  buildPath(ROM_FILES_ORIGINAL_FOLDER, "logo.bin"),
  ]);

  {
    GameVer gameVer = extractGameVer(ROM_FILES_ORIGINAL_FOLDER);

    ubyte[4] coBranchCode = extractCOBranchCode(gameVer, ROM_FILES_ORIGINAL_FOLDER);

    bool isFollowingPlatBranch = gameVer.code == GameCode.PlatinumEng && coBranchCode == FOLLOWING_PLAT_CO_BRANCH;

    if (coBranchCode == coGameInfo(gameVer).branchCode || isFollowingPlatBranch) {
      //custom overlay already exists
      if (coGameInfo(gameVer).hostSubfile == CustomOverlayGameData.USE_WHOLE_FILE) {
        copy(buildPath(ROM_FILES_ORIGINAL_FOLDER, "data", coGameInfo(gameVer).hostFile), CUSTOM_OVERLAY_ORIG_PATH);
      }
      else {
        auto coSubfile = unpackCustomOverlayNarc(gameVer, isFollowingPlatBranch, ROM_FILES_ORIGINAL_FOLDER);
        std.file.write(CUSTOM_OVERLAY_ORIG_PATH, coSubfile);
      }
    }
    else {
      //make new custom overlay

      auto customOverlayFile = File(CUSTOM_OVERLAY_ORIG_PATH, "wb");

      uint[1] zero;
      foreach (i; 0..CUSTOM_OVERLAY_FILE_SIZE/4) {
        customOverlayFile.rawWrite(zero[]);
      }
    }
  }

  // @TOOD: Replace these shell calls with direct OS calls or something...
  version (Windows) {
    execute(["xcopy", "/i", "/e", ROM_FILES_ORIGINAL_FOLDER, ROM_FILES_FOLDER]);
  }
  else version (Posix) {
    execute(["cp", "-r", ROM_FILES_ORIGINAL_FOLDER, ROM_FILES_FOLDER]);
  }
  else static assert(0, "Need support for copying a directory.");

  return 0;
}

int build(string newRomFile) {
  import std.file, std.algorithm;

  if (!(exists(MODS_FOLDER) && isDir(MODS_FOLDER))) {
    stderr.writeln("Error: There should be a folder called `", MODS_FOLDER, "` that holds the project's mods, but it's not there!");
    return 1;
  }

  if (exists(TEMP_FOLDER)) {
    stderr.writeln("Error: The temporary working folder `", TEMP_FOLDER, "` exists. Please move/delete it manually.");
    return 1;
  }

  mkdirRecurse(TEMP_FOLDER);
  mkdirRecurse(PREPROCESS_SOURCE_PATH);
  scope (exit) rmdirRecurse(TEMP_FOLDER);

  //restore original overlay
  void restoreFile(string path) {
    copy(buildPath(ROM_FILES_ORIGINAL_FOLDER, path), buildPath(ROM_FILES_FOLDER, path));
  }

  foreach (x; ["arm9.bin", "arm7.bin", "overlay/overlay_custom.bin"]) {
    restoreFile(x);
  }

  ProjectInfo projInfo = getProjectInfo();

  foreach (i; 0..projInfo.overlayOffsets.length) {
    restoreFile(format("overlay/overlay_%04d.bin", i));
  }
  installCustomOverlay(projInfo);

  auto mods = findMods();
  foreach (ref mod; mods) {
    patchAllCode(mod, projInfo);
  }

  {
    auto coStart = projInfo.customOverlay.startOffset;
    projInfo.customOverlay.header.nextFreeSpace = projInfo.customOverlay.currentOffset - coStart;
    projInfo.customOverlay.data[coStart..coStart+COHeader.sizeof] = toRawBytes!COHeader(projInfo.customOverlay.header);

    std.file.write(CUSTOM_OVERLAY_PATH, projInfo.customOverlay.data);

    if (coGameInfo(projInfo.gameVer).hostSubfile == CustomOverlayGameData.USE_WHOLE_FILE) {
      copy(CUSTOM_OVERLAY_PATH, buildPath(ROM_FILES_FOLDER, "data", coGameInfo(projInfo.gameVer).hostFile));
    }
    else {
      packCustomOverlayNarc(projInfo.customOverlay.data, projInfo.gameVer, projInfo.isFollowingPlatinum);
    }
  }

  auto cmdResult = execute([
    "ndstool", "-c", newRomFile, 
    "-d",  buildPath(ROM_FILES_FOLDER, "data"),
    "-9",  buildPath(ROM_FILES_FOLDER, "arm9.bin"),
    "-7",  buildPath(ROM_FILES_FOLDER, "arm7.bin"),
    "-y",  buildPath(ROM_FILES_FOLDER, "overlay"),
    "-y9", buildPath(ROM_FILES_FOLDER, "arm9ovltable.bin"),
    "-y7", buildPath(ROM_FILES_FOLDER, "arm7ovltable.bin"),
    "-t",  buildPath(ROM_FILES_FOLDER, "banner.bin"),
    "-h",  buildPath(ROM_FILES_FOLDER, "header.bin"),
    "-o",  buildPath(ROM_FILES_FOLDER, "logo.bin"),
  ]);

  return 0;
}


struct Mod {
  string configPath, modPath;
  string name, author, version_, description;
  uint freeRAM;

  struct CodePatch {
    string file, destination, name;
    uint offset;
    bool addNewCode;

    struct Hijack {
      string destination;
      uint offset;
    }

    Hijack[] hijacks;
  }

  CodePatch[] code;
}

// Members of this struct shouldn't be removed or reordered for compatibility reasons!
struct COHeader {
  char[CUSTOM_OVERLAY_TAG.length] tag = CUSTOM_OVERLAY_TAG;
  uint nextFreeSpace;
}
static assert(COHeader.sizeof <= CUSTOM_OVERLAY_HEADER_SIZE);

struct ProjectInfo {
  uint[] overlayOffsets;

  struct CustomOverlay {
    bool alreadyInstalled;
    COHeader header;
    ubyte[] data;
    uint startOffset;
    uint currentOffset;
  }
  CustomOverlay customOverlay;

  GameVer gameVer;
  bool isFollowingPlatinum;
}

struct Symbol {
  string name;
  uint value;
}

Mod[] findMods() {
  auto modDirs = dirEntries(MODS_FOLDER, SpanMode.shallow)
    .filter!(x => x.isDir)
    .map!(x => buildPath(x.name, MOD_INFO_FILE))
    .filter!exists
    .map!parseModInfo
    .array;

  return modDirs;
}

Mod parseModInfo(string path) {
  import dyaml;

  Mod result;

  result.configPath = path;
  result.modPath    = path.dirName;

  Node root = Loader.fromFile(path).load();

  result.name        = root["name"].as!string;
  result.author      = root["author"].as!string;
  result.version_    = root["version"].as!string;
  result.description = root["description"].as!string;

  if (auto freeRAM = "free_ram" in root) {
    result.freeRAM = root["free_ram"].as!uint;
  }

  if (auto code = "code" in root) {
    foreach (ref Node codeNode; *code) {
      Mod.CodePatch codePatch;
      
      codePatch.file        = codeNode["file"].as!string;
      codePatch.destination = codeNode["destination"].as!string;

      if (auto name = "name" in codeNode) {
        codePatch.name = (*name).as!string;
      }
      else {
        codePatch.name = codePatch.file.baseName.stripExtension;
      }

      if (auto offset = "offset" in codeNode) {
        codePatch.offset = (*offset).as!uint;
      }
      else {
        codePatch.addNewCode = true;
      }

      if (auto hijacks = "hijacks" in codeNode) {
        foreach (ref Node hijackNode; *hijacks) {
          Mod.CodePatch.Hijack hijack;

          hijack.destination = hijackNode["destination"].as!string;
          hijack.offset      = hijackNode["offset"].as!uint;

          codePatch.hijacks ~= hijack;
        }
      }

      result.code ~= codePatch;
    }
  }

  return result;
}

void patchAllCode(ref Mod mod, ref ProjectInfo projInfo) {
  auto preprocessCodePath = buildPath(PREPROCESS_SOURCE_PATH, mod.name);
  mkdirRecurse(preprocessCodePath);

  Symbol[] symbols = [Symbol("Mod_Free_RAM", coGameInfo(projInfo.gameVer).loadAddress + projInfo.customOverlay.currentOffset)];

  projInfo.customOverlay.currentOffset += mod.freeRAM;

  foreach (ref codePatch; mod.code) {
    string sourceFile = buildPath(mod.modPath, "code", codePatch.file);
    string includesFile;

    if ([".s", ".asm", ".c", ".d"].canFind(codePatch.file.extension)) {
      includesFile = makeIncludesFile(preprocessCodePath, sourceFile, symbols);
    }

    string compiledPath = compile(mod, sourceFile, includesFile, preprocessCodePath);

    uint codeAddr;

    if (codePatch.destination == "custom" && codePatch.addNewCode) {
      //handle new code
      codeAddr = customOverlayAdd(projInfo, extractMachineCode(compiledPath));
      writefln("Patched new code %s at %X", codePatch.file.baseName, codeAddr);
    }
    else {
      codeAddr = getAddr(projInfo, codePatch.destination, codePatch.offset);
      patch(getDestinationFile(codePatch.destination), extractMachineCode(compiledPath), codePatch.offset);
      writefln("Patched existing code with %s at %X", codePatch.file.baseName, codeAddr);
    }

    foreach (ref hijack; codePatch.hijacks) {
      uint blInstruction = makeBl(codeAddr - getAddr(projInfo, hijack.destination, hijack.offset));

      patch(getDestinationFile(hijack.destination), nativeToLittleEndian(blInstruction)[], hijack.offset);
      writefln("  Writing hijack to %s: %X to %X", hijack.destination, getAddr(projInfo, hijack.destination, hijack.offset), codeAddr);
    }

    symbols ~= Symbol(codePatch.name, codeAddr);
  }
}

string compile(ref Mod mod, string filename, string includesFilename, string outDir) {
  string program;
  string[] options;

  string outputFlag = "-o";

  switch (filename.extension) {
    case ".bin":
    default:
      //don't compile binary files - just returned them to be patched as-is
      return filename;

    case ".c":
      program = buildPath(gDevkitarmPath, "bin/arm-none-eabi-gcc");
      options = [
        "-Wall", "-Os", "-std=c11", "-march=armv5te", "-mtune=arm946e-s", "-fomit-frame-pointer", "-ffast-math",
        "-mthumb", "-mthumb-interwork", "-fshort-enums",
        "-I" ~ gDevkitproPath ~ "/libnds/include",
        "-I" ~ gDevkitproPath ~ "/calico/include",
        "-include", includesFilename, "-D__NDS__", "-DARM9",
      ];
      break;

    case ".d":
      program = "ldc2";
      options = ["-betterC", "--defaultlib=no", "-Os", "-ffast-math", "-mtriple=armv5te-none-eabi",
                 "-mcpu=arm946e-s", "-float-abi=soft", "-mattr=+thumb-mode", "--frame-pointer=none", "--link-internally", "--disable-loop-unrolling",
                 "-I", filename.dirName, "-i", includesFilename];
      outputFlag = "-of";
      break;

    case ".s":
    case ".asm":
      program = buildPath(gDevkitarmPath, "bin/arm-none-eabi-as");
      options = ["-march=armv5te", "-mthumb", "-mthumb-interwork", "-I", includesFilename.dirName];
      break;
  }

  string outPath = buildPath(outDir, filename.baseName.setExtension(".o"));

  auto cmdResult = execute(
    [program] ~ options ~ ["-c", filename, outputFlag, outPath]
  );

  if (cmdResult.status != 0) {
    throw new Exception("Compilation failed: " ~ cmdResult.output);
  }

  writeln(cmdResult.output);

  return outPath;
}

string getDestinationFileImpl(string destination) {
  if (destination == "custom") {
    return CUSTOM_OVERLAY_PATH;
  }
  else if (destination == "arm9") {
    return buildPath(ROM_FILES_FOLDER, "arm9.bin");
  }
  else if (destination.startsWith("overlay")) {
    auto overlayNum = destination["overlay".length..$].to!uint;
    return buildPath(ROM_FILES_FOLDER, "overlay", format("overlay_%04d.bin", overlayNum));
  }

  return "";
}
//remember result to reduce duplicate work
alias getDestinationFile = memoize!getDestinationFileImpl;

uint getAddr(ref ProjectInfo projInfo, string destination, uint offset) {
  import std.algorithm;

  if (destination == "custom") {
    return coGameInfo(projInfo.gameVer).loadAddress + offset;
  }
  else if (destination == "arm9") {
    return 0x02000000 + offset;
  }
  else if (destination.startsWith("overlay")) {
    import std.conv : to;

    auto overlayNum = destination["overlay".length..$].to!uint;
    return projInfo.overlayOffsets[overlayNum] + offset;
  }
  else {
    assert(0, "wut");
  }
}

ubyte[] extractMachineCode(string path) {
  import elf;

  //binary files will be used as-is
  if (path.extension == ".bin") return cast(ubyte[]) read(path);

  auto codeElf = ELF.fromFile(path);

  // Concatenate all sections starting with .text, as there may be a .text section for each function.
  // @HACK: This isn't really valid, but it should suffice for the time being. We really need to actually
  // implement a full linker to make this work.
  ubyte[] result;

  foreach (section; codeElf.sections) {
    if (section.name.startsWith(".text")) {
      result ~= section.contents;
    }
  }

  // @HACK: If we don't destroy this MmFile, the file lock will still stick around, which will cause issues if we try
  //        to open it again (which is possible if a mod uses the same source file to patch multiple places).
  destroy(codeElf.m_file);

  return result;
}

string makeIncludesFile(string destFolder, string sourceFile, const(Symbol)[] symbols) {
  auto app = appender!string;

  string result = buildPath(destFolder, "includes_for_" ~ sourceFile.baseName);

  foreach (symbol; symbols) {
    switch (sourceFile.extension) {
      case ".c":
        app.formattedWrite("#define %s 0x%X\n", symbol.name, symbol.value);
        break;
      case ".d":
        app.formattedWrite("enum %s = 0x%X;\n", symbol.name, symbol.value);
        break;
      case ".s":
        app.formattedWrite(".set %s, 0x%X\n", symbol.name, symbol.value);
        break;
      default:
        break;
    }
  }

  std.file.write(result, app.data);

  return result;
}

uint customOverlayAdd(ref ProjectInfo projInfo, const(ubyte)[] data) {
  uint result = projInfo.customOverlay.currentOffset + coGameInfo(projInfo.gameVer).loadAddress;

  auto start = projInfo.customOverlay.currentOffset;
  projInfo.customOverlay.data[start..start+data.length] = data;
  projInfo.customOverlay.currentOffset += data.length;

  return result;
}

ProjectInfo getProjectInfo() {
  ProjectInfo result;

  ////
  // Overlay offsets
  ////

  auto overlayTableFile = File(buildPath(ROM_FILES_FOLDER, "arm9ovltable.bin"), "rb");

  enum OVERLAY_TABLE_ENTRY_SIZE = 0x20;
  uint curOffset = 0x4;  //second word in each entry is location the overlay will load to
  auto numOverlays = overlayTableFile.size / OVERLAY_TABLE_ENTRY_SIZE;

  result.overlayOffsets.reserve(numOverlays);

  foreach (overlay; 0..numOverlays) {
    ubyte[4] readBuffer;

    overlayTableFile.seek(curOffset);
    overlayTableFile.rawRead(readBuffer[]);

    result.overlayOffsets ~= littleEndianToNative!uint(readBuffer);

    curOffset += OVERLAY_TABLE_ENTRY_SIZE;
  }

  overlayTableFile.close();


  ////
  // Game code
  ////

  result.gameVer = extractGameVer();


  ////
  // Custom overlay file
  ////

  //Check if Following Platinum is the base
  auto coBranchCode = extractCOBranchCode(result.gameVer);
  if (result.gameVer.code == GameCode.PlatinumEng) {
    result.isFollowingPlatinum = coBranchCode == FOLLOWING_PLAT_CO_BRANCH;
  }

  result.customOverlay.alreadyInstalled = result.isFollowingPlatinum || coBranchCode == coGameInfo(result.gameVer).branchCode;

  ubyte[] coData = cast(ubyte[]) read(CUSTOM_OVERLAY_PATH);
  result.customOverlay.data = coData;

  if (coData.length < CUSTOM_OVERLAY_FILE_SIZE) {
    coData.length = CUSTOM_OVERLAY_FILE_SIZE;
  }

  size_t searchStart = result.isFollowingPlatinum ? FOLLOWING_PLAT_CO_FREE_SPACE_START : 0;
  auto nitromodsPortion = find(coData[searchStart..$], CUSTOM_OVERLAY_TAG.representation);

  uint coStart = 0;
  if (nitromodsPortion.length) {
    // Tag found, so nitromods has already been installed here
    coStart = cast(uint) (coData.length - nitromodsPortion.length);

    writefln("Found existing nitromods tag in custom overlay at %08X", coStart);

    assert((coStart & (COHeader.alignof - 1)) == 0);
    result.customOverlay.header = fromRawBytes!COHeader(coData[coStart..$][0..COHeader.sizeof]);
    result.customOverlay.currentOffset = result.customOverlay.header.nextFreeSpace;
    assert(result.customOverlay.currentOffset >= coStart + CUSTOM_OVERLAY_HEADER_SIZE);
  }
  else {
    // Search for free space
    coStart = 0;

    foreach_reverse (i; searchStart .. coData.length - CUSTOM_OVERLAY_HEADER_SIZE) {
      if (coData[i] != 0) {
        // Align to COHeader's alignof from the last zero byte. That should be enough, right?
        coStart = cast(uint) ((i+1+COHeader.alignof-1) & (~(COHeader.alignof-1)));
        break;
      }
    }

    writefln("Inserting new nitrmods tag into custom overlay at %08X", coStart);

    result.customOverlay.startOffset   = coStart;
    assert(coData.length - coStart >= CUSTOM_OVERLAY_HEADER_SIZE);
    result.customOverlay.currentOffset = coStart + CUSTOM_OVERLAY_HEADER_SIZE;

    // result.customOverlay.header initted already to default
  }

  return result;
}

void installCustomOverlay(ref ProjectInfo projInfo) {
  auto arm9File = File(buildPath(ROM_FILES_FOLDER, "arm9.bin"), "rb+");

  auto coGameData = &coGameInfo(projInfo.gameVer);

  patch(arm9File, coGameData.initSubCode, coGameData.initSubOffset);
  patch(arm9File, coGameData.branchCode,  coGameData.branchOffset);
}

GameVer extractGameVer(string baseFolder = ROM_FILES_FOLDER) {
  GameVer result;

  auto headerFile = File(buildPath(baseFolder, "header.bin"), "rb");

  headerFile.seek(0xC);
  char[4] gameCode;
  headerFile.rawRead(gameCode[]);

  switch (gameCode) {
    case "ADAE": result.code = GameCode.DiamondEng;     break;
    case "APAE": result.code = GameCode.PearlEng;       break;
    case "CPUE": result.code = GameCode.PlatinumEng;    break;
    case "IPKE": result.code = GameCode.HeartGoldEng;   break;
    case "IPGE": result.code = GameCode.SoulSilverEng;  break;
    case "ADAS": result.code = GameCode.DiamondSpa;     break;
    case "APAS": result.code = GameCode.PearlSpa;       break;
    case "CPUS": result.code = GameCode.PlatinumSpa;    break;
    case "IPKS": result.code = GameCode.HeartGoldSpa;   break;
    case "IPGS": result.code = GameCode.SoulSilverSpa;  break;
    case "ADME": result.code = GameCode.WildWorldUsa;   break;
    case "ADMP": result.code = GameCode.WildWorldPal;   break;
    default: throw new Exception("This game code is unsupported: " ~ gameCode.idup);
  }

  ubyte[1] revision;
  headerFile.seek(0x1E);
  headerFile.rawRead(revision);

  if (result.revision >= CO_GAME_INFO[result.code].length) {
    throw new Exception("This revision of the game is unsupported: " ~ gameCode.idup ~ " rev " ~ result.revision.to!string);
  }

  return result;
}

ubyte[4] extractCOBranchCode(GameVer gameVer, string baseFolder = ROM_FILES_FOLDER) {
  auto arm9File = File(buildPath(baseFolder, "arm9.bin"), "rb");

  ubyte[4] branchCode;
  arm9File.seek(coGameInfo(gameVer).branchOffset);
  arm9File.rawRead(branchCode[]);

  return branchCode;
}

ubyte[] unpackCustomOverlayNarc(GameVer gameVer, bool isFollowingPlat, string baseFolder = ROM_FILES_FOLDER) {
  auto coGameData = &coGameInfo(gameVer);

  auto narcPath = buildPath(baseFolder, "data", coGameData.hostFile);

  auto parseResult = parseNarc(&tTempStorage, cast(ubyte[]) std.file.read(narcPath));

  ushort subfileNum = isFollowingPlat ? FOLLOWING_PLAT_CO_SUBFILE : coGameData.hostSubfile;
  auto subfile = fileById(parseResult.narc, subfileNum);

  return subfile.data;
}

void packCustomOverlayNarc(ubyte[] data, GameVer gameVer, bool isFollowingPlat, string baseFolder = ROM_FILES_FOLDER) {
  auto coGameData = &coGameInfo(gameVer);

  auto narcPath = buildPath(baseFolder, "data", coGameData.hostFile);
  auto parseResult = parseNarc(&tTempStorage, cast(ubyte[]) std.file.read(narcPath));
  auto narc = parseResult.narc;

  auto subfile = fileById(narc, cast(ushort) coGameData.hostSubfile);
  subfile.data = data;

  auto outBytes = packNarc(&tTempStorage, narc);
  std.file.write(narcPath, outBytes);
}

