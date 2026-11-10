// Ported from NodaTime 3.3.7: src/NodaTime.Test/Calendars/GregorianCalendarSystemTest.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { expect } from "vitest";
import { CalendarSystem, Era, LocalDate, LocalDateTime } from "../../../src/noda-js/internal.ts";
import { assertNodaEqual } from "../../helpers/assertions.ts";
import { port } from "../../helpers/scenarios.ts";
import { fixture } from "../../scenarios/Calendars/GregorianCalendarSystemTest.generated.ts";

port(fixture, {
  LeapYears() {
    const calendar = CalendarSystem.Gregorian;
    expect(calendar.IsLeapYear(1900)).toBe(false);
    expect(calendar.IsLeapYear(1901)).toBe(false);
    expect(calendar.IsLeapYear(1904)).toBe(true);
    expect(calendar.IsLeapYear(1996)).toBe(true);
    expect(calendar.IsLeapYear(2000)).toBe(true);
    expect(calendar.IsLeapYear(2100)).toBe(false);
    expect(calendar.IsLeapYear(2400)).toBe(true);
  },

  EraProperty() {
    const calendar = CalendarSystem.Gregorian;
    const startOfEra = new LocalDateTime(1, 1, 1, 0, 0, 0, calendar);
    assertNodaEqual(startOfEra.Era, Era.Common);
    assertNodaEqual(startOfEra.PlusTicks(-1).Era, Era.BeforeCommon);
  },

  AddMonths_BoundaryCondition() {
    const start = new LocalDate(2017, 8, 20);
    const end = start.PlusMonths(-19);
    const expected = new LocalDate(2016, 1, 20);
    assertNodaEqual(end, expected);
  },
});
