// Ported from NodaTime 3.3.0: src/NodaTime.Test/TimeZones/ZoneRecurrenceTest.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda-js: the internal ZoneYearOffset constructors are the static factories
// newModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(AddDay). System.DayOfWeek values are written as numbers.

import { expect } from "vitest";
import {
  ArgumentNullError,
  Duration,
  GregorianYearMonthDayCalculator,
  Instant,
  InvalidOperationError,
  IsoDayOfWeek,
  LocalTime,
  NodaConstants,
  Offset,
  Transition,
  TransitionMode,
  ZoneRecurrence,
  ZoneYearOffset,
} from "../../../src/noda-js/internal.ts";
import { assertNodaEqual, assertThrows } from "../../helpers/assertions.ts";
import { port } from "../../helpers/scenarios.ts";
import { TestHelper } from "../../helpers/TestHelper.ts";
import { fixture } from "../../scenarios/TimeZones/ZoneRecurrenceTest.generated.ts";

/** C# `new ZoneYearOffset(mode, monthOfYear, dayOfMonth, dayOfWeek, advance, timeOfDay[, addDay])`. */
function newZoneYearOffset(
  mode: TransitionMode,
  monthOfYear: number,
  dayOfMonth: number,
  dayOfWeek: number,
  advance: boolean,
  timeOfDay: LocalTime,
  addDay?: boolean,
): ZoneYearOffset {
  return addDay === undefined
    ? ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(mode, monthOfYear, dayOfMonth, dayOfWeek, advance, timeOfDay)
    : ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDayAddDay(mode, monthOfYear, dayOfMonth, dayOfWeek, advance, timeOfDay, addDay);
}

/** System.DayOfWeek.Wednesday */
const DayOfWeekWednesday = 3;

/** Assert.AreEqual on two Transition? values. */
function assertTransitionEqual(actual: Transition | null, expected: Transition | null): void {
  if (expected === null) {
    expect(actual).toBeNull();
    return;
  }
  assertNodaEqual(actual, expected);
}

port(
  fixture,
  {
    Constructor_nullName_exception() {
      const yearOffset = newZoneYearOffset(TransitionMode.Utc, 10, 31, DayOfWeekWednesday, true, LocalTime.Midnight);
      assertThrows(ArgumentNullError, () => new ZoneRecurrence(null!, Offset.Zero, yearOffset, 1971, 2009));
    },

    Constructor_nullYearOffset_exception() {
      assertThrows(ArgumentNullError, () => new ZoneRecurrence("bob", Offset.Zero, null!, 1971, 2009));
    },

    Next_BeforeFirstYear() {
      const januaryFirstMidnight = newZoneYearOffset(TransitionMode.Utc, 1, 1, 0, true, LocalTime.Midnight);
      const recurrence = new ZoneRecurrence("bob", Offset.Zero, januaryFirstMidnight, 1970, 1972);
      const actual = recurrence.Next(Instant.MinValue, Offset.Zero, Offset.Zero);
      const expected = new Transition(NodaConstants.UnixEpoch, Offset.Zero);
      assertTransitionEqual(actual, expected);
    },

    Next_FirstYear() {
      const januaryFirstMidnight = newZoneYearOffset(TransitionMode.Utc, 1, 1, 0, true, LocalTime.Midnight);
      const recurrence = new ZoneRecurrence("bob", Offset.Zero, januaryFirstMidnight, 1970, 1972);
      const actual = recurrence.Next(NodaConstants.UnixEpoch, Offset.Zero, Offset.Zero);
      const expected = new Transition(Instant.FromUtc(1971, 1, 1, 0, 0), Offset.Zero);
      assertTransitionEqual(actual, expected);
    },

    NextTwice_FirstYear() {
      const januaryFirstMidnight = newZoneYearOffset(TransitionMode.Utc, 1, 1, 0, true, LocalTime.Midnight);
      const recurrence = new ZoneRecurrence("bob", Offset.Zero, januaryFirstMidnight, 1970, 1972);
      let actual = recurrence.Next(NodaConstants.UnixEpoch, Offset.Zero, Offset.Zero);
      actual = recurrence.Next(actual!.Instant, Offset.Zero, Offset.Zero);
      const expected = new Transition(Instant.FromUtc(1972, 1, 1, 0, 0), Offset.Zero);
      assertTransitionEqual(actual, expected);
    },

    Next_BeyondLastYear_null() {
      const afterRecurrenceEnd = Instant.FromUtc(1980, 1, 1, 0, 0);
      const januaryFirstMidnight = newZoneYearOffset(TransitionMode.Utc, 1, 1, 0, true, LocalTime.Midnight);
      const recurrence = new ZoneRecurrence("bob", Offset.Zero, januaryFirstMidnight, 1970, 1972);
      const actual = recurrence.Next(afterRecurrenceEnd, Offset.Zero, Offset.Zero);
      const expected = null;
      assertTransitionEqual(actual, expected);
    },

    PreviousOrSame_AfterLastYear() {
      const januaryFirstMidnight = newZoneYearOffset(TransitionMode.Utc, 1, 1, 0, true, LocalTime.Midnight);
      const recurrence = new ZoneRecurrence("bob", Offset.Zero, januaryFirstMidnight, 1970, 1972);
      const actual = recurrence.PreviousOrSame(Instant.MaxValue, Offset.Zero, Offset.Zero);
      const expected = new Transition(Instant.FromUtc(1972, 1, 1, 0, 0), Offset.Zero);
      assertTransitionEqual(actual, expected);
    },

    PreviousOrSame_LastYear() {
      const januaryFirstMidnight = newZoneYearOffset(TransitionMode.Utc, 1, 1, 0, true, LocalTime.Midnight);
      const recurrence = new ZoneRecurrence("bob", Offset.Zero, januaryFirstMidnight, 1970, 1972);
      const actual = recurrence.PreviousOrSame(Instant.Subtract(Instant.FromUtc(1971, 1, 1, 0, 0), Duration.Epsilon), Offset.Zero, Offset.Zero);
      const expected = new Transition(NodaConstants.UnixEpoch, Offset.Zero);
      assertTransitionEqual(actual, expected);
    },

    PreviousOrSameTwice_LastYear() {
      const januaryFirstMidnight = newZoneYearOffset(TransitionMode.Utc, 1, 1, 0, true, LocalTime.Midnight);
      const recurrence = new ZoneRecurrence("bob", Offset.Zero, januaryFirstMidnight, 1970, 1973);
      let actual = recurrence.PreviousOrSame(Instant.Subtract(Instant.FromUtc(1972, 1, 1, 0, 0), Duration.Epsilon), Offset.Zero, Offset.Zero);
      actual = recurrence.PreviousOrSame(Instant.Subtract(actual!.Instant, Duration.Epsilon), Offset.Zero, Offset.Zero);
      const expected = new Transition(NodaConstants.UnixEpoch, Offset.Zero);
      assertTransitionEqual(actual, expected);
    },

    PreviousOrSame_OnFirstYear_null() {
      // Transition is on January 2nd, but we're asking for January 1st.
      const januaryFirstMidnight = newZoneYearOffset(TransitionMode.Utc, 1, 2, 0, true, LocalTime.Midnight);
      const recurrence = new ZoneRecurrence("bob", Offset.Zero, januaryFirstMidnight, 1970, 1972);
      const actual = recurrence.PreviousOrSame(NodaConstants.UnixEpoch, Offset.Zero, Offset.Zero);
      const expected = null;
      assertTransitionEqual(actual, expected);
    },

    PreviousOrSame_BeforeFirstYear_null() {
      const januaryFirstMidnight = newZoneYearOffset(TransitionMode.Utc, 1, 1, 0, true, LocalTime.Midnight);
      const recurrence = new ZoneRecurrence("bob", Offset.Zero, januaryFirstMidnight, 1970, 1972);
      const actual = recurrence.PreviousOrSame(Instant.Subtract(NodaConstants.UnixEpoch, Duration.Epsilon), Offset.Zero, Offset.Zero);
      const expected = null;
      assertTransitionEqual(actual, expected);
    },

    Next_ExcludesGivenInstant() {
      const january10thMidnight = newZoneYearOffset(TransitionMode.Utc, 1, 10, 0, true, LocalTime.Midnight);
      const recurrence = new ZoneRecurrence("x", Offset.Zero, january10thMidnight, 2000, 3000);
      const transition = Instant.FromUtc(2500, 1, 10, 0, 0);
      const next = recurrence.Next(transition, Offset.Zero, Offset.Zero);
      expect(next!.Instant.InUtc().Year).toBe(2501);
    },

    PreviousOrSame_IncludesGivenInstant() {
      const january10thMidnight = newZoneYearOffset(TransitionMode.Utc, 1, 10, 0, true, LocalTime.Midnight);
      const recurrence = new ZoneRecurrence("x", Offset.Zero, january10thMidnight, 2000, 3000);
      const transition = Instant.FromUtc(2500, 1, 10, 0, 0);
      const next = recurrence.PreviousOrSame(transition, Offset.Zero, Offset.Zero);
      assertNodaEqual(next!.Instant, transition);
    },

    NextOrFail_Fail() {
      const afterRecurrenceEnd = Instant.FromUtc(1980, 1, 1, 0, 0);
      const januaryFirstMidnight = newZoneYearOffset(TransitionMode.Utc, 1, 1, 0, true, LocalTime.Midnight);
      const recurrence = new ZoneRecurrence("bob", Offset.Zero, januaryFirstMidnight, 1970, 1972);
      assertThrows(InvalidOperationError, () => recurrence.NextOrFail(afterRecurrenceEnd, Offset.Zero, Offset.Zero));
    },

    PreviousOrSameOrFail_Fail() {
      const beforeRecurrenceStart = Instant.FromUtc(1960, 1, 1, 0, 0);
      const januaryFirstMidnight = newZoneYearOffset(TransitionMode.Utc, 1, 1, 0, true, LocalTime.Midnight);
      const recurrence = new ZoneRecurrence("bob", Offset.Zero, januaryFirstMidnight, 1970, 1972);
      assertThrows(InvalidOperationError, () => recurrence.PreviousOrSameOrFail(beforeRecurrenceStart, Offset.Zero, Offset.Zero));
    },

    IEquatable_Tests() {
      const yearOffset = newZoneYearOffset(TransitionMode.Utc, 10, 31, DayOfWeekWednesday, true, LocalTime.Midnight);

      const value = new ZoneRecurrence("bob", Offset.Zero, yearOffset, 1971, 2009);
      const equalValue = new ZoneRecurrence("bob", Offset.Zero, yearOffset, 1971, 2009);
      const unequalValue = new ZoneRecurrence("foo", Offset.Zero, yearOffset, 1971, 2009);

      TestHelper.testEqualsClass(value, equalValue, unequalValue);
    },

    December31st2400_MaxYear_UtcTransition() {
      // Each year, the transition is at the midnight at the *end* of December 31st...
      const yearOffset = newZoneYearOffset(TransitionMode.Utc, 12, 31, 0, true, LocalTime.Midnight, true);
      // ... and the recurrence is valid for the whole of time
      const recurrence = new ZoneRecurrence(
        "awkward",
        Offset.FromHours(1),
        yearOffset,
        GregorianYearMonthDayCalculator.MinGregorianYear,
        GregorianYearMonthDayCalculator.MaxGregorianYear,
      );

      const next = recurrence.Next(Instant.FromUtc(9999, 6, 1, 0, 0), Offset.Zero, Offset.Zero);
      assertNodaEqual(next!.Instant, Instant.AfterMaxValue);
    },

    December31st2400_AskAtNanoBeforeLastTransition() {
      // The transition occurs after the end of the maximum
      // Each year, the transition is at the midnight at the *end* of December 31st...
      const yearOffset = newZoneYearOffset(TransitionMode.Utc, 12, 31, 0, true, LocalTime.Midnight, true);
      // ... and the recurrence is valid for the whole of time
      const recurrence = new ZoneRecurrence("awkward", Offset.FromHours(1), yearOffset, 1, 5000);

      // We can find the final transition
      const finalTransition = Instant.FromUtc(5001, 1, 1, 0, 0);
      const next = recurrence.Next(Instant.Subtract(finalTransition, Duration.Epsilon), Offset.Zero, Offset.Zero);
      const expected = new Transition(finalTransition, Offset.FromHours(1));
      assertTransitionEqual(next, expected);

      // But we correctly reject anything after that
      expect(recurrence.Next(finalTransition, Offset.Zero, Offset.Zero)).toBeNull();
    },

    WithName() {
      const yearOffset = newZoneYearOffset(TransitionMode.Utc, 10, 31, DayOfWeekWednesday, true, LocalTime.Midnight);
      const original = new ZoneRecurrence("original", Offset.FromHours(1), yearOffset, 1900, 2000);
      const renamed = original.WithName("renamed");
      expect(renamed.Name).toBe("renamed");
      assertNodaEqual(renamed.Savings, original.Savings);
      assertNodaEqual(renamed.YearOffset, original.YearOffset);
      expect(renamed.FromYear).toBe(original.FromYear);
      expect(renamed.ToYear).toBe(original.ToYear);
    },

    ForSingleYear() {
      const yearOffset = newZoneYearOffset(TransitionMode.Utc, 10, 31, DayOfWeekWednesday, true, LocalTime.Midnight);
      const original = new ZoneRecurrence("original", Offset.FromHours(1), yearOffset, 1900, 2000);
      const singleYear = original.ForSingleYear(2017);
      expect(singleYear.Name).toBe(original.Name);
      assertNodaEqual(singleYear.Savings, original.Savings);
      assertNodaEqual(singleYear.YearOffset, original.YearOffset);
      expect(singleYear.FromYear).toBe(2017);
      expect(singleYear.ToYear).toBe(2017);
    },

    ZoneRecurrenceToString() {
      const yearOffset = newZoneYearOffset(TransitionMode.Utc, 10, 31, DayOfWeekWednesday, true, LocalTime.Midnight);
      const recurrence = new ZoneRecurrence("name", Offset.FromHours(1), yearOffset, 1900, 2000);
      expect(recurrence.toString()).toBe(
        "name +01 ZoneYearOffset[mode:Utc monthOfYear:10 dayOfMonth:31 dayOfWeek:3 advance:True timeOfDay:00:00:00 addDay:False] [1900-2000]",
      );
    },
  },
  {
    skip: {
      Serialization: "Needs DateTimeZoneWriter (DtzIoHelper round trip), which isn't ported",
      Serialization_Infinite: "Needs DateTimeZoneWriter (DtzIoHelper round trip), which isn't ported",
    },
  },
);
