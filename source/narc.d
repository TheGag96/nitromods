module nitromods.narc;

import nitromods.arena, nitromods.util;
import std.bitmanip;

enum NarcFileType : byte {
  narc,
  //headerless_narc,
  nds,
}

// Thank you Mr. No$ man!!
// http://problemkaputt.de/gbatek-ds-cartridge-nitrorom-and-nitroarc-file-systems.htm
struct NarcHeader {
  char[4] name = "NARC";
  ushort byteOrder = 0xFFFE;
  ushort ver = 0x0100;
  uint fileSize;  // from "NARC" ID to end of file
  ushort chunkSize = 0x0010;
  ushort numChunks = 0x0003;
}

enum UnitCode : ubyte {
  nds     = 0,
  nds_dsi = 1,
  dsi     = 2,
}

enum Region : ubyte {
  normal      = 0,
  south_korea = 0x40,
  china       = 0x80,
}

struct NdsHeader {
  char[12] gameTitle;          // 000h    12    Game Title  (Uppercase ASCII, padded with 00h)
  char[4] gameCode;            // 00Ch    4     Gamecode    (Uppercase ASCII, NTR-<code>)        (0=homebrew)
  char[2] makerCode;           // 010h    2     Makercode   (Uppercase ASCII, eg. "01"=Nintendo) (0=homebrew)
  UnitCode unitCode;           // 012h    1     Unitcode    (00h=NDS, 02h=NDS+DSi, 03h=DSi) (bit1=DSi)
  ubyte encryptionSeedSelect;  // 013h    1     Encryption Seed Select (00..07h, usually 00h)
  ubyte deviceCapacity;        // 014h    1     Devicecapacity         (Chipsize = 128KB SHL nn) (eg. 7 = 16MB)
  ubyte[7] reserved1;          // 015h    7     Reserved    (zero filled)
  ubyte reserved2;             // 01Ch    1     Reserved    (zero)                      (except, used on DSi)
  Region region;               // 01Dh    1     NDS Region  (00h=Normal, 80h=China, 40h=Korea) (other on DSi)
  ubyte romVersion;               // 01Eh    1     ROM Version (usually 00h)
  ubyte autoStart;             // 01Fh    1     Autostart (Bit2: Skip "Press Button" after Health and Safety)
                               // (Also skips bootmenu, even in Manual mode & even Start pressed)
  uint arm9RomOffset;          // 020h    4     ARM9 rom_offset    (4000h and up, align 1000h)
  uint arm9EntryAddress;       // 024h    4     ARM9 entry_address (2000000h..23BFE00h)
  uint arm9RamAddress;         // 028h    4     ARM9 ram_address   (2000000h..23BFE00h)
  uint arm9Size;               // 02Ch    4     ARM9 size          (max 3BFE00h) (3839.5KB)
  uint arm7RomOffset;          // 030h    4     ARM7 rom_offset    (8000h and up)
  uint arm7EntryAddress;       // 034h    4     ARM7 entry_address (2000000h..23BFE00h, or 37F8000h..3807E00h)
  uint arm7RamAddress;         // 038h    4     ARM7 ram_address   (2000000h..23BFE00h, or 37F8000h..3807E00h)
  uint arm7Size;               // 03Ch    4     ARM7 size          (max 3BFE00h, or FE00h) (3839.5KB, 63.5KB)
  uint fntOffset;              // 040h    4     File Name Table (FNT) offset
  uint fntSize;                // 044h    4     File Name Table (FNT) size
  uint fatOffset;              // 048h    4     File Allocation Table (FAT) offset
  uint fatSize;                // 04Ch    4     File Allocation Table (FAT) size
  uint arm9OverlayOffset;      // 050h    4     File ARM9 overlay_offset
  uint arm9OverlaySize;        // 054h    4     File ARM9 overlay_size
  uint arm7OverlayOffset;      // 058h    4     File ARM7 overlay_offset
  uint arm7OverlaySize;        // 05Ch    4     File ARM7 overlay_size
  uint normalCommandsSetting;  // 060h    4     Port 40001A4h setting for normal commands (usually 00586000h)
  uint key1CommandsSetting;    // 064h    4     Port 40001A4h setting for KEY1 commands   (usually 001808F8h)
  uint iconTitleOffset;        // 068h    4     Icon/Title offset (0=None) (8000h and up)
  ushort secureAreaChecksum;   // 06Ch    2     Secure Area Checksum, CRC-16 of [[020h]..00007FFFh]
  uint secureAreaDelay;        // 06Eh    2     Secure Area Delay (in 131kHz units) (051Eh=10ms or 0D7Eh=26ms)
  uint arm9AutoLoadListAddr;   // 070h    4     ARM9 Auto Load List Hook RAM Address (?) ;\endaddr of auto-load
  uint arm7AutoLoadListAddr;   // 074h    4     ARM7 Auto Load List Hook RAM Address (?) ;/functions
  ubyte[8] secureAreaDisable;  // 078h    8     Secure Area Disable (by encrypted "NmMdOnly") (usually zero)
  uint totalUsedRomSize;       // 080h    4     Total Used ROM size (remaining/unused bytes usually FFh-padded)
  uint romHeaderSize;          // 084h    4     ROM Header Size (4000h)
  uint unk1;                   // 088h    4     Unknown, some rom_offset, or zero? (DSi: slightly different)
  ubyte[8] reserved3;          // 08Ch    8     Reserved (zero filled; except, [88h..93h] used on DSi)
  ushort nandEndOfRom;         // 094h    2     NAND end of ROM area  ;\in 20000h-byte units (DSi: 80000h-byte)
  ushort nandStartofRw;        // 096h    2     NAND start of RW area ;/usually both same address (0=None)
  ubyte[24] reserved4;         // 098h    18h   Reserved (zero filled)
  ubyte[16] reserved5;         // 0B0h    10h   Reserved (zero filled; or "DoNotZeroFillMem"=unlaunch fastboot)
  ubyte[0x9C] nintendoLogo;    // 0C0h    9Ch   Nintendo Logo (compressed bitmap, same as in GBA Headers)
  ushort nintendoLogoChecksum; // 15Ch    2     Nintendo Logo Checksum, CRC-16 of [0C0h-15Bh], fixed CF56h
  ushort headerChecksum;       // 15Eh    2     Header Checksum, CRC-16 of [000h-15Dh]
  uint debugRomOffset;         // 160h    4     Debug rom_offset   (0=none) (8000h and up)       ;only if debug
  uint debugSize;              // 164h    4     Debug size         (0=none) (max 3BFE00h)        ;version with
  uint debugRamAddr;           // 168h    4     Debug ram_address  (0=none) (2400000h..27BFE00h) ;SIO and 8MB
  uint reserved6;              // 16Ch    4     Reserved (zero filled) (transferred, and stored, but not used)
  ubyte[0x90] reserved7;       // 170h    90h   Reserved (zero filled) (transferred, but not stored in RAM)
  ubyte[0xE00] reserved8;      // 200h    E00h  Reserved (zero filled) (usually not transferred)

  bool isNull() {
    return &this == null || &this == &gNdsHeader;
  }
}

struct OverlayTableEntry {
  uint overlayId;       // 00h  4    Overlay ID
  uint ramAddress;      // 04h  4    RAM Address ;Point at which to load
  uint ramSize;         // 08h  4    RAM Size    ;Amount to load
  uint bssSize;         // 0Ch  4    BSS Size    ;Size of BSS data region
  uint staticInitStart; // 10h  4    Static initialiser start address
  uint staticInitEnd;   // 14h  4    Static initialiser end address
  uint fileId;          // 18h  4    File ID  (0000h..EFFFh)
  uint reserved;        // 1Ch  4    Reserved (zero)
}

__gshared const NdsHeader gNdsHeader = NdsHeader.init;

struct ChunkHeader {
  char[4] name;
  uint size;
}

struct BtafChunkExtra {
  ushort numFiles;
  ushort reserved;  // I wonder if this is really just a 4-byte field?
}

struct FatEntry {
  uint start; // originated at IMG base
  uint end;   // Start + Len
}

struct FntMainTableEntry {
  uint subTableOffset; // originated at FNT base
  ushort subTableFirstFile;
  ushort numDirsOrParent;  // In the first entry, it means total number of directories; in subsequent, it means parent ID
}

enum Chunk {
  fat,  // File Allocation Table
  fnt,  // File Name Table
  img,  // File Data
}

immutable char[4][Chunk.max+1] CHUNK_TAGS = [
  Chunk.fat : "BTAF",
  Chunk.fnt : "BTNF",
  Chunk.img : "GMIF",
];

struct NarcParseResult {
  Narc* narc;
  NarcError* errors;
  Severity highestSeverity;
}

enum Severity {
  debugging,
  info,
  warning,
  error,
}

struct NarcError {
  NarcError* next;
  uint pos;
  Severity severity;
  const(char)[] message;
}

void addError(Arena* arena, NarcParseResult* result, uint pos, Severity severity, const(char)[] message) {
  auto newOne     = push!NarcError(arena);
  newOne.pos      = pos;
  newOne.severity = severity;
  newOne.message  = message;

  if (severity > result.highestSeverity) {
    result.highestSeverity = severity;
  }

  if (result.errors == null) {
    result.errors = newOne;
  }
  else {
    result.errors.next = newOne;
  }
}

struct NarcFile {
  NarcFile* parent, first, last, next, prev;
  ushort id;
  uint offset;
  char[] name;
  ubyte[] data;

  bool isNull() {
    return &this == null || &this == &gNullFile;
  }
}

bool isDirectory(in NarcFile file) {
  return (file.id & 0xF000) != 0;
}

__gshared const NarcFile gNullFile = {
  first: cast(NarcFile*) &gNullFile, last: cast(NarcFile*) &gNullFile, next: cast(NarcFile*) &gNullFile, prev: cast(NarcFile*) &gNullFile, parent: cast(NarcFile*) &gNullFile,
};

struct Narc {
  NarcFile* root;
  NarcFile[] files, directories;
  NarcFileType fileType;

  // Fields relevant only for NDS ROMs
  NdsHeader* ndsHeader;
  OverlayTableEntry[] overlayTableArm9, overlayTableArm7;
  ubyte[][] overlaysArm9, overlaysArm7;
  ubyte[] arm9, arm7;
}

pragma(inline, true)
private T* consume(T)(ubyte[] bytes, uint* index) {
  if (bytes.length - *index >= T.sizeof) {
    auto result = &bytes[*index];
    *index += T.sizeof;
    return cast(T*) result;
  }
  else {
    return null;
  }
}

NarcParseResult parseNarc(Arena* arena, ubyte[] bytes, NarcFileType fileType = NarcFileType.narc) {
  NarcParseResult result;

  result.narc = push!Narc(arena);
  result.narc.ndsHeader = cast(NdsHeader*) &gNdsHeader;
  result.narc.fileType  = fileType;

  uint index = 0;

  uint fatBase = 0, fntBase = 0, imgBase = 0;
  uint fatSize = 0, fntSize = 0, imgSize = 0;
  final switch (fileType) {
    case NarcFileType.narc:
      auto header = consume!NarcHeader(bytes, &index);
      if (!header) {
        addError(
          arena, &result, index, Severity.error,
          "The file is too small to even contain a NARC header."
        );
        return result;
      }

      if (header.name != "NARC") {
        addError(
          arena, &result, index, Severity.error,
          "This doesn't look like a NARC file - didn't see the 'NARC' tag at the beginning."
        );
        return result;
      }

      if (header.numChunks != 3) {
        addError(
          arena, &result, index, Severity.warning,
          aprintf(arena, "There should be 3 chunks reported, not %u.", header.numChunks)
        );
      }
      break;

    case NarcFileType.nds:
      result.narc.ndsHeader = push!NdsHeader(arena);

      auto ndsHeader = consume!NdsHeader(bytes, &index);
      if (!ndsHeader) {
        addError(
          arena, &result, index, Severity.error,
          "The file is too small to even contain an NDS ROM header."
        );
        return result;
      }
      result.narc.ndsHeader = ndsHeader;

      // The ROM header just gives these locations and sizes to us - we don't need to parse chunks in-order to find
      // them out, like with NARC files.
      fntBase = ndsHeader.fntOffset;
      fatBase = ndsHeader.fatOffset;
      imgBase = 0;

      fntSize = ndsHeader.fntSize;
      fatSize = ndsHeader.fatSize;
      imgSize = cast(uint) bytes.length;

      bool boundsCheckArray(const(char)* sectionName, uint fieldIndex, size_t start, size_t length) {
        if (start + length > bytes.length) {
          addError(
            arena, &result, fieldIndex, Severity.error,
            aprintf(arena, "The %s breaks past the bounds of the file. File size = %zu, section range = [%zu, %zu)", sectionName, bytes.length, start, start + length)
          );

          return false;
        }

        return true;
      }

      if (!boundsCheckArray("FNT",                ndsHeader.fntOffset.offsetof,         ndsHeader.fntOffset, ndsHeader.fntSize))                 return result;
      if (!boundsCheckArray("FAT",                ndsHeader.fatOffset.offsetof,         ndsHeader.fatOffset, ndsHeader.fatSize))                 return result;
      if (!boundsCheckArray("ARM9 overlay table", ndsHeader.arm9OverlayOffset.offsetof, ndsHeader.arm9OverlayOffset, ndsHeader.arm9OverlaySize)) return result;
      if (!boundsCheckArray("ARM7 overlay table", ndsHeader.arm7OverlayOffset.offsetof, ndsHeader.arm7OverlayOffset, ndsHeader.arm7OverlaySize)) return result;
      if (!boundsCheckArray("ARM9 binary",        ndsHeader.arm9RomOffset.offsetof,     ndsHeader.arm9RomOffset, ndsHeader.arm9Size))            return result;
      if (!boundsCheckArray("ARM7 binary",        ndsHeader.arm7RomOffset.offsetof,     ndsHeader.arm7RomOffset, ndsHeader.arm7Size))            return result;

      if (ndsHeader.arm9OverlaySize % OverlayTableEntry.sizeof != 0) {
        addError(
          arena, &result, ndsHeader.arm9OverlaySize.offsetof, Severity.error,
          aprintf(arena, "The ARM9 overlay table should be a multiple of the entry size (%zu bytes)", OverlayTableEntry.sizeof)
        );
        return result;
      }

      if (ndsHeader.arm7OverlaySize % OverlayTableEntry.sizeof != 0) {
        addError(
          arena, &result, ndsHeader.arm7OverlaySize.offsetof, Severity.error,
          aprintf(arena, "The ARM7 overlay table should be a multiple of the entry size (%zu bytes)", OverlayTableEntry.sizeof)
        );
        return result;
      }

      OverlayTableEntry[] overlayTableArm9 = cast(OverlayTableEntry[]) bytes[ndsHeader.arm9OverlayOffset..ndsHeader.arm9OverlayOffset+ndsHeader.arm9OverlaySize];
      OverlayTableEntry[] overlayTableArm7 = cast(OverlayTableEntry[]) bytes[ndsHeader.arm7OverlayOffset..ndsHeader.arm7OverlayOffset+ndsHeader.arm7OverlaySize];

      result.narc.overlayTableArm9 = overlayTableArm9;
      result.narc.overlayTableArm7 = overlayTableArm7;

      result.narc.overlaysArm9 = pushArray!(ubyte[])(arena, overlayTableArm9.length);
      result.narc.overlaysArm7 = pushArray!(ubyte[])(arena, overlayTableArm7.length);

      result.narc.arm9 = bytes[ndsHeader.arm9RomOffset..ndsHeader.arm9RomOffset+ndsHeader.arm9Size];
      result.narc.arm7 = bytes[ndsHeader.arm7RomOffset..ndsHeader.arm7RomOffset+ndsHeader.arm7Size];

      break;
  }


  // Chunks immediately follow

  // Parse FAT

  ChunkHeader* fatChunkHeader;
  if (fileType != NarcFileType.nds) {
    uint fatHeaderStart = index;
    fatChunkHeader = consume!ChunkHeader(bytes, &index);
    if (!fatChunkHeader) {
      addError(
        arena, &result, index, Severity.error,
        "Unexpected end of file looking for FAT chunk header."
      );
      return result;
    }

    if (fatChunkHeader.name != CHUNK_TAGS[Chunk.fat]) {
      addError(
        arena, &result, cast(uint) (fatHeaderStart + fatChunkHeader.name.offsetof), Severity.error,
        "Expected the 'BTAF' tag to begin the FAT chunk."
      );
      return result;
    }

    if (fatChunkHeader.size > bytes.length - index - fatChunkHeader.name.sizeof) {
      addError(
        arena, &result, cast(uint) (fatHeaderStart + fatChunkHeader.size.offsetof), Severity.error,
        aprintf(arena, "FAT chunk size %u is too big to fit into this file.", fatChunkHeader.size)
      );
      return result;
    }

    auto fatChunkExtra = consume!BtafChunkExtra(bytes, &index);
    if (!fatChunkExtra) {
      addError(
        arena, &result, index, Severity.error,
        "Unexpected end of file looking for second part of FAT chunk header."
      );
      return result;
    }

    import std.stdio;
    fatBase = index;

    // This should be safe since we've bounds checked above.
    fatSize = cast(uint) (fatChunkHeader.size - fatChunkHeader.name.sizeof - fatChunkHeader.size.sizeof);
  }

  FatEntry[] fatEntries = (cast(FatEntry*) &bytes[fatBase])[0 .. fatSize / FatEntry.sizeof];

  // Parse FNT

  if (fileType != NarcFileType.nds) {
    index = cast(uint) (fatBase + fatChunkHeader.size - ChunkHeader.sizeof - BtafChunkExtra.sizeof);

    uint fntHeaderStart = index;
    auto fntChunkHeader = consume!ChunkHeader(bytes, &index);
    if (!fntChunkHeader) {
      addError(
        arena, &result, index, Severity.error,
        "Unexpected end of file looking for FNT chunk header."
      );
      return result;
    }

    if (fntChunkHeader.name != CHUNK_TAGS[Chunk.fnt]) {
      addError(
        arena, &result, cast(uint) (fntHeaderStart + fntChunkHeader.name.offsetof), Severity.error,
        "Expected the 'BTNF' tag to begin the FNT chunk."
      );
      return result;
    }

    if (fntChunkHeader.size > bytes.length - index - fntChunkHeader.name.sizeof) {
      addError(
        arena, &result, cast(uint) (fntHeaderStart + fntChunkHeader.size.offsetof), Severity.error,
        aprintf(arena, "FNT chunk size %u is too big to fit into this file.", fntChunkHeader.size)
      );
      return result;
    }

    fntBase = index;
    fntSize = cast(uint) (fntChunkHeader.size - fntChunkHeader.name.sizeof - fntChunkHeader.size.sizeof);
  }

  index = fntBase;
  uint fntTmp = fntBase;

  auto firstFntEntry = consume!FntMainTableEntry(bytes, &fntTmp);  // Don't advance index here
  if (!firstFntEntry) {
    addError(
      arena, &result, fntBase, Severity.error,
      "Unexpected end of file looking for FNT."
    );
    return result;
  }

  if (firstFntEntry.numDirsOrParent * FntMainTableEntry.sizeof > fntSize) {
    addError(
      arena, &result, cast(uint) (fntBase + firstFntEntry.numDirsOrParent.offsetof), Severity.error,
      aprintf(arena, "FNT reports %u directories are present, but that's too many to fit in the FNT chunk of size %u.", firstFntEntry.numDirsOrParent, fntSize)
    );
    return result;
  }

  FntMainTableEntry[] mainEntries = (cast(FntMainTableEntry*) &bytes[fntBase])[0..firstFntEntry.numDirsOrParent];

  import std.stdio;

  index = fntBase + fntSize;

  // Parse IMG

  if (fileType != NarcFileType.nds) {
    uint imgHeaderStart = index;
    auto imgChunkHeader = consume!ChunkHeader(bytes, &index);
    if (!imgChunkHeader) {
      addError(
        arena, &result, index, Severity.error,
        "Unexpected end of file looking for IMG chunk header."
      );
      return result;
    }

    if (imgChunkHeader.name != CHUNK_TAGS[Chunk.img]) {
      addError(
        arena, &result, cast(uint) (imgHeaderStart + imgChunkHeader.name.offsetof), Severity.error,
        "Expected the 'BTNF' tag to begin the IMG chunk."
      );
      return result;
    }

    if (imgChunkHeader.size > bytes.length - index + (*imgChunkHeader).sizeof) {
      addError(
        arena, &result, cast(uint) (imgHeaderStart + imgChunkHeader.size.offsetof), Severity.error,
        aprintf(arena, "IMG chunk size %u is too big to fit into this file.", imgChunkHeader.size)
      );
      return result;
    }

    imgBase = index;
    imgSize = cast(uint) (imgChunkHeader.size - ChunkHeader.sizeof);

    index += imgSize;

    if (index != bytes.length) {
      addError(
        arena, &result, index, Severity.warning,
        "There appears to be junk at the end of the file."
      );
      return result;
    }
  }

  index = imgBase;

  // Create file entries

  result.narc.files       = pushArray!(NarcFile, false)(arena, fatEntries.length);
  result.narc.directories = pushArray!(NarcFile, false)(arena, mainEntries.length);
  result.narc.files[]       = cast(NarcFile) gNullFile;
  result.narc.directories[] = cast(NarcFile) gNullFile;

  foreach (i, ref fatEntry; fatEntries) {
    NarcFile* file = &result.narc.files[i];

    file.id = cast(ushort) i;
    file.offset = fatEntry.start;

    if (fatEntry.end < fatEntry.start) {
      addError(
        arena, &result, cast(uint) (cast(ubyte*) &fatEntry.end - bytes.ptr), Severity.error,
        aprintf(arena, "File %zu's end offset is greater than its start offset: 0x%X > 0xX.", i, fatEntry.end, fatEntry.start)
      );
      return result;
    }

    if (fatEntry.start > imgSize) {
      addError(
        arena, &result, cast(uint) (cast(ubyte*) &fatEntry.start - bytes.ptr), Severity.error,
        aprintf(arena, "File %zu's start offset is out of bounds of the IMG section: 0x%X > 0xX.", i, fatEntry.start, imgSize)
      );
      return result;
    }

    if (fatEntry.end > imgSize) {
      addError(
        arena, &result, cast(uint) (cast(ubyte*) &fatEntry.end - bytes.ptr), Severity.error,
        aprintf(arena, "File %zu's end offset is out of bounds of the IMG section: 0x%X > 0xX.", i, fatEntry.end, imgSize)
      );
      return result;
    }

    file.data = bytes[imgBase + fatEntry.start..imgBase + fatEntry.end];

    // name and pointers to be filled in later...
  }

  // Using this name to call the pattern of a NARC that only contains nameless files under a single root directory -
  // see below.
  bool flat = false;

  foreach (dirId, ref mainEntry; mainEntries) {
    bool isRoot = dirId == 0;
    uint runner = fntBase + mainEntry.subTableOffset;
    uint fileId = mainEntry.subTableFirstFile;

    if (runner >= fntBase+fntSize) {
      addError(
        arena, &result, runner, Severity.error,
        aprintf(arena, "FNT main entry 0x04X: Sub-table offset would be at 0xX, which is out of bounds of the FNT chunk.", 0xF000 + dirId, runner)
      );
      return result;
    }

    NarcFile* parent = &result.narc.directories[dirId];

    parent.id = cast(ushort) (0xF000 + dirId);

    int subCount = 0;
    NarcFile* lastFile = null;
    while (true) {
      auto subEntryBase = runner;

      if (runner >= fntBase+fntSize) {
        addError(
          arena, &result, runner, Severity.error,
          aprintf(arena, "Unexpected end of chunk while reading FNT main entry 0x%04X", parent.id)
        );
        return result;
      }

      // 01h..7Fh File Entry          (Length=1..127, without ID field)
      // 81h..FFh Sub-Directory Entry (Length=1..127, plus ID field)
      // 00h      End of Sub-Table
      // 80h      Reserved
      ubyte typeOrLength = bytes[runner];
      if (typeOrLength == 0) {
        // List terminated

        // In some NARCs, there's a hack where the FNT contains a single main root entry with no filenames,
        // accomplished using a sub-table offset to a zero byte WITHIN the main table entry's space!
        // Trying to capture that here. Detection for this is squirrled away here to take advantage
        // of the bounds checking for reading into that weird sub-table already done here.
        if (dirId == 0 && mainEntries.length == 1 && subCount == 0) {
          flat = true;
        }

        break;
      }

      bool  isDir     = (typeOrLength & 0b10000000) != 0;
      ubyte strLength = (typeOrLength & 0b01111111);

      size_t expectedSize = 1 + strLength + (isDir * 2);

      if (fntBase+fntSize - runner < expectedSize) {
        addError(
          arena, &result, runner, Severity.error,
          aprintf(arena, "FNT main entry 0x%04X, sub-entry #%d: Chunk not large enough to hold entry and name string of length %d.", parent.id, subCount, strLength)
        );
        return result;
      }

      runner += 1;
      char[] name = cast(char[]) bytes[runner..runner+strLength];
      runner += strLength;

      NarcFile* file;
      ushort subDirId = 0;
      if (isDir) {
        subDirId = littleEndianToNative!ushort(bytes[runner..runner+2][0..2]);

        if (!(subDirId >= 0xF000 && subDirId <= 0xFFFF) || (subDirId & 0xFFF) >= result.narc.directories.length) {
          addError(
            arena, &result, runner, Severity.error,
            aprintf(arena, "FNT main entry 0x%04X, sub-entry #%d: Directory ID 0x%04X is invalid.", parent.id, subCount, subDirId)
          );
          return result;
        }

        runner += 2;
        file = &result.narc.directories[subDirId & 0xFFF];
      }
      else {
        if (fileId >= result.narc.files.length) {
          addError(
            arena, &result, subEntryBase, Severity.error,
            aprintf(arena, "FNT main entry 0x%04X, sub-entry #%d: This file would have ID 0x04X, but there are in fact fewer files than that.", parent.id, subCount, fileId)
          );
          return result;
        }

        file = &result.narc.files[fileId];
      }

      file.name   = name;
      file.parent = &result.narc.directories[dirId];

      if (lastFile) {
        lastFile.next = file;
        file.prev     = lastFile;
      }
      else {
        parent.first = file;
      }
      lastFile = file;

      if (!isDir) fileId++;
      subCount++;
    }

    parent.last = lastFile;
  }

  // If we found out the NARC is flat, we need to manually fix up the file hierarchy now, because it didn't get done
  // in the loop above.
  if (flat && result.narc.files.length) {
    foreach (i, ref file; result.narc.files) {
      file.parent = &result.narc.directories[0];
      if (i > 0)                          file.prev = &result.narc.files[i-1];
      if (i < result.narc.files.length-1) file.next = &result.narc.files[i+1];
    }

    result.narc.directories[0].first = &result.narc.files[0];
    result.narc.directories[0].last  = &result.narc.files[$-1];
  }

  result.narc.root = &result.narc.directories[0];

  if (fileType == NarcFileType.nds) {
    foreach (i, ref overlayInfo; result.narc.overlayTableArm9) {
      if (i != overlayInfo.overlayId) {
        addError(
          arena, &result, cast(uint) ((cast(ubyte*) &overlayInfo.overlayId) - bytes.ptr), Severity.warning,
          aprintf(arena, "The table entry for ARM9 overlay %zu has an ID (%u) that does not match its number.", i, overlayInfo.overlayId)
        );
      }

      if (overlayInfo.fileId < result.narc.files.length) {
        result.narc.overlaysArm9[i] = result.narc.files[overlayInfo.fileId].data;
      }
      else {
        addError(
          arena, &result, cast(uint) ((cast(ubyte*) &overlayInfo.fileId) - bytes.ptr), Severity.error,
          aprintf(arena, "ARM9 overlay %zu's table entry points to an invalid file (0x%X).", i, overlayInfo.overlayId)
        );
      }
    }

    foreach (i, ref overlayInfo; result.narc.overlayTableArm7) {
      if (i != overlayInfo.overlayId) {
        addError(
          arena, &result, cast(uint) ((cast(ubyte*) &overlayInfo.overlayId) - bytes.ptr), Severity.warning,
          aprintf(arena, "The table entry for ARM7 overlay %zu has an ID (%u) that does not match its number.", i, overlayInfo.overlayId)
        );
      }

      if (overlayInfo.fileId < result.narc.files.length) {
        result.narc.overlaysArm7[i] = result.narc.files[overlayInfo.fileId].data;
      }
      else {
        addError(
          arena, &result, cast(uint) ((cast(ubyte*) &overlayInfo.fileId) - bytes.ptr), Severity.error,
          aprintf(arena, "ARM7 overlay %zu's table entry points to an invalid file (0x%X).", i, overlayInfo.overlayId)
        );
      }
    }
  }

  return result;
}

// @Speed: This is an O(n) search.
NarcFile* fileByName(Narc* narc, const(char)[] name) {
  foreach (ref file; narc.files) {
    if (file.name == name) return &file;
  }
  foreach (ref file; narc.directories) {
    if (file.name == name) return &file;
  }
  return cast(NarcFile*) &gNullFile;
}

NarcFile* fileById(Narc* narc, ushort id) {
  // Should I return gNullFile on bounds error?

  if (id < 0xF000) {
    return &narc.files[id];
  }
  else {
    return &narc.directories[id & 0x0FFF];
  }
}

ubyte[] packNarc(Arena* arena, Narc* narc) {
  auto header      = push!NarcHeader(arena);
  ubyte* narcStart = cast(ubyte*) header;

  ubyte* fatStart        = arena.index;
  auto fatChunkHeader    = push!ChunkHeader(arena);
  auto fatChunkExtra     = push!BtafChunkExtra(arena);
  fatChunkHeader.name    = CHUNK_TAGS[Chunk.fat];
  fatChunkExtra.numFiles = cast(ushort) narc.files.length;

  auto fatEntries = pushArray!FatEntry(arena, narc.files.length);

  fatChunkHeader.size = cast(uint) (arena.index - fatStart);

  ubyte* fntStart     = arena.index;
  auto fntChunkHeader = push!ChunkHeader(arena);
  ubyte* fntBase      = arena.index;
  fntChunkHeader.name = CHUNK_TAGS[Chunk.fnt];

  auto mainEntries = pushArray!FntMainTableEntry(arena, narc.directories.length);

  // Detect whether this NARC is "flat" (single root directory, empty filenames).
  // @TODO: It's not really good if any of the files have empty names in a non-flat NARC. Maybe check/assert for that?
  bool flat = () {
    if (mainEntries.length > 1) return false;

    foreach (ref file; narc.files) {
      if (file.name.length) return false;
    }

    return true;
  }();

  if (flat) {
    // Hack that I've seen in officially-packed "flat" NARCs: This subTableOffset of 4 will point to a zero-byte within
    // this very entry!
    mainEntries[0] = FntMainTableEntry(subTableOffset : 4, subTableFirstFile : 0, numDirsOrParent : 1);
  }
  else {
    foreach (dirId, ref file; narc.directories) {
      bool wroteFirstFile = false;

      mainEntries[dirId].subTableOffset = cast(uint) (arena.index - fntBase);

      if (dirId == 0) {
        mainEntries[dirId].numDirsOrParent = cast(ushort) mainEntries.length;
      }
      else {
        mainEntries[dirId].numDirsOrParent = file.parent.id;
      }

      foreach (subFile; linkedRange(file.first)) {
        auto typeOrLength = push!ubyte(arena);
        *typeOrLength = cast(ubyte) subFile.name.length;
        if (isDirectory(*subFile)) {
          *typeOrLength |= 0b10000000;
        }

        copyArray(arena, subFile.name);
        if (!isDirectory(*subFile) && !wroteFirstFile) {
          wroteFirstFile = true;
          mainEntries[dirId].subTableFirstFile = subFile.id;
        }

        if (isDirectory(*subFile)) {
          *push!ushort(arena) = subFile.id;
        }
      }

      pushBytes(arena, 1);  // 0 byte to end table
    }
  }

  void padTo4Alignment() {
    auto padding = pushBytesNoZero(arena, -(arena.index - narcStart) & (4-1));
    padding[] = 0xFF;
  }

  // GBATEK says we need to pad 0xFFs to the nearest 4 bytes at the end of this chunk.
  padTo4Alignment();

  fntChunkHeader.size = cast(uint) (arena.index - fntStart);

  ubyte* imgStart     = arena.index;
  auto imgChunkHeader = push!ChunkHeader(arena);
  ubyte* imgBase      = arena.index;
  imgChunkHeader.name = CHUNK_TAGS[Chunk.img];

  foreach (i, ref file; narc.files) {
    fatEntries[i].start = cast(uint) (arena.index - imgBase);
    fatEntries[i].end   = cast(uint) (fatEntries[i].start + file.data.length);
    copyArray(arena, file.data);

    // Pad to the nearest 4 bytes with 0xFFs, which seems to be how official NARCs are packed
    padTo4Alignment();
  }

  imgChunkHeader.size = cast(uint) (arena.index - imgStart);

  header.fileSize = cast(uint) (arena.index-narcStart);

  return narcStart[0..header.fileSize];
}
