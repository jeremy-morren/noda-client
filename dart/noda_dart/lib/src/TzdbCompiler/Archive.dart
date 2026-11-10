// noda_dart: new code. Reads a tzdata .tar.gz or .tar into a FileSource (NodaTime's FileSource.FromArchive).

import 'dart:convert';
import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../Tools/Common/FileUtility.dart';
import 'Shims.dart';
import 'Tar.dart';
import 'Tzdb/FileSource.dart';

/// Whether the data starts with lzip's magic number ("LZIP").
bool _IsLzip(Uint8List data) =>
    data.length >= 4 && data[0] == 0x4c && data[1] == 0x5a && data[2] == 0x49 && data[3] == 0x50;

/// Throws if the archive is lzip-compressed, which isn't supported.
void _CheckNotLzip(Uint8List archive) {
  if (_IsLzip(archive)) {
    throw UnsupportedError(
      "lzip-compressed archives (such as tzdb-<version>.tar.lz) aren't supported. Use the tzdata archive, "
      'tzdata<version>.tar.gz (e.g. https://data.iana.org/time-zones/tzdata-latest.tar.gz).',
    );
  }
}

/// Tzdata files as a [FileSource]; named `tzdata<version>.tar` if there's a `version` file, else [origin], as
/// the compiler takes the version from the name.
@internal
FileSource TzdataFileSource(Map<String, Uint8List> files, String origin) {
  final version = files['version'];
  if (version != null) {
    origin = 'tzdata${Trim(utf8.decode(version, allowMalformed: true))}.tar';
  }
  final copy = Map<String, Uint8List>.of(files);
  return FileSource.NewNamesOpenFunctionFullOrigin(copy.keys.toList(), (name) => GetValue(copy, name), origin);
}

/// Reads a tar archive's files, by file name without directories, as a [FileSource].
FileSource _ReadTarFiles(Uint8List tar, String origin) {
  final files = <String, Uint8List>{};
  for (final MapEntry(key: name, value: data) in ReadTar(tar).entries) {
    files[GetFileName(name)] = data;
  }
  return TzdataFileSource(files, origin);
}

/// Reads a (gzip-compressed) tar archive as a [FileSource]; [origin] gives the version if there's no `version`
/// file.
///
/// Throws [UnsupportedError] for lzip, and [InvalidDataException] for an invalid archive.
@internal
FileSource ReadTzdbArchive(Uint8List archive, String origin) {
  _CheckNotLzip(archive);
  return _ReadTarFiles(FileUtility.Decompress(archive), origin);
}
