// Ported from NodaTime 6e024dde: src/NodaTime.Test/Calendars/PersianCalendarSystemTest.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { CalendarSystem, LocalDate } from "../../../src/noda-js/internal.ts";
import { PersianSimple, PersianArithmetic, PersianAstronomical } from "../../../src/noda-js/entries/calendars/persian.ts";
import { assertNodaEqual, assertThrows } from "../../helpers/assertions.ts";
import { port } from "../../helpers/scenarios.ts";
import { fixture } from "../../scenarios/Calendars/PersianCalendarSystemTest.generated.ts";

/**
 * Tests for PersianYearMonthDayCalculator via the Persian CalendarSystem.
 */
port(fixture, {
  /**
   * Use the examples in Calendrical Calculations for where the arithmetic calendar differs
   * from the astronomical one.
   */
  ArithmeticExamples(persianYear: number, gregorianYear: number, gregorianDayOfMarch: number) {
    const persian = new LocalDate(persianYear, 1, 1, PersianArithmetic);
    const gregorian = persian.WithCalendar(CalendarSystem.Gregorian);
    assertNodaEqual(gregorian.Year, gregorianYear);
    assertNodaEqual(gregorian.Month, 3);
    assertNodaEqual(gregorian.Day, gregorianDayOfMarch);
  },

  /**
   * The arithmetic calendar repeats every 2820 years, including the years before 474.
   * A floored modulo puts year 24 in the same position in the cycle as year 2844.
   */
  ArithmeticLeapYearsRepeatEvery2820Years() {
    const calendar = PersianArithmetic;
    for (let year = calendar.MinYear; year + 2820 <= calendar.MaxYear; year++) {
      assertNodaEqual(calendar.IsLeapYear(year), calendar.IsLeapYear(year + 2820), `Year ${year}`);
    }
  },

  /**
   * Leap years and new year's days before 474 use the same cycle as later years.
   */
  ArithmeticYearsBefore474(persianYear: number, leap: boolean, gregorianYear: number, gregorianDayOfMarch: number) {
    assertNodaEqual(PersianArithmetic.IsLeapYear(persianYear), leap);
    const gregorian = new LocalDate(persianYear, 1, 1, PersianArithmetic).WithCalendar(CalendarSystem.Gregorian);
    assertNodaEqual(gregorian, new LocalDate(gregorianYear, 3, gregorianDayOfMarch, CalendarSystem.Gregorian));
  },

  ArithmeticYearEndBefore474() {
    const calendar = PersianArithmetic;
    const lastDayOfYear24 = new LocalDate(24, 12, 29, calendar);
    assertNodaEqual(lastDayOfYear24.PlusDays(1), new LocalDate(25, 1, 1, calendar));
    assertThrows("ArgumentOutOfRangeException", () => new LocalDate(24, 12, 30, calendar));
    const leapDayOfYear25 = new LocalDate(25, 12, 30, calendar);
    assertNodaEqual(leapDayOfYear25.PlusDays(1), new LocalDate(26, 1, 1, calendar));
  },

  // Not ported: GenerateData (#if DEBUG, explicit; generated the base64 leap-year data from the BCL's PersianCalendar)
}, {
  skip: {
    BclThroughHistory: "uses the BCL's PersianCalendar as the oracle; test/golden/calendars.test.ts checks every year " +
      "of every calendar against NodaTime's own data",
  },
});
