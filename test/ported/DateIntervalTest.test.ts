// Ported from NodaTime 3.3.7: src/NodaTime.Test/DateIntervalTest.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda-js: C# == / != are Equals(); GetHashCode isn't ported, so those checks are omitted. Deconstruct isn't
// ported either: JS destructuring of the start/end getters is the equivalent. The internal constructor
// LocalDate(int daysSinceEpoch) is LocalDate.NewDaysSinceEpoch. IEnumerable<LocalDate> is [Symbol.iterator].

import { expect } from "vitest";
import {
  CalendarSystem,
  DateInterval,
  Instant,
  LocalDate,
  LocalDatePattern,
} from "../../src/noda-js/internal.ts";
import { assertNodaEqual, assertThrows } from "../helpers/assertions.ts";
import { port } from "../helpers/scenarios.ts";
import { fixture } from "../scenarios/DateIntervalTest.generated.ts";

function parseIntervalOrNull(textualInterval: string | null): DateInterval | null {
  return textualInterval === null ? null : parseInterval(textualInterval);
}

function parseInterval(textualInterval: string): DateInterval {
  const parts = textualInterval.split(",");
  const start = LocalDatePattern.Iso.Parse(parts[0]!).Value;
  const end = LocalDatePattern.Iso.Parse(parts[1]!).Value;

  return new DateInterval(start, end);
}

/** NUnit's Assert.AreEqual on a nullable value. */
function assertNullableEqual(actual: DateInterval | null, expected: DateInterval | null, message?: string): void {
  if (expected === null) {
    expect(actual, message).toBeNull();
  } else {
    assertNodaEqual(actual, expected, message);
  }
}

const JulianCalendar = CalendarSystem.Julian;

port(fixture, {
  Construction_DifferentCalendars() {
    const start = new LocalDate(1600, 1, 1);
    const end = new LocalDate(1800, 1, 1, JulianCalendar);
    assertThrows("ArgumentException", () => new DateInterval(start, end));
  },

  Construction_EndBeforeStart() {
    const start = new LocalDate(1600, 1, 1);
    const end = new LocalDate(1500, 1, 1);
    assertThrows("ArgumentException", () => new DateInterval(start, end));
  },

  Construction_EqualStartAndEnd() {
    const start = new LocalDate(2000, 1, 1);
    expect(() => new DateInterval(start, start)).not.toThrow();
  },

  Construction_Properties() {
    const start = new LocalDate(2000, 1, 1);
    const end = new LocalDate(2001, 6, 19);
    const interval = new DateInterval(start, end);
    assertNodaEqual(interval.Start, start);
    assertNodaEqual(interval.End, end);
  },

  Equals_SameInstance() {
    const start = new LocalDate(2000, 1, 1);
    const end = new LocalDate(2001, 6, 19);
    const interval = new DateInterval(start, end);

    assertNodaEqual(interval, interval);
    expect(interval.Equals(interval)).toBe(true); // C# ==
    expect(!interval.Equals(interval)).toBe(false); // C# !=
    expect(interval.Equals(interval)).toBe(true); // IEquatable implementation
  },

  Equals_EqualValues() {
    const start = new LocalDate(2000, 1, 1);
    const end = new LocalDate(2001, 6, 19);
    const interval1 = new DateInterval(start, end);
    const interval2 = new DateInterval(start, end);

    assertNodaEqual(interval2, interval1);
    expect(interval1.Equals(interval2)).toBe(true); // C# ==
    expect(!interval1.Equals(interval2)).toBe(false); // C# !=
    expect(interval1.Equals(interval2)).toBe(true); // IEquatable implementation
  },

  Equals_DifferentCalendars() {
    const start1 = new LocalDate(2000, 1, 1);
    const end1 = new LocalDate(2001, 6, 19);
    // This is a really, really similar calendar to ISO, but we do distinguish.
    const start2 = start1.WithCalendar(CalendarSystem.Gregorian);
    const end2 = end1.WithCalendar(CalendarSystem.Gregorian);
    const interval1 = new DateInterval(start1, end1);
    const interval2 = new DateInterval(start2, end2);

    expect(interval1.Equals(interval2)).toBe(false); // Assert.AreNotEqual
    // Not ported: the GetHashCode check (GetHashCode isn't ported).
    expect(interval1.Equals(interval2)).toBe(false); // C# ==
    expect(!interval1.Equals(interval2)).toBe(true); // C# !=
    expect(interval1.Equals(interval2)).toBe(false); // IEquatable implementation
  },

  Equals_DifferentStart() {
    const start1 = new LocalDate(2000, 1, 1);
    const start2 = new LocalDate(2000, 1, 2);
    const end = new LocalDate(2001, 6, 19);
    const interval1 = new DateInterval(start1, end);
    const interval2 = new DateInterval(start2, end);

    expect(interval1.Equals(interval2)).toBe(false); // Assert.AreNotEqual
    expect(interval1.Equals(interval2)).toBe(false); // C# ==
    expect(!interval1.Equals(interval2)).toBe(true); // C# !=
    expect(interval1.Equals(interval2)).toBe(false); // IEquatable implementation
  },

  Equals_DifferentEnd() {
    const start = new LocalDate(2000, 1, 1);
    const end1 = new LocalDate(2001, 6, 19);
    const end2 = new LocalDate(2001, 6, 20);
    const interval1 = new DateInterval(start, end1);
    const interval2 = new DateInterval(start, end2);

    expect(interval1.Equals(interval2)).toBe(false); // Assert.AreNotEqual
    expect(interval1.Equals(interval2)).toBe(false); // C# ==
    expect(!interval1.Equals(interval2)).toBe(true); // C# !=
    expect(interval1.Equals(interval2)).toBe(false); // IEquatable implementation
  },

  Equals_DifferentToNull() {
    const start = new LocalDate(2000, 1, 1);
    const end = new LocalDate(2001, 6, 19);
    const interval = new DateInterval(start, end);

    expect(interval.Equals(null!)).toBe(false);
  },

  Equals_DifferentToOtherType() {
    const start = new LocalDate(2000, 1, 1);
    const end = new LocalDate(2001, 6, 19);
    const interval = new DateInterval(start, end);
    expect(interval.Equals(Instant.FromUnixTimeTicks(0))).toBe(false);
  },

  StringRepresentation() {
    const start = new LocalDate(2000, 1, 1);
    const end = new LocalDate(2001, 6, 19);
    const interval = new DateInterval(start, end);
    assertNodaEqual(interval.toString(), "[2000-01-01, 2001-06-19]");
  },

  Length() {
    const start = new LocalDate(2000, 1, 1);
    const end = new LocalDate(2000, 2, 10);
    const interval = new DateInterval(start, end);
    assertNodaEqual(interval.Length, 41);
  },

  Calendar() {
    const calendar = CalendarSystem.Julian;
    const start = new LocalDate(2000, 1, 1, calendar);
    const end = new LocalDate(2000, 2, 10, calendar);
    const interval = new DateInterval(start, end);
    assertNodaEqual(interval.Calendar, calendar);
  },

  Contains(candidateText: string, expected: boolean) {
    const start = new LocalDate(2000, 1, 1);
    const end = new LocalDate(2014, 6, 30);
    const candidate = LocalDatePattern.Iso.Parse(candidateText).Value;
    const interval = new DateInterval(start, end);
    assertNodaEqual(interval.Contains(candidate), expected);
  },

  Contains_DifferentCalendar() {
    const start = new LocalDate(2000, 1, 1);
    const end = new LocalDate(2014, 6, 30);
    const interval = new DateInterval(start, end);
    const candidate = new LocalDate(2000, 1, 1, JulianCalendar);
    assertThrows("ArgumentException", () => interval.Contains(candidate));
  },

  Deconstruction() {
    const start = new LocalDate(2017, 11, 6);
    const end = new LocalDate(2017, 11, 10);
    const value = new DateInterval(start, end);

    const { Start: actualStart, End: actualEnd } = value;

    assertNodaEqual(actualStart, start);
    assertNodaEqual(actualEnd, end);
  },

  Contains_NullInterval_Throws() {
    const start = new LocalDate(2017, 11, 6);
    const end = new LocalDate(2017, 11, 10);
    const value = new DateInterval(start, end);

    assertThrows("ArgumentNullException", () => value.Contains(null! as DateInterval));
  },

  Contains_IntervalWithinAnotherCalendar_Throws() {
    const value = new DateInterval(
      new LocalDate(2017, 11, 6, CalendarSystem.Gregorian),
      new LocalDate(2017, 11, 10, CalendarSystem.Gregorian));

    const other = new DateInterval(
      new LocalDate(2017, 11, 6, CalendarSystem.Coptic),
      new LocalDate(2017, 11, 10, CalendarSystem.Coptic));

    assertThrows("ArgumentException", () => value.Contains(other));
  },

  Contains_IntervalOverload(firstInterval: string, secondInterval: string, expectedResult: boolean) {
    const value = parseInterval(firstInterval);
    const other = parseInterval(secondInterval);
    assertNodaEqual(value.Contains(other), expectedResult);
  },

  Intersection_NullInterval_Throws() {
    const value = new DateInterval(LocalDate.NewDaysSinceEpoch(100), LocalDate.NewDaysSinceEpoch(200));
    assertThrows("ArgumentNullException", () => value.Intersection(null!));
  },

  Intersection_IntervalInDifferentCalendar_Throws() {
    const value = new DateInterval(
      new LocalDate(2017, 11, 6, CalendarSystem.Gregorian),
      new LocalDate(2017, 11, 10, CalendarSystem.Gregorian));

    const other = new DateInterval(
      new LocalDate(2017, 11, 6, CalendarSystem.Coptic),
      new LocalDate(2017, 11, 10, CalendarSystem.Coptic));

    assertThrows("ArgumentException", () => value.Intersection(other));
  },

  Intersection(firstInterval: string, secondInterval: string, expectedInterval: string | null) {
    const value = parseInterval(firstInterval);
    const other = parseInterval(secondInterval);
    const expectedResult = parseIntervalOrNull(expectedInterval);
    assertNullableEqual(value.Intersection(other), expectedResult);
  },

  Union_NullInterval_Throws() {
    const value = new DateInterval(LocalDate.NewDaysSinceEpoch(100), LocalDate.NewDaysSinceEpoch(200));
    assertThrows("ArgumentNullException", () => value.Union(null!));
  },

  Union_DifferentCalendar_Throws() {
    const value = new DateInterval(
      new LocalDate(2017, 11, 6, CalendarSystem.Gregorian),
      new LocalDate(2017, 11, 10, CalendarSystem.Gregorian));

    const other = new DateInterval(
      new LocalDate(2017, 11, 6, CalendarSystem.Coptic),
      new LocalDate(2017, 11, 10, CalendarSystem.Coptic));

    assertThrows("ArgumentException", () => value.Union(other));
  },

  Union(first: string, second: string, expected: string | null) {
    const firstInterval = parseInterval(first);
    const secondInterval = parseInterval(second);
    const expectedResult = parseIntervalOrNull(expected);

    assertNullableEqual(firstInterval.Union(secondInterval), expectedResult, "First union failed.");
    assertNullableEqual(secondInterval.Union(firstInterval), expectedResult, "Second union failed.");
  },

  Iteration(intervalText: string, expectedDatesText: string[]) {
    const interval = parseInterval(intervalText);
    const expected = expectedDatesText.map(x => LocalDatePattern.Iso.Parse(x).Value);
    let actual = [...interval];
    assertNodaEqual(actual, expected);

    // Test the non-generic version too. The double cast makes sure we use the right GetEnumerator call.
    // noda-js: there's only one iterator; iterate it again through Array.from.
    actual = Array.from(interval as Iterable<unknown>) as LocalDate[];
    assertNodaEqual(actual, expected);
  },
});
