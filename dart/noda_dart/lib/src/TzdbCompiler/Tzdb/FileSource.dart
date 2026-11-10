// Ported from NodaTime 6e024dde: src/NodaTime.TzdbCompiler/Tzdb/FileSource.cs
// Copyright 2015 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../FileSystem.dart' as host;
import '../Shims.dart';
import '../Tar.dart';

/// A random access collection of files.
///
/// noda_dart: a Stream is its bytes (a Uint8List).
@internal
final class FileSource {
  /// The name of the origin of the files - just the last part,
  /// rather than the whole URL/path.
  final String Origin;

  /// The names of the files.
  final List<String> Names;

  final Uint8List Function(String) _openFunction;

  /// noda_dart: internal rather than private, for ../Archive.dart.
  FileSource.NewNamesOpenFunctionFullOrigin(List<String> names, Uint8List Function(String) openFunction, String fullOrigin)
      : Names = names, // Could create a ReadOnlyCollection if we ever wanted to make this public
        Origin = GetFileName(fullOrigin),
        _openFunction = openFunction;

  Uint8List Open(String name) => _openFunction(name);

  bool Contains(String name) => Names.contains(name);

  /// noda_dart: [archiveData] is the decompressed tar file, read by ../Tar.dart.
  static FileSource FromArchive(Uint8List archiveData, String fullOrigin) {
    final entries = <String, Uint8List>{};
    for (final MapEntry(key: entryName, value: entryData) in ReadTar(archiveData).entries) {
      // The lzip file puts everything into a subdirectory. Let's just take the filename...
      entries[GetFileName(entryName)] = entryData;
    }
    return FileSource.NewNamesOpenFunctionFullOrigin(
        entries.keys.toList(), (file) => GetValue(entries, file), fullOrigin);
  }

  /// noda_dart: needs dart:io; throws [UnsupportedError] on the web.
  static FileSource FromDirectory(String path) {
    final files = host.GetFiles(path).map((p) => GetFileName(p)).toList();
    return FileSource.NewNamesOpenFunctionFullOrigin(
        files, (file) => host.ReadAllBytes('$path/$file'), GetFileName(path));
  }
}
