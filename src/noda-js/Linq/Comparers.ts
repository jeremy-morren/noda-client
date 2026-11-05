// noda-js/linq: ordering comparers, linq-to-typescript's IComparer: (x, y) => number, negative if x sorts first.
// One per noda-js type that is IComparable in NodaTime (its natural order, as Comparer<T>.Default), plus NodaTime's
// own comparers for types without a natural order (OffsetDateTime.Comparer, ZonedDateTime.Comparer,
// Period.CreateComparer). null and undefined sort before any value; see Comparison.ts.

import {
  AnnualDate,
  Duration,
  Instant,
  LocalDate,
  LocalDateTime,
  LocalTime,
  Offset,
  OffsetDateTime,
  Period,
  YearMonth,
  ZonedDateTime,
} from "../internal.ts";
import { CompareComparable, CompareWith } from "./Comparison.ts";
import type { IComparer } from "./LinqToTypeScript.ts";
import type { ArgumentException } from "../internal.ts";

// #region Natural order (IComparable<T>.CompareTo)

/**
 * Orders {@link AnnualDate} values by month, then day ({@link AnnualDate.CompareTo}). null and undefined sort first.
 */
export const AnnualDateComparer: IComparer<AnnualDate | null | undefined> =
  (x, y) => CompareComparable(AnnualDate, x, y);

/**
 * Orders {@link Duration} values from shortest (most negative) to longest ({@link Duration.CompareTo}). null and
 * undefined sort first.
 */
export const DurationComparer: IComparer<Duration | null | undefined> =
  (x, y) => CompareComparable(Duration, x, y);

/**
 * Orders {@link Instant} values from earliest to latest ({@link Instant.CompareTo}). null and undefined sort first.
 */
export const InstantComparer: IComparer<Instant | null | undefined> =
  (x, y) => CompareComparable(Instant, x, y);

/**
 * Orders {@link LocalDate} values from earliest to latest ({@link LocalDate.CompareTo}). null and undefined sort
 * first. Comparing dates in different calendar systems throws ArgumentException, as in NodaTime.
 */
export const LocalDateComparer: IComparer<LocalDate | null | undefined> =
  (x, y) => CompareComparable(LocalDate, x, y);

/**
 * Orders {@link LocalDateTime} values from earliest to latest ({@link LocalDateTime.CompareTo}). null and undefined
 * sort first. Comparing values in different calendar systems throws ArgumentException, as in NodaTime.
 */
export const LocalDateTimeComparer: IComparer<LocalDateTime | null | undefined> =
  (x, y) => CompareComparable(LocalDateTime, x, y);

/**
 * Orders {@link LocalTime} values from midnight to just before the next midnight ({@link LocalTime.CompareTo}).
 * null and undefined sort first.
 */
export const LocalTimeComparer: IComparer<LocalTime | null | undefined> =
  (x, y) => CompareComparable(LocalTime, x, y);

/**
 * Orders {@link Offset} values from most negative (west of UTC) to most positive ({@link Offset.CompareTo}). null and
 * undefined sort first.
 */
export const OffsetComparer: IComparer<Offset | null | undefined> =
  (x, y) => CompareComparable(Offset, x, y);

/**
 * Orders {@link YearMonth} values from earliest to latest ({@link YearMonth.CompareTo}). null and undefined sort
 * first. Comparing values in different calendar systems throws ArgumentException, as in NodaTime.
 */
export const YearMonthComparer: IComparer<YearMonth | null | undefined> =
  (x, y) => CompareComparable(YearMonth, x, y);

// #endregion

// #region NodaTime's comparers

/**
 * NodaTime's `OffsetDateTime.Comparer.Local`: orders {@link OffsetDateTime} values by their local date/time,
 * ignoring the offset (so 2013-03-04T20:21:00+01:00 sorts after 2013-03-04T19:21:00-07:00, an earlier local time
 * but a later instant). null and undefined sort first. Comparing values in different calendar systems throws
 * ArgumentException, as in NodaTime.
 */
export const OffsetDateTimeLocalComparer: IComparer<OffsetDateTime | null | undefined> =
  (x, y) => CompareWith(OffsetDateTime.Comparer.Local, x, y);

/**
 * NodaTime's `OffsetDateTime.Comparer.Instant`: orders {@link OffsetDateTime} values by the instant they represent
 * (local date/time minus offset), ignoring the calendar system (so 2013-03-04T20:21:00+01:00 sorts before
 * 2013-03-04T19:21:00-07:00). null and undefined sort first.
 */
export const OffsetDateTimeInstantComparer: IComparer<OffsetDateTime | null | undefined> =
  (x, y) => CompareWith(OffsetDateTime.Comparer.Instant, x, y);

/**
 * NodaTime's `ZonedDateTime.Comparer.Local`: orders {@link ZonedDateTime} values by their local date/time, ignoring
 * the time zone and offset. null and undefined sort first. Comparing values in different calendar systems throws
 * ArgumentException, as in NodaTime.
 */
export const ZonedDateTimeLocalComparer: IComparer<ZonedDateTime | null | undefined> =
  (x, y) => CompareWith(ZonedDateTime.Comparer.Local, x, y);

/**
 * NodaTime's `ZonedDateTime.Comparer.Instant`: orders {@link ZonedDateTime} values by the instant they represent,
 * ignoring the time zone and calendar system. null and undefined sort first.
 */
export const ZonedDateTimeInstantComparer: IComparer<ZonedDateTime | null | undefined> =
  (x, y) => CompareWith(ZonedDateTime.Comparer.Instant, x, y);

/**
 * NodaTime's `Period.CreateComparer(baseDateTime)`: a comparer that orders {@link Period} values by adding each to
 * `baseDateTime` and comparing the results (or, when neither has years or months, by comparing their durations).
 * How "1 month" compares to "30 days" depends on the base. null and undefined sort first.
 * @param baseDateTime The base local date/time to use for comparisons.
 * @returns The new comparer.
 */
export const CreatePeriodComparer: (baseDateTime: LocalDateTime) => IComparer<Period | null | undefined> =
  (baseDateTime) => {
    const comparer: { Compare(x: Period, y: Period): number } = Period.CreateComparer(baseDateTime);
    return (x, y) => CompareWith(comparer, x, y);
  };

// #endregion
