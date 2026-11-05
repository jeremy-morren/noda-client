// Ported from NodaTime 3.3.7: src/NodaTime.Test/Calendars/HebrewCalendarSystemTest.cs
// Copyright 2014 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import {
  CalendarSystem,
  HebrewMonthNumbering,
  HebrewScripturalCalculator,
  HebrewYearMonthDayCalculator,
  LocalDate,
  LocalDatePattern,
  LocalDateTime,
  Period,
  PeriodUnits,
  YearMonthDay,
} from "../../../src/noda-js/internal.ts";
import { HebrewCivil, HebrewScriptural, GetHebrewCalendar } from "../../../src/noda-js/entries/calendars/hebrew.ts";
import { assertNodaEqual, assertThrows } from "../../helpers/assertions.ts";
import { port } from "../../helpers/scenarios.ts";
import { TestHelper } from "../../helpers/TestHelper.ts";
import { fixture } from "../../scenarios/Calendars/HebrewCalendarSystemTest.generated.ts";

const BclReason = "uses the BCL's System.Globalization.HebrewCalendar as the oracle; " +
  "test/golden/calendars.test.ts checks every year and month of both Hebrew calendars against NodaTime's own data instead";

/**
 * Tests for HebrewYearMonthDayCalculator via the Hebrew CalendarSystem.
 * See https://blog.nodatime.org/2014/06/hebrew-calendar-cheat-sheet.html
 * for sample year information.
 */
port(fixture, {
  // Test cases are in scriptural month numbering, but we check both. This is
  // mostly testing the behaviour of SetYear, via LocalDate.PlusYears.
  SetYear(startText: string, years: number, expectedEndText: string) {
    const civil = HebrewCivil;
    const scriptural = HebrewScriptural;
    const pattern = LocalDatePattern.CreateWithInvariantCulture("uuuu-MM-dd")
      .WithTemplateValue(new LocalDate(5774, 1, 1, scriptural)); // Sample value in 2014 ISO

    const start = pattern.Parse(startText).Value;
    const expectedEnd = pattern.Parse(expectedEndText).Value;
    assertNodaEqual(start.PlusYears(years), expectedEnd);

    // Check civil as well... the date should be the same (year, month, day) even though
    // the numbering is different.
    assertNodaEqual(start.WithCalendar(civil).PlusYears(years), expectedEnd.WithCalendar(civil));
  },

  AddMonths_MonthsBetween(startText: string, months: number, expectedEndText: string) {
    const civil = HebrewCivil;
    const pattern = LocalDatePattern.CreateWithInvariantCulture("uuuu-MM-dd")
      .WithTemplateValue(new LocalDate(5774, 1, 1, civil)); // Sample value in 2014 ISO

    const start = pattern.Parse(startText).Value;
    const expectedEnd = pattern.Parse(expectedEndText).Value;
    assertNodaEqual(start.PlusMonths(months), expectedEnd);
  },

  MonthsBetween(startText: string, expectedMonths: number, endText: string) {
    const civil = HebrewCivil;
    const pattern = LocalDatePattern.CreateWithInvariantCulture("uuuu-MM-dd")
      .WithTemplateValue(new LocalDate(5774, 1, 1, civil)); // Sample value in 2014 ISO

    const start = pattern.Parse(startText).Value;
    const end = pattern.Parse(endText).Value;
    assertNodaEqual(Period.Between(start, end, PeriodUnits.Months).Months, expectedMonths);
  },

  MonthsBetween_TimeOfDay() {
    const civil = HebrewCivil;
    const start = new LocalDateTime(5774, 5, 10, 15, 0, civil); // 3pm
    const end = new LocalDateTime(5774, 7, 10, 5, 0, civil); // 5am
    // Would be 2, but the start time is later than the end time.
    assertNodaEqual(Period.Between(start, end, PeriodUnits.Months).Months, 1);
  },

  DayOfYearAndReverse(numbering: HebrewMonthNumbering) {
    const calculator = HebrewYearMonthDayCalculator.NewMonthNumbering(numbering);
    for (let year = 5400; year < 5419; year++) {
      const daysInYear = calculator.GetDaysInYear(year);
      for (let dayOfYear = 1; dayOfYear <= daysInYear; dayOfYear++) {
        const ymd = calculator.GetYearMonthDay(year, dayOfYear);
        assertNodaEqual(calculator.GetDayOfYear(ymd), dayOfYear);
      }
    }
  },

  GetDaysSinceEpoch() {
    const calculator = HebrewYearMonthDayCalculator.NewMonthNumbering(HebrewMonthNumbering.Scriptural);
    const unixEpoch = YearMonthDay.NewYearMonthDay(5730, 10, 23);
    assertNodaEqual(calculator.GetDaysSinceEpoch(unixEpoch), 0);
  },

  DaysAtStartOfYear() {
    // These are somewhat random values used when diagnosing an issue.
    const calculator = HebrewYearMonthDayCalculator.NewMonthNumbering(HebrewMonthNumbering.Scriptural);
    assertNodaEqual(calculator.GetStartOfYearInDays(5730), -110);
    assertNodaEqual(calculator.GetStartOfYearInDays(5731), 273);
    assertNodaEqual(calculator.GetStartOfYearInDays(5345), -140735);
    assertNodaEqual(calculator.GetYearMonthDay(-140529), YearMonthDay.NewYearMonthDay(5345, 1, 1));
  },

  GetDaysInYearCrossCheck() {
    const calculator = HebrewYearMonthDayCalculator.NewMonthNumbering(HebrewMonthNumbering.Civil);
    for (let year = calculator.MinYear; year <= calculator.MaxYear; year++) {
      let sum = 0;
      for (let month = 1; month <= calculator.GetMonthsInYear(year); month++) {
        sum += calculator.GetDaysInMonth(year, month);
      }
      assertNodaEqual(calculator.GetDaysInYear(year), sum, `Days in ${year}`);
    }
  },

  ScripturalCompare(earlier: string, later: string) {
    const pattern = LocalDatePattern.Iso.WithCalendar(HebrewScriptural);
    const earlierDate = pattern.Parse(earlier).Value;
    const laterDate = pattern.Parse(later).Value;
    TestHelper.testCompareToStruct(earlierDate, earlierDate, laterDate);
  },

  ScripturalGetDaysFromStartOfYearToStartOfMonth_InvalidForCoverage() {
    assertThrows("ArgumentOutOfRangeException", () => HebrewScripturalCalculator.GetDaysFromStartOfYearToStartOfMonth(5502, 0));
  },

  PlusMonths_Overflow(monthNumbering: HebrewMonthNumbering) {
    const calendar = GetHebrewCalendar(monthNumbering);
    // TODO: It would be nice to have an easy way of getting the smallest/largest LocalDate for
    // a calendar. Or possibly FromDayOfYear as well... instead, we'll just add/subtract 8 months instead
    const earlyDate = new LocalDate(calendar.MinYear, 1, 1, calendar);
    const lateDate = new LocalDate(calendar.MaxYear, 12, 1, calendar);

    assertThrows("OverflowException", () => earlyDate.PlusMonths(-7));
    assertThrows("OverflowException", () => lateDate.PlusMonths(7));
  },
}, {
  skip: {
    IsLeapYear: BclReason,
    BclThroughHistory_Civil: BclReason,
    BclThroughHistory_Scriptural: BclReason,
  },
});
