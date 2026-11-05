// Ported from NodaTime 3.3.0: src/NodaTime.Test/Calendars/JulianCalendarSystemTest.cs
// (+ JulianCalendarSystemTest.Era.cs)
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { expect } from "vitest";
import { CalendarSystem, DateTimeZone, Era, LocalDate, LocalDateTime, NodaConstants } from "../../../src/noda-js/internal.ts";
import { assertNodaEqual } from "../../helpers/assertions.ts";
import { port } from "../../helpers/scenarios.ts";
import { fixture } from "../../scenarios/Calendars/JulianCalendarSystemTest.generated.ts";

/**
 * Tests for the Julian calendar system via JulianYearMonthDayCalculator.
 */
const Julian = CalendarSystem.Julian;

port(fixture, {
  // #region JulianCalendarSystemTest.cs
  /**
   * The Unix epoch is equivalent to December 19th 1969 in the Julian calendar.
   */
  Epoch() {
    const julianEpoch: LocalDateTime = NodaConstants.UnixEpoch.InZone(DateTimeZone.Utc, Julian).LocalDateTime;
    assertNodaEqual(julianEpoch.Year, 1969);
    assertNodaEqual(julianEpoch.Month, 12);
    assertNodaEqual(julianEpoch.Day, 19);
  },

  LeapYears() {
    expect(Julian.IsLeapYear(1900)).toBe(true); // No 100 year rule...
    expect(Julian.IsLeapYear(1901)).toBe(false);
    expect(Julian.IsLeapYear(1904)).toBe(true);
    expect(Julian.IsLeapYear(2000)).toBe(true);
    expect(Julian.IsLeapYear(2100)).toBe(true); // No 100 year rule...
    expect(Julian.IsLeapYear(2400)).toBe(true);
    // Check 1BC, 5BC etc...
    expect(Julian.IsLeapYear(0)).toBe(true);
    expect(Julian.IsLeapYear(-4)).toBe(true);
  },
  // #endregion

  // #region JulianCalendarSystemTest.Era.cs
  GetMaxYearOfEra() {
    let date = new LocalDate(Julian.MaxYear, 1, 1, Julian);
    assertNodaEqual(Julian.GetMaxYearOfEra(Era.Common), date.YearOfEra);
    assertNodaEqual(date.Era, Era.Common);
    date = new LocalDate(Julian.MinYear, 1, 1, Julian);
    assertNodaEqual(date.Year, Julian.MinYear);
    assertNodaEqual(Julian.GetMaxYearOfEra(Era.BeforeCommon), date.YearOfEra);
    assertNodaEqual(date.Era, Era.BeforeCommon);
  },

  GetMinYearOfEra() {
    let date = new LocalDate(1, 1, 1, Julian);
    assertNodaEqual(Julian.GetMinYearOfEra(Era.Common), date.YearOfEra);
    assertNodaEqual(date.Era, Era.Common);
    date = new LocalDate(0, 1, 1, Julian);
    assertNodaEqual(Julian.GetMinYearOfEra(Era.BeforeCommon), date.YearOfEra);
    assertNodaEqual(date.Era, Era.BeforeCommon);
  },

  GetAbsoluteYear() {
    assertNodaEqual(Julian.GetAbsoluteYear(1, Era.Common), 1);
    assertNodaEqual(Julian.GetAbsoluteYear(1, Era.BeforeCommon), 0);
    assertNodaEqual(Julian.GetAbsoluteYear(2, Era.BeforeCommon), -1);
    assertNodaEqual(Julian.GetAbsoluteYear(Julian.GetMaxYearOfEra(Era.Common), Era.Common), Julian.MaxYear);
    assertNodaEqual(Julian.GetAbsoluteYear(Julian.GetMaxYearOfEra(Era.BeforeCommon), Era.BeforeCommon), Julian.MinYear);
  },

  EraProperty() {
    const calendar = CalendarSystem.Julian;
    const startOfEra = new LocalDateTime(1, 1, 1, 0, 0, 0, calendar);
    assertNodaEqual(startOfEra.Era, Era.Common);
    assertNodaEqual(startOfEra.PlusTicks(-1).Era, Era.BeforeCommon);
  },
  // #endregion
});
