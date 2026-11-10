// Ported from NodaTime 3.3.7: src/NodaTime.Test/Calendars/CopticCalendarSystemTest.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { expect } from "vitest";
import {
  CalendarSystem,
  DateTimeZone,
  Era,
  IsoDayOfWeek,
  LocalDateTime,
  NodaConstants,
} from "../../../src/noda-js/internal.ts";
import { assertNodaEqual, assertThrows } from "../../helpers/assertions.ts";
import { port } from "../../helpers/scenarios.ts";
import { fixture } from "../../scenarios/Calendars/CopticCalendarSystemTest.generated.ts";

/**
 * Tests for the Coptic calendar system.
 */
port(fixture, {
  CopticEpoch() {
    const coptic = CalendarSystem.Coptic;
    const copticEpoch = new LocalDateTime(1, 1, 1, 0, 0, coptic);

    const julian = CalendarSystem.Julian;
    const converted = copticEpoch.WithCalendar(julian);

    const expected = new LocalDateTime(284, 8, 29, 0, 0, julian);
    assertNodaEqual(converted, expected);
  },

  UnixEpoch() {
    const coptic = CalendarSystem.Coptic;
    const unixEpochInCopticCalendar = NodaConstants.UnixEpoch.InZone(DateTimeZone.Utc, coptic).LocalDateTime;
    const expected = new LocalDateTime(1686, 4, 23, 0, 0, coptic);
    assertNodaEqual(unixEpochInCopticCalendar, expected);
  },

  SampleDate() {
    const copticCalendar = CalendarSystem.Coptic;
    const iso = new LocalDateTime(2004, 6, 9, 0, 0, 0, 0);
    const coptic = iso.WithCalendar(copticCalendar);

    assertNodaEqual(coptic.Era, Era.AnnoMartyrum);
    assertNodaEqual(coptic.YearOfEra, 1720);

    assertNodaEqual(coptic.Year, 1720);
    expect(copticCalendar.IsLeapYear(1720)).toBe(false);

    assertNodaEqual(coptic.Month, 10);
    assertNodaEqual(coptic.Day, 2);

    assertNodaEqual(coptic.DayOfWeek, IsoDayOfWeek.Wednesday);

    assertNodaEqual(coptic.DayOfYear, 9 * 30 + 2);

    assertNodaEqual(coptic.Hour, 0);
    assertNodaEqual(coptic.Minute, 0);
    assertNodaEqual(coptic.Second, 0);
    assertNodaEqual(coptic.Millisecond, 0);
  },

  // Really testing SingleEraCalculator...
  InvalidEra() {
    assertThrows("ArgumentNullException", () => CalendarSystem.Coptic.GetAbsoluteYear(1720, null!));
    assertThrows("ArgumentException", () => CalendarSystem.Coptic.GetAbsoluteYear(1720, Era.AnnoHegirae));
  },
});
