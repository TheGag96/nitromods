import std.stdio, std.algorithm, std.process, std.file, std.path, std.conv, std.array, std.bitmanip, std.format;

enum MODS_FOLDER               = "mods";
enum MOD_INFO_FILE             = "mod.yaml";
enum PROJECT_INFO_FILE         = "project.yaml";
enum ROM_FILES_FOLDER          = "romfiles";
enum ROM_FILES_ORIGINAL_FOLDER = "romfiles_original";
enum TEMP_FOLDER               = "tmp_pokemods";
enum CUSTOM_OVERLAY_FILE       = "overlay_custom.bin";
enum CUSTOM_OVERLAY_PATH       = buildPath(ROM_FILES_FOLDER,          "overlay", "overlay_custom.bin");
enum CUSTOM_OVERLAY_ORIG_PATH  = buildPath(ROM_FILES_ORIGINAL_FOLDER, "overlay", "overlay_custom.bin");
enum PREPROCESS_SOURCE_PATH    = buildPath(TEMP_FOLDER, "preprocessed");

enum CUSTOM_OVERLAY_ADDRESS     = 0x023C8000;
enum CUSTOM_OVERLAY_FILE_SIZE   = 1024*96;
enum CUSTOM_OVERLAY_HEADER_SIZE = 0x20;

string gDevkitproPath, gDevkitarmPath;

struct CustomOverlayGameData {
  uint initSubOffset;
  ubyte[] initSubCode;

  uint branchOffset;
  ubyte[] branchCode;

  string narcFile;
  uint narcSubfile;
}

enum GameVer {
  DiamondEng,    // ADAE
  PearlEng,      // APAE
  PlatinumEng,   // CPUE
  HeartGoldEng,  // IPKE
  SoulSilverEng, // IPGE
  DiamondSpa,    // ADAS
  PearlSpa,      // APAS
  PlatinumSpa,   // CPUS
  HeartGoldSpa,  // IPKS
  SoulSilverSpa, // IPGS
}

// Thanks to: Mikelan98, Nomura: ARM9 Expansion Subroutine (pokehacking.com/r/20041000)
static immutable CustomOverlayGameData[] CO_GAME_INFO = [
  GameVer.DiamondEng    : { 0x1064EC, hex!"FC B5 05 48 C0 46 41 21 09 22 02 4D A8 47 00 20 03 21 FC BD F1 64 00 02 00 80 3C 02", 0xC80, hex!"05 F1 34 FC", "data/weather_sys.narc", 9 },
  GameVer.PearlEng      : { 0x1064EC, hex!"FC B5 05 48 C0 46 41 21 09 22 02 4D A8 47 00 20 03 21 FC BD F1 64 00 02 00 80 3C 02", 0xC80, hex!"05 F1 34 FC", "data/weather_sys.narc", 9 },
  GameVer.PlatinumEng   : { 0x100E20, hex!"FC B5 05 48 C0 46 41 21 09 22 02 4D A8 47 00 20 03 21 FC BD A5 6A 00 02 00 80 3C 02", 0xCB4, hex!"00 F1 B4 F8", "data/weather_sys.narc", 9 },
  GameVer.HeartGoldEng  : { 0x110334, hex!"FC B5 05 48 C0 46 1C 21 00 22 02 4D A8 47 00 20 03 21 FC BD 09 75 00 02 00 80 3C 02", 0xCD0, hex!"0F F1 30 FB", "a/0/2/8",               0 },
  GameVer.SoulSilverEng : { 0x110334, hex!"FC B5 05 48 C0 46 1C 21 00 22 02 4D A8 47 00 20 03 21 FC BD 09 75 00 02 00 80 3C 02", 0xCD0, hex!"0F F1 30 FB", "a/0/2/8",               0 },
  GameVer.DiamondSpa    : { 0x10668C, hex!"FC B5 05 48 C0 46 41 21 09 22 02 4D A8 47 00 20 03 21 FC BD F1 64 00 02 00 80 3C 02", 0xC80, hex!"05 F1 04 FD", "data/weather_sys.narc", 9 },
  GameVer.PearlSpa      : { 0x10668C, hex!"FC B5 05 48 C0 46 41 21 09 22 02 4D A8 47 00 20 03 21 FC BD F1 64 00 02 00 80 3C 02", 0xC80, hex!"05 F1 04 FD", "data/weather_sys.narc", 9 },
  GameVer.PlatinumSpa   : { 0x10101C, hex!"FC B5 05 48 C0 46 41 21 09 22 02 4D A8 47 00 20 03 21 FC BD B9 6A 00 02 00 80 3C 02", 0xCB4, hex!"00 F1 B2 F9", "data/weather_sys.narc", 9 },
  GameVer.HeartGoldSpa  : { 0x110354, hex!"FC B5 05 48 C0 46 1C 21 00 22 02 4D A8 47 00 20 03 21 FC BD 09 75 00 02 00 80 3C 02", 0xCD0, hex!"0F F1 40 FB", "a/0/2/8",               0 },
  GameVer.SoulSilverSpa : { 0x110354, hex!"FC B5 05 48 C0 46 1C 21 00 22 02 4D A8 47 00 20 03 21 FC BD 09 75 00 02 00 80 3C 02", 0xCD0, hex!"0F F1 40 FB", "a/0/2/8,",              0 },
];

static immutable FOLLOWING_PLAT_CO_BRANCH = hex!"E9 F0 D0 FF";
enum FOLLOWING_PLAT_CO_FREE_SPACE_START = 0x13CD0; //subject to change if the mod is updated
enum FOLLOWING_PLAT_CO_SUBFILE          = 65;

int main(string[] args) {
  if (args.length < 2) {
    writeln("Error: idiot");
    return 1;
  }

  gDevkitproPath = environment.get("DEVKITPRO");
  gDevkitarmPath = environment.get("DEVKITARM");

  if (!gDevkitproPath || !gDevkitarmPath) {
    writeln("Error: DEVKITPRO and DEVKITARM must be in your PATH.\n",
                   "Ensure DevkitARM is installed and try again.");
    return 1;
  }

  switch (args[1]) {
    case "init":  
      if (args.length < 3) {
        writeln("Error: Need ROM filename.");
        return 1;
      }
      return init(args[2]);
    
    case "build": 
      string newRomFile = args.length < 3 ? "build.nds" : args[2];
      return build(newRomFile);

    default: 
      writeln("Error: Unrecognized command.");
      return 1;
  }
}

int init(string romFile) {
  if (exists(PROJECT_INFO_FILE)) {
    writeln("Error: Project already exists here.");
    return 1;
  }

  foreach (folder; [ROM_FILES_FOLDER, ROM_FILES_ORIGINAL_FOLDER]) {
    if (exists(folder)) {
      writeln("Error: `", folder, "` already exists. Please move/remove it and try again.");
      return 1;
    }   
  }

  mkdirRecurse(ROM_FILES_ORIGINAL_FOLDER);

  if (exists(TEMP_FOLDER)) {
    writeln("Error: `", TEMP_FOLDER, "` exists. Please move/delete it manually.");
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

    bool isFollowingPlatBranch = gameVer == GameVer.PlatinumEng && coBranchCode == FOLLOWING_PLAT_CO_BRANCH;

    if (coBranchCode == CO_GAME_INFO[gameVer].branchCode || isFollowingPlatBranch) {
      //custom overlay already exists
      auto coSubfile = unpackCustomOverlayNarc(gameVer, isFollowingPlatBranch, ROM_FILES_ORIGINAL_FOLDER);
      copy(coSubfile, CUSTOM_OVERLAY_ORIG_PATH);
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

  version (Windows) {
    execute(["xcopy", "/e", ROM_FILES_ORIGINAL_FOLDER, ROM_FILES_FOLDER]);
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
    writeln("Error: Mods folder not found!");
    return 1;
  }

  if (exists(TEMP_FOLDER)) {
    writeln("Error: `", TEMP_FOLDER, "` exists. Please move/delete it manually.");
    return 1;
  }

  mkdirRecurse(TEMP_FOLDER);
  mkdirRecurse(PREPROCESS_SOURCE_PATH);
  scope (exit) rmdirRecurse(TEMP_FOLDER);

  ProjectInfo projInfo = getProjectInfo();

  //restore original overlay
  void restoreFile(string path) {
    copy(buildPath(ROM_FILES_ORIGINAL_FOLDER, path), buildPath(ROM_FILES_FOLDER, path));
  }

  foreach (i; 0..projInfo.overlayOffsets.length) {
    restoreFile(format("overlay/overlay_%04d.bin", i));
  }

  foreach (x; ["arm9.bin", "arm7.bin", "overlay/overlay_custom.bin"]) {
    restoreFile(x);
  }

  if (!projInfo.customOverlay.alreadyInstalled) {
    installCustomOverlay(projInfo);
  }

  auto mods = findMods();
  foreach (ref mod; mods) {
    patchAllCode(mod, projInfo);
  }

  {
    auto coStart = projInfo.customOverlay.startOffset;
    projInfo.customOverlay.header.nextFreeSpace = projInfo.customOverlay.currentOffset - coStart;
    projInfo.customOverlay.data[coStart..coStart+COHeader.sizeof] = toRawBytes!COHeader(projInfo.customOverlay.header);

    std.file.write(CUSTOM_OVERLAY_PATH, projInfo.customOverlay.data);

    auto coSubfile = unpackCustomOverlayNarc(projInfo.gameVer, projInfo.isFollowingPlatinum);

    copy(CUSTOM_OVERLAY_PATH, coSubfile);

    packCustomOverlayNarc(projInfo.gameVer, projInfo.isFollowingPlatinum);
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

struct COHeader {
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

  Symbol[] symbols = [Symbol("Mod_Free_RAM", CUSTOM_OVERLAY_ADDRESS + projInfo.customOverlay.currentOffset)];

  projInfo.customOverlay.currentOffset += mod.freeRAM;

  foreach (ref codePatch; mod.code) {
    string sourceFile = buildPath(mod.modPath, "code", codePatch.file);

    if ([".s", ".asm", ".c"].canFind(codePatch.file.extension)) {
      sourceFile = preprocessSource(preprocessCodePath, sourceFile, symbols);
    }

    string compiledPath = compile(mod, sourceFile, preprocessCodePath);

    uint codeAddr;

    if (codePatch.destination == "custom" && codePatch.addNewCode) {
      //handle new code
      codeAddr = customOverlayAdd(projInfo, extractMachineCode(compiledPath));
      debug writefln("Patched new code %s at %X", codePatch.file.baseName, codeAddr);
    }
    else {
      codeAddr = getAddr(projInfo, codePatch.destination, codePatch.offset);
      patch(getDestinationFile(codePatch.destination), extractMachineCode(compiledPath), codePatch.offset);
      debug writefln("Patched existing code with %s at %X", codePatch.file.baseName, codeAddr);
    }

    foreach (ref hijack; codePatch.hijacks) {
      uint blInstruction = makeBl(codeAddr - getAddr(projInfo, hijack.destination, hijack.offset));

      patch(getDestinationFile(hijack.destination), nativeToLittleEndian(blInstruction)[], hijack.offset);
      debug writefln("  Writing hijack to %s: %X to %X", hijack.destination, getAddr(projInfo, hijack.destination, hijack.offset), codeAddr);
    }

    symbols ~= Symbol(codePatch.name, codeAddr);
  }
}

void patch(File destFile, const(ubyte)[] data, uint offset) {
  destFile.seek(offset);
  destFile.rawWrite(data);
}

void patch(string destPath, const(ubyte)[] data, uint offset) {
  auto file = File(destPath, "rb+");
  patch(file, data, offset);
}

string compile(ref Mod mod, string filename, string outDir) {
  string program;
  string[] options;

  switch (filename.extension) {
    case ".bin":
      //don't compile binary files - just returned them to be patched as-is
      return filename;

    case ".c":
      program = buildPath(gDevkitarmPath, "bin/arm-none-eabi-gcc");
      options = ["-Wall", "-Os", "-march=armv5te", "-mtune=arm946e-s", "-fomit-frame-pointer", "-ffast-math", 
                 "-mthumb", "-mthumb-interwork", "-I/opt/devkitpro/libnds/include", "-DARM9"];
      break;

    case ".s":
    case ".asm":
      program = buildPath(gDevkitarmPath, "bin/arm-none-eabi-as");
      options = ["-march=armv5te", "-mthumb", "-mthumb-interwork"];
      break;

    default: break;
  }

  string outPath = buildPath(outDir, filename.baseName.setExtension(".o"));

  auto cmdResult = execute(
    [program] ~ options ~ ["-c", filename, "-o", outPath]
  );

  return outPath;
}

string getDestinationFile(string destination) {
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

uint getAddr(ref ProjectInfo projInfo, string destination, uint offset) {
  import std.algorithm;

  if (destination == "custom") {
    return CUSTOM_OVERLAY_ADDRESS + offset;
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
  import std.range : chunks;

  //binary files will be used as-is
  if (path.extension == ".bin") return cast(ubyte[]) read(path);

  string objcopyPath    = buildPath(gDevkitarmPath, "bin/arm-none-eabi-objcopy");
  string tempOutputPath = path.setExtension(".bin");

  auto cmdResult = execute([objcopyPath, "-O", "binary", "-j", ".text", path, tempOutputPath]);

  return cast(ubyte[]) read(tempOutputPath);
}

string preprocessSource(string destFolder, string sourceFile, const(Symbol)[] symbols) {
  auto app = appender!string;

  string result = buildPath(destFolder, sourceFile.baseName);

  bool isCSource = sourceFile.extension == ".c";

  foreach (symbol; symbols) {
    if (isCSource) {
      app.formattedWrite("#define %s 0x%X\n", symbol.name, symbol.value);
    }
    else {
      app.formattedWrite(".set %s, 0x%X\n", symbol.name, symbol.value);
    }
  }

  app.put(readText(sourceFile));

  std.file.write(result, app.data);

  return result;
}

uint customOverlayAdd(ref ProjectInfo projInfo, const(ubyte)[] data) {
  uint result = projInfo.customOverlay.currentOffset + CUSTOM_OVERLAY_ADDRESS;

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
  if (result.gameVer == GameVer.PlatinumEng) {
    result.isFollowingPlatinum = coBranchCode == FOLLOWING_PLAT_CO_BRANCH;
  }

  result.customOverlay.alreadyInstalled = result.isFollowingPlatinum || coBranchCode == CO_GAME_INFO[result.gameVer].branchCode;
  result.customOverlay.data = cast(ubyte[]) read(CUSTOM_OVERLAY_PATH);

  if (result.customOverlay.data.length < CUSTOM_OVERLAY_FILE_SIZE) {
    result.customOverlay.data.length = CUSTOM_OVERLAY_FILE_SIZE;
  }

  if (result.isFollowingPlatinum) {
    result.customOverlay.startOffset = FOLLOWING_PLAT_CO_FREE_SPACE_START;
  }
  else {
    result.customOverlay.startOffset = 0;
  }

  result.customOverlay.currentOffset = result.customOverlay.startOffset + CUSTOM_OVERLAY_HEADER_SIZE;

  auto coStart = result.customOverlay.startOffset;
  result.customOverlay.header = fromRawBytes!COHeader(result.customOverlay.data[coStart..$][0..COHeader.sizeof]);

  return result;
}

void installCustomOverlay(ref ProjectInfo projInfo) {
  auto arm9File = File(buildPath(ROM_FILES_FOLDER, "arm9.bin"), "rb+");

  auto coGameData = &CO_GAME_INFO[projInfo.gameVer];

  patch(arm9File, coGameData.initSubCode, coGameData.initSubOffset);
  patch(arm9File, coGameData.branchCode,  coGameData.branchOffset);
}

GameVer extractGameVer(string baseFolder = ROM_FILES_FOLDER) {
  auto headerFile = File(buildPath(baseFolder, "header.bin"), "rb");

  headerFile.seek(0xC);
  char[4] gameCode;
  headerFile.rawRead(gameCode[]);

  switch (gameCode) {
    case "ADAE": return GameVer.DiamondEng;
    case "APAE": return GameVer.PearlEng;
    case "CPUE": return GameVer.PlatinumEng;
    case "IPKE": return GameVer.HeartGoldEng;
    case "IPGE": return GameVer.SoulSilverEng;
    case "ADAS": return GameVer.DiamondSpa;
    case "APAS": return GameVer.PearlSpa;
    case "CPUS": return GameVer.PlatinumSpa;
    case "IPKS": return GameVer.HeartGoldSpa;
    case "IPGS": return GameVer.SoulSilverSpa;
    default: throw new Exception("Game version unsupported!");
  }
}

ubyte[4] extractCOBranchCode(GameVer gameVer, string baseFolder = ROM_FILES_FOLDER) {
  auto arm9File = File(buildPath(baseFolder, "arm9.bin"), "rb");

  ubyte[4] branchCode;
  arm9File.seek(CO_GAME_INFO[gameVer].branchOffset);
  arm9File.rawRead(branchCode[]);

  return branchCode;
}

string unpackCustomOverlayNarc(GameVer gameVer, bool isFollowingPlat, string baseFolder = ROM_FILES_FOLDER) {
  auto knarcPath = buildPath(thisExePath.dirName, "knarc");

  auto coGameData = &CO_GAME_INFO[gameVer];

  auto narcPath    = buildPath(baseFolder, "data", coGameData.narcFile);
  auto extractPath = buildPath(TEMP_FOLDER, "weather_sys");

  mkdir(extractPath);

  auto knarcResult = execute( [
    knarcPath, "-d", extractPath, "-u", narcPath,
  ]);

  auto subfileNum = isFollowingPlat ? FOLLOWING_PLAT_CO_SUBFILE : coGameData.narcSubfile;

  //knarc will unfortunatey not spit out predictable filenames. have to search the directory ourselves
  auto re = regex(`weather_sys_[0]*` ~ subfileNum.to!string);
  string subfile = dirEntries(extractPath, SpanMode.shallow).filter!(x => !matchFirst(x.name, re).empty).front.name;

  return subfile;
}

void packCustomOverlayNarc(GameVer gameVer, bool isFollowingPlat, string baseFolder = ROM_FILES_FOLDER) {
  auto knarcPath = buildPath(thisExePath.dirName, "knarc");

  auto coGameData = &CO_GAME_INFO[gameVer];

  auto narcPath    = buildPath(baseFolder, "data", coGameData.narcFile);
  auto extractPath = buildPath(TEMP_FOLDER, "weather_sys");

  auto knarcResult = execute( [
    knarcPath, "-d", extractPath, "-p", narcPath,
  ]);
}

uint makeBl(int Value) {
  // Taken from: https://github.com/keystone-engine/keystone/blob/e1547852d9accb9460573eb156fc81645b8e1871/llvm/lib/Target/ARM/MCTargetDesc/ARMAsmBackend.cpp#L497-L523

  // The value doesn't encode the low bit (always zero) and is offset by
  // four. The 32-bit immediate value is encoded as
  //   imm32 = SignExtend(S:I1:I2:imm10:imm11:0)
  // where I1 = NOT(J1 ^ S) and I2 = NOT(J2 ^ S).
  // The value is encoded into disjoint bit positions in the destination
  // opcode. x = unchanged, I = immediate value bit, S = sign extension bit,
  // J = either J1 or J2 bit
  //
  //   BL:  xxxxxSIIIIIIIIII xxJxJIIIIIIIIIII
  //
  // Note that the halfwords are stored high first, low second; so we need
  // to transpose the fixup value here to map properly.
  uint offset = (Value - 4) >> 1;
  uint signBit = (offset & 0x800000) >> 23;
  uint I1Bit = (offset & 0x400000) >> 22;
  uint J1Bit = (I1Bit ^ 0x1) ^ signBit;
  uint I2Bit = (offset & 0x200000) >> 21;
  uint J2Bit = (I2Bit ^ 0x1) ^ signBit;
  uint imm10Bits = (offset & 0x1FF800) >> 11;
  uint imm11Bits = (offset & 0x000007FF);

  uint FirstHalf = ((cast(ushort)signBit << 10) | cast(ushort)imm10Bits);
  uint SecondHalf = ((cast(ushort)J1Bit << 13) | (cast(ushort)J2Bit << 11) |
                         cast(ushort)imm11Bits);

  FirstHalf  |= 0b1111000000000000;
  SecondHalf |= 0b1111100000000000;

  return FirstHalf | (SecondHalf << 16);
}

enum hex(string s) = () {
  import std.algorithm : filter, map;
  import std.array     : array;
  import std.conv      : to;
  import std.range     : chunks;
  import std.uni       : isSpace;

  return s
    .filter!(x => !isSpace(x))
    .chunks(2)
    //.map!((x) { enforce(x.length == 2); return x; })
    .map!(x => x.to!ubyte(16))
    .array;
}();

@trusted T fromRawBytes(T)(const ref ubyte[T.sizeof] bytes) if (safeAllBitPatterns!T) {
  T result = *(cast(const(T)*) bytes.ptr);

  version (BigEndian) {
    swapEndianAllMembers(result);
  }

  return result;
}

@trusted ubyte[T.sizeof] toRawBytes(T)(const ref T thing) if (safeAllBitPatterns!T) {
  version (BigEndian) {
    T tmp = thing;
    swapEndianAllMembers(tmp);
    return (cast(const(ubyte)*) &tmp)[0..T.sizeof];
  }
  else {
    return (cast(const(ubyte)*) &thing)[0..T.sizeof];
  }
}

//don't use std.traits' version because it makes char[] tie in with autodecode
alias ElementType(T : T[]) = T;

enum safeAllBitPatterns(T) = () {
  import std.traits : isArray, isStaticArray;

  bool result = true;

  static if (is(T == struct) || is(T == union)) {
    static foreach (member; T.tupleof) {{
      result = result && safeAllBitPatterns!(typeof(member));
    }}
  }
  else static if (isStaticArray!T) {
    result = safeAllBitPatterns!(ElementType!T);
  }
  else static if (is(T U : U*) || (isArray!T && !isStaticArray!T) || is(T : bool)) {
    result = false;
  }

  return result;
}();

void swapEndianAllMembers(T)(ref T thing) {
  import std.traits : isArray, isStaticArray;
  import std.bitmanip : swapEndian;

  static assert (!is(T == union), "Don't know how to handle unions, sorry");

  foreach (member; thing.tupleof) {
    alias M = typeof(member);
    pragma(msg, M);

    static assert (!is(M == union), "Don't know how to handle unions, sorry");
    static if (is(M == struct)) {
      swapEndianAllMembers(member);
    }
    else static if (isArray!M && ElementType!M.sizeof > 1) {
      foreach (ref elem; member) {
        elem = swapEndian(elem);
      }
    }
    else static if (M.sizeof > 1) {
      member = swapEndian(member);
    }
  }
}
