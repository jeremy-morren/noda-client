// noda-js: new code. DEFLATE (RFC 1951) and gzip (RFC 1952) for hosts without DecompressionStream.
// Small rather than fast: canonical Huffman codes decoded a bit at a time, without lookup tables.

import { NewInvalidDataException, type InvalidDataException } from "../internal.ts";

/** The longest Huffman code, in bits. */
const MaxBits = 15;

/** The base lengths of length symbols 257-285 (RFC 1951 section 3.2.5), and their numbers of extra bits. */
const LengthBase = [3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258];
const LengthExtraBits = [0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0];

/** The base distances of distance symbols 0-29, and their numbers of extra bits. */
const DistanceBase = [
  1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145,
  8193, 12289, 16385, 24577,
];
const DistanceExtraBits = [0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13];

/** The order in which a dynamic block lists the code lengths of the code length alphabet (RFC 1951 section 3.2.7). */
const CodeLengthOrder = [16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15];

/** A canonical Huffman code: how many codes there are of each length, and the symbols in code order. */
interface Huffman {
  readonly Counts: Uint16Array;
  readonly Symbols: Uint16Array;
}

/**
 * Builds the Huffman code with the given code lengths (0 for a symbol that isn't used).
 * @throws {InvalidDataException} The lengths are over-subscribed (more codes than the lengths allow).
 */
function BuildHuffman(lengths: ArrayLike<number>): Huffman {
  const counts = new Uint16Array(MaxBits + 1);
  for (let symbol = 0; symbol < lengths.length; symbol++) {
    counts[lengths[symbol]!]!++;
  }
  // An incomplete code is allowed (e.g. a single distance code); data that uses a missing code fails in Decode.
  let left = 1;
  for (let length = 1; length <= MaxBits; length++) {
    left = (left << 1) - counts[length]!;
    if (left < 0) {
      throw NewInvalidDataException("Invalid DEFLATE data: over-subscribed Huffman code.");
    }
  }
  // Symbols sorted by code length, then by symbol: the order of their codes.
  const offsets = new Uint16Array(MaxBits + 1);
  for (let length = 1; length < MaxBits; length++) {
    offsets[length + 1] = offsets[length]! + counts[length]!;
  }
  const symbols = new Uint16Array(lengths.length);
  for (let symbol = 0; symbol < lengths.length; symbol++) {
    if (lengths[symbol] !== 0) {
      symbols[offsets[lengths[symbol]!]!++] = symbol;
    }
  }
  return { Counts: counts, Symbols: symbols };
}

let fixedLiteralLength: Huffman | undefined;
let fixedDistance: Huffman | undefined;

/** The decompressor's state: the input, the bits read from it but not used yet, and the output so far. */
class Inflater {
  private readonly _input: Uint8Array;
  /** The index of the next input byte. */
  _position: number;
  private _bitBuffer = 0;
  private _bitCount = 0;
  private _output: Uint8Array;
  private _outputLength = 0;

  constructor(input: Uint8Array, position: number) {
    this._input = input;
    this._position = position;
    this._output = new Uint8Array(Math.max(65536, (input.length - position) * 4));
  }

  /** The decompressed data. */
  get Output(): Uint8Array {
    return this._output.subarray(0, this._outputLength);
  }

  /** Decompresses blocks until the last one. */
  Inflate(): void {
    let last: boolean;
    do {
      last = this.Bits(1) === 1;
      const type = this.Bits(2);
      if (type === 0) {
        this.Stored();
      } else if (type === 1) {
        this.Codes(
          (fixedLiteralLength ??= BuildHuffman(FixedLiteralLengthLengths())),
          (fixedDistance ??= BuildHuffman(FixedDistanceLengths())),
        );
      } else if (type === 2) {
        this.Dynamic();
      } else {
        throw NewInvalidDataException("Invalid DEFLATE data: invalid block type.");
      }
    } while (!last);
  }

  /** Reads `count` bits (0-16), least significant first. (Leaves fewer than 8 bits in the buffer.) */
  private Bits(count: number): number {
    while (this._bitCount < count) {
      if (this._position >= this._input.length) {
        throw NewInvalidDataException("Invalid DEFLATE data: unexpected end of data.");
      }
      this._bitBuffer |= this._input[this._position++]! << this._bitCount;
      this._bitCount += 8;
    }
    const value = this._bitBuffer & ((1 << count) - 1);
    this._bitBuffer >>>= count;
    this._bitCount -= count;
    return value;
  }

  /** Makes room for `count` more bytes of output. */
  private Reserve(count: number): void {
    if (this._outputLength + count > this._output.length) {
      const output = new Uint8Array(Math.max(this._output.length * 2, this._outputLength + count));
      output.set(this.Output);
      this._output = output;
    }
  }

  /** A stored (uncompressed) block (RFC 1951 section 3.2.4). */
  private Stored(): void {
    // Skip to the next byte boundary: the bits left in the buffer are the rest of the current byte.
    this._bitBuffer = 0;
    this._bitCount = 0;
    const input = this._input;
    const start = this._position + 4;
    if (start > input.length) {
      throw NewInvalidDataException("Invalid DEFLATE data: unexpected end of data.");
    }
    const length = input[this._position]! | (input[this._position + 1]! << 8);
    const complement = input[this._position + 2]! | (input[this._position + 3]! << 8);
    if (length !== (~complement & 0xffff)) {
      throw NewInvalidDataException("Invalid DEFLATE data: stored block length doesn't match its complement.");
    }
    if (start + length > input.length) {
      throw NewInvalidDataException("Invalid DEFLATE data: unexpected end of data.");
    }
    this.Reserve(length);
    this._output.set(input.subarray(start, start + length), this._outputLength);
    this._outputLength += length;
    this._position = start + length;
  }

  /** A block with dynamic Huffman codes (RFC 1951 section 3.2.7): reads the codes, then the data. */
  private Dynamic(): void {
    const literalLengthCount = this.Bits(5) + 257;
    const distanceCount = this.Bits(5) + 1;
    const codeLengthCount = this.Bits(4) + 4;
    if (literalLengthCount > 286 || distanceCount > 30) {
      throw NewInvalidDataException("Invalid DEFLATE data: too many length or distance codes.");
    }
    const codeLengthLengths = new Uint8Array(19);
    for (let i = 0; i < codeLengthCount; i++) {
      codeLengthLengths[CodeLengthOrder[i]!] = this.Bits(3);
    }
    const codeLengthCode = BuildHuffman(codeLengthLengths);

    // The literal/length and distance code lengths, as one sequence (a repeat may cross from one to the other).
    const lengths = new Uint8Array(literalLengthCount + distanceCount);
    for (let i = 0; i < lengths.length;) {
      const symbol = this.Decode(codeLengthCode);
      if (symbol < 16) {
        lengths[i++] = symbol;
        continue;
      }
      let value = 0;
      let repeat: number;
      if (symbol === 16) {
        if (i === 0) {
          throw NewInvalidDataException("Invalid DEFLATE data: repeat with no previous length.");
        }
        value = lengths[i - 1]!;
        repeat = 3 + this.Bits(2);
      } else if (symbol === 17) {
        repeat = 3 + this.Bits(3);
      } else {
        repeat = 11 + this.Bits(7);
      }
      if (i + repeat > lengths.length) {
        throw NewInvalidDataException("Invalid DEFLATE data: too many code lengths.");
      }
      while (repeat-- > 0) {
        lengths[i++] = value;
      }
    }
    if (lengths[256] === 0) {
      throw NewInvalidDataException("Invalid DEFLATE data: no end-of-block code.");
    }
    this.Codes(BuildHuffman(lengths.subarray(0, literalLengthCount)), BuildHuffman(lengths.subarray(literalLengthCount)));
  }

  /** Decodes one symbol. */
  private Decode(huffman: Huffman): number {
    // `first`: the first code of the current length; `index`: its symbol's index.
    let code = 0;
    let first = 0;
    let index = 0;
    for (let length = 1; length <= MaxBits; length++) {
      code |= this.Bits(1);
      const count = huffman.Counts[length]!;
      if (code - first < count) {
        return huffman.Symbols[index + code - first]!;
      }
      index += count;
      first = (first + count) << 1;
      code <<= 1;
    }
    throw NewInvalidDataException("Invalid DEFLATE data: invalid Huffman code.");
  }

  /** The compressed data of a block, up to its end-of-block symbol (RFC 1951 section 3.2.5). */
  private Codes(literalLength: Huffman, distance: Huffman): void {
    for (;;) {
      const symbol = this.Decode(literalLength);
      if (symbol < 256) {
        this.Reserve(1);
        this._output[this._outputLength++] = symbol;
      } else if (symbol === 256) {
        return;
      } else {
        const lengthIndex = symbol - 257;
        if (lengthIndex >= LengthBase.length) {
          throw NewInvalidDataException("Invalid DEFLATE data: invalid length symbol.");
        }
        const length = LengthBase[lengthIndex]! + this.Bits(LengthExtraBits[lengthIndex]!);
        const distanceIndex = this.Decode(distance);
        if (distanceIndex >= DistanceBase.length) {
          throw NewInvalidDataException("Invalid DEFLATE data: invalid distance symbol.");
        }
        const back = DistanceBase[distanceIndex]! + this.Bits(DistanceExtraBits[distanceIndex]!);
        if (back > this._outputLength) {
          throw NewInvalidDataException("Invalid DEFLATE data: distance too far back.");
        }
        this.Reserve(length);
        // Byte by byte: the copy may overlap the bytes it writes (a distance shorter than the length repeats them).
        const output = this._output;
        for (let i = 0; i < length; i++, this._outputLength++) {
          output[this._outputLength] = output[this._outputLength - back]!;
        }
      }
    }
  }
}

/** The fixed literal/length code lengths (RFC 1951 section 3.2.6). */
function FixedLiteralLengthLengths(): Uint8Array {
  const lengths = new Uint8Array(288);
  for (let symbol = 0; symbol < 288; symbol++) {
    lengths[symbol] = symbol < 144 ? 8 : symbol < 256 ? 9 : symbol < 280 ? 7 : 8;
  }
  return lengths;
}

/** The fixed distance code lengths: all 5 bits (including the two unused symbols, 30 and 31). */
function FixedDistanceLengths(): Uint8Array {
  const lengths = new Uint8Array(32);
  for (let symbol = 0; symbol < 32; symbol++) {
    lengths[symbol] = 5;
  }
  return lengths;
}

/**
 * Decompresses raw DEFLATE data (RFC 1951) starting at `start`.
 * @returns The decompressed data, and the index of the first byte after the compressed data.
 * @throws {InvalidDataException} The data is invalid or truncated.
 * @internal
 */
export function Inflate(input: Uint8Array, start: number = 0): { readonly Output: Uint8Array; readonly End: number } {
  const inflater = new Inflater(input, start);
  inflater.Inflate();
  return { Output: inflater.Output, End: inflater._position };
}

let crcTable: Uint32Array | undefined;

/** The CRC-32 of the data, as gzip computes it. @internal */
export function Crc32(data: Uint8Array): number {
  if (crcTable === undefined) {
    crcTable = new Uint32Array(256);
    for (let n = 0; n < 256; n++) {
      let c = n;
      for (let k = 0; k < 8; k++) {
        c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
      }
      crcTable[n] = c;
    }
  }
  let crc = 0xffffffff;
  for (let i = 0; i < data.length; i++) {
    crc = crcTable[(crc ^ data[i]!) & 0xff]! ^ (crc >>> 8);
  }
  return (crc ^ 0xffffffff) >>> 0;
}

/** Whether the data starts with gzip's magic number (1F 8B). @internal */
export function IsGzip(data: Uint8Array): boolean {
  return data.length >= 2 && data[0] === 0x1f && data[1] === 0x8b;
}

// gzip header flags (RFC 1952 section 2.3.1).
const FlagHeaderCrc = 2;
const FlagExtra = 4;
const FlagName = 8;
const FlagComment = 16;

/**
 * Decompresses one gzip member (RFC 1952), checking its CRC-32 and length.
 * @throws {InvalidDataException} The data isn't gzip data, or is invalid or truncated.
 * @internal
 */
export function Gunzip(data: Uint8Array): Uint8Array {
  if (!IsGzip(data)) {
    throw NewInvalidDataException("Not gzip data.");
  }
  if (data.length < 18) {
    throw NewInvalidDataException("Invalid gzip data: unexpected end of data.");
  }
  if (data[2] !== 8) {
    throw NewInvalidDataException(`Invalid gzip data: unsupported compression method ${data[2]!}.`);
  }
  const flags = data[3]!;
  if ((flags & 0xe0) !== 0) {
    throw NewInvalidDataException("Invalid gzip data: reserved flags are set.");
  }
  // Skip the rest of the header: modification time (4 bytes), extra flags and OS (1 each), then the optional fields.
  let position = 10;
  if ((flags & FlagExtra) !== 0) {
    position += 2 + (data[position]! | (data[position + 1]! << 8));
  }
  for (const flag of [FlagName, FlagComment]) {
    if ((flags & flag) !== 0) {
      // A zero-terminated string.
      while (position < data.length && data[position] !== 0) {
        position++;
      }
      position++;
    }
  }
  if ((flags & FlagHeaderCrc) !== 0) {
    position += 2;
  }
  if (position >= data.length) {
    throw NewInvalidDataException("Invalid gzip data: unexpected end of data.");
  }

  const { Output: output, End: end } = Inflate(data, position);
  if (end + 8 > data.length) {
    throw NewInvalidDataException("Invalid gzip data: unexpected end of data.");
  }
  // The trailer: the CRC-32 of the uncompressed data, and its length modulo 2^32, both little-endian.
  const crc = (data[end]! | (data[end + 1]! << 8) | (data[end + 2]! << 16) | (data[end + 3]! << 24)) >>> 0;
  const size = (data[end + 4]! | (data[end + 5]! << 8) | (data[end + 6]! << 16) | (data[end + 7]! << 24)) >>> 0;
  if (crc !== Crc32(output)) {
    throw NewInvalidDataException("Invalid gzip data: CRC-32 mismatch.");
  }
  if (size !== output.length % 0x100000000) {
    throw NewInvalidDataException("Invalid gzip data: length mismatch.");
  }
  return output;
}
