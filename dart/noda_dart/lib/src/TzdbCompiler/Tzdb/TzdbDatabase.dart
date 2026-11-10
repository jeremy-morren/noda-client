// Ported from NodaTime 6e024dde: src/NodaTime.TzdbCompiler/Tzdb/TzdbDatabase.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import '../../DateTimeZone.dart';
import '../../TimeZones/Cldr/MapZone.dart';
import '../../TimeZones/Cldr/WindowsZones.dart';
import '../../TimeZones/TzdbDateTimeZoneSource.dart';
import '../../TimeZones/TzdbZone1970Location.dart';
import '../../TimeZones/TzdbZoneLocation.dart';
import '../../Utility/Stream.dart';
import '../Shims.dart';
import 'DateTimeZoneBuilder.dart';
import 'RuleLine.dart';
import 'TzdbStreamWriter.dart';
import 'ZoneLine.dart';

/// Provides a container for the definitions parsed from the TZDB zone info files.
class TzdbDatabase {
  /// Returns the zone lists. This is only available for the sake of testing.
  @internal
  final Map<String, List<ZoneLine>> Zones;

  /// Returns the version of the TZDB data represented.
  final String Version;

  /// Returns the (mutable) map of links from alias to canonical ID.
  final Map<String, String> Aliases;

  /// Mapping from rule name to the zone rules for that name. This is only available for the sake of testing.
  @internal
  final Map<String, List<RuleLine>> Rules;

  /// A list of the zone locations known to this database from zone.tab.
  @internal
  List<TzdbZoneLocation>? ZoneLocations;

  /// A list of the zone locations known to this database from zone1970.tab.
  @internal
  List<TzdbZone1970Location>? Zone1970Locations;

  /// Initializes a new instance of the [TzdbDatabase] class.
  TzdbDatabase(String version)
      : Zones = <String, List<ZoneLine>>{},
        Rules = <String, List<RuleLine>>{},
        Aliases = <String, String>{},
        Version = version;

  /// Returns the data in this database as a [TzdbDateTimeZoneSource] with no
  /// Windows mappings.
  TzdbDateTimeZoneSource ToTzdbDateTimeZoneSource() {
    final ms = MemoryStream();
    final writer = TzdbStreamWriter();
    writer.Write(
        this,
        WindowsZones.NewVersionTzdbVersionWindowsVersionMapZones('n/a', Version, 'n/a', <MapZone>[]), // No Windows mappings,
        <String, String>{}, // No additional name-to-id mappings
        ms);
    // noda_dart: FromBytes, for TzdbDateTimeZoneSource.FromStream(ms) after ms.Position = 0.
    return TzdbDateTimeZoneSource.FromBytes(ms.ToArray());
  }

  /// Adds the given zone alias to the database.
  ///
  /// [existing]: The existing zone ID to map the alias to.
  /// [alias]: The zone alias to add.
  @internal
  void AddAlias(String existing, String alias) {
    AddValue(Aliases, alias, existing);
  }

  /// Adds the given rule to the appropriate rule set. If there is no existing
  /// rule set, one is created and added to the database.
  ///
  /// [rule]: The rule to add.
  @internal
  void AddRule(RuleLine rule) {
    var ruleSet = Rules[rule.Name];
    if (ruleSet == null) {
      ruleSet = <RuleLine>[];
      Rules[rule.Name] = ruleSet;
    }
    ruleSet.add(rule);
  }

  /// Adds the given zone line to the database, creating a new list for
  /// that zone ID if necessary.
  ///
  /// [zone]: The zone to add.
  @internal
  void AddZone(ZoneLine zone) {
    var zoneSet = Zones[zone.Name];
    if (zoneSet == null) {
      zoneSet = <ZoneLine>[];
      Zones[zone.Name] = zoneSet;
    }
    zoneSet.add(zone);
  }

  /// Converts a single zone into a DateTimeZone. As well as for testing purposes,
  /// this can be used to resolve aliases.
  ///
  /// [zoneId]: The ID of the zone to convert.
  DateTimeZone GenerateDateTimeZone(String zoneId) {
    var zoneListKey = zoneId;
    // Recursively resolve aliases
    while (Aliases.containsKey(zoneListKey)) {
      zoneListKey = Aliases[zoneListKey]!;
    }
    return _CreateTimeZone(zoneId, GetValue(Zones, zoneListKey));
  }

  /// Converts each zone in the database into a DateTimeZone.
  Iterable<DateTimeZone> GenerateDateTimeZones() sync* {
    final keys = Zones.keys.toList()..sort(CompareOrdinal);
    for (final key in keys) {
      yield _CreateTimeZone(key, Zones[key]!);
    }
  }

  /// Returns a newly created [DateTimeZone] built from the given time zone data.
  ///
  /// [zoneList]: The time zone definition parts to add.
  DateTimeZone _CreateTimeZone(String id, List<ZoneLine> zoneList) {
    final ruleSets = zoneList.map((zone) => zone.ResolveRules(Rules)).toList();
    return DateTimeZoneBuilder.Build(id, ruleSets);
  }

  /// Writes various informational counts to the log.
  ///
  /// noda_dart: NodaTime writes to the console; this writes each line to [log].
  @internal
  void LogCounts(void Function(String line) log) {
    log('=======================================');
    log('Rule sets:    ${Rules.length}');
    log('Zones:        ${Zones.length}');
    log('Aliases:      ${Aliases.length}');
    log('Zone locations: ${ZoneLocations?.length ?? 0}');
    log('Zone1970 locations: ${Zone1970Locations?.length ?? 0}');
    log('=======================================');
  }
}
