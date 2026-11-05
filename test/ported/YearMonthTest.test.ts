// Ported from NodaTime 3.3.7: src/NodaTime.Test/YearMonthTest.cs
// (+ YearMonthTest.BasicProperties.cs, .Comparison.cs, .Construction.cs, .Misc.cs, .XmlSerialization.cs)
// Copyright 2019 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda-js: C# operators are CompareTo()/Equals(); GetHashCode isn't ported. GetEra(name) looks the era up by its
// static property, as the C# does by reflection.

import { expect } from "vitest";
import {
  CalendarOrdinal,
  CalendarSystem,
  DateInterval,
  Era,
  Instant,
  IslamicEpoch,
  IslamicLeapYearPattern,
  LocalDate,
  LocalDateTime,
  YearMonth,
} from "../../src/noda-js/internal.ts";
import { GetIslamicCalendar } from "../../src/noda-js/entries/calendars/islamic.ts";
import { assertNodaEqual, assertThrows } from "../helpers/assertions.ts";
import { UnsupportedValue } from "../helpers/decode.ts";
import { port } from "../helpers/scenarios.ts";
import { TestHelper } from "../helpers/TestHelper.ts";
import { fixture } from "../scenarios/YearMonthTest.generated.ts";
import { IsNodaError, type ArgumentException, type ArgumentOutOfRangeException } from "../../src/noda-js/internal.ts";

/** C# CalendarSystem.ForOrdinal((CalendarOrdinal) ordinal); skips the case for a calendar that isn't ported. */
function forOrdinal(ordinal: number): CalendarSystem {
  if (!CalendarSystem.Ids.some(id => CalendarSystem.ForId(id).Ordinal === ordinal)) {
    throw new UnsupportedValue(`Calendar ${CalendarOrdinal[ordinal] ?? ordinal} isn't supported by noda-js (only ISO, Gregorian, Julian and Coptic are ported)`);
  }
  return CalendarSystem.ForOrdinal(ordinal);
}

// We may want to put this somewhere in the production code; I'm surprised we
// haven't needed it before.
function getEra(eraName: string): Era {
  const era = (Era as unknown as Record<string, unknown>)[eraName];
  if (!(era instanceof Era)) {
    throw new Error(`No era ${eraName}`);
  }
  return era;
}

/** NUnit's Assert.That(action, Throws.InstanceOf<ArgumentException>()): ArgumentOutOfRangeException extends RangeError. */
function assertThrowsArgumentException(action: () => unknown): void {
  try {
    action();
  } catch (e) {
    expect(IsNodaError(e, "ArgumentException") || IsNodaError(e, "ArgumentOutOfRangeException"), `Expected an ArgumentException but got ${e}`).toBe(true);
    return;
  }
  expect.fail("Expected an ArgumentException but nothing was thrown");
}

port(fixture, {
  // #region YearMonthTest.BasicProperties.cs
  Properties() {
    // Some of these are covered in other tests too, but it doesn't hurt
    // to repeat ourselves here.
    const yearMonth = new YearMonth(2000, 1);
    assertNodaEqual(yearMonth.Year, 2000);
    assertNodaEqual(yearMonth.Month, 1);
    assertNodaEqual(yearMonth.Calendar, CalendarSystem.Iso);
    assertNodaEqual(yearMonth.YearOfEra, 2000);
    assertNodaEqual(yearMonth.Era, Era.Common);

    assertNodaEqual(yearMonth.StartDate, new LocalDate(2000, 1, 1));
    assertNodaEqual(yearMonth.EndDate, new LocalDate(2000, 1, 31));
  },

  ToDateInterval() {
    const yearMonth = new YearMonth(2000, 1);

    const interval = new DateInterval(new LocalDate(2000, 1, 1), new LocalDate(2000, 1, 31));
    assertNodaEqual(yearMonth.ToDateInterval(), interval);
  },
  // #endregion

  // #region YearMonthTest.Comparison.cs
  // These tests were copied from LocalDateTest and then modified for YearMonth.

  Equals_EqualValues() {
    const calendar = CalendarSystem.Julian;
    const yearMonth1 = new YearMonth(2011, 1, calendar);
    const yearMonth2 = new YearMonth(2011, 1, calendar);
    assertNodaEqual(yearMonth2, yearMonth1);
    expect(yearMonth1.Equals(yearMonth2)).toBe(true); // C# ==
    expect(!yearMonth1.Equals(yearMonth2)).toBe(false); // C# !=
    expect(yearMonth1.Equals(yearMonth2)).toBe(true); // IEquatable implementation
  },

  Equals_DifferentMonths() {
    const calendar = CalendarSystem.Julian;
    const yearMonth1 = new YearMonth(2011, 1, calendar);
    const yearMonth2 = new YearMonth(2011, 2, calendar);
    expect(yearMonth1.Equals(yearMonth2)).toBe(false); // Assert.AreNotEqual
    expect(yearMonth1.Equals(yearMonth2)).toBe(false); // C# ==
    expect(!yearMonth1.Equals(yearMonth2)).toBe(true); // C# !=
    expect(yearMonth1.Equals(yearMonth2)).toBe(false); // IEquatable implementation
  },

  Equals_DifferentCalendars() {
    const calendar = CalendarSystem.Julian;
    const yearMonth1 = new YearMonth(2011, 1, calendar);
    const yearMonth2 = new YearMonth(2011, 1, CalendarSystem.Iso);
    expect(yearMonth1.Equals(yearMonth2)).toBe(false); // Assert.AreNotEqual
    expect(yearMonth1.Equals(yearMonth2)).toBe(false); // C# ==
    expect(!yearMonth1.Equals(yearMonth2)).toBe(true); // C# !=
    expect(yearMonth1.Equals(yearMonth2)).toBe(false); // IEquatable implementation
  },

  Equals_DifferentToNull() {
    const date = new YearMonth(2011, 1);
    expect(date.Equals(null!)).toBe(false);
  },

  Equals_DifferentToOtherType() {
    const date = new YearMonth(2011, 1);
    expect(date.Equals(Instant.FromUnixTimeTicks(0))).toBe(false);
  },

  CompareTo_SameCalendar() {
    const yearMonth1 = new YearMonth(2011, 1);
    const yearMonth2 = new YearMonth(2011, 1);
    const yearMonth3 = new YearMonth(2011, 2);

    TestHelper.testOperatorComparisonEquality(yearMonth1, yearMonth2, yearMonth3);
  },

  /** IComparable.CompareTo works properly with YearMonth inputs with same calendar. */
  CompareTo_DifferentCalendars_Throws() {
    const islamic = GetIslamicCalendar(IslamicLeapYearPattern.Base15, IslamicEpoch.Astronomical);
    const yearMonth1 = new YearMonth(2011, 1);
    const yearMonth2 = new YearMonth(1500, 1, islamic);

    assertThrows("ArgumentException", () => yearMonth1.CompareTo(yearMonth2));
    // C#: ((IComparable) yearMonth1).CompareTo(yearMonth2) and yearMonth1 > yearMonth2: both CompareTo here.
    assertThrows("ArgumentException", () => yearMonth1.CompareTo(yearMonth2 as unknown));
  },

  IComparableCompareTo_SameCalendar() {
    const instance = new YearMonth(2012, 3);
    const i_instance = instance;

    const later = new YearMonth(2012, 6);
    const earlier = new YearMonth(2012, 1);
    const same = new YearMonth(2012, 3);

    expect(i_instance.CompareTo(later)).toBeLessThan(0);
    expect(i_instance.CompareTo(earlier)).toBeGreaterThan(0);
    expect(i_instance.CompareTo(same)).toBe(0);
  },

  /** IComparable.CompareTo returns a positive number for a null input. */
  IComparableCompareTo_Null_Positive() {
    const instance = new YearMonth(2012, 3);
    const comparable = instance;
    const result = comparable.CompareTo(null!);
    expect(result).toBeGreaterThan(0);
  },

  /** IComparable.CompareTo throws an ArgumentException for non-null arguments that are not a YearMonth. */
  IComparableCompareTo_WrongType_ArgumentException() {
    const instance = new YearMonth(2012, 3);
    const i_instance = instance;
    const arg = new LocalDateTime(2012, 3, 6, 15, 42);
    assertThrows("ArgumentException", () => {
      i_instance.CompareTo(arg as unknown as YearMonth);
    });
  },
  // #endregion

  // #region YearMonthTest.Construction.cs
  ValidConstruction(year: number, month: number) {
    const yearMonth = new YearMonth(year, month);
    assertNodaEqual(yearMonth.Year, year);
    assertNodaEqual(yearMonth.Month, month);
    assertNodaEqual(yearMonth.Calendar, CalendarSystem.Iso);
  },

  InvalidConstruction(year: number, month: number) {
    assertThrows("ArgumentOutOfRangeException", () => new YearMonth(year, month));
  },

  ValidConstruction_WithCalendar(year: number, month: number, ordinal: number) {
    const calendar = forOrdinal(ordinal);
    const yearMonth = new YearMonth(year, month, calendar);
    assertNodaEqual(yearMonth.Year, year);
    assertNodaEqual(yearMonth.Month, month);
    assertNodaEqual(yearMonth.Calendar, calendar);
  },

  InvalidConstruction_WithCalendar(year: number, month: number, ordinal: number) {
    const calendar = forOrdinal(ordinal);
    assertThrows("ArgumentOutOfRangeException", () => new YearMonth(year, month, calendar));
  },

  ValidConstruction_WithIsoEra(yearOfEra: number, month: number, eraName: string) {
    const era = getEra(eraName);
    const yearMonth = new YearMonth(era, yearOfEra, month);
    assertNodaEqual(yearMonth.Era, era);
    assertNodaEqual(yearMonth.YearOfEra, yearOfEra);
    assertNodaEqual(yearMonth.Month, month);
    assertNodaEqual(yearMonth.Calendar, CalendarSystem.Iso);
  },

  InvalidConstruction_WithIsoEra(yearOfEra: number, month: number, eraName: string) {
    const era = getEra(eraName);
    // We'll assume it throws the correct exact exception type. It varies by test case.
    assertThrowsArgumentException(() => new YearMonth(era, yearOfEra, month));
  },

  ValidConstruction_WithEraAndCalendar(yearOfEra: number, month: number, eraName: string, calendarOrdinal: number) {
    const era = getEra(eraName);
    const calendar = forOrdinal(calendarOrdinal);
    const yearMonth = new YearMonth(era, yearOfEra, month, calendar);
    assertNodaEqual(yearMonth.Era, era);
    assertNodaEqual(yearMonth.YearOfEra, yearOfEra);
    assertNodaEqual(yearMonth.Month, month);
    assertNodaEqual(yearMonth.Calendar, calendar);
  },

  InvalidConstruction_WithEraAndCalendar(yearOfEra: number, month: number, eraName: string, calendarOrdinal: number) {
    const era = getEra(eraName);
    const calendar = forOrdinal(calendarOrdinal);
    // We'll assume it throws the correct exact exception type. It varies by test case.
    assertThrowsArgumentException(() => new YearMonth(era, yearOfEra, month, calendar));
  },
  // #endregion

  // #region YearMonthTest.Misc.cs
  OnDayOfMonth_Valid(calendarOrdinal: number, year: number, month: number, day: number) {
    const calendar = forOrdinal(calendarOrdinal);
    const yearMonth = new YearMonth(year, month, calendar);
    const actualDate = yearMonth.OnDayOfMonth(day);
    const expectedDate = new LocalDate(year, month, day, calendar);
    assertNodaEqual(actualDate, expectedDate);
  },

  OnDayOfMonth_Invalid(calendarOrdinal: number, year: number, month: number, day: number) {
    const calendar = forOrdinal(calendarOrdinal);
    const yearMonth = new YearMonth(year, month, calendar);
    assertThrows("ArgumentOutOfRangeException", () => yearMonth.OnDayOfMonth(day));
  },

  PlusMonths(year: number, month: number, monthsToAdd: number, expectedYear: number, expectedMonth: number) {
    const yearMonth = new YearMonth(year, month);
    const expected = new YearMonth(expectedYear, expectedMonth);
    assertNodaEqual(yearMonth.PlusMonths(monthsToAdd), expected);
  },
  // #endregion
}, {
  skip: {
    // YearMonthTest.Comparison.cs
    // YearMonthTest.Misc.cs
    ToStringTest_Iso: "compares toString() under the thread's current culture; noda-js has no current culture (toString() uses the invariant culture)",
    ToStringBclEquality: "uses BCL DateTime formatting as the oracle, under the thread's current culture",
    // YearMonthTest.XmlSerialization.cs
    XmlSerialization_Iso: "XML serialization isn't ported",
    XmlSerialization_NonIso: "XML serialization isn't ported",
    XmlSerialization_Invalid: "XML serialization isn't ported",
  },
});
