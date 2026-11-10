// Ported from NodaTime 6e024dde: src/NodaTime/TimeZones/CachingZoneIntervalMap.cs
// Copyright 2012 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'dart:math' as math;

import 'package:meta/meta.dart';

import '../Duration.dart';
import '../Instant.dart';
import '../Offset.dart';
import 'IZoneIntervalMap.dart';
import 'ZoneInterval.dart';

/// Helper methods for creating IZoneIntervalMaps which cache results.
@internal
abstract final class CachingZoneIntervalMap {
  // Currently the only implementation is HashArrayCache. This container class is mostly for historical
  // reasons; it's not really necessary but it does no harm.

  /// Returns a caching map for the given input map.
  @internal
  static IZoneIntervalMap CacheMap(IZoneIntervalMap map) {
    return _CachingZoneIntervalMapHashArrayCache._NewMap(map);
  }
}

// #region Nested type: HashArrayCache
/// This provides a simple cache based on two hash tables (one for local instants, another
/// for instants).
///
/// Each hash table entry is either entry or contains a node with enough
/// information for a particular "period" of 32 days - so multiple calls for time
/// zone information within the same few years are likely to hit the cache. Note that
/// a single "period" may include a daylight saving change (or conceivably more than one);
/// a node therefore has to contain enough intervals to completely represent that period.
///
/// If another call is made which maps to the same cache entry number but is for a different
/// period, the existing hash entry is simply overridden.
final class _CachingZoneIntervalMapHashArrayCache implements IZoneIntervalMap {
  // Currently we have no need or way to create hash cache zones with
  // different cache sizes. But the cache size should always be a power of 2 to get the
  // "period to cache entry" conversion simply as a bitmask operation.
  static const int _CacheSize = 512;
  // Mask to AND the period number with in order to get the cache entry index. The
  // result will always be in the range [0, CacheSize).
  static const int _CachePeriodMask = _CacheSize - 1;

  @override
  Offset get MinOffset => _map.MinOffset;
  @override
  Offset get MaxOffset => _map.MaxOffset;

  /// Defines the number of bits to shift an instant's "days since epoch" to get the period. This
  /// converts an instant into a number of 32 day periods.
  static const int _PeriodShift = 5;

  final List<_CachingZoneIntervalMapHashArrayCacheHashCacheNode?> _instantCache;
  final IZoneIntervalMap _map;

  _CachingZoneIntervalMapHashArrayCache._NewMap(IZoneIntervalMap map)
      // Dart: null safety checks map.
      : _map = map,
        _instantCache = List<_CachingZoneIntervalMapHashArrayCacheHashCacheNode?>.filled(_CacheSize, null);

  /// Gets the zone offset period for the given instant. Null is returned if no period is
  /// defined by the time zone for the given instant.
  ///
  /// [instant]: The Instant to test.
  ///
  /// Returns the defined ZoneOffsetPeriod or null.
  @override
  ZoneInterval GetZoneInterval(Instant instant) {
    // noda_dart: toSigned(32) after >>, as dart2js's >> gives an unsigned 32-bit result for a negative value.
    int period = (instant.DaysSinceEpoch >> _PeriodShift).toSigned(32);
    int index = period & _CachePeriodMask;
    var node = _instantCache[index];
    if (node == null || node.Period != period) {
      node = _CachingZoneIntervalMapHashArrayCacheHashCacheNode.CreateNode(period, _map);
      _instantCache[index] = node;
    }

    // Note: moving this code into an instance method in HashCacheNode makes a surprisingly
    // large performance difference.
    while (node!.Previous != null && node.Interval.RawStart > instant) {
      node = node.Previous;
    }
    return node.Interval;
  }
}

// #region Nested type: HashCacheNode
// Note: I (Jon) have tried optimizing this as a struct containing two ZoneIntervals
// and a list of zone intervals (normally null) for the rare case where there are more
// than two zone intervals in a period. It halved the performance...
final class _CachingZoneIntervalMapHashArrayCacheHashCacheNode {
  final ZoneInterval Interval;

  final int Period;

  final _CachingZoneIntervalMapHashArrayCacheHashCacheNode? Previous;

  /// Creates a hash table node with all the information for this period.
  /// We start off by finding the interval for the start of the period, and
  /// then repeatedly check whether that interval ends after the end of the
  /// period - at which point we're done. If not, find the next interval, create
  /// a new node referring to that interval and the previous interval, and keep going.
  static _CachingZoneIntervalMapHashArrayCacheHashCacheNode CreateNode(int period, IZoneIntervalMap map) {
    // noda_dart: toSigned(32), as dart2js's << gives an unsigned 32-bit result (for a period before 1970).
    var days = (period << _CachingZoneIntervalMapHashArrayCache._PeriodShift).toSigned(32);
    var periodStart = Instant.FromTrustedDuration(Duration.NewDaysNanoOfDay(math.max(days, Instant.MinDays), 0));
    var nextPeriodStartDays = days + (1 << _CachingZoneIntervalMapHashArrayCache._PeriodShift);

    var interval = map.GetZoneInterval(periodStart);
    var node = _CachingZoneIntervalMapHashArrayCacheHashCacheNode._NewIntervalPeriodPrevious(interval, period, null);

    // Keep going while the current interval ends before the period.
    // (We only need to check the days, as every period lands on a
    // day boundary.)
    // If the raw end is the end of time, the condition will definitely
    // evaluate to false.
    while (interval.RawEnd.DaysSinceEpoch < nextPeriodStartDays) {
      interval = map.GetZoneInterval(interval.End);
      node = _CachingZoneIntervalMapHashArrayCacheHashCacheNode._NewIntervalPeriodPrevious(interval, period, node);
    }

    return node;
  }

  /// Initializes a new instance of the [_CachingZoneIntervalMapHashArrayCacheHashCacheNode] class.
  ///
  /// [interval]: The zone interval.
  /// [period]:
  /// [previous]: The previous [_CachingZoneIntervalMapHashArrayCacheHashCacheNode] node.
  _CachingZoneIntervalMapHashArrayCacheHashCacheNode._NewIntervalPeriodPrevious(
      ZoneInterval interval, int period, _CachingZoneIntervalMapHashArrayCacheHashCacheNode? previous)
      : Period = period,
        Interval = interval,
        Previous = previous;
}
// #endregion
// #endregion
