// noda-js/linq: equality comparers, linq-to-typescript's IEqualityComparer: (x, y) => boolean. One per noda-js type
// that is IEquatable in NodaTime (its own Equals, as EqualityComparer<T>.Default), plus NodaTime's own equality
// comparers (OffsetDateTime.Comparer, ZonedDateTime.Comparer, Period.NormalizingEqualityComparer). null and
// undefined equal each other and nothing else; see Comparison.ts.

import {
  AnnualDate,
  DateInterval,
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
} from "../internal.ts";
import { EqualsEquatable, EqualsWith } from "./Comparison.ts";
import type { IEqualityComparer } from "./LinqToTypeScript.ts";

// #region Equals (IEquatable<T>)

/** Equality of {@link AnnualDate} values ({@link AnnualDate.Equals}); null and undefined equal each other. */
export const AnnualDateEqualityComparer: IEqualityComparer<AnnualDate | null | undefined> =
  (x, y) => EqualsEquatable(AnnualDate, x, y);

/**
 * Equality of {@link DateInterval} values: same start, end and calendar ({@link DateInterval.Equals}); null and
 * undefined equal each other.
 */
export const DateIntervalEqualityComparer: IEqualityComparer<DateInterval | null | undefined> =
  (x, y) => EqualsEquatable(DateInterval, x, y);

/** Equality of {@link Duration} values ({@link Duration.Equals}); null and undefined equal each other. */
export const DurationEqualityComparer: IEqualityComparer<Duration | null | undefined> =
  (x, y) => EqualsEquatable(Duration, x, y);

/** Equality of {@link Instant} values ({@link Instant.Equals}); null and undefined equal each other. */
export const InstantEqualityComparer: IEqualityComparer<Instant | null | undefined> =
  (x, y) => EqualsEquatable(Instant, x, y);

/**
 * Equality of {@link Interval} values: same start and end, including whether each is unbounded
 * ({@link Interval.Equals}); null and undefined equal each other.
 */
export const IntervalEqualityComparer: IEqualityComparer<Interval | null | undefined> =
  (x, y) => EqualsEquatable(Interval, x, y);

/**
 * Equality of {@link LocalDate} values: same date in the same calendar ({@link LocalDate.Equals}); null and
 * undefined equal each other.
 */
export const LocalDateEqualityComparer: IEqualityComparer<LocalDate | null | undefined> =
  (x, y) => EqualsEquatable(LocalDate, x, y);

/**
 * Equality of {@link LocalDateTime} values: same date and time in the same calendar ({@link LocalDateTime.Equals});
 * null and undefined equal each other.
 */
export const LocalDateTimeEqualityComparer: IEqualityComparer<LocalDateTime | null | undefined> =
  (x, y) => EqualsEquatable(LocalDateTime, x, y);

/** Equality of {@link LocalTime} values ({@link LocalTime.Equals}); null and undefined equal each other. */
export const LocalTimeEqualityComparer: IEqualityComparer<LocalTime | null | undefined> =
  (x, y) => EqualsEquatable(LocalTime, x, y);

/** Equality of {@link Offset} values ({@link Offset.Equals}); null and undefined equal each other. */
export const OffsetEqualityComparer: IEqualityComparer<Offset | null | undefined> =
  (x, y) => EqualsEquatable(Offset, x, y);

/**
 * Equality of {@link OffsetDate} values: same date (and calendar) and offset ({@link OffsetDate.Equals}); null and
 * undefined equal each other.
 */
export const OffsetDateEqualityComparer: IEqualityComparer<OffsetDate | null | undefined> =
  (x, y) => EqualsEquatable(OffsetDate, x, y);

/**
 * Equality of {@link OffsetDateTime} values: same local date/time (and calendar) and offset
 * ({@link OffsetDateTime.Equals}); null and undefined equal each other. To compare only the local date/time or only
 * the instant, use {@link OffsetDateTimeLocalEqualityComparer} or {@link OffsetDateTimeInstantEqualityComparer}.
 */
export const OffsetDateTimeEqualityComparer: IEqualityComparer<OffsetDateTime | null | undefined> =
  (x, y) => EqualsEquatable(OffsetDateTime, x, y);

/**
 * Equality of {@link OffsetTime} values: same time and offset ({@link OffsetTime.Equals}); null and undefined equal
 * each other.
 */
export const OffsetTimeEqualityComparer: IEqualityComparer<OffsetTime | null | undefined> =
  (x, y) => EqualsEquatable(OffsetTime, x, y);

/**
 * Equality of {@link Period} values, unit by unit without normalization, so "24 hours" doesn't equal "1 day"
 * ({@link Period.Equals}); null and undefined equal each other. To normalize first, use
 * {@link PeriodNormalizingEqualityComparer}.
 */
export const PeriodEqualityComparer: IEqualityComparer<Period | null | undefined> =
  (x, y) => EqualsEquatable(Period, x, y);

/**
 * Equality of {@link YearMonth} values: same year and month in the same calendar ({@link YearMonth.Equals}); null
 * and undefined equal each other.
 */
export const YearMonthEqualityComparer: IEqualityComparer<YearMonth | null | undefined> =
  (x, y) => EqualsEquatable(YearMonth, x, y);

/**
 * Equality of {@link ZonedDateTime} values: same local date/time (and calendar), offset and time zone
 * ({@link ZonedDateTime.Equals}); null and undefined equal each other. To compare only the local date/time or only
 * the instant, use {@link ZonedDateTimeLocalEqualityComparer} or {@link ZonedDateTimeInstantEqualityComparer}.
 */
export const ZonedDateTimeEqualityComparer: IEqualityComparer<ZonedDateTime | null | undefined> =
  (x, y) => EqualsEquatable(ZonedDateTime, x, y);

/**
 * Equality of {@link ZoneInterval} values: same name, start, end, wall offset and savings
 * ({@link ZoneInterval.Equals}); null and undefined equal each other.
 */
export const ZoneIntervalEqualityComparer: IEqualityComparer<ZoneInterval | null | undefined> =
  (x, y) => EqualsEquatable(ZoneInterval, x, y);

// #endregion

// #region NodaTime's equality comparers

/**
 * NodaTime's `OffsetDateTime.Comparer.Local.Equals`: {@link OffsetDateTime} values with the same local date/time (and
 * calendar), whatever their offsets. null and undefined equal each other.
 */
export const OffsetDateTimeLocalEqualityComparer: IEqualityComparer<OffsetDateTime | null | undefined> =
  (x, y) => EqualsWith(OffsetDateTime.Comparer.Local, x, y);

/**
 * NodaTime's `OffsetDateTime.Comparer.Instant.Equals`: {@link OffsetDateTime} values that represent the same instant,
 * whatever their local date/times, offsets and calendars. null and undefined equal each other.
 */
export const OffsetDateTimeInstantEqualityComparer: IEqualityComparer<OffsetDateTime | null | undefined> =
  (x, y) => EqualsWith(OffsetDateTime.Comparer.Instant, x, y);

/**
 * NodaTime's `ZonedDateTime.Comparer.Local.Equals`: {@link ZonedDateTime} values with the same local date/time (and
 * calendar), whatever their time zones and offsets. null and undefined equal each other.
 */
export const ZonedDateTimeLocalEqualityComparer: IEqualityComparer<ZonedDateTime | null | undefined> =
  (x, y) => EqualsWith(ZonedDateTime.Comparer.Local, x, y);

/**
 * NodaTime's `ZonedDateTime.Comparer.Instant.Equals`: {@link ZonedDateTime} values that represent the same instant,
 * whatever their time zones and calendars. null and undefined equal each other.
 */
export const ZonedDateTimeInstantEqualityComparer: IEqualityComparer<ZonedDateTime | null | undefined> =
  (x, y) => EqualsWith(ZonedDateTime.Comparer.Instant, x, y);

/**
 * NodaTime's `Period.NormalizingEqualityComparer`: {@link Period} values that are equal once normalized
 * ({@link Period.Normalize}), so "24 hours" equals "1 day" and "1 week" equals "7 days". (Years and months aren't
 * normalized, as their lengths vary.) null and undefined equal each other.
 */
export const PeriodNormalizingEqualityComparer: IEqualityComparer<Period | null | undefined> =
  (x, y) => EqualsWith(Period.NormalizingEqualityComparer as { Equals(x: Period, y: Period): boolean }, x, y);

// #endregion
