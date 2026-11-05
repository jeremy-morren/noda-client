// noda-js: the equals/compareTo contract of every class implementing the internal IEquatable<T> /
// IComparable<T> interfaces (src/noda-js/Utility/Equality.ts). As in C#'s object.Equals(object), equals never throws
// and is false for anything that isn't an instance of the class; as in the non-generic
// IComparable.CompareTo(object), compareTo is positive for null and throws ArgumentError for anything else.

import { describe, expect, it } from "vitest";
import {
  AnnualDate,
  ArgumentError,
  CalendarOrdinal,
  DateInterval,
  DateTimeZone,
  Duration,
  FixedDateTimeZone,
  Instant,
  Int32,
  Interval,
  LocalDate,
  LocalDateTime,
  LocalInstant,
  LocalTime,
  MapZone,
  Offset,
  OffsetDate,
  OffsetDateTime,
  OffsetTime,
  Period,
  StandardDaylightAlternatingMap,
  Transition,
  TransitionMode,
  TzdbZone1970LocationCountry,
  YearMonth,
  YearMonthDay,
  YearMonthDayCalendar,
  ZoneEqualityComparer,
  ZoneInterval,
  ZoneRecurrence,
  ZoneYearOffset,
  ZonedDateTime,
  type IComparable,
  type IEquatable,
} from "../src/noda-js/internal.ts";

const date = new LocalDate(2024, 3, 1);
const time = new LocalTime(10, 30);
const dateTime = new LocalDateTime(2024, 3, 1, 10, 30);
const offset = Offset.FromHours(2);
const instant = Instant.FromUnixTimeSeconds(1_700_000_000);
const yearOffset = ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(TransitionMode.Wall, 10, 5, 0, false, new LocalTime(2, 0));
const summerOffset = ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(TransitionMode.Wall, 3, 10, 0, false, new LocalTime(1, 0));
const winter = new ZoneRecurrence("Winter", Offset.Zero, yearOffset, 2000, Int32.MaxValue);
const summer = new ZoneRecurrence("Summer", Offset.FromHours(1), summerOffset, 2000, Int32.MaxValue);

/** One sample instance of each class implementing IEquatable<T>. */
const equatables: Record<string, IEquatable<unknown>> = {
  AnnualDate: new AnnualDate(3, 1),
  DateInterval: new DateInterval(date, date.PlusDays(10)),
  Duration: Duration.FromHours(1),
  FixedDateTimeZone: new FixedDateTimeZone(offset),
  Instant: instant,
  Interval: new Interval(instant, instant.Plus(Duration.FromHours(1))),
  LocalDate: date,
  LocalDateTime: dateTime,
  LocalInstant: LocalInstant.NewDaysNanoOfDay(100, 0),
  LocalTime: time,
  MapZone: new MapZone("Some Standard Time", "001", ["Europe/London"]),
  Offset: offset,
  OffsetDate: new OffsetDate(date, offset),
  OffsetDateTime: new OffsetDateTime(dateTime, offset),
  OffsetTime: new OffsetTime(time, offset),
  Period: Period.FromDays(1),
  StandardDaylightAlternatingMap: StandardDaylightAlternatingMap.NewStandardOffsetStartRecurrenceEndRecurrence(Offset.Zero, winter, summer),
  Transition: new Transition(instant, offset),
  TzdbZone1970LocationCountry: new TzdbZone1970LocationCountry("United Kingdom", "GB"),
  YearMonth: new YearMonth(2024, 3),
  YearMonthDay: YearMonthDay.NewYearMonthDay(2024, 3, 1),
  YearMonthDayCalendar: YearMonthDayCalendar.NewYearMonthDayCalendarOrdinal(2024, 3, 1, CalendarOrdinal.Iso),
  ZonedDateTime: instant.InUtc(),
  ZoneInterval: new ZoneInterval("Test", instant, instant.Plus(Duration.FromHours(1)), offset, Offset.Zero),
  ZoneRecurrence: winter,
  ZoneYearOffset: yearOffset,
};

/** The classes that also implement IComparable<T>. */
const comparables: Record<string, IComparable<unknown>> = {
  AnnualDate: new AnnualDate(3, 1),
  Duration: Duration.FromHours(1),
  Instant: instant,
  LocalDate: date,
  LocalDateTime: dateTime,
  LocalTime: time,
  Offset: offset,
  YearMonth: new YearMonth(2024, 3),
  YearMonthDay: YearMonthDay.NewYearMonthDay(2024, 3, 1),
};

/** A value of a different noda type (never an instance of the class under test). */
function foreignValue(name: string): unknown {
  return name === "Duration" ? Offset.Zero : Duration.Zero;
}

describe("IEquatable<T> contract", () => {
  for (const [name, value] of Object.entries(equatables)) {
    describe(name, () => {
      it("equals itself", () => {
        expect(value.Equals(value)).toBe(true);
      });

      it("equals(non-instance) is false without throwing", () => {
        for (const other of [undefined, null, {}, 0, "x", foreignValue(name)]) {
          expect(value.Equals(other), `${name}.equals(${String(other)})`).toBe(false);
        }
      });
    });
  }
});

describe("IComparable<T> contract", () => {
  for (const [name, value] of Object.entries(comparables)) {
    describe(name, () => {
      it("compareTo(itself) is zero", () => {
        expect(value.CompareTo(value)).toBe(0);
      });

      it("compareTo(null) and compareTo(undefined) are positive", () => {
        expect(value.CompareTo(null)).toBeGreaterThan(0);
        expect(value.CompareTo(undefined)).toBeGreaterThan(0);
      });

      it("compareTo(non-instance) throws ArgumentError", () => {
        for (const other of [{}, 0, "x", foreignValue(name)]) {
          expect(() => value.CompareTo(other), `${name}.compareTo(${String(other)})`).toThrow(ArgumentError);
        }
      });
    });
  }

  it("C#'s message and parameter name for a foreign value", () => {
    const e = (() => {
      try {
        Duration.Zero.CompareTo({});
      } catch (error) {
        return error;
      }
      return undefined;
    })();
    expect(e).toBeInstanceOf(ArgumentError);
    expect((e as ArgumentError).message).toContain("Object must be of type NodaTime.Duration.");
  });
});

describe("compareTo helpers outside IComparable", () => {
  it("LocalInstant.compareTo(non-instance) throws ArgumentError", () => {
    const value = LocalInstant.NewDaysNanoOfDay(100, 0);
    for (const other of [null, undefined, {}, Duration.Zero]) {
      expect(() => value.CompareTo(other as unknown as LocalInstant)).toThrow(ArgumentError);
    }
  });
});

describe("comparers", () => {
  const odt = new OffsetDateTime(dateTime, offset);
  const zdt = instant.InUtc();

  it("OffsetDateTime.Comparer: equals false and compare throws ArgumentError for non-instances", () => {
    for (const comparer of [OffsetDateTime.Comparer.Local, OffsetDateTime.Comparer.Instant]) {
      for (const other of [null, undefined, {}, zdt]) {
        expect(comparer.Equals(odt, other as OffsetDateTime)).toBe(false);
        expect(comparer.Equals(other as OffsetDateTime, odt)).toBe(false);
        expect(() => comparer.Compare(odt, other as OffsetDateTime)).toThrow(ArgumentError);
        expect(() => comparer.Compare(other as OffsetDateTime, odt)).toThrow(ArgumentError);
      }
      expect(comparer.Equals(odt, odt)).toBe(true);
    }
  });

  it("ZonedDateTime.Comparer: equals false and compare throws ArgumentError for non-instances", () => {
    for (const comparer of [ZonedDateTime.Comparer.Local, ZonedDateTime.Comparer.Instant]) {
      for (const other of [null, undefined, {}, odt]) {
        expect(comparer.Equals(zdt, other as ZonedDateTime)).toBe(false);
        expect(comparer.Equals(other as ZonedDateTime, zdt)).toBe(false);
        expect(() => comparer.Compare(zdt, other as ZonedDateTime)).toThrow(ArgumentError);
        expect(() => comparer.Compare(other as ZonedDateTime, zdt)).toThrow(ArgumentError);
      }
      expect(comparer.Equals(zdt, zdt)).toBe(true);
    }
  });

  it("Period.normalizingEqualityComparer: false for non-periods", () => {
    const comparer = Period.NormalizingEqualityComparer;
    const period = Period.FromHours(1);
    expect(comparer.Equals(null, null)).toBe(true);
    expect(comparer.Equals(period, Period.FromMinutes(60))).toBe(true);
    for (const other of [null, undefined, {}, Duration.Zero]) {
      expect(comparer.Equals(period, other as Period)).toBe(false);
      expect(comparer.Equals(other as Period, period)).toBe(false);
    }
  });

  it("Period.createComparer: null sorts first; non-periods throw ArgumentError", () => {
    const comparer = Period.CreateComparer(dateTime);
    const period = Period.FromDays(1);
    expect(comparer.Compare(period, null)).toBeGreaterThan(0);
    expect(comparer.Compare(null, period)).toBeLessThan(0);
    for (const other of [{}, Duration.Zero]) {
      expect(() => comparer.Compare(period, other as Period)).toThrow(ArgumentError);
      expect(() => comparer.Compare(other as Period, period)).toThrow(ArgumentError);
    }
  });

  it("ZoneEqualityComparer: false for non-zones", () => {
    const comparer = ZoneEqualityComparer.ForInterval(new Interval(instant, instant.Plus(Duration.FromHours(1))));
    const zone = DateTimeZone.ForOffset(offset);
    expect(comparer.Equals(zone, zone)).toBe(true);
    for (const other of [null, undefined, {}, Duration.Zero]) {
      expect(comparer.Equals(zone, other as DateTimeZone)).toBe(false);
      expect(comparer.Equals(other as DateTimeZone, zone)).toBe(false);
    }
  });
});
