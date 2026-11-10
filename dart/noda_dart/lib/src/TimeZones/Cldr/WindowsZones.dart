// Ported from NodaTime 6e024dde: src/NodaTime/TimeZones/Cldr/WindowsZones.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import '../IO/IDateTimeZoneReader.dart';
import '../IO/IDateTimeZoneWriter.dart';
import '../TzdbDateTimeZoneSource.dart';
import 'MapZone.dart';

/// Representation of the `<windowsZones>` element of CLDR supplemental data.
///
/// See [the CLDR design proposal](http://cldr.unicode.org/development/development-process/design-proposals/extended-windows-olson-zid-mapping)
/// for more details of the structure of the file from which data is taken.
///
/// This type is immutable reference type. See the thread safety section of the user guide for more information.
final class WindowsZones {
  /// Gets the version of the Windows zones mapping data read from the original file.
  ///
  /// As with other IDs, this should largely be treated as an opaque string. Previously, it was
  /// generated from the mapping file by extracting a number from an element such as `<version number="$Revision: 7825 $"/>`.
  /// This used to be a Subversion revision number. Currently, the version is the [CLDR](https://cldr.unicode.org) version from the original file.
  /// That association should only be used for diagnostic curiosity and never assumed in code.
  final String Version;

  /// Gets the TZDB version this Windows zone mapping data was created from.
  ///
  /// The CLDR mapping file usually lags behind the TZDB file somewhat - partly because the
  /// mappings themselves don't always change when the time zone data does. For example, it's entirely
  /// reasonable for a [TzdbDateTimeZoneSource] with a [TzdbDateTimeZoneSource.TzdbVersion] of
  /// "2013b" to be supply a `WindowsZones` object with a `TzdbVersion` of "2012f".
  final String TzdbVersion;

  /// Gets the Windows time zone database version this Windows zone mapping data was created from.
  ///
  /// At the time of this writing, this is populated (by CLDR) from the registry key
  /// HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Time Zones\TzVersion,
  /// so "7dc0101" for example.
  final String WindowsVersion;

  /// Gets an immutable collection of mappings from Windows system time zones to
  /// TZDB time zones.
  ///
  /// Each mapping consists of a single Windows time zone ID and a single
  /// territory to potentially multiple TZDB IDs that are broadly equivalent to that Windows zone/territory
  /// pair.
  ///
  /// Mappings for a single Windows system time zone can appear multiple times
  /// in this list, in different territories. For example, "Central Standard Time"
  /// maps to different TZDB zones in different countries (the US, Canada, Mexico) and
  /// even within a single territory there can be multiple zones. Every Windows system time zone covered within
  /// this collection has a "primary" entry with a territory code of "001" (which is the value of
  /// [MapZone.PrimaryTerritory]) and a single corresponding TZDB zone.
  ///
  /// This collection is not guaranteed to cover every Windows time zone. Some zones may be unmappable
  /// (such as "Mid-Atlantic Standard Time") and there can be a delay between a new Windows time zone being introduced
  /// and it appearing in CLDR, ready to be used by Noda Time. (There's also bound to be a delay between it appearing
  /// in CLDR and being used in your production system.) In practice however, you're unlikely to wish to use a time zone
  /// which isn't covered here.
  final List<MapZone> MapZones;

  /// Gets an immutable dictionary of primary mappings, from Windows system time zone ID
  /// to TZDB zone ID. This corresponds to the "001" territory which is present for every zone
  /// within the mapping file.
  ///
  /// Each value in the dictionary is a canonical ID in CLDR, but it may not be canonical
  /// in TZDB. For example, the ID corresponding to "India Standard Time" is "Asia/Calcutta", which
  /// is canonical in CLDR but is an alias in TZDB for "Asia/Kolkata". To obtain a canonical TZDB
  /// ID, use [TzdbDateTimeZoneSource.CanonicalIdMap].
  final Map<String, String> PrimaryMapping;

  @internal
  WindowsZones.NewVersionTzdbVersionWindowsVersionMapZones(
      String version, String tzdbVersion, String windowsVersion, List<MapZone> mapZones)
      // Dart: null safety checks version, tzdbVersion, windowsVersion and mapZones.
      : this._NewVersionTzdbVersionWindowsVersionMapZones(
            version, tzdbVersion, windowsVersion, List<MapZone>.unmodifiable(mapZones));

  WindowsZones._NewVersionTzdbVersionWindowsVersionMapZones(
      String version, String tzdbVersion, String windowsVersion, List<MapZone> mapZones)
      : Version = version,
        TzdbVersion = tzdbVersion,
        WindowsVersion = windowsVersion,
        MapZones = mapZones,
        PrimaryMapping = Map<String, String>.unmodifiable(_ToPrimaryMapping(mapZones));

  // Dart: mapZones.Where(z => z.Territory == MapZone.PrimaryTerritory).ToDictionary(z => z.WindowsId, z => z.TzdbIds.Single()),
  // with the errors LINQ throws.
  static Map<String, String> _ToPrimaryMapping(List<MapZone> mapZones) {
    var primaryMapping = <String, String>{};
    for (var z in mapZones.where((z) => z.Territory == MapZone.PrimaryTerritory)) {
      if (z.TzdbIds.length != 1) {
        throw StateError(z.TzdbIds.isEmpty ? 'Sequence contains no elements' : 'Sequence contains more than one element');
      }
      if (primaryMapping.containsKey(z.WindowsId)) {
        throw ArgumentError('An item with the same key has already been added. Key: ${z.WindowsId}');
      }
      primaryMapping[z.WindowsId] = z.TzdbIds.single;
    }
    return primaryMapping;
  }

  @internal
  static WindowsZones Read(IDateTimeZoneReader reader) {
    String version = reader.ReadString();
    String tzdbVersion = reader.ReadString();
    String windowsVersion = reader.ReadString();
    int count = reader.ReadCount();
    var mapZones = <MapZone>[];
    for (int i = 0; i < count; i++) {
      mapZones.add(MapZone.Read(reader));
    }
    return WindowsZones._NewVersionTzdbVersionWindowsVersionMapZones(
        version, tzdbVersion, windowsVersion, List<MapZone>.unmodifiable(mapZones));
  }

  @internal
  void Write(IDateTimeZoneWriter writer) {
    writer.WriteString(Version);
    writer.WriteString(TzdbVersion);
    writer.WriteString(WindowsVersion);
    writer.WriteCount(MapZones.length);
    for (var mapZone in MapZones) {
      mapZone.Write(writer);
    }
  }
}
