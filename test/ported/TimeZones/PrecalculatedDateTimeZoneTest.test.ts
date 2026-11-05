// Ported from NodaTime 3.3.0: src/NodaTime.Test/TimeZones/PrecalculatedDateTimeZoneTest.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda-js: internal constructors are the static factories new<ParameterNames>.

import { expect } from "vitest";
import {
  ArgumentError,
  DateTimeZone,
  Duration,
  FixedDateTimeZone,
  Instant,
  Int32,
  LocalDateTime,
  LocalTime,
  Offset,
  PrecalculatedDateTimeZone,
  SingleTransitionDateTimeZone,
  StandardDaylightAlternatingMap,
  TransitionMode,
  ZoneInterval,
  ZoneRecurrence,
  ZoneYearOffset,
} from "../../../src/noda-js/internal.ts";
import { assertNodaEqual, assertThrows } from "../../helpers/assertions.ts";
import { port } from "../../helpers/scenarios.ts";
import { fixture } from "../../scenarios/TimeZones/PrecalculatedDateTimeZoneTest.generated.ts";

/** C# `new ZoneYearOffset(mode, monthOfYear, dayOfMonth, dayOfWeek, advance, timeOfDay)`. */
function newZoneYearOffset(mode: TransitionMode, monthOfYear: number, dayOfMonth: number, dayOfWeek: number, advance: boolean, timeOfDay: LocalTime): ZoneYearOffset {
  return ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(mode, monthOfYear, dayOfMonth, dayOfWeek, advance, timeOfDay);
}

const newZone = PrecalculatedDateTimeZone.NewIdIntervalsTailZone;

const FirstInterval = new ZoneInterval("First", Instant.BeforeMinValue, Instant.FromUtc(2000, 3, 10, 10, 0), Offset.FromHours(3), Offset.Zero);

// Note that this is effectively UTC +3 + 1 hour DST.
const SecondInterval = new ZoneInterval("Second", FirstInterval.End, Instant.FromUtc(2000, 9, 15, 5, 0), Offset.FromHours(4), Offset.FromHours(1));

const ThirdInterval = new ZoneInterval("Third", SecondInterval.End, Instant.FromUtc(2005, 1, 20, 8, 0), Offset.FromHours(-5), Offset.Zero);

const Winter = new ZoneRecurrence("Winter", Offset.Zero, newZoneYearOffset(TransitionMode.Wall, 10, 5, 0, false, new LocalTime(2, 0)), 1960, Int32.MaxValue);

const Summer = new ZoneRecurrence("Summer", Offset.FromHours(1), newZoneYearOffset(TransitionMode.Wall, 3, 10, 0, false, new LocalTime(1, 0)), 1960, Int32.MaxValue);

const TailZone = StandardDaylightAlternatingMap.NewStandardOffsetStartRecurrenceEndRecurrence(Offset.FromHours(-6), Winter, Summer);

// We don't actually want an interval from the beginning of time when we ask our composite time zone for an interval
// - because that could give the wrong idea. So we clamp it at the end of the precalculated interval.
const ClampedTailZoneInterval = TailZone.GetZoneInterval(ThirdInterval.End).WithStart(ThirdInterval.End);

const TestZone = newZone("Test", [FirstInterval, SecondInterval, ThirdInterval], TailZone);

function checkMapping(localDateTime: LocalDateTime, earlyInterval: ZoneInterval, lateInterval: ZoneInterval, count: number): void {
  const mapping = TestZone.MapLocal(localDateTime);
  assertNodaEqual(mapping.EarlyInterval, earlyInterval);
  assertNodaEqual(mapping.LateInterval, lateInterval);
  expect(mapping.Count).toBe(count);
}

port(
  fixture,
  {
    MinMaxOffsets() {
      assertNodaEqual(TestZone.MinOffset, Offset.FromHours(-6));
      assertNodaEqual(TestZone.MaxOffset, Offset.FromHours(4));
    },

    MinMaxOffsetsWithOtherTailZone() {
      const tailZone = new FixedDateTimeZone("TestFixed", Offset.FromHours(8));
      const testZone = newZone("Test", [FirstInterval, SecondInterval, ThirdInterval], tailZone);
      assertNodaEqual(testZone.MinOffset, Offset.FromHours(-5));
      assertNodaEqual(testZone.MaxOffset, Offset.FromHours(8));
    },

    MinMaxOffsetsWithNullTailZone() {
      const testZone = newZone(
        "Test",
        [FirstInterval, SecondInterval, ThirdInterval, new ZoneInterval("Last", ThirdInterval.End, Instant.AfterMaxValue, Offset.Zero, Offset.Zero)],
        null,
      );
      assertNodaEqual(testZone.MinOffset, Offset.FromHours(-5));
      assertNodaEqual(testZone.MaxOffset, Offset.FromHours(4));
    },

    GetZoneIntervalInstant_End() {
      assertNodaEqual(TestZone.GetZoneInterval(Instant.Subtract(SecondInterval.End, Duration.Epsilon)), SecondInterval);
    },

    GetZoneIntervalInstant_Start() {
      assertNodaEqual(TestZone.GetZoneInterval(SecondInterval.Start), SecondInterval);
    },

    GetZoneIntervalInstant_FinalInterval_End() {
      assertNodaEqual(TestZone.GetZoneInterval(Instant.Subtract(ThirdInterval.End, Duration.Epsilon)), ThirdInterval);
    },

    GetZoneIntervalInstant_FinalInterval_Start() {
      assertNodaEqual(TestZone.GetZoneInterval(ThirdInterval.Start), ThirdInterval);
    },

    GetZoneIntervalInstant_TailZone() {
      assertNodaEqual(TestZone.GetZoneInterval(ThirdInterval.End), ClampedTailZoneInterval);
    },

    MapLocal_UnambiguousInPrecalculated() {
      checkMapping(new LocalDateTime(2000, 6, 1, 0, 0), SecondInterval, SecondInterval, 1);
    },

    MapLocal_UnambiguousInTailZone() {
      checkMapping(new LocalDateTime(2005, 2, 1, 0, 0), ClampedTailZoneInterval, ClampedTailZoneInterval, 1);
    },

    MapLocal_AmbiguousWithinPrecalculated() {
      // Transition from +4 to -5 has a 9 hour ambiguity
      checkMapping(ThirdInterval.IsoLocalStart, SecondInterval, ThirdInterval, 2);
    },

    MapLocal_AmbiguousAroundTailZoneTransition() {
      // Transition from -5 to -6 has a 1 hour ambiguity
      checkMapping(ThirdInterval.IsoLocalEnd.PlusNanoseconds(-1), ThirdInterval, ClampedTailZoneInterval, 2);
    },

    MapLocal_AmbiguousButTooEarlyInTailZoneTransition() {
      // Tail zone is +10 / +8, with the transition occurring just after
      // the transition *to* the tail zone from the precalculated zone.
      // A local instant of one hour before after the transition from the precalculated zone (which is -5)
      // will therefore be ambiguous, but the resulting instants from the ambiguity occur
      // before our transition into the tail zone, so are ignored.
      const tailZone = new SingleTransitionDateTimeZone(Instant.Add(ThirdInterval.End, Duration.FromHours(1)), 10, 8);
      const gapZone = newZone("Test", [FirstInterval, SecondInterval, ThirdInterval], tailZone);
      const mapping = gapZone.MapLocal(ThirdInterval.IsoLocalEnd.PlusHours(-1));
      assertNodaEqual(mapping.EarlyInterval, ThirdInterval);
      assertNodaEqual(mapping.LateInterval, ThirdInterval);
      expect(mapping.Count).toBe(1);
    },

    MapLocal_GapWithinPrecalculated() {
      // Transition from +3 to +4 has a 1 hour gap
      expect(FirstInterval.IsoLocalEnd.CompareTo(SecondInterval.IsoLocalStart) < 0).toBe(true);
      checkMapping(FirstInterval.IsoLocalEnd, FirstInterval, SecondInterval, 0);
    },

    MapLocal_SingleIntervalAroundTailZoneTransition() {
      // Tail zone is fixed at +5. A local instant of one hour before the transition
      // from the precalculated zone (which is -5) will therefore give an instant from
      // the tail zone which occurs before the precalculated-to-tail transition,
      // and can therefore be ignored, resulting in an overall unambiguous time.
      const tailZone = new FixedDateTimeZone(Offset.FromHours(5));
      const gapZone = newZone("Test", [FirstInterval, SecondInterval, ThirdInterval], tailZone);
      const mapping = gapZone.MapLocal(ThirdInterval.IsoLocalEnd.PlusHours(-1));
      assertNodaEqual(mapping.EarlyInterval, ThirdInterval);
      assertNodaEqual(mapping.LateInterval, ThirdInterval);
      expect(mapping.Count).toBe(1);
    },

    MapLocal_GapAroundTailZoneTransition() {
      // Tail zone is fixed at +5. A local time at the transition
      // from the precalculated zone (which is -5) will therefore give an instant from
      // the tail zone which occurs before the precalculated-to-tail transition,
      // and can therefore be ignored, resulting in an overall gap.
      const tailZone = new FixedDateTimeZone(Offset.FromHours(5));
      const gapZone = newZone("Test", [FirstInterval, SecondInterval, ThirdInterval], tailZone);
      const mapping = gapZone.MapLocal(ThirdInterval.IsoLocalEnd);
      assertNodaEqual(mapping.EarlyInterval, ThirdInterval);
      assertNodaEqual(mapping.LateInterval, new ZoneInterval("UTC+05", ThirdInterval.End, Instant.AfterMaxValue, Offset.FromHours(5), Offset.Zero));
      expect(mapping.Count).toBe(0);
    },

    MapLocal_GapAroundAndInTailZoneTransition() {
      // Tail zone is -10 / +5, with the transition occurring just after
      // the transition *to* the tail zone from the precalculated zone.
      // A local time of one hour after the transition from the precalculated zone (which is -5)
      // will therefore be in the gap.
      const tailZone = new SingleTransitionDateTimeZone(Instant.Add(ThirdInterval.End, Duration.FromHours(1)), -10, +5);
      const gapZone = newZone("Test", [FirstInterval, SecondInterval, ThirdInterval], tailZone);
      const mapping = gapZone.MapLocal(ThirdInterval.IsoLocalEnd.PlusHours(1));
      assertNodaEqual(mapping.EarlyInterval, ThirdInterval);
      assertNodaEqual(mapping.LateInterval, new ZoneInterval("Single-Early", ThirdInterval.End, tailZone.Transition, Offset.FromHours(-10), Offset.Zero));
      expect(mapping.Count).toBe(0);
    },

    GetZoneIntervals_NullTailZone_Eot() {
      const intervals = [
        new ZoneInterval("foo", Instant.BeforeMinValue, Instant.FromUnixTimeTicks(20), Offset.Zero, Offset.Zero),
        new ZoneInterval("foo", Instant.FromUnixTimeTicks(20), Instant.AfterMaxValue, Offset.Zero, Offset.Zero),
      ];
      const zone = newZone("Test", intervals, null);
      assertNodaEqual(zone.GetZoneInterval(Instant.MaxValue), intervals[1]);
    },

    Validation_EmptyPeriodArray() {
      assertThrows(ArgumentError, () => PrecalculatedDateTimeZone.ValidatePeriods([], DateTimeZone.Utc));
    },

    Validation_BadFirstStartingPoint() {
      const intervals = [
        new ZoneInterval("foo", Instant.FromUnixTimeTicks(10), Instant.FromUnixTimeTicks(20), Offset.Zero, Offset.Zero),
        new ZoneInterval("foo", Instant.FromUnixTimeTicks(20), Instant.FromUnixTimeTicks(30), Offset.Zero, Offset.Zero),
      ];
      assertThrows(ArgumentError, () => PrecalculatedDateTimeZone.ValidatePeriods(intervals, DateTimeZone.Utc));
    },

    Validation_NonAdjoiningIntervals() {
      const intervals = [
        new ZoneInterval("foo", Instant.BeforeMinValue, Instant.FromUnixTimeTicks(20), Offset.Zero, Offset.Zero),
        new ZoneInterval("foo", Instant.FromUnixTimeTicks(25), Instant.FromUnixTimeTicks(30), Offset.Zero, Offset.Zero),
      ];
      assertThrows(ArgumentError, () => PrecalculatedDateTimeZone.ValidatePeriods(intervals, DateTimeZone.Utc));
    },

    Validation_Success() {
      const intervals = [
        new ZoneInterval("foo", Instant.BeforeMinValue, Instant.FromUnixTimeTicks(20), Offset.Zero, Offset.Zero),
        new ZoneInterval("foo", Instant.FromUnixTimeTicks(20), Instant.FromUnixTimeTicks(30), Offset.Zero, Offset.Zero),
        new ZoneInterval("foo", Instant.FromUnixTimeTicks(30), Instant.FromUnixTimeTicks(100), Offset.Zero, Offset.Zero),
        new ZoneInterval("foo", Instant.FromUnixTimeTicks(100), Instant.FromUnixTimeTicks(200), Offset.Zero, Offset.Zero),
      ];
      PrecalculatedDateTimeZone.ValidatePeriods(intervals, DateTimeZone.Utc);
    },

    Validation_NullTailZoneWithMiddleOfTimeFinalPeriod() {
      const intervals = [
        new ZoneInterval("foo", Instant.BeforeMinValue, Instant.FromUnixTimeTicks(20), Offset.Zero, Offset.Zero),
        new ZoneInterval("foo", Instant.FromUnixTimeTicks(20), Instant.FromUnixTimeTicks(30), Offset.Zero, Offset.Zero),
      ];
      assertThrows(ArgumentError, () => PrecalculatedDateTimeZone.ValidatePeriods(intervals, null));
    },

    Validation_NullTailZoneWithEotPeriodEnd() {
      const intervals = [
        new ZoneInterval("foo", Instant.BeforeMinValue, Instant.FromUnixTimeTicks(20), Offset.Zero, Offset.Zero),
        new ZoneInterval("foo", Instant.FromUnixTimeTicks(20), Instant.AfterMaxValue, Offset.Zero, Offset.Zero),
      ];
      PrecalculatedDateTimeZone.ValidatePeriods(intervals, null);
    },
  },
  {
    skip: {
      Serialization: "Needs DateTimeZoneWriter (PrecalculatedDateTimeZone.Write), which isn't ported",
    },
  },
);
