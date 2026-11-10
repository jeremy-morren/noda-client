// Ported from NodaTime 6e024dde: src/NodaTime.TzdbCompiler/Program.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../TimeZones/Cldr/MapZone.dart';
import '../TimeZones/Cldr/WindowsZones.dart';
import '../TimeZones/TzdbDateTimeZoneSource.dart';
import '../Utility/Stream.dart';
import 'Shims.dart';
import 'Tzdb/FileSource.dart';
import 'Tzdb/NameIdMappingSupport.dart';
import 'Tzdb/TzdbStreamWriter.dart';
import 'Tzdb/TzdbZoneInfoCompiler.dart';

/// Main entry point for the time zone information compiler. In theory we could support
/// multiple sources and formats but currently we only support one:
/// https://www.iana.org/time-zones. This system refers to it as TZDB.
/// This also requires a windowsZone.xml file from the Unicode CLDR repository, to
/// map Windows time zone names to TZDB IDs.
///
/// noda_dart: only Main's compile, write and read-back validation, and MergeWindowsZones (no command line or files).
@internal
abstract final class Program {
  /// Compiles [source], writes the NZD data, and reads it back and validates it.
  ///
  /// noda_dart: returns the data and the source read back, rather than an exit code; [log] replaces the console.
  static ({Uint8List Nzd, TzdbDateTimeZoneSource Source}) Main(
      FileSource source, WindowsZones windowsZones, void Function(String line)? log) {
    final tzdbCompiler = TzdbZoneInfoCompiler(log);
    final tzdb = tzdbCompiler.Compile(source);
    if (log != null) {
      tzdb.LogCounts(log);
    }
    _LogWindowsZonesSummary(windowsZones, log);
    final writer = TzdbStreamWriter();
    final stream = MemoryStream();
    writer.Write(tzdb, windowsZones, NameIdMappingSupport.StandardNameToIdMap, stream);
    final nzd = stream.ToArray();

    log?.call('Reading generated data and validating...');
    final tzdbSource = TzdbDateTimeZoneSource.FromBytes(nzd);
    tzdbSource.Validate();
    return (Nzd: nzd, Source: tzdbSource);
  }

  // Not ported: LoadWindowsZones(CompilerOptions, string) (CLDR's windowsZones.xml files), CreateOutputStream(CompilerOptions),
  // Read(CompilerOptions) (the command line's output file)

  static void _LogWindowsZonesSummary(WindowsZones windowsZones, void Function(String line)? log) {
    if (log == null) {
      return;
    }
    log('Windows Zones:');
    log('  Version: ${windowsZones.Version}');
    log('  TZDB version: ${windowsZones.TzdbVersion}');
    log('  Windows version: ${windowsZones.WindowsVersion}');
    log('  ${windowsZones.MapZones.length} MapZones');
    log('  ${windowsZones.PrimaryMapping.length} primary mappings');
  }

  /// Merge two WindowsZones objects together. The result has versions present in override,
  /// but falling back to the original for versions absent in the override. The set of MapZones
  /// in the result is the union of those in the original and override, but any ID/Territory
  /// pair present in both results in the override taking priority, unless the override has an
  /// empty "type" entry, in which case the entry is removed entirely.
  ///
  /// While this method could reasonably be in WindowsZones class, it's only needed in
  /// TzdbCompiler - and here is as good a place as any.
  ///
  /// The resulting MapZones will be ordered by Windows ID followed by territory.
  ///
  /// [originalZones]: The original WindowsZones
  /// [overrideZones]: The WindowsZones to override entries in the original
  ///
  /// Returns a merged zones object.
  static WindowsZones MergeWindowsZones(WindowsZones originalZones, WindowsZones overrideZones) {
    final version = overrideZones.Version == '' ? originalZones.Version : overrideZones.Version;
    final tzdbVersion = overrideZones.TzdbVersion == '' ? originalZones.TzdbVersion : overrideZones.TzdbVersion;
    final windowsVersion =
        overrideZones.WindowsVersion == '' ? originalZones.WindowsVersion : overrideZones.WindowsVersion;

    // Work everything out using dictionaries, and then sort.
    // (originalZones.MapZones.ToDictionary(mz => new { mz.WindowsId, mz.Territory }): the key is a record.)
    final mapZones = <(String, String), MapZone>{};
    for (final mz in originalZones.MapZones) {
      AddValue(mapZones, (mz.WindowsId, mz.Territory), mz);
    }
    for (final overrideMapZone in overrideZones.MapZones) {
      final key = (overrideMapZone.WindowsId, overrideMapZone.Territory);
      if (overrideMapZone.TzdbIds.isEmpty) {
        mapZones.remove(key);
      } else {
        mapZones[key] = overrideMapZone;
      }
    }
    // OrderBy(pair => pair.Key.WindowsId).ThenBy(pair => pair.Key.Territory) (noda_dart: ordinal; the keys are unique)
    final pairs = mapZones.entries.toList()
      ..sort((x, y) {
        final comparison = CompareOrdinal(x.key.$1, y.key.$1);
        return comparison != 0 ? comparison : CompareOrdinal(x.key.$2, y.key.$2);
      });
    final mapZoneList = pairs.map((pair) => pair.value).toList();
    return WindowsZones.NewVersionTzdbVersionWindowsVersionMapZones(version, tzdbVersion, windowsVersion, mapZoneList);
  }
}
