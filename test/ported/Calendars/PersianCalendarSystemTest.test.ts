// Ported from NodaTime 3.3.7: src/NodaTime.Test/Calendars/PersianCalendarSystemTest.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { CalendarSystem, LocalDate } from "../../../src/noda-js/internal.ts";
import { PersianSimple, PersianArithmetic, PersianAstronomical } from "../../../src/noda-js/entries/calendars/persian.ts";
import { assertNodaEqual } from "../../helpers/assertions.ts";
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

  // Not ported: GenerateData (#if DEBUG, explicit; generated the base64 leap-year data from the BCL's PersianCalendar)
}, {
  skip: {
    BclThroughHistory: "uses the BCL's PersianCalendar as the oracle; test/golden/calendars.test.ts checks every year " +
      "of every calendar against NodaTime's own data",
  },
});
