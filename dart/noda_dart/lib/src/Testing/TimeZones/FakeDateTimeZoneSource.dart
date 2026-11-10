// Ported from NodaTime 6e024dde: src/NodaTime.Testing/TimeZones/FakeDateTimeZoneSource.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import '../../DateTimeZone.dart';
import '../../IDateTimeZoneProvider.dart';
import '../../TimeZones/DateTimeZoneCache.dart';
import '../../TimeZones/IDateTimeZoneSource.dart';
import '../../TimeZones/SystemDateTimeZoneSource.dart';

/// A time zone source for test purposes.
/// Create instances via [FakeDateTimeZoneSourceBuilder] (NodaTime's `FakeDateTimeZoneSource.Builder`).
final class FakeDateTimeZoneSource implements IDateTimeZoneSource {
  final Map<String, DateTimeZone> _zones;
  final Map<String, String> _bclToZoneIds;

  FakeDateTimeZoneSource._NewVersionIdZonesBclToZoneIds(
      String versionId, Map<String, DateTimeZone> zones, Map<String, String> bclToZoneIds)
      : VersionId = versionId,
        _zones = zones,
        _bclToZoneIds = bclToZoneIds;

  /// Creates a time zone provider ([DateTimeZoneCache]) from this source.
  ///
  /// Returns a provider backed by this source.
  IDateTimeZoneProvider ToProvider() => DateTimeZoneCache(this);

  /// Returns an unordered enumeration of the IDs available from this source.
  @override
  Iterable<String> GetIds() => _zones.keys;

  /// Returns an appropriate version ID for diagnostic purposes, which must not be null.
  @override
  final String VersionId;

  /// Returns the time zone definition associated with the given ID.
  @override
  DateTimeZone ForId(String id) {
    // Dart: null safety checks id.
    final zone = _zones[id];
    if (zone != null) {
      return zone;
    }
    throw ArgumentError('Unknown ID: $id');
  }

  /// Returns this source's ID for the system default time zone.
  ///
  /// noda_dart: `SystemDateTimeZoneSource().GetSystemDefaultId()` stands for `TimeZoneInfo.Local.Id`.
  @override
  String? GetSystemDefaultId() {
    final id = SystemDateTimeZoneSource().GetSystemDefaultId();
    // We don't care about the return value of TryGetValue - if it's false,
    // canonicalId will be null, which is what we want.
    final canonicalId = id == null ? null : _bclToZoneIds[id];
    return canonicalId;
  }
}

/// Builder for [FakeDateTimeZoneSource], allowing the built object to
/// be immutable, but constructed via object/collection initializers.
///
/// (NodaTime's nested class `FakeDateTimeZoneSource.Builder`.)
final class FakeDateTimeZoneSourceBuilder extends Iterable<DateTimeZone> {
  final Map<String, String> _bclIdsToZoneIds = <String, String>{};
  final List<DateTimeZone> _zones = <DateTimeZone>[];

  /// Gets the dictionary mapping BCL `TimeZoneInfo` IDs to the canonical IDs
  /// served within the provider being built.
  ///

  /// The dictionary mapping BCL IDs to the canonical IDs served within the provider
  /// being built.
  Map<String, String> get BclIdsToZoneIds => _bclIdsToZoneIds;

  /// Gets the list of zones, exposed as a property for use when a test needs to set properties as
  /// well as adding zones.
  ///
  /// The list of zones within the provider being built.
  List<DateTimeZone> get Zones => _zones;

  /// Gets the version ID to advertise; defaults to "TestZones".
  ///
  /// The version ID to advertise; defaults to "TestZones".
  String VersionId;

  /// Creates a new builder.
  FakeDateTimeZoneSourceBuilder() : VersionId = 'TestZones';

  /// Adds a time zone to the builder.
  ///
  /// [zone]: The zone to add.
  void Add(DateTimeZone zone) {
    // Dart: null safety checks zone.
    _zones.add(zone);
  }

  /// Returns the zones within the builder. This mostly exists
  /// to enable collection initializers.
  ///
  /// Returns an iterator over the zones in this builder.
  @override
  Iterator<DateTimeZone> get iterator => _zones.iterator;

  // (IEnumerable.GetEnumerator, the explicit interface implementation, is the same iterator.)

  /// Builds a time zone source from this builder. The returned
  /// builder will be independent of this builder; further changes
  /// to this builder will not be reflected in the returned source.
  ///
  /// This method performs some sanity checks, and throws exceptions if
  /// they're violated. Those exceptions are not documented here, and you
  /// shouldn't be catching them anyway. (This is aimed at testing...)
  ///
  /// Returns the newly-built time zone source.
  FakeDateTimeZoneSource Build() {
    // zones.ToDictionary(zone => zone.Id): ArgumentException for a duplicate ID.
    final zoneMap = <String, DateTimeZone>{};
    for (final zone in _zones) {
      if (zoneMap.containsKey(zone.Id)) {
        throw ArgumentError('An item with the same key has already been added. Key: ${zone.Id}');
      }
      zoneMap[zone.Id] = zone;
    }
    for (final entry in _bclIdsToZoneIds.entries) {
      // Dart: null safety checks entry.Value.
      if (!zoneMap.containsKey(entry.value)) {
        throw StateError('Mapping for BCL ${entry.key}/${entry.value} has no corresponding zone.');
      }
    }
    final bclIdMapClone = Map<String, String>.of(_bclIdsToZoneIds);
    return FakeDateTimeZoneSource._NewVersionIdZonesBclToZoneIds(VersionId, zoneMap, bclIdMapClone);
  }
}
