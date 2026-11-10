// Ported from NodaTime 3.3.7: src/NodaTime.Test/CalendarSystemTest.cs
// (+ CalendarSystemTest.Era.cs, CalendarSystemTest.Ids.cs, CalendarSystemTest.Validation.cs)
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda-js: cases for calendar IDs not in CalendarSystem.Ids are skipped.

import { expect } from "vitest";
import {
  CalendarOrdinal,
  CalendarSystem,
  Era,
  LocalDate,
} from "../../src/noda-js/internal.ts";
import { HebrewCivil } from "../../src/noda-js/entries/calendars/hebrew.ts";
import { assertNodaEqual, assertThrows } from "../helpers/assertions.ts";
import { UnsupportedValue } from "../helpers/decode.ts";
import { port } from "../helpers/scenarios.ts";
import { TestHelper } from "../helpers/TestHelper.ts";
import { fixture } from "../scenarios/CalendarSystemTest.generated.ts";

// #region CalendarSystemTest.cs
const SupportedIds: readonly string[] = [...CalendarSystem.Ids];

/** Skips a scenario case whose calendar ID (from NodaTime's CalendarSystem.Ids) isn't ported. */
function requireSupportedId(id: string): void {
  if (SupportedIds.indexOf(id) < 0) {
    throw new UnsupportedValue(`Calendar ${id} isn't supported by noda-js (only ISO, Gregorian, Julian and Coptic are ported)`);
  }
}

function validateProperties(calendar: CalendarSystem, daysSinceEpoch: number, expectedYear: number): void {
  const localDate = LocalDate.NewDaysSinceEpochCalendar(daysSinceEpoch, calendar);
  assertNodaEqual(localDate.Year, expectedYear);

  // C#: typeof(LocalDate).GetTypeInfo().DeclaredProperties (instance properties are getters on the prototype).
  for (const [name, descriptor] of Object.entries(Object.getOwnPropertyDescriptors(LocalDate.prototype))) {
    if (descriptor.get !== undefined) {
      TestHelper.consume((localDate as any)[name]);
    }
  }
}
// #endregion

// #region CalendarSystemTest.Era.cs
const CopticCalendar = CalendarSystem.Coptic;
// #endregion

// #region CalendarSystemTest.Validation.cs
// Tests for validation of public methods on CalendarSystem. These typically use the ISO calendar, just for simplicity.
const Iso = CalendarSystem.Iso;
// #endregion

port(fixture, {
  // #region CalendarSystemTest.cs
  MaxDate(calendar: CalendarSystem) {
    // Construct the largest LocalDate we can, and validate that all the properties can be fetched without
    // issues.
    validateProperties(calendar, calendar.MaxDays, calendar.MaxYear);
  },

  MinDate(calendar: CalendarSystem) {
    // Construct the smallest LocalDate we can, and validate that all the properties can be fetched without
    // issues.
    validateProperties(calendar, calendar.MinDays, calendar.MinYear);
  },
  // #endregion

  // #region CalendarSystemTest.Era.cs
  // Tests using CopticCalendar as a simple example which doesn't override anything.
  GetAbsoluteYear() {
    assertNodaEqual(CopticCalendar.GetAbsoluteYear(5, Era.AnnoMartyrum), 5);
    // Prove it's right...
    const localDate = new LocalDate(5, 1, 1, CopticCalendar);
    assertNodaEqual(localDate.Year, 5);
    assertNodaEqual(localDate.YearOfEra, 5);
    assertNodaEqual(localDate.Era, Era.AnnoMartyrum);
  },

  GetMinYearOfEra() {
    assertNodaEqual(CopticCalendar.GetMinYearOfEra(Era.AnnoMartyrum), 1);
  },

  GetMaxYearOfEra() {
    assertNodaEqual(CopticCalendar.GetMaxYearOfEra(Era.AnnoMartyrum), CopticCalendar.MaxYear);
  },
  // #endregion

  // #region CalendarSystemTest.Ids.cs
  ValidId(id: string) {
    requireSupportedId(id);
    expect(CalendarSystem.ForId(id)).toBeInstanceOf(CalendarSystem);
  },

  IdsAreCaseSensitive(id: string) {
    requireSupportedId(id);
    assertThrows("KeyNotFoundException", () => CalendarSystem.ForId(id.toLowerCase()));
  },

  AllIdsGiveDifferentCalendars() {
    const allCalendars = SupportedIds.map(id => CalendarSystem.ForId(id));
    assertNodaEqual(new Set(allCalendars).size, SupportedIds.length);
  },

  BadId() {
    assertThrows("KeyNotFoundException", () => CalendarSystem.ForId("bad"));
  },

  NoSubstrings() {
    // C#: CultureInfo.InvariantCulture.CompareInfo.Compare(..., CompareOptions.IgnoreCase) on the leading characters.
    for (const firstId of CalendarSystem.Ids) {
      for (const secondId of CalendarSystem.Ids) {
        // We're looking for firstId being a substring of secondId, which can only
        // happen if firstId is shorter...
        if (firstId.length >= secondId.length) {
          continue;
        }
        expect(firstId.toUpperCase() === secondId.substring(0, firstId.length).toUpperCase(),
          `${firstId} is a leading substring of ${secondId}`).toBe(false);
      }
    }
  },

  // Ordinals are similar enough to IDs to keep the tests in this file too...

  ForOrdinal_Roundtrip(calendar: CalendarSystem) {
    expect(CalendarSystem.ForOrdinal(calendar.Ordinal)).toBe(calendar);
  },

  ForOrdinalUncached_Roundtrip(calendar: CalendarSystem) {
    expect(CalendarSystem.ForOrdinalUncached(calendar.Ordinal)).toBe(calendar);
  },

  ForOrdinalUncached_Invalid() {
    assertThrows("InvalidOperationException", () => CalendarSystem.ForOrdinalUncached(9999 as CalendarOrdinal));
  },
  // #endregion

  // #region CalendarSystemTest.Validation.cs
  GetMonthsInYear_Valid(year: number) {
    TestHelper.assertValid((y: number) => Iso.GetMonthsInYear(y), year);
  },

  GetMonthsInYear_Invalid(year: number) {
    TestHelper.assertOutOfRange((y: number) => Iso.GetMonthsInYear(y), year);
  },

  GetDaysInMonth_Valid(year: number, month: number) {
    TestHelper.assertValid((y: number, m: number) => Iso.GetDaysInMonth(y, m), year, month);
  },

  GetDaysInMonth_Invalid(year: number, month: number) {
    TestHelper.assertOutOfRange((y: number, m: number) => Iso.GetDaysInMonth(y, m), year, month);
  },

  GetDaysInMonth_Hebrew() {
    TestHelper.assertValid((y: number, m: number) => HebrewCivil.GetDaysInMonth(y, m), 5402, 13); // Leap year
    TestHelper.assertOutOfRange((y: number, m: number) => HebrewCivil.GetDaysInMonth(y, m), 5401, 13); // Not a leap year
  },

  IsLeapYear_Valid(year: number) {
    TestHelper.assertValid((y: number) => Iso.IsLeapYear(y), year);
  },

  IsLeapYear_Invalid(year: number) {
    TestHelper.assertOutOfRange((y: number) => Iso.IsLeapYear(y), year);
  },

  GetAbsoluteYear_ValidCe(year: number) {
    TestHelper.assertValid((y: number, e: Era) => Iso.GetAbsoluteYear(y, e), year, Era.Common);
  },

  GetAbsoluteYear_ValidBce(year: number) {
    TestHelper.assertValid((y: number, e: Era) => Iso.GetAbsoluteYear(y, e), year, Era.BeforeCommon);
  },

  GetAbsoluteYear_InvalidCe(year: number) {
    TestHelper.assertOutOfRange((y: number, e: Era) => Iso.GetAbsoluteYear(y, e), year, Era.Common);
  },

  GetAbsoluteYear_InvalidBce(year: number) {
    TestHelper.assertOutOfRange((y: number, e: Era) => Iso.GetAbsoluteYear(y, e), year, Era.BeforeCommon);
  },

  GetAbsoluteYear_InvalidEra() {
    TestHelper.assertInvalid((y: number, e: Era) => Iso.GetAbsoluteYear(y, e), 1, Era.AnnoPersico);
  },

  GetAbsoluteYear_NullEra() {
    TestHelper.assertArgumentNull((y: number, e: Era) => Iso.GetAbsoluteYear(y, e), 1, null);
  },

  GetMinYearOfEra_NullEra() {
    TestHelper.assertArgumentNull((e: Era) => Iso.GetMinYearOfEra(e), null);
  },

  GetMinYearOfEra_InvalidEra() {
    TestHelper.assertInvalid((e: Era) => Iso.GetMinYearOfEra(e), Era.AnnoPersico);
  },

  GetMaxYearOfEra_NullEra() {
    TestHelper.assertArgumentNull((e: Era) => Iso.GetMaxYearOfEra(e), null);
  },

  GetMaxYearOfEra_InvalidEra() {
    TestHelper.assertInvalid((e: Era) => Iso.GetMaxYearOfEra(e), Era.AnnoPersico);
  },
  // #endregion
});
