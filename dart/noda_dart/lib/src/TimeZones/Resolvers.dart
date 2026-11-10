// Ported from NodaTime 6e024dde: src/NodaTime/TimeZones/Resolvers.cs
// Copyright 2012 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

// NodaTime's resolvers are static properties holding delegates: static fields holding functions.
// ignore_for_file: prefer_function_declarations_over_variables

import '../AmbiguousTimeException.dart';
import '../Duration.dart';
import '../OffsetDateTime.dart';
import '../SkippedTimeException.dart';
import '../ZonedDateTime.dart';
import 'Delegates.dart';
import 'ZoneLocalMapping.dart';

/// Commonly-used implementations of the delegates used in resolving a [LocalDateTime] to a
/// [ZonedDateTime], and a method to combine two "partial" resolvers into a full one.
///
/// This class contains predefined implementations of [ZoneLocalMappingResolver],
/// [AmbiguousTimeResolver], and [SkippedTimeResolver], along with
/// [CreateMappingResolver], which produces a `ZoneLocalMappingResolver` from instances of the
/// other two.
abstract final class Resolvers {
  /// An [AmbiguousTimeResolver] which returns the earlier of the two matching times.
  static final AmbiguousTimeResolver ReturnEarlier = (earlier, later) => earlier;

  /// An [AmbiguousTimeResolver] which returns the later of the two matching times.
  static final AmbiguousTimeResolver ReturnLater = (earlier, later) => later;

  /// An [AmbiguousTimeResolver] which simply throws an [AmbiguousTimeException].
  static final AmbiguousTimeResolver ThrowWhenAmbiguous = (earlier, later) {
    throw AmbiguousTimeException(earlier, later);
  };

  /// A [SkippedTimeResolver] which returns the final tick of the time zone interval
  /// before the "gap".
  static final SkippedTimeResolver ReturnEndOfIntervalBefore = (local, zone, before, after) {
    // Dart: null safety checks zone, before and after.
    // Given that there's a zone after before, it can't extend to the end of time.
    return ZonedDateTime(before.End.MinusDuration(Duration.Epsilon), zone, local.Calendar);
  };

  /// A [SkippedTimeResolver] which returns the first tick of the time zone interval
  /// after the "gap".
  static final SkippedTimeResolver ReturnStartOfIntervalAfter = (local, zone, before, after) {
    // Dart: null safety checks zone, before and after.
    return ZonedDateTime(after.Start, zone, local.Calendar);
  };

  /// A [SkippedTimeResolver] which shifts values in the "gap" forward by the duration
  /// of the gap (which is usually 1 hour). This corresponds to the instant that would have occured,
  /// had there not been a transition.
  static final SkippedTimeResolver ReturnForwardShifted = (local, zone, before, after) {
    // Dart: null safety checks zone, before and after.
    return ZonedDateTime.NewOffsetDateTimeZone(OffsetDateTime(local, before.WallOffset).WithOffset(after.WallOffset), zone);
  };

  /// A [SkippedTimeResolver] which simply throws a [SkippedTimeException].
  static final SkippedTimeResolver ThrowWhenSkipped = (local, zone, before, after) {
    // Dart: null safety checks zone, before and after.
    throw SkippedTimeException(local, zone);
  };

  /// A [ZoneLocalMappingResolver] which only ever succeeds in the (usual) case where the result
  /// of the mapping is unambiguous.
  ///
  /// If the mapping is ambiguous or skipped, this throws [SkippedTimeException] or
  /// [AmbiguousTimeException], as appropriate. This resolver combines
  /// [ThrowWhenAmbiguous] and [ThrowWhenSkipped].
  ///
  /// See also [DateTimeZone.AtStrictly].
  static final ZoneLocalMappingResolver StrictResolver =
      CreateMappingResolver(ThrowWhenAmbiguous, ThrowWhenSkipped);

  /// A [ZoneLocalMappingResolver] which never throws an exception due to ambiguity or skipped time.
  ///
  /// Ambiguity is handled by returning the earlier occurrence, and skipped times are shifted forward by the duration
  /// of the gap. This resolver combines [ReturnEarlier] and [ReturnForwardShifted].
  ///
  /// Note: The behavior of this resolver was changed in version 2.0 to fit the most commonly seen real-world
  /// usage pattern.  Previous versions combined the [ReturnLater] and [ReturnStartOfIntervalAfter]
  /// resolvers, which can still be used separately if desired.
  ///
  /// See also [DateTimeZone.AtLeniently].
  static final ZoneLocalMappingResolver LenientResolver =
      CreateMappingResolver(ReturnEarlier, ReturnForwardShifted);

  /// Combines an [AmbiguousTimeResolver] and a [SkippedTimeResolver] to create a
  /// [ZoneLocalMappingResolver].
  ///
  /// The `ZoneLocalMappingResolver` created by this method operates in the obvious way: unambiguous mappings
  /// are returned directly, ambiguous mappings are delegated to the given `AmbiguousTimeResolver`, and
  /// "skipped" mappings are delegated to the given `SkippedTimeResolver`.
  ///
  /// [ambiguousTimeResolver]: Resolver to use for ambiguous mappings.
  /// [skippedTimeResolver]: Resolver to use for "skipped" mappings.
  ///
  /// Returns the logical combination of the two resolvers.
  static ZoneLocalMappingResolver CreateMappingResolver(
      AmbiguousTimeResolver ambiguousTimeResolver, SkippedTimeResolver skippedTimeResolver) {
    // Dart: null safety checks ambiguousTimeResolver and skippedTimeResolver.
    return (ZoneLocalMapping mapping) =>
        // Dart: null safety checks mapping.
        switch (mapping.Count) {
          0 => skippedTimeResolver(mapping.LocalDateTime, mapping.Zone, mapping.EarlyInterval, mapping.LateInterval),
          1 => mapping.First(),
          2 => ambiguousTimeResolver(mapping.First(), mapping.Last()),
          _ => throw StateError('Mapping has count outside range 0-2; should not happen.'),
        };
  }
}
