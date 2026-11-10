// noda_dart: new code (as noda-js's Inflate.test.ts). Our DEFLATE/gzip decoder, on hand-made blocks and host output.

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:noda_dart/src/TzdbCompiler/Inflate.dart';
import 'package:noda_dart/src/Utility/SystemExceptions.dart';
import 'package:test/test.dart';

import '../helpers/Host.dart';

final Uint8List hello = utf8.encode('hello');

/// zlib's raw DEFLATE of "hello" (one fixed Huffman block).
final Uint8List helloDeflate = Uint8List.fromList([0xcb, 0x48, 0xcd, 0xc9, 0xc9, 0x07, 0x00]);

void expectInvalidData(void Function() action, [String message = '']) {
  expect(action, throwsA(isA<InvalidDataException>().having((e) => e.message, 'message', contains(message))));
}

/// A gzip member: a minimal header (or the one given), the DEFLATE data, then the CRC-32 and length of [content].
Uint8List GzipMember(List<int> deflate, Uint8List content,
    [List<int> header = const [0x1f, 0x8b, 8, 0, 0, 0, 0, 0, 0, 255]]) {
  final crc = Crc32(content);
  final n = content.length;
  return Uint8List.fromList([
    ...header,
    ...deflate,
    crc & 0xff, (crc >> 8) & 0xff, (crc >> 16) & 0xff, (crc >> 24) & 0xff, //
    n & 0xff, (n >> 8) & 0xff, (n >> 16) & 0xff, (n >> 24) & 0xff,
  ]);
}

/// Text that compresses well (a dynamic Huffman block with long matches).
Uint8List SampleText() {
  final lines = <String>[];
  for (var i = 0; i < 2000; i++) {
    lines.add('Zone\tEurope/Zone${i % 37}\t${i % 13}:${(i * 7) % 60} -\tLMT\t${1800 + (i % 200)}');
  }
  return utf8.encode(lines.join('\n'));
}

/// Bytes that don't compress (so a compressor emits stored blocks).
Uint8List RandomBytes(int length) {
  final random = Random(12345);
  return Uint8List.fromList(List<int>.generate(length, (_) => random.nextInt(256)));
}

void main() {
  group('Inflate', () {
    test('a stored block', () {
      // BFINAL = 1, BTYPE = 00; then LEN = 5, NLEN = ~5, and the bytes.
      final (Output: output, End: end) = Inflate(Uint8List.fromList([0x01, 0x05, 0x00, 0xfa, 0xff, ...hello, 0x99]));
      expect(output, hello);
      expect(end, 10);
    });

    test('an empty stored block, then a final fixed block', () {
      // BFINAL = 0, BTYPE = 00, LEN = 0; then zlib's raw DEFLATE of "hello" (one fixed Huffman block).
      expect(Inflate(Uint8List.fromList([0x00, 0x00, 0x00, 0xff, 0xff, ...helloDeflate])).Output, hello);
    });

    test('a fixed Huffman block', () {
      // zlib's raw DEFLATE of "hello": BFINAL = 1, BTYPE = 01.
      final data = helloDeflate;
      expect((data[0] >> 1) & 3, 1);
      final (Output: output, End: end) = Inflate(data);
      expect(utf8.decode(output), 'hello');
      expect(end, 7);
    });

    test('a fixed Huffman block with an overlapping match (a distance shorter than its length)', () {
      // zlib's raw DEFLATE of 100 'a's: a literal, then matches at distance 1.
      final data = Uint8List.fromList([0x4b, 0x4c, 0xa4, 0x3d, 0x00, 0x00]);
      expect(utf8.decode(Inflate(data).Output), 'a' * 100);
    });

    test("dynamic Huffman blocks (from the host's compressor)", () => RunOrSkip(() async {
          final text = SampleText();
          final compressed = await Compress(text, 'deflate-raw');
          expect((compressed[0] >> 1) & 3, 2);
          final (Output: output, End: end) = Inflate(compressed);
          expect(output, text);
          expect(end, compressed.length);
        }));

    test("stored blocks (from the host's compressor, for data that doesn't compress)", () => RunOrSkip(() async {
          final bytes = RandomBytes(200000);
          final compressed = await Compress(bytes, 'deflate-raw');
          expect(Inflate(compressed).Output, bytes);
        }));

    test('starts at the given index', () {
      expect(Inflate(Uint8List.fromList([0xaa, 0xbb, ...helloDeflate]), 2).Output, hello);
    });

    test('rejects invalid data', () {
      // Block type 3 is reserved.
      expectInvalidData(() => Inflate(Uint8List.fromList([0x07])), 'invalid block type');
      // A stored block's length must match its complement.
      expectInvalidData(() => Inflate(Uint8List.fromList([0x01, 0x05, 0x00, 0xfb, 0xff, ...hello])), 'complement');
      // Truncated: stored, fixed.
      expectInvalidData(
          () => Inflate(Uint8List.fromList([0x01, 0x05, 0x00, 0xfa, 0xff, 0x68])), 'unexpected end of data');
      expectInvalidData(() => Inflate(Uint8List.fromList([0xcb, 0x48, 0xcd])), 'unexpected end of data');
      // A match before the start of the output: fixed block, length symbol 257 (length 3), distance symbol 0 (1).
      // Bits, least significant first: 1 (BFINAL), 1 0 (BTYPE 01), 0000001 (257), 00000 (distance 0).
      expectInvalidData(() => Inflate(Uint8List.fromList([0x03, 0x02, 0x00])), 'distance too far back');
    });
  });

  group('Gunzip', () {
    test('decompresses a gzip member and checks its CRC-32 and length', () {
      final gzip = GzipMember(helloDeflate, hello);
      expect(Gunzip(gzip), hello);
    });

    test('skips the optional header fields (extra, name, comment, header CRC)', () {
      final header = [
        0x1f, 0x8b, 8, 4 | 8 | 16 | 2, 0, 0, 0, 0, 0, 3, //
        3, 0, 0xaa, 0xbb, 0xcc, // FEXTRA: length 3, then the data
        ...utf8.encode('hello.txt'), 0, // FNAME
        ...utf8.encode('a comment'), 0, // FCOMMENT
        0x12, 0x34, // FHCRC (not checked)
      ];
      expect(Gunzip(GzipMember(helloDeflate, hello, header)), hello);
    });

    test("reads the host's gzip output", () => RunOrSkip(() async {
          final text = SampleText();
          expect(Gunzip(await Compress(text, 'gzip')), text);
        }));

    test('reads the tzdata fixture as the host decompresses it', () => RunOrSkip(() async {
          final tarGz = await ReadFixtureOrNode('tzdb/tzdata2026f.tar.gz');
          expect(Gunzip(tarGz), await Decompress(tarGz, 'gzip'));
        }));

    test('rejects a CRC-32 or length mismatch', () {
      final gzip = GzipMember(helloDeflate, hello);
      final badCrc = Uint8List.fromList(gzip);
      badCrc[gzip.length - 8] ^= 1;
      expectInvalidData(() => Gunzip(badCrc), 'CRC-32 mismatch');
      final badLength = Uint8List.fromList(gzip);
      badLength[gzip.length - 4] ^= 1;
      expectInvalidData(() => Gunzip(badLength), 'length mismatch');
    });

    test("rejects data that isn't gzip, or is truncated", () {
      expectInvalidData(() => Gunzip(hello), 'Not gzip data.');
      final gzip = GzipMember(helloDeflate, hello);
      expectInvalidData(() => Gunzip(Uint8List.sublistView(gzip, 0, gzip.length - 1)), 'unexpected end of data');
      final deflate64 = Uint8List.fromList(gzip);
      deflate64[2] = 9;
      expectInvalidData(() => Gunzip(deflate64), 'unsupported compression method 9');
    });
  });

  group('Crc32', () {
    test('gives the standard check value', () {
      expect(Crc32(utf8.encode('123456789')), 0xcbf43926);
      expect(Crc32(Uint8List(0)), 0);
    });
  });
}
