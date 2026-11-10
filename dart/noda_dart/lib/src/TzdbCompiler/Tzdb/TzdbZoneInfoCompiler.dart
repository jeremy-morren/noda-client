// Ported from NodaTime 6e024dde: src/NodaTime.TzdbCompiler/Tzdb/TzdbZoneInfoCompiler.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import '../../TimeZones/TzdbZone1970Location.dart';
import '../../Tools/Common/FileUtility.dart';
import '../../Utility/SystemExceptions.dart';
import '../FileSystem.dart' as host;
import '../Shims.dart';
import 'FileSource.dart';
import 'IoExtensions.dart';
import 'TzdbDatabase.dart';
import 'TzdbZoneInfoParser.dart';
import 'TzdbZoneLocationParser.dart';

/// Provides a compiler for Olson (TZDB) zone info files into the internal format used by Noda
/// Time for its [DateTimeZone] definitions. This read a set of files and generates
/// a resource file with the compiled contents suitable for reading with [TzdbDateTimeZoneSource] or one of its variants.
///
/// noda_dart: the log is a function called with each line, rather than a TextWriter.
class TzdbZoneInfoCompiler {
  static const String _Makefile = 'Makefile';

  // noda_dart: private in NodaTime; internal for ../Input.dart.
  @internal
  static const String Zone1970TabFile = 'zone1970.tab';
  @internal
  static const String Iso3166TabFile = 'iso3166.tab';
  @internal
  static const String ZoneTabFile = 'zone.tab';

  @internal
  static final List<String> ZoneFiles = List<String>.unmodifiable(const [
    'africa', 'antarctica', 'asia', 'australasia', 'europe', //
    'northamerica', 'southamerica', 'pacificnew', 'etcetera', 'backward', 'systemv',
  ]);

  static final RegExp _VersionRegex = RegExp(r'\d{2,4}[a-z]');

  final void Function(String line)? _log;

  /// Initializes a new instance of the [TzdbZoneInfoCompiler] class
  /// logging to the given function, which may be null.
  ///
  /// (NodaTime's `TzdbZoneInfoCompiler()`, logging to standard output, and `TzdbZoneInfoCompiler(TextWriter? log)`,
  /// as one constructor: by default, the compiler logs with [print].)
  TzdbZoneInfoCompiler([void Function(String line)? log = print]) : _log = log;

  /// Tries to compile the contents of a path to a TzdbDatabase. The path can be a directory
  /// name containing the TZDB files, or a local tar.gz file, or a remote tar.gz file.
  /// The version ID is taken from the Makefile, if it exists. Otherwise, an attempt is made to guess
  /// it based on the last element of the path, to match a regex of \d{2,4}[a-z] (anywhere within the element).
  ///
  /// noda_dart: a directory or local file needs dart:io; on the web, a path is a URL relative to the page.
  Future<TzdbDatabase> CompileAsync(String path) async {
    final source = await _LoadSourceAsync(path);
    return Compile(source);
  }

  /// Compiles the contents of a file source to a TzdbDatabase: the part of [CompileAsync] after loading the source.
  ///
  /// noda_dart: compiles a source built in memory (as noda-js's `Compile`).
  @internal
  TzdbDatabase Compile(FileSource source) {
    final version = _InferVersion(source);
    final database = TzdbDatabase(version);
    _LoadZoneFiles(source, database);
    _LoadLocationFiles(source, database);
    return database;
  }

  void _LoadZoneFiles(FileSource source, TzdbDatabase database) {
    final tzdbParser = TzdbZoneInfoParser();
    for (final file in ZoneFiles) {
      if (source.Contains(file)) {
        _log?.call('Parsing file $file . . .');
        final stream = source.Open(file);
        tzdbParser.Parse(stream, database);
      }
    }
  }

  void _LoadLocationFiles(FileSource source, TzdbDatabase database) {
    if (!source.Contains(Iso3166TabFile)) {
      return;
    }
    final iso3166 = source
        .ReadLines(Iso3166TabFile)
        .where((line) => line != '' && !line.startsWith('#'))
        .map((line) => line.split('\t'))
        .toList();
    if (source.Contains(ZoneTabFile)) {
      // iso3166.ToDictionary(bits => bits[0], bits => bits[1]) (bits[1] throws IndexError if the line has no tab, as
      // C#'s IndexOutOfRangeException)
      final iso3166Dict = <String, String>{};
      for (final bits in iso3166) {
        AddValue(iso3166Dict, bits[0], bits[1]);
      }
      database.ZoneLocations = source
          .ReadLines(ZoneTabFile)
          .where((line) => line != '' && !line.startsWith('#'))
          .map((line) => TzdbZoneLocationParser.ParseLocation(line, iso3166Dict))
          .toList();
    }
    if (source.Contains(Zone1970TabFile)) {
      // iso3166.ToDictionary(bits => bits[0], bits => new TzdbZone1970Location.Country(code: bits[0], name: bits[1]))
      final iso3166Dict = <String, TzdbZone1970LocationCountry>{};
      for (final bits in iso3166) {
        AddValue(iso3166Dict, bits[0], TzdbZone1970LocationCountry(bits[1], bits[0]));
      }
      database.Zone1970Locations = source
          .ReadLines(Zone1970TabFile)
          .where((line) => line != '' && !line.startsWith('#'))
          .map((line) => TzdbZoneLocationParser.ParseEnhancedLocation(line, iso3166Dict))
          .toList();
    }
  }

  Future<FileSource> _LoadSourceAsync(String path) async {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      _log?.call('Downloading $path');
      final stream = await FileUtility.LoadFileOrUrlAsync(path);
      return FileSource.FromArchive(stream, path);
    }
    if (host.DirectoryExists(path)) {
      _log?.call('Compiling from directory $path');
      return FileSource.FromDirectory(path);
    } else {
      _log?.call('Compiling from archive file $path');
      final file = await FileUtility.LoadFileOrUrlAsync(path);
      return FileSource.FromArchive(file, path);
    }
  }

  String _InferVersion(FileSource source) {
    if (source.Contains(_Makefile)) {
      for (final line in source.ReadLines(_Makefile)) {
        if (RegExp(r'VERSION=\d{4}.*').hasMatch(line)) {
          final version = Trim(line.substring(8));
          _log?.call('Inferred version $version from $_Makefile');
          return version;
        }
      }
    }
    final match = _VersionRegex.firstMatch(source.Origin);
    if (match != null) {
      final version = match.group(0)!;
      _log?.call('Inferred version $version from file/directory name ${source.Origin}');
      return version;
    }
    throw InvalidDataException('Unable to determine TZDB version from source');
  }
}
