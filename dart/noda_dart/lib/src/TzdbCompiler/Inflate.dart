// noda_dart: new code. DEFLATE (RFC 1951) and gzip (RFC 1952) decompression in plain Dart, for every platform.
// Port of noda-js's TzdbCompiler/Inflate.ts; small rather than fast (no lookup tables).

import 'dart:typed_data';

import '../Utility/SystemExceptions.dart';

/// The longest Huffman code, in bits.
const int _MaxBits = 15;

/// The base lengths of length symbols 257-285 (RFC 1951 section 3.2.5), and their numbers of extra bits.
const List<int> _LengthBase = [
  3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258, //
];
const List<int> _LengthExtraBits = [
  0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0, //
];

/// The base distances of distance symbols 0-29, and their numbers of extra bits.
const List<int> _DistanceBase = [
  1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145,
  8193, 12289, 16385, 24577,
];
const List<int> _DistanceExtraBits = [
  0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13, //
];

/// The order in which a dynamic block lists the code lengths of the code length alphabet (RFC 1951 section 3.2.7).
const List<int> _CodeLengthOrder = [16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15];

/// A canonical Huffman code: how many codes there are of each length, and the symbols in code order.
final class _Huffman {
  final Uint16List Counts;
  final Uint16List Symbols;

  _Huffman(this.Counts, this.Symbols);
}

/// Builds the Huffman code with the given code lengths; throws [InvalidDataException] if over-subscribed.
_Huffman _BuildHuffman(List<int> lengths) {
  final counts = Uint16List(_MaxBits + 1);
  for (var symbol = 0; symbol < lengths.length; symbol++) {
    counts[lengths[symbol]]++;
  }
  // An incomplete code is allowed (e.g. a single distance code); data that uses a missing code fails in Decode.
  var left = 1;
  for (var length = 1; length <= _MaxBits; length++) {
    left = (left << 1) - counts[length];
    if (left < 0) {
      throw InvalidDataException('Invalid DEFLATE data: over-subscribed Huffman code.');
    }
  }
  // Symbols sorted by code length, then by symbol: the order of their codes.
  final offsets = Uint16List(_MaxBits + 1);
  for (var length = 1; length < _MaxBits; length++) {
    offsets[length + 1] = offsets[length] + counts[length];
  }
  final symbols = Uint16List(lengths.length);
  for (var symbol = 0; symbol < lengths.length; symbol++) {
    if (lengths[symbol] != 0) {
      symbols[offsets[lengths[symbol]]++] = symbol;
    }
  }
  return _Huffman(counts, symbols);
}

final _Huffman _fixedLiteralLength = _BuildHuffman(_FixedLiteralLengthLengths());
final _Huffman _fixedDistance = _BuildHuffman(_FixedDistanceLengths());

/// The decompressor's state: the input, the bits read from it but not used yet, and the output so far.
final class _Inflater {
  final Uint8List _input;

  /// The index of the next input byte.
  int _position;
  int _bitBuffer = 0;
  int _bitCount = 0;
  Uint8List _output;
  int _outputLength = 0;

  _Inflater(Uint8List input, int position)
      : _input = input,
        _position = position,
        _output = Uint8List((input.length - position) * 4 > 65536 ? (input.length - position) * 4 : 65536);

  /// The decompressed data.
  Uint8List get Output => Uint8List.sublistView(_output, 0, _outputLength);

  /// Decompresses blocks until the last one.
  void Inflate() {
    bool last;
    do {
      last = _Bits(1) == 1;
      final type = _Bits(2);
      if (type == 0) {
        _Stored();
      } else if (type == 1) {
        _Codes(_fixedLiteralLength, _fixedDistance);
      } else if (type == 2) {
        _Dynamic();
      } else {
        throw InvalidDataException('Invalid DEFLATE data: invalid block type.');
      }
    } while (!last);
  }

  /// Reads [count] bits (0-16), least significant first. (Leaves fewer than 8 bits in the buffer.)
  int _Bits(int count) {
    while (_bitCount < count) {
      if (_position >= _input.length) {
        throw InvalidDataException('Invalid DEFLATE data: unexpected end of data.');
      }
      _bitBuffer |= _input[_position++] << _bitCount;
      _bitCount += 8;
    }
    final value = _bitBuffer & ((1 << count) - 1);
    _bitBuffer >>= count;
    _bitCount -= count;
    return value;
  }

  /// Makes room for [count] more bytes of output.
  void _Reserve(int count) {
    if (_outputLength + count > _output.length) {
      final doubled = _output.length * 2;
      final output = Uint8List(doubled > _outputLength + count ? doubled : _outputLength + count);
      output.setRange(0, _outputLength, _output);
      _output = output;
    }
  }

  /// A stored (uncompressed) block (RFC 1951 section 3.2.4).
  void _Stored() {
    // Skip to the next byte boundary: the bits left in the buffer are the rest of the current byte.
    _bitBuffer = 0;
    _bitCount = 0;
    final input = _input;
    final start = _position + 4;
    if (start > input.length) {
      throw InvalidDataException('Invalid DEFLATE data: unexpected end of data.');
    }
    final length = input[_position] | (input[_position + 1] << 8);
    final complement = input[_position + 2] | (input[_position + 3] << 8);
    if (length != (~complement & 0xffff)) {
      throw InvalidDataException("Invalid DEFLATE data: stored block length doesn't match its complement.");
    }
    if (start + length > input.length) {
      throw InvalidDataException('Invalid DEFLATE data: unexpected end of data.');
    }
    _Reserve(length);
    _output.setRange(_outputLength, _outputLength + length, input, start);
    _outputLength += length;
    _position = start + length;
  }

  /// A block with dynamic Huffman codes (RFC 1951 section 3.2.7): reads the codes, then the data.
  void _Dynamic() {
    final literalLengthCount = _Bits(5) + 257;
    final distanceCount = _Bits(5) + 1;
    final codeLengthCount = _Bits(4) + 4;
    if (literalLengthCount > 286 || distanceCount > 30) {
      throw InvalidDataException('Invalid DEFLATE data: too many length or distance codes.');
    }
    final codeLengthLengths = Uint8List(19);
    for (var i = 0; i < codeLengthCount; i++) {
      codeLengthLengths[_CodeLengthOrder[i]] = _Bits(3);
    }
    final codeLengthCode = _BuildHuffman(codeLengthLengths);

    // The literal/length and distance code lengths, as one sequence (a repeat may cross from one to the other).
    final lengths = Uint8List(literalLengthCount + distanceCount);
    for (var i = 0; i < lengths.length;) {
      final symbol = _Decode(codeLengthCode);
      if (symbol < 16) {
        lengths[i++] = symbol;
        continue;
      }
      var value = 0;
      int repeat;
      if (symbol == 16) {
        if (i == 0) {
          throw InvalidDataException('Invalid DEFLATE data: repeat with no previous length.');
        }
        value = lengths[i - 1];
        repeat = 3 + _Bits(2);
      } else if (symbol == 17) {
        repeat = 3 + _Bits(3);
      } else {
        repeat = 11 + _Bits(7);
      }
      if (i + repeat > lengths.length) {
        throw InvalidDataException('Invalid DEFLATE data: too many code lengths.');
      }
      while (repeat-- > 0) {
        lengths[i++] = value;
      }
    }
    if (lengths[256] == 0) {
      throw InvalidDataException('Invalid DEFLATE data: no end-of-block code.');
    }
    _Codes(
      _BuildHuffman(Uint8List.sublistView(lengths, 0, literalLengthCount)),
      _BuildHuffman(Uint8List.sublistView(lengths, literalLengthCount)),
    );
  }

  /// Decodes one symbol.
  int _Decode(_Huffman huffman) {
    // Canonical codes of each length are consecutive, following on from the codes one bit shorter.
    var code = 0;
    var first = 0;
    var index = 0;
    for (var length = 1; length <= _MaxBits; length++) {
      code |= _Bits(1);
      final count = huffman.Counts[length];
      if (code - first < count) {
        return huffman.Symbols[index + code - first];
      }
      index += count;
      first = (first + count) << 1;
      code <<= 1;
    }
    throw InvalidDataException('Invalid DEFLATE data: invalid Huffman code.');
  }

  /// The compressed data of a block, up to its end-of-block symbol (RFC 1951 section 3.2.5).
  void _Codes(_Huffman literalLength, _Huffman distance) {
    for (;;) {
      final symbol = _Decode(literalLength);
      if (symbol < 256) {
        _Reserve(1);
        _output[_outputLength++] = symbol;
      } else if (symbol == 256) {
        return;
      } else {
        final lengthIndex = symbol - 257;
        if (lengthIndex >= _LengthBase.length) {
          throw InvalidDataException('Invalid DEFLATE data: invalid length symbol.');
        }
        final length = _LengthBase[lengthIndex] + _Bits(_LengthExtraBits[lengthIndex]);
        final distanceIndex = _Decode(distance);
        if (distanceIndex >= _DistanceBase.length) {
          throw InvalidDataException('Invalid DEFLATE data: invalid distance symbol.');
        }
        final back = _DistanceBase[distanceIndex] + _Bits(_DistanceExtraBits[distanceIndex]);
        if (back > _outputLength) {
          throw InvalidDataException('Invalid DEFLATE data: distance too far back.');
        }
        _Reserve(length);
        // Byte by byte: the copy may overlap the bytes it writes (a distance shorter than the length repeats them).
        final output = _output;
        for (var i = 0; i < length; i++, _outputLength++) {
          output[_outputLength] = output[_outputLength - back];
        }
      }
    }
  }
}

/// The fixed literal/length code lengths (RFC 1951 section 3.2.6).
Uint8List _FixedLiteralLengthLengths() {
  final lengths = Uint8List(288);
  for (var symbol = 0; symbol < 288; symbol++) {
    lengths[symbol] = symbol < 144
        ? 8
        : symbol < 256
            ? 9
            : symbol < 280
                ? 7
                : 8;
  }
  return lengths;
}

/// The fixed distance code lengths: all 5 bits (including the two unused symbols, 30 and 31).
Uint8List _FixedDistanceLengths() {
  final lengths = Uint8List(32);
  for (var symbol = 0; symbol < 32; symbol++) {
    lengths[symbol] = 5;
  }
  return lengths;
}

/// Decompresses raw DEFLATE data from [start]: the data, and the index after it.
({Uint8List Output, int End}) Inflate(Uint8List input, [int start = 0]) {
  final inflater = _Inflater(input, start);
  inflater.Inflate();
  return (Output: inflater.Output, End: inflater._position);
}

final Uint32List _crcTable = () {
  final table = Uint32List(256);
  for (var n = 0; n < 256; n++) {
    var c = n;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? 0xedb88320 ^ (c >> 1) : c >> 1;
    }
    table[n] = c;
  }
  return table;
}();

/// The CRC-32 of the data, as gzip computes it (ISO 3309; the polynomial 0xEDB88320, reflected).
int Crc32(Uint8List data) {
  final table = _crcTable;
  var crc = 0xffffffff;
  for (var i = 0; i < data.length; i++) {
    crc = table[(crc ^ data[i]) & 0xff] ^ (crc >> 8);
  }
  return (crc ^ 0xffffffff) & 0xffffffff;
}

/// Whether the data starts with gzip's magic number (1F 8B).
bool IsGzip(List<int> data) => data.length >= 2 && data[0] == 0x1f && data[1] == 0x8b;

// gzip header flags (RFC 1952 section 2.3.1).
const int _FlagHeaderCrc = 2;
const int _FlagExtra = 4;
const int _FlagName = 8;
const int _FlagComment = 16;

/// Decompresses one gzip member, checking its CRC-32 and length; anything after it is ignored.
Uint8List Gunzip(Uint8List data) {
  if (!IsGzip(data)) {
    throw InvalidDataException('Not gzip data.');
  }
  if (data.length < 18) {
    throw InvalidDataException('Invalid gzip data: unexpected end of data.');
  }
  if (data[2] != 8) {
    throw InvalidDataException('Invalid gzip data: unsupported compression method ${data[2]}.');
  }
  final flags = data[3];
  if ((flags & 0xe0) != 0) {
    throw InvalidDataException('Invalid gzip data: reserved flags are set.');
  }
  // Skip the rest of the header: modification time (4 bytes), extra flags and OS (1 each), then the optional fields.
  var position = 10;
  if ((flags & _FlagExtra) != 0) {
    position += 2 + (data[position] | (data[position + 1] << 8));
  }
  for (final flag in const [_FlagName, _FlagComment]) {
    if ((flags & flag) != 0) {
      // A zero-terminated string.
      while (position < data.length && data[position] != 0) {
        position++;
      }
      position++;
    }
  }
  if ((flags & _FlagHeaderCrc) != 0) {
    position += 2;
  }
  if (position >= data.length) {
    throw InvalidDataException('Invalid gzip data: unexpected end of data.');
  }

  final (Output: output, End: end) = Inflate(data, position);
  if (end + 8 > data.length) {
    throw InvalidDataException('Invalid gzip data: unexpected end of data.');
  }
  // The trailer: the CRC-32 of the uncompressed data, and its length modulo 2^32, both little-endian.
  // (noda_dart: bit operations stay within 32 bits, for dart2js.)
  final crc = (data[end] | (data[end + 1] << 8) | (data[end + 2] << 16) | (data[end + 3] << 24)) & 0xffffffff;
  final size = (data[end + 4] | (data[end + 5] << 8) | (data[end + 6] << 16) | (data[end + 7] << 24)) & 0xffffffff;
  if (crc != Crc32(output)) {
    throw InvalidDataException('Invalid gzip data: CRC-32 mismatch.');
  }
  if (size != (output.length & 0xffffffff)) {
    throw InvalidDataException('Invalid gzip data: length mismatch.');
  }
  return output;
}
