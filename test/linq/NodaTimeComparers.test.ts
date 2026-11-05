// noda-js/linq's versions of NodaTime's own comparers: OffsetDateTime.Comparer.Local/Instant,
// ZonedDateTime.Comparer.Local/Instant, Period.CreateComparer and Period.NormalizingEqualityComparer. (linq-to-typescript
// checks use null rather than undefined in orderBy, and no nulls in distinct: see Comparers.test.ts and
// EqualityComparers.test.ts.)

import { from } from "linq-to-typescript";
import {
  ArgumentError,
  CalendarSystem,
  DateTimeZone,
  LocalDateTime,
  Offset,
  OffsetDateTime,
  Period,
  ZonedDateTime,
} from "noda-js";
import { describe, expect, it } from "vitest";
import {
  CreatePeriodComparer,
  OffsetDateTimeInstantComparer,
  OffsetDateTimeInstantEqualityComparer,
  OffsetDateTimeLocalComparer,
  OffsetDateTimeLocalEqualityComparer,
  PeriodEqualityComparer,
  PeriodNormalizingEqualityComparer,
  ZonedDateTimeInstantComparer,
  ZonedDateTimeInstantEqualityComparer,
  ZonedDateTimeLocalComparer,
  ZonedDateTimeLocalEqualityComparer,
} from "noda-js/linq";

type Comparer<T> = (x: T | null | undefined, y: T | null | undefined) => number;
type EqualityComparer<T> = (x: T | null | undefined, y: T | null | undefined) => boolean;

function expectNullsFirst<T>(comparer: Comparer<T>, value: T): void {
  expect(comparer(null, undefined)).toBe(0);
  expect(comparer(undefined, undefined)).toBe(0);
  expect(comparer(null, value)).toBeLessThan(0);
  expect(comparer(undefined, value)).toBeLessThan(0);
  expect(comparer(value, null)).toBeGreaterThan(0);
  expect(comparer(value, undefined)).toBeGreaterThan(0);
}

function expectNullsEqual<T>(comparer: EqualityComparer<T>, value: T): void {
  expect(comparer(null, undefined)).toBe(true);
  expect(comparer(null, null)).toBe(true);
  expect(comparer(null, value)).toBe(false);
  expect(comparer(value, undefined)).toBe(false);
}

function expectSame<T>(actual: readonly T[], expected: readonly T[]): void {
  expect(actual.length).toBe(expected.length);
  actual.forEach((value, i) => expect(value).toBe(expected[i]));
}

// NodaTime's documentation examples: `later` has the later local date/time, `earlier` the later instant.
const later = new LocalDateTime(2013, 3, 4, 20, 21).WithOffset(Offset.FromHours(1)); // 19:21Z
const earlier = new LocalDateTime(2013, 3, 4, 19, 21).WithOffset(Offset.FromHours(-7)); // 02:21Z the next day
// The same instant as `later`, with another local date/time and offset.
const sameInstant = new LocalDateTime(2013, 3, 4, 12, 21).WithOffset(Offset.FromHours(-7));
// The same local date/time as `later`, with another offset (so another instant).
const sameLocal = new LocalDateTime(2013, 3, 4, 20, 21).WithOffset(Offset.FromHours(-7));
// `later` in the Julian calendar: the same instant, another local date.
const julian = later.WithCalendar(CalendarSystem.Julian);

describe("OffsetDateTimeLocalComparer", () => {
  it("orders by local date/time, ignoring the offset", () => {
    expect(OffsetDateTimeLocalComparer(later, earlier)).toBeGreaterThan(0);
    expect(OffsetDateTimeLocalComparer(earlier, later)).toBeLessThan(0);
    expect(OffsetDateTimeLocalComparer(later, sameLocal)).toBe(0);
    expect(OffsetDateTimeLocalComparer(later, sameInstant)).toBeGreaterThan(0);
  });

  it("matches OffsetDateTime.Comparer.Local", () => {
    for (const x of [later, earlier, sameInstant, sameLocal]) {
      for (const y of [later, earlier, sameInstant, sameLocal]) {
        expect(OffsetDateTimeLocalComparer(x, y)).toBe(OffsetDateTime.Comparer.Local.Compare(x, y));
      }
    }
  });

  it("sorts null and undefined first", () => expectNullsFirst(OffsetDateTimeLocalComparer, later));

  it("throws ArgumentError for different calendars or a foreign value", () => {
    expect(() => OffsetDateTimeLocalComparer(later, julian)).toThrow(ArgumentError);
    expect(() => (OffsetDateTimeLocalComparer as Comparer<unknown>)(later, {})).toThrow(ArgumentError);
    expect(() => (OffsetDateTimeLocalComparer as Comparer<unknown>)({}, later)).toThrow(ArgumentError);
  });

  it("works with linq-to-typescript", () => {
    expectSame(from([later, null, earlier]).orderBy(x => x, OffsetDateTimeLocalComparer).toArray(),
      [null, earlier, later]);
  });
});

describe("OffsetDateTimeInstantComparer", () => {
  it("orders by instant, ignoring the local date/time and calendar", () => {
    expect(OffsetDateTimeInstantComparer(later, earlier)).toBeLessThan(0);
    expect(OffsetDateTimeInstantComparer(earlier, later)).toBeGreaterThan(0);
    expect(OffsetDateTimeInstantComparer(later, sameInstant)).toBe(0);
    expect(OffsetDateTimeInstantComparer(later, sameLocal)).toBeLessThan(0);
    expect(OffsetDateTimeInstantComparer(later, julian)).toBe(0);
  });

  it("sorts null and undefined first", () => expectNullsFirst(OffsetDateTimeInstantComparer, later));

  it("throws ArgumentError for a foreign value", () => {
    expect(() => (OffsetDateTimeInstantComparer as Comparer<unknown>)(later, later.ToInstant())).toThrow(ArgumentError);
  });

  it("works with linq-to-typescript", () => {
    expectSame(from([earlier, null, later]).orderBy(x => x, OffsetDateTimeInstantComparer).toArray(),
      [null, later, earlier]);
    expectSame(from([later, earlier]).orderByDescending(x => x, OffsetDateTimeInstantComparer).toArray(),
      [earlier, later]);
  });
});

describe("OffsetDateTimeLocalEqualityComparer", () => {
  it("is true for the same local date/time, whatever the offset", () => {
    expect(OffsetDateTimeLocalEqualityComparer(later, sameLocal)).toBe(true);
    expect(OffsetDateTimeLocalEqualityComparer(later, sameInstant)).toBe(false);
    expect(OffsetDateTimeLocalEqualityComparer(later, julian)).toBe(false);
  });

  it("equates null and undefined", () => expectNullsEqual(OffsetDateTimeLocalEqualityComparer, later));

  it("is false for a foreign value", () => {
    expect((OffsetDateTimeLocalEqualityComparer as EqualityComparer<unknown>)(later, {})).toBe(false);
  });

  it("works with linq-to-typescript", () => {
    expectSame(from([later, sameInstant, sameLocal]).distinct(OffsetDateTimeLocalEqualityComparer).toArray(),
      [later, sameInstant]);
  });
});

describe("OffsetDateTimeInstantEqualityComparer", () => {
  it("is true for the same instant, whatever the offset and calendar", () => {
    expect(OffsetDateTimeInstantEqualityComparer(later, sameInstant)).toBe(true);
    expect(OffsetDateTimeInstantEqualityComparer(later, julian)).toBe(true);
    expect(OffsetDateTimeInstantEqualityComparer(later, sameLocal)).toBe(false);
  });

  it("equates null and undefined", () => expectNullsEqual(OffsetDateTimeInstantEqualityComparer, later));

  it("works with linq-to-typescript", () => {
    expectSame(from([later, sameInstant, sameLocal, julian]).distinct(OffsetDateTimeInstantEqualityComparer).toArray(),
      [later, sameLocal]);
  });
});

describe("ZonedDateTime comparers", () => {
  const zLater = later.InFixedZone();
  const zEarlier = earlier.InFixedZone();
  const zSameInstant = new ZonedDateTime(later.ToInstant(), DateTimeZone.Utc);
  const zSameLocal = sameLocal.InFixedZone();
  const zJulian = julian.InFixedZone();

  it("ZonedDateTimeLocalComparer orders by local date/time", () => {
    expect(ZonedDateTimeLocalComparer(zLater, zEarlier)).toBeGreaterThan(0);
    expect(ZonedDateTimeLocalComparer(zLater, zSameLocal)).toBe(0);
    expect(ZonedDateTimeLocalComparer(zLater, zSameInstant)).toBeGreaterThan(0);
    expect(() => ZonedDateTimeLocalComparer(zLater, zJulian)).toThrow(ArgumentError);
    expect(() => (ZonedDateTimeLocalComparer as Comparer<unknown>)(zLater, later)).toThrow(ArgumentError);
    expectNullsFirst(ZonedDateTimeLocalComparer, zLater);
    expectSame(from([zLater, null, zEarlier]).orderBy(x => x, ZonedDateTimeLocalComparer).toArray(),
      [null, zEarlier, zLater]);
  });

  it("ZonedDateTimeInstantComparer orders by instant", () => {
    expect(ZonedDateTimeInstantComparer(zLater, zEarlier)).toBeLessThan(0);
    expect(ZonedDateTimeInstantComparer(zLater, zSameInstant)).toBe(0);
    expect(ZonedDateTimeInstantComparer(zLater, zJulian)).toBe(0);
    expect(() => (ZonedDateTimeInstantComparer as Comparer<unknown>)(later, zLater)).toThrow(ArgumentError);
    expectNullsFirst(ZonedDateTimeInstantComparer, zLater);
    expectSame(from([zEarlier, null, zLater]).orderBy(x => x, ZonedDateTimeInstantComparer).toArray(),
      [null, zLater, zEarlier]);
  });

  it("ZonedDateTimeLocalEqualityComparer equates the same local date/time", () => {
    expect(ZonedDateTimeLocalEqualityComparer(zLater, zSameLocal)).toBe(true);
    expect(ZonedDateTimeLocalEqualityComparer(zLater, zSameInstant)).toBe(false);
    expect(ZonedDateTimeLocalEqualityComparer(zLater, zJulian)).toBe(false);
    expect((ZonedDateTimeLocalEqualityComparer as EqualityComparer<unknown>)(zLater, later)).toBe(false);
    expectNullsEqual(ZonedDateTimeLocalEqualityComparer, zLater);
    expectSame(from([zLater, zSameInstant, zSameLocal]).distinct(ZonedDateTimeLocalEqualityComparer).toArray(),
      [zLater, zSameInstant]);
  });

  it("ZonedDateTimeInstantEqualityComparer equates the same instant", () => {
    expect(ZonedDateTimeInstantEqualityComparer(zLater, zSameInstant)).toBe(true);
    expect(ZonedDateTimeInstantEqualityComparer(zLater, zJulian)).toBe(true);
    expect(ZonedDateTimeInstantEqualityComparer(zLater, zSameLocal)).toBe(false);
    expectNullsEqual(ZonedDateTimeInstantEqualityComparer, zLater);
    expectSame(from([zLater, zSameInstant, zSameLocal, zJulian]).distinct(ZonedDateTimeInstantEqualityComparer).toArray(),
      [zLater, zSameLocal]);
  });
});

describe("CreatePeriodComparer", () => {
  const oneMonth = Period.FromMonths(1);
  const thirtyDays = Period.FromDays(30);

  it("compares by adding the periods to the base", () => {
    // February 2024 has 29 days, January 31.
    const february = CreatePeriodComparer(new LocalDateTime(2024, 2, 1, 0, 0));
    const january = CreatePeriodComparer(new LocalDateTime(2024, 1, 1, 0, 0));
    expect(february(oneMonth, thirtyDays)).toBeLessThan(0);
    expect(january(oneMonth, thirtyDays)).toBeGreaterThan(0);
    expect(january(thirtyDays, oneMonth)).toBeLessThan(0);
    expect(february(Period.FromMonths(1), Period.FromDays(29))).toBe(0);
  });

  it("compares periods without years or months by duration", () => {
    const comparer = CreatePeriodComparer(new LocalDateTime(2024, 1, 1, 0, 0));
    expect(comparer(Period.FromHours(24), Period.FromDays(1))).toBe(0);
    expect(comparer(Period.FromHours(25), Period.FromDays(1))).toBeGreaterThan(0);
    expect(comparer(Period.FromWeeks(1), Period.FromDays(8))).toBeLessThan(0);
  });

  it("matches Period.CreateComparer", () => {
    const base = new LocalDateTime(2024, 2, 1, 0, 0);
    const ours = CreatePeriodComparer(base);
    const nodaTime = Period.CreateComparer(base);
    const periods = [oneMonth, thirtyDays, Period.FromDays(29), Period.FromHours(-1), Period.Zero];
    for (const x of periods) {
      for (const y of periods) {
        expect(ours(x, y)).toBe(nodaTime.Compare(x, y));
      }
    }
  });

  it("sorts null and undefined first", () => {
    expectNullsFirst(CreatePeriodComparer(new LocalDateTime(2024, 1, 1, 0, 0)), oneMonth);
  });

  it("throws ArgumentError for a foreign value", () => {
    const comparer = CreatePeriodComparer(new LocalDateTime(2024, 1, 1, 0, 0)) as Comparer<unknown>;
    expect(() => comparer(oneMonth, {})).toThrow(ArgumentError);
    expect(() => comparer({}, oneMonth)).toThrow(ArgumentError);
  });

  it("works with linq-to-typescript", () => {
    const periods = [thirtyDays, null, oneMonth, Period.FromWeeks(4)];
    expectSame(from(periods).orderBy(x => x, CreatePeriodComparer(new LocalDateTime(2024, 2, 1, 0, 0))).toArray(),
      [null, periods[3], oneMonth, thirtyDays]);
    expectSame(from(periods).orderBy(x => x, CreatePeriodComparer(new LocalDateTime(2024, 1, 1, 0, 0))).toArray(),
      [null, periods[3], thirtyDays, oneMonth]);
  });
});

describe("PeriodNormalizingEqualityComparer", () => {
  it("equates periods that are equal once normalized", () => {
    expect(PeriodNormalizingEqualityComparer(Period.FromHours(24), Period.FromDays(1))).toBe(true);
    expect(PeriodNormalizingEqualityComparer(Period.FromWeeks(1), Period.FromDays(7))).toBe(true);
    expect(PeriodNormalizingEqualityComparer(Period.FromMinutes(90), Period.FromSeconds(5400))).toBe(true);
    expect(PeriodNormalizingEqualityComparer(Period.FromMonths(1), Period.FromDays(30))).toBe(false);
    expect(PeriodNormalizingEqualityComparer(Period.FromHours(24), Period.FromHours(25))).toBe(false);
    // Unlike PeriodEqualityComparer.
    expect(PeriodEqualityComparer(Period.FromHours(24), Period.FromDays(1))).toBe(false);
  });

  it("matches Period.NormalizingEqualityComparer", () => {
    const periods = [Period.FromHours(24), Period.FromDays(1), Period.FromMonths(1), Period.Zero, Period.FromWeeks(1)];
    for (const x of periods) {
      for (const y of periods) {
        expect(PeriodNormalizingEqualityComparer(x, y)).toBe(Period.NormalizingEqualityComparer.Equals(x, y));
      }
    }
  });

  it("equates null and undefined", () => expectNullsEqual(PeriodNormalizingEqualityComparer, Period.Zero));

  it("is false for a foreign value", () => {
    expect((PeriodNormalizingEqualityComparer as EqualityComparer<unknown>)(Period.Zero, {})).toBe(false);
    expect((PeriodNormalizingEqualityComparer as EqualityComparer<unknown>)({}, Period.Zero)).toBe(false);
  });

  it("works with linq-to-typescript", () => {
    const day = Period.FromDays(1);
    const week = Period.FromWeeks(1);
    expectSame(from([day, Period.FromHours(24), week, Period.FromDays(7)]).distinct(PeriodNormalizingEqualityComparer).toArray(),
      [day, week]);
  });
});
