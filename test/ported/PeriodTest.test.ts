// Ported from NodaTime 3.3.0: src/NodaTime.Test/PeriodTest.cs
// Copyright 2010 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { expect } from "vitest";
import {
  ArgumentError, CalendarSystem, Duration, Int64, InvalidOperationError, LocalDate, LocalDatePattern, LocalDateTime, LocalDateTimePattern,
  LocalTime, LocalTimePattern, NodaConstants, OverflowError, Period, PeriodBuilder, PeriodPattern, PeriodUnits, YearMonth,
  YearMonthPattern,
} from "../../src/noda-js/internal.ts";
import { assertNodaEqual, assertThrows } from "../helpers/assertions.ts";
import { port } from "../helpers/scenarios.ts";
import { fixture } from "../scenarios/PeriodTest.generated.ts";

// June 19th 2010, 2:30:15am
const TestDateTime1 = new LocalDateTime(2010, 6, 19, 2, 30, 15);
// June 19th 2010, 4:45:10am
const TestDateTime2 = new LocalDateTime(2010, 6, 19, 4, 45, 10);
// June 19th 2010
const TestDate1 = new LocalDate(2010, 6, 19);
// March 1st 2011
const TestDate2 = new LocalDate(2011, 3, 1);
// March 1st 2012
const TestDate3 = new LocalDate(2012, 3, 1);

const HoursMinutesPeriodType = PeriodUnits.Hours | PeriodUnits.Minutes;

/** The settable properties of PeriodBuilder, for C# object initializers (`new PeriodBuilder { Hours = 5 }`). */
interface PeriodBuilderInit {
  Years?: number;
  Months?: number;
  Weeks?: number;
  Days?: number;
  Hours?: number | string;
  Minutes?: number | string;
  Seconds?: number | string;
  Milliseconds?: number | string;
  Ticks?: number | string;
  Nanoseconds?: number | string;
}

/** `new PeriodBuilder { ... }`: Object.assign invokes the builder's property setters. */
function newPeriodBuilder(init: PeriodBuilderInit = {}): PeriodBuilder {
  return Object.assign(new PeriodBuilder(), init);
}

/** `new PeriodBuilder { [unit] = value, ... }` (the indexer setter). */
function newPeriodBuilderIndexed(...values: [PeriodUnits, number | string][]): PeriodBuilder {
  const builder = new PeriodBuilder();
  for (const [unit, value] of values) {
    builder.Set(unit, value);
  }
  return builder;
}

/** C# `Period ==` operator: handles nulls, then uses Equals. */
function opEquals(left: Period | null, right: Period | null): boolean {
  return left === null || right === null ? left === right : left.Equals(right);
}

/** Just a simple way of parsing a period string. It's a more compact period representation. */
function parse(text: string): Period {
  return PeriodPattern.Roundtrip.Parse(text).Value;
}

const longMaxValue = Int64.ToString(Int64.MaxValue);

port(fixture, {
  BetweenLocalDateTimes_WithoutSpecifyingUnits_OmitsWeeks() {
    const actual = Period.Between(new LocalDateTime(2012, 2, 21, 0, 0), new LocalDateTime(2012, 2, 28, 0, 0));
    const expected = Period.FromDays(7);
    assertNodaEqual(actual, expected);
  },

  BetweenLocalDateTimes_MovingForwardWithAllFields_GivesExactResult() {
    const actual = Period.Between(TestDateTime1, TestDateTime2);
    const expected = Period.Add(Period.Add(Period.FromHours(2), Period.FromMinutes(14)), Period.FromSeconds(55));
    assertNodaEqual(actual, expected);
  },

  BetweenLocalDateTimes_MovingBackwardWithAllFields_GivesExactResult() {
    const actual = Period.Between(TestDateTime2, TestDateTime1);
    const expected = Period.Add(Period.Add(Period.FromHours(-2), Period.FromMinutes(-14)), Period.FromSeconds(-55));
    assertNodaEqual(actual, expected);
  },

  BetweenLocalDateTimes_MovingForwardWithHoursAndMinutes_RoundsTowardsStart() {
    const actual = Period.Between(TestDateTime1, TestDateTime2, HoursMinutesPeriodType);
    const expected = Period.Add(Period.FromHours(2), Period.FromMinutes(14));
    assertNodaEqual(actual, expected);
  },

  BetweenLocalDateTimes_MovingBackwardWithHoursAndMinutes_RoundsTowardsStart() {
    const actual = Period.Between(TestDateTime2, TestDateTime1, HoursMinutesPeriodType);
    const expected = Period.Add(Period.FromHours(-2), Period.FromMinutes(-14));
    assertNodaEqual(actual, expected);
  },

  BetweenLocalDateTimes_AcrossDays() {
    const expected = Period.Add(Period.FromHours(23), Period.FromMinutes(59));
    const actual = Period.Between(TestDateTime1, TestDateTime1.PlusDays(1).PlusMinutes(-1));
    assertNodaEqual(actual, expected);
  },

  BetweenLocalDateTimes_AcrossDays_MinutesAndSeconds() {
    const expected = Period.Add(Period.FromMinutes(24 * 60 - 1), Period.FromSeconds(59));
    const actual = Period.Between(TestDateTime1, TestDateTime1.PlusDays(1).PlusSeconds(-1), PeriodUnits.Minutes | PeriodUnits.Seconds);
    assertNodaEqual(actual, expected);
  },

  BetweenLocalDateTimes_NotInt64Representable() {
    const start = new LocalDateTime(-5000, 1, 1, 0, 1, 2, 123);
    const end = new LocalDateTime(9000, 1, 1, 1, 2, 3, 456);
    expect(end.ToLocalInstant().TimeSinceLocalEpoch.Minus(start.ToLocalInstant().TimeSinceLocalEpoch).IsInt64Representable).toBe(false);

    const expected = newPeriodBuilder({
      // 365.2425 * 14000 = 5113395
      Hours: 5113395 * 24 + 1,
      Minutes: 1,
      Seconds: 1,
      Milliseconds: 333,
    }).Build();
    const actual = Period.Between(start, end, PeriodUnits.AllTimeUnits);
    assertNodaEqual(actual, expected);
  },

  BetweenLocalDates_InvalidUnits() {
    assertThrows(ArgumentError, () => Period.Between(TestDate1, TestDate2, 0 as PeriodUnits));
    assertThrows(ArgumentError, () => Period.Between(TestDate1, TestDate2, -1 as PeriodUnits));
    assertThrows(ArgumentError, () => Period.Between(TestDate1, TestDate2, PeriodUnits.AllTimeUnits));
    assertThrows(ArgumentError, () => Period.Between(TestDate1, TestDate2, PeriodUnits.Years | PeriodUnits.Hours));
  },

  BetweenLocalDates_DifferentCalendarSystems_Throws() {
    const start = new LocalDate(2017, 11, 1, CalendarSystem.Coptic);
    const end = new LocalDate(2017, 11, 5, CalendarSystem.Gregorian);
    assertThrows(ArgumentError, () => Period.Between(start, end));
  },

  BetweenLocalDates_SingleUnit(startText: string, endText: string, units: PeriodUnits, expectedValue: number) {
    const start = LocalDatePattern.Iso.Parse(startText).Value;
    const end = LocalDatePattern.Iso.Parse(endText).Value;
    const actual = Period.Between(start, end, units);
    const expected = newPeriodBuilderIndexed([units, expectedValue]).Build();
    assertNodaEqual(actual, expected);
  },

  DaysBetweenLocalDates_DifferentCalendarsThrows() {
    const start = new LocalDate(2020, 6, 13, CalendarSystem.Iso);
    const end = new LocalDate(2020, 6, 15, CalendarSystem.Julian);
    assertThrows(ArgumentError, () => Period.DaysBetween(start, end));
  },

  DaysBetweenLocalDates_SameDatesReturnsZero() {
    const start = new LocalDate(2020, 6, 13, CalendarSystem.Iso);
    const end = start;
    const expected = 0;
    const actual = Period.DaysBetween(start, end);
    assertNodaEqual(actual, expected);
  },

  DaysBetweenLocalDates(startText: string, endText: string, expected: number) {
    const start = LocalDatePattern.Iso.Parse(startText).Value;
    const end = LocalDatePattern.Iso.Parse(endText).Value;
    const actual = Period.DaysBetween(start, end);
    assertNodaEqual(actual, expected);
  },

  DaysBetweenLocalDates_StartDateGreaterThanEndDate(startText: string, endText: string, expected: number) {
    const start = LocalDatePattern.Iso.Parse(startText).Value;
    const end = LocalDatePattern.Iso.Parse(endText).Value;
    const actual = Period.DaysBetween(start, end);
    assertNodaEqual(actual, expected);
  },

  BetweenLocalDates_MovingForwardNoLeapYears_WithExactResults() {
    const actual = Period.Between(TestDate1, TestDate2);
    const expected = Period.Add(Period.FromMonths(8), Period.FromDays(10));
    assertNodaEqual(actual, expected);
  },

  BetweenLocalDates_MovingForwardInLeapYear_WithExactResults() {
    const actual = Period.Between(TestDate1, TestDate3);
    const expected = Period.Add(Period.Add(Period.FromYears(1), Period.FromMonths(8)), Period.FromDays(11));
    assertNodaEqual(actual, expected);
  },

  BetweenLocalDates_MovingBackwardNoLeapYears_WithExactResults() {
    const actual = Period.Between(TestDate2, TestDate1);
    const expected = Period.Add(Period.FromMonths(-8), Period.FromDays(-12));
    assertNodaEqual(actual, expected);
  },

  BetweenLocalDates_MovingBackwardInLeapYear_WithExactResults() {
    // This is asymmetric with moving forward, because we first take off a whole year, which
    // takes us to March 1st 2011, then 8 months to take us to July 1st 2010, then 12 days
    // to take us back to June 19th. In this case, the fact that our start date is in a leap
    // year had no effect.
    const actual = Period.Between(TestDate3, TestDate1);
    const expected = Period.Add(Period.Add(Period.FromYears(-1), Period.FromMonths(-8)), Period.FromDays(-12));
    assertNodaEqual(actual, expected);
  },

  BetweenLocalDates_MovingForward_WithJustMonths() {
    const actual = Period.Between(TestDate1, TestDate3, PeriodUnits.Months);
    const expected = Period.FromMonths(20);
    assertNodaEqual(actual, expected);
  },

  BetweenLocalDates_MovingBackward_WithJustMonths() {
    const actual = Period.Between(TestDate3, TestDate1, PeriodUnits.Months);
    const expected = Period.FromMonths(-20);
    assertNodaEqual(actual, expected);
  },

  BetweenLocalDates_AsymmetricForwardAndBackward() {
    // February 10th 2010
    const d1 = new LocalDate(2010, 2, 10);
    // March 30th 2010
    const d2 = new LocalDate(2010, 3, 30);
    // Going forward, we go to March 10th (1 month) then March 30th (20 days)
    assertNodaEqual(Period.Between(d1, d2), Period.Add(Period.FromMonths(1), Period.FromDays(20)));
    // Going backward, we go to February 28th (-1 month, day is rounded) then February 10th (-18 days)
    assertNodaEqual(Period.Between(d2, d1), Period.Add(Period.FromMonths(-1), Period.FromDays(-18)));
  },

  BetweenLocalDates_EndOfMonth() {
    const d1 = new LocalDate(2013, 3, 31);
    const d2 = new LocalDate(2013, 4, 30);
    assertNodaEqual(Period.Between(d1, d2), Period.FromMonths(1));
    assertNodaEqual(Period.Between(d2, d1), Period.FromDays(-30));
  },

  BetweenLocalDates_OnLeapYear() {
    const d1 = new LocalDate(2012, 2, 29);
    const d2 = new LocalDate(2013, 2, 28);
    assertNodaEqual(Period.Between(d1, d2), Period.FromYears(1));
    // Go back from February 28th 2013 to March 28th 2012, then back 28 days to February 29th 2012
    assertNodaEqual(Period.Between(d2, d1), Period.Add(Period.FromMonths(-11), Period.FromDays(-28)));
  },

  BetweenLocalDates_AfterLeapYear() {
    const d1 = new LocalDate(2012, 3, 5);
    const d2 = new LocalDate(2013, 3, 5);
    assertNodaEqual(Period.Between(d1, d2), Period.FromYears(1));
    assertNodaEqual(Period.Between(d2, d1), Period.FromYears(-1));
  },

  BetweenLocalDateTimes_OnLeapYear() {
    const dt1 = new LocalDateTime(2012, 2, 29, 2, 0);
    const dt2 = new LocalDateTime(2012, 2, 29, 4, 0);
    const dt3 = new LocalDateTime(2013, 2, 28, 3, 0);
    assertNodaEqual(Period.Between(dt1, dt3), parse("P1YT1H"));
    assertNodaEqual(Period.Between(dt2, dt3), parse("P11M29DT23H"));

    assertNodaEqual(Period.Between(dt3, dt1), parse("P-11M-28DT-1H"));
    assertNodaEqual(Period.Between(dt3, dt2), parse("P-11M-27DT-23H"));
  },

  BetweenLocalDateTimes_InvalidUnits() {
    assertThrows(ArgumentError, () => Period.Between(TestDateTime1, TestDateTime2, 0 as PeriodUnits));
    assertThrows(ArgumentError, () => Period.Between(TestDateTime1, TestDateTime2, -1 as PeriodUnits));
  },

  NanosecondsBetweenLocalTimes(start: LocalTime, end: LocalTime, expected: number) {
    const actual = Period.NanosecondsBetween(start, end);
    assertNodaEqual(actual, expected);
  },

  BetweenLocalTimes_InvalidUnits() {
    const t1 = new LocalTime(10, 0);
    const t2 = LocalTime.FromHourMinuteSecondMillisecondTick(15, 30, 45, 20, 5);
    assertThrows(ArgumentError, () => Period.Between(t1, t2, 0 as PeriodUnits));
    assertThrows(ArgumentError, () => Period.Between(t1, t2, -1 as PeriodUnits));
    assertThrows(ArgumentError, () => Period.Between(t1, t2, PeriodUnits.YearMonthDay));
    assertThrows(ArgumentError, () => Period.Between(t1, t2, PeriodUnits.Years | PeriodUnits.Hours));
  },

  BetweenLocalTimes_SingleUnit(startText: string, endText: string, units: PeriodUnits, expectedValue: number) {
    const start = LocalTimePattern.ExtendedIso.Parse(startText).Value;
    const end = LocalTimePattern.ExtendedIso.Parse(endText).Value;
    const actual = Period.Between(start, end, units);
    const expected = newPeriodBuilderIndexed([units, expectedValue]).Build();
    assertNodaEqual(actual, expected);
  },

  BetweenLocalTimes_MovingForwards() {
    const t1 = new LocalTime(10, 0);
    const t2 = LocalTime.FromHourMinuteSecondMillisecondTick(15, 30, 45, 20, 5);
    assertNodaEqual(Period.Between(t1, t2),
      [Period.FromHours(5), Period.FromMinutes(30), Period.FromSeconds(45), Period.FromMilliseconds(20), Period.FromTicks(5)]
        .reduce(Period.Add));
  },

  BetweenLocalTimes_MovingBackwards() {
    const t1 = LocalTime.FromHourMinuteSecondMillisecondTick(15, 30, 45, 20, 5);
    const t2 = new LocalTime(10, 0);
    assertNodaEqual(Period.Between(t1, t2),
      [Period.FromHours(-5), Period.FromMinutes(-30), Period.FromSeconds(-45), Period.FromMilliseconds(-20), Period.FromTicks(-5)]
        .reduce(Period.Add));
  },

  BetweenLocalTimes_MovingForwards_WithJustHours() {
    const t1 = new LocalTime(11, 30);
    const t2 = new LocalTime(17, 15);
    assertNodaEqual(Period.Between(t1, t2, PeriodUnits.Hours), Period.FromHours(5));
  },

  BetweenLocalTimes_MovingBackwards_WithJustHours() {
    const t1 = new LocalTime(17, 15);
    const t2 = new LocalTime(11, 30);
    assertNodaEqual(Period.Between(t1, t2, PeriodUnits.Hours), Period.FromHours(-5));
  },

  Addition_WithDifferent_PeriodTypes() {
    const p1 = Period.FromHours(3);
    const p2 = Period.FromMinutes(20);
    const sum = Period.Add(p1, p2);
    assertNodaEqual(sum.Hours, 3);
    assertNodaEqual(sum.Minutes, 20);
  },

  Addition_MaxAndMinValue() {
    const p1 = Period.MaxValue;
    const p2 = Period.MinValue;
    const sum = Period.Add(p1, p2);
    // C#: new Period(-1, -1, -1, -1, -1, -1, -1, -1, -1, -1) (an internal constructor)
    assertNodaEqual(sum, Period.NewYearsMonthsWeeksDaysHoursMinutesSecondsMillisecondsTicksNanoseconds(-1, -1, -1, -1, -1, -1, -1, -1, -1, -1));
  },

  Addition_With_IdenticalPeriodTypes() {
    const p1 = Period.FromHours(3);
    const p2 = Period.FromHours(2);
    const sum = Period.Add(p1, p2);
    assertNodaEqual(sum.Hours, 5);
    // C#: Assert.AreEqual(sum, Period.Add(p1, p2)), where sum = p1 + p2 (both are Period.add in noda-js).
    assertNodaEqual(Period.Add(p1, p2), sum);
  },

  Addition_DayCrossingMonthBoundary() {
    const start = new LocalDateTime(2010, 2, 20, 10, 0);
    const result = LocalDateTime.Add(start, Period.FromDays(10));
    assertNodaEqual(result, new LocalDateTime(2010, 3, 2, 10, 0));
  },

  Addition_OneYearOnLeapDay() {
    const start = new LocalDateTime(2012, 2, 29, 10, 0);
    const result = LocalDateTime.Add(start, Period.FromYears(1));
    // Feb 29th becomes Feb 28th
    assertNodaEqual(result, new LocalDateTime(2013, 2, 28, 10, 0));
  },

  Addition_FourYearsOnLeapDay() {
    const start = new LocalDateTime(2012, 2, 29, 10, 0);
    const result = LocalDateTime.Add(start, Period.FromYears(4));
    // Feb 29th is still valid in 2016
    assertNodaEqual(result, new LocalDateTime(2016, 2, 29, 10, 0));
  },

  Addition_YearMonthDay() {
    // One year, one month, two days
    const period = Period.Add(Period.Add(Period.FromYears(1), Period.FromMonths(1)), Period.FromDays(2));
    const start = new LocalDateTime(2007, 1, 30, 0, 0);
    // Periods are added in order, so this becomes...
    // Add one year: Jan 30th 2008
    // Add one month: Feb 29th 2008
    // Add two days: March 2nd 2008
    // If we added the days first, we'd end up with March 1st instead.
    const result = LocalDateTime.Add(start, period);
    assertNodaEqual(result, new LocalDateTime(2008, 3, 2, 0, 0));
  },

  Subtraction_WithDifferent_PeriodTypes() {
    const p1 = Period.FromHours(3);
    const p2 = Period.FromMinutes(20);
    const difference = Period.Subtract(p1, p2);
    assertNodaEqual(difference.Hours, 3);
    assertNodaEqual(difference.Minutes, -20);
    assertNodaEqual(Period.Subtract(p1, p2), difference);
  },

  Subtraction_With_IdenticalPeriodTypes() {
    const p1 = Period.FromHours(3);
    const p2 = Period.FromHours(2);
    const difference = Period.Subtract(p1, p2);
    assertNodaEqual(difference.Hours, 1);
    assertNodaEqual(Period.Subtract(p1, p2), difference);
  },

  UnaryNegation() {
    const period = Period.NewYearsMonthsWeeksDaysHoursMinutesSecondsMillisecondsTicksNanoseconds(2, 3, 4, 5, 6, 7, 8, 9, 10, 11);
    const negation = Period.Negate(period);
    assertNodaEqual(negation, Period.NewYearsMonthsWeeksDaysHoursMinutesSecondsMillisecondsTicksNanoseconds(-2, -3, -4, -5, -6, -7, -8, -9, -10, -11));
  },

  UnaryAddition() {
    const period = Period.NewYearsMonthsWeeksDaysHoursMinutesSecondsMillisecondsTicksNanoseconds(2, 3, 4, 5, 6, 7, 8, 9, 10, 11);
    // C#: +period. Unary + is dropped in noda-js (it returns its operand), so this is the identity.
    const addition = period;
    assertNodaEqual(addition, period);
  },

  Equality_WhenEqual() {
    assertNodaEqual(Period.FromHours(10), Period.FromHours(10));
    assertNodaEqual(Period.FromMinutes(15), Period.FromMinutes(15));
    assertNodaEqual(Period.FromDays(5), Period.FromDays(5));
  },

  Equality_WithDifferentPeriodTypes_OnlyConsidersValues() {
    const allFields = Period.Subtract(Period.Add(Period.FromMinutes(1), Period.FromHours(1)), Period.FromMinutes(1));
    const justHours = Period.FromHours(1);
    assertNodaEqual(justHours, allFields);
  },

  Equality_WhenUnequal() {
    expect(Period.FromHours(10).Equals(Period.FromHours(20))).toBe(false);
    expect(Period.FromMinutes(15).Equals(Period.FromSeconds(15))).toBe(false);
    expect(Period.FromHours(1).Equals(Period.FromMinutes(60))).toBe(false);
    expect(Period.FromHours(1).Equals({})).toBe(false);
    expect(Period.FromHours(1).Equals(null)).toBe(false);
    // C#: Equals((object?) null), the same call in noda-js.
    expect(Period.FromHours(1).Equals(null as unknown)).toBe(false);
  },

  EqualityOperators() {
    const val1 = Period.FromHours(1);
    const val2 = Period.FromHours(1);
    const val3 = Period.FromHours(2);
    const val4: Period | null = null;
    expect(opEquals(val1, val2)).toBe(true);
    expect(opEquals(val1, val3)).toBe(false);
    expect(opEquals(val1, val4)).toBe(false);
    expect(opEquals(val4, val1)).toBe(false);
    expect(opEquals(val4, null)).toBe(true);
    expect(opEquals(null, val4)).toBe(true);

    expect(!opEquals(val1, val2)).toBe(false);
    expect(!opEquals(val1, val3)).toBe(true);
    expect(!opEquals(val1, val4)).toBe(true);
    expect(!opEquals(val4, val1)).toBe(true);
    expect(!opEquals(val4, null)).toBe(false);
    expect(!opEquals(null, val4)).toBe(false);
  },

  HasTimeComponent_SingleValued(unit: PeriodUnits, hasTimeComponent: boolean) {
    const period = newPeriodBuilderIndexed([unit, 1]).Build();
    assertNodaEqual(period.HasTimeComponent, hasTimeComponent);
  },

  HasDateComponent_SingleValued(unit: PeriodUnits, hasDateComponent: boolean) {
    const period = newPeriodBuilderIndexed([unit, 1]).Build();
    assertNodaEqual(period.HasDateComponent, hasDateComponent);
  },

  HasTimeComponent_Compound() {
    const dt1 = new LocalDateTime(2000, 1, 1, 10, 45, 0);
    const dt2 = new LocalDateTime(2000, 2, 4, 11, 50, 0);

    // Case 1: Entire period is date-based (no time units available)
    expect(Period.Between(dt1.Date, dt2.Date).HasTimeComponent).toBe(false);

    // Case 2: Period contains date and time units, but time units are all zero
    expect(Period.Between(LocalDate.Add(dt1.Date, LocalTime.Midnight), LocalDate.Add(dt2.Date, LocalTime.Midnight)).HasTimeComponent).toBe(false);

    // Case 3: Entire period is time-based, but 0. (Same local time twice here.)
    expect(Period.Between(dt1.TimeOfDay, dt1.TimeOfDay).HasTimeComponent).toBe(false);

    // Case 4: Period contains date and time units, and some time units are non-zero
    expect(Period.Between(dt1, dt2).HasTimeComponent).toBe(true);

    // Case 5: Entire period is time-based, and some time units are non-zero
    expect(Period.Between(dt1.TimeOfDay, dt2.TimeOfDay).HasTimeComponent).toBe(true);
  },

  HasDateComponent_Compound() {
    const dt1 = new LocalDateTime(2000, 1, 1, 10, 45, 0);
    const dt2 = new LocalDateTime(2000, 2, 4, 11, 50, 0);

    // Case 1: Entire period is time-based (no date units available)
    expect(Period.Between(dt1.TimeOfDay, dt2.TimeOfDay).HasDateComponent).toBe(false);

    // Case 2: Period contains date and time units, but date units are all zero
    expect(Period.Between(dt1, LocalDate.Add(dt1.Date, dt2.TimeOfDay)).HasDateComponent).toBe(false);

    // Case 3: Entire period is date-based, but 0. (Same local date twice here.)
    expect(Period.Between(dt1.Date, dt1.Date).HasDateComponent).toBe(false);

    // Case 4: Period contains date and time units, and some date units are non-zero
    expect(Period.Between(dt1, dt2).HasDateComponent).toBe(true);

    // Case 5: Entire period is date-based, and some time units are non-zero
    expect(Period.Between(dt1.Date, dt2.Date).HasDateComponent).toBe(true);
  },

  ToString_Positive() {
    const period = Period.Add(Period.FromDays(1), Period.FromHours(2));
    assertNodaEqual(period.toString(), "P1DT2H");
  },

  ToString_AllUnits() {
    const period = Period.NewYearsMonthsWeeksDaysHoursMinutesSecondsMillisecondsTicksNanoseconds(1, 2, 3, 4, 5, 6, 7, 8, 9, 10);
    assertNodaEqual(period.toString(), "P1Y2M3W4DT5H6M7S8s9t10n");
  },

  ToString_Negative() {
    const period = Period.Add(Period.FromDays(-1), Period.FromHours(-2));
    assertNodaEqual(period.toString(), "P-1DT-2H");
  },

  ToString_Mixed() {
    const period = Period.Add(Period.FromDays(-1), Period.FromHours(2));
    assertNodaEqual(period.toString(), "P-1DT2H");
  },

  ToString_Zero() {
    assertNodaEqual(Period.Zero.toString(), "P0D");
  },

  ToBuilder_SingleUnit() {
    const builder = Period.FromHours(5).ToBuilder();
    const expected = newPeriodBuilder({ Hours: 5 }).Build();
    assertNodaEqual(builder.Build(), expected);
  },

  ToBuilder_MultipleUnits() {
    const builder = Period.Add(Period.FromHours(5), Period.FromWeeks(2)).ToBuilder();
    const expected = newPeriodBuilder({ Hours: 5, Weeks: 2 }).Build();
    assertNodaEqual(builder.Build(), expected);
  },

  Normalize_Weeks() {
    const original = newPeriodBuilder({ Weeks: 2, Days: 5 }).Build();
    const normalized = original.Normalize();
    const expected = newPeriodBuilder({ Days: 19 }).Build();
    assertNodaEqual(normalized, expected);
  },

  Normalize_Hours() {
    const original = newPeriodBuilder({ Hours: 25, Days: 1 }).Build();
    const normalized = original.Normalize();
    const expected = newPeriodBuilder({ Hours: 1, Days: 2 }).Build();
    assertNodaEqual(normalized, expected);
  },

  Normalize_Minutes() {
    const original = newPeriodBuilder({ Hours: 1, Minutes: 150 }).Build();
    const normalized = original.Normalize();
    const expected = newPeriodBuilder({ Hours: 3, Minutes: 30 }).Build();
    assertNodaEqual(normalized, expected);
  },

  Normalize_Seconds() {
    const original = newPeriodBuilder({ Minutes: 1, Seconds: 150 }).Build();
    const normalized = original.Normalize();
    const expected = newPeriodBuilder({ Minutes: 3, Seconds: 30 }).Build();
    assertNodaEqual(normalized, expected);
  },

  Normalize_Milliseconds() {
    const original = newPeriodBuilder({ Seconds: 1, Milliseconds: 1500 }).Build();
    const normalized = original.Normalize();
    const expected = newPeriodBuilder({ Seconds: 2, Milliseconds: 500 }).Build();
    assertNodaEqual(normalized, expected);
  },

  Normalize_Ticks() {
    const original = newPeriodBuilder({ Milliseconds: 1, Ticks: 15000 }).Build();
    const normalized = original.Normalize();
    const expected = newPeriodBuilder({ Milliseconds: 2, Ticks: 0, Nanoseconds: 500000 }).Build();
    assertNodaEqual(normalized, expected);
  },

  Normalize_Nanoseconds() {
    const original = newPeriodBuilder({ Ticks: 1, Nanoseconds: 150 }).Build();
    const normalized = original.Normalize();
    const expected = newPeriodBuilder({ Nanoseconds: 250 }).Build();
    assertNodaEqual(normalized, expected);
  },

  Normalize_MultipleFields() {
    const original = newPeriodBuilder({ Hours: 1, Minutes: 119, Seconds: 150 }).Build();
    const normalized = original.Normalize();
    const expected = newPeriodBuilder({ Hours: 3, Minutes: 1, Seconds: 30 }).Build();
    assertNodaEqual(normalized, expected);
  },

  Normalize_AllNegative() {
    const original = newPeriodBuilder({ Hours: -1, Minutes: -119, Seconds: -150 }).Build();
    const normalized = original.Normalize();
    const expected = newPeriodBuilder({ Hours: -3, Minutes: -1, Seconds: -30 }).Build();
    assertNodaEqual(normalized, expected);
  },

  Normalize_MixedSigns_PositiveResult() {
    const original = newPeriodBuilder({ Hours: 3, Minutes: -1 }).Build();
    const normalized = original.Normalize();
    const expected = newPeriodBuilder({ Hours: 2, Minutes: 59 }).Build();
    assertNodaEqual(normalized, expected);
  },

  Normalize_MixedSigns_NegativeResult() {
    const original = newPeriodBuilder({ Hours: 1, Minutes: -121 }).Build();
    const normalized = original.Normalize();
    const expected = newPeriodBuilder({ Hours: -1, Minutes: -1 }).Build();
    assertNodaEqual(normalized, expected);
  },

  Normalize_DoesntAffectMonthsAndYears() {
    const original = newPeriodBuilder({ Years: 2, Months: 1, Days: 400 }).Build();
    assertNodaEqual(original.Normalize(), original);
  },

  Normalize_ZeroResult() {
    const original = newPeriodBuilder({ Years: 0 }).Build();
    assertNodaEqual(original.Normalize(), Period.Zero);
  },

  Normalize_Overflow() {
    const period = Period.FromHours(longMaxValue);
    assertThrows(OverflowError, () => period.Normalize());
  },

  ToString_SingleUnit() {
    const period = Period.FromHours(5);
    assertNodaEqual(period.toString(), "PT5H");
  },

  ToString_MultipleUnits() {
    const period = newPeriodBuilder({ Hours: 5, Minutes: 30 }).Build();
    assertNodaEqual(period.toString(), "PT5H30M");
  },

  ToDuration_InvalidWithYears() {
    const period = Period.FromYears(1);
    assertThrows(InvalidOperationError, () => period.ToDuration());
  },

  ToDuration_InvalidWithMonths() {
    const period = Period.FromMonths(1);
    assertThrows(InvalidOperationError, () => period.ToDuration());
  },

  ToDuration_ValidAllAcceptableUnits() {
    const period = newPeriodBuilder({
      Weeks: 1,
      Days: 2,
      Hours: 3,
      Minutes: 4,
      Seconds: 5,
      Milliseconds: 6,
      Ticks: 7,
    }).Build();
    assertNodaEqual(
      period.ToDuration().BclCompatibleTicks,
      1 * NodaConstants.TicksPerWeek +
      2 * NodaConstants.TicksPerDay +
      3 * NodaConstants.TicksPerHour +
      4 * NodaConstants.TicksPerMinute +
      5 * NodaConstants.TicksPerSecond +
      6 * NodaConstants.TicksPerMillisecond + 7);
  },

  ToDuration_ValidWithZeroValuesInMonthYearUnits() {
    let period = Period.Add(Period.FromMonths(1), Period.FromYears(1));
    period = Period.Add(Period.Subtract(period, period), Period.FromDays(1));
    expect(period.HasTimeComponent).toBe(false);
    assertNodaEqual(period.ToDuration(), Duration.OneDay);
  },

  ToDuration_Overflow() {
    const period = Period.FromSeconds(longMaxValue);
    assertThrows(OverflowError, () => period.ToDuration());
  },

  ToDuration_Overflow_WhenPossiblyValid() {
    // These two should pretty much cancel each other out - and would, if we had a 128-bit integer
    // representation to use.
    const period = Period.Add(Period.FromSeconds(longMaxValue), Period.FromMinutes(Int64.ToString(Int64.Divide(Int64.MinValue, 60))));
    assertThrows(OverflowError, () => period.ToDuration());
  },

  NormalizingEqualityComparer_NullToNonNull() {
    const period = Period.FromYears(1);
    expect(Period.NormalizingEqualityComparer.Equals(period, null)).toBe(false);
    expect(Period.NormalizingEqualityComparer.Equals(null, period)).toBe(false);
  },

  NormalizingEqualityComparer_NullToNull() {
    expect(Period.NormalizingEqualityComparer.Equals(null, null)).toBe(true);
  },

  NormalizingEqualityComparer_PeriodToItself() {
    const period = Period.FromYears(1);
    expect(Period.NormalizingEqualityComparer.Equals(period, period)).toBe(true);
  },

  NormalizingEqualityComparer_NonEqualAfterNormalization() {
    const period1 = Period.FromHours(2);
    const period2 = Period.FromMinutes(150);
    expect(Period.NormalizingEqualityComparer.Equals(period1, period2)).toBe(false);
  },

  NormalizingEqualityComparer_EqualAfterNormalization() {
    const period1 = Period.FromHours(2);
    const period2 = Period.FromMinutes(120);
    expect(Period.NormalizingEqualityComparer.Equals(period1, period2)).toBe(true);
  },

  Comparer_NullWithNull() {
    const comparer = Period.CreateComparer(new LocalDateTime(2000, 1, 1, 0, 0));
    assertNodaEqual(comparer.Compare(null, null), 0);
  },

  Comparer_NullWithNonNull() {
    const comparer = Period.CreateComparer(new LocalDateTime(2000, 1, 1, 0, 0));
    expect(comparer.Compare(null, Period.Zero)).toBeLessThan(0);
  },

  Comparer_NonNullWithNull() {
    const comparer = Period.CreateComparer(new LocalDateTime(2000, 1, 1, 0, 0));
    expect(comparer.Compare(Period.Zero, null)).toBeGreaterThan(0);
  },

  Comparer_DurationablePeriods() {
    const bigger = Period.FromHours(25);
    const smaller = Period.FromDays(1);
    const comparer = Period.CreateComparer(new LocalDateTime(2000, 1, 1, 0, 0));
    expect(comparer.Compare(bigger, smaller)).toBeGreaterThan(0);
    expect(comparer.Compare(smaller, bigger)).toBeLessThan(0);
    assertNodaEqual(comparer.Compare(bigger, bigger), 0);
  },

  Comparer_NonDurationablePeriods() {
    const month = Period.FromMonths(1);
    const days = Period.FromDays(30);
    // At the start of January, a month is longer than 30 days
    const januaryComparer = Period.CreateComparer(new LocalDateTime(2000, 1, 1, 0, 0));
    expect(januaryComparer.Compare(month, days)).toBeGreaterThan(0);
    expect(januaryComparer.Compare(days, month)).toBeLessThan(0);
    assertNodaEqual(januaryComparer.Compare(month, month), 0);

    // At the start of February, a month is shorter than 30 days
    const februaryComparer = Period.CreateComparer(new LocalDateTime(2000, 2, 1, 0, 0));
    expect(februaryComparer.Compare(month, days)).toBeLessThan(0);
    expect(februaryComparer.Compare(days, month)).toBeGreaterThan(0);
    assertNodaEqual(februaryComparer.Compare(month, month), 0);
  },

  // C# iterates Period's public instance properties by reflection, comparing int properties with expectedIntValue and
  // long properties with expectedLongValue (stopping at the first bool property, HasTimeComponent/HasDateComponent,
  // which are declared after all the unit properties). noda-js lists the properties explicitly; the long ones are
  // compared exactly through the internal exact accessors, as the public getters return the nearest number.
  Period_MaxAndMinValues_AllMembers(period: Period, expectedIntValue: number, expectedLongValue: string) {
    const exactLongValues = {
      nanoseconds: period.ExactNanoseconds,
      ticks: period.ExactTicks,
      milliseconds: period.ExactMilliseconds,
      seconds: period.ExactSeconds,
      minutes: period.ExactMinutes,
      hours: period.ExactHours,
    };
    for (const [name, actualValue] of Object.entries(exactLongValues)) {
      assertNodaEqual(Int64.ToString(actualValue), expectedLongValue, name);
    }
    const intValues = { days: period.Days, weeks: period.Weeks, months: period.Months, years: period.Years };
    for (const [name, actualValue] of Object.entries(intValues)) {
      assertNodaEqual(actualValue, expectedIntValue, name);
    }
  },

  Between_ExtremeValues(units: PeriodUnits) {
    // We can't use None, and Nanoseconds will *correctly* overflow.
    if (units === PeriodUnits.None || units === PeriodUnits.Nanoseconds) {
      return;
    }
    const minValue = LocalDate.MinIsoValue.At(LocalTime.MinValue);
    const maxValue = LocalDate.MaxIsoValue.At(LocalTime.MaxValue);
    Period.Between(minValue, maxValue, units);
  },

  Between_ExtremeValues_Overflow() {
    const minValue = LocalDate.MinIsoValue.At(LocalTime.MinValue);
    const maxValue = LocalDate.MaxIsoValue.At(LocalTime.MaxValue);
    assertThrows(OverflowError, () => Period.Between(minValue, maxValue, PeriodUnits.Nanoseconds));
  },

  Between_LocalDateTime_AwkwardTimeOfDayWithSingleUnit(startText: string, endText: string, units: PeriodUnits, expectedForward: number,
    expectedBackward: number) {
    const start = LocalDateTimePattern.ExtendedIso.Parse(startText).Value;
    const end = LocalDateTimePattern.ExtendedIso.Parse(endText).Value;
    const forward = Period.Between(start, end, units);
    assertNodaEqual(forward.ToBuilder().Get(units), expectedForward);
    const backward = Period.Between(end, start, units);
    assertNodaEqual(backward.ToBuilder().Get(units), expectedBackward);
  },

  Between_LocalDateTime_SameValue() {
    const start = new LocalDateTime(2014, 1, 1, 16, 0, 0);
    expect(Period.Between(start, start)).toBe(Period.Zero);
  },

  Between_LocalDateTime_AwkwardTimeOfDayWithMultipleUnits() {
    const start = new LocalDateTime(2014, 1, 1, 16, 0, 0);
    const end = new LocalDateTime(2015, 2, 3, 8, 0, 0);
    const actual = Period.Between(start, end, PeriodUnits.YearMonthDay | PeriodUnits.AllTimeUnits);
    const expected = newPeriodBuilder({ Years: 1, Months: 1, Days: 1, Hours: 16 }).Build();
    assertNodaEqual(actual, expected);
  },

  BetweenYearMonth_InvalidUnits() {
    const yearMonth1 = new YearMonth(2010, 1);
    const yearMonth2 = new YearMonth(2011, 3);
    assertThrows(ArgumentError, () => Period.Between(yearMonth1, yearMonth2, 0 as PeriodUnits));
    assertThrows(ArgumentError, () => Period.Between(yearMonth1, yearMonth2, -1 as PeriodUnits));
    assertThrows(ArgumentError, () => Period.Between(yearMonth1, yearMonth2, PeriodUnits.AllTimeUnits));
    assertThrows(ArgumentError, () => Period.Between(yearMonth1, yearMonth2, PeriodUnits.Days));
    assertThrows(ArgumentError, () => Period.Between(yearMonth1, yearMonth2, PeriodUnits.Years | PeriodUnits.Days));
    assertThrows(ArgumentError, () => Period.Between(yearMonth1, yearMonth2, PeriodUnits.Years | PeriodUnits.Weeks));
    assertThrows(ArgumentError, () => Period.Between(yearMonth1, yearMonth2, PeriodUnits.Years | PeriodUnits.Hours));
  },

  BetweenYearMonth_DifferentCalendarSystems_Throws() {
    const start = new YearMonth(2017, 11, CalendarSystem.Coptic);
    const end = new YearMonth(2017, 11, CalendarSystem.Gregorian);
    assertThrows(ArgumentError, () => Period.Between(start, end));
  },

  BetweenYearMonth_SingleUnit(startText: string, endText: string, units: PeriodUnits, expectedValue: number) {
    const start = YearMonthPattern.Iso.Parse(startText).Value;
    const end = YearMonthPattern.Iso.Parse(endText).Value;
    const forward = Period.Between(start, end, units);
    const expectedForward = newPeriodBuilderIndexed([units, expectedValue]).Build();
    assertNodaEqual(forward, expectedForward);
    const backward = Period.Between(end, start, units);
    const expectedBackward = newPeriodBuilderIndexed([units, -expectedValue]).Build();
    assertNodaEqual(backward, expectedBackward);
  },

  BetweenYearMonth_BothUnits(startText: string, endText: string, expectedYears: number, expectedMonths: number) {
    const start = YearMonthPattern.Iso.Parse(startText).Value;
    const end = YearMonthPattern.Iso.Parse(endText).Value;
    const forward = Period.Between(start, end, PeriodUnits.Years | PeriodUnits.Months);
    const expectedForward = newPeriodBuilderIndexed([PeriodUnits.Years, expectedYears], [PeriodUnits.Months, expectedMonths]).Build();
    assertNodaEqual(forward, expectedForward);
    const forwardNoUnits = Period.Between(start, end);
    assertNodaEqual(forwardNoUnits, expectedForward);
    const backward = Period.Between(end, start, PeriodUnits.Years | PeriodUnits.Months);
    const expectedBackward = newPeriodBuilderIndexed([PeriodUnits.Years, -expectedYears], [PeriodUnits.Months, -expectedMonths]).Build();
    assertNodaEqual(backward, expectedBackward);
    const backwardNoUnits = Period.Between(end, start);
    assertNodaEqual(backwardNoUnits, expectedBackward);
  },

  FromNanoseconds() {
    const period = Period.FromNanoseconds(1234567890);
    assertNodaEqual(period.Nanoseconds, 1234567890);
  },

  AddPeriodToPeriod_NoOverflow() {
    const p1 = Period.FromHours(longMaxValue);
    const p2 = Period.FromMinutes(60);
    assertNodaEqual(Period.Add(p1, p2), newPeriodBuilder({ Hours: longMaxValue, Minutes: 60 }).Build());
  },

  AddPeriodToPeriod_Overflow() {
    const p1 = Period.FromHours(longMaxValue);
    const p2 = Period.FromHours(1);
    // C#: (p1 + p2).GetHashCode(); hash codes are omitted in noda-js, and the overflow is in the addition.
    assertThrows(OverflowError, () => Period.Add(p1, p2));
  },
}, {
  skip: {
    BetweenLocalDateTimes_OnLeapYearIslamic: "non-ISO calendar (Islamic) not supported in noda-js",
    NormalizingEqualityComparer_GetHashCodeAfterNormalization: "GetHashCode is omitted in noda-js",
  },
});
