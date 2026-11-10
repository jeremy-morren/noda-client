// noda-js/linq's natural-order comparers: null and undefined sort first, as with .NET's Comparer<T>.Default.

import { from } from "linq-to-typescript";
import {
  AnnualDate,
  CalendarSystem,
  Duration,
  Instant,
  LocalDate,
  LocalDateTime,
  LocalTime,
  Offset,
  YearMonth,
} from "noda-js";
import { describe, expect, it } from "vitest";
import {
  AnnualDateComparer,
  DurationComparer,
  InstantComparer,
  LocalDateComparer,
  LocalDateTimeComparer,
  LocalTimeComparer,
  OffsetComparer,
  YearMonthComparer,
} from "noda-js/linq";
import type { ArgumentException } from "../../src/noda-js/internal.ts";

type Comparer<T> = (x: T | null | undefined, y: T | null | undefined) => number;

/** `ascending` is called twice, to get equal values that are different instances. */
function naturalOrder<T extends object>(name: string, comparer: Comparer<T>, ascending: () => T[]): void {
  describe(name, () => {
    const values = ascending();
    const copies = ascending();

    it("orders the values", () => {
      for (let i = 0; i < values.length; i++) {
        for (let j = 0; j < values.length; j++) {
          expect(Math.sign(comparer(values[i], values[j]))).toBe(Math.sign(i - j));
        }
      }
    });

    it("compares equal values (different instances) as 0", () => {
      values.forEach((value, i) => {
        expect(comparer(value, copies[i])).toBe(0);
        expect(comparer(value, value)).toBe(0);
      });
    });

    it("sorts null and undefined first, equal to each other", () => {
      expect(comparer(null, undefined)).toBe(0);
      expect(comparer(undefined, null)).toBe(0);
      expect(comparer(null, null)).toBe(0);
      expect(comparer(undefined, undefined)).toBe(0);
      for (const value of values) {
        expect(comparer(null, value)).toBeLessThan(0);
        expect(comparer(undefined, value)).toBeLessThan(0);
        expect(comparer(value, null)).toBeGreaterThan(0);
        expect(comparer(value, undefined)).toBeGreaterThan(0);
      }
    });

    it("throws ArgumentException for a value of another type, like CompareTo", () => {
      const value = values[0]!;
      const foreign = comparer as Comparer<unknown>;
      expect(() => foreign(value, {})).toThrowNodaError("ArgumentException");
      expect(() => foreign({}, value)).toThrowNodaError("ArgumentException");
      expect(() => foreign("a", "a")).toThrowNodaError("ArgumentException");
      expect(() => foreign(value, 1)).toThrowNodaError("ArgumentException");
    });

    it("sorts with Array.prototype.sort", () => {
      expectSame([...values].reverse().sort(comparer), values);
    });

    it("sorts with linq-to-typescript's orderBy and orderByDescending", () => {
      // Not undefined: see below.
      const shuffled: (T | null)[] = [...values].reverse();
      shuffled.splice(1, 0, null);
      shuffled.push(null);

      const ordered = from(shuffled).orderBy(x => x, comparer).toArray();
      expectSame(ordered, [null, null, ...values]);

      const descending = from(shuffled).orderByDescending(x => x, comparer).toArray();
      expectSame(descending, [...[...values].reverse(), null, null]);
    });

    it("sorts by a key with linq-to-typescript", () => {
      const items = [...values].reverse().map((value, i) => ({ id: i, value }));
      const ordered = from(items).orderBy(x => x.value, comparer).thenBy(x => x.id).select(x => x.value).toArray();
      expectSame(ordered, values);
    });
  });
}

function expectSame<T>(actual: readonly T[], expected: readonly T[]): void {
  expect(actual.length).toBe(expected.length);
  actual.forEach((value, i) => expect(value).toBe(expected[i]));
}

naturalOrder("AnnualDateComparer", AnnualDateComparer, () => [
  new AnnualDate(1, 1), new AnnualDate(2, 28), new AnnualDate(2, 29), new AnnualDate(12, 31),
]);

naturalOrder("DurationComparer", DurationComparer, () => [
  Duration.FromDays(-365), Duration.FromHours(-1), Duration.FromNanoseconds(0), Duration.FromNanoseconds(1),
  Duration.FromMinutes(1), Duration.FromDays(36500),
]);

naturalOrder("InstantComparer", InstantComparer, () => [
  Instant.FromUtc(1969, 12, 31, 23, 59), Instant.FromUnixTimeSeconds(0), Instant.FromUtc(2024, 1, 1, 0, 0),
  Instant.FromUtc(2024, 1, 1, 0, 0, 1),
]);

naturalOrder("LocalDateComparer", LocalDateComparer, () => [
  new LocalDate(-5, 6, 1), new LocalDate(2023, 12, 31), new LocalDate(2024, 1, 1), new LocalDate(2024, 2, 29),
]);

naturalOrder("LocalDateTimeComparer", LocalDateTimeComparer, () => [
  new LocalDateTime(2023, 12, 31, 23, 59, 59), new LocalDateTime(2024, 1, 1, 0, 0),
  new LocalDateTime(2024, 1, 1, 0, 0, 0, 1), new LocalDateTime(2024, 1, 2, 0, 0),
]);

naturalOrder("LocalTimeComparer", LocalTimeComparer, () => [
  new LocalTime(0, 0), new LocalTime(0, 0, 0, 1), new LocalTime(11, 59, 59), new LocalTime(12, 0),
  new LocalTime(23, 59, 59, 999),
]);

naturalOrder("OffsetComparer", OffsetComparer, () => [
  Offset.FromHours(-12), Offset.FromSeconds(-1), Offset.FromSeconds(0), Offset.FromHoursAndMinutes(5, 30),
  Offset.FromHours(14),
]);

naturalOrder("YearMonthComparer", YearMonthComparer, () => [
  new YearMonth(2023, 12), new YearMonth(2024, 1), new YearMonth(2024, 2), new YearMonth(2025, 1),
]);

describe("undefined", () => {
  // Array.prototype.sort (and so orderBy) puts undefined last without calling the comparer.
  it("sorts last with Array.prototype.sort and orderBy, whatever the comparer says", () => {
    const one = Duration.FromHours(1);
    expect(DurationComparer(undefined, one)).toBeLessThan(0);
    expectSame([undefined, one, null].sort(DurationComparer), [null, one, undefined]);
    expectSame(from([undefined, one, null]).orderBy(x => x, DurationComparer).toArray(), [null, one, undefined]);
  });
});

describe("values in different calendars", () => {
  it("LocalDateComparer throws ArgumentException", () => {
    const iso = new LocalDate(2024, 1, 1);
    const julian = new LocalDate(2024, 1, 1, CalendarSystem.Julian);
    expect(() => LocalDateComparer(iso, julian)).toThrowNodaError("ArgumentException");
    expect(() => from([iso, julian]).orderBy(x => x, LocalDateComparer).toArray()).toThrowNodaError("ArgumentException");
    // Nulls never reach CompareTo.
    expect(LocalDateComparer(null, julian)).toBeLessThan(0);
  });

  it("LocalDateTimeComparer throws ArgumentException", () => {
    const iso = new LocalDateTime(2024, 1, 1, 12, 0);
    expect(() => LocalDateTimeComparer(iso, iso.WithCalendar(CalendarSystem.Julian))).toThrowNodaError("ArgumentException");
  });

  it("YearMonthComparer throws ArgumentException", () => {
    const iso = new YearMonth(2024, 1);
    const julian = new YearMonth(2024, 1, CalendarSystem.Julian);
    expect(() => YearMonthComparer(iso, julian)).toThrowNodaError("ArgumentException");
  });
});
