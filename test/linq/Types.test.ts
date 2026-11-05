// noda-js/linq's public surface: the export list, and (checked by `npm run typecheck`) that the comparer types
// copied from linq-to-typescript are linq-to-typescript's, so every export type-checks with its methods.

import {
  from,
  type IComparer as LinqIComparer,
  type IEqualityComparer as LinqIEqualityComparer,
} from "linq-to-typescript";
import { Duration, Instant, LocalDateTime, OffsetDateTime, Period } from "noda-js";
import { describe, expect, expectTypeOf, it } from "vitest";
import * as linq from "noda-js/linq";
import {
  CreatePeriodComparer,
  DurationComparer,
  InstantEqualityComparer,
  OffsetDateTimeInstantComparer,
  PeriodNormalizingEqualityComparer,
} from "noda-js/linq";
import type { IComparer, IEqualityComparer } from "../../src/noda-js/Linq/LinqToTypeScript.ts";

const comparers = [
  "AnnualDateComparer",
  "DurationComparer",
  "InstantComparer",
  "LocalDateComparer",
  "LocalDateTimeComparer",
  "LocalTimeComparer",
  "OffsetComparer",
  "YearMonthComparer",
  "OffsetDateTimeLocalComparer",
  "OffsetDateTimeInstantComparer",
  "ZonedDateTimeLocalComparer",
  "ZonedDateTimeInstantComparer",
] as const;

const equalityComparers = [
  "AnnualDateEqualityComparer",
  "DateIntervalEqualityComparer",
  "DurationEqualityComparer",
  "InstantEqualityComparer",
  "IntervalEqualityComparer",
  "LocalDateEqualityComparer",
  "LocalDateTimeEqualityComparer",
  "LocalTimeEqualityComparer",
  "OffsetDateEqualityComparer",
  "OffsetDateTimeEqualityComparer",
  "OffsetEqualityComparer",
  "OffsetTimeEqualityComparer",
  "PeriodEqualityComparer",
  "YearMonthEqualityComparer",
  "ZonedDateTimeEqualityComparer",
  "ZoneIntervalEqualityComparer",
  "OffsetDateTimeLocalEqualityComparer",
  "OffsetDateTimeInstantEqualityComparer",
  "ZonedDateTimeLocalEqualityComparer",
  "ZonedDateTimeInstantEqualityComparer",
  "PeriodNormalizingEqualityComparer",
] as const;

describe("noda-js/linq exports", () => {
  it("are exactly the comparers, equality comparers and CreatePeriodComparer", () => {
    expect(Object.keys(linq).sort()).toEqual([...comparers, ...equalityComparers, "CreatePeriodComparer"].sort());
  });

  it("are functions of two arguments (CreatePeriodComparer: one)", () => {
    for (const name of [...comparers, ...equalityComparers]) {
      expect(typeof linq[name]).toBe("function");
      expect(linq[name].length).toBe(2);
    }
    expect(CreatePeriodComparer.length).toBe(1);
  });
});

// #region Compile-time checks (no-ops at run time)

// The copied types are linq-to-typescript's.
expectTypeOf<IComparer<Duration>>().toEqualTypeOf<LinqIComparer<Duration>>();
expectTypeOf<IEqualityComparer<Duration>>().toEqualTypeOf<LinqIEqualityComparer<Duration>>();
expectTypeOf<IComparer<unknown>>().toEqualTypeOf<LinqIComparer<unknown>>();
expectTypeOf<IEqualityComparer<unknown>>().toEqualTypeOf<LinqIEqualityComparer<unknown>>();

// Each export is a linq-to-typescript comparer for its type, with or without null and undefined.
type Element<C> = C extends IComparer<infer T> ? T : never;
type Equated<C> = C extends IEqualityComparer<infer T> ? T : never;
type Linq = typeof linq;
type ComparerChecks = {
  [N in (typeof comparers)[number]]:
  [Linq[N]] extends [LinqIComparer<Element<Linq[N]>> & LinqIComparer<NonNullable<Element<Linq[N]>>>]
    ? (null extends Element<Linq[N]> ? (undefined extends Element<Linq[N]> ? true : N) : N) : N;
};
type EqualityComparerChecks = {
  [N in (typeof equalityComparers)[number]]:
  [Linq[N]] extends [LinqIEqualityComparer<Equated<Linq[N]>> & LinqIEqualityComparer<NonNullable<Equated<Linq[N]>>>]
    ? (null extends Equated<Linq[N]> ? (undefined extends Equated<Linq[N]> ? true : N) : N) : N;
};
// A failure names the export.
expectTypeOf<ComparerChecks[keyof ComparerChecks]>().toEqualTypeOf<true>();
expectTypeOf<EqualityComparerChecks[keyof EqualityComparerChecks]>().toEqualTypeOf<true>();
expectTypeOf<ReturnType<typeof CreatePeriodComparer>>().toEqualTypeOf<LinqIComparer<Period | null | undefined>>();
expectTypeOf(DurationComparer).toExtend<LinqIComparer<Duration>>();
expectTypeOf(DurationComparer).toExtend<LinqIComparer<Duration | null>>();
expectTypeOf(DurationComparer).toExtend<LinqIComparer<Duration | null | undefined>>();
expectTypeOf(DurationComparer).not.toExtend<LinqIComparer<Instant>>();
expectTypeOf(InstantEqualityComparer).toExtend<LinqIEqualityComparer<Instant>>();
expectTypeOf(InstantEqualityComparer).not.toExtend<LinqIEqualityComparer<Duration>>();
expectTypeOf(CreatePeriodComparer).returns.toExtend<LinqIComparer<Period>>();
expectTypeOf(CreatePeriodComparer).parameter(0).toEqualTypeOf<LocalDateTime>();

// #endregion

describe("with linq-to-typescript", () => {
  // These type-check against linq-to-typescript's own signatures (orderBy's IComparer<TKey>, distinct's
  // IEqualityComparer<TSource>), with and without nullable elements.
  it("orderBy, distinct and the special comparers type-check and run", () => {
    const durations = [Duration.FromHours(2), Duration.FromHours(1)];
    expect(from(durations).orderBy(d => d, DurationComparer).toArray()).toEqual([durations[1], durations[0]]);
    const withNull: (Duration | null)[] = [durations[0]!, null];
    expect(from(withNull).orderBy(d => d, DurationComparer).first()).toBe(null);

    const instants = [Instant.FromUnixTimeSeconds(1), Instant.FromUnixTimeSeconds(1), Instant.FromUnixTimeSeconds(2)];
    expect(from(instants).distinct(InstantEqualityComparer).count()).toBe(2);

    const odts: OffsetDateTime[] = [];
    expect(from(odts).orderBy(x => x, OffsetDateTimeInstantComparer).toArray()).toEqual([]);

    const periods = [Period.FromDays(1), Period.FromHours(24)];
    expect(from(periods).distinct(PeriodNormalizingEqualityComparer).count()).toBe(1);
    expect(from(periods).orderBy(p => p, CreatePeriodComparer(new LocalDateTime(2024, 1, 1, 0, 0))).count()).toBe(2);

    // @ts-expect-error A Duration comparer doesn't order Instants.
    from(instants).orderBy(x => x, DurationComparer);
    // @ts-expect-error An Instant equality comparer doesn't compare Durations.
    from(durations).distinct(InstantEqualityComparer);
  });
});
