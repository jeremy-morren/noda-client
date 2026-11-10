// noda_dart: new code. A minimal tar reader (ustar, pax, GNU long names) for tzdata archives.

import 'dart:convert';
import 'dart:typed_data';

import '../Utility/SystemExceptions.dart';

const int _BlockSize = 512;

/// The text of a NUL-terminated header field (or the whole field, if it has no NUL), decoded as UTF-8.
String _ReadString(Uint8List bytes, int offset, int length) {
  var end = offset;
  while (end < offset + length && bytes[end] != 0) {
    end++;
  }
  return utf8.decode(Uint8List.sublistView(bytes, offset, end), allowMalformed: true);
}

/// The text without leading and trailing spaces (only U+0020: tar pads numbers with spaces).
String _TrimSpaces(String text) {
  var start = 0;
  var end = text.length;
  while (start < end && text[start] == ' ') {
    start++;
  }
  while (end > start && text[end - 1] == ' ') {
    end--;
  }
  return text.substring(start, end);
}

final RegExp _OctalRegex = RegExp(r'^[0-7]*$');

/// A numeric header field: octal, or big-endian base-256 if the first byte's high bit is set (GNU).
int _ReadNumber(Uint8List header, int offset, int length) {
  if ((header[offset] & 0x80) != 0) {
    var value = header[offset] & 0x7f;
    for (var i = 1; i < length; i++) {
      value = value * 256 + header[offset + i];
    }
    return value;
  }
  final text = _TrimSpaces(_ReadString(header, offset, length));
  if (!_OctalRegex.hasMatch(text)) {
    throw InvalidDataException("Invalid tar archive: invalid number '$text' in a header.");
  }
  return text == '' ? 0 : int.parse(text, radix: 8);
}

/// Whether the header's checksum (the sum of its bytes, with the checksum field counted as spaces) is right.
bool _IsChecksumValid(Uint8List header) {
  var sum = 0;
  for (var i = 0; i < _BlockSize; i++) {
    sum += i >= 148 && i < 156 ? 0x20 : header[i];
  }
  // Six octal digits, then a NUL and a space (by convention; readers accept other padding).
  final stored = _TrimSpaces(_ReadString(header, 148, 8));
  return stored != '' && _OctalRegex.hasMatch(stored) && int.parse(stored, radix: 8) == sum;
}

bool _IsZeroBlock(Uint8List block) {
  for (var i = 0; i < block.length; i++) {
    if (block[i] != 0) {
      return false;
    }
  }
  return true;
}

/// The `path` record of a pax extended header (records of the form `"<length> <key>=<value>\n"`), if it has one.
String? _ReadPaxPath(Uint8List data) {
  String? path;
  for (var position = 0; position < data.length;) {
    var space = position;
    while (space < data.length && data[space] != 0x20) {
      space++;
    }
    final length = int.tryParse(_ReadString(data, position, space - position));
    if (length == null ||
        !(length > space - position) ||
        position + length > data.length ||
        data[position + length - 1] != 0x0a) {
      throw InvalidDataException('Invalid tar archive: invalid pax extended header.');
    }
    final record = utf8.decode(Uint8List.sublistView(data, space + 1, position + length - 1), allowMalformed: true);
    final equals = record.indexOf('=');
    if (equals == -1) {
      throw InvalidDataException('Invalid tar archive: invalid pax extended header.');
    }
    if (record.substring(0, equals) == 'path') {
      path = record.substring(equals + 1);
    }
    position += length;
  }
  return path;
}

/// Reads the regular files in a tar archive (the last of a repeated name wins).
///
/// Throws [InvalidDataException] if the data isn't a valid tar archive.
Map<String, Uint8List> ReadTar(Uint8List archive) {
  final files = <String, Uint8List>{};
  // The name of the next entry, from a pax extended header or GNU long name entry before it.
  String? nextName;
  var position = 0;
  while (position + _BlockSize <= archive.length) {
    final header = Uint8List.sublistView(archive, position, position + _BlockSize);
    // The archive ends with two zero blocks (and is padded with more); the first is enough.
    if (_IsZeroBlock(header)) {
      return files;
    }
    if (!_IsChecksumValid(header)) {
      throw InvalidDataException('Not a tar archive (invalid header checksum at offset $position).');
    }
    final size = _ReadNumber(header, 124, 12);
    final dataStart = position + _BlockSize;
    if (dataStart + size > archive.length) {
      throw InvalidDataException('Invalid tar archive: unexpected end of data.');
    }
    final data = Uint8List.sublistView(archive, dataStart, dataStart + size);
    position = dataStart + (size + _BlockSize - 1) ~/ _BlockSize * _BlockSize;

    final type = header[156];
    if (type == 0x78 /* 'x': pax extended header, for the next entry */) {
      nextName = _ReadPaxPath(data) ?? nextName;
      continue;
    }
    if (type == 0x4c /* 'L': GNU long name, for the next entry */) {
      nextName = _ReadString(data, 0, data.length);
      continue;
    }
    // '0' (or NUL, in old archives) is a regular file; '7' is a contiguous file, which readers treat as regular.
    if (type == 0x30 || type == 0 || type == 0x37) {
      var name = nextName;
      if (name == null) {
        name = _ReadString(header, 0, 100);
        // POSIX ustar (not GNU's "ustar  \0") splits long names into a prefix and a name.
        final prefix =
            _ReadString(header, 257, 6) == 'ustar' && header[262] == 0 ? _ReadString(header, 345, 155) : '';
        if (prefix != '') {
          name = '$prefix/$name';
        }
      }
      // Old archives mark directories as regular files whose names end with '/'.
      if (!name.endsWith('/')) {
        files[name] = data;
      }
    }
    nextName = null;
  }
  // No end-of-archive blocks: accepted if the last entry was complete (as other readers do).
  if (position < archive.length && !_IsZeroBlock(Uint8List.sublistView(archive, position))) {
    throw InvalidDataException('Invalid tar archive: unexpected end of data.');
  }
  return files;
}
