// Ported from NodaTime 3.3.7: src/NodaTime.Test/LocalDateTest.cs
// (+ LocalDateTest.BasicProperties.cs, .Comparison.cs, .Construction.cs, .Conversion.cs, .PeriodArithmetic.cs,
// .Pseudomutators.cs)
// Copyright 2010 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda-js: C# operators are LocalDate.Add / Subtract (+, -) and CompareTo (<, <=, >, >=); == / != are Equals().
// GetHashCode isn't ported, so those checks are omitted. The internal constructors LocalDate(int daysSinceEpoch)
// and LocalDate(int daysSinceEpoch, CalendarSystem) are LocalDate.NewDaysSinceEpoch / NewDaysSinceEpochCalendar.
// Deconstruct isn't ported: JS destructuring of the getters is the equivalent. The BCL DateTime values used as an
// oracle are computed with JS Date.

import { expect } from "vitest";
import {
  CalendarOrdinal,
  CalendarSystem,
  DateAdjusters,
  Era,
  Instant,
  IslamicEpoch,
  IslamicLeapYearPattern,
  IsoDayOfWeek,
  LocalDate,
  LocalDateTime,
  LocalTime,
  NodaConstants,
  Offset,
  OffsetDate,
  Period,
} from "../../src/noda-js/internal.ts";
import { PersianSimple } from "../../src/noda-js/entries/calendars/persian.ts";
import { GetIslamicCalendar } from "../../src/noda-js/entries/calendars/islamic.ts";
import { assertNodaEqual, assertThrows } from "../helpers/assertions.ts";
import { port } from "../helpers/scenarios.ts";
import { TestHelper } from "../helpers/TestHelper.ts";
import { fixture } from "../scenarios/LocalDateTest.generated.ts";
import type { ArgumentException, ArgumentOutOfRangeException, OverflowException } from "../../src/noda-js/internal.ts";

/** C# BclConversions.ToIsoDayOfWeek(System.DayOfWeek): JS Date.getUTCDay() uses the same numbering (0 = Sunday). */
function toIsoDayOfWeek(dayOfWeek: number): IsoDayOfWeek {
  return dayOfWeek === 0 ? IsoDayOfWeek.Sunday : dayOfWeek as IsoDayOfWeek;
}

port(fixture, {
  // #region LocalDateTest.cs
  CombinationWithTime() {
    // Test all three approaches in the same test - they're logically equivalent.
    const calendar = CalendarSystem.Julian;
    const date = new LocalDate(2014, 3, 28, calendar);
    const time = new LocalTime(20, 17, 30);
    const expected = new LocalDateTime(2014, 3, 28, 20, 17, 30, calendar);
    assertNodaEqual(LocalDate.Add(date, time), expected);
    assertNodaEqual(date.At(time), expected);
    assertNodaEqual(time.On(date), expected);
  },

  Construction_NullCalendar_Throws() {
    assertThrows("ArgumentNullException", () => new LocalDate(2017, 11, 7, null!)); // Basic construction.
    assertThrows("ArgumentNullException", () => new LocalDate(Era.Common, 2017, 11, 7, null!)); // Construction including era.
  },

  MaxIsoValue() {
    const value = LocalDate.MaxIsoValue;
    assertNodaEqual(value.Calendar, CalendarSystem.Iso);
    assertThrows("OverflowException", () => value.PlusDays(1));
  },

  MinIsoValue() {
    const value = LocalDate.MinIsoValue;
    assertNodaEqual(value.Calendar, CalendarSystem.Iso);
    assertThrows("OverflowException", () => value.PlusDays(-1));
  },

  Deconstruction() {
    const value = new LocalDate(2017, 11, 7);
    const expectedYear = 2017;
    const expectedMonth = 11;
    const expectedDay = 7;
    const { Year: actualYear, Month: actualMonth, Day: actualDay } = value;

    assertNodaEqual(actualYear, expectedYear);
    assertNodaEqual(actualMonth, expectedMonth);
    assertNodaEqual(actualDay, expectedDay);
  },

  Deconstruction_IncludingCalendar() {
    const value = new LocalDate(2017, 11, 7, CalendarSystem.Gregorian);
    const expectedYear = 2017;
    const expectedMonth = 11;
    const expectedDay = 7;
    const expectedCalendar = CalendarSystem.Gregorian;
    const { Year: actualYear, Month: actualMonth, Day: actualDay, Calendar: actualCalendar } = value;

    assertNodaEqual(actualYear, expectedYear);
    assertNodaEqual(actualMonth, expectedMonth);
    assertNodaEqual(actualDay, expectedDay);
    assertNodaEqual(actualCalendar, expectedCalendar);
  },
  // #endregion

  // #region LocalDateTest.BasicProperties.cs
  EpochProperties() {
    const date = NodaConstants.UnixEpoch.InUtc().Date;
    assertNodaEqual(date.Year, 1970);
    assertNodaEqual(date.YearOfEra, 1970);
    assertNodaEqual(date.Day, 1);
    assertNodaEqual(date.DayOfWeek, IsoDayOfWeek.Thursday);
    assertNodaEqual(date.DayOfYear, 1);
    assertNodaEqual(date.Month, 1);
  },

  ArbitraryDateProperties() {
    // C#: (new DateTime(2011, 3, 5, ...).Ticks - new DateTime(1970, 1, 1, ...).Ticks) / NodaConstants.TicksPerDay
    const bclTicks = Date.UTC(2011, 2, 5) * NodaConstants.TicksPerMillisecond;
    const bclDays = Math.trunc(bclTicks / NodaConstants.TicksPerDay);
    const date = LocalDate.NewDaysSinceEpochCalendar(bclDays, CalendarSystem.Iso);
    assertNodaEqual(date.Year, 2011);
    assertNodaEqual(date.YearOfEra, 2011);
    assertNodaEqual(date.Day, 5);
    assertNodaEqual(date.DayOfWeek, IsoDayOfWeek.Saturday);
    assertNodaEqual(date.DayOfYear, 64);
    assertNodaEqual(date.Month, 3);
  },

  DayOfWeek_AroundEpoch() {
    // Test about couple of months around the Unix epoch. If that works, I'm confident the rest will.
    let date = new LocalDate(1969, 12, 1);
    for (let i = 0; i < 60; i++) {
      // C#: date.AtMidnight().ToDateTimeUnspecified().DayOfWeek
      const bclDayOfWeek = new Date(Date.UTC(date.Year, date.Month - 1, date.Day)).getUTCDay();
      assertNodaEqual(date.DayOfWeek, toIsoDayOfWeek(bclDayOfWeek));
      date = date.PlusDays(1);
    }
  },
  // #endregion

  // #region LocalDateTest.Comparison.cs
  Equals_EqualValues() {
    const calendar = CalendarSystem.Julian;
    const date1 = new LocalDate(2011, 1, 2, calendar);
    const date2 = new LocalDate(2011, 1, 2, calendar);
    assertNodaEqual(date2, date1);
    expect(date1.Equals(date2)).toBe(true); // C# ==
    expect(!date1.Equals(date2)).toBe(false); // C# !=
    expect(date1.Equals(date2)).toBe(true); // IEquatable implementation
  },

  Equals_DifferentDates() {
    const calendar = CalendarSystem.Julian;
    const date1 = new LocalDate(2011, 1, 2, calendar);
    const date2 = new LocalDate(2011, 1, 3, calendar);
    expect(date1.Equals(date2)).toBe(false); // Assert.AreNotEqual
    expect(date1.Equals(date2)).toBe(false); // C# ==
    expect(!date1.Equals(date2)).toBe(true); // C# !=
    expect(date1.Equals(date2)).toBe(false); // IEquatable implementation
  },

  Equals_DifferentCalendars() {
    const calendar = CalendarSystem.Julian;
    const date1 = new LocalDate(2011, 1, 2, calendar);
    const date2 = new LocalDate(2011, 1, 2, CalendarSystem.Iso);
    expect(date1.Equals(date2)).toBe(false); // Assert.AreNotEqual
    expect(date1.Equals(date2)).toBe(false); // C# ==
    expect(!date1.Equals(date2)).toBe(true); // C# !=
    expect(date1.Equals(date2)).toBe(false); // IEquatable implementation
  },

  Equals_DifferentToNull() {
    const date = new LocalDate(2011, 1, 2);
    expect(date.Equals(null!)).toBe(false);
  },

  Equals_DifferentToOtherType() {
    const date = new LocalDate(2011, 1, 2);
    expect(date.Equals(Instant.FromUnixTimeTicks(0))).toBe(false);
  },

  ComparisonOperators_SameCalendar() {
    const date1 = new LocalDate(2011, 1, 2);
    const date2 = new LocalDate(2011, 1, 2);
    const date3 = new LocalDate(2011, 1, 5);

    expect(date1.CompareTo(date2) < 0).toBe(false);
    expect(date1.CompareTo(date3) < 0).toBe(true);
    expect(date2.CompareTo(date1) < 0).toBe(false);
    expect(date3.CompareTo(date1) < 0).toBe(false);

    expect(date1.CompareTo(date2) <= 0).toBe(true);
    expect(date1.CompareTo(date3) <= 0).toBe(true);
    expect(date2.CompareTo(date1) <= 0).toBe(true);
    expect(date3.CompareTo(date1) <= 0).toBe(false);

    expect(date1.CompareTo(date2) > 0).toBe(false);
    expect(date1.CompareTo(date3) > 0).toBe(false);
    expect(date2.CompareTo(date1) > 0).toBe(false);
    expect(date3.CompareTo(date1) > 0).toBe(true);

    expect(date1.CompareTo(date2) >= 0).toBe(true);
    expect(date1.CompareTo(date3) >= 0).toBe(false);
    expect(date2.CompareTo(date1) >= 0).toBe(true);
    expect(date3.CompareTo(date1) >= 0).toBe(true);
  },

  ComparisonOperators_DifferentCalendars_Throws() {
    const date1 = new LocalDate(2011, 1, 2);
    const date2 = new LocalDate(2011, 1, 3, CalendarSystem.Julian);

    assertThrows("ArgumentException", () => (date1.CompareTo(date2) < 0).toString());
    assertThrows("ArgumentException", () => (date1.CompareTo(date2) <= 0).toString());
    assertThrows("ArgumentException", () => (date1.CompareTo(date2) > 0).toString());
    assertThrows("ArgumentException", () => (date1.CompareTo(date2) >= 0).toString());
  },

  CompareTo_SameCalendar() {
    const date1 = new LocalDate(2011, 1, 2);
    const date2 = new LocalDate(2011, 1, 2);
    const date3 = new LocalDate(2011, 1, 5);

    expect(date1.CompareTo(date2)).toBe(0);
    expect(date1.CompareTo(date3)).toBeLessThan(0);
    expect(date3.CompareTo(date2)).toBeGreaterThan(0);
  },

  /** IComparable.CompareTo works properly with LocalDate inputs with same calendar. */
  CompareTo_DifferentCalendars_Throws() {
    const islamic = GetIslamicCalendar(IslamicLeapYearPattern.Base15, IslamicEpoch.Astronomical);
    const date1 = new LocalDate(2011, 1, 2);
    const date2 = new LocalDate(1500, 1, 1, islamic);

    assertThrows("ArgumentException", () => date1.CompareTo(date2));
    // C#: ((IComparable) date1).CompareTo(date2), the same CompareTo here.
    assertThrows("ArgumentException", () => date1.CompareTo(date2 as unknown));
  },

  IComparableCompareTo_SameCalendar() {
    const instance = new LocalDate(2012, 3, 5);
    const i_instance = instance;

    const later = new LocalDate(2012, 6, 4);
    const earlier = new LocalDate(2012, 1, 4);
    const same = new LocalDate(2012, 3, 5);

    expect(i_instance.CompareTo(later)).toBeLessThan(0);
    expect(i_instance.CompareTo(earlier)).toBeGreaterThan(0);
    expect(i_instance.CompareTo(same)).toBe(0);
  },

  /** IComparable.CompareTo returns a positive number for a null input. */
  IComparableCompareTo_Null_Positive() {
    const instance = new LocalDate(2012, 3, 5);
    const comparable = instance;
    const result = comparable.CompareTo(null!);
    expect(result).toBeGreaterThan(0);
  },

  /** IComparable.CompareTo throws an ArgumentException for non-null arguments that are not a LocalDate. */
  IComparableCompareTo_WrongType_ArgumentException() {
    const instance = new LocalDate(2012, 3, 5);
    const i_instance = instance;
    const arg = new LocalDateTime(2012, 3, 6, 15, 42);
    assertThrows("ArgumentException", () => {
      i_instance.CompareTo(arg as unknown as LocalDate);
    });
  },

  MinMax_DifferentCalendars_Throws() {
    const date1 = new LocalDate(2011, 1, 2);
    const date2 = new LocalDate(1500, 1, 1, CalendarSystem.Julian);

    assertThrows("ArgumentException", () => LocalDate.Max(date1, date2));
    assertThrows("ArgumentException", () => LocalDate.Min(date1, date2));
  },

  MinMax_SameCalendar() {
    const date1 = new LocalDate(1500, 1, 2, CalendarSystem.Julian);
    const date2 = new LocalDate(1500, 1, 1, CalendarSystem.Julian);

    assertNodaEqual(LocalDate.Max(date1, date2), date1);
    assertNodaEqual(LocalDate.Max(date2, date1), date1);
    assertNodaEqual(LocalDate.Min(date1, date2), date2);
    assertNodaEqual(LocalDate.Min(date2, date1), date2);
  },
  // #endregion

  // #region LocalDateTest.Construction.cs
  Constructor_WithDays(year: number) {
    const start = new LocalDate(year, 1, 1);
    const startDays = start.DaysSinceEpoch;
    for (let i = 0; i < 366; i++) {
      assertNodaEqual(LocalDate.NewDaysSinceEpoch(startDays + i), start.PlusDays(i));
    }
  },

  Constructor_WithDaysAndCalendar(year: number) {
    const start = new LocalDate(year, 1, 1);
    const startDays = start.DaysSinceEpoch;
    for (let i = 0; i < 366; i++) {
      assertNodaEqual(LocalDate.NewDaysSinceEpochCalendar(startDays + i, CalendarSystem.Iso), start.PlusDays(i));
    }
  },

  Constructor_CalendarDefaultsToIso() {
    const date = new LocalDate(2000, 1, 1);
    assertNodaEqual(date.Calendar, CalendarSystem.Iso);
  },

  Constructor_PropertiesRoundTrip() {
    const date = new LocalDate(2023, 7, 27);
    assertNodaEqual(date.Year, 2023);
    assertNodaEqual(date.Month, 7);
    assertNodaEqual(date.Day, 27);
  },

  Constructor_PropertiesRoundTrip_CustomCalendar() {
    const date = new LocalDate(2023, 7, 27, CalendarSystem.Julian);
    assertNodaEqual(date.Year, 2023);
    assertNodaEqual(date.Month, 7);
    assertNodaEqual(date.Day, 27);
  },

  Constructor_Invalid(year: number, month: number, day: number) {
    assertThrows("ArgumentOutOfRangeException", () => new LocalDate(year, month, day));
  },

  Constructor_Invalid_WithCalendar(year: number, month: number, day: number) {
    assertThrows("ArgumentOutOfRangeException", () => new LocalDate(year, month, day, CalendarSystem.Iso));
  },

  Constructor_InvalidYearOfEra() {
    assertThrows("ArgumentOutOfRangeException", () => new LocalDate(Era.Common, 0, 1, 1));
    assertThrows("ArgumentOutOfRangeException", () => new LocalDate(Era.BeforeCommon, 0, 1, 1));
    assertThrows("ArgumentOutOfRangeException", () => new LocalDate(Era.Common, 10000, 1, 1));
    // Although our minimum year is -9998, that's 9999 BC.
    assertThrows("ArgumentOutOfRangeException", () => new LocalDate(Era.BeforeCommon, 10000, 1, 1));
  },

  Constructor_WithYearOfEra_BC() {
    const absolute = new LocalDate(-10, 1, 1);
    const withEra = new LocalDate(Era.BeforeCommon, 11, 1, 1);
    assertNodaEqual(withEra, absolute);
  },

  Constructor_WithYearOfEra_AD() {
    const absolute = new LocalDate(50, 6, 19);
    const withEra = new LocalDate(Era.Common, 50, 6, 19);
    assertNodaEqual(withEra, absolute);
  },

  Constructor_WithYearOfEra_NonIsoCalendar() {
    const calendar = CalendarSystem.Coptic;
    const absolute = new LocalDate(50, 6, 19, calendar);
    const withEra = new LocalDate(Era.AnnoMartyrum, 50, 6, 19, calendar);
    assertNodaEqual(withEra, absolute);
  },

  // Most tests are in IsoBasedWeekYearRuleTest.
  FromWeekYearWeekAndDay_InvalidWeek53() {
    // Week year 2005 only has 52 weeks
    assertThrows("ArgumentOutOfRangeException", () => LocalDate.FromWeekYearWeekAndDay(2005, 53, IsoDayOfWeek.Sunday));
  },

  FromYearMonthWeekAndDay(year: number, month: number, occurrence: number, dayOfWeek: IsoDayOfWeek, expectedDay: number) {
    const date = LocalDate.FromYearMonthWeekAndDay(year, month, occurrence, dayOfWeek);
    assertNodaEqual(date.Year, year);
    assertNodaEqual(date.Month, month);
    assertNodaEqual(date.Day, expectedDay);
  },
  // #endregion

  // #region LocalDateTest.Conversion.cs
  AtMidnight() {
    const date = new LocalDate(2011, 6, 29);
    const expected = new LocalDateTime(2011, 6, 29, 0, 0, 0);
    assertNodaEqual(date.AtMidnight(), expected);
  },

  WithCalendar() {
    const isoEpoch = new LocalDate(1970, 1, 1);
    const julianEpoch = isoEpoch.WithCalendar(CalendarSystem.Julian);
    assertNodaEqual(julianEpoch.Year, 1969);
    assertNodaEqual(julianEpoch.Month, 12);
    assertNodaEqual(julianEpoch.Day, 19);
  },

  WithOffset() {
    const date = new LocalDate(2011, 6, 29);
    const offset = Offset.FromHours(5);
    const expected = new OffsetDate(date, offset);
    assertNodaEqual(date.WithOffset(offset), expected);
  },

  WithCalendar_OutOfRange() {
    const start = new LocalDate(1, 1, 1);
    assertThrows("ArgumentOutOfRangeException", () => start.WithCalendar(PersianSimple));
  },

  WithCalendar_Unchanged() {
    const isoEpoch = new LocalDate(1970, 1, 1);
    const unchanged = isoEpoch.WithCalendar(CalendarSystem.Iso);
    assertNodaEqual(unchanged.Year, isoEpoch.Year);
    assertNodaEqual(unchanged.Month, isoEpoch.Month);
    assertNodaEqual(unchanged.Day, isoEpoch.Day);
    expect(unchanged.Calendar).toBe(isoEpoch.Calendar);
  },
  // #endregion

  // #region LocalDateTest.PeriodArithmetic.cs
  Addition_WithPeriod() {
    const start = new LocalDate(2010, 6, 19);
    const period = Period.Add(Period.FromMonths(3), Period.FromDays(10));
    const expected = new LocalDate(2010, 9, 29);
    assertNodaEqual(LocalDate.Add(start, period), expected);
  },

  Addition_TruncatesOnShortMonth() {
    const start = new LocalDate(2010, 1, 30);
    const period = Period.FromMonths(1);
    const expected = new LocalDate(2010, 2, 28);
    assertNodaEqual(LocalDate.Add(start, period), expected);
  },

  Addition_WithNullPeriod_ThrowsArgumentNullException() {
    const date = new LocalDate(2010, 1, 1);
    // Call to ToString just to make it a valid statement
    assertThrows("ArgumentNullException", () => LocalDate.Add(date, null! as Period).toString());
  },

  Subtraction_WithPeriod() {
    const start = new LocalDate(2010, 9, 29);
    const period = Period.Add(Period.FromMonths(3), Period.FromDays(10));
    const expected = new LocalDate(2010, 6, 19);
    assertNodaEqual(LocalDate.Subtract(start, period), expected);
  },

  Subtraction_TruncatesOnShortMonth() {
    const start = new LocalDate(2010, 3, 30);
    const period = Period.FromMonths(1);
    const expected = new LocalDate(2010, 2, 28);
    assertNodaEqual(LocalDate.Subtract(start, period), expected);
  },

  Subtraction_WithNullPeriod_ThrowsArgumentNullException() {
    const date = new LocalDate(2010, 1, 1);
    // Call to ToString just to make it a valid statement
    assertThrows("ArgumentNullException", () => LocalDate.Subtract(date, null! as Period).toString());
  },

  Addition_PeriodWithTime() {
    const date = new LocalDate(2010, 1, 1);
    const period = Period.FromHours(1);
    // Use method not operator here to form a valid statement
    assertThrows("ArgumentException", () => LocalDate.Add(date, period));
  },

  Subtraction_PeriodWithTime() {
    const date = new LocalDate(2010, 1, 1);
    const period = Period.FromHours(1);
    // Use method not operator here to form a valid statement
    assertThrows("ArgumentException", () => LocalDate.Subtract(date, period));
  },

  PeriodAddition_MethodEquivalents() {
    const start = new LocalDate(2010, 6, 19);
    const period = Period.Add(Period.FromMonths(3), Period.FromDays(10));
    assertNodaEqual(LocalDate.Add(start, period), LocalDate.Add(start, period));
    assertNodaEqual(start.Plus(period), LocalDate.Add(start, period));
  },

  PeriodSubtraction_MethodEquivalents() {
    const start = new LocalDate(2010, 6, 19);
    const period = Period.Add(Period.FromMonths(3), Period.FromDays(10));
    const end = LocalDate.Add(start, period);
    assertNodaEqual(LocalDate.Subtract(start, period), LocalDate.Subtract(start, period));
    assertNodaEqual(start.Minus(period), LocalDate.Subtract(start, period));
    assertNodaEqual(LocalDate.Subtract(end, start), period);
    assertNodaEqual(LocalDate.Subtract(end, start), period);
    assertNodaEqual(end.Minus(start), period);
  },

  PlusMonths_Overflow(year: number, month: number, day: number, monthsToAdd: number) {
    const start = new LocalDate(year, month, day);
    assertThrows("OverflowException", () => start.PlusMonths(monthsToAdd));
  },
  // #endregion

  // #region LocalDateTest.Pseudomutators.cs
  PlusYear_Simple() {
    const start = new LocalDate(2011, 6, 26);
    let expected = new LocalDate(2016, 6, 26);
    assertNodaEqual(start.PlusYears(5), expected);

    expected = new LocalDate(2006, 6, 26);
    assertNodaEqual(start.PlusYears(-5), expected);
  },

  PlusYear_LeapToNonLeap() {
    const start = new LocalDate(2012, 2, 29);
    let expected = new LocalDate(2013, 2, 28);
    assertNodaEqual(start.PlusYears(1), expected);

    expected = new LocalDate(2011, 2, 28);
    assertNodaEqual(start.PlusYears(-1), expected);
  },

  PlusYear_LeapToLeap() {
    const start = new LocalDate(2012, 2, 29);
    const expected = new LocalDate(2016, 2, 29);
    assertNodaEqual(start.PlusYears(4), expected);
  },

  PlusMonth_Simple() {
    const start = new LocalDate(2012, 4, 15);
    const expected = new LocalDate(2012, 8, 15);
    assertNodaEqual(start.PlusMonths(4), expected);
  },

  PlusMonth_ChangingYear() {
    const start = new LocalDate(2012, 10, 15);
    const expected = new LocalDate(2013, 2, 15);
    assertNodaEqual(start.PlusMonths(4), expected);
  },

  PlusMonth_WithTruncation() {
    const start = new LocalDate(2011, 1, 30);
    const expected = new LocalDate(2011, 2, 28);
    assertNodaEqual(start.PlusMonths(1), expected);
  },

  PlusMonths_OutOfRange(year: number, month: number, calendarOrdinal: number, months: number) {
    const calendar = CalendarSystem.ForOrdinal(calendarOrdinal as CalendarOrdinal);
    const date = new LocalDate(year, month, 1, calendar);
    // Arguably ArgumentOutOfRangeException would be better in this specific
    // case, but there may be other cases ending up at the same check,
    // where OverflowException is better. The existing code "tried" to throw
    // OverflowException, so in cases where we weren't already failing for
    // whatever reason, we're keeping the original behavior.
    assertThrows("OverflowException", () => date.PlusMonths(months));
  },

  PlusDays_SameMonth() {
    const start = new LocalDate(2011, 1, 15);
    let expected = new LocalDate(2011, 1, 23);
    assertNodaEqual(start.PlusDays(8), expected);

    expected = new LocalDate(2011, 1, 7);
    assertNodaEqual(start.PlusDays(-8), expected);
  },

  PlusDays_MonthBoundary() {
    const start = new LocalDate(2011, 1, 26);
    const expected = new LocalDate(2011, 2, 3);
    assertNodaEqual(start.PlusDays(8), expected);

    // Round-trip back across the boundary
    assertNodaEqual(start.PlusDays(8).PlusDays(-8), start);
  },

  PlusDays_YearBoundary() {
    const start = new LocalDate(2011, 12, 26);
    const expected = new LocalDate(2012, 1, 3);
    assertNodaEqual(start.PlusDays(8), expected);

    // Round-trip back across the boundary
    assertNodaEqual(start.PlusDays(8).PlusDays(-8), start);
  },

  PlusDays_EndOfFebruary_InLeapYear() {
    const start = new LocalDate(2012, 2, 26);
    const expected = new LocalDate(2012, 3, 5);
    assertNodaEqual(start.PlusDays(8), expected);
    // Round-trip back across the boundary
    assertNodaEqual(start.PlusDays(8).PlusDays(-8), start);
  },

  PlusDays_EndOfFebruary_NotInLeapYear() {
    const start = new LocalDate(2011, 2, 26);
    const expected = new LocalDate(2011, 3, 6);
    assertNodaEqual(start.PlusDays(8), expected);

    // Round-trip back across the boundary
    assertNodaEqual(start.PlusDays(8).PlusDays(-8), start);
  },

  PlusDays_LargeValue() {
    const start = new LocalDate(2013, 2, 26);
    const expected = new LocalDate(2015, 2, 26);
    assertNodaEqual(start.PlusDays(365 * 2), expected);
  },

  PlusWeeks_Simple() {
    const start = new LocalDate(2011, 4, 2);
    const expectedForward = new LocalDate(2011, 4, 23);
    const expectedBackward = new LocalDate(2011, 3, 12);
    assertNodaEqual(start.PlusWeeks(3), expectedForward);
    assertNodaEqual(start.PlusWeeks(-3), expectedBackward);
  },

  PlusDays_OutOfRange(year: number, month: number, day: number, days: number) {
    const start = new LocalDate(year, month, day);
    TestHelper.assertOverflow(() => start.PlusDays(days));
  },

  // Each test case gives a day-of-month in November 2011 and a target "next day of week";
  // the result is the next day-of-month in November 2011 with that target day.
  // The tests are picked somewhat arbitrarily...
  Next(dayOfMonth: number, targetDayOfWeek: IsoDayOfWeek): number {
    const start = new LocalDate(2011, 11, dayOfMonth);
    const target = start.Next(targetDayOfWeek);
    assertNodaEqual(target.Year, 2011);
    assertNodaEqual(target.Month, 11);
    return target.Day;
  },

  Next_InvalidArgument(targetDayOfWeek: IsoDayOfWeek) {
    const start = new LocalDate(2011, 1, 1);
    assertThrows("ArgumentOutOfRangeException", () => start.Next(targetDayOfWeek));
  },

  // Each test case gives a day-of-month in November 2011 and a target "next day of week";
  // the result is the next day-of-month in November 2011 with that target day.
  Previous(dayOfMonth: number, targetDayOfWeek: IsoDayOfWeek): number {
    const start = new LocalDate(2011, 11, dayOfMonth);
    const target = start.Previous(targetDayOfWeek);
    assertNodaEqual(target.Year, 2011);
    assertNodaEqual(target.Month, 11);
    return target.Day;
  },

  Previous_InvalidArgument(targetDayOfWeek: IsoDayOfWeek) {
    const start = new LocalDate(2011, 1, 1);
    assertThrows("ArgumentOutOfRangeException", () => start.Previous(targetDayOfWeek));
  },

  // No tests for non-ISO-day-of-week calendars as we don't have any yet.

  With() {
    const start = new LocalDate(2014, 6, 27);
    const expected = new LocalDate(2014, 6, 30);
    assertNodaEqual(start.With(DateAdjusters.EndOfMonth), expected);
  },
  // #endregion
}, {
  skip: {
    // LocalDateTest.cs
    DefaultConstructor: "C# default(LocalDate) struct construction; LocalDate has no parameterless constructor in noda-js",
    XmlSerialization_Iso: "XML serialization isn't ported",
    XmlSerialization_NonIso: "XML serialization isn't ported",
    XmlSerialization_Invalid: "XML serialization isn't ported",
    // LocalDateTest.Conversion.cs
    ToDateTimeUnspecified: "BCL interop (DateTime) isn't ported",
    ToDateTimeUnspecified_JulianCalendar: "BCL interop (DateTime) isn't ported",
    FromDateTime: "BCL interop (DateTime) isn't ported",
    FromDateTime_WithCalendar: "BCL interop (DateTime) isn't ported",
    ToDateOnly_Gregorian: "BCL interop (DateOnly) isn't ported",
    ToDateOnly_NonGregorian: "BCL interop (DateOnly) isn't ported",
    ToDateOnly_OutOfRange: "BCL interop (DateOnly) isn't ported",
    FromDateOnly: "BCL interop (DateOnly) isn't ported",
  },
});
