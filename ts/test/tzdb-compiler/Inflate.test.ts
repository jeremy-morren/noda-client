// src/noda-js/TzdbCompiler/Inflate.ts, on hand-made blocks and the host's CompressionStream output.

import { describe, expect, it } from "vitest";
import { Crc32, Gunzip, Inflate } from "../../src/noda-js/TzdbCompiler/Inflate.ts";
import tzdataUrl from "@testdata/tzdb/tzdata2026f.tar.gz?inline";

const hello = new TextEncoder().encode("hello");

async function Compress(data: Uint8Array, format: CompressionFormat): Promise<Uint8Array> {
  const stream = new Blob([data as Uint8Array<ArrayBuffer>]).stream().pipeThrough(new CompressionStream(format));
  return new Uint8Array(await new Response(stream).arrayBuffer());
}

async function Decompress(data: Uint8Array, format: CompressionFormat): Promise<Uint8Array> {
  const stream = new Blob([data as Uint8Array<ArrayBuffer>]).stream().pipeThrough(new DecompressionStream(format));
  return new Uint8Array(await new Response(stream).arrayBuffer());
}

function GzipMember(deflate: Uint8Array, content: Uint8Array, header: number[] = [0x1f, 0x8b, 8, 0, 0, 0, 0, 0, 0, 255]): Uint8Array {
  const crc = Crc32(content);
  const n = content.length;
  return new Uint8Array([
    ...header,
    ...deflate,
    crc & 0xff, (crc >>> 8) & 0xff, (crc >>> 16) & 0xff, crc >>> 24,
    n & 0xff, (n >>> 8) & 0xff, (n >>> 16) & 0xff, n >>> 24,
  ]);
}

/** Compresses to a dynamic Huffman block with long matches. */
function SampleText(): Uint8Array {
  const lines: string[] = [];
  for (let i = 0; i < 2000; i++) {
    lines.push(`Zone\tEurope/Zone${i % 37}\t${i % 13}:${(i * 7) % 60} -\tLMT\t${1800 + (i % 200)}`);
  }
  return new TextEncoder().encode(lines.join("\n"));
}

/** Incompressible: stored blocks. */
function RandomBytes(length: number): Uint8Array {
  const bytes = new Uint8Array(length);
  let x = 12345;
  for (let i = 0; i < length; i++) {
    x = (Math.imul(x, 1103515245) + 12345) >>> 0;
    bytes[i] = x >>> 24;
  }
  return bytes;
}

describe("Inflate", () => {
  it("a stored block", () => {
    // BFINAL = 1, BTYPE = 00; then LEN = 5, NLEN = ~5, and the bytes.
    const { Output, End } = Inflate(new Uint8Array([0x01, 0x05, 0x00, 0xfa, 0xff, ...hello, 0x99]));
    expect(Output).toEqual(hello);
    expect(End).toBe(10);
  });

  it("an empty stored block, then a final fixed block", () => {
    // BFINAL = 0, BTYPE = 00, LEN = 0; then zlib's raw DEFLATE of "hello" (one fixed Huffman block).
    expect(Inflate(new Uint8Array([0x00, 0x00, 0x00, 0xff, 0xff, 0xcb, 0x48, 0xcd, 0xc9, 0xc9, 0x07, 0x00])).Output).toEqual(hello);
  });

  it("a fixed Huffman block", () => {
    // zlib's raw DEFLATE of "hello": BFINAL = 1, BTYPE = 01.
    const data = new Uint8Array([0xcb, 0x48, 0xcd, 0xc9, 0xc9, 0x07, 0x00]);
    expect((data[0]! >> 1) & 3).toBe(1);
    const { Output, End } = Inflate(data);
    expect(new TextDecoder().decode(Output)).toBe("hello");
    expect(End).toBe(7);
  });

  it("a fixed Huffman block with an overlapping match (a distance shorter than its length)", () => {
    // zlib's raw DEFLATE of 100 'a's: a literal, then matches at distance 1.
    const data = new Uint8Array([0x4b, 0x4c, 0xa4, 0x3d, 0x00, 0x00]);
    expect(new TextDecoder().decode(Inflate(data).Output)).toBe("a".repeat(100));
  });

  it("dynamic Huffman blocks (from the host's CompressionStream)", async () => {
    const text = SampleText();
    const compressed = await Compress(text, "deflate-raw");
    expect((compressed[0]! >> 1) & 3).toBe(2);
    const { Output, End } = Inflate(compressed);
    expect(Output).toEqual(text);
    expect(End).toBe(compressed.length);
  });

  it("stored blocks (from the host's CompressionStream, for data that doesn't compress)", async () => {
    const bytes = RandomBytes(200_000);
    const compressed = await Compress(bytes, "deflate-raw");
    expect(Inflate(compressed).Output).toEqual(bytes);
  });

  it("starts at the given index", () => {
    expect(Inflate(new Uint8Array([0xaa, 0xbb, 0xcb, 0x48, 0xcd, 0xc9, 0xc9, 0x07, 0x00]), 2).Output).toEqual(hello);
  });

  it("rejects invalid data", () => {
    // Block type 3 is reserved.
    expect(() => Inflate(new Uint8Array([0x07]))).toThrowNodaError("InvalidDataException");
    expect(() => Inflate(new Uint8Array([0x07]))).toThrow("invalid block type");
    // A stored block's length must match its complement.
    expect(() => Inflate(new Uint8Array([0x01, 0x05, 0x00, 0xfb, 0xff, ...hello]))).toThrow("complement");
    // Truncated: stored, fixed.
    expect(() => Inflate(new Uint8Array([0x01, 0x05, 0x00, 0xfa, 0xff, 0x68]))).toThrow("unexpected end of data");
    expect(() => Inflate(new Uint8Array([0xcb, 0x48, 0xcd]))).toThrow("unexpected end of data");
    // A match before the start of the output: fixed block, length symbol 257 (length 3), distance symbol 0 (1).
    // Bits, least significant first: 1 (BFINAL), 1 0 (BTYPE 01), 0000001 (257), 00000 (distance 0).
    expect(() => Inflate(new Uint8Array([0x03, 0x02, 0x00]))).toThrow("distance too far back");
  });
});

describe("Gunzip", () => {
  it("decompresses a gzip member and checks its CRC-32 and length", () => {
    const gzip = GzipMember(new Uint8Array([0xcb, 0x48, 0xcd, 0xc9, 0xc9, 0x07, 0x00]), hello);
    expect(Gunzip(gzip)).toEqual(hello);
  });

  it("skips the optional header fields (extra, name, comment, header CRC)", () => {
    const header = [
      0x1f, 0x8b, 8, 4 | 8 | 16 | 2, 0, 0, 0, 0, 0, 3,
      3, 0, 0xaa, 0xbb, 0xcc, // FEXTRA: length 3, then the data
      ...new TextEncoder().encode("hello.txt"), 0, // FNAME
      ...new TextEncoder().encode("a comment"), 0, // FCOMMENT
      0x12, 0x34, // FHCRC (not checked)
    ];
    expect(Gunzip(GzipMember(new Uint8Array([0xcb, 0x48, 0xcd, 0xc9, 0xc9, 0x07, 0x00]), hello, header))).toEqual(hello);
  });

  it("reads the host's CompressionStream output", async () => {
    const text = SampleText();
    expect(Gunzip(await Compress(text, "gzip"))).toEqual(text);
  });

  it("reads the tzdata fixture as the host's DecompressionStream does", async () => {
    const tarGz = new Uint8Array(await (await fetch(tzdataUrl)).arrayBuffer());
    expect(Gunzip(tarGz)).toEqual(await Decompress(tarGz, "gzip"));
  });

  it("rejects a CRC-32 or length mismatch", () => {
    const gzip = GzipMember(new Uint8Array([0xcb, 0x48, 0xcd, 0xc9, 0xc9, 0x07, 0x00]), hello);
    const badCrc = gzip.slice();
    badCrc[gzip.length - 8]! ^= 1;
    expect(() => Gunzip(badCrc)).toThrowNodaError("InvalidDataException");
    expect(() => Gunzip(badCrc)).toThrow("CRC-32 mismatch");
    const badLength = gzip.slice();
    badLength[gzip.length - 4]! ^= 1;
    expect(() => Gunzip(badLength)).toThrow("length mismatch");
  });

  it("rejects data that isn't gzip, or is truncated", () => {
    expect(() => Gunzip(hello)).toThrow("Not gzip data.");
    const gzip = GzipMember(new Uint8Array([0xcb, 0x48, 0xcd, 0xc9, 0xc9, 0x07, 0x00]), hello);
    expect(() => Gunzip(gzip.subarray(0, gzip.length - 1))).toThrow("unexpected end of data");
    const deflate64 = gzip.slice();
    deflate64[2] = 9;
    expect(() => Gunzip(deflate64)).toThrow("unsupported compression method 9");
  });
});

describe("Crc32", () => {
  it("gives the standard check value", () => {
    expect(Crc32(new TextEncoder().encode("123456789"))).toBe(0xcbf43926);
    expect(Crc32(new Uint8Array(0))).toBe(0);
  });
});

