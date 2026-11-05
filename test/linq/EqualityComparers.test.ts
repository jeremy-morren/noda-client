// noda-js/linq's equality comparers (one per IEquatable NodaTime type): equality, null handling (null and undefined
// equal each other and nothing else, as with .NET's EqualityComparer<T>.Default), foreign values, and use with
// linq-to-typescript.

import { from } from "linq-to-typescript";
import {
  AnnualDate,
  CalendarSystem,
  DateInterval,
  DateTimeZone,
  Duration,
  Instant,
  Interval,
  LocalDate,
  LocalDateTime,
  LocalTime,
  Offset,
  OffsetDate,
  OffsetDateTime,
  OffsetTime,
  Period,
  YearMonth,
  ZonedDateTime,
  ZoneInterval,
} from "noda-js";
import { describe, expect, it } from "vitest";
import {
  AnnualDateEqualityComparer,
  DateIntervalEqualityComparer,
  DurationEqualityComparer,
  InstantEqualityComparer,
  IntervalEqualityComparer,
  LocalDateEqualityComparer,
  LocalDateTimeEqualityComparer,
  LocalTimeEqualityComparer,
  OffsetDateEqualityComparer,
  OffsetDateTimeEqualityComparer,
  OffsetEqualityComparer,
  OffsetTimeEqualityComparer,
  PeriodEqualityComparer,
  YearMonthEqualityComparer,
  ZonedDateTimeEqualityComparer,
  ZoneIntervalEqualityComparer,
} from "noda-js/linq";

type EqualityComparer<T> = (x: T | null | undefined, y: T | null | undefined) => boolean;

/**
 * Tests an equality comparer with `a`, `aCopy` (equal to `a`, a different instance) and values different from `a`
 * (and from each other).
 */
function equality<T extends object>(
  name: string, comparer: EqualityComparer<T>, a: T, aCopy: T, ...others: T[]): void {
  describe(name, () => {
    it("is true for equal values", () => {
      expect(aCopy).not.toBe(a);
      expect(comparer(a, aCopy)).toBe(true);
      expect(comparer(aCopy, a)).toBe(true);
      expect(comparer(a, a)).toBe(true);
    });

    it("is false for different values", () => {
      for (const other of others) {
        expect(comparer(a, other)).toBe(false);
        expect(comparer(other, a)).toBe(false);
      }
    });

    it("agrees with Equals", () => {
      const all = [a, aCopy, ...others] as (T & { Equals(other: unknown): boolean })[];
      for (const x of all) {
        for (const y of all) {
          expect(comparer(x, y)).toBe(x.Equals(y));
        }
      }
    });

    it("equates null and undefined with each other and nothing else", () => {
      expect(comparer(null, null)).toBe(true);
      expect(comparer(undefined, undefined)).toBe(true);
      expect(comparer(null, undefined)).toBe(true);
      expect(comparer(undefined, null)).toBe(true);
      expect(comparer(a, null)).toBe(false);
      expect(comparer(a, undefined)).toBe(false);
      expect(comparer(null, a)).toBe(false);
      expect(comparer(undefined, a)).toBe(false);
    });

    it("is false (never throws) for a value of another type, like Equals", () => {
      const foreign = comparer as EqualityComparer<unknown>;
      expect(foreign(a, {})).toBe(false);
      expect(foreign({}, a)).toBe(false);
      expect(foreign(a, "a")).toBe(false);
      expect(foreign("a", "a")).toBe(false);
      expect(foreign(a, 0)).toBe(false);
    });

    it("works with linq-to-typescript's distinct, contains and sequenceEquals", () => {
      // (No nulls here: linq-to-typescript 12's distinct keeps every null and undefined, as it tests the matching
      // element it found for truthiness.)
      const distinct = from([a, ...others, aCopy, ...others]).distinct(comparer).toArray();
      expect(distinct.length).toBe(1 + others.length);
      expect(distinct[0]).toBe(a);
      others.forEach((other, i) => expect(distinct[1 + i]).toBe(other));

      expect(from([...others, aCopy]).contains(a, comparer)).toBe(true);
      expect(from(others).contains(a, comparer)).toBe(false);
      expect(from<T | null | undefined>([a, null]).sequenceEquals(from([aCopy, undefined]), comparer)).toBe(true);
    });
  });
}

const instant1 = Instant.FromUtc(2024, 1, 1, 0, 0);
const instant2 = Instant.FromUtc(2024, 7, 1, 0, 0);
const date1 = new LocalDate(2024, 1, 1);
const date2 = new LocalDate(2024, 12, 31);
const dateTime = new LocalDateTime(2024, 3, 10, 12, 30);
const time = new LocalTime(12, 30);
const plusOne = Offset.FromHours(1);
const minusSeven = Offset.FromHours(-7);

equality("AnnualDateEqualityComparer", AnnualDateEqualityComparer,
  new AnnualDate(2, 29), new AnnualDate(2, 29), new AnnualDate(3, 1), new AnnualDate(1, 29));

equality("DateIntervalEqualityComparer", DateIntervalEqualityComparer,
  new DateInterval(date1, date2), new DateInterval(new LocalDate(2024, 1, 1), new LocalDate(2024, 12, 31)),
  new DateInterval(date1, date1),
  new DateInterval(date1.WithCalendar(CalendarSystem.Julian), date2.WithCalendar(CalendarSystem.Julian)));

equality("DurationEqualityComparer", DurationEqualityComparer,
  Duration.FromHours(1), Duration.FromMinutes(60), Duration.FromHours(-1), Duration.FromNanoseconds(1));

equality("InstantEqualityComparer", InstantEqualityComparer,
  instant1, Instant.FromUnixTimeSeconds(1704067200), instant2, Instant.FromUnixTimeSeconds(0));

equality("IntervalEqualityComparer", IntervalEqualityComparer,
  new Interval(instant1, instant2), new Interval(Instant.FromUnixTimeSeconds(1704067200), instant2),
  new Interval(instant1, null), new Interval(null, instant2), new Interval(null, null));

equality("LocalDateEqualityComparer", LocalDateEqualityComparer,
  date1, new LocalDate(2024, 1, 1), date2, date1.WithCalendar(CalendarSystem.Julian),
  new LocalDate(2024, 1, 1, CalendarSystem.Julian));

equality("LocalDateTimeEqualityComparer", LocalDateTimeEqualityComparer,
  dateTime, new LocalDateTime(2024, 3, 10, 12, 30, 0, 0), dateTime.PlusNanoseconds(1),
  dateTime.WithCalendar(CalendarSystem.Gregorian));

equality("LocalTimeEqualityComparer", LocalTimeEqualityComparer,
  time, new LocalTime(12, 30, 0, 0), new LocalTime(12, 30, 1), new LocalTime(0, 0));

equality("OffsetEqualityComparer", OffsetEqualityComparer,
  plusOne, Offset.FromSeconds(3600), Offset.FromHours(-1), Offset.Zero);

equality("OffsetDateEqualityComparer", OffsetDateEqualityComparer,
  new OffsetDate(date1, plusOne), date1.WithOffset(Offset.FromSeconds(3600)), new OffsetDate(date1, minusSeven),
  new OffsetDate(date2, plusOne));

equality("OffsetDateTimeEqualityComparer", OffsetDateTimeEqualityComparer,
  dateTime.WithOffset(plusOne), new OffsetDateTime(dateTime, Offset.FromSeconds(3600)),
  dateTime.WithOffset(minusSeven),
  // The same instant as `a`, with another offset: not equal (see OffsetDateTimeInstantEqualityComparer).
  dateTime.PlusHours(-8).WithOffset(minusSeven));

equality("OffsetTimeEqualityComparer", OffsetTimeEqualityComparer,
  new OffsetTime(time, plusOne), new OffsetTime(new LocalTime(12, 30), plusOne), new OffsetTime(time, minusSeven),
  new OffsetTime(new LocalTime(13, 30), plusOne));

equality("PeriodEqualityComparer", PeriodEqualityComparer,
  Period.FromHours(24), Period.FromHours(24),
  // Equal once normalized, but not by Period.Equals (see PeriodNormalizingEqualityComparer).
  Period.FromDays(1), Period.FromMinutes(1440), Period.Zero);

equality("YearMonthEqualityComparer", YearMonthEqualityComparer,
  new YearMonth(2024, 2), new YearMonth(2024, 2), new YearMonth(2024, 3),
  new YearMonth(2024, 2, CalendarSystem.Julian));

equality("ZonedDateTimeEqualityComparer", ZonedDateTimeEqualityComparer,
  new ZonedDateTime(instant1, DateTimeZone.Utc), instant1.InUtc(),
  new ZonedDateTime(instant2, DateTimeZone.Utc),
  // The same instant in other zones: not equal (see ZonedDateTimeInstantEqualityComparer).
  new ZonedDateTime(instant1, DateTimeZone.ForOffset(plusOne)),
  new ZonedDateTime(instant1, DateTimeZone.Utc, CalendarSystem.Julian));

equality("ZoneIntervalEqualityComparer", ZoneIntervalEqualityComparer,
  new ZoneInterval("CET", instant1, instant2, plusOne, Offset.Zero),
  new ZoneInterval("CET", instant1, instant2, plusOne, Offset.Zero),
  new ZoneInterval("CEST", instant1, instant2, plusOne, Offset.Zero),
  new ZoneInterval("CET", instant1, null, plusOne, Offset.Zero),
  new ZoneInterval("CET", instant1, instant2, Offset.FromHours(2), plusOne));
