import std.stdio, std.algorithm, std.process, std.file, std.path, std.conv, std.array, std.bitmanip, std.format;

enum MODS_FOLDER               = "mods";
enum MOD_INFO_FILE             = "mod.yaml";
enum PROJECT_INFO_FILE         = "project.yaml";
enum ROM_FILES_FOLDER          = "romfiles";
enum ROM_FILES_ORIGINAL_FOLDER = "romfiles_original";
enum TEMP_FOLDER               = "tmp_build";
enum CUSTOM_OVERLAY_FILE       = "overlay_custom.bin";
enum CUSTOM_OVERLAY_PATH       = buildPath(ROM_FILES_FOLDER,          "overlay", "overlay_custom.bin");
enum CUSTOM_OVERLAY_ORIG_PATH  = buildPath(ROM_FILES_ORIGINAL_FOLDER, "overlay", "overlay_custom.bin");
enum PREPROCESS_SOURCE_PATH    = buildPath(TEMP_FOLDER, "preprocessed");

enum CUSTOM_OVERLAY_ADDRESS     = 0x023C8000;
enum CUSTOM_OVERLAY_FILE_SIZE   = 1024*88;
enum CUSTOM_OVERLAY_HEADER_SIZE = 0x20;

string gDevkitproPath, gDevkitarmPath;

int main(string[] args) {
  if (args.length < 2) {
    stderr.writeln("Error: idiot");
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
        stderr.writeln("Error: Need ROM filename.");
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
    stderr.writeln("Error: Project already exists here.");
    return 1;
  }

  mkdirRecurse(MODS_FOLDER);

  foreach (folder; [ROM_FILES_FOLDER, ROM_FILES_ORIGINAL_FOLDER]) {
    if (exists(folder)) {
      stderr.writeln("Error: `", folder, "` already exists. Please move/remove it and try again.");
      return 1;
    }   
  }

  mkdirRecurse(ROM_FILES_ORIGINAL_FOLDER);

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
    auto customOverlayFile = File(CUSTOM_OVERLAY_ORIG_PATH, "wb");

    uint[1] zero;
    foreach (i; 0..CUSTOM_OVERLAY_FILE_SIZE/4) {
      customOverlayFile.rawWrite(zero[]);
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
    stderr.writeln("Error: Mods folder not found!");
    return 1;
  }

  if (exists(TEMP_FOLDER)) {
    stderr.writeln("Error: `", TEMP_FOLDER, "` exists. Please move/delete it manually.");
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

  installCustomOverlay();

  auto mods = findMods();
  foreach (ref mod; mods) {
    patchAllCode(mod, projInfo);
  }

  {
    projInfo.customOverlayData[0..4] = nativeToLittleEndian!uint(projInfo.customOverlayCurrentOffset);

    std.file.write(CUSTOM_OVERLAY_PATH, projInfo.customOverlayData);

    auto narchivePath = buildPath(thisExePath.dirName, "Narchive.exe");

    version (Windows) {
      auto narchiveCmd = [narchivePath];
    }
    else {
      auto narchiveCmd = ["wine", narchivePath];
    }

    auto narcPath    = buildPath(ROM_FILES_FOLDER, "data", "data", "weather_sys.narc");
    auto extractPath = buildPath(TEMP_FOLDER, "weather_sys");

    mkdir(extractPath);

    writeln("Extracting...");

    auto narchiveResult = execute( narchiveCmd ~ [
      "extract", narcPath,
      "-o", extractPath,
    ]);

    copy(CUSTOM_OVERLAY_PATH, buildPath(extractPath, "weather_sys_09"));

    writeln("Creating...");
    narchiveResult = execute( narchiveCmd ~ [
      "create", narcPath, extractPath,
    ]);
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

    struct Hijack {
      string destination;
      uint offset;
    }

    Hijack[] hijacks;
  }

  CodePatch[] code;
}

struct ProjectInfo {
  uint[] overlayOffsets;

  ubyte[] customOverlayData;
  uint customOverlayCurrentOffset;
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
        codePatch.offset = 0; //auto
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

  Symbol[] symbols = [Symbol("Mod_Free_RAM", CUSTOM_OVERLAY_ADDRESS + projInfo.customOverlayCurrentOffset)];

  projInfo.customOverlayCurrentOffset += mod.freeRAM;

  foreach (ref codePatch; mod.code) {
    string sourceFile = buildPath(mod.modPath, "code", codePatch.file);

    if ([".s", ".asm", ".c"].canFind(codePatch.file.extension)) {
      sourceFile = preprocessSource(preprocessCodePath, sourceFile, symbols);
    }

    string compiledPath = compile(mod, sourceFile, preprocessCodePath);

    uint codeAddr;

    if (codePatch.destination == "custom") {
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

void patch(File destFile, ubyte[] data, uint offset) {
  destFile.seek(offset);
  destFile.rawWrite(data);
}

void patch(string destPath, ubyte[] data, uint offset) {
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

string preprocessSource(string destFolder, string sourceFile, Symbol[] symbols) {
  //TODO: actually do something smart here

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

uint customOverlayAdd(ref ProjectInfo projInfo, ubyte[] data) {
  uint result = projInfo.customOverlayCurrentOffset + CUSTOM_OVERLAY_ADDRESS;

  auto start = projInfo.customOverlayCurrentOffset;
  projInfo.customOverlayData[start..start+data.length] = data;
  projInfo.customOverlayCurrentOffset += data.length;

  return result;
}

ProjectInfo getProjectInfo() {
  ProjectInfo result;

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

  result.customOverlayData = cast(ubyte[]) read(CUSTOM_OVERLAY_PATH);

  if (result.customOverlayData.length < CUSTOM_OVERLAY_FILE_SIZE) {
    result.customOverlayData.length = CUSTOM_OVERLAY_FILE_SIZE;
  }

  result.customOverlayCurrentOffset = CUSTOM_OVERLAY_HEADER_SIZE;

  return result;
}

void installCustomOverlay() {
  // Thanks to: Mikelan98, Nomura: ARM9 Expansion Subroutine (pokehacking.com/r/20041000)

  //TODO: Support other ROMS

  auto arm9File = File(buildPath(ROM_FILES_FOLDER, "arm9.bin"), "rb+");

  patch(arm9File, [0xFC, 0xB5, 0x05, 0x48, 0xC0, 0x46, 0x41, 0x21, 0x09, 0x22, 0x02, 0x4D, 0xA8, 0x47, 0x00, 0x20, 0x03, 0x21, 0xFC, 0xBD, 0xA5, 0x6A, 0x00, 0x02, 0x00, 0x80, 0x3C, 0x02], 0x100E20);
  patch(arm9File, [0x00, 0xF1, 0xB4, 0xF8], 0xCB4);
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


