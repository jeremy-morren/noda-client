// Ported from NodaTime 3.3.0: src/NodaTime.Test/LocalDateTimeTest.cs (+ .Pseudomutators.cs)
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda-js: C# operators map to LocalDateTime.add / subtract (+, -), LocalDate.add (date + time) and CompareTo / equals
// (comparisons). LocalDateTime.With(Func<LocalTime, LocalTime>) is withTimeAdjuster. C# long arguments beyond 2^53 are
// decimal strings. DateTimeZoneProviders.Tzdb is the bundled tzdb provider. C# Deconstruct isn't ported; JS
// destructuring reads the getters.

import { expect } from "vitest";
import {
  AmbiguousTimeError,
  ArgumentError,
  ArgumentOutOfRangeError,
  CalendarSystem,
  DateAdjusters,
  DateTimeZone,
  GregorianYearMonthDayCalculator,
  IsoDayOfWeek,
  LocalDate,
  LocalDateTime,
  LocalTime,
  NodaConstants,
  Offset,
  OverflowError,
  Period,
  PeriodBuilder,
  Resolvers,
  SkippedTimeError,
  TimeAdjusters,
} from "../../src/noda-js/internal.ts";
import { tzdb } from "../../src/noda-js/entries/tzdb-bundled.ts";
import { assertNodaEqual, assertThrows } from "../helpers/assertions.ts";
import { port } from "../helpers/scenarios.ts";
import { TestHelper } from "../helpers/TestHelper.ts";
import { fixture } from "../scenarios/LocalDateTimeTest.generated.ts";

const Pacific = (): DateTimeZone => tzdb.Get("America/Los_Angeles");

/** C#'s non-generic IComparable view (noda-js folds IComparable.CompareTo(object) into CompareTo). */
type NonGenericComparable = { CompareTo(other: unknown): number };

// #region LocalDateTimeTest.cs

const mainBodies = {
  TimeProperties_AfterEpoch() {
    // Use the largest valid year as part of validating against overflow
    const ldt = new LocalDateTime(GregorianYearMonthDayCalculator.MaxGregorianYear, 1, 2, 15, 48, 25).PlusNanoseconds(123456789);
    expect(ldt.Hour).toBe(15);
    expect(ldt.ClockHourOfHalfDay).toBe(3);
    expect(ldt.Minute).toBe(48);
    expect(ldt.Second).toBe(25);
    expect(ldt.Millisecond).toBe(123);
    expect(ldt.TickOfSecond).toBe(1234567);
    expect(ldt.TickOfDay).toBe(15 * NodaConstants.TicksPerHour +
      48 * NodaConstants.TicksPerMinute +
      25 * NodaConstants.TicksPerSecond +
      1234567);
    expect(ldt.NanosecondOfDay).toBe(15 * NodaConstants.NanosecondsPerHour +
      48 * NodaConstants.NanosecondsPerMinute +
      25 * NodaConstants.NanosecondsPerSecond +
      123456789);
    expect(ldt.NanosecondOfSecond).toBe(123456789);
  },

  TimeProperties_BeforeEpoch() {
    // Use the smallest valid year number as part of validating against overflow
    const ldt = new LocalDateTime(GregorianYearMonthDayCalculator.MinGregorianYear, 1, 2, 15, 48, 25).PlusNanoseconds(123456789);
    expect(ldt.Hour).toBe(15);
    expect(ldt.ClockHourOfHalfDay).toBe(3);
    expect(ldt.Minute).toBe(48);
    expect(ldt.Second).toBe(25);
    expect(ldt.Millisecond).toBe(123);
    expect(ldt.TickOfSecond).toBe(1234567);
    expect(ldt.TickOfDay).toBe(15 * NodaConstants.TicksPerHour +
      48 * NodaConstants.TicksPerMinute +
      25 * NodaConstants.TicksPerSecond +
      1234567);
    expect(ldt.NanosecondOfDay).toBe(15 * NodaConstants.NanosecondsPerHour +
      48 * NodaConstants.NanosecondsPerMinute +
      25 * NodaConstants.NanosecondsPerSecond +
      123456789);
    expect(ldt.NanosecondOfSecond).toBe(123456789);
  },

  WithCalendar() {
    const isoEpoch = new LocalDateTime(1970, 1, 1, 0, 0, 0);
    const julianEpoch = isoEpoch.WithCalendar(CalendarSystem.Julian);
    assertNodaEqual(julianEpoch.Year, 1969);
    assertNodaEqual(julianEpoch.Month, 12);
    assertNodaEqual(julianEpoch.Day, 19);
    assertNodaEqual(julianEpoch.TimeOfDay, isoEpoch.TimeOfDay);
  },

  // Verifies that negative local instant ticks don't cause a problem with the date
  TimeOfDay_Before1970() {
    const dateTime = new LocalDateTime(1965, 11, 8, 12, 5, 23);
    const expected = new LocalTime(12, 5, 23);
    assertNodaEqual(dateTime.TimeOfDay, expected);
  },

  // Verifies that positive local instant ticks don't cause a problem with the date
  TimeOfDay_After1970() {
    const dateTime = new LocalDateTime(1975, 11, 8, 12, 5, 23);
    const expected = new LocalTime(12, 5, 23);
    assertNodaEqual(dateTime.TimeOfDay, expected);
  },

  // Verifies that negative local instant ticks don't cause a problem with the date
  Date_Before1970() {
    const dateTime = new LocalDateTime(1965, 11, 8, 12, 5, 23);
    const expected = new LocalDate(1965, 11, 8);
    assertNodaEqual(dateTime.Date, expected);
  },

  // Verifies that positive local instant ticks don't cause a problem with the date
  Date_After1970() {
    const dateTime = new LocalDateTime(1975, 11, 8, 12, 5, 23);
    const expected = new LocalDate(1975, 11, 8);
    assertNodaEqual(dateTime.Date, expected);
  },

  DayOfWeek_AroundEpoch() {
    // Test about couple of months around the Unix epoch. If that works, I'm confident the rest will.
    let dateTime = new LocalDateTime(1969, 12, 1, 0, 0);
    for (let i = 0; i < 60; i++) {
      // Check once per hour of the day, just in case something's messed up based on the time of day.
      for (let hour = 0; hour < 24; hour++) {
        // noda-js: the BCL DateTime.DayOfWeek reference is a JS Date's UTC day of week (0 = Sunday).
        const jsDate = new Date(Date.UTC(dateTime.Year, dateTime.Month - 1, dateTime.Day, dateTime.Hour));
        const expected = (jsDate.getUTCDay() === 0 ? 7 : jsDate.getUTCDay()) as IsoDayOfWeek;
        expect(dateTime.DayOfWeek).toBe(expected);
        dateTime = dateTime.PlusHours(1);
      }
    }
  },

  ClockHourOfHalfDay() {
    expect(new LocalDateTime(1975, 11, 8, 0, 0, 0).ClockHourOfHalfDay).toBe(12);
    expect(new LocalDateTime(1975, 11, 8, 1, 0, 0).ClockHourOfHalfDay).toBe(1);
    expect(new LocalDateTime(1975, 11, 8, 12, 0, 0).ClockHourOfHalfDay).toBe(12);
    expect(new LocalDateTime(1975, 11, 8, 13, 0, 0).ClockHourOfHalfDay).toBe(1);
    expect(new LocalDateTime(1975, 11, 8, 23, 0, 0).ClockHourOfHalfDay).toBe(11);
  },

  Operators_SameCalendar() {
    const value1 = new LocalDateTime(2011, 1, 2, 10, 30, 0);
    const value2 = new LocalDateTime(2011, 1, 2, 10, 30, 0);
    const value3 = new LocalDateTime(2011, 1, 2, 10, 45, 0);
    TestHelper.testOperatorComparisonEquality(value1, value2, value3);
  },

  Operators_DifferentCalendars_Throws() {
    const value1 = new LocalDateTime(2011, 1, 2, 10, 30);
    const value2 = new LocalDateTime(2011, 1, 3, 10, 30, CalendarSystem.Julian);

    expect(value1.Equals(value2)).toBe(false); // C# ==
    expect(!value1.Equals(value2)).toBe(true); // C# !=

    assertThrows(ArgumentError, () => (value1.CompareTo(value2) < 0).toString());
    assertThrows(ArgumentError, () => (value1.CompareTo(value2) <= 0).toString());
    assertThrows(ArgumentError, () => (value1.CompareTo(value2) > 0).toString());
    assertThrows(ArgumentError, () => (value1.CompareTo(value2) >= 0).toString());
  },

  CompareTo_SameCalendar() {
    const value1 = new LocalDateTime(2011, 1, 2, 10, 30);
    const value2 = new LocalDateTime(2011, 1, 2, 10, 30);
    const value3 = new LocalDateTime(2011, 1, 2, 10, 45);

    expect(value1.CompareTo(value2)).toBe(0);
    expect(value1.CompareTo(value3)).toBeLessThan(0);
    expect(value3.CompareTo(value2)).toBeGreaterThan(0);
  },

  /** IComparable.CompareTo works properly for LocalDateTime inputs with different calendars. */
  IComparableCompareTo_SameCalendar() {
    const value1 = new LocalDateTime(2011, 1, 2, 10, 30);
    const value2 = new LocalDateTime(2011, 1, 2, 10, 30);
    const value3 = new LocalDateTime(2011, 1, 2, 10, 45);

    const i_value1: NonGenericComparable = value1;
    const i_value3: NonGenericComparable = value3;

    expect(i_value1.CompareTo(value2)).toBe(0);
    expect(i_value1.CompareTo(value3)).toBeLessThan(0);
    expect(i_value3.CompareTo(value2)).toBeGreaterThan(0);
  },

  /** IComparable.CompareTo returns a positive number for a null input. */
  IComparableCompareTo_Null_Positive() {
    const instance = new LocalDateTime(2012, 3, 5, 10, 45);
    const comparable: NonGenericComparable = instance;
    const result = comparable.CompareTo(null);
    expect(result).toBeGreaterThan(0);
  },

  /** IComparable.CompareTo throws an ArgumentException for non-null arguments that are not a LocalDateTime. */
  IComparableCompareTo_WrongType_ArgumentException() {
    const instance = new LocalDateTime(2012, 3, 5, 10, 45);
    const i_instance: NonGenericComparable = instance;
    const arg = new LocalDate(2012, 3, 6);
    assertThrows(ArgumentError, () => i_instance.CompareTo(arg));
  },

  WithOffset() {
    const offset = Offset.FromHoursAndMinutes(5, 10);
    const localDateTime = new LocalDateTime(2009, 12, 22, 21, 39, 30);
    const offsetDateTime = localDateTime.WithOffset(offset);
    assertNodaEqual(offsetDateTime.LocalDateTime, localDateTime);
    assertNodaEqual(offsetDateTime.Offset, offset);
  },

  InUtc() {
    const local = new LocalDateTime(2009, 12, 22, 21, 39, 30);
    const zoned = local.InUtc();
    assertNodaEqual(zoned.LocalDateTime, local);
    assertNodaEqual(zoned.Offset, Offset.Zero);
    expect(zoned.Zone).toBe(DateTimeZone.Utc);
  },

  InZoneStrictly_InWinter() {
    const local = new LocalDateTime(2009, 12, 22, 21, 39, 30);
    const zoned = local.InZoneStrictly(Pacific());
    assertNodaEqual(zoned.LocalDateTime, local);
    assertNodaEqual(zoned.Offset, Offset.FromHours(-8));
  },

  InZoneStrictly_InSummer() {
    const local = new LocalDateTime(2009, 6, 22, 21, 39, 30);
    const zoned = local.InZoneStrictly(Pacific());
    assertNodaEqual(zoned.LocalDateTime, local);
    assertNodaEqual(zoned.Offset, Offset.FromHours(-7));
  },

  /**
   * Pacific time changed from -7 to -8 at 2am wall time on November 2nd 2009,
   * so 2am became 1am.
   */
  InZoneStrictly_ThrowsWhenAmbiguous() {
    const local = new LocalDateTime(2009, 11, 1, 1, 30, 0);
    assertThrows(AmbiguousTimeError, () => local.InZoneStrictly(Pacific()));
  },

  /**
   * Pacific time changed from -8 to -7 at 2am wall time on March 8th 2009,
   * so 2am became 3am. This means that 2.30am doesn't exist on that day.
   */
  InZoneStrictly_ThrowsWhenSkipped() {
    const local = new LocalDateTime(2009, 3, 8, 2, 30, 0);
    assertThrows(SkippedTimeError, () => local.InZoneStrictly(Pacific()));
  },

  /**
   * Pacific time changed from -7 to -8 at 2am wall time on November 2nd 2009,
   * so 2am became 1am. We'll return the earlier result, i.e. with the offset of -7
   */
  InZoneLeniently_AmbiguousTime_ReturnsEarlierMapping() {
    const local = new LocalDateTime(2009, 11, 1, 1, 30, 0);
    const zoned = local.InZoneLeniently(Pacific());
    assertNodaEqual(zoned.LocalDateTime, local);
    assertNodaEqual(zoned.Offset, Offset.FromHours(-7));
  },

  /**
   * Pacific time changed from -8 to -7 at 2am wall time on March 8th 2009,
   * so 2am became 3am. This means that 2:30am doesn't exist on that day.
   * We'll return 3:30am, the forward-shifted value.
   */
  InZoneLeniently_ReturnsStartOfSecondInterval() {
    const local = new LocalDateTime(2009, 3, 8, 2, 30, 0);
    const zoned = local.InZoneLeniently(Pacific());
    assertNodaEqual(zoned.LocalDateTime, new LocalDateTime(2009, 3, 8, 3, 30, 0));
    assertNodaEqual(zoned.Offset, Offset.FromHours(-7));
  },

  InZone() {
    // Don't need much for this - it only delegates.
    const ambiguous = new LocalDateTime(2009, 11, 1, 1, 30, 0);
    const skipped = new LocalDateTime(2009, 3, 8, 2, 30, 0);
    assertNodaEqual(ambiguous.InZone(Pacific(), Resolvers.LenientResolver), Pacific().AtLeniently(ambiguous));
    assertNodaEqual(skipped.InZone(Pacific(), Resolvers.LenientResolver), Pacific().AtLeniently(skipped));
  },

  MinMax_DifferentCalendars_Throws() {
    const ldt1 = new LocalDateTime(2011, 1, 2, 2, 20);
    const ldt2 = new LocalDateTime(1500, 1, 1, 5, 10, CalendarSystem.Julian);

    assertThrows(ArgumentError, () => LocalDateTime.Max(ldt1, ldt2));
    assertThrows(ArgumentError, () => LocalDateTime.Min(ldt1, ldt2));
  },

  MinMax_SameCalendar() {
    const ldt1 = new LocalDateTime(1500, 1, 1, 7, 20, CalendarSystem.Julian);
    const ldt2 = new LocalDateTime(1500, 1, 1, 5, 10, CalendarSystem.Julian);

    assertNodaEqual(LocalDateTime.Max(ldt1, ldt2), ldt1);
    assertNodaEqual(LocalDateTime.Max(ldt2, ldt1), ldt1);
    assertNodaEqual(LocalDateTime.Min(ldt1, ldt2), ldt2);
    assertNodaEqual(LocalDateTime.Min(ldt2, ldt1), ldt2);
  },

  Deconstruction() {
    const value = new LocalDateTime(2017, 10, 15, 21, 30, 0);
    const expectedDate = new LocalDate(2017, 10, 15);
    const expectedTime = new LocalTime(21, 30, 0);

    const { Date: actualDate, TimeOfDay: actualTime } = value;

    assertNodaEqual(actualDate, expectedDate);
    assertNodaEqual(actualTime, expectedTime);
  },

  Equality() {
    TestHelper.testEqualsStruct(
      new LocalDateTime(2017, 10, 15, 21, 30, 0, 0, CalendarSystem.Iso),
      new LocalDateTime(2017, 10, 15, 21, 30, 0, 0, CalendarSystem.Iso),
      new LocalDateTime(2018, 10, 15, 21, 30, 0, 0, CalendarSystem.Iso),
      new LocalDateTime(2017, 11, 15, 21, 30, 0, 0, CalendarSystem.Iso),
      new LocalDateTime(2017, 10, 16, 21, 30, 0, 0, CalendarSystem.Iso),
      new LocalDateTime(2017, 10, 15, 22, 30, 0, 0, CalendarSystem.Iso),
      new LocalDateTime(2017, 10, 15, 21, 31, 0, 0, CalendarSystem.Iso),
      new LocalDateTime(2017, 10, 15, 21, 30, 1, 0, CalendarSystem.Iso),
      new LocalDateTime(2017, 10, 15, 21, 30, 0, 1, CalendarSystem.Iso),
      new LocalDateTime(2017, 10, 15, 21, 30, 0, 0, CalendarSystem.Gregorian),
    );
  },

  MaxIsoValue() {
    const value = LocalDateTime.MaxIsoValue;
    assertNodaEqual(value.Calendar, CalendarSystem.Iso);
    assertThrows(OverflowError, () => value.PlusNanoseconds(1));
  },

  MinIsoValue() {
    const value = LocalDateTime.MinIsoValue;
    assertNodaEqual(value.Calendar, CalendarSystem.Iso);
    assertThrows(OverflowError, () => value.PlusNanoseconds(-1));
  },
};

// #endregion

// #region LocalDateTimeTest.Pseudomutators.cs

/** C#'s `$"{expected:uuuu-MM-dd HH:mm:ss.fffffffff} != {actual:uuuu-MM-dd HH:mm:ss.fffffffff}"` message. */
function mismatchMessage(expected: LocalDateTime, actual: LocalDateTime): string {
  const pattern = "uuuu-MM-dd HH:mm:ss.fffffffff";
  return `${expected.toString(pattern)} != ${actual.toString(pattern)}`;
}

const pseudomutatorBodies = {
  PlusYear_Simple() {
    const start = new LocalDateTime(2011, 6, 26, 12, 15, 8);
    let expected = new LocalDateTime(2016, 6, 26, 12, 15, 8);
    assertNodaEqual(start.PlusYears(5), expected);

    expected = new LocalDateTime(2006, 6, 26, 12, 15, 8);
    assertNodaEqual(start.PlusYears(-5), expected);
  },

  PlusYear_LeapToNonLeap() {
    const start = new LocalDateTime(2012, 2, 29, 12, 15, 8);
    let expected = new LocalDateTime(2013, 2, 28, 12, 15, 8);
    assertNodaEqual(start.PlusYears(1), expected);

    expected = new LocalDateTime(2011, 2, 28, 12, 15, 8);
    assertNodaEqual(start.PlusYears(-1), expected);
  },

  PlusYear_LeapToLeap() {
    const start = new LocalDateTime(2012, 2, 29, 12, 15, 8);
    const expected = new LocalDateTime(2016, 2, 29, 12, 15, 8);
    assertNodaEqual(start.PlusYears(4), expected);
  },

  PlusMonth_Simple() {
    const start = new LocalDateTime(2012, 4, 15, 12, 15, 8);
    const expected = new LocalDateTime(2012, 8, 15, 12, 15, 8);
    assertNodaEqual(start.PlusMonths(4), expected);
  },

  PlusMonth_ChangingYear() {
    const start = new LocalDateTime(2012, 10, 15, 12, 15, 8);
    const expected = new LocalDateTime(2013, 2, 15, 12, 15, 8);
    assertNodaEqual(start.PlusMonths(4), expected);
  },

  PlusMonth_WithTruncation() {
    const start = new LocalDateTime(2011, 1, 30, 12, 15, 8);
    const expected = new LocalDateTime(2011, 2, 28, 12, 15, 8);
    assertNodaEqual(start.PlusMonths(1), expected);
  },

  PlusDays_Simple() {
    const start = new LocalDateTime(2011, 1, 15, 12, 15, 8);
    let expected = new LocalDateTime(2011, 1, 23, 12, 15, 8);
    assertNodaEqual(start.PlusDays(8), expected);

    expected = new LocalDateTime(2011, 1, 7, 12, 15, 8);
    assertNodaEqual(start.PlusDays(-8), expected);
  },

  PlusDays_MonthBoundary() {
    const start = new LocalDateTime(2011, 1, 26, 12, 15, 8);
    const expected = new LocalDateTime(2011, 2, 3, 12, 15, 8);
    assertNodaEqual(start.PlusDays(8), expected);

    // Round-trip back across the boundary
    assertNodaEqual(start.PlusDays(8).PlusDays(-8), start);
  },

  PlusDays_YearBoundary() {
    const start = new LocalDateTime(2011, 12, 26, 12, 15, 8);
    const expected = new LocalDateTime(2012, 1, 3, 12, 15, 8);
    assertNodaEqual(start.PlusDays(8), expected);

    // Round-trip back across the boundary
    assertNodaEqual(start.PlusDays(8).PlusDays(-8), start);
  },

  PlusDays_EndOfFebruary_InLeapYear() {
    const start = new LocalDateTime(2012, 2, 26, 12, 15, 8);
    const expected = new LocalDateTime(2012, 3, 5, 12, 15, 8);
    assertNodaEqual(start.PlusDays(8), expected);
    // Round-trip back across the boundary
    assertNodaEqual(start.PlusDays(8).PlusDays(-8), start);
  },

  PlusDays_EndOfFebruary_NotInLeapYear() {
    const start = new LocalDateTime(2011, 2, 26, 12, 15, 8);
    const expected = new LocalDateTime(2011, 3, 6, 12, 15, 8);
    assertNodaEqual(start.PlusDays(8), expected);

    // Round-trip back across the boundary
    assertNodaEqual(start.PlusDays(8).PlusDays(-8), start);
  },

  PlusWeeks_Simple() {
    const start = new LocalDateTime(2011, 4, 2, 12, 15, 8);
    const expectedForward = new LocalDateTime(2011, 4, 23, 12, 15, 8);
    const expectedBackward = new LocalDateTime(2011, 3, 12, 12, 15, 8);
    assertNodaEqual(start.PlusWeeks(3), expectedForward);
    assertNodaEqual(start.PlusWeeks(-3), expectedBackward);
  },

  PlusHours_Simple() {
    const start = new LocalDateTime(2011, 4, 2, 12, 15, 8);
    const expectedForward = new LocalDateTime(2011, 4, 2, 14, 15, 8);
    const expectedBackward = new LocalDateTime(2011, 4, 2, 10, 15, 8);
    assertNodaEqual(start.PlusHours(2), expectedForward);
    assertNodaEqual(start.PlusHours(-2), expectedBackward);
  },

  PlusHours_CrossingDayBoundary() {
    const start = new LocalDateTime(2011, 4, 2, 12, 15, 8);
    const expected = new LocalDateTime(2011, 4, 3, 8, 15, 8);
    assertNodaEqual(start.PlusHours(20), expected);
    assertNodaEqual(start.PlusHours(20).PlusHours(-20), start);
  },

  PlusHours_CrossingYearBoundary() {
    // Christmas day + 10 days and 1 hour
    const start = new LocalDateTime(2011, 12, 25, 12, 15, 8);
    const expected = new LocalDateTime(2012, 1, 4, 13, 15, 8);
    assertNodaEqual(start.PlusHours(241), expected);
    assertNodaEqual(start.PlusHours(241).PlusHours(-241), start);
  },

  // Having tested that hours cross boundaries correctly, the other time unit
  // tests are straightforward
  PlusMinutes_Simple() {
    const start = new LocalDateTime(2011, 4, 2, 12, 15, 8);
    const expectedForward = new LocalDateTime(2011, 4, 2, 12, 17, 8);
    const expectedBackward = new LocalDateTime(2011, 4, 2, 12, 13, 8);
    assertNodaEqual(start.PlusMinutes(2), expectedForward);
    assertNodaEqual(start.PlusMinutes(-2), expectedBackward);
  },

  PlusSeconds_Simple() {
    const start = new LocalDateTime(2011, 4, 2, 12, 15, 8);
    const expectedForward = new LocalDateTime(2011, 4, 2, 12, 15, 18);
    const expectedBackward = new LocalDateTime(2011, 4, 2, 12, 14, 58);
    assertNodaEqual(start.PlusSeconds(10), expectedForward);
    assertNodaEqual(start.PlusSeconds(-10), expectedBackward);
  },

  PlusMilliseconds_Simple() {
    const start = new LocalDateTime(2011, 4, 2, 12, 15, 8, 300);
    const expectedForward = new LocalDateTime(2011, 4, 2, 12, 15, 8, 700);
    const expectedBackward = new LocalDateTime(2011, 4, 2, 12, 15, 7, 900);
    assertNodaEqual(start.PlusMilliseconds(400), expectedForward);
    assertNodaEqual(start.PlusMilliseconds(-400), expectedBackward);
  },

  PlusTicks_Simple() {
    const date = new LocalDate(2011, 4, 2);
    const startTime = LocalTime.FromHourMinuteSecondMillisecondTick(12, 15, 8, 300, 7500);
    const expectedForwardTime = LocalTime.FromHourMinuteSecondMillisecondTick(12, 15, 8, 301, 1500);
    const expectedBackwardTime = LocalTime.FromHourMinuteSecondMillisecondTick(12, 15, 8, 300, 3500);
    assertNodaEqual(LocalDate.Add(date, startTime).PlusTicks(4000), LocalDate.Add(date, expectedForwardTime));
    assertNodaEqual(LocalDate.Add(date, startTime).PlusTicks(-4000), LocalDate.Add(date, expectedBackwardTime));
  },

  PlusTicks_Long() {
    expect(NodaConstants.TicksPerDay > 2147483647).toBe(true);
    const start = new LocalDateTime(2011, 4, 2, 12, 15, 8);
    const expectedForward = new LocalDateTime(2011, 4, 3, 12, 15, 8);
    const expectedBackward = new LocalDateTime(2011, 4, 1, 12, 15, 8);
    assertNodaEqual(start.PlusTicks(NodaConstants.TicksPerDay), expectedForward);
    assertNodaEqual(start.PlusTicks(-NodaConstants.TicksPerDay), expectedBackward);
  },

  PlusNanoseconds_Simple() {
    // Just use the ticks values
    const date = new LocalDate(2011, 4, 2);
    const startTime = LocalTime.FromHourMinuteSecondMillisecondTick(12, 15, 8, 300, 7500);
    const expectedForwardTime = LocalTime.FromHourMinuteSecondMillisecondTick(12, 15, 8, 300, 7540);
    const expectedBackwardTime = LocalTime.FromHourMinuteSecondMillisecondTick(12, 15, 8, 300, 7460);
    assertNodaEqual(LocalDate.Add(date, startTime).PlusNanoseconds(4000), LocalDate.Add(date, expectedForwardTime));
    assertNodaEqual(LocalDate.Add(date, startTime).PlusNanoseconds(-4000), LocalDate.Add(date, expectedBackwardTime));
  },

  PlusTicks_CrossingDay() {
    const start = new LocalDateTime(2011, 4, 2, 12, 15, 8);
    const expectedForward = new LocalDateTime(2011, 4, 3, 12, 15, 8);
    const expectedBackward = new LocalDateTime(2011, 4, 1, 12, 15, 8);
    assertNodaEqual(start.PlusNanoseconds(NodaConstants.NanosecondsPerDay), expectedForward);
    assertNodaEqual(start.PlusNanoseconds(-NodaConstants.NanosecondsPerDay), expectedBackward);
  },

  Plus_FullPeriod() {
    // Period deliberately chosen to require date rollover
    const start = new LocalDateTime(2011, 4, 2, 12, 15, 8);
    const builder = new PeriodBuilder();
    builder.Years = 1; builder.Months = 2; builder.Weeks = 3; builder.Days = 4; builder.Hours = 15; builder.Minutes = 6;
    builder.Seconds = 7; builder.Milliseconds = 8; builder.Ticks = 9; builder.Nanoseconds = 11;
    const period = builder.Build();
    const actual = start.Plus(period);
    const expected = new LocalDateTime(2012, 6, 28, 3, 21, 15).PlusNanoseconds(8000911);
    assertNodaEqual(actual, expected, mismatchMessage(expected, actual));
  },

  Minus_FullPeriod() {
    // Period deliberately chosen to require date rollover
    const start = new LocalDateTime(2011, 4, 2, 12, 15, 8);
    const builder = new PeriodBuilder();
    builder.Years = 1; builder.Months = 2; builder.Weeks = 3; builder.Days = 4; builder.Hours = 15; builder.Minutes = 6;
    builder.Seconds = 7; builder.Milliseconds = 8; builder.Ticks = 9; builder.Nanoseconds = 11;
    const period = builder.Build();
    const actual = start.Minus(period);
    const expected = new LocalDateTime(2010, 1, 7, 21, 9, 0).PlusNanoseconds(991999089);
    assertNodaEqual(actual, expected, mismatchMessage(expected, actual));
  },

  // Each test case gives a day-of-month in November 2011 and a target "next day of week";
  // the result is the next day-of-month in November 2011 with that target day.
  // The tests are picked somewhat arbitrarily...
  Next(dayOfMonth: number, targetDayOfWeek: IsoDayOfWeek) {
    const start = new LocalDateTime(2011, 11, dayOfMonth, 15, 25, 30).PlusNanoseconds(123456789);
    const target = start.Next(targetDayOfWeek);
    expect(target.Year).toBe(2011);
    expect(target.Month).toBe(11);
    assertNodaEqual(target.TimeOfDay, start.TimeOfDay);
    return target.Day;
  },

  Next_InvalidArgument(targetDayOfWeek: IsoDayOfWeek) {
    const start = new LocalDateTime(2011, 1, 1, 15, 25, 30).PlusNanoseconds(123456789);
    assertThrows(ArgumentOutOfRangeError, () => start.Next(targetDayOfWeek));
  },

  // Each test case gives a day-of-month in November 2011 and a target "next day of week";
  // the result is the next day-of-month in November 2011 with that target day.
  Previous(dayOfMonth: number, targetDayOfWeek: IsoDayOfWeek) {
    const start = new LocalDateTime(2011, 11, dayOfMonth, 15, 25, 30).PlusNanoseconds(123456789);
    const target = start.Previous(targetDayOfWeek);
    expect(target.Year).toBe(2011);
    expect(target.Month).toBe(11);
    return target.Day;
  },

  Previous_InvalidArgument(targetDayOfWeek: IsoDayOfWeek) {
    const start = new LocalDateTime(2011, 1, 1, 15, 25, 30).PlusNanoseconds(123456789);
    assertThrows(ArgumentOutOfRangeError, () => start.Previous(targetDayOfWeek));
  },

  // No tests for non-ISO-day-of-week calendars as we don't have any yet.

  Operator_MethodEquivalents() {
    const start = new LocalDateTime(2011, 1, 1, 15, 25, 30).PlusNanoseconds(123456789);
    const period = Period.Add(Period.FromHours(1), Period.FromDays(1));
    const end = LocalDateTime.Add(start, period);
    assertNodaEqual(LocalDateTime.Add(start, period), LocalDateTime.Add(start, period));
    assertNodaEqual(start.Plus(period), LocalDateTime.Add(start, period));
    assertNodaEqual(LocalDateTime.Subtract(start, period), LocalDateTime.Subtract(start, period));
    assertNodaEqual(start.Minus(period), LocalDateTime.Subtract(start, period));
    assertNodaEqual(LocalDateTime.Subtract(end, start), period);
    assertNodaEqual(LocalDateTime.Subtract(end, start), period);
    assertNodaEqual(end.Minus(start), period);
  },

  With_TimeAdjuster() {
    const start = new LocalDateTime(2014, 6, 27, 12, 15, 8).PlusNanoseconds(123456789);
    const expected = new LocalDateTime(2014, 6, 27, 12, 15, 8);
    assertNodaEqual(start.WithTimeAdjuster(TimeAdjusters.TruncateToSecond), expected);
  },

  With_DateAdjuster() {
    const start = new LocalDateTime(2014, 6, 27, 12, 5, 8).PlusNanoseconds(123456789);
    const expected = new LocalDateTime(2014, 6, 30, 12, 5, 8).PlusNanoseconds(123456789);
    assertNodaEqual(start.With(DateAdjusters.EndOfMonth), expected);
  },

  PlusHours_Overflow(year: number, month: number, day: number, hours: number | string) {
    const value = new LocalDateTime(year, month, day, 0, 0);
    TestHelper.assertOverflow(() => value.PlusHours(hours));
  },
};

// #endregion

const BclNotPorted = "BCL interop (DateTime) isn't ported";
const XmlNotPorted = "XML serialization isn't ported";

port(fixture, {
  ...mainBodies,
  ...pseudomutatorBodies,
}, {
  skip: {
    ToDateTimeUnspecified: BclNotPorted,
    ToDateTimeUnspecified_JulianCalendar: BclNotPorted,
    ToDateTimeUnspecified_TruncatesTowardsStartOfTime: BclNotPorted,
    ToDateTimeUnspecified_OutOfRange: BclNotPorted,
    FromDateTime: BclNotPorted,
    FromDateTime_WithCalendar: BclNotPorted,
    DateTime_Roundtrip_OtherCalendarInBcl: BclNotPorted,
    CompareTo_DifferentCalendars_Throws: "non-ISO calendars (Islamic) aren't ported",
    DefaultConstructor: "C# default(LocalDateTime) struct construction; LocalDateTime has no parameterless constructor in noda-js",
    XmlSerialization_Iso: XmlNotPorted,
    XmlSerialization_NonIso: XmlNotPorted,
    XmlSerialization_Invalid: XmlNotPorted,
  },
});
