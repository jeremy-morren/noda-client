// Ported from NodaTime 6e024dde: src/NodaTime/TimeZones/StandardDaylightAlternatingMap.cs
// Copyright 2010 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import '../Instant.dart';
import '../Offset.dart';
import '../Utility/HashCodeHelper.dart';
import '../Utility/Int64.dart';
import '../Utility/Preconditions.dart';
import 'IO/IDateTimeZoneReader.dart';
import 'IO/IDateTimeZoneWriter.dart';
import 'IZoneIntervalMap.dart';
import 'Transition.dart';
import 'ZoneInterval.dart';
import 'ZoneRecurrence.dart';
import 'ZoneYearOffset.dart';

// Reader notes, 2017-04-05:
// - It's not clear that this really needs to be standard/daylight - it could just be two arbitrary recurrences
//   with the same standard offset. Knowing which one is standard avoids one memory access (for the offset) in
//   many occurrences, but we could potentially optimize this in other ways anyway.
//
// - The comment around America/Resolute was added on July 20th 2011. The TZDB release at the time was 2011h.
//   From https://github.com/eggert/tz/blob/338ff27740c38fcef26920c9dbd776c09768eb3b/northamerica
//     Rule    Resolute 2006	max	-	Nov	Sun>=1	2:00	0	ES
//     Rule    Resolute 2007	max	-	Mar Sun>=8	2:00	0	CD
//   We probably still want to be able to consume 2011h later, so let's not remove that functionality.

/// Provides a zone interval map representing an infinite sequence of standard/daylight
/// transitions from a pair of rules.
///
/// IMPORTANT: This class *accepts* recurrences which start from a particular year
/// rather than being infinite back to the start of time, but *treats* them as if
/// they were infinite. This makes various calculations easier, but this map should
/// only be used as part of a zone which will only ask it for values within the right
/// portion of the timeline.
@internal
final class StandardDaylightAlternatingMap implements IZoneIntervalMap {
  final Offset _standardOffset;
  late final ZoneRecurrence _standardRecurrence;
  late final ZoneRecurrence _dstRecurrence;

  @override
  Offset get MinOffset => Offset.Min(_standardOffset, _standardOffset + _dstRecurrence.Savings);
  @override
  Offset get MaxOffset => Offset.Max(_standardOffset, _standardOffset + _dstRecurrence.Savings);

  /// Initializes a new instance of the [StandardDaylightAlternatingMap] class.
  ///
  /// At least one of the recurrences (it doesn't matter which) must be a "standard", i.e. not have any savings
  /// applied. The other may still not have any savings (e.g. for America/Resolute) or (for BCL compatibility) may
  /// even have negative daylight savings.
  ///
  /// [standardOffset]: The standard offset.
  /// [startRecurrence]: The start recurrence.
  /// [endRecurrence]: The end recurrence.
  @internal
  StandardDaylightAlternatingMap.NewStandardOffsetStartRecurrenceEndRecurrence(
      Offset standardOffset, ZoneRecurrence startRecurrence, ZoneRecurrence endRecurrence)
      : _standardOffset = standardOffset {
    // Treat the recurrences as if they extended to the start of time.
    startRecurrence = startRecurrence.ToStartOfTime();
    endRecurrence = endRecurrence.ToStartOfTime();
    Preconditions.CheckArgument(startRecurrence.IsInfinite, 'startRecurrence', 'Start recurrence must extend to the end of time');
    Preconditions.CheckArgument(endRecurrence.IsInfinite, 'endRecurrence', 'End recurrence must extend to the end of time');
    var dst = startRecurrence;
    var standard = endRecurrence;
    if (startRecurrence.Savings == Offset.Zero) {
      dst = endRecurrence;
      standard = startRecurrence;
    }
    Preconditions.CheckArgument(standard.Savings == Offset.Zero, 'startRecurrence', 'At least one recurrence must not have savings applied');
    _dstRecurrence = dst;
    _standardRecurrence = standard;
  }

  @override
  bool operator ==(Object other) => other is StandardDaylightAlternatingMap && Equals(other);

  bool Equals(StandardDaylightAlternatingMap? other) =>
      other != null &&
      _standardOffset == other._standardOffset &&
      _dstRecurrence.Equals(other._dstRecurrence) &&
      _standardRecurrence.Equals(other._standardRecurrence);

  @override
  int get hashCode =>
      HashCodeHelper.Initialize().Hash(_standardOffset).Hash(_dstRecurrence).Hash(_standardRecurrence).Value;

  /// Gets the zone interval for the given instant.
  ///
  /// [instant]: The Instant to test.
  ///
  /// Returns the ZoneInterval in effect at the given instant.
  ///
  /// Throws [RangeError] if the instant falls outside the bounds
  /// of the recurrence rules of the zone.
  @override
  ZoneInterval GetZoneInterval(Instant instant) {
    var (next, recurrence) = _NextTransition(instant);
    // Now we know the recurrence we're in, we can work out when we went into it. (We'll never have
    // two transitions into the same recurrence in a row.)
    Offset previousSavings = identical(recurrence, _standardRecurrence) ? _dstRecurrence.Savings : Offset.Zero;
    var previous = recurrence.PreviousOrSameOrFail(instant, _standardOffset, previousSavings);
    return ZoneInterval.NewNameStartEndWallOffsetSavings(
        recurrence.Name, previous.Instant, next.Instant, _standardOffset + recurrence.Savings, recurrence.Savings);
  }

  /// Returns the transition occurring strictly after the specified instant, and the recurrence the transition goes
  /// *from* (C#'s `recurrence` out parameter).
  ///
  /// [instant]: The instant after which to consider transitions.
  (Transition, ZoneRecurrence) _NextTransition(Instant instant) {
    // Both recurrences are infinite, so they'll both have next transitions (possibly at infinity).
    Transition dstTransition = _dstRecurrence.NextOrFail(instant, _standardOffset, Offset.Zero);
    Transition standardTransition = _standardRecurrence.NextOrFail(instant, _standardOffset, _dstRecurrence.Savings);
    var standardTransitionInstant = standardTransition.Instant;
    var dstTransitionInstant = dstTransition.Instant;
    if (standardTransitionInstant < dstTransitionInstant) {
      // Next transition is from DST to standard.
      return (standardTransition, _dstRecurrence);
    } else if (standardTransitionInstant > dstTransitionInstant) {
      // Next transition is from standard to DST.
      return (dstTransition, _standardRecurrence);
    } else {
      // Okay, the transitions happen at the same time. If they're not at infinity, we're stumped.
      if (standardTransitionInstant.IsValid) {
        throw StateError('Zone recurrence rules have identical transitions. This time zone is broken. Transition time: $standardTransitionInstant');
      }
      // Okay, the two transitions must be to the end of time. Find which recurrence has the later *previous* transition...
      var previousDstTransition = _dstRecurrence.PreviousOrSameOrFail(instant, _standardOffset, Offset.Zero);
      var previousStandardTransition = _standardRecurrence.PreviousOrSameOrFail(instant, _standardOffset, _dstRecurrence.Savings);
      // No point in checking for equality here... they can't go back from the end of time to the start...
      if (previousDstTransition.Instant > previousStandardTransition.Instant) {
        // The previous transition is from standard to DST. Therefore the next one is from DST to standard.
        return (standardTransition, _dstRecurrence);
      } else {
        // The previous transition is from DST to standard. Therefore the next one is from standard to DST.
        return (dstTransition, _standardRecurrence);
      }
    }
  }

  /// Writes the time zone to the specified writer.
  ///
  /// [writer]: The writer to write to.
  @internal
  void Write(IDateTimeZoneWriter writer) {
    // We don't need everything a recurrence can supply: we know that both recurrences should be
    // infinite, and that only the DST recurrence should have savings.
    // Dart: null safety checks writer.
    writer.WriteOffset(_standardOffset);
    writer.WriteString(_standardRecurrence.Name);
    _standardRecurrence.YearOffset.Write(writer);
    writer.WriteString(_dstRecurrence.Name);
    _dstRecurrence.YearOffset.Write(writer);
    writer.WriteOffset(_dstRecurrence.Savings);
  }

  @internal
  static StandardDaylightAlternatingMap Read(IDateTimeZoneReader reader) {
    // Dart: null safety checks reader.
    Offset standardOffset = reader.ReadOffset();
    String standardName = reader.ReadString();
    ZoneYearOffset standardYearOffset = ZoneYearOffset.Read(reader);
    String daylightName = reader.ReadString();
    ZoneYearOffset daylightYearOffset = ZoneYearOffset.Read(reader);
    Offset savings = reader.ReadOffset();
    ZoneRecurrence standardRecurrence = ZoneRecurrence(standardName, Offset.Zero, standardYearOffset, Int64.Int32MinValue, Int64.Int32MaxValue);
    ZoneRecurrence dstRecurrence = ZoneRecurrence(daylightName, savings, daylightYearOffset, Int64.Int32MinValue, Int64.Int32MaxValue);
    return StandardDaylightAlternatingMap.NewStandardOffsetStartRecurrenceEndRecurrence(standardOffset, standardRecurrence, dstRecurrence);
  }
}
