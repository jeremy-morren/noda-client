// Ported from NodaTime 3.3.0: src/NodaTime.Test/DateAdjustersTest.cs
// Copyright 2014 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda-js: C# operator + on periods is Period.add.

import {
  ArgumentError,
  ArgumentNullError,
  ArgumentOutOfRangeError,
  CalendarSystem,
  DateAdjusters,
  IsoDayOfWeek,
  LocalDate,
  Period,
} from "../../src/noda-js/internal.ts";
import { assertNodaEqual, assertThrows } from "../helpers/assertions.ts";
import { port } from "../helpers/scenarios.ts";
import { fixture } from "../scenarios/DateAdjustersTest.generated.ts";

port(fixture, {
  StartOfMonth() {
    const start = new LocalDate(2014, 6, 27);
    const end = new LocalDate(2014, 6, 1);
    assertNodaEqual(DateAdjusters.StartOfMonth(start), end);
  },

  EndOfMonth() {
    const start = new LocalDate(2014, 6, 27);
    const end = new LocalDate(2014, 6, 30);
    assertNodaEqual(DateAdjusters.EndOfMonth(start), end);
  },

  DayOfMonth() {
    const start = new LocalDate(2014, 6, 27);
    const end = new LocalDate(2014, 6, 19);
    const adjuster = DateAdjusters.DayOfMonth(19);
    assertNodaEqual(adjuster(start), end);
  },

  NextOrSame(year: number, month: number, day: number, dayOfWeek: IsoDayOfWeek,
    expectedYear: number, expectedMonth: number, expectedDay: number) {
    const start = new LocalDate(year, month, day);
    const actual = start.With(DateAdjusters.NextOrSame(dayOfWeek));
    const expected = new LocalDate(expectedYear, expectedMonth, expectedDay);
    assertNodaEqual(actual, expected);
  },

  PreviousOrSame(year: number, month: number, day: number, dayOfWeek: IsoDayOfWeek,
    expectedYear: number, expectedMonth: number, expectedDay: number) {
    const start = new LocalDate(year, month, day);
    const actual = start.With(DateAdjusters.PreviousOrSame(dayOfWeek));
    const expected = new LocalDate(expectedYear, expectedMonth, expectedDay);
    assertNodaEqual(actual, expected);
  },

  Next(year: number, month: number, day: number, dayOfWeek: IsoDayOfWeek,
    expectedYear: number, expectedMonth: number, expectedDay: number) {
    const start = new LocalDate(year, month, day);
    const actual = start.With(DateAdjusters.Next(dayOfWeek));
    const expected = new LocalDate(expectedYear, expectedMonth, expectedDay);
    assertNodaEqual(actual, expected);
  },

  Previous(year: number, month: number, day: number, dayOfWeek: IsoDayOfWeek,
    expectedYear: number, expectedMonth: number, expectedDay: number) {
    const start = new LocalDate(year, month, day);
    const actual = start.With(DateAdjusters.Previous(dayOfWeek));
    const expected = new LocalDate(expectedYear, expectedMonth, expectedDay);
    assertNodaEqual(actual, expected);
  },

  Month_Valid() {
    const adjuster = DateAdjusters.Month(2);
    const start = new LocalDate(2017, 8, 21, CalendarSystem.Julian);
    const actual = start.With(adjuster);
    const expected = new LocalDate(2017, 2, 21, CalendarSystem.Julian);
    assertNodaEqual(actual, expected);
  },

  Month_InvalidAdjustment() {
    const adjuster = DateAdjusters.Month(2);
    const start = new LocalDate(2017, 8, 30, CalendarSystem.Julian);
    assertThrows(ArgumentOutOfRangeError, () => start.With(adjuster));
  },

  IsoDayOfWeekAdjusters_Invalid() {
    const invalid = 10 as IsoDayOfWeek;
    assertThrows(ArgumentOutOfRangeError, () => DateAdjusters.Next(invalid));
    assertThrows(ArgumentOutOfRangeError, () => DateAdjusters.NextOrSame(invalid));
    assertThrows(ArgumentOutOfRangeError, () => DateAdjusters.Previous(invalid));
    assertThrows(ArgumentOutOfRangeError, () => DateAdjusters.PreviousOrSame(invalid));
  },

  AddPeriod_Valid() {
    const period = Period.Add(Period.FromMonths(1), Period.FromDays(3));
    const adjuster = DateAdjusters.AddPeriod(period);
    const start = new LocalDate(2019, 5, 4);
    assertNodaEqual(start.With(adjuster), new LocalDate(2019, 6, 7));
  },

  AddPeriod_Null() {
    assertThrows(ArgumentNullError, () => DateAdjusters.AddPeriod(null!));
  },

  AddPeriod_IncludingTimeUnits() {
    // NUnit's Assert.Throws<ArgumentException> requires exactly ArgumentException.
    const e = assertThrows(ArgumentError, () => DateAdjusters.AddPeriod(Period.Add(Period.FromDays(1), Period.FromHours(1))));
    assertNodaEqual(e.constructor, ArgumentError);
  },
});
