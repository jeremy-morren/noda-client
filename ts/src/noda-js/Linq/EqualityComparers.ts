// noda-js: new code. noda-js/linq's equality comparers (Equals, and NodaTime's comparers).
// null and undefined equal each other and nothing else.

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

/** Equality of {@link AnnualDate} values ({@link AnnualDate.Equals}). */
export const AnnualDateEqualityComparer: IEqualityComparer<AnnualDate | null | undefined> =
  (x, y) => EqualsEquatable(AnnualDate, x, y);

/** Equality of {@link DateInterval} values ({@link DateInterval.Equals}). */
export const DateIntervalEqualityComparer: IEqualityComparer<DateInterval | null | undefined> =
  (x, y) => EqualsEquatable(DateInterval, x, y);

/** Equality of {@link Duration} values ({@link Duration.Equals}). */
export const DurationEqualityComparer: IEqualityComparer<Duration | null | undefined> =
  (x, y) => EqualsEquatable(Duration, x, y);

/** Equality of {@link Instant} values ({@link Instant.Equals}). */
export const InstantEqualityComparer: IEqualityComparer<Instant | null | undefined> =
  (x, y) => EqualsEquatable(Instant, x, y);

/** Equality of {@link Interval} values ({@link Interval.Equals}). */
export const IntervalEqualityComparer: IEqualityComparer<Interval | null | undefined> =
  (x, y) => EqualsEquatable(Interval, x, y);

/** Equality of {@link LocalDate} values ({@link LocalDate.Equals}). */
export const LocalDateEqualityComparer: IEqualityComparer<LocalDate | null | undefined> =
  (x, y) => EqualsEquatable(LocalDate, x, y);

/** Equality of {@link LocalDateTime} values ({@link LocalDateTime.Equals}). */
export const LocalDateTimeEqualityComparer: IEqualityComparer<LocalDateTime | null | undefined> =
  (x, y) => EqualsEquatable(LocalDateTime, x, y);

/** Equality of {@link LocalTime} values ({@link LocalTime.Equals}). */
export const LocalTimeEqualityComparer: IEqualityComparer<LocalTime | null | undefined> =
  (x, y) => EqualsEquatable(LocalTime, x, y);

/** Equality of {@link Offset} values ({@link Offset.Equals}). */
export const OffsetEqualityComparer: IEqualityComparer<Offset | null | undefined> =
  (x, y) => EqualsEquatable(Offset, x, y);

/** Equality of {@link OffsetDate} values ({@link OffsetDate.Equals}). */
export const OffsetDateEqualityComparer: IEqualityComparer<OffsetDate | null | undefined> =
  (x, y) => EqualsEquatable(OffsetDate, x, y);

/** Equality of {@link OffsetDateTime} values ({@link OffsetDateTime.Equals}). */
export const OffsetDateTimeEqualityComparer: IEqualityComparer<OffsetDateTime | null | undefined> =
  (x, y) => EqualsEquatable(OffsetDateTime, x, y);

/** Equality of {@link OffsetTime} values ({@link OffsetTime.Equals}). */
export const OffsetTimeEqualityComparer: IEqualityComparer<OffsetTime | null | undefined> =
  (x, y) => EqualsEquatable(OffsetTime, x, y);

/** Equality of {@link Period} values unit by unit, so "24 hours" isn't "1 day" ({@link Period.Equals}). */
export const PeriodEqualityComparer: IEqualityComparer<Period | null | undefined> =
  (x, y) => EqualsEquatable(Period, x, y);

/** Equality of {@link YearMonth} values ({@link YearMonth.Equals}). */
export const YearMonthEqualityComparer: IEqualityComparer<YearMonth | null | undefined> =
  (x, y) => EqualsEquatable(YearMonth, x, y);

/** Equality of {@link ZonedDateTime} values ({@link ZonedDateTime.Equals}). */
export const ZonedDateTimeEqualityComparer: IEqualityComparer<ZonedDateTime | null | undefined> =
  (x, y) => EqualsEquatable(ZonedDateTime, x, y);

/** Equality of {@link ZoneInterval} values ({@link ZoneInterval.Equals}). */
export const ZoneIntervalEqualityComparer: IEqualityComparer<ZoneInterval | null | undefined> =
  (x, y) => EqualsEquatable(ZoneInterval, x, y);

// #endregion

// #region NodaTime's equality comparers

/** NodaTime's `OffsetDateTime.Comparer.Local.Equals`: same local date/time, any offset. */
export const OffsetDateTimeLocalEqualityComparer: IEqualityComparer<OffsetDateTime | null | undefined> =
  (x, y) => EqualsWith(OffsetDateTime.Comparer.Local, x, y);

/** NodaTime's `OffsetDateTime.Comparer.Instant.Equals`: same instant. */
export const OffsetDateTimeInstantEqualityComparer: IEqualityComparer<OffsetDateTime | null | undefined> =
  (x, y) => EqualsWith(OffsetDateTime.Comparer.Instant, x, y);

/** NodaTime's `ZonedDateTime.Comparer.Local.Equals`: same local date/time, any zone. */
export const ZonedDateTimeLocalEqualityComparer: IEqualityComparer<ZonedDateTime | null | undefined> =
  (x, y) => EqualsWith(ZonedDateTime.Comparer.Local, x, y);

/** NodaTime's `ZonedDateTime.Comparer.Instant.Equals`: same instant. */
export const ZonedDateTimeInstantEqualityComparer: IEqualityComparer<ZonedDateTime | null | undefined> =
  (x, y) => EqualsWith(ZonedDateTime.Comparer.Instant, x, y);

/** NodaTime's `Period.NormalizingEqualityComparer`: equal once normalized ({@link Period.Normalize}). */
export const PeriodNormalizingEqualityComparer: IEqualityComparer<Period | null | undefined> =
  (x, y) => EqualsWith(Period.NormalizingEqualityComparer as { Equals(x: Period, y: Period): boolean }, x, y);

// #endregion
