// Ported from NodaTime 6e024dde: src/NodaTime/TimeZones/DateTimeZoneCache.cs
// Copyright 2010 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import '../DateTimeZone.dart';
import '../IDateTimeZoneProvider.dart';
import 'DateTimeZoneNotFoundException.dart';
import 'FixedDateTimeZone.dart';
import 'IDateTimeZoneSource.dart';
import 'InvalidDateTimeZoneSourceException.dart';

/// Provides an implementation of [IDateTimeZoneProvider] that caches results from an
/// [IDateTimeZoneSource].
///
/// The process of loading or creating time zones may be an expensive operation. This class implements an
/// unlimited-size non-expiring cache over a time zone source, and adapts an implementation of the
/// `IDateTimeZoneSource` interface to an `IDateTimeZoneProvider`.
///
/// See also [DateTimeZoneProviders].
// Public only; caches are naturally mutable internally.
final class DateTimeZoneCache implements IDateTimeZoneProvider {
  final IDateTimeZoneSource _source;
  // Dart: isolates don't share memory (C#: ConcurrentDictionary).
  final Map<String, DateTimeZone?> _timeZoneMap = <String, DateTimeZone?>{};

  /// Gets the version ID of this provider. This is simply the [IDateTimeZoneSource.VersionId] returned by
  /// the underlying source.
  @override
  final String VersionId;

  @override
  late final List<String> Ids;

  /// Creates a provider backed by the given [IDateTimeZoneSource].
  ///
  /// Note that the source will never be consulted for requests for the fixed-offset timezones "UTC" and
  /// "UTC+/-Offset" (a standard implementation will be returned instead). This is true even if these IDs are
  /// advertised by the source.
  ///
  /// [source]: The [IDateTimeZoneSource] for this provider.
  ///
  /// Throws [InvalidDateTimeZoneSourceException] if [source] violates its contract.
  DateTimeZoneCache(IDateTimeZoneSource source)
      // Dart: null safety checks source.
      : _source = source,
        VersionId = source.VersionId {
    // Dart: null safety checks that the source's version ID, its ID sequence and the IDs in it aren't null
    // (C#: InvalidDateTimeZoneSourceException).
    var providerIds = source.GetIds();
    var idList = List<String>.of(providerIds);
    // Dart's String.compareTo compares UTF-16 code units: StringComparer.Ordinal.
    idList.sort((a, b) => a.compareTo(b));
    Ids = List<String>.unmodifiable(idList);
    // Populate the dictionary with null values meaning "the ID is valid, we haven't fetched the zone yet".
    for (String id in Ids) {
      _timeZoneMap[id] = null;
    }
  }

  @override
  DateTimeZone GetSystemDefault() {
    String? id = _source.GetSystemDefaultId();
    if (id == null) {
      throw DateTimeZoneNotFoundException('System default time zone is unknown to source $VersionId');
    }
    return this[id];
  }

  @override
  DateTimeZone? GetZoneOrNull(String id) {
    // Dart: null safety checks id.
    return _GetZoneFromSourceOrNull(id) ?? FixedDateTimeZone.GetFixedZoneOrNull(id);
  }

  DateTimeZone? _GetZoneFromSourceOrNull(String id) {
    if (!_timeZoneMap.containsKey(id)) {
      return null;
    }
    DateTimeZone? zone = _timeZoneMap[id];
    // Ask the source for the zone. Multiple threads *may* do the same thing, but
    // that's hidden from the user: only one thread will update the map, and
    // all other threads will use that value.
    if (zone == null) {
      // Dart: null safety checks that the source returned a zone (C#: InvalidDateTimeZoneSourceException
      // "Time zone {id} is supported by source {VersionId} but not returned").
      zone = _source.ForId(id);
      // Dart: isolates don't share memory, so C#'s TryUpdate always succeeds.
      _timeZoneMap[id] = zone;
      return zone;
    }
    return zone;
  }

  @override
  DateTimeZone operator [](String id) {
    var zone = GetZoneOrNull(id);
    if (zone == null) {
      throw DateTimeZoneNotFoundException('Time zone $id is unknown to source $VersionId');
    }
    return zone;
  }
}
