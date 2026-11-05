// Ported from NodaTime 3.3.0: src/NodaTime.Test/YearMonthDayCalendarTest.cs
// Copyright 2014 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda-js: the internal constructor YearMonthDayCalendar(int year, int month, int day, CalendarOrdinal) is
// YearMonthDayCalendar.newYearMonthDayCalendarOrdinal. Calendar ordinals are just numbers here, so the non-ISO
// ordinals work even though their calendar systems aren't ported. C# == / != are equals().

import { CalendarOrdinal, YearMonthDayCalendar } from "../../src/noda-js/internal.ts";
import { assertNodaEqual } from "../helpers/assertions.ts";
import { port } from "../helpers/scenarios.ts";
import { TestHelper } from "../helpers/TestHelper.ts";
import { fixture } from "../scenarios/YearMonthDayCalendarTest.generated.ts";

/** C# `new YearMonthDayCalendar(year, month, day, calendarOrdinal)`. */
function newYmdc(year: number, month: number, day: number, calendarOrdinal: CalendarOrdinal): YearMonthDayCalendar {
  return YearMonthDayCalendar.NewYearMonthDayCalendarOrdinal(year, month, day, calendarOrdinal);
}

port(fixture, {
  AllYears() {
    // Range of years we actually care about. We support more, but that's okay.
    for (let year = -9999; year <= 9999; year++) {
      const ymdc = newYmdc(year, 5, 20, 0);
      assertNodaEqual(ymdc.Year, year);
      assertNodaEqual(ymdc.Month, 5);
      assertNodaEqual(ymdc.Day, 20);
      assertNodaEqual(ymdc.CalendarOrdinal, CalendarOrdinal.Iso);
    }
  },

  AllMonths() {
    // We'll never actually need 32 months, but we support that many...
    for (let month = 1; month <= 32; month++) {
      const ymdc = newYmdc(-123, month, 20, CalendarOrdinal.HebrewCivil);
      assertNodaEqual(ymdc.Year, -123);
      assertNodaEqual(ymdc.Month, month);
      assertNodaEqual(ymdc.Day, 20);
      assertNodaEqual(ymdc.CalendarOrdinal, CalendarOrdinal.HebrewCivil);
    }
  },

  AllDays() {
    // We'll never actually need 64 days, but we support that many...
    for (let day = 1; day <= 64; day++) {
      const ymdc = newYmdc(-123, 12, day, CalendarOrdinal.IslamicAstronomicalBase15);
      assertNodaEqual(ymdc.Year, -123);
      assertNodaEqual(ymdc.Month, 12);
      assertNodaEqual(ymdc.Day, day);
      assertNodaEqual(ymdc.CalendarOrdinal, CalendarOrdinal.IslamicAstronomicalBase15);
    }
  },

  AllCalendars() {
    for (let ordinal = 0; ordinal < 64; ordinal++) {
      const calendar = ordinal as CalendarOrdinal;
      const ymdc = newYmdc(-123, 30, 64, calendar);
      assertNodaEqual(ymdc.Year, -123);
      assertNodaEqual(ymdc.Month, 30);
      assertNodaEqual(ymdc.Day, 64);
      assertNodaEqual(ymdc.CalendarOrdinal, calendar);
    }
  },

  Equality() {
    const original = newYmdc(1000, 12, 20, CalendarOrdinal.Coptic);
    TestHelper.testEqualsStruct(original, newYmdc(1000, 12, 20, CalendarOrdinal.Coptic),
      newYmdc(original.Year + 1, original.Month, original.Day, original.CalendarOrdinal),
      newYmdc(original.Year, original.Month + 1, original.Day, original.CalendarOrdinal),
      newYmdc(original.Year, original.Month, original.Day + 1, original.CalendarOrdinal),
      newYmdc(original.Year, original.Month, original.Day, CalendarOrdinal.Gregorian));
    // Just test the first one again with operators.
    // noda-js: C# passes the struct `original` twice (as two copies); TestHelper needs two distinct objects.
    TestHelper.testOperatorEquality(original, newYmdc(1000, 12, 20, CalendarOrdinal.Coptic),
      newYmdc(original.Year + 1, original.Month, original.Day, original.CalendarOrdinal));
  },

  Parse(text: string, year: number, month: number, day: number, calendar: number) {
    const value = YearMonthDayCalendar.Parse(text);
    assertNodaEqual(value.Year, year);
    assertNodaEqual(value.Month, month);
    assertNodaEqual(value.Day, day);
    assertNodaEqual(value.CalendarOrdinal, calendar as CalendarOrdinal);
    assertNodaEqual(value.toString(), text);
  },
});
