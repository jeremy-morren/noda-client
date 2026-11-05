// Ported from NodaTime 3.3.7: src/NodaTime.Test/Calendars/SimpleWeekYearRuleTest.cs
// Copyright 2016 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda-js: the IWeekYearRule extension methods without a calendar (GetLocalDate, GetWeeksInWeekYear) are
// WeekYearRuleExtensions.GetLocalDate / GetWeeksInWeekYear. WeekYearRules.FromCalendarWeekRule takes the BCL
// enums (CalendarWeekRule, DayOfWeek) as their numeric values, which is how the scenarios supply them.

import {
  CalendarSystem,
  IsoDayOfWeek,
  LocalDate,
  WeekYearRuleExtensions,
  WeekYearRules,
  type IWeekYearRule,
} from "../../../src/noda-js/internal.ts";
import { HebrewCivil, HebrewScriptural } from "../../../src/noda-js/entries/calendars/hebrew.ts";
import { assertNodaEqual, assertThrows } from "../../helpers/assertions.ts";
import { port } from "../../helpers/scenarios.ts";
import { fixture } from "../../scenarios/Calendars/SimpleWeekYearRuleTest.generated.ts";

const { Monday, Tuesday, Friday, Saturday } = IsoDayOfWeek;

/** C# extension method rule.GetLocalDate(weekYear, weekOfWeekYear, dayOfWeek) (ISO calendar). */
function getLocalDate(rule: IWeekYearRule, weekYear: number, weekOfWeekYear: number, dayOfWeek: IsoDayOfWeek): LocalDate {
  return WeekYearRuleExtensions.GetLocalDate(rule, weekYear, weekOfWeekYear, dayOfWeek);
}

/** C# extension method rule.GetWeeksInWeekYear(weekYear) (ISO calendar). */
function getWeeksInWeekYear(rule: IWeekYearRule, weekYear: number): number {
  return WeekYearRuleExtensions.GetWeeksInWeekYear(rule, weekYear);
}

port(fixture, {
  RoundtripFirstDay_Iso7() {
    // In the Gregorian calendar with a minimum of 7 days in the first
    // week, Tuesday January 1st -9998 is in week year -9999. We should be able to
    // round-trip.
    const rule = WeekYearRules.ForMinDaysInFirstWeek(7);
    const date = new LocalDate(-9998, 1, 1);
    assertNodaEqual(getLocalDate(rule,
      rule.GetWeekYear(date),
      rule.GetWeekOfWeekYear(date),
      date.DayOfWeek), date);
  },

  RoundtripLastDay_Iso1() {
    // In the Gregorian calendar with a minimum of 1 day in the first
    // week, Friday December 31st 9999 is in week year 10000. We should be able to
    // round-trip.
    const rule = WeekYearRules.ForMinDaysInFirstWeek(1);
    const date = new LocalDate(9999, 12, 31);
    assertNodaEqual(getLocalDate(rule,
      rule.GetWeekYear(date),
      rule.GetWeekOfWeekYear(date),
      date.DayOfWeek), date);
  },

  OutOfRange_ValidWeekYearAndWeek_TooEarly() {
    // Gregorian 4: Week year 1 starts on Monday December 31st -9999,
    // and is therefore out of range, even though the week-year
    // and week-of-week-year are valid.
    assertThrows("ArgumentOutOfRangeException",
      () => getLocalDate(WeekYearRules.Iso, -9998, 1, Monday));

    // Sanity check: no exception for January 1st
    getLocalDate(WeekYearRules.Iso, -9998, 1, Tuesday);
  },

  OutOfRange_ValidWeekYearAndWeek_TooLate() {
    // Gregorian 4: December 31st 9999 is a Friday, so the Saturday of the
    // same week is therefore out of range, even though the week-year
    // and week-of-week-year are valid.
    assertThrows("ArgumentOutOfRangeException",
      () => getLocalDate(WeekYearRules.Iso, 9999, 52, Saturday));

    // Sanity check: no exception for December 31st
    getLocalDate(WeekYearRules.Iso, 9999, 52, Friday);
  },

  // Tests ported from IsoCalendarSystemTest and LocalDateTest.Construction
  WeekYearDifferentToYear(year: number, month: number, day: number, weekYear: number, weekOfWeekYear: number, dayOfWeek: IsoDayOfWeek) {
    const date = new LocalDate(year, month, day);
    assertNodaEqual(WeekYearRules.Iso.GetWeekYear(date), weekYear);
    assertNodaEqual(WeekYearRules.Iso.GetWeekOfWeekYear(date), weekOfWeekYear);
    assertNodaEqual(date.DayOfWeek, dayOfWeek);
    assertNodaEqual(getLocalDate(WeekYearRules.Iso, weekYear, weekOfWeekYear, dayOfWeek), date);
  },

  // Ported from CalendarSystemTest.Validation
  "GetWeeksInWeekYear(int, int)"(weekYear: number, expectedResult: number) {
    assertNodaEqual(getWeeksInWeekYear(WeekYearRules.Iso, weekYear), expectedResult);
  },

  // Ported from LocalDateTest.BasicProperties
  // See https://stackoverflow.com/questions/8010125
  WeekOfWeekYear_ComparisonWithOracle(year: number, month: number, day: number, weekOfWeekYear: number) {
    const date = new LocalDate(year, month, day);
    assertNodaEqual(WeekYearRules.Iso.GetWeekOfWeekYear(date), weekOfWeekYear);
  },

  Gregorian(year: number, firstDayOfYear: IsoDayOfWeek, maxMinDaysInFirstWeekForSameWeekYear: number) {
    const startOfCalendarYear = new LocalDate(year, 1, 1);
    assertNodaEqual(startOfCalendarYear.DayOfWeek, firstDayOfYear);

    // Rules which put the first day of the calendar year into the same week year
    for (let i = 1; i <= maxMinDaysInFirstWeekForSameWeekYear; i++) {
      const rule = WeekYearRules.ForMinDaysInFirstWeek(i);
      assertNodaEqual(rule.GetWeekYear(startOfCalendarYear), year);
      assertNodaEqual(rule.GetWeekOfWeekYear(startOfCalendarYear), 1);
    }
    // Rules which put the first day of the calendar year into the previous week year
    for (let i = maxMinDaysInFirstWeekForSameWeekYear + 1; i <= 7; i++) {
      const rule = WeekYearRules.ForMinDaysInFirstWeek(i);
      assertNodaEqual(rule.GetWeekYear(startOfCalendarYear), year - 1);
      assertNodaEqual(rule.GetWeekOfWeekYear(startOfCalendarYear), getWeeksInWeekYear(rule, year - 1));
    }
  },

  // Test cases from https://blogs.msdn.microsoft.com/shawnste/2006/01/24/iso-8601-week-of-year-format-in-microsoft-net/
  // which distinguish our ISO option from the BCL. When we implement the BCL equivalents, we should have similar
  // tests there...
  Iso(year: number, month: number, day: number, weekYear: number, weekOfWeekYear: number, dayOfWeek: IsoDayOfWeek) {
    const viaCalendar = new LocalDate(year, month, day);
    const rule = WeekYearRules.Iso;
    assertNodaEqual(rule.GetWeekYear(viaCalendar), weekYear);
    assertNodaEqual(rule.GetWeekOfWeekYear(viaCalendar), weekOfWeekYear);
    assertNodaEqual(viaCalendar.DayOfWeek, dayOfWeek);
    const viaRule = getLocalDate(rule, weekYear, weekOfWeekYear, dayOfWeek);
    assertNodaEqual(viaRule, viaCalendar);
  },

  HebrewCalendar(year: number, expectedFirstDay: IsoDayOfWeek,
    isoYear: number, isoMonth: number, isoDay: number, // Mostly for documentation
    expectedWeeks: number, expectedWeekYearOfFirstDay: number, expectedWeekOfWeekYearOfFirstDay: number) {
    const civilDate = new LocalDate(year, 1, 1, HebrewCivil);
    const rule = WeekYearRules.Iso;
    assertNodaEqual(civilDate.DayOfWeek, expectedFirstDay);
    assertNodaEqual(new LocalDate(isoYear, isoMonth, isoDay), civilDate.WithCalendar(CalendarSystem.Iso));
    assertNodaEqual(rule.GetWeeksInWeekYear(year, HebrewCivil), expectedWeeks);
    assertNodaEqual(rule.GetWeekYear(civilDate), expectedWeekYearOfFirstDay);
    assertNodaEqual(rule.GetWeekOfWeekYear(civilDate), expectedWeekOfWeekYearOfFirstDay);
    assertNodaEqual(rule.GetLocalDate(expectedWeekYearOfFirstDay, expectedWeekOfWeekYearOfFirstDay, expectedFirstDay, HebrewCivil),
      civilDate);

    // The scriptural month numbering system should have the same week-year and week-of-week-year.
    const scripturalDate = civilDate.WithCalendar(HebrewScriptural);
    assertNodaEqual(rule.GetWeeksInWeekYear(year, HebrewScriptural), expectedWeeks);
    assertNodaEqual(rule.GetWeekYear(scripturalDate), expectedWeekYearOfFirstDay);
    assertNodaEqual(rule.GetWeekOfWeekYear(scripturalDate), expectedWeekOfWeekYearOfFirstDay);
    assertNodaEqual(rule.GetLocalDate(expectedWeekYearOfFirstDay, expectedWeekOfWeekYearOfFirstDay, expectedFirstDay, HebrewScriptural),
      scripturalDate);
  },

  // Jan 1st 2015 = Thursday
  // Jan 1st 2016 = Friday
  // Jan 1st 2017 = Sunday
  NonMondayFirstDayOfWeek(minDaysInFirstWeek: number, firstDayOfWeek: IsoDayOfWeek,
    weekYear: number, week: number, dayOfWeek: IsoDayOfWeek,
    expectedYear: number, expectedMonth: number, expectedDay: number) {
    const rule = WeekYearRules.ForMinDaysInFirstWeek(minDaysInFirstWeek, firstDayOfWeek);
    const actual = getLocalDate(rule, weekYear, week, dayOfWeek);
    const expected = new LocalDate(expectedYear, expectedMonth, expectedDay);
    assertNodaEqual(actual, expected);
    assertNodaEqual(rule.GetWeekYear(actual), weekYear);
    assertNodaEqual(rule.GetWeekOfWeekYear(actual), week);
  },

  // Tests for BCL rules...

  // Tests where we ask for an invalid combination of week-year/week/day-of-week due to a week being "short"
  // in BCL rules.
  // Jan 1st 2016 = Friday
  GetLocalDate_Invalid(bclRule: number, firstDayOfWeek: number, weekYear: number, week: number, dayOfWeek: IsoDayOfWeek) {
    const nodaRule = WeekYearRules.FromCalendarWeekRule(bclRule, firstDayOfWeek);
    assertThrows("ArgumentOutOfRangeException", () => getLocalDate(nodaRule, weekYear, week, dayOfWeek));
  },

  RoundtripFirstDayBcl(bclRule: number, firstDayOfWeek: number) {
    const rule = WeekYearRules.FromCalendarWeekRule(bclRule, firstDayOfWeek);
    const date = new LocalDate(-9998, 1, 1);
    assertNodaEqual(getLocalDate(rule,
      rule.GetWeekYear(date),
      rule.GetWeekOfWeekYear(date),
      date.DayOfWeek), date);
  },

  RoundtripLastDayBcl(bclRule: number, firstDayOfWeek: number) {
    const rule = WeekYearRules.FromCalendarWeekRule(bclRule, firstDayOfWeek);
    const date = new LocalDate(9999, 12, 31);
    assertNodaEqual(getLocalDate(rule,
      rule.GetWeekYear(date),
      rule.GetWeekOfWeekYear(date),
      date.DayOfWeek), date);
  },

  // TODO: Test the difference in ValidateWeekYear for 9999 between regular and non-regular rules.
}, {
  skip: {
    BclEquivalence: "uses the BCL's System.Globalization.Calendar.GetWeekOfYear as the oracle",
    "GetWeeksInWeekYear(Calendar, CalendarWeekRule, DayOfWeek)": "uses the BCL's System.Globalization.Calendar.GetWeekOfYear as the oracle",
  },
});
