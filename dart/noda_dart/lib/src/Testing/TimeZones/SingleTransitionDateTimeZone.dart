// Ported from NodaTime 6e024dde: src/NodaTime.Testing/TimeZones/SingleTransitionDateTimeZone.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import '../../DateTimeZone.dart';
import '../../Instant.dart';
import '../../Offset.dart';
import '../../TimeZones/ZoneInterval.dart';

/// Time zone with a single transition between two offsets. This provides a simple way to test behaviour across a transition.
final class SingleTransitionDateTimeZone extends DateTimeZone {
  /// Gets the [ZoneInterval] for the period before the transition, starting at the beginning of time.
  ///
  /// The zone interval for the period before the transition, starting at the beginning of time.
  final ZoneInterval EarlyInterval;

  /// Gets the [ZoneInterval] for the period after the transition, ending at the end of time.
  ///
  /// The zone interval for the period after the transition, ending at the end of time.
  final ZoneInterval LateInterval;

  /// Gets the transition instant of the zone.
  ///
  /// The transition instant of the zone.
  Instant get Transition => EarlyInterval.End;

  /// Creates a zone with a single transition between two offsets.
  ///
  /// [transitionPoint]: The transition point as an [Instant].
  /// [offsetBeforeHours]: The offset of local time from UTC, in hours, before the transition.
  /// [offsetAfterHours]: The offset of local time from UTC, in hours, before the transition.
  SingleTransitionDateTimeZone(Instant transitionPoint, int offsetBeforeHours, int offsetAfterHours)
      : this.TransitionPointOffsetBeforeOffsetAfter(
            transitionPoint, Offset.FromHours(offsetBeforeHours), Offset.FromHours(offsetAfterHours));

  /// Creates a zone with a single transition between two offsets.
  ///
  /// (NodaTime's `SingleTransitionDateTimeZone(Instant transitionPoint, Offset offsetBefore, Offset offsetAfter)`,
  /// with the ID "Single", and `SingleTransitionDateTimeZone(Instant transitionPoint, Offset offsetBefore, Offset
  /// offsetAfter, string id)`, as one constructor.)
  ///
  /// [transitionPoint]: The transition point as an [Instant].
  /// [offsetBefore]: The offset of local time from UTC before the transition.
  /// [offsetAfter]: The offset of local time from UTC before the transition.
  /// [id]: ID for the newly created time zone.
  SingleTransitionDateTimeZone.TransitionPointOffsetBeforeOffsetAfter(
      Instant transitionPoint, Offset offsetBefore, Offset offsetAfter,
      [String id = 'Single'])
      : EarlyInterval = ZoneInterval('$id-Early', null, transitionPoint, offsetBefore, Offset.Zero),
        LateInterval = ZoneInterval('$id-Late', transitionPoint, null, offsetAfter, Offset.Zero),
        super(id, false, Offset.Min(offsetBefore, offsetAfter), Offset.Max(offsetBefore, offsetAfter));

  /// Returns the zone interval for the given instant.
  @override
  ZoneInterval GetZoneInterval(Instant instant) => EarlyInterval.Contains(instant) ? EarlyInterval : LateInterval;
}
