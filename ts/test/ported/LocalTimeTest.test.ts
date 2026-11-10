// Ported from NodaTime 6e024dde: src/NodaTime.Test/LocalTimeTest.cs (+ .Construction.cs, .Conversion.cs, .Operators.cs,
// .Pseudomutators.cs)
// Copyright 2010 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { expect } from "vitest";
import {
  CalendarSystem,
  LocalDate,
  LocalDateTime,
  LocalTime,
  NodaConstants,
  Offset,
  OffsetTime,
  Period,
  TimeAdjusters,
} from "../../src/noda-js/internal.ts";
import { assertNodaEqual, assertThrows } from "../helpers/assertions.ts";
import { port } from "../helpers/scenarios.ts";
import { TestHelper } from "../helpers/TestHelper.ts";
import { fixture } from "../scenarios/LocalTimeTest.generated.ts";
import type { ArgumentException } from "../../src/noda-js/internal.ts";

// #region LocalTimeTest.cs

const mainBodies = {
  MinValueEqualToMidnight() {
    assertNodaEqual(LocalTime.MinValue, LocalTime.Midnight);
  },

  MaxValue() {
    assertNodaEqual(LocalTime.MaxValue.NanosecondOfDay, NodaConstants.NanosecondsPerDay - 1);
  },

  ClockHourOfHalfDay() {
    expect(new LocalTime(0, 0).ClockHourOfHalfDay).toBe(12);
    expect(new LocalTime(1, 0).ClockHourOfHalfDay).toBe(1);
    expect(new LocalTime(12, 0).ClockHourOfHalfDay).toBe(12);
    expect(new LocalTime(13, 0).ClockHourOfHalfDay).toBe(1);
    expect(new LocalTime(23, 0).ClockHourOfHalfDay).toBe(11);
  },

  Max() {
    const x = new LocalTime(5, 10);
    const y = new LocalTime(6, 20);
    assertNodaEqual(LocalTime.Max(x, y), y);
    assertNodaEqual(LocalTime.Max(y, x), y);
    assertNodaEqual(LocalTime.Max(x, LocalTime.MinValue), x);
    assertNodaEqual(LocalTime.Max(LocalTime.MinValue, x), x);
    assertNodaEqual(LocalTime.Max(LocalTime.MaxValue, x), LocalTime.MaxValue);
    assertNodaEqual(LocalTime.Max(x, LocalTime.MaxValue), LocalTime.MaxValue);
  },

  Min() {
    const x = new LocalTime(5, 10);
    const y = new LocalTime(6, 20);
    assertNodaEqual(LocalTime.Min(x, y), x);
    assertNodaEqual(LocalTime.Min(y, x), x);
    assertNodaEqual(LocalTime.Min(x, LocalTime.MinValue), LocalTime.MinValue);
    assertNodaEqual(LocalTime.Min(LocalTime.MinValue, x), LocalTime.MinValue);
    assertNodaEqual(LocalTime.Min(LocalTime.MaxValue, x), x);
    assertNodaEqual(LocalTime.Min(x, LocalTime.MaxValue), x);
  },

  Deconstruction() {
    const value = new LocalTime(15, 8, 20);
    const expectedHour = 15;
    const expectedMinute = 8;
    const expectedSecond = 20;

    const { Hour: actualHour, Minute: actualMinute, Second: actualSecond } = value;

    expect(actualHour).toBe(expectedHour);
    expect(actualMinute).toBe(expectedMinute);
    expect(actualSecond).toBe(expectedSecond);
  },

  WithOffset() {
    const time = new LocalTime(3, 45, 12, 34);
    const offset = Offset.FromHours(5);
    const expected = new OffsetTime(time, offset);
    assertNodaEqual(time.WithOffset(offset), expected);
  },

  TestToString() {
    const value = new LocalTime(3, 45, 12, 34).WithOffset(Offset.FromHours(5));
    assertNodaEqual(value.toString(), value.toString(null, null));
  },
};

// #endregion

// #region LocalTimeTest.Construction.cs

const constructionBodies = {
  InvalidConstructionToMinute(hour: number, minute: number) {
    assertThrows("ArgumentOutOfRangeException", () => new LocalTime(hour, minute));
  },

  InvalidConstructionToSecond(hour: number, minute: number, second: number) {
    assertThrows("ArgumentOutOfRangeException", () => new LocalTime(hour, minute, second));
  },

  InvalidConstructionToMillisecond(hour: number, minute: number, second: number, millisecond: number) {
    assertThrows("ArgumentOutOfRangeException", () => new LocalTime(hour, minute, second, millisecond));
  },

  FromHourMinuteSecondMillisecondTick_Invalid(hour: number, minute: number, second: number, millisecond: number, tick: number) {
    assertThrows("ArgumentOutOfRangeException",
      () => LocalTime.FromHourMinuteSecondMillisecondTick(hour, minute, second, millisecond, tick));
  },

  FromHourMinuteSecondTick_Invalid(hour: number, minute: number, second: number, tick: number) {
    assertThrows("ArgumentOutOfRangeException",
      () => LocalTime.FromHourMinuteSecondTick(hour, minute, second, tick));
  },

  FromHourMinuteSecondTick_Valid() {
    const result = LocalTime.FromHourMinuteSecondTick(1, 2, 3, NodaConstants.TicksPerSecond - 1);
    expect(result.Hour).toBe(1);
    expect(result.Minute).toBe(2);
    expect(result.Second).toBe(3);
    expect(result.TickOfSecond).toBe(NodaConstants.TicksPerSecond - 1);
  },

  FromHourMinuteSecondNanosecond_Invalid(hour: number, minute: number, second: number, nanosecond: number) {
    assertThrows("ArgumentOutOfRangeException",
      () => LocalTime.FromHourMinuteSecondNanosecond(hour, minute, second, nanosecond));
  },

  FromNanosecondsSinceMidnight_Valid() {
    assertNodaEqual(LocalTime.FromNanosecondsSinceMidnight(0), LocalTime.Midnight);
    assertNodaEqual(LocalTime.FromNanosecondsSinceMidnight(NodaConstants.NanosecondsPerDay - 1), LocalTime.Midnight.PlusNanoseconds(-1));
  },

  FromNanosecondsSinceMidnight_RangeChecks() {
    assertThrows("ArgumentOutOfRangeException", () => LocalTime.FromNanosecondsSinceMidnight(-1));
    assertThrows("ArgumentOutOfRangeException", () => LocalTime.FromNanosecondsSinceMidnight(NodaConstants.NanosecondsPerDay));
  },

  FromTicksSinceMidnight_Valid() {
    assertNodaEqual(LocalTime.FromTicksSinceMidnight(0), LocalTime.Midnight);
    assertNodaEqual(LocalTime.FromTicksSinceMidnight(NodaConstants.TicksPerDay - 1), LocalTime.Subtract(LocalTime.Midnight, Period.FromTicks(1)));
  },

  FromTicksSinceMidnight_RangeChecks() {
    assertThrows("ArgumentOutOfRangeException", () => LocalTime.FromTicksSinceMidnight(-1));
    assertThrows("ArgumentOutOfRangeException", () => LocalTime.FromTicksSinceMidnight(NodaConstants.TicksPerDay));
  },

  FromMillisecondsSinceMidnight_Valid() {
    assertNodaEqual(LocalTime.FromMillisecondsSinceMidnight(0), LocalTime.Midnight);
    assertNodaEqual(LocalTime.FromMillisecondsSinceMidnight(NodaConstants.MillisecondsPerDay - 1), LocalTime.Subtract(LocalTime.Midnight, Period.FromMilliseconds(1)));
  },

  FromMillisecondsSinceMidnight_RangeChecks() {
    assertThrows("ArgumentOutOfRangeException", () => LocalTime.FromMillisecondsSinceMidnight(-1));
    assertThrows("ArgumentOutOfRangeException", () => LocalTime.FromMillisecondsSinceMidnight(NodaConstants.MillisecondsPerDay));
  },

  FromSecondsSinceMidnight_Valid() {
    assertNodaEqual(LocalTime.FromSecondsSinceMidnight(0), LocalTime.Midnight);
    assertNodaEqual(LocalTime.FromSecondsSinceMidnight(NodaConstants.SecondsPerDay - 1), LocalTime.Subtract(LocalTime.Midnight, Period.FromSeconds(1)));
  },

  FromSecondsSinceMidnight_RangeChecks() {
    assertThrows("ArgumentOutOfRangeException", () => LocalTime.FromSecondsSinceMidnight(-1));
    assertThrows("ArgumentOutOfRangeException", () => LocalTime.FromSecondsSinceMidnight(NodaConstants.SecondsPerDay));
  },

  FromMinutesSinceMidnight_Valid() {
    assertNodaEqual(LocalTime.FromMinutesSinceMidnight(0), LocalTime.Midnight);
    assertNodaEqual(LocalTime.FromMinutesSinceMidnight(NodaConstants.MinutesPerDay - 1), LocalTime.Subtract(LocalTime.Midnight, Period.FromMinutes(1)));
  },

  FromMinutesSinceMidnight_RangeChecks() {
    assertThrows("ArgumentOutOfRangeException", () => LocalTime.FromMinutesSinceMidnight(-1));
    assertThrows("ArgumentOutOfRangeException", () => LocalTime.FromMinutesSinceMidnight(NodaConstants.MinutesPerDay));
  },

  FromHoursSinceMidnight_Valid() {
    assertNodaEqual(LocalTime.FromHoursSinceMidnight(0), LocalTime.Midnight);
    assertNodaEqual(LocalTime.FromHoursSinceMidnight(NodaConstants.HoursPerDay - 1), LocalTime.Subtract(LocalTime.Midnight, Period.FromHours(1)));
  },

  FromHoursSinceMidnight_RangeChecks() {
    assertThrows("ArgumentOutOfRangeException", () => LocalTime.FromHoursSinceMidnight(-1));
    assertThrows("ArgumentOutOfRangeException", () => LocalTime.FromHoursSinceMidnight(NodaConstants.HoursPerDay));
  },
};

// #endregion

// #region LocalTimeTest.Operators.cs

const operatorBodies = {
  Addition_WithPeriod() {
    const start = new LocalTime(3, 30);
    const period = Period.Add(Period.FromHours(2), Period.FromSeconds(1));
    const expected = new LocalTime(5, 30, 1);
    assertNodaEqual(LocalTime.Add(start, period), expected);
  },

  Addition_WrapsAtMidnight() {
    const start = new LocalTime(22, 0);
    const period = Period.FromHours(3);
    const expected = new LocalTime(1, 0);
    assertNodaEqual(LocalTime.Add(start, period), expected);
  },

  Addition_WithNullPeriod_ThrowsArgumentNullException() {
    const date = new LocalTime(12, 0);
    // Call to ToString just to make it a valid statement
    assertThrows("ArgumentNullException", () => LocalTime.Add(date, null!).toString());
  },

  Subtraction_WithPeriod() {
    const start = new LocalTime(5, 30, 1);
    const period = Period.Add(Period.FromHours(2), Period.FromSeconds(1));
    const expected = new LocalTime(3, 30, 0);
    assertNodaEqual(LocalTime.Subtract(start, period), expected);
  },

  Subtraction_WrapsAtMidnight() {
    const start = new LocalTime(1, 0, 0);
    const period = Period.FromHours(3);
    const expected = new LocalTime(22, 0, 0);
    assertNodaEqual(LocalTime.Subtract(start, period), expected);
  },

  Subtraction_WithNullPeriod_ThrowsArgumentNullException() {
    const date = new LocalTime(12, 0);
    // Call to ToString just to make it a valid statement
    assertThrows("ArgumentNullException", () => LocalTime.Subtract(date, null as unknown as Period).toString());
  },

  Addition_PeriodWithDate() {
    const time = new LocalTime(20, 30);
    const period = Period.FromDays(1);
    // Use method not operator here to form a valid statement
    assertThrows("ArgumentException", () => LocalTime.Add(time, period));
  },

  Subtraction_PeriodWithTime() {
    const time = new LocalTime(20, 30);
    const period = Period.FromDays(1);
    // Use method not operator here to form a valid statement
    assertThrows("ArgumentException", () => LocalTime.Subtract(time, period));
  },

  PeriodAddition_MethodEquivalents() {
    const start = new LocalTime(20, 30);
    const period = Period.Add(Period.FromHours(3), Period.FromMinutes(10));
    assertNodaEqual(LocalTime.Add(start, period), LocalTime.Add(start, period));
    assertNodaEqual(start.Plus(period), LocalTime.Add(start, period));
  },

  PeriodSubtraction_MethodEquivalents() {
    const start = new LocalTime(20, 30);
    const period = Period.Add(Period.FromHours(3), Period.FromMinutes(10));
    const end = LocalTime.Add(start, period);
    assertNodaEqual(LocalTime.Subtract(start, period), LocalTime.Subtract(start, period));
    assertNodaEqual(start.Minus(period), LocalTime.Subtract(start, period));

    assertNodaEqual(LocalTime.Subtract(end, start), period);
    assertNodaEqual(LocalTime.Subtract(end, start), period);
    assertNodaEqual(end.Minus(start), period);
  },

  EqualityAndComparison() {
    const time1 = new LocalTime(10, 30, 45);
    const time2 = new LocalTime(10, 30, 45);
    const time3 = new LocalTime(10, 30, 50);

    TestHelper.testNonGenericCompareTo(time1, time2, time3);
    TestHelper.testCompareToStruct(time1, time2, time3);
    TestHelper.testOperatorComparisonEquality(time1, time2, time3);
    TestHelper.testEqualsStruct(time1, time2, time3);
  },

  Comparison_IgnoresOriginalCalendar() {
    const dateTime1 = new LocalDateTime(1900, 1, 1, 10, 30, 0);
    const dateTime2 = dateTime1.WithCalendar(CalendarSystem.Julian);

    // Calendar information is propagated into LocalDate, but not into LocalTime
    expect(dateTime1.Date.Equals(dateTime2.Date)).toBe(false);
    expect(dateTime1.TimeOfDay.Equals(dateTime2.TimeOfDay)).toBe(true);
  },

  CompareTo() {
    const time1 = new LocalTime(10, 30, 45);
    const time2 = new LocalTime(10, 30, 45);
    const time3 = new LocalTime(10, 30, 50);

    expect(time1.CompareTo(time2)).toBe(0);
    expect(time1.CompareTo(time3)).toBeLessThan(0);
    expect(time3.CompareTo(time2)).toBeGreaterThan(0);
  },

  /** IComparable.CompareTo returns a positive number for a null input. */
  IComparableCompareTo_Null_Positive() {
    const instance = new LocalTime(10, 30, 45);
    const comparable = instance as { CompareTo(other: unknown): number };
    const result = comparable.CompareTo(null);
    expect(result).toBeGreaterThan(0);
  },

  /** IComparable.CompareTo throws an ArgumentException for non-null arguments that are not a LocalTime. */
  IComparableCompareTo_WrongType_ArgumentException() {
    const instance = new LocalTime(10, 30, 45);
    const i_instance = instance as { CompareTo(other: unknown): number };
    const arg = new LocalDate(2012, 3, 6);
    assertThrows("ArgumentException", () => {
      i_instance.CompareTo(arg);
    });
  },
};

// #endregion

// #region LocalTimeTest.Pseudomutators.cs

const pseudomutatorBodies = {
  PlusHours_Simple() {
    const start = new LocalTime(12, 15, 8);
    const expectedForward = new LocalTime(14, 15, 8);
    const expectedBackward = new LocalTime(10, 15, 8);
    assertNodaEqual(start.PlusHours(2), expectedForward);
    assertNodaEqual(start.PlusHours(-2), expectedBackward);
  },

  PlusHours_CrossingDayBoundary() {
    const start = new LocalTime(12, 15, 8);
    const expected = new LocalTime(8, 15, 8);
    assertNodaEqual(start.PlusHours(20), expected);
    assertNodaEqual(start.PlusHours(20).PlusHours(-20), start);
  },

  PlusHours_CrossingSeveralDaysBoundary() {
    // Christmas day + 10 days and 1 hour
    const start = new LocalTime(12, 15, 8);
    const expected = new LocalTime(13, 15, 8);
    assertNodaEqual(start.PlusHours(241), expected);
    assertNodaEqual(start.PlusHours(241).PlusHours(-241), start);
  },

  // Having tested that hours cross boundaries correctly, the other time unit
  // tests are straightforward
  PlusMinutes_Simple() {
    const start = new LocalTime(12, 15, 8);
    const expectedForward = new LocalTime(12, 17, 8);
    const expectedBackward = new LocalTime(12, 13, 8);
    assertNodaEqual(start.PlusMinutes(2), expectedForward);
    assertNodaEqual(start.PlusMinutes(-2), expectedBackward);
  },

  PlusSeconds_Simple() {
    const start = new LocalTime(12, 15, 8);
    const expectedForward = new LocalTime(12, 15, 18);
    const expectedBackward = new LocalTime(12, 14, 58);
    assertNodaEqual(start.PlusSeconds(10), expectedForward);
    assertNodaEqual(start.PlusSeconds(-10), expectedBackward);
  },

  PlusMilliseconds_Simple() {
    const start = new LocalTime(12, 15, 8, 300);
    const expectedForward = new LocalTime(12, 15, 8, 700);
    const expectedBackward = new LocalTime(12, 15, 7, 900);
    assertNodaEqual(start.PlusMilliseconds(400), expectedForward);
    assertNodaEqual(start.PlusMilliseconds(-400), expectedBackward);
  },

  PlusTicks_Simple() {
    const start = LocalTime.FromHourMinuteSecondMillisecondTick(12, 15, 8, 300, 7500);
    const expectedForward = LocalTime.FromHourMinuteSecondMillisecondTick(12, 15, 8, 301, 1500);
    const expectedBackward = LocalTime.FromHourMinuteSecondMillisecondTick(12, 15, 8, 300, 3500);
    assertNodaEqual(start.PlusTicks(4000), expectedForward);
    assertNodaEqual(start.PlusTicks(-4000), expectedBackward);
  },

  PlusTicks_Long() {
    expect(NodaConstants.TicksPerDay > 2147483647).toBe(true);
    const start = new LocalTime(12, 15, 8);
    const expectedForward = new LocalTime(12, 15, 9);
    const expectedBackward = new LocalTime(12, 15, 7);
    assertNodaEqual(start.PlusTicks(NodaConstants.TicksPerDay + NodaConstants.TicksPerSecond), expectedForward);
    assertNodaEqual(start.PlusTicks(-NodaConstants.TicksPerDay - NodaConstants.TicksPerSecond), expectedBackward);
  },

  With() {
    const start = LocalTime.FromHourMinuteSecondMillisecondTick(12, 15, 8, 100, 1234);
    const expected = new LocalTime(12, 15, 8);
    assertNodaEqual(start.With(TimeAdjusters.TruncateToSecond), expected);
  },

  PlusMinutes_WouldOverflowNaively() {
    const start = new LocalTime(12, 34, 56);
    // Very big value, which just wraps round a *lot* and adds one minute.
    // There's no way we could compute that many nanoseconds.
    // noda-js: (NanosecondsPerDay << 15) + 1 is beyond 2^53, so it's passed as a decimal string.
    const value = "2831155200000000001";
    const expected = new LocalTime(12, 35, 56);
    const actual = start.PlusMinutes(value);
    assertNodaEqual(actual, expected);
  },
};

// #endregion

const BclNotPorted = "BCL interop (TimeOnly) isn't ported";

port(fixture, {
  ...mainBodies,
  ...constructionBodies,
  ...operatorBodies,
  ...pseudomutatorBodies,
}, {
  skip: {
    DefaultConstructor: "C# default(LocalTime) struct construction; LocalTime has no parameterless constructor in noda-js",
    XmlSerialization: "XML serialization isn't ported",
    XmlSerialization_Invalid: "XML serialization isn't ported",
    ToTimeOnly_OnTickBoundary: BclNotPorted,
    ToTimeOnly_RoundsDown: BclNotPorted,
    FromTimeOnly: BclNotPorted,
  },
});
