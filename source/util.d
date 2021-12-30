module pokemods.util;

import std.stdio : File;

void patch(File destFile, const(ubyte)[] data, uint offset) {
  destFile.seek(offset);
  destFile.rawWrite(data);
}

void patch(string destPath, const(ubyte)[] data, uint offset) {
  auto file = File(destPath, "rb+");
  patch(file, data, offset);
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
