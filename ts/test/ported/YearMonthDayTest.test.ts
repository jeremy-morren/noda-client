// Ported from NodaTime 6e024dde: src/NodaTime.Test/YearMonthDayTest.cs
// Copyright 2014 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { CalendarOrdinal, CalendarSystem, YearMonthDay, YearMonthDayCalendar } from "../../src/noda-js/internal.ts";
import { assertNodaEqual } from "../helpers/assertions.ts";
import { port } from "../helpers/scenarios.ts";
import { TestHelper } from "../helpers/TestHelper.ts";
import { fixture } from "../scenarios/YearMonthDayTest.generated.ts";

port(fixture, {
  AllYears() {
    // Range of years we actually care about. We support more, but that's okay.
    for (let year = -9999; year <= 9999; year++) {
      const ymd = YearMonthDay.NewYearMonthDay(year, 5, 20);
      assertNodaEqual(ymd.Year, year);
      assertNodaEqual(ymd.Month, 5);
      assertNodaEqual(ymd.Day, 20);
    }
  },

  AllMonths() {
    // We'll never actually need 32 months, but we support that many...
    for (let month = 1; month < 32; month++) {
      const ymd = YearMonthDay.NewYearMonthDay(-123, month, 20);
      assertNodaEqual(ymd.Year, -123);
      assertNodaEqual(ymd.Month, month);
      assertNodaEqual(ymd.Day, 20);
    }
  },

  AllDays() {
    // We'll never actually need 64 days, but we support that many...
    for (let day = 1; day < 64; day++) {
      const ymd = YearMonthDay.NewYearMonthDay(-123, 30, day);
      assertNodaEqual(ymd.Year, -123);
      assertNodaEqual(ymd.Month, 30);
      assertNodaEqual(ymd.Day, day);
    }
  },

  Comparisons(smallerText: string, greaterText: string) {
    const smaller = YearMonthDay.Parse(smallerText);
    const greater = YearMonthDay.Parse(greaterText);
    // noda-js: TestHelper needs two distinct objects for the equal value.
    const equalToSmaller = YearMonthDay.Parse(smallerText);
    TestHelper.testCompareToStruct(smaller, equalToSmaller, greater);
    TestHelper.testOperatorComparisonEquality(smaller, equalToSmaller, greater);
    TestHelper.testEqualsStruct(smaller, equalToSmaller, greater);
  },

  YearMonthDayToString() {
    const ymd = YearMonthDay.NewYearMonthDay(2017, 8, 25);
    assertNodaEqual(ymd.toString(), "2017-08-25");
  },

  WithCalendar() {
    const ymd = YearMonthDay.NewYearMonthDay(2017, 8, 25);
    const ymdc = YearMonthDayCalendar.NewYearMonthDayCalendarOrdinal(2017, 8, 25, CalendarOrdinal.Julian);
    assertNodaEqual(ymd.WithCalendar(CalendarSystem.Julian), ymdc);
  },

  WithCalendar_Null() {
    const ymd = YearMonthDay.NewYearMonthDay(2017, 8, 25);
    const ymdc = YearMonthDayCalendar.NewYearMonthDayCalendarOrdinal(2017, 8, 25, CalendarOrdinal.Iso);
    assertNodaEqual(ymd.WithCalendar(null), ymdc);
  },
});
