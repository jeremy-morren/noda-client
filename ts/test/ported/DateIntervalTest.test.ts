// Ported from NodaTime 6e024dde: src/NodaTime.Test/DateIntervalTest.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { expect } from "vitest";
import {
  CalendarSystem,
  DateInterval,
  LocalDate,
  LocalDatePattern,
} from "../../src/noda-js/internal.ts";
import { assertNodaEqual, assertThrows } from "../helpers/assertions.ts";
import { port } from "../helpers/scenarios.ts";
import { TestHelper } from "../helpers/TestHelper.ts";
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

  Equals() {
    const start = new LocalDate(2000, 1, 1);
    const end = new LocalDate(2001, 6, 19);
    const interval = new DateInterval(start, end);
    const equalInterval = new DateInterval(start, end);
    const unequalIntervals = [
      new DateInterval(start.PlusDays(1), end),
      new DateInterval(start, end.PlusDays(1)),
      // This is a really, really similar calendar to ISO, but we do distinguish.
      // (The calendar system has to be the same for the start and end, so we don't
      // need to perform start-different vs end-different equality tests.)
      new DateInterval(start.WithCalendar(CalendarSystem.Gregorian), end.WithCalendar(CalendarSystem.Gregorian)),
    ];
    TestHelper.testEqualsClass(interval, equalInterval, ...unequalIntervals);

    expect(interval.Equals(equalInterval)).toBe(true); // C# ==
    expect(!interval.Equals(equalInterval)).toBe(false); // C# !=

    // C# interval == null, interval != null, null == interval, null != interval: all Equals(null) in noda-js.
    expect(interval.Equals(null)).toBe(false);
    expect(!interval.Equals(null)).toBe(true);
    expect(interval.Equals(null)).toBe(false);
    expect(!interval.Equals(null)).toBe(true);

    for (const unequalInterval of unequalIntervals) {
      expect(interval.Equals(unequalInterval)).toBe(false); // C# ==
      expect(!interval.Equals(unequalInterval)).toBe(true); // C# !=
    }
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
