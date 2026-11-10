// Ported from NodaTime 6e024dde: src/NodaTime/TimeZones/TzdbDateTimeZoneSource.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'dart:convert';
import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../DateTimeZone.dart';
import '../Instant.dart';
import '../Offset.dart';
import '../SystemClock.dart';
import '../Utility/InvalidNodaDataException.dart';
import 'Cldr/MapZone.dart';
import 'Cldr/WindowsZones.dart';
import 'HostTimeZone.dart';
import 'IDateTimeZoneSource.dart';
import 'IO/TzdbStreamData.dart';
import 'TzdbBundledData.generated.dart' as bundled;
import 'TzdbZone1970Location.dart';
import 'TzdbZoneLocation.dart';

/// Provides an implementation of [IDateTimeZoneSource] that loads data originating from the
/// [tz database](https://www.iana.org/time-zones) (also known as the IANA Time Zone database, or zoneinfo
/// or Olson database).
///
/// All calls to [ForId] for fixed-offset IDs advertised by the source (i.e. "UTC" and "UTC+/-Offset")
/// will return zones equal to those returned by [DateTimeZone.ForOffset].
///
/// This type is immutable reference type. See the thread safety section of the user guide for more information.
final class TzdbDateTimeZoneSource implements IDateTimeZoneSource {
  /// Gets the [TzdbDateTimeZoneSource] initialised from resources within the NodaTime assembly.
  ///
  /// noda_dart: the tzdb data bundled with noda_dart, decoded on first use.
  static TzdbDateTimeZoneSource get Default => _DefaultHolder.BuiltIn;

  /// Original source data - we delegate to this to create actual DateTimeZone instances,
  /// and for windows mappings.
  final TzdbStreamData _source;

  /// Composite version ID including TZDB and Windows mapping version strings.
  final String _version;

  // Dart: C#'s Lazy<T> fields are plain lazy fields (isolates don't share memory).
  late final Map<String, String> _tzdbToWindowsId = _BuildTzdbToWindowsIdMap();
  late final Map<String, String> _windowsToTzdbId = _BuildWindowsToTzdbId();

  /// Gets a lookup from canonical time zone ID (e.g. "Europe/London") to a group of aliases for that time zone
  /// (e.g. {"Europe/Belfast", "Europe/Guernsey", "Europe/Jersey", "Europe/Isle_of_Man", "GB", "GB-Eire"}).
  ///
  /// The group of values for a key never contains the canonical ID, only aliases. Any time zone
  /// ID which is itself an alias or has no aliases linking to it will not be present in the lookup.
  /// The aliases within a group are returned in alphabetical (ordinal) order.
  ///
  /// noda_dart: NodaTime's `ILookup<string, string>` is a read-only [Map]; null (not empty) for no aliases.
  final Map<String, List<String>> Aliases;

  /// Returns a read-only map from time zone ID to the canonical ID. For example, the key "Europe/Jersey"
  /// would be associated with the value "Europe/London".
  ///
  /// This map contains an entry for every ID returned by [GetIds], where
  /// canonical IDs map to themselves.
  ///
  /// The returned map is read-only; any attempts to call a mutating method will throw
  /// [UnsupportedError].
  Map<String, String> get CanonicalIdMap => _source.TzdbIdMap;

  /// Gets a read-only list of zone locations known to this source, or null if the original source data
  /// does not include zone locations.
  ///
  /// Every zone location's time zone ID is guaranteed to be valid within this source (assuming the source
  /// has been validated).
  List<TzdbZoneLocation>? get ZoneLocations => _source.ZoneLocations;

  /// Gets a read-only list of "zone 1970" locations known to this source, or null if the original source data
  /// does not include zone locations.
  ///
  /// This location data differs from [ZoneLocations] in two important respects:
  /// - Where multiple similar zones exist but only differ in transitions before 1970,
  ///   this location data chooses one zone to be the canonical "post 1970" zone.
  /// - This location data can represent multiple ISO-3166 country codes in a single entry. For example,
  ///   the entry corresponding to "Europe/London" includes country codes GB, GG, JE and IM (Britain,
  ///   Guernsey, Jersey and the Isle of Man, respectively).
  ///
  /// Every zone location's time zone ID is guaranteed to be valid within this source (assuming the source
  /// has been validated).
  List<TzdbZone1970Location>? get Zone1970Locations => _source.Zone1970Locations;

  /// This source returns a string such as "TZDB: 2013b (mapping: 8274)" corresponding to the versions of the tz
  /// database and the CLDR Windows zones mapping file.
  ///
  /// Note that there is no need to parse this string to extract any of the above information, as it is available
  /// directly from the [TzdbVersion] and [WindowsZones.Version] properties.
  @override
  String get VersionId => 'TZDB: $_version';

  // Not ported: FromStream(Stream): use FromBytes or FromBase64.

  /// Creates an instance from the bytes of a file in the custom Noda Time format (an `.nzd` file).
  ///
  /// See the user guide for instructions on how to generate an updated time zone database file from a copy of the
  /// (textual) tz database.
  ///
  /// noda_dart: replaces NodaTime's `FromStream(Stream)`.
  ///
  /// [bytes]: The time zone data
  ///
  /// Returns a `TzdbDateTimeZoneSource` providing information from the given data.
  ///
  /// Throws [InvalidNodaDataException] if the data is invalid time zone data, or data which cannot
  /// be read by this version of Noda Time.
  static TzdbDateTimeZoneSource FromBytes(Uint8List bytes) {
    // Dart: null safety checks bytes.
    return TzdbDateTimeZoneSource.NewSource(TzdbStreamData.FromBytes(bytes));
  }

  /// Creates an instance from the base64 encoding of a file in the custom Noda Time format (an `.nzd` file).
  ///
  /// noda_dart: replaces NodaTime's `FromStream(Stream)`.
  ///
  /// [text]: The base64-encoded time zone data
  ///
  /// Returns a `TzdbDateTimeZoneSource` providing information from the given data.
  ///
  /// Throws [InvalidNodaDataException] if the data is invalid time zone data, or data which cannot
  /// be read by this version of Noda Time; [FormatException] if [text] isn't valid base64.
  static TzdbDateTimeZoneSource FromBase64(String text) {
    // Dart: null safety checks text.
    return FromBytes(base64Decode(text));
  }

  @visibleForTesting
  @internal
  TzdbDateTimeZoneSource.NewSource(TzdbStreamData source)
      // Dart: null safety checks source.
      : _source = source,
        Aliases = _BuildAliases(source.TzdbIdMap),
        _version = '${source.TzdbVersion} (mapping: ${source.WindowsMapping.Version})';

  // Dart: CanonicalIdMap
  //     .Where(pair => pair.Key != pair.Value)
  //     .OrderBy(pair => pair.Key, StringComparer.Ordinal)
  //     .ToLookup(pair => pair.Value, pair => pair.Key)
  static Map<String, List<String>> _BuildAliases(Map<String, String> canonicalIdMap) {
    var aliasPairs = canonicalIdMap.entries.where((pair) => pair.key != pair.value).toList()
      // String.compareTo compares UTF-16 code units: StringComparer.Ordinal.
      ..sort((a, b) => a.key.compareTo(b.key));
    var aliases = <String, List<String>>{};
    for (var pair in aliasPairs) {
      (aliases[pair.value] ??= <String>[]).add(pair.key);
    }
    return Map<String, List<String>>.unmodifiable(
        {for (var entry in aliases.entries) entry.key: List<String>.unmodifiable(entry.value)});
  }

  /// Builds the dictionary returned by [TzdbToWindowsIds]; this is called lazily.
  /// This method assumes the source is valid, for uniqueness purposes etc.
  Map<String, String> _BuildTzdbToWindowsIdMap() {
    var mutable = <String, String>{};
    // First map everything from the WindowsZones.
    for (var zone in WindowsMapping.MapZones.where((mz) => mz.Territory != MapZone.PrimaryTerritory)) {
      for (var tzdbId in zone.TzdbIds) {
        mutable[tzdbId] = zone.WindowsId;
      }
    }

    var aliases = CanonicalIdMap.entries.where((pair) => pair.key != pair.value);

    // Now map any missing canonical IDs based on aliases
    for (var entry in aliases
        // Only find aliases where the canonical ID isn't in the map
        .where((pair) => !mutable.containsKey(pair.value))
        .toList()
      // Order by alias for predictability
      // (noda_dart: ordinal comparison; C#'s OrderBy is culture-sensitive, but the IDs are ASCII.)
      ..sort((a, b) => a.key.compareTo(b.key))) {
      // OrderBy is effectively greedy, so our earlier check for may not still be valid.
      // (An earlier alias may have provided an ID.)
      var windowsId = mutable[entry.key];
      if (!mutable.containsKey(entry.value) && windowsId != null) {
        mutable[entry.value] = windowsId;
      }
    }

    // Finally map any missing aliases based on canonical IDs
    // (Dart: the filter is evaluated lazily as the loop runs, as LINQ's Where is.)
    for (var entry in aliases
        // Only find aliases where the alias ID isn't in the map
        .where((pair) => !mutable.containsKey(pair.key))) {
      // Add a mapping based on the canonical mapping, if it's present.
      var windowsId = mutable[entry.value];
      if (windowsId != null) {
        mutable[entry.key] = windowsId;
      }
    }
    return Map<String, String>.unmodifiable(mutable);
  }

  /// Builds the dictionary returned by [WindowsToTzdbIds]; this is called lazily.
  Map<String, String> _BuildWindowsToTzdbId() => Map<String, String>.unmodifiable({
        for (var pair in WindowsMapping.PrimaryMapping.entries) pair.key: _CanonicalIdFor(pair.value),
      });

  // Dart: CanonicalIdMap[value], whose missing key is KeyNotFoundException in C#.
  String _CanonicalIdFor(String value) {
    var canonical = CanonicalIdMap[value];
    if (canonical == null) {
      throw ArgumentError("The given key '$value' was not present in the dictionary.");
    }
    return canonical;
  }

  @override
  DateTimeZone ForId(String id) {
    // Dart: null safety checks id.
    var canonicalId = CanonicalIdMap[id];
    if (canonicalId == null) {
      throw ArgumentError('Time zone with ID $id not found in source $_version', 'id');
    }
    return _source.CreateZone(id, canonicalId);
  }

  @override
  Iterable<String> GetIds() => CanonicalIdMap.keys;

  /// noda_dart: the system time zone is TZ's if set, else the host's (see `HostTimeZone.dart`).
  @override
  String? GetSystemDefaultId() => MapTimeZoneInfoId(GetHostTimeZone());

  /// Maps a system time zone to a TZDB ID: a Windows ID is mapped through the primary Windows mapping,
  /// a TZDB ID known to this source is returned as-is, and otherwise the zone is guessed by its transitions.
  ///
  /// noda_dart: takes an [IHostTimeZone] rather than a `TimeZoneInfo`. A TZ ID matches ignoring case and is never
  /// guessed: unmapped, it means "Etc/UTC".
  @visibleForTesting
  @internal
  String? MapTimeZoneInfoId(IHostTimeZone? timeZone) {
    // Unusual, but can happen in some Mono installations.
    if (timeZone == null) {
      return null;
    }
    String id = timeZone.Id;
    // First see if it's a Windows time zone ID.
    String? result = _source.WindowsMapping.PrimaryMapping[id];
    if (result != null) {
      return result;
    }
    // Next see if it's already a TZDB ID (e.g. .NET Core running on Linux or Mac).
    if (CanonicalIdMap.containsKey(id)) {
      return id;
    }
    if (timeZone.FromEnvironment) {
      // noda_dart: TZ is hand-written, and the system provider matches it ignoring case, so this does too.
      var matched = _FindEnvironmentIdIgnoringCase(id);
      if (matched != null) {
        return matched;
      }
      // Otherwise it names a zone we don't know: UTC, as for Node, Python, glibc and .NET on Unix.
      return CanonicalIdMap.containsKey('Etc/UTC') ? 'Etc/UTC' : null;
    }
    // Maybe it's a Windows zone we don't have a mapping for, or we're on a Mono system
    // where TimeZoneInfo.Local.Id returns "Local" but can actually do the mappings.
    return _GuessZoneIdByTransitions(timeZone);
  }

  // noda_dart: by upper-cased ID, MapTimeZoneInfoId's result for each Windows ID (first) and TZDB ID.
  late final Map<String, String> _idsIgnoringCase = _BuildIdsIgnoringCase();

  Map<String, String> _BuildIdsIgnoringCase() {
    var ids = <String, String>{};
    for (var entry in _source.WindowsMapping.PrimaryMapping.entries) {
      ids.putIfAbsent(entry.key.toUpperCase(), () => entry.value);
    }
    for (var tzdbId in CanonicalIdMap.keys) {
      ids.putIfAbsent(tzdbId.toUpperCase(), () => tzdbId);
    }
    return ids;
  }

  /// noda_dart: MapTimeZoneInfoId's result for a Windows or TZDB ID matched ignoring case, or null.
  String? _FindEnvironmentIdIgnoringCase(String id) => _idsIgnoringCase[id.toUpperCase()];

  // Dart: isolates don't share memory (C#: ConcurrentDictionary).
  final Map<String, String?> _guesses = <String, String?>{};

  // Cache around GuessZoneIdByTransitionsUncached
  String? _GuessZoneIdByTransitions(IHostTimeZone zone) => _guesses.putIfAbsent(zone.Id, () {
        // Build the list of candidates here instead of within the method, so that
        // tests can pass in the same list on each iteration. We order the time zones
        // by ID so that if there are multiple zones with the same score, we'll always
        // pick the same one across multiple runs/platforms.
        // noda_dart: in ordinal order (NodaTime's OrderBy uses the current culture's comparer).
        var candidates = CanonicalIdMap.values.map(ForId).toList()..sort((a, b) => a.Id.compareTo(b.Id));
        return GuessZoneIdByTransitionsUncached(zone, candidates);
      });

  /// In cases where we can't get a zone mapping directly, we try to work out a good fit
  /// by checking the transitions within the next few years.
  /// This can happen if the Windows data isn't up-to-date, or if we're on a system where
  /// TimeZoneInfo.Local.Id just returns "local", or if TimeZoneInfo.Local is a custom time
  /// zone for some reason. We return null if we don't get a 70% hit rate.
  /// We look at all transitions in all canonical IDs for the next 5 years.
  /// Heuristically, this seems to be good enough to get the right results in most cases.
  /// This method used to only be called in the PCL build in 1.x, but it seems reasonable enough to
  /// call it if we can't get an exact match anyway.
  ///
  /// [zone]: Zone to resolve in a best-effort fashion.
  /// [candidates]: All the Noda Time zones to consider - normally a list
  /// obtained from this source.
  @internal
  static String? GuessZoneIdByTransitionsUncached(IHostTimeZone zone, List<DateTimeZone> candidates) {
    // See https://github.com/nodatime/nodatime/issues/686 for performance observations.
    // Very rare use of the system clock! Windows time zone updates sometimes sacrifice past
    // accuracy for future accuracy, so let's use the current year's transitions.
    int thisYear = SystemClock.Instance.GetCurrentInstant().InUtc().Year;
    Instant startOfThisYear = Instant.FromUtc(thisYear, 1, 1, 0, 0);
    Instant startOfNextYear = Instant.FromUtc(thisYear + 5, 1, 1, 0, 0);
    // Dart: Distinct() keeps the first occurrence of each value, in order, as a Dart (linked hash) Set does.
    var instants = candidates
        .expand((z) => z.GetZoneIntervals(startOfThisYear, startOfNextYear))
        .map((zi) => Instant.Max(zi.RawStart, startOfThisYear)) // Clamp to start of interval
        .toSet()
        .toList();
    // noda_dart: the host zone gives Offsets directly (C#: Offset.FromTimeSpan(zone.GetUtcOffset(instant.ToDateTimeUtc()))).
    List<Offset> bclOffsets = instants.map((instant) => zone.GetUtcOffset(instant)).toList();
    // For a zone to be mappable, at most 30% of the checks must fail
    // - so if we get to that number (or whatever our "best" so far is)
    // we know we can stop for any particular zone.
    int lowestFailureScore = (instants.length * 30) ~/ 100;
    DateTimeZone? bestZone;
    for (var candidate in candidates) {
      int failureScore = 0;
      for (int i = 0; i < instants.length; i++) {
        if (candidate.GetUtcOffset(instants[i]) != bclOffsets[i]) {
          failureScore++;
          if (failureScore == lowestFailureScore) {
            break;
          }
        }
      }
      if (failureScore < lowestFailureScore) {
        lowestFailureScore = failureScore;
        bestZone = candidate;
      }
    }
    return bestZone?.Id;
  }

  /// Gets just the TZDB version (e.g. "2013a") of the source data.
  String get TzdbVersion => _source.TzdbVersion;

  /// Gets the Windows time zone mapping information provided in the CLDR
  /// supplemental "windowsZones.xml" file.
  WindowsZones get WindowsMapping => _source.WindowsMapping;

  /// Returns a dictionary mapping TZDB IDs to Windows IDs.
  ///
  /// Where a TZDB alias isn't present directly in the Windows mapping, but its canonical ID is,
  /// the dictionary will contain an entry for the alias as well. For example, the TZDB ID
  /// "Africa/Asmara" is an alias for "Africa/Nairobi", which has a Windows ID of "E. Africa Standard Time".
  /// "Africa/Asmara" doesn't appear in the Windows mapping directly, but it will still be present in the
  /// returned dictionary.
  ///
  /// Where a TZDB canonical ID isn't present in the Windows mapping, but an alias is, the dictionary
  /// will contain an entry for the canonical ID as well. For example, the Windows mapping uses the
  /// TZDB ID "Asia/Calcutta" for "India Standard Time". This is an alias for "Asia/Kolkata" in TZDB,
  /// so the returned dictionary will have an entry mapping "Asia/Kolkata" to "Asia/Calcutta".
  /// If multiple aliases for the same canonical ID have entries in the Windows mapping with different
  /// Windows IDs, the alias that is earliest in lexicographical ordering determines the value for the entry.
  ///
  /// If a canonical ID is not present in the mapping, nor any of its aliases, it will not be present in
  /// the returned dictionary.
  Map<String, String> get TzdbToWindowsIds => _tzdbToWindowsId;

  /// Returns a dictionary mapping Windows IDs to canonical TZDB IDs, using the
  /// primary mapping in each [MapZone].
  ///
  /// Sometimes the Windows mapping contains values which are not canonical TZDB IDs.
  /// Every value in the returned dictionary is a canonical ID. For example, the Windows
  /// mapping contains as "Asia/Calcutta" for the Windows ID "India Standard Time", but
  /// "Asia/Calcutta" is an alias for "Asia/Kolkata". The entry for "India Standard Time"
  /// in the returned dictionary therefore has "Asia/Kolkata" as the value.
  Map<String, String> get WindowsToTzdbIds => _windowsToTzdbId;

  /// Validates that the data within this source is consistent with itself.
  ///
  /// Source data is not validated automatically when it's loaded, but any source
  /// loaded from data produced by `NodaTime.TzdbCompiler` (including the data shipped with Noda Time)
  /// will already have been validated via this method when it was originally produced. This method should
  /// only normally be called explicitly if you have data from a source you're unsure of.
  ///
  /// Throws [InvalidNodaDataException] if the source data is invalid. The source may not function
  /// correctly.
  void Validate() {
    // Check that each entry has a canonical value. (Every mapping x to y
    // should be such that y maps to itself.)
    for (var entry in CanonicalIdMap.entries) {
      String? canonical = CanonicalIdMap[entry.value];
      if (canonical == null) {
        throw InvalidNodaDataException('Mapping for entry ${entry.key} (${entry.value}) is missing');
      }
      if (entry.value != canonical) {
        throw InvalidNodaDataException(
            'Mapping for entry ${entry.key} (${entry.value}) is not canonical (${entry.value} maps to $canonical)');
      }
    }

    // Check that every Windows mapping has a primary territory
    for (var mapZone in WindowsMapping.MapZones) {
      // Simplest way of checking is to find the primary mapping...
      if (!_source.WindowsMapping.PrimaryMapping.containsKey(mapZone.WindowsId)) {
        throw InvalidNodaDataException('Windows mapping for standard ID ${mapZone.WindowsId} has no primary territory');
      }
    }

    // Check Windows mappings:
    // - Each MapZone uses TZDB IDs that are known to this source,
    // - Each TZDB ID only occurs once except for the primary territory
    // - Every ID has a primary territory
    // - Within each ID, the territories are unique
    // - Each primary territory TZDB ID occurs as a non-primary territory
    Set<String> mappedTzdbIds = <String>{};
    for (var mapZone in WindowsMapping.MapZones) {
      for (var id in mapZone.TzdbIds) {
        if (!CanonicalIdMap.containsKey(id)) {
          throw InvalidNodaDataException('Windows mapping uses TZDB ID $id which is missing');
        }
        // The primary territory ID is also present as a non-primary territory,
        // so don't include it in duplicate detection. Everything else should be unique.
        if (mapZone.Territory != MapZone.PrimaryTerritory && !mappedTzdbIds.add(id)) {
          throw InvalidNodaDataException('Windows mapping has multiple entries for TZDB ID $id');
        }
      }
    }
    // Dart: WindowsMapping.MapZones.ToLookup(mapZone => mapZone.WindowsId), in order of first occurrence.
    var territoriesByWindowsId = <String, List<MapZone>>{};
    for (var mapZone in WindowsMapping.MapZones) {
      (territoriesByWindowsId[mapZone.WindowsId] ??= <MapZone>[]).add(mapZone);
    }
    for (var group in territoriesByWindowsId.entries) {
      if (group.value.map((zone) => zone.Territory).toSet().length != group.value.length) {
        throw InvalidNodaDataException('Windows mapping has duplicate territories entries for Windows ID ${group.key}');
      }
      var primary = group.value.where((zone) => zone.Territory == MapZone.PrimaryTerritory).firstOrNull;
      if (primary == null) {
        throw InvalidNodaDataException('Windows mapping has no primary territory entry for Windows ID ${group.key}');
      }
      // Dart: Single() throws InvalidOperationException (StateError) unless there's exactly one ID, as Dart's single does.
      var primaryTzdb = primary.TzdbIds.single;
      if (!group.value
          .any((zone) => zone.Territory != MapZone.PrimaryTerritory && zone.TzdbIds.contains(primaryTzdb))) {
        throw InvalidNodaDataException(
            'Windows mapping primary territory entry for Windows ID ${group.key} has TZDB ID $primaryTzdb which does not occur in a non-primary territory');
      }
    }

    // Check that each zone location has a valid zone ID
    var zoneLocations = ZoneLocations;
    if (zoneLocations != null) {
      for (var location in zoneLocations) {
        if (!CanonicalIdMap.containsKey(location.ZoneId)) {
          throw InvalidNodaDataException(
              'Zone location ${location.CountryName} uses zone ID ${location.ZoneId} which is missing');
        }
      }
    }
    var zone1970Locations = Zone1970Locations;
    if (zone1970Locations != null) {
      for (var location in zone1970Locations) {
        if (!CanonicalIdMap.containsKey(location.ZoneId)) {
          throw InvalidNodaDataException(
              'Zone 1970 location ${location.Countries[0].Name} uses zone ID ${location.ZoneId} which is missing');
        }
      }
    }
  }
}

// Class to enable lazy initialization of the default instance.
// (Dart: a static final field is initialized on first use.)
abstract final class _DefaultHolder {
  static final TzdbDateTimeZoneSource BuiltIn = TzdbDateTimeZoneSource.NewSource(_LoadDefaultDataSource());

  // noda_dart: the bundled NZD bytes (TzdbBundledData.generated.dart) rather than an assembly resource.
  static TzdbStreamData _LoadDefaultDataSource() => TzdbStreamData.FromBytes(bundled.nzdBytes);
}
