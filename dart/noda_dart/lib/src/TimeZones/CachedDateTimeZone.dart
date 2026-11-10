// Ported from NodaTime 6e024dde: src/NodaTime/TimeZones/CachedDateTimeZone.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import '../DateTimeZone.dart';
import '../Instant.dart';
import 'CachingZoneIntervalMap.dart';
import 'IZoneIntervalMap.dart';
import 'ZoneInterval.dart';

///  Provides a [DateTimeZone] wrapper class that implements a simple cache to
///  speed up the lookup of transitions.
///
/// The cache supports multiple caching strategies which are implemented in nested subclasses of
/// this one. Until we have a better sense of what the usage behavior is, we cannot tune the
/// cache. It is possible that we may support multiple strategies selectable at runtime so the
/// user can tune the performance based on their knowledge of how they are using the system.
///
/// In fact, only one cache type is currently implemented: an MRU cache existed before
/// the GetZoneIntervalPair call was created in DateTimeZone, but as it wasn't being used, it
/// was more effort than it was worth to update. The mechanism is still available for future
/// expansion though.
@internal
final class CachedDateTimeZone extends DateTimeZone {
  final IZoneIntervalMap _map;

  /// Gets the cached time zone.
  @internal
  final DateTimeZone TimeZone;

  /// Initializes a new instance of the [CachedDateTimeZone] class.
  ///
  /// [timeZone]: The time zone to cache.
  /// [map]: The caching map
  CachedDateTimeZone._NewTimeZoneMap(DateTimeZone timeZone, IZoneIntervalMap map)
      : TimeZone = timeZone,
        _map = map,
        super(timeZone.Id, false, timeZone.MinOffset, timeZone.MaxOffset);

  /// Returns a cached time zone for the given time zone.
  ///
  /// If the time zone is already cached or it is fixed then it is returned unchanged.
  ///
  /// [timeZone]: The time zone to cache.
  ///
  /// Returns the cached time zone.
  @internal
  static DateTimeZone ForZone(DateTimeZone timeZone) {
    // Dart: null safety checks timeZone.
    if (timeZone is CachedDateTimeZone || timeZone.IsFixed) {
      return timeZone;
    }
    return CachedDateTimeZone._NewTimeZoneMap(timeZone, CachingZoneIntervalMap.CacheMap(timeZone));
  }

  /// Delegates fetching a zone interval to the caching map.
  @override
  ZoneInterval GetZoneInterval(Instant instant) {
    return _map.GetZoneInterval(instant);
  }
}
