// noda_dart: new code. Builds tar archives for the tzdb compiler's tests.

import 'dart:convert';
import 'dart:typed_data';

/// Magic and version: POSIX ustar by default, "ustar  \u0000" for GNU tar, "" for v7.
final class TarEntry {
  final String name;
  final String data;
  final String type;
  final String? prefix;
  final String magic;

  const TarEntry(this.name, {this.data = '', this.type = '0', this.prefix, this.magic = 'ustar\u000000'});
}

Uint8List TarHeader(TarEntry entry, int size) {
  final header = Uint8List(512);
  void put(int offset, String text) => header.setAll(offset, utf8.encode(text));
  put(0, entry.name);
  put(100, '0000644\u0000');
  put(108, '0000000\u0000');
  put(116, '0000000\u0000');
  put(124, '${size.toRadixString(8).padLeft(11, '0')}\u0000');
  put(136, '00000000000\u0000');
  put(156, entry.type);
  put(257, entry.magic);
  if (entry.prefix != null) {
    put(345, entry.prefix!);
  }
  SetTarChecksum(header);
  return header;
}

/// Sets a header's checksum: six octal digits, a NUL and a space.
void SetTarChecksum(Uint8List header) {
  var sum = 0;
  for (var i = 0; i < 512; i++) {
    sum += i >= 148 && i < 156 ? 0x20 : header[i];
  }
  header.setAll(148, utf8.encode('${sum.toRadixString(8).padLeft(6, '0')}\u0000 '));
}

/// A pax extended header record: `"<length> <key>=<value>\n"`, where the length counts itself.
String PaxRecord(String key, String value) {
  final rest = ' $key=$value\n';
  final restLength = utf8.encode(rest).length;
  var length = restLength + 1;
  while ('$length'.length + restLength != length) {
    length++;
  }
  return '$length$rest';
}

Uint8List Tar(List<TarEntry> entries) {
  final builder = BytesBuilder();
  for (final entry in entries) {
    final data = utf8.encode(entry.data);
    builder.add(TarHeader(entry, data.length));
    final padded = Uint8List((data.length + 511) ~/ 512 * 512);
    padded.setAll(0, data);
    builder.add(padded);
  }
  builder.add(Uint8List(1024));
  return builder.takeBytes();
}

Uint8List TarOfBytes(Map<String, List<int>> files) {
  final builder = BytesBuilder();
  for (final MapEntry(key: name, value: data) in files.entries) {
    builder.add(TarHeader(TarEntry(name), data.length));
    final padded = Uint8List((data.length + 511) ~/ 512 * 512);
    padded.setAll(0, data);
    builder.add(padded);
  }
  builder.add(Uint8List(1024));
  return builder.takeBytes();
}

Map<String, String> Texts(Map<String, Uint8List> files) =>
    {for (final MapEntry(key: name, value: data) in files.entries) name: utf8.decode(data)};

/// Without the named entry (renamed, so readers skip it).
Uint8List RemoveTarEntry(Uint8List archive, String name) {
  final copy = Uint8List.fromList(archive);
  for (var position = 0; position + 512 <= copy.length;) {
    final header = Uint8List.sublistView(copy, position, position + 512);
    var nameEnd = 0;
    while (nameEnd < 100 && header[nameEnd] != 0) {
      nameEnd++;
    }
    final entryName = utf8.decode(Uint8List.sublistView(header, 0, nameEnd));
    if (entryName == '') {
      break;
    }
    var sizeEnd = 124;
    while (sizeEnd < 136 && header[sizeEnd] != 0) {
      sizeEnd++;
    }
    final size = int.parse(utf8.decode(Uint8List.sublistView(header, 124, sizeEnd)).trim(), radix: 8);
    if (entryName == name) {
      header[0] = 0x5f; // '_'
      SetTarChecksum(header);
    }
    position += 512 + (size + 511) ~/ 512 * 512;
  }
  return copy;
}
