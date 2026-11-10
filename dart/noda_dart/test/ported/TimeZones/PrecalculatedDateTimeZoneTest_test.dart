// Ported from NodaTime 6e024dde: src/NodaTime.Test/TimeZones/PrecalculatedDateTimeZoneTest.cs
// Copyright 2010 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:noda_dart/src/DateTimeZone.dart';
import 'package:noda_dart/src/Duration.dart';
import 'package:noda_dart/src/Instant.dart';
import 'package:noda_dart/src/Interval.dart';
import 'package:noda_dart/src/LocalDateTime.dart';
import 'package:noda_dart/src/LocalTime.dart';
import 'package:noda_dart/src/Offset.dart';
import 'package:noda_dart/src/Testing/TimeZones/SingleTransitionDateTimeZone.dart';
import 'package:noda_dart/src/TimeZones/FixedDateTimeZone.dart';
import 'package:noda_dart/src/TimeZones/IO/DateTimeZoneReader.dart';
import 'package:noda_dart/src/TimeZones/IO/DateTimeZoneWriter.dart';
import 'package:noda_dart/src/TimeZones/PrecalculatedDateTimeZone.dart';
import 'package:noda_dart/src/TimeZones/StandardDaylightAlternatingMap.dart';
import 'package:noda_dart/src/TimeZones/TransitionMode.generated.dart';
import 'package:noda_dart/src/TimeZones/ZoneEqualityComparer.Options.generated.dart';
import 'package:noda_dart/src/TimeZones/ZoneInterval.dart';
import 'package:noda_dart/src/TimeZones/ZoneRecurrence.dart';
import 'package:noda_dart/src/TimeZones/ZoneYearOffset.dart';
import 'package:noda_dart/src/Utility/Int64.dart';
import 'package:noda_dart/src/Utility/Stream.dart';

import '../../helpers/Assertions.dart';
import '../../helpers/Scenarios.dart';
import '../../scenarios/TimeZones/PrecalculatedDateTimeZoneTest.generated.dart' as scenarios;

final ZoneInterval FirstInterval =
    ZoneInterval('First', Instant.BeforeMinValue, Instant.FromUtc(2000, 3, 10, 10, 0), Offset.FromHours(3), Offset.Zero);

// Note that this is effectively UTC +3 + 1 hour DST.
final ZoneInterval SecondInterval =
    ZoneInterval('Second', FirstInterval.End, Instant.FromUtc(2000, 9, 15, 5, 0), Offset.FromHours(4), Offset.FromHours(1));

final ZoneInterval ThirdInterval =
    ZoneInterval('Third', SecondInterval.End, Instant.FromUtc(2005, 1, 20, 8, 0), Offset.FromHours(-5), Offset.Zero);

final ZoneRecurrence Winter = ZoneRecurrence('Winter', Offset.Zero,
    ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(TransitionMode.Wall, 10, 5, 0, false, LocalTime(2, 0)), 1960, Int64.Int32MaxValue);

final ZoneRecurrence Summer = ZoneRecurrence('Summer', Offset.FromHours(1),
    ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(TransitionMode.Wall, 3, 10, 0, false, LocalTime(1, 0)), 1960, Int64.Int32MaxValue);

final StandardDaylightAlternatingMap TailZone =
    StandardDaylightAlternatingMap.NewStandardOffsetStartRecurrenceEndRecurrence(Offset.FromHours(-6), Winter, Summer);

// We don't actually want an interval from the beginning of time when we ask our composite time zone for an interval
// - because that could give the wrong idea. So we clamp it at the end of the precalculated interval.
final ZoneInterval ClampedTailZoneInterval = TailZone.GetZoneInterval(ThirdInterval.End).WithStart(ThirdInterval.End);

final PrecalculatedDateTimeZone TestZone =
    PrecalculatedDateTimeZone.NewIdIntervalsTailZone('Test', [FirstInterval, SecondInterval, ThirdInterval], TailZone);

void main() {
  port(scenarios.fixture, {
    'MinMaxOffsets': (args) {
      Assert.AreEqual(Offset.FromHours(-6), TestZone.MinOffset);
      Assert.AreEqual(Offset.FromHours(4), TestZone.MaxOffset);
    },

    'MinMaxOffsetsWithOtherTailZone': (args) {
      var tailZone = FixedDateTimeZone.NewIdOffset('TestFixed', Offset.FromHours(8));
      var testZone = PrecalculatedDateTimeZone.NewIdIntervalsTailZone('Test',
          [FirstInterval, SecondInterval, ThirdInterval], tailZone);
      Assert.AreEqual(Offset.FromHours(-5), testZone.MinOffset);
      Assert.AreEqual(Offset.FromHours(8), testZone.MaxOffset);
    },

    'MinMaxOffsetsWithNullTailZone': (args) {
      var testZone = PrecalculatedDateTimeZone.NewIdIntervalsTailZone('Test',
          [FirstInterval, SecondInterval, ThirdInterval,
              ZoneInterval('Last', ThirdInterval.End, Instant.AfterMaxValue, Offset.Zero, Offset.Zero)], null);
      Assert.AreEqual(Offset.FromHours(-5), testZone.MinOffset);
      Assert.AreEqual(Offset.FromHours(4), testZone.MaxOffset);
    },

    'GetZoneIntervalInstant_End': (args) {
      Assert.AreEqual(SecondInterval, TestZone.GetZoneInterval(SecondInterval.End.MinusDuration(Duration.Epsilon)));
    },

    'GetZoneIntervalInstant_Start': (args) {
      Assert.AreEqual(SecondInterval, TestZone.GetZoneInterval(SecondInterval.Start));
    },

    'GetZoneIntervalInstant_FinalInterval_End': (args) {
      Assert.AreEqual(ThirdInterval, TestZone.GetZoneInterval(ThirdInterval.End.MinusDuration(Duration.Epsilon)));
    },

    'GetZoneIntervalInstant_FinalInterval_Start': (args) {
      Assert.AreEqual(ThirdInterval, TestZone.GetZoneInterval(ThirdInterval.Start));
    },

    'GetZoneIntervalInstant_TailZone': (args) {
      Assert.AreEqual(ClampedTailZoneInterval, TestZone.GetZoneInterval(ThirdInterval.End));
    },

    'MapLocal_UnambiguousInPrecalculated': (args) {
      CheckMapping(LocalDateTime(2000, 6, 1, 0, 0), SecondInterval, SecondInterval, 1);
    },

    'MapLocal_UnambiguousInTailZone': (args) {
      CheckMapping(LocalDateTime(2005, 2, 1, 0, 0), ClampedTailZoneInterval, ClampedTailZoneInterval, 1);
    },

    'MapLocal_AmbiguousWithinPrecalculated': (args) {
      // Transition from +4 to -5 has a 9 hour ambiguity
      CheckMapping(ThirdInterval.IsoLocalStart, SecondInterval, ThirdInterval, 2);
    },

    'MapLocal_AmbiguousAroundTailZoneTransition': (args) {
      // Transition from -5 to -6 has a 1 hour ambiguity
      CheckMapping(ThirdInterval.IsoLocalEnd.PlusNanoseconds(-1), ThirdInterval, ClampedTailZoneInterval, 2);
    },

    'MapLocal_AmbiguousButTooEarlyInTailZoneTransition': (args) {
      // Tail zone is +10 / +8, with the transition occurring just after
      // the transition *to* the tail zone from the precalculated zone.
      // A local instant of one hour before after the transition from the precalculated zone (which is -5)
      // will therefore be ambiguous, but the resulting instants from the ambiguity occur
      // before our transition into the tail zone, so are ignored.
      var tailZone = SingleTransitionDateTimeZone(ThirdInterval.End + Duration.FromHours(1), 10, 8);
      var gapZone = PrecalculatedDateTimeZone.NewIdIntervalsTailZone('Test',
          [FirstInterval, SecondInterval, ThirdInterval], tailZone);
      var mapping = gapZone.MapLocal(ThirdInterval.IsoLocalEnd.PlusHours(-1));
      Assert.AreEqual(ThirdInterval, mapping.EarlyInterval);
      Assert.AreEqual(ThirdInterval, mapping.LateInterval);
      Assert.AreEqual(1, mapping.Count);
    },

    'MapLocal_GapWithinPrecalculated': (args) {
      // Transition from +3 to +4 has a 1 hour gap
      Assert.IsTrue(FirstInterval.IsoLocalEnd < SecondInterval.IsoLocalStart);
      CheckMapping(FirstInterval.IsoLocalEnd, FirstInterval, SecondInterval, 0);
    },

    'MapLocal_SingleIntervalAroundTailZoneTransition': (args) {
      // Tail zone is fixed at +5. A local instant of one hour before the transition
      // from the precalculated zone (which is -5) will therefore give an instant from
      // the tail zone which occurs before the precalculated-to-tail transition,
      // and can therefore be ignored, resulting in an overall unambiguous time.
      var tailZone = FixedDateTimeZone.NewOffset(Offset.FromHours(5));
      var gapZone = PrecalculatedDateTimeZone.NewIdIntervalsTailZone('Test',
          [FirstInterval, SecondInterval, ThirdInterval], tailZone);
      var mapping = gapZone.MapLocal(ThirdInterval.IsoLocalEnd.PlusHours(-1));
      Assert.AreEqual(ThirdInterval, mapping.EarlyInterval);
      Assert.AreEqual(ThirdInterval, mapping.LateInterval);
      Assert.AreEqual(1, mapping.Count);
    },

    'MapLocal_GapAroundTailZoneTransition': (args) {
      // Tail zone is fixed at +5. A local time at the transition
      // from the precalculated zone (which is -5) will therefore give an instant from
      // the tail zone which occurs before the precalculated-to-tail transition,
      // and can therefore be ignored, resulting in an overall gap.
      var tailZone = FixedDateTimeZone.NewOffset(Offset.FromHours(5));
      var gapZone = PrecalculatedDateTimeZone.NewIdIntervalsTailZone('Test',
          [FirstInterval, SecondInterval, ThirdInterval], tailZone);
      var mapping = gapZone.MapLocal(ThirdInterval.IsoLocalEnd);
      Assert.AreEqual(ThirdInterval, mapping.EarlyInterval);
      Assert.AreEqual(ZoneInterval('UTC+05', ThirdInterval.End, Instant.AfterMaxValue, Offset.FromHours(5), Offset.Zero),
          mapping.LateInterval);
      Assert.AreEqual(0, mapping.Count);
    },

    'MapLocal_GapAroundAndInTailZoneTransition': (args) {
      // Tail zone is -10 / +5, with the transition occurring just after
      // the transition *to* the tail zone from the precalculated zone.
      // A local time of one hour after the transition from the precalculated zone (which is -5)
      // will therefore be in the gap.
      var tailZone = SingleTransitionDateTimeZone(ThirdInterval.End + Duration.FromHours(1), -10, 5);
      var gapZone = PrecalculatedDateTimeZone.NewIdIntervalsTailZone('Test',
          [FirstInterval, SecondInterval, ThirdInterval], tailZone);
      var mapping = gapZone.MapLocal(ThirdInterval.IsoLocalEnd.PlusHours(1));
      Assert.AreEqual(ThirdInterval, mapping.EarlyInterval);
      Assert.AreEqual(ZoneInterval('Single-Early', ThirdInterval.End, tailZone.Transition, Offset.FromHours(-10), Offset.Zero),
          mapping.LateInterval);
      Assert.AreEqual(0, mapping.Count);
    },

    'GetZoneIntervals_NullTailZone_Eot': (args) {
      List<ZoneInterval> intervals = [
        ZoneInterval('foo', Instant.BeforeMinValue, Instant.FromUnixTimeTicks(20), Offset.Zero, Offset.Zero),
        ZoneInterval('foo', Instant.FromUnixTimeTicks(20), Instant.AfterMaxValue, Offset.Zero, Offset.Zero)
      ];
      var zone = PrecalculatedDateTimeZone.NewIdIntervalsTailZone('Test', intervals, null);
      Assert.AreEqual(intervals[1], zone.GetZoneInterval(Instant.MaxValue));
    },

    'Validation_EmptyPeriodArray': (args) {
      Assert.Throws<ArgumentError>(() => PrecalculatedDateTimeZone.ValidatePeriods(<ZoneInterval>[],
          DateTimeZone.Utc));
    },

    'Validation_BadFirstStartingPoint': (args) {
      List<ZoneInterval> intervals = [
        ZoneInterval('foo', Instant.FromUnixTimeTicks(10), Instant.FromUnixTimeTicks(20), Offset.Zero, Offset.Zero),
        ZoneInterval('foo', Instant.FromUnixTimeTicks(20), Instant.FromUnixTimeTicks(30), Offset.Zero, Offset.Zero)
      ];
      Assert.Throws<ArgumentError>(() => PrecalculatedDateTimeZone.ValidatePeriods(intervals, DateTimeZone.Utc));
    },

    'Validation_NonAdjoiningIntervals': (args) {
      List<ZoneInterval> intervals = [
        ZoneInterval('foo', Instant.BeforeMinValue, Instant.FromUnixTimeTicks(20), Offset.Zero, Offset.Zero),
        ZoneInterval('foo', Instant.FromUnixTimeTicks(25), Instant.FromUnixTimeTicks(30), Offset.Zero, Offset.Zero)
      ];
      Assert.Throws<ArgumentError>(() => PrecalculatedDateTimeZone.ValidatePeriods(intervals, DateTimeZone.Utc));
    },

    'Validation_Success': (args) {
      List<ZoneInterval> intervals = [
        ZoneInterval('foo', Instant.BeforeMinValue, Instant.FromUnixTimeTicks(20), Offset.Zero, Offset.Zero),
        ZoneInterval('foo', Instant.FromUnixTimeTicks(20), Instant.FromUnixTimeTicks(30), Offset.Zero, Offset.Zero),
        ZoneInterval('foo', Instant.FromUnixTimeTicks(30), Instant.FromUnixTimeTicks(100), Offset.Zero, Offset.Zero),
        ZoneInterval('foo', Instant.FromUnixTimeTicks(100), Instant.FromUnixTimeTicks(200), Offset.Zero, Offset.Zero)
      ];
      PrecalculatedDateTimeZone.ValidatePeriods(intervals, DateTimeZone.Utc);
    },

    'Validation_NullTailZoneWithMiddleOfTimeFinalPeriod': (args) {
      List<ZoneInterval> intervals = [
        ZoneInterval('foo', Instant.BeforeMinValue, Instant.FromUnixTimeTicks(20), Offset.Zero, Offset.Zero),
        ZoneInterval('foo', Instant.FromUnixTimeTicks(20), Instant.FromUnixTimeTicks(30), Offset.Zero, Offset.Zero)
      ];
      Assert.Throws<ArgumentError>(() => PrecalculatedDateTimeZone.ValidatePeriods(intervals, null));
    },

    'Validation_NullTailZoneWithEotPeriodEnd': (args) {
      List<ZoneInterval> intervals = [
        ZoneInterval('foo', Instant.BeforeMinValue, Instant.FromUnixTimeTicks(20), Offset.Zero, Offset.Zero),
        ZoneInterval('foo', Instant.FromUnixTimeTicks(20), Instant.AfterMaxValue, Offset.Zero, Offset.Zero)
      ];
      PrecalculatedDateTimeZone.ValidatePeriods(intervals, null);
    },

    'Serialization': (args) {
      var stream = MemoryStream();
      var writer = DateTimeZoneWriter.NewOutputStringPool(stream, null);
      TestZone.Write(writer);
      stream.Position = 0;
      // ignore: unused_local_variable
      var reloaded = PrecalculatedDateTimeZone.Read(DateTimeZoneReader.NewInputStringPool(stream, null), TestZone.Id);

      // Check equivalence by finding zone intervals
      var interval = Interval(Instant.FromUtc(1990, 1, 1, 0, 0), Instant.FromUtc(2010, 1, 1, 0, 0));
      var originalZoneIntervals = TestZone.GetZoneIntervalsInterval(interval, ZoneEqualityComparerOptions.StrictestMatch).toList();
      // noda_dart: as in the C#, this reads TestZone again, not reloaded.
      var reloadedZoneIntervals = TestZone.GetZoneIntervalsInterval(interval, ZoneEqualityComparerOptions.StrictestMatch).toList();
      CollectionAssert.AreEqual(originalZoneIntervals, reloadedZoneIntervals);
    },
  });
}

void CheckMapping(LocalDateTime localDateTime, ZoneInterval earlyInterval, ZoneInterval lateInterval, int count) {
  var mapping = TestZone.MapLocal(localDateTime);
  Assert.AreEqual(earlyInterval, mapping.EarlyInterval);
  Assert.AreEqual(lateInterval, mapping.LateInterval);
  Assert.AreEqual(count, mapping.Count);
}
