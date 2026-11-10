// Ported from NodaTime 6e024dde: src/NodaTime.Test/Calendars/SimpleWeekYearRuleTest.cs
// Copyright 2016 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda-js: FromCalendarWeekRule takes the BCL enums' numeric values.

import { describe, expect, it } from "vitest";
import {
  CalendarSystem,
  IsoDayOfWeek,
  LocalDate,
  WeekYearRuleExtensions,
  WeekYearRules,
  type IWeekYearRule,
} from "../../../src/noda-js/internal.ts";
// noda-js: registers every calendar, as in NodaTime.
import "../../../src/noda-js/entries/calendars/all.ts";
import { Badi } from "../../../src/noda-js/entries/calendars/badi.ts";
import { HebrewCivil, HebrewScriptural } from "../../../src/noda-js/entries/calendars/hebrew.ts";
import { assertNodaEqual, assertThrows } from "../../helpers/assertions.ts";
import { port } from "../../helpers/scenarios.ts";
import { fixture } from "../../scenarios/Calendars/SimpleWeekYearRuleTest.generated.ts";

const { Monday, Tuesday, Thursday, Friday, Saturday } = IsoDayOfWeek;

// C# Enum.GetValues(typeof(DayOfWeek)) and Enum.GetValues(typeof(CalendarWeekRule)).
const BclDaysOfWeek: readonly (readonly [string, number])[] =
  [["Sunday", 0], ["Monday", 1], ["Tuesday", 2], ["Wednesday", 3], ["Thursday", 4], ["Friday", 5], ["Saturday", 6]];
const CalendarWeekRules: readonly (readonly [string, number])[] = [["FirstDay", 0], ["FirstFullWeek", 1], ["FirstFourDayWeek", 2]];

/** C# extension method rule.GetLocalDate(weekYear, weekOfWeekYear, dayOfWeek) (ISO calendar). */
function getLocalDate(rule: IWeekYearRule, weekYear: number, weekOfWeekYear: number, dayOfWeek: IsoDayOfWeek): LocalDate {
  return WeekYearRuleExtensions.GetLocalDate(rule, weekYear, weekOfWeekYear, dayOfWeek);
}

/** C# extension method rule.GetWeeksInWeekYear(weekYear) (ISO calendar). */
function getWeeksInWeekYear(rule: IWeekYearRule, weekYear: number): number {
  return WeekYearRuleExtensions.GetWeeksInWeekYear(rule, weekYear);
}

const bodies = {
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

  /**
   * As {@link RoundtripFirstDay_Iso7} and {@link RoundtripLastDay_Iso1}, for every calendar and rule:
   * the first and last days of a calendar may be in the week-year before its first year or after its last year, which
   * {@link IWeekYearRule.GetLocalDate} documents as valid.
   *
   * noda-js: the scenarios can't encode the IWeekYearRule argument: see the describe block at the end.
   */
  RoundtripFirstAndLastDays_AllCalendars(calendarId: string, rule: IWeekYearRule) {
    const calendar = CalendarSystem.ForId(calendarId);
    const firstDay = new LocalDate(calendar.MinYear, 1, 1, calendar);
    const lastMonth = calendar.GetMonthsInYear(calendar.MaxYear);
    const lastDay = new LocalDate(calendar.MaxYear, lastMonth, calendar.GetDaysInMonth(calendar.MaxYear, lastMonth), calendar);

    for (const date of [firstDay, lastDay]) {
      const weekYear = rule.GetWeekYear(date);
      const weekOfWeekYear = rule.GetWeekOfWeekYear(date);
      const message = `${date.Year}-${date.Month}-${date.Day}`;
      expect(weekOfWeekYear, message).toBeGreaterThanOrEqual(1);
      expect(weekOfWeekYear, message).toBeLessThanOrEqual(rule.GetWeeksInWeekYear(weekYear, calendar));
      assertNodaEqual(rule.GetLocalDate(weekYear, weekOfWeekYear, date.DayOfWeek, calendar), date, message);
    }
  },

  FirstDayInWeekYearBeforeFirstYear_Badi() {
    // 1 Bahá 1 BE is Thursday March 21st 1844. With weeks starting on Monday and at least 5 days in the first
    // week, its week (Monday March 18th to Sunday March 24th 1844) has only 4 days in year 1, so it's the last
    // week of week-year 0. Year 0 starts on Tuesday March 21st 1843, so week 1 of week-year 0 starts on Monday
    // March 20th 1843, and the week of 1 Bahá 1 is week 53.
    const rule = WeekYearRules.ForMinDaysInFirstWeek(5, Monday);
    const date = new LocalDate(1, 1, 1, Badi);
    assertNodaEqual(date.WithCalendar(CalendarSystem.Iso), new LocalDate(1844, 3, 21));
    assertNodaEqual(rule.GetWeekYear(date), 0);
    assertNodaEqual(rule.GetWeekOfWeekYear(date), 53);
    assertNodaEqual(rule.GetWeeksInWeekYear(0, Badi), 53);
    assertNodaEqual(rule.GetLocalDate(0, 53, Thursday, Badi), date);
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
};

port(fixture, bodies, {
  skip: {
    BclEquivalence: "uses the BCL's System.Globalization.Calendar.GetWeekOfYear as the oracle",
    "GetWeeksInWeekYear(Calendar, CalendarWeekRule, DayOfWeek)": "uses the BCL's System.Globalization.Calendar.GetWeekOfYear as the oracle",
  },
});

function* CalendarBoundaryRules(): Iterable<[string, string, IWeekYearRule]> {
  const rules: [string, IWeekYearRule][] = [];
  for (let minDays = 1; minDays <= 7; minDays++) {
    for (let firstDayOfWeek = IsoDayOfWeek.Monday; firstDayOfWeek <= IsoDayOfWeek.Sunday; firstDayOfWeek++) {
      rules.push([
        `ForMinDaysInFirstWeek(${minDays}, ${IsoDayOfWeek[firstDayOfWeek]})`,
        WeekYearRules.ForMinDaysInFirstWeek(minDays, firstDayOfWeek)]);
    }
  }
  for (const [calendarWeekRuleName, calendarWeekRule] of CalendarWeekRules) {
    for (const [bclDayOfWeekName, bclDayOfWeek] of BclDaysOfWeek) {
      rules.push([
        `FromCalendarWeekRule(${calendarWeekRuleName}, ${bclDayOfWeekName})`,
        WeekYearRules.FromCalendarWeekRule(calendarWeekRule, bclDayOfWeek)]);
    }
  }

  for (const calendarId of CalendarSystem.Ids) {
    for (const [name, rule] of rules) {
      yield [calendarId, `RoundtripFirstAndLastDays_AllCalendars(${calendarId}, ${name})`, rule];
    }
  }
}

// noda-js: RoundtripFirstAndLastDays_AllCalendars' CalendarBoundaryRules cases.
describe("NodaTime.Test.Calendars.SimpleWeekYearRuleTest CalendarBoundaryRules", () => {
  for (const [calendarId, name, rule] of CalendarBoundaryRules()) {
    it(name, () => bodies.RoundtripFirstAndLastDays_AllCalendars(calendarId, rule));
  }
});
