// Ported from NodaTime 6e024dde: src/NodaTime/TimeZones/ZoneLocalMapping.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import '../AmbiguousTimeException.dart';
import '../DateTimeZone.dart';
// ZoneLocalMapping has a member named LocalDateTime, which hides the type inside the class.
import '../LocalDateTime.dart' as nt show LocalDateTime;
import '../SkippedTimeException.dart';
import '../Utility/Preconditions.dart';
import '../ZonedDateTime.dart';
import 'ZoneInterval.dart';

// Note: documentation that refers to the LocalDateTime type within this class must use the fully-qualified
// reference to avoid being resolved to the LocalDateTime property instead.

/// The result of mapping a [nt.LocalDateTime] within a time zone, i.e. finding out
/// at what "global" time the "local" time occurred.
///
/// This class is used as the return type of [DateTimeZone.MapLocal]. It allows for
/// finely-grained handling of the three possible results:
///
/// * Unambiguous mapping: The local time occurs exactly once in the target time zone.
/// * Ambiguous mapping: The local time occurs twice in the target time zone, due to the offset from UTC
///   changing. This usually occurs for an autumnal daylight saving transition, where the clocks
///   are put back by an hour. If the clocks change from 2am to 1am for example, then 1:30am occurs
///   twice - once before the transition and once afterwards.
/// * Impossible mapping: The local time does not occur at all in the target time zone, due to the offset from UTC
///   changing. This usually occurs for a vernal (spring-time) daylight saving transition, where the clocks
///   are put forward by an hour. If the clocks change from 1am to 2am for example, then 1:30am is
///   skipped entirely.
final class ZoneLocalMapping {
  /// Gets the [DateTimeZone] in which this mapping was performed.
  final DateTimeZone Zone;

  /// Gets the [nt.LocalDateTime] which was mapped within the time zone.
  final nt.LocalDateTime LocalDateTime;

  /// Gets the earlier [ZoneInterval] within this mapping.
  ///
  /// For unambiguous mappings, this is the same as [LateInterval]; for ambiguous mappings,
  /// this is the interval during which the mapped local time first occurs; for impossible
  /// mappings, this is the interval before which the mapped local time occurs.
  final ZoneInterval EarlyInterval;

  /// Gets the later [ZoneInterval] within this mapping.
  ///
  /// For unambiguous
  /// mappings, this is the same as [EarlyInterval]; for ambiguous mappings,
  /// this is the interval during which the mapped local time last occurs; for impossible
  /// mappings, this is the interval after which the mapped local time occurs.
  final ZoneInterval LateInterval;

  /// Gets the number of results within this mapping: the number of distinct
  /// [ZonedDateTime] values which map to the original [nt.LocalDateTime].
  final int Count;

  @internal
  ZoneLocalMapping.NewZoneLocalDateTimeEarlyIntervalLateIntervalCount(DateTimeZone zone, nt.LocalDateTime localDateTime,
      ZoneInterval earlyInterval, ZoneInterval lateInterval, int count)
      : Zone = zone,
        EarlyInterval = earlyInterval,
        LateInterval = lateInterval,
        LocalDateTime = localDateTime,
        Count = count {
    // Dart: null safety checks zone, earlyInterval and lateInterval.
    Preconditions.DebugCheckArgumentRange('count', count, 0, 2);
  }

  /// Returns the single [ZonedDateTime] which maps to the original
  /// [nt.LocalDateTime] in the mapped [DateTimeZone].
  ///
  /// Throws [SkippedTimeException] if the local date/time was skipped in the time zone.
  /// Throws [AmbiguousTimeException] if the local date/time was ambiguous in the time zone.
  ///
  /// Returns the unambiguous result of mapping the local date/time in the time zone.
  ZonedDateTime Single() {
    switch (Count) {
      case 0:
        throw SkippedTimeException(LocalDateTime, Zone);
      case 1:
        return _BuildZonedDateTime(EarlyInterval);
      case 2:
        throw AmbiguousTimeException(
            _BuildZonedDateTime(EarlyInterval),
            _BuildZonedDateTime(LateInterval));
      default:
        throw StateError("Can't happen");
    }
  }

  // TODO: Reimplement as switch expressions after fixing https://github.com/nodatime/nodatime/issues/1269

  /// Returns a [ZonedDateTime] which maps to the original [nt.LocalDateTime]
  /// in the mapped [DateTimeZone]: either the single result if the mapping is unambiguous,
  /// or the earlier result if the local date/time occurs twice in the time zone due to a time zone
  /// offset change such as an autumnal daylight saving transition.
  ///
  /// Throws [SkippedTimeException] if the local date/time was skipped in the time zone.
  ///
  /// Returns the unambiguous result of mapping a local date/time in a time zone.
  ZonedDateTime First() {
    switch (Count) {
      case 0:
        throw SkippedTimeException(LocalDateTime, Zone);
      case 1:
      case 2:
        return _BuildZonedDateTime(EarlyInterval);
      default:
        throw StateError("Can't happen");
    }
  }

  /// Returns a [ZonedDateTime] which maps to the original [nt.LocalDateTime]
  /// in the mapped [DateTimeZone]: either the single result if the mapping is unambiguous,
  /// or the later result if the local date/time occurs twice in the time zone due to a time zone
  /// offset change such as an autumnal daylight saving transition.
  ///
  /// Throws [SkippedTimeException] if the local date/time was skipped in the time zone.
  ///
  /// Returns the unambiguous result of mapping a local date/time in a time zone.
  ZonedDateTime Last() {
    switch (Count) {
      case 0:
        throw SkippedTimeException(LocalDateTime, Zone);
      case 1:
        return _BuildZonedDateTime(EarlyInterval);
      case 2:
        return _BuildZonedDateTime(LateInterval);
      default:
        throw StateError("Can't happen");
    }
  }

  ZonedDateTime _BuildZonedDateTime(ZoneInterval interval) =>
      ZonedDateTime.NewOffsetDateTimeZone(LocalDateTime.WithOffset(interval.WallOffset), Zone);
}
