// Ported from NodaTime 6e024dde: src/NodaTime/TimeZones/ZoneEqualityComparer.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import '../DateTimeZone.dart';
import '../Instant.dart';
import '../Interval.dart';
import '../Utility/Comparers.dart';
import '../Utility/HashCodeHelper.dart';
import '../Utility/Preconditions.dart';
import 'ZoneEqualityComparer.Options.generated.dart';
import 'ZoneInterval.dart';

/// Equality comparer for time zones, comparing specific aspects of the zone intervals within
/// a time zone for a specific interval of the time line.
///
/// The default behaviour of this comparator is to consider two time zones to be equal if they share the same wall
/// offsets at all points within a given time interval, regardless of other aspects of each
/// [ZoneInterval] within the two time zones. This behaviour can be changed using the
/// [WithOptions] method.
final class ZoneEqualityComparer implements IEqualityComparer<DateTimeZone?> {
  // Dart: the nested enum Options is ZoneEqualityComparerOptions (ZoneEqualityComparer.Options.generated.dart).

  /// Checks whether the given set of options includes the candidate one. This would be an extension method, but
  /// that causes problems on Mono at the moment.
  static bool _CheckOption(ZoneEqualityComparerOptions options, ZoneEqualityComparerOptions candidate) {
    return (options & candidate).value != 0;
  }

  final Interval _interval;
  final ZoneEqualityComparerOptions _options;

  /// Returns the interval over which this comparer operates.
  @visibleForTesting
  @internal
  Interval get IntervalForTest => _interval;

  /// Returns the options used by this comparer.
  @visibleForTesting
  @internal
  ZoneEqualityComparerOptions get OptionsForTest => _options;

  late final ZoneEqualityComparerZoneIntervalEqualityComparer _zoneIntervalComparer;

  /// Creates a new comparer for the given interval, with the given comparison options.
  ///
  /// [interval]: The interval within the time line to use for comparisons.
  /// [options]: The options to use when comparing time zones.
  ///
  /// Throws [RangeError] if the specified options are invalid.
  ZoneEqualityComparer._NewIntervalOptions(Interval interval, ZoneEqualityComparerOptions options)
      : _interval = interval,
        _options = options {
    if ((options & ~ZoneEqualityComparerOptions.StrictestMatch).value != 0) {
      throw RangeError.value(
          options.value, 'options', 'The value ${options.Name} is not defined within ZoneEqualityComparer.Options');
    }
    _zoneIntervalComparer = ZoneEqualityComparerZoneIntervalEqualityComparer.NewOptionsInterval(options, interval);
  }

  /// Returns a [ZoneEqualityComparer] for the given interval with the default options.
  ///
  /// The default behaviour of this comparator is to consider two time zones to be equal if they share the same wall
  /// offsets at all points within a given interval.
  /// To specify non-default options, call the [WithOptions] method on the result
  /// of this method.
  ///
  /// [interval]: The interval over which to compare time zones. This must have both a start and an end.
  ///
  /// Returns a ZoneEqualityComparer for the given interval with the default options.
  static ZoneEqualityComparer ForInterval(Interval interval) {
    Preconditions.CheckArgument(interval.HasStart && interval.HasEnd, 'interval',
        'The interval must have both a start and an end.');
    return ZoneEqualityComparer._NewIntervalOptions(interval, ZoneEqualityComparerOptions.OnlyMatchWallOffset);
  }

  /// Returns a comparer operating over the same interval as this one, but with the given
  /// set of options.
  ///
  /// This method does not modify the comparer on which it's called.
  ///
  /// [options]: New set of options, which must consist of flags defined within the [ZoneEqualityComparerOptions] enum.
  ///
  /// Throws [RangeError] if the specified options are invalid.
  ///
  /// Returns a comparer operating over the same interval as this one, but with the given set of options.
  ZoneEqualityComparer WithOptions(ZoneEqualityComparerOptions options) {
    return _options == options ? this : ZoneEqualityComparer._NewIntervalOptions(_interval, options);
  }

  /// Compares two time zones for equality according to the options and interval provided to this comparer.
  ///
  /// [x]: The first [DateTimeZone] to compare.
  /// [y]: The second [DateTimeZone] to compare.
  ///
  /// Returns `true` if the specified time zones are equal under the options and interval of this comparer; otherwise, `false`.
  @override
  bool Equals(DateTimeZone? x, DateTimeZone? y) {
    if (identical(x, y)) {
      return true;
    }
    if (x == null || y == null) {
      return false;
    }
    // If we ever need to port this to a platform which doesn't support LINQ,
    // we'll need to reimplement this. Until then, it would seem pointless...
    // Dart: Enumerable.SequenceEqual(second, comparer).
    var xIntervals = _GetIntervals(x).iterator;
    var yIntervals = _GetIntervals(y).iterator;
    while (xIntervals.moveNext()) {
      if (!yIntervals.moveNext() || !_zoneIntervalComparer.Equals(xIntervals.current, yIntervals.current)) {
        return false;
      }
    }
    return !yIntervals.moveNext();
  }

  /// Returns a hash code for the specified time zone.
  ///
  /// The hash code generated by any instance of `ZoneEqualityComparer` will be equal to the hash code
  /// generated by any other instance constructed with the same options and interval, for the same time zone (or equal ones).
  /// Two instances of `ZoneEqualityComparer` with different options or intervals may (but may not) produce
  /// different hash codes for the same zone.
  ///
  /// [obj]: The time zone to compute a hash code for.
  ///
  /// Returns a hash code for the specified object.
  @override
  int GetHashCode(DateTimeZone? obj) {
    Preconditions.CheckNotNull(obj, 'obj');
    // unchecked
    int hash = 19;
    for (var zoneInterval in _GetIntervals(obj!)) {
      hash = (hash * 31 + _zoneIntervalComparer.GetHashCode(zoneInterval)).toSigned(32);
    }
    return hash;
  }

  Iterable<ZoneInterval> _GetIntervals(DateTimeZone zone) {
    var allIntervals = zone.GetZoneIntervals(_interval.Start, _interval.End);
    return _CheckOption(_options, ZoneEqualityComparerOptions.MatchAllTransitions)
        ? allIntervals
        : _zoneIntervalComparer.CoalesceIntervals(allIntervals);
  }
}

@internal
final class ZoneEqualityComparerZoneIntervalEqualityComparer implements IEqualityComparer<ZoneInterval> {
  final ZoneEqualityComparerOptions _options;
  final Interval _interval;

  @internal
  ZoneEqualityComparerZoneIntervalEqualityComparer.NewOptionsInterval(
      ZoneEqualityComparerOptions options, Interval interval)
      : _options = options,
        _interval = interval;

  @internal
  Iterable<ZoneInterval> CoalesceIntervals(Iterable<ZoneInterval> zoneIntervals) sync* {
    ZoneInterval? current;
    for (var zoneInterval in zoneIntervals) {
      if (current == null) {
        current = zoneInterval;
        continue;
      }
      if (_EqualExceptStartAndEnd(current, zoneInterval)) {
        current = current.WithEnd(zoneInterval.RawEnd);
      } else {
        yield current;
        current = zoneInterval;
      }
    }
    // current will only be null if start == end...
    if (current != null) {
      yield current;
    }
  }

  // This is only called with non-null zone intervals - we never expose it.
  @override
  bool Equals(ZoneInterval x, ZoneInterval y) {
    if (!_EqualExceptStartAndEnd(x, y)) {
      return false;
    }
    return _GetEffectiveStart(x) == _GetEffectiveStart(y) &&
        _GetEffectiveEnd(x) == _GetEffectiveEnd(y);
  }

  @override
  int GetHashCode(ZoneInterval obj) {
    var hash = HashCodeHelper.Initialize();
    if (ZoneEqualityComparer._CheckOption(_options, ZoneEqualityComparerOptions.MatchOffsetComponents)) {
      hash = hash.Hash(obj.StandardOffset).Hash(obj.Savings);
    } else {
      hash = hash.Hash(obj.WallOffset);
    }
    if (ZoneEqualityComparer._CheckOption(_options, ZoneEqualityComparerOptions.MatchNames)) {
      hash = hash.Hash(obj.Name);
    }
    return hash.Hash(_GetEffectiveStart(obj)).Hash(_GetEffectiveEnd(obj)).Value;
  }

  Instant _GetEffectiveStart(ZoneInterval zoneInterval) =>
      ZoneEqualityComparer._CheckOption(_options, ZoneEqualityComparerOptions.MatchStartAndEndTransitions)
          ? zoneInterval.RawStart
          : Instant.Max(zoneInterval.RawStart, _interval.Start);

  Instant _GetEffectiveEnd(ZoneInterval zoneInterval) =>
      ZoneEqualityComparer._CheckOption(_options, ZoneEqualityComparerOptions.MatchStartAndEndTransitions)
          ? zoneInterval.RawEnd
          : Instant.Min(zoneInterval.RawEnd, _interval.End);

  bool _EqualExceptStartAndEnd(ZoneInterval x, ZoneInterval y) {
    if (x.WallOffset != y.WallOffset) {
      return false;
    }
    // As we've already compared wall offsets, we only need to compare savings...
    // If the savings are equal, the standard offset will be too.
    if (ZoneEqualityComparer._CheckOption(_options, ZoneEqualityComparerOptions.MatchOffsetComponents) && x.Savings != y.Savings) {
      return false;
    }
    if (ZoneEqualityComparer._CheckOption(_options, ZoneEqualityComparerOptions.MatchNames) && x.Name != y.Name) {
      return false;
    }
    return true;
  }
}
