// Ported from NodaTime 3.3.7: src/NodaTime/OffsetDateTime.cs
// Copyright 2012 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import {
  CalendarSystem,
  NodaCultureInfo,
  DateTimeZone,
  Duration,
  Era,
  Instant,
  IsoDayOfWeek,
  LocalDate,
  LocalDateTime,
  LocalTime,
  Offset,
  OffsetDate,
  OffsetDateTimePattern,
  OffsetTime,
  Preconditions,
  YearMonthDay,
  ZonedDateTime,
  ThrowValueOf,
} from "./internal.ts";
import type { IEquatable, IFormatProvider } from "./internal.ts";
import { NanosecondsPerDay } from "./NodaConstants.generated.ts";
import type { ArgumentException } from "./internal.ts";

// Do not nest type X.
// The rule is somewhat subjective, but more importantly these have been available
// publicly for a while, so we can't change them now anyway.

// #region Comparers

let localComparerInstance: OffsetDateTimeComparer | undefined;
let instantComparerInstance: OffsetDateTimeComparer | undefined;

/**
 * Base class for {@link OffsetDateTime} comparers. (NodaTime's `OffsetDateTime.Comparer`.)
 *
 * Use the static properties of this class to obtain instances. This type is exposed so that the
 * same value can be used for both equality and ordering comparisons.
 */
export abstract class OffsetDateTimeComparer {
  // TODO(feature): Should we have a comparer which is calendar-sensitive (so will fail if the calendars are different)
  // but still uses the offset?

  /**
   * Gets a comparer which compares {@link OffsetDateTime} values by their local date/time, without reference to
   * the offset. Comparisons between two values of different calendar systems will fail with {@link ArgumentException}.
   *
   * For example, this comparer considers 2013-03-04T20:21:00+0100 to be later than 2013-03-04T19:21:00-0700 even though
   * the second value represents a later instant in time.
   *
   * This property will return a reference to the same instance every time it is called.
   */
  static get Local(): OffsetDateTimeComparer {
    return (localComparerInstance ??= new OffsetDateTimeLocalComparer());
  }

  /**
   * Returns a comparer which compares {@link OffsetDateTime} values by the instant values obtained by applying the offset to
   * the local date/time, ignoring the calendar system.
   *
   * For example, this comparer considers 2013-03-04T20:21:00+0100 to be earlier than 2013-03-04T19:21:00-0700 even though
   * the second value has a local time which is earlier.
   *
   * This property will return a reference to the same instance every time it is called.
   */
  static get Instant(): OffsetDateTimeComparer {
    return (instantComparerInstance ??= new OffsetDateTimeInstantComparer());
  }

  /**
   * Internal constructor to prevent external classes from deriving from this.
   * (That means we can add more abstract members in the future.)
   * @internal
   */
  constructor() {
  }

  /**
   * Compares two {@link OffsetDateTime} values and returns a value indicating whether one is less than, equal to, or greater than the other.
   * @param x The first value to compare.
   * @param y The second value to compare.
   * @returns A signed integer that indicates the relative values of `x` and `y`: less than zero if `x` is less
   * than `y`; zero if `x` is equal to `y`; greater than zero if `x` is greater than `y`.
   */
  abstract Compare(x: OffsetDateTime, y: OffsetDateTime): number;

  /**
   * Determines whether the specified `OffsetDateTime` values are equal.
   * @param x The first `OffsetDateTime` to compare.
   * @param y The second `OffsetDateTime` to compare.
   * @returns `true` if the specified objects are equal; otherwise, `false`.
   */
  abstract Equals(x: OffsetDateTime, y: OffsetDateTime): boolean;

  // Not ported: GetHashCode(OffsetDateTime)
}

// noda-js: so a null or foreign value throws ArgumentException rather than a TypeError.
function CheckComparerArguments(x: unknown, y: unknown): void {
  Preconditions.CheckArgument(x instanceof OffsetDateTime, "x", "Object must be of type NodaTime.OffsetDateTime.");
  Preconditions.CheckArgument(y instanceof OffsetDateTime, "y", "Object must be of type NodaTime.OffsetDateTime.");
}

/** Implementation for {@link OffsetDateTimeComparer.Local} */
class OffsetDateTimeLocalComparer extends OffsetDateTimeComparer {
  /** @inheritdoc */
  override Compare(x: OffsetDateTime, y: OffsetDateTime): number {
    CheckComparerArguments(x, y);
    Preconditions.CheckArgument(x.Calendar === y.Calendar, "y",
      "Only values with the same calendar system can be compared");
    const dateComparison = x.Calendar.Compare(x.YearMonthDay, y.YearMonthDay);
    if (dateComparison !== 0) {
      return dateComparison;
    }
    return x.NanosecondOfDay < y.NanosecondOfDay ? -1 : x.NanosecondOfDay > y.NanosecondOfDay ? 1 : 0;
  }

  /** @inheritdoc */
  override Equals(x: OffsetDateTime, y: OffsetDateTime): boolean {
    if (!(x instanceof OffsetDateTime) || !(y instanceof OffsetDateTime)) {
      return false;
    }
    return x._localDate.Equals(y._localDate) && x.NanosecondOfDay === y.NanosecondOfDay;
  }
}

/** Implementation for {@link OffsetDateTimeComparer.Instant}. */
class OffsetDateTimeInstantComparer extends OffsetDateTimeComparer {
  /** @inheritdoc */
  override Compare(x: OffsetDateTime, y: OffsetDateTime): number {
    CheckComparerArguments(x, y);
    // TODO(optimization): Optimize cases which are more than 2 days apart, by avoiding the arithmetic?
    return x.ToElapsedTimeSinceEpoch().CompareTo(y.ToElapsedTimeSinceEpoch());
  }

  /** @inheritdoc */
  override Equals(x: OffsetDateTime, y: OffsetDateTime): boolean {
    if (!(x instanceof OffsetDateTime) || !(y instanceof OffsetDateTime)) {
      return false;
    }
    return x.ToElapsedTimeSinceEpoch().Equals(y.ToElapsedTimeSinceEpoch());
  }
}
// #endregion

/**
 * A local date and time in a particular calendar system, combined with an offset from UTC. This is
 * broadly similar to DateTimeOffset in the BCL.
 *
 * Equality is defined in a component-wise fashion: two values are the same if they represent equal date/time values
 * (including being in the same calendar) and equal offsets from UTC.
 * Ordering between offset date/time values has no natural definition; see {@link OffsetDateTime.Comparer} for built-in comparers.
 *
 * A value of this type unambiguously represents both a local time and an instant on the timeline,
 * but does not have a well-defined time zone. This means you cannot reliably know what the local
 * time would be five minutes later, for example. While this doesn't sound terribly useful, it's very common
 * in text representations.
 *
 * The default value of this type is 0001-01-01T00:00:00Z (midnight on January 1st, 1 C.E. with a UTC offset of 0) in the ISO calendar.
 *
 * This type is an immutable value type. See the thread safety section of the user guide for more information.
 */
export class OffsetDateTime implements IEquatable<OffsetDateTime> {
  /** NodaTime's nested `OffsetDateTime.Comparer` class. */
  static readonly Comparer = OffsetDateTimeComparer;

  // Not ported: MinBclOffsetMinutes, MaxBclOffsetMinutes (only used for BCL interop)

  // This is effectively a LocalDateTime and an Offset, but by composing it slightly differently, we can save memory.
  /** @internal */
  readonly _localDate: LocalDate;
  private readonly _offsetTime: OffsetTime;

  /**
   * Constructs a new offset date/time with the given local date and time, and the given offset from UTC.
   * @param localDateTime Local date and time to represent
   * @param offset Offset from UTC
   */
  constructor(localDateTime: LocalDateTime, offset: Offset) {
    this._localDate = localDateTime.Date;
    this._offsetTime = OffsetTime.NewNanosecondOfDayOffsetSeconds(localDateTime.NanosecondOfDay, offset.Seconds);
  }

  /** @internal */
  static NewLocalDateOffsetTime(localDate: LocalDate, offsetTime: OffsetTime): OffsetDateTime {
    const result: { _localDate: LocalDate; _offsetTime: OffsetTime } = Object.create(OffsetDateTime.prototype);
    result._localDate = localDate;
    result._offsetTime = offsetTime;
    return result as unknown as OffsetDateTime;
  }

  /**
   * Optimized conversion from an Instant to an OffsetDateTime in the ISO calendar.
   * This is equivalent to `new OffsetDateTime(new LocalDateTime(instant.Plus(offset)), offset)`
   * but with less overhead.
   * @internal
   */
  static NewInstantOffset(instant: Instant, offset: Offset): OffsetDateTime {
    let days = instant.DaysSinceEpoch;
    let nanoOfDay = instant.NanosecondOfDay + offset.Nanoseconds;
    if (nanoOfDay >= NanosecondsPerDay) {
      days++;
      nanoOfDay -= NanosecondsPerDay;
    } else if (nanoOfDay < 0) {
      days--;
      nanoOfDay += NanosecondsPerDay;
    }
    return OffsetDateTime.NewLocalDateOffsetTime(
      LocalDate.NewDaysSinceEpoch(days),
      OffsetTime.NewNanosecondOfDayOffsetSeconds(nanoOfDay, offset.Seconds));
  }

  /**
   * Optimized conversion from an Instant to an OffsetDateTime in the specified calendar.
   * This is equivalent to `new OffsetDateTime(new LocalDateTime(instant.Plus(offset), calendar), offset)`
   * but with less overhead.
   * @internal
   */
  static NewInstantOffsetCalendar(instant: Instant, offset: Offset, calendar: CalendarSystem): OffsetDateTime {
    let days = instant.DaysSinceEpoch;
    let nanoOfDay = instant.NanosecondOfDay + offset.Nanoseconds;
    if (nanoOfDay >= NanosecondsPerDay) {
      days++;
      nanoOfDay -= NanosecondsPerDay;
    } else if (nanoOfDay < 0) {
      days--;
      nanoOfDay += NanosecondsPerDay;
    }
    return OffsetDateTime.NewLocalDateOffsetTime(
      LocalDate.NewDaysSinceEpochCalendar(days, calendar),
      OffsetTime.NewNanosecondOfDayOffsetSeconds(nanoOfDay, offset.Seconds));
  }

  /** Gets the calendar system associated with this offset date and time. */
  get Calendar(): CalendarSystem {
    return this._localDate.Calendar;
  }

  /**
   * Gets the year of this offset date and time.
   *
   * This returns the "absolute year", so, for the ISO calendar,
   * a value of 0 means 1 BC, for example.
   */
  get Year(): number {
    return this._localDate.Year;
  }

  /** Gets the month of this offset date and time within the year. */
  get Month(): number {
    return this._localDate.Month;
  }

  /** Gets the day of this offset date and time within the month. */
  get Day(): number {
    return this._localDate.Day;
  }

  /** @internal */
  get YearMonthDay(): YearMonthDay {
    return this._localDate.YearMonthDay;
  }

  /** Gets the week day of this offset date and time expressed as an {@link IsoDayOfWeek} value. */
  get DayOfWeek(): IsoDayOfWeek {
    return this._localDate.DayOfWeek;
  }

  /** Gets the year of this offset date and time within the era. */
  get YearOfEra(): number {
    return this._localDate.YearOfEra;
  }

  /** Gets the era of this offset date and time. */
  get Era(): Era {
    return this._localDate.Era;
  }

  /** Gets the day of this offset date and time within the year. */
  get DayOfYear(): number {
    return this._localDate.DayOfYear;
  }

  /** Gets the hour of day of this offset date and time, in the range 0 to 23 inclusive. */
  get Hour(): number {
    return this._offsetTime.Hour;
  }

  /** Gets the hour of the half-day of this offset date and time, in the range 1 to 12 inclusive. */
  get ClockHourOfHalfDay(): number {
    return this._offsetTime.ClockHourOfHalfDay;
  }

  /** Gets the minute of this offset date and time, in the range 0 to 59 inclusive. */
  get Minute(): number {
    return this._offsetTime.Minute;
  }

  /** Gets the second of this offset date and time within the minute, in the range 0 to 59 inclusive. */
  get Second(): number {
    return this._offsetTime.Second;
  }

  /** Gets the millisecond of this offset date and time within the second, in the range 0 to 999 inclusive. */
  get Millisecond(): number {
    return this._offsetTime.Millisecond;
  }

  /** Gets the tick of this offset date and time within the second, in the range 0 to 9,999,999 inclusive. */
  get TickOfSecond(): number {
    return this._offsetTime.TickOfSecond;
  }

  /** Gets the tick of this offset date and time within the day, in the range 0 to 863,999,999,999 inclusive. */
  get TickOfDay(): number {
    return this._offsetTime.TickOfDay;
  }

  /** Gets the nanosecond of this offset date and time within the second, in the range 0 to 999,999,999 inclusive. */
  get NanosecondOfSecond(): number {
    return this._offsetTime.NanosecondOfSecond;
  }

  /** Gets the nanosecond of this offset date and time within the day, in the range 0 to 86,399,999,999,999 inclusive. */
  get NanosecondOfDay(): number {
    return this._offsetTime.NanosecondOfDay;
  }

  /** Returns the local date and time represented within this offset date and time. */
  get LocalDateTime(): LocalDateTime {
    return LocalDateTime.NewDateTime(this.Date, this.TimeOfDay);
  }

  /**
   * Gets the local date represented by this offset date and time.
   *
   * The returned {@link LocalDate}
   * will have the same calendar system and return the same values for each of the date-based calendar
   * properties (Year, MonthOfYear and so on), but will not have any offset information.
   */
  get Date(): LocalDate {
    return this._localDate;
  }

  /**
   * Gets the time portion of this offset date and time.
   *
   * The returned {@link LocalTime} will
   * return the same values for each of the time-based properties (Hour, Minute and so on), but
   * will not have any offset information.
   */
  get TimeOfDay(): LocalTime {
    return LocalTime.NewNanoseconds(this.NanosecondOfDay);
  }

  /** Gets the offset from UTC. */
  get Offset(): Offset {
    return this._offsetTime.Offset;
  }

  /**
   * Converts this offset date and time to an instant in time by subtracting the offset from the local date and time.
   * @returns The instant represented by this offset date and time
   */
  ToInstant(): Instant {
    return Instant.FromUntrustedDuration(this.ToElapsedTimeSinceEpoch());
  }

  /** @internal */
  ToElapsedTimeSinceEpoch(): Duration {
    // Equivalent to LocalDateTime.ToLocalInstant().Minus(offset)
    const days = this._localDate.DaysSinceEpoch;
    const elapsedTime = Duration.NewDaysNanoOfDay(days, this.NanosecondOfDay).MinusSmallNanoseconds(this._offsetTime.OffsetNanoseconds);
    return elapsedTime;
  }

  /**
   * Returns this value as a {@link ZonedDateTime}.
   *
   * This method returns a {@link ZonedDateTime} with the same local date and time as this value, using a
   * fixed time zone with the same offset as the offset for this value.
   *
   * Note that because the resulting `ZonedDateTime` has a fixed time zone, it is generally not useful to
   * use this result for arithmetic operations, as the zone will not adjust to account for daylight savings.
   * @returns A zoned date/time with the same local time and a fixed time zone using the offset from this value.
   */
  InFixedZone(): ZonedDateTime {
    return ZonedDateTime.NewOffsetDateTimeZone(this, DateTimeZone.ForOffset(this.Offset));
  }

  /**
   * Returns this value in ths specified time zone. This method does not expect
   * the offset in the zone to be the same as for the current value; it simply converts
   * this value into an {@link Instant} and finds the {@link ZonedDateTime}
   * for that instant in the specified zone.
   * @param zone The time zone of the new value.
   * @returns The instant represented by this value, in the specified time zone.
   */
  InZone(zone: DateTimeZone): ZonedDateTime {
    Preconditions.CheckNotNull(zone, "zone");
    return this.ToInstant().InZone(zone);
  }

  // Not ported: ToDateTimeOffset, FromDateTimeOffset (BCL interop)

  /**
   * Creates a new OffsetDateTime representing the same physical date, time and offset, but in a different calendar.
   * The returned OffsetDateTime is likely to have different date field values to this one.
   * For example, January 1st 1970 in the Gregorian calendar was December 19th 1969 in the Julian calendar.
   * @param calendar The calendar system to convert this offset date and time to.
   * @returns The converted OffsetDateTime.
   */
  WithCalendar(calendar: CalendarSystem): OffsetDateTime {
    const newDate = this.Date.WithCalendar(calendar);
    return OffsetDateTime.NewLocalDateOffsetTime(newDate, this._offsetTime);
  }

  /**
   * Returns this offset date/time, with the given date adjuster applied to it, maintaining the existing time of day and offset.
   *
   * If the adjuster attempts to construct an
   * invalid date (such as by trying to set a day-of-month of 30 in February), any exception thrown by
   * that construction attempt will be propagated through this method.
   * @param adjuster The adjuster to apply.
   * @returns The adjusted offset date/time.
   */
  With(adjuster: (date: LocalDate) => LocalDate): OffsetDateTime {
    return OffsetDateTime.NewLocalDateOffsetTime(this._localDate.With(adjuster), this._offsetTime);
  }

  /**
   * Returns this date/time, with the given time adjuster applied to it, maintaining the existing date and offset.
   *
   * noda-js: NodaTime's `With(Func<LocalTime, LocalTime>)`, renamed: it can't be told apart from {@link With} at runtime.
   *
   * If the adjuster attempts to construct an invalid time, any exception thrown by
   * that construction attempt will be propagated through this method.
   * @param adjuster The adjuster to apply.
   * @returns The adjusted offset date/time.
   */
  WithTimeAdjuster(adjuster: (time: LocalTime) => LocalTime): OffsetDateTime {
    const newTime = this.TimeOfDay.With(adjuster);
    return OffsetDateTime.NewLocalDateOffsetTime(
      this._localDate, OffsetTime.NewNanosecondOfDayOffsetSeconds(newTime.NanosecondOfDay, this._offsetTime.OffsetSeconds));
  }

  /**
   * Creates a new OffsetDateTime representing the instant in time in the same calendar,
   * but with a different offset. The local date and time is adjusted accordingly.
   * @param offset The new offset to use.
   * @returns The converted OffsetDateTime.
   */
  WithOffset(offset: Offset): OffsetDateTime {
    // Slight change to the normal operation, as it's *just* about plausible that we change day
    // twice in one direction or the other.
    let days = 0;
    let nanos = this._offsetTime.NanosecondOfDay + offset.Nanoseconds - this._offsetTime.OffsetNanoseconds;
    if (nanos >= NanosecondsPerDay) {
      days++;
      nanos -= NanosecondsPerDay;
      if (nanos >= NanosecondsPerDay) {
        days++;
        nanos -= NanosecondsPerDay;
      }
    } else if (nanos < 0) {
      days--;
      nanos += NanosecondsPerDay;
      if (nanos < 0) {
        days--;
        nanos += NanosecondsPerDay;
      }
    }
    return OffsetDateTime.NewLocalDateOffsetTime(
      days === 0 ? this._localDate : this._localDate.PlusDays(days),
      OffsetTime.NewNanosecondOfDayOffsetSeconds(nanos, offset.Seconds));
  }

  /**
   * Constructs a new {@link OffsetDate} from the date and offset of this value,
   * but omitting the time-of-day.
   * @returns A value representing the date and offset aspects of this value.
   */
  ToOffsetDate(): OffsetDate {
    return new OffsetDate(this.Date, this.Offset);
  }

  /**
   * Constructs a new {@link OffsetTime} from the time and offset of this value,
   * but omitting the date.
   * @returns A value representing the time and offset aspects of this value.
   */
  ToOffsetTime(): OffsetTime {
    return this._offsetTime;
  }

  // Not ported: GetHashCode

  /**
   * Compares two {@link OffsetDateTime} values for equality.
   * See the type documentation for a description of equality semantics.
   * @param other The value to compare this offset date/time with.
   * @returns True if the given value is another offset date/time equal to this one; false otherwise.
   */
  Equals(other: OffsetDateTime): boolean;
  /** @inheritDoc */
  Equals(other: unknown): boolean;
  Equals(other: unknown): boolean {
    return other instanceof OffsetDateTime &&
      this._localDate.Equals(other._localDate) && this._offsetTime.Equals(other._offsetTime);
  }

  // Not ported: Deconstruct

  // #region Formatting
  /**
   * Formats the value of the current instance using the specified pattern.
   *
   * noda-js: the default culture is the invariant culture (NodaTime uses the current culture).
   * @param patternText The pattern to use, or null to use the default format pattern ("G").
   * @param formatProvider The format provider to use when formatting the value,
   * or null to use the invariant culture.
   * @returns The value of the current instance in the specified format.
   */
  toString(patternText: string | null = null, formatProvider: IFormatProvider | null = null): string {
    return OffsetDateTimePattern.Patterns.BclSupport.Format(this, patternText, formatProvider ?? NodaCultureInfo.InvariantCulture);
  }
  // #endregion Formatting

  // #region Operators

  /**
   * Adds a duration to an offset date and time.
   *
   * This is an alternative way of calling `operator+(OffsetDateTime, Duration)`.
   * The returned value retains the calendar system and offset of the `offsetDateTime`.
   * @param offsetDateTime The value to add the duration to.
   * @param duration The duration to add
   * @returns A new value with the time advanced by the given duration, in the same calendar system and with the same offset.
   */
  static Add(offsetDateTime: OffsetDateTime, duration: Duration): OffsetDateTime {
    return OffsetDateTime.NewInstantOffset(Instant.Add(offsetDateTime.ToInstant(), duration), offsetDateTime.Offset);
  }

  /**
   * Returns the result of adding a duration to this offset date and time.
   *
   * This is an alternative way of calling `operator+(OffsetDateTime, Duration)`.
   * @param duration The duration to add
   * @returns A new {@link OffsetDateTime} representing the result of the addition.
   */
  Plus(duration: Duration): OffsetDateTime {
    return OffsetDateTime.Add(this, duration);
  }

  /**
   * Returns the result of adding a increment of hours to this offset date and time
   * @param hours The number of hours to add
   * @returns A new {@link OffsetDateTime} representing the result of the addition.
   */
  PlusHours(hours: number): OffsetDateTime {
    return OffsetDateTime.Add(this, Duration.FromHours(hours));
  }

  /**
   * Returns the result of adding an increment of minutes to this offset date and time
   * @param minutes The number of minutes to add
   * @returns A new {@link OffsetDateTime} representing the result of the addition.
   */
  PlusMinutes(minutes: number): OffsetDateTime {
    return OffsetDateTime.Add(this, Duration.FromMinutes(minutes));
  }

  /**
   * Returns the result of adding an increment of seconds to this offset date and time
   * @param seconds The number of seconds to add
   * @returns A new {@link OffsetDateTime} representing the result of the addition.
   */
  PlusSeconds(seconds: number): OffsetDateTime {
    return OffsetDateTime.Add(this, Duration.FromSeconds(seconds));
  }

  /**
   * Returns the result of adding an increment of milliseconds to this offset date and time
   * @param milliseconds The number of milliseconds to add
   * @returns A new {@link OffsetDateTime} representing the result of the addition.
   */
  PlusMilliseconds(milliseconds: number): OffsetDateTime {
    return OffsetDateTime.Add(this, Duration.FromMilliseconds(milliseconds));
  }

  /**
   * Returns the result of adding an increment of ticks to this offset date and time
   * @param ticks The number of ticks to add
   * @returns A new {@link OffsetDateTime} representing the result of the addition.
   */
  PlusTicks(ticks: number | string): OffsetDateTime {
    return OffsetDateTime.Add(this, Duration.FromTicks(ticks));
  }

  /**
   * Returns the result of adding an increment of nanoseconds to this offset date and time
   * @param nanoseconds The number of nanoseconds to add
   * @returns A new {@link OffsetDateTime} representing the result of the addition.
   */
  PlusNanoseconds(nanoseconds: number | string): OffsetDateTime {
    return OffsetDateTime.Add(this, Duration.FromNanoseconds(nanoseconds));
  }

  /**
   * Subtracts a duration from an offset date and time, or one offset date and time from another.
   *
   * This is an alternative way of calling `operator-(OffsetDateTime, Duration)` or
   * `operator-(OffsetDateTime, OffsetDateTime)`.
   *
   * When subtracting a duration, the returned value retains the calendar system and offset of `offsetDateTime`,
   * with the time "rewound" by the given duration.
   *
   * When subtracting an offset date and time, the result is the elapsed duration from `start` to `end`. This is
   * equivalent to `end.ToInstant() - start.ToInstant()`; in particular:
   * - The two values can use different calendar systems
   * - The two values can have different UTC offsets
   * @param end The value to subtract from; if this is later than `start` then the result will be positive.
   * @param start The duration or offset date and time to subtract from `end`.
   * @returns The adjusted value, or the elapsed duration from `start` to `end`.
   */
  static Subtract(end: OffsetDateTime, start: Duration): OffsetDateTime;
  static Subtract(end: OffsetDateTime, start: OffsetDateTime): Duration;
  static Subtract(end: OffsetDateTime, start: Duration | OffsetDateTime): OffsetDateTime | Duration {
    if (start instanceof OffsetDateTime) {
      return Instant.Subtract(end.ToInstant(), start.ToInstant());
    }
    return OffsetDateTime.NewInstantOffset(Instant.Subtract(end.ToInstant(), start), end.Offset);
  }

  /**
   * Returns the result of subtracting a duration from this offset date and time, for a fluent alternative to
   * `operator-(OffsetDateTime, Duration)`
   * @param duration The duration to subtract
   * @returns A new {@link OffsetDateTime} representing the result of the subtraction.
   */
  Minus(duration: Duration): OffsetDateTime;
  /**
   * Returns the result of subtracting another offset date and time from this one, resulting in the elapsed duration
   * between the two instants represented in the values.
   *
   * This is an alternative way of calling `operator-(OffsetDateTime, OffsetDateTime)`.
   * @param other The offset date and time to subtract from this one.
   * @returns The elapsed duration from `other` to this value.
   */
  Minus(other: OffsetDateTime): Duration;
  Minus(other: Duration | OffsetDateTime): OffsetDateTime | Duration {
    return other instanceof OffsetDateTime ? OffsetDateTime.Subtract(this, other) : OffsetDateTime.Subtract(this, other);
  }
  // #endregion

  // #region XML serialization
  // Not ported: AddSchema, IXmlSerializable members (XML serialization)
  // #endregion

  // #region JSON (noda-js)
  /** Formats this value with {@link OffsetDateTimePattern.Rfc3339}, as NodaTime.Serialization.SystemTextJson does. */
  toJSON(): string {
    return OffsetDateTimePattern.Rfc3339.Format(this);
  }

  /**
   * Parses a value written by {@link toJSON}.
   *
   * JSON doesn't record the calendar system: the date is read in `calendar` (the ISO calendar if omitted), as
   * NodaTime.Serialization.SystemTextJson reads it with a converter whose pattern uses that calendar.
   * @throws {UnparsableValueException} The text could not be parsed.
   */
  static fromJSON(json: string, calendar?: CalendarSystem): OffsetDateTime {
    const pattern = OffsetDateTimePattern.Rfc3339;
    return (calendar === undefined ? pattern : pattern.WithCalendar(calendar)).Parse(json).Value;
  }
  // #endregion

  /** Throws a TypeError: use {@link Equals} or {@link OffsetDateTime.Comparer} instead of relational operators. */
  valueOf(): never {
    return ThrowValueOf("OffsetDateTime");
  }
}
