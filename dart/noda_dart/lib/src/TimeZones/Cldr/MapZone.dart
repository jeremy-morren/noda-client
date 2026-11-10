// Ported from NodaTime 6e024dde: src/NodaTime/TimeZones/Cldr/MapZone.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import '../../Utility/HashCodeHelper.dart';
import '../IO/IDateTimeZoneReader.dart';
import '../IO/IDateTimeZoneWriter.dart';

/// Represents a single `<mapZone>` element in the CLDR Windows zone mapping file.
///
/// Equality is defined in a component-wise fashion. When comparing two values for equality, the [TzdbIds] properties
/// must return the same IDs in the same order for the values to be considered equal.
///
/// This type is immutable reference type. See the thread safety section of the user guide for more information.
final class MapZone {
  /// Identifier used for the primary territory of each Windows time zone. A zone mapping with
  /// this territory will always have a single entry. The value of this constant is "001".
  static const String PrimaryTerritory = '001';

  /// Identifier used for the "fixed offset" territory. A zone mapping with
  /// this territory will always have a single entry. The value of this constant is "ZZ".
  static const String FixedOffsetTerritory = 'ZZ';

  /// Gets the Windows system time zone identifier for this mapping, such as "Central Standard Time".
  ///
  /// Most Windows system time zone identifiers use the name for the "standard" part of the zone as
  /// the overall identifier. Don't be fooled: just because a time zone includes "standard" in its identifier
  /// doesn't mean that it doesn't observe daylight saving time.
  final String WindowsId;

  /// Gets the territory code for this mapping.
  ///
  /// This is typically either "001" to indicate that it's the primary territory for this ID, or
  /// "ZZ" to indicate a fixed-offset ID, or a different two-character capitalized code
  /// which indicates the geographical territory.
  final String Territory;

  /// Gets a read-only non-empty collection of TZDB zone identifiers for this mapping, such as
  /// "America/Chicago" and "America/Matamoros" (both of which are TZDB zones associated with the "Central Standard Time"
  /// Windows system time zone).
  ///
  /// For the primary and fixed-offset territory IDs ("001" and "ZZ") this always
  /// contains exactly one time zone ID. The IDs returned are not necessarily canonical in TZDB.
  final List<String> TzdbIds;

  /// Creates a new mapping entry.
  ///
  /// This constructor is only public for the sake of testability.
  ///
  /// [windowsId]: Windows system time zone identifier. Must not be null.
  /// [territory]: Territory code. Must not be null.
  /// [tzdbIds]: List of territory codes. Must not be null, and must not
  /// contains null values.
  MapZone(String windowsId, String territory, List<String> tzdbIds)
      // Dart: null safety checks windowsId, territory and tzdbIds.
      : this._NewWindowsIdTerritoryTzdbIds(windowsId, territory, List<String>.unmodifiable(tzdbIds));

  /// Private constructor to avoid unnecessary list copying (and validation) when deserializing.
  MapZone._NewWindowsIdTerritoryTzdbIds(String windowsId, String territory, List<String> tzdbIds)
      : WindowsId = windowsId,
        Territory = territory,
        TzdbIds = tzdbIds;

  /// Reads a mapping from a reader.
  @internal
  static MapZone Read(IDateTimeZoneReader reader) {
    String windowsId = reader.ReadString();
    String territory = reader.ReadString();
    int count = reader.ReadCount();
    List<String> tzdbIds = List<String>.filled(count, '');
    for (int i = 0; i < count; i++) {
      tzdbIds[i] = reader.ReadString();
    }
    return MapZone._NewWindowsIdTerritoryTzdbIds(windowsId, territory, List<String>.unmodifiable(tzdbIds));
  }

  /// Writes this mapping to a writer.
  ///
  /// [writer]:
  @internal
  void Write(IDateTimeZoneWriter writer) {
    writer.WriteString(WindowsId);
    writer.WriteString(Territory);
    writer.WriteCount(TzdbIds.length);
    for (String id in TzdbIds) {
      writer.WriteString(id);
    }
  }

  /// Compares two [MapZone] values for equality.
  /// See the type documentation for a description of equality semantics.
  ///
  /// [other]: The value to compare this map zone with.
  ///
  /// Returns true if the given value is another map zone equal to this one; false otherwise.
  bool Equals(MapZone? other) =>
      other != null &&
      WindowsId == other.WindowsId &&
      Territory == other.Territory &&
      _SequenceEqual(TzdbIds, other.TzdbIds);

  // Dart: Enumerable.SequenceEqual.
  static bool _SequenceEqual(List<String> first, List<String> second) {
    if (first.length != second.length) return false;
    for (int i = 0; i < first.length; i++) {
      if (first[i] != second[i]) return false;
    }
    return true;
  }

  /// Returns a hash code for this map zone.
  /// See the type documentation for a description of equality semantics.
  ///
  /// Returns a hash code for this map zone.
  @override
  int get hashCode {
    var hash = HashCodeHelper.Initialize().Hash(WindowsId).Hash(Territory);
    for (var id in TzdbIds) {
      hash = hash.Hash(id);
    }
    return hash.Value;
  }

  /// Compares two [MapZone] values for equality.
  /// See the type documentation for a description of equality semantics.
  ///
  /// [other]: The value to compare this map zone with.
  ///
  /// Returns true if the given value is another map zone equal to this one; false otherwise.
  @override
  bool operator ==(Object other) => other is MapZone && Equals(other);

  /// Returns a [String] that represents this instance.
  ///
  /// Returns the value of the current instance, for diagnostic purposes.
  @override
  String toString() => 'Windows ID: $WindowsId; Territory: $Territory; TzdbIds: ${TzdbIds.join(' ')}';
}
