// noda-js: new code. noda-js/linq's ordering comparers (natural order, and NodaTime's comparers).
// null and undefined sort first; values in different calendars throw ArgumentException, as in NodaTime.

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

/** Orders {@link AnnualDate} values ({@link AnnualDate.CompareTo}). */
export const AnnualDateComparer: IComparer<AnnualDate | null | undefined> =
  (x, y) => CompareComparable(AnnualDate, x, y);

/** Orders {@link Duration} values ({@link Duration.CompareTo}). */
export const DurationComparer: IComparer<Duration | null | undefined> =
  (x, y) => CompareComparable(Duration, x, y);

/** Orders {@link Instant} values ({@link Instant.CompareTo}). */
export const InstantComparer: IComparer<Instant | null | undefined> =
  (x, y) => CompareComparable(Instant, x, y);

/** Orders {@link LocalDate} values ({@link LocalDate.CompareTo}). */
export const LocalDateComparer: IComparer<LocalDate | null | undefined> =
  (x, y) => CompareComparable(LocalDate, x, y);

/** Orders {@link LocalDateTime} values ({@link LocalDateTime.CompareTo}). */
export const LocalDateTimeComparer: IComparer<LocalDateTime | null | undefined> =
  (x, y) => CompareComparable(LocalDateTime, x, y);

/** Orders {@link LocalTime} values ({@link LocalTime.CompareTo}). */
export const LocalTimeComparer: IComparer<LocalTime | null | undefined> =
  (x, y) => CompareComparable(LocalTime, x, y);

/** Orders {@link Offset} values ({@link Offset.CompareTo}). */
export const OffsetComparer: IComparer<Offset | null | undefined> =
  (x, y) => CompareComparable(Offset, x, y);

/** Orders {@link YearMonth} values ({@link YearMonth.CompareTo}). */
export const YearMonthComparer: IComparer<YearMonth | null | undefined> =
  (x, y) => CompareComparable(YearMonth, x, y);

// #endregion

// #region NodaTime's comparers

/** NodaTime's `OffsetDateTime.Comparer.Local`: by local date/time, ignoring the offset. */
export const OffsetDateTimeLocalComparer: IComparer<OffsetDateTime | null | undefined> =
  (x, y) => CompareWith(OffsetDateTime.Comparer.Local, x, y);

/** NodaTime's `OffsetDateTime.Comparer.Instant`: by instant. */
export const OffsetDateTimeInstantComparer: IComparer<OffsetDateTime | null | undefined> =
  (x, y) => CompareWith(OffsetDateTime.Comparer.Instant, x, y);

/** NodaTime's `ZonedDateTime.Comparer.Local`: by local date/time, ignoring zone and offset. */
export const ZonedDateTimeLocalComparer: IComparer<ZonedDateTime | null | undefined> =
  (x, y) => CompareWith(ZonedDateTime.Comparer.Local, x, y);

/** NodaTime's `ZonedDateTime.Comparer.Instant`: by instant. */
export const ZonedDateTimeInstantComparer: IComparer<ZonedDateTime | null | undefined> =
  (x, y) => CompareWith(ZonedDateTime.Comparer.Instant, x, y);

/**
 * NodaTime's `Period.CreateComparer(baseDateTime)`: orders {@link Period} values by adding each to `baseDateTime`.
 * @param baseDateTime The base local date/time.
 * @returns The new comparer.
 */
export const CreatePeriodComparer: (baseDateTime: LocalDateTime) => IComparer<Period | null | undefined> =
  (baseDateTime) => {
    const comparer: { Compare(x: Period, y: Period): number } = Period.CreateComparer(baseDateTime);
    return (x, y) => CompareWith(comparer, x, y);
  };

// #endregion
