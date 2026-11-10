// Ported from NodaTime 6e024dde: src/NodaTime/DateTimeZone.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import 'Duration.dart';
import 'IDateTimeZoneProvider.dart';
import 'Instant.dart';
import 'Interval.dart';
import 'LocalDate.dart';
import 'LocalDateTime.dart';
import 'LocalInstant.dart';
import 'NodaConstants.dart';
import 'Offset.dart';
import 'OffsetDateTime.dart';
import 'SkippedTimeException.dart';
import 'ZonedDateTime.dart';
import 'TimeZones/Delegates.dart';
import 'TimeZones/FixedDateTimeZone.dart';
import 'TimeZones/IZoneIntervalMap.dart';
import 'TimeZones/Resolvers.dart';
import 'TimeZones/ZoneEqualityComparer.dart';
import 'TimeZones/ZoneEqualityComparer.Options.generated.dart';
import 'TimeZones/ZoneInterval.dart';
import 'TimeZones/ZoneLocalMapping.dart';

const int _FixedZoneCacheGranularitySeconds = NodaConstants.SecondsPerMinute * 30;
const int _FixedZoneCacheMinimumSeconds = -_FixedZoneCacheGranularitySeconds * 12 * 2; // From UTC-12
const int _FixedZoneCacheSize = (12 + 15) * 2 + 1; // To UTC+15 inclusive

/// Represents a time zone - a mapping between UTC and local time. A time zone maps UTC instants to local times
///  - or, equivalently, to the offset from UTC at any particular instant.
///
/// The mapping is unambiguous in the "UTC to local" direction, but
/// the reverse is not true: when the offset changes, usually due to a Daylight Saving transition,
/// the change either creates a gap (a period of local time which never occurs in the time zone)
/// or an ambiguity (a period of local time which occurs twice in the time zone). Mapping back from
/// local time to an instant requires consideration of how these problematic times will be handled.
///
/// Noda Time provides various options when mapping local time to a specific instant:
/// - [AtStrictly] will throw an exception if the mapping from local time is either ambiguous
///   or impossible, i.e. if there is anything other than one instant which maps to the given local time.
/// - [AtLeniently] will never throw an exception due to ambiguous or skipped times,
///   resolving to the earlier option of ambiguous matches, or to a value that's forward-shifted by the duration
///   of the gap for skipped times.
/// - [ResolveLocal] will apply a [ZoneLocalMappingResolver] to the result of
///   a mapping.
/// - [MapLocal] will return a [ZoneLocalMapping]
///   with complete information about whether the given local time occurs zero times, once or twice. This is the most
///   fine-grained approach, which is the fiddliest to use but puts the caller in the most control.
///
/// Noda Time has two built-in sources of time zone data available: a copy of the
/// [tz database](https://www.iana.org/time-zones) (also known as the IANA Time Zone database, or zoneinfo
/// or Olson database), and the ability to convert .NET's own `TimeZoneInfo` format into a "native" Noda
/// Time zone. Which of these is most appropriate for you to use will very much depend on your exact needs. The
/// zoneinfo database is widely used outside Windows, and has more historical data than the Windows-provided
/// information, but if you need to interoperate with other Windows systems by specifying time zone IDs, you may
/// wish to stick to the Windows time zones.
/// (noda_dart: see `package:noda_dart/tzdb.dart` and `system.dart`.)
///
/// To obtain a [DateTimeZone] for a given timezone ID, use one of the methods on
/// [IDateTimeZoneProvider] (and see `DateTimeZoneProviders` for access to the built-in
/// providers). The UTC timezone is also available via the [Utc] property on this class.
///
/// To obtain a [DateTimeZone] representing the system default time zone, you can either call
/// [IDateTimeZoneProvider.GetSystemDefault] on a provider to obtain the [DateTimeZone] that
/// the provider considers matches the system default time zone, or you can construct a
/// `SystemDateTimeZone` (NodaTime's `BclDateTimeZone`) via `SystemDateTimeZone.ForSystemDefault`, which returns a
/// [DateTimeZone] that wraps the system local time zone. The latter will always
/// succeed, but has access only to that information available via the system time zone; the former may contain more
/// complete data, but may (in uncommon cases) fail to find a matching [DateTimeZone].
///
/// Note that Noda Time does not require that [DateTimeZone] instances be singletons.
/// Comparing two time zones for equality is not straightforward: if you care about whether two
/// zones act the same way within a particular portion of time, use [ZoneEqualityComparer].
/// Additional guarantees are provided by [IDateTimeZoneProvider] and [ForOffset].
///
/// All time zone implementations within Noda Time are immutable and thread-safe.
/// See the thread safety section of the user guide for more information.
/// It is expected that third party implementations will be immutable and thread-safe as well:
/// code within Noda Time assumes that it can hand out time zones to any thread without any concerns. If you
/// implement a non-thread-safe time zone, you will need to use it extremely carefully. We'd recommend that you
/// avoid this if possible.
abstract class DateTimeZone implements IZoneIntervalMap {
  /// The ID of the UTC (Coordinated Universal Time) time zone. This ID is always valid, whatever provider is
  /// used. If the provider has its own mapping for UTC, that will be returned by `DateTimeZoneCache.GetZoneOrNull`, but otherwise
  /// the value of the [Utc] property will be returned.
  @internal
  static const String UtcId = 'UTC';

  /// Gets the UTC (Coordinated Universal Time) time zone.
  ///
  /// This is a single instance which is not provider-specific; it is guaranteed to have the ID "UTC", and to
  /// compare equal to an instance returned by calling [ForOffset] with an offset of zero, but it may
  /// or may not compare equal to an instance returned by e.g. `DateTimeZoneProviders.Tzdb['UTC']`.
  static final DateTimeZone Utc = FixedDateTimeZone.NewOffset(Offset.Zero);
  static final List<DateTimeZone> _FixedZoneCache = _BuildFixedZoneCache();

  /// Returns a fixed time zone with the given offset.
  ///
  /// The returned time zone will have an ID of "UTC" if the offset is zero, or "UTC+/-Offset"
  /// otherwise. In the former case, the returned instance will be equal to [Utc].
  ///
  /// Note also that this method is not required to return the same [DateTimeZone] instance for
  /// successive requests for the same offset; however, all instances returned for a given offset will compare
  /// as equal.
  ///
  /// [offset]: The offset for the returned time zone
  ///
  /// Returns a fixed time zone with the given offset.
  static DateTimeZone ForOffset(Offset offset) {
    int seconds = offset.Seconds;
    if (seconds.remainder(_FixedZoneCacheGranularitySeconds) != 0) {
      return FixedDateTimeZone.NewOffset(offset);
    }
    int index = (seconds - _FixedZoneCacheMinimumSeconds) ~/ _FixedZoneCacheGranularitySeconds;
    if (index < 0 || index >= _FixedZoneCacheSize) {
      return FixedDateTimeZone.NewOffset(offset);
    }
    return _FixedZoneCache[index];
  }

  /// Initializes a new instance of the [DateTimeZone] class.
  ///
  /// [id]: The unique id of this time zone.
  /// [isFixed]: Set to `true` if this time zone has no transitions.
  /// [minOffset]: Minimum offset applied within this zone
  /// [maxOffset]: Maximum offset applied within this zone
  DateTimeZone(String id, bool isFixed, Offset minOffset, Offset maxOffset)
      // Dart: null safety checks id.
      : Id = id,
        IsFixed = isFixed,
        MinOffset = minOffset,
        MaxOffset = maxOffset;

  /// Get the provider's ID for the time zone.
  ///
  /// This identifies the time zone within the current time zone provider; a different provider may
  /// provide a different time zone with the same ID, or may not provide a time zone with that ID at all.
  final String Id;

  /// Indicates whether the time zone is fixed, i.e. contains no transitions.
  ///
  /// This is used as an optimization. If the time zone has no transitions but returns `false`
  /// for this then the behavior will be correct but the system will have to do extra work. However
  /// if the time zone has transitions and this returns `true` then the transitions will never
  /// be examined.
  @internal
  final bool IsFixed;

  /// Gets the least (most negative) offset within this time zone, over all time.
  @override
  final Offset MinOffset;

  /// Gets the greatest (most positive) offset within this time zone, over all time.
  @override
  final Offset MaxOffset;

  // #region Core abstract/virtual methods
  /// Returns the offset from UTC, where a positive duration indicates that local time is
  /// later than UTC. In other words, local time = UTC + offset.
  ///
  /// This is mostly a convenience method for calling `GetZoneInterval(instant).WallOffset`,
  /// although it can also be overridden for more efficiency.
  ///
  /// [instant]: The instant for which to calculate the offset.
  ///
  /// Returns the offset from UTC at the specified instant.
  Offset GetUtcOffset(Instant instant) => GetZoneInterval(instant).WallOffset;

  // Note for CA2119:
  // IZoneIntervalMap is primarily used while *building* time zones, but is also implemented by DateTimeZone for simplicity
  // of caching. (BclDateTimeZone always returns a cached date time zone having created an IZoneIntervalMap.)
  // While a regular user can create their own DateTimeZone implementation, that would never end up being cached
  // because CachedDateTimeZone.ForZone is internal anyway.
  // In other words: we don't believe this can be exploited.

  /// Gets the zone interval for the given instant; the range of time around the instant in which the same Offset
  /// applies (with the same split between standard time and daylight saving time, and with the same offset).
  ///
  /// This will always return a valid zone interval, as time zones cover the whole of time.
  ///
  /// [instant]: The [Instant] to query.
  ///
  /// Returns the defined [ZoneInterval].
  ///
  /// See also [GetZoneIntervalsInterval].
  @override
  ZoneInterval GetZoneInterval(Instant instant);

  /// Returns complete information about how the given [LocalDateTime] is mapped in this time zone.
  ///
  /// Mapping a local date/time to a time zone can give an unambiguous, ambiguous or impossible result, depending on
  /// time zone transitions. Use the return value of this method to handle these cases in an appropriate way for
  /// your use case.
  ///
  /// As an alternative, consider [ResolveLocal], which uses a caller-provided strategy to
  /// convert the [ZoneLocalMapping] returned here to a [ZonedDateTime].
  ///
  /// [localDateTime]: The local date and time to map in this time zone.
  ///
  /// Returns a mapping of the given local date and time to zero, one or two zoned date/time values.
  ZoneLocalMapping MapLocal(LocalDateTime localDateTime) {
    LocalInstant localInstant = localDateTime.ToLocalInstant();
    Instant firstGuess = localInstant.MinusZeroOffset();
    ZoneInterval interval = GetZoneInterval(firstGuess);

    // Most of the time we'll go into here... the local instant and the instant
    // are close enough that we've found the right instant.
    if (interval.ContainsLocalInstant(localInstant)) {
      ZoneInterval? earlier = _GetEarlierMatchingInterval(interval, localInstant);
      if (earlier != null) {
        return ZoneLocalMapping.NewZoneLocalDateTimeEarlyIntervalLateIntervalCount(this, localDateTime, earlier, interval, 2);
      }
      ZoneInterval? later = _GetLaterMatchingInterval(interval, localInstant);
      if (later != null) {
        return ZoneLocalMapping.NewZoneLocalDateTimeEarlyIntervalLateIntervalCount(this, localDateTime, interval, later, 2);
      }
      return ZoneLocalMapping.NewZoneLocalDateTimeEarlyIntervalLateIntervalCount(this, localDateTime, interval, interval, 1);
    } else {
      // Our first guess was wrong. Either we need to change interval by one (either direction)
      // or we're in a gap.
      ZoneInterval? earlier = _GetEarlierMatchingInterval(interval, localInstant);
      if (earlier != null) {
        return ZoneLocalMapping.NewZoneLocalDateTimeEarlyIntervalLateIntervalCount(this, localDateTime, earlier, earlier, 1);
      }
      ZoneInterval? later = _GetLaterMatchingInterval(interval, localInstant);
      if (later != null) {
        return ZoneLocalMapping.NewZoneLocalDateTimeEarlyIntervalLateIntervalCount(this, localDateTime, later, later, 1);
      }
      return ZoneLocalMapping.NewZoneLocalDateTimeEarlyIntervalLateIntervalCount(
          this, localDateTime, _GetIntervalBeforeGap(localInstant), _GetIntervalAfterGap(localInstant), 0);
    }
  }
  // #endregion

  // #region Conversion between local dates/times and ZonedDateTime
  /// Returns the earliest valid [ZonedDateTime] with the given local date.
  ///
  /// If midnight exists unambiguously on the given date, it is returned.
  /// If the given date has an ambiguous start time (e.g. the clocks go back from 1am to midnight)
  /// then the earlier ZonedDateTime is returned. If the given date has no midnight (e.g. the clocks
  /// go forward from midnight to 1am) then the earliest valid value is returned; this will be the instant
  /// of the transition.
  ///
  /// [date]: The local date to map in this time zone.
  ///
  /// Throws [SkippedTimeException] if the entire day was skipped due to a very large time zone transition.
  /// (This is extremely rare.)
  ///
  /// Returns the [ZonedDateTime] representing the earliest time in the given date, in this time zone.
  ZonedDateTime AtStartOfDay(LocalDate date) {
    LocalDateTime midnight = date.AtMidnight();
    var mapping = MapLocal(midnight);
    switch (mapping.Count) {
      // Midnight doesn't exist. Maybe we just skip to 1am (or whatever), or maybe the whole day is missed.
      case 0:
        var interval = mapping.LateInterval;
        // Safe to use Start, as it can't extend to the start of time.
        var offsetDateTime = OffsetDateTime.NewInstantOffsetCalendar(interval.Start, interval.WallOffset, date.Calendar);
        // It's possible that the entire day is skipped. For example, Samoa skipped December 30th 2011.
        // We know the two values are in the same calendar here, so we just need to check the YearMonthDay.
        if (offsetDateTime.YearMonthDay != date.YearMonthDay) {
          throw SkippedTimeException(midnight, this);
        }
        return ZonedDateTime.NewOffsetDateTimeZone(offsetDateTime, this);
      // Unambiguous or occurs twice, we can just use the offset from the earlier interval.
      case 1:
      case 2:
        return ZonedDateTime.NewOffsetDateTimeZone(midnight.WithOffset(mapping.EarlyInterval.WallOffset), this);
      default:
        throw StateError("This won't happen.");
    }
  }

  /// Maps the given [LocalDateTime] to the corresponding [ZonedDateTime], following
  /// the given [ZoneLocalMappingResolver] to handle ambiguity and skipped times.
  ///
  /// This is a convenience method for calling [MapLocal] and passing the result to the resolver.
  /// Common options for resolvers are provided in the static [Resolvers] class.
  ///
  /// See [AtStrictly] and [AtLeniently] for alternative ways to map a local time to a
  /// specific instant.
  ///
  /// [localDateTime]: The local date and time to map in this time zone.
  /// [resolver]: The resolver to apply to the mapping.
  ///
  /// Returns the result of resolving the mapping.
  ZonedDateTime ResolveLocal(LocalDateTime localDateTime, ZoneLocalMappingResolver resolver) {
    // Dart: null safety checks resolver.
    return resolver(MapLocal(localDateTime));
  }

  /// Maps the given [LocalDateTime] to the corresponding [ZonedDateTime], if and only if
  /// that mapping is unambiguous in this time zone.  Otherwise, [SkippedTimeException] or
  /// `AmbiguousTimeException` is thrown, depending on whether the mapping is ambiguous or the local
  /// date/time is skipped entirely.
  ///
  /// See [AtLeniently] and [ResolveLocal] for alternative ways to map a local time to a
  /// specific instant.
  ///
  /// [localDateTime]: The local date and time to map into this time zone.
  ///
  /// Throws [SkippedTimeException] if the given local date/time is skipped in this time zone.
  /// Throws `AmbiguousTimeException` if the given local date/time is ambiguous in this time zone.
  ///
  /// Returns the unambiguous matching [ZonedDateTime] if it exists.
  ZonedDateTime AtStrictly(LocalDateTime localDateTime) => ResolveLocal(localDateTime, Resolvers.StrictResolver);

  /// Maps the given [LocalDateTime] to the corresponding [ZonedDateTime] in a lenient
  /// manner: ambiguous values map to the earlier of the alternatives, and "skipped" values are shifted forward
  /// by the duration of the "gap".
  ///
  /// See [AtStrictly] and [ResolveLocal] for alternative ways to map a local time to a
  /// specific instant.
  ///
  /// Note: The behavior of this method was changed in version 2.0 to fit the most commonly seen real-world
  /// usage pattern.  Previous versions returned the later instance of ambiguous values, and returned the start of
  /// the zone interval after the gap for skipped value.  The previous functionality can still be used if desired,
  /// by using [ResolveLocal], passing in a resolver
  /// created from [Resolvers.ReturnLater] and [Resolvers.ReturnStartOfIntervalAfter].
  ///
  /// [localDateTime]: The local date/time to map.
  ///
  /// Returns the unambiguous mapping if there is one, the earlier result if the mapping is ambiguous,
  /// or the forward-shifted value if the given local date/time is skipped.
  ZonedDateTime AtLeniently(LocalDateTime localDateTime) => ResolveLocal(localDateTime, Resolvers.LenientResolver);
  // #endregion

  /// Returns the interval before this one, if it contains the given local instant, or null otherwise.
  ZoneInterval? _GetEarlierMatchingInterval(ZoneInterval interval, LocalInstant localInstant) {
    // Micro-optimization to avoid fetching interval.Start multiple times. Seems
    // to give a performance improvement on x86 at least...
    // If the zone interval extends to the start of time, the next check will definitely evaluate to false.
    Instant intervalStart = interval.RawStart;
    // This allows for a maxOffset of up to +1 day, and the "truncate towards beginning of time"
    // nature of the Days property.
    if (localInstant.DaysSinceEpoch <= intervalStart.DaysSinceEpoch + 1) {
      // We *could* do a more accurate check here based on the actual maxOffset, but it's probably
      // not worth it.
      ZoneInterval candidate = GetZoneInterval(intervalStart.MinusDuration(Duration.Epsilon));
      if (candidate.ContainsLocalInstant(localInstant)) {
        return candidate;
      }
    }
    return null;
  }

  /// Returns the next interval after this one, if it contains the given local instant, or null otherwise.
  ZoneInterval? _GetLaterMatchingInterval(ZoneInterval interval, LocalInstant localInstant) {
    // Micro-optimization to avoid fetching interval.End multiple times. Seems
    // to give a performance improvement on x86 at least...
    // If the zone interval extends to the end of time, the next check will
    // definitely evaluate to false.
    Instant intervalEnd = interval.RawEnd;
    // Crude but cheap first check to see whether there *might* be a later interval.
    // This allows for a minOffset of up to -1 day, and the "truncate towards beginning of time"
    // nature of the Days property.
    if (localInstant.DaysSinceEpoch >= intervalEnd.DaysSinceEpoch - 1) {
      // We *could* do a more accurate check here based on the actual maxOffset, but it's probably
      // not worth it.
      ZoneInterval candidate = GetZoneInterval(intervalEnd);
      if (candidate.ContainsLocalInstant(localInstant)) {
        return candidate;
      }
    }
    return null;
  }

  ZoneInterval _GetIntervalBeforeGap(LocalInstant localInstant) {
    Instant guess = localInstant.MinusZeroOffset();
    ZoneInterval guessInterval = GetZoneInterval(guess);
    // If the local interval occurs before the zone interval we're looking at starts,
    // we need to find the earlier one; otherwise this interval must come after the gap, and
    // it's therefore the one we want.
    if (localInstant.Minus(guessInterval.WallOffset) < guessInterval.RawStart) {
      return GetZoneInterval(guessInterval.Start.MinusDuration(Duration.Epsilon));
    } else {
      return guessInterval;
    }
  }

  ZoneInterval _GetIntervalAfterGap(LocalInstant localInstant) {
    Instant guess = localInstant.MinusZeroOffset();
    ZoneInterval guessInterval = GetZoneInterval(guess);
    // If the local interval occurs before the zone interval we're looking at starts,
    // it's the one we're looking for. Otherwise, we need to find the next interval.
    if (localInstant.Minus(guessInterval.WallOffset) < guessInterval.RawStart) {
      return guessInterval;
    } else {
      // Will definitely be valid - there can't be a gap after an infinite interval.
      return GetZoneInterval(guessInterval.End);
    }
  }

  // #region Object overrides
  /// Returns the ID of this time zone.
  ///
  /// Returns the ID of this time zone.
  @override
  String toString() => Id;
  // #endregion

  /// Creates a fixed time zone for offsets -12 to +15 at every half hour,
  /// fixing the 0 offset as DateTimeZone.Utc.
  static List<DateTimeZone> _BuildFixedZoneCache() {
    List<DateTimeZone> ret = List<DateTimeZone>.filled(_FixedZoneCacheSize, Utc);
    for (int i = 0; i < _FixedZoneCacheSize; i++) {
      int offsetSeconds = i * _FixedZoneCacheGranularitySeconds + _FixedZoneCacheMinimumSeconds;
      ret[i] = FixedDateTimeZone.NewOffset(Offset.FromSeconds(offsetSeconds));
    }
    ret[-_FixedZoneCacheMinimumSeconds ~/ _FixedZoneCacheGranularitySeconds] = Utc;
    return ret;
  }

  /// Returns all the zone intervals which occur for any instant in the interval [[start], [end]).
  ///
  /// This method is simply a convenience method for calling [GetZoneIntervalsInterval] without
  /// explicitly constructing the interval beforehand.
  ///
  /// [start]: Inclusive start point of the interval for which to retrieve zone intervals.
  /// [end]: Exclusive end point of the interval for which to retrieve zone intervals.
  ///
  /// Throws [RangeError] if [end] is earlier than [start].
  ///
  /// Returns a sequence of zone intervals covering the given interval.
  ///
  /// See also [DateTimeZone.GetZoneInterval].
  Iterable<ZoneInterval> GetZoneIntervals(Instant start, Instant end) =>
      // The constructor performs all the validation we need.
      GetZoneIntervalsInterval(Interval(start, end));

  /// Returns all the zone intervals which occur for any instant in the given interval, potentially coalescing some
  /// of the original intervals according to [options] (C#'s `GetZoneIntervals(Interval)` and
  /// `GetZoneIntervals(Interval, ZoneEqualityComparer.Options)`).
  ///
  /// Without [options]: the zone intervals are returned in chronological order.
  /// This method is equivalent to calling [DateTimeZone.GetZoneInterval] for every
  /// instant in the interval and then collapsing to a set of distinct zone intervals.
  /// The first and last zone intervals are likely to also cover instants outside the given interval;
  /// the zone intervals returned are not truncated to match the start and end points.
  ///
  /// With [options]: this is equivalent to calling it without options, but may coalesce some intervals.
  /// For example, if the [ZoneEqualityComparerOptions.OnlyMatchWallOffset] is specified,
  /// and two consecutive zone intervals have the same offset but different names, a single zone interval
  /// will be returned instead of two separate ones. When zone intervals are coalesced, all aspects of
  /// the first zone interval are used except its end instant, which is taken from the second zone interval.
  ///
  /// As the options are only used to determine which intervals to coalesce, the
  /// [ZoneEqualityComparerOptions.MatchStartAndEndTransitions] option does not affect
  /// the intervals returned.
  ///
  /// [interval]: Interval to find zone intervals for. This is allowed to be unbounded (i.e.
  /// infinite in both directions).
  /// [options]: The options for coalescing intervals, or null for none.
  ///
  /// Returns a sequence of zone intervals covering the given interval.
  ///
  /// See also [DateTimeZone.GetZoneInterval].
  Iterable<ZoneInterval> GetZoneIntervalsInterval(Interval interval, [ZoneEqualityComparerOptions? options]) {
    if (options == null) {
      return _GetZoneIntervals(interval);
    }
    if ((options & ~ZoneEqualityComparerOptions.StrictestMatch).value != 0) {
      throw RangeError.value(
          options.value, 'options', 'The value ${options.Name} is not defined within ZoneEqualityComparer.Options');
    }
    var zoneIntervalEqualityComparer = ZoneEqualityComparerZoneIntervalEqualityComparer.NewOptionsInterval(options, interval);
    var originalIntervals = _GetZoneIntervals(interval);
    return zoneIntervalEqualityComparer.CoalesceIntervals(originalIntervals);
  }

  // noda_dart: the iterator body of C#'s GetZoneIntervals(Interval), separate so validation runs eagerly.
  Iterable<ZoneInterval> _GetZoneIntervals(Interval interval) sync* {
    var current = interval.HasStart ? interval.Start : Instant.MinValue;
    var end = interval.RawEnd;
    while (current < end) {
      var zoneInterval = GetZoneInterval(current);
      yield zoneInterval;
      // If this is the end of time, this will just fail on the next comparison.
      current = zoneInterval.RawEnd;
    }
  }

  // #region JSON
  /// Returns the ID of this time zone, as NodaTime.Serialization.SystemTextJson writes it.
  String toJson() => Id;

  /// Returns the time zone with the given ID (as written by [toJson]) from the given provider.
  ///
  /// Throws `DateTimeZoneNotFoundException` if the provider does not support the given ID.
  factory DateTimeZone.fromJson(String json, IDateTimeZoneProvider provider) => provider[json];
  // #endregion
}
