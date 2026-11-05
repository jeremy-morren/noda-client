// Ported from NodaTime 3.3.0: src/NodaTime/LocalDateTime.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import {
  CalendarSystem,
  NodaCultureInfo,
  DateTimeZone,
  Era,
  Int64,
  IsoDayOfWeek,
  LocalDate,
  LocalDateTimePattern,
  LocalInstant,
  LocalTime,
  Offset,
  OffsetDateTime,
  OffsetTime,
  Period,
  Preconditions,
  TimePeriodField,
  ZonedDateTime,
  ThrowValueOf,
} from "./internal.ts";
import type { IComparable, IEquatable, IFormatProvider, ZoneLocalMappingResolver } from "./internal.ts";
import type { ArgumentError, Resolvers } from "./internal.ts";

// TODO(feature): Calendar-neutral comparer.

/**
 * A date and time in a particular calendar system. A LocalDateTime value does not represent an
 * instant on the global time line, because it has no associated time zone: "November 12th 2009 7pm, ISO calendar"
 * occurred at different instants for different people around the world.
 *
 * This type defaults to using the ISO calendar system unless a different calendar system is
 * specified.
 *
 * Values can freely be compared for equality: a value in a different calendar system is not equal to
 * a value in a different calendar system. However, ordering comparisons (either via the {@link CompareTo} method
 * or via operators) fail with {@link ArgumentError}; attempting to compare values in different calendars
 * almost always indicates a bug in the calling code.
 *
 * The default value of this type is 0001-01-01T00:00:00 (midnight on January 1st, 1 C.E.) in the ISO calendar.
 *
 * This type is an immutable value type. See the thread safety section of the user guide for more information.
 */
export class LocalDateTime implements IEquatable<LocalDateTime>, IComparable<LocalDateTime> {
  /**
   * The maximum (latest) date and time representable in the ISO calendar system.
   * This is a nanosecond before midnight at the end of {@link LocalDate.MaxIsoValue}.
   */
  static get MaxIsoValue(): LocalDateTime {
    return LocalDate.MaxIsoValue.At(LocalTime.MaxValue);
  }

  /**
   * The minimum (earliest) date and time representable in the ISO calendar system.
   * This is midnight at the start of {@link LocalDate.MinIsoValue}.
   */
  static get MinIsoValue(): LocalDateTime {
    return LocalDate.MinIsoValue.At(LocalTime.MinValue);
  }

  // noda-js: NodaTime's "date" field; renamed as it would clash with the Date property.
  private readonly _date: LocalDate;
  private readonly _time: LocalTime;

  /**
   * Initializes a new instance of the {@link LocalDateTime} struct using the ISO
   * calendar system.
   * @param localInstant The local instant.
   * @returns The resulting date/time.
   * @internal
   */
  static NewLocalInstant(localInstant: LocalInstant): LocalDateTime {
    return LocalDateTime.NewDateTime(
      LocalDate.NewDaysSinceEpoch(localInstant.DaysSinceEpoch),
      LocalTime.NewNanoseconds(localInstant.NanosecondOfDay));
  }

  /**
   * Initializes a new instance of the {@link LocalDateTime} struct using the ISO calendar system.
   * @param year The year. This is the "absolute year",
   * so a value of 0 means 1 BC, for example.
   * @param month The month of year.
   * @param day The day of month.
   * @param hour The hour.
   * @param minute The minute.
   * @throws {ArgumentOutOfRangeError} The parameters do not form a valid date/time.
   */
  constructor(year: number, month: number, day: number, hour: number, minute: number);
  /**
   * Initializes a new instance of the {@link LocalDateTime} struct.
   * @param year The year. This is the "absolute year", so, for
   * the ISO calendar, a value of 0 means 1 BC, for example.
   * @param month The month of year.
   * @param day The day of month.
   * @param hour The hour.
   * @param minute The minute.
   * @param calendar The calendar.
   * @throws {ArgumentOutOfRangeError} The parameters do not form a valid date/time.
   */
  constructor(year: number, month: number, day: number, hour: number, minute: number, calendar: CalendarSystem);
  /**
   * Initializes a new instance of the {@link LocalDateTime} struct using the ISO calendar system.
   * @param year The year. This is the "absolute year",
   * so a value of 0 means 1 BC, for example.
   * @param month The month of year.
   * @param day The day of month.
   * @param hour The hour.
   * @param minute The minute.
   * @param second The second.
   * @throws {ArgumentOutOfRangeError} The parameters do not form a valid date/time.
   */
  constructor(year: number, month: number, day: number, hour: number, minute: number, second: number);
  /**
   * Initializes a new instance of the {@link LocalDateTime} struct.
   * @param year The year. This is the "absolute year", so, for
   * the ISO calendar, a value of 0 means 1 BC, for example.
   * @param month The month of year.
   * @param day The day of month.
   * @param hour The hour.
   * @param minute The minute.
   * @param second The second.
   * @param calendar The calendar.
   * @throws {ArgumentOutOfRangeError} The parameters do not form a valid date/time.
   */
  constructor(year: number, month: number, day: number, hour: number, minute: number, second: number, calendar: CalendarSystem);
  /**
   * Initializes a new instance of the {@link LocalDateTime} struct using the ISO calendar system.
   * @param year The year. This is the "absolute year",
   * so a value of 0 means 1 BC, for example.
   * @param month The month of year.
   * @param day The day of month.
   * @param hour The hour.
   * @param minute The minute.
   * @param second The second.
   * @param millisecond The millisecond.
   * @throws {ArgumentOutOfRangeError} The parameters do not form a valid date/time.
   */
  constructor(year: number, month: number, day: number, hour: number, minute: number, second: number, millisecond: number);
  /**
   * Initializes a new instance of the {@link LocalDateTime} struct.
   * @param year The year. This is the "absolute year", so, for
   * the ISO calendar, a value of 0 means 1 BC, for example.
   * @param month The month of year.
   * @param day The day of month.
   * @param hour The hour.
   * @param minute The minute.
   * @param second The second.
   * @param millisecond The millisecond.
   * @param calendar The calendar.
   * @throws {ArgumentOutOfRangeError} The parameters do not form a valid date/time.
   */
  constructor(year: number, month: number, day: number, hour: number, minute: number, second: number, millisecond: number, calendar: CalendarSystem);
  constructor(year: number, month: number, day: number, hour: number, minute: number, ...rest: (number | CalendarSystem)[]) {
    // noda-js: one implementation covers all six constructors.
    let calendar: CalendarSystem | null = null;
    if (rest.length > 0 && typeof rest[rest.length - 1] !== "number") {
      calendar = rest.pop() as CalendarSystem;
    }
    const [second, millisecond] = rest as number[];
    this._date = calendar === null
      ? new LocalDate(year, month, day)
      : new LocalDate(year, month, day, calendar);
    this._time = second === undefined ? new LocalTime(hour, minute)
      : millisecond === undefined ? new LocalTime(hour, minute, second)
      : new LocalTime(hour, minute, second, millisecond);
  }

  /** @internal */
  static NewDateTime(date: LocalDate, time: LocalTime): LocalDateTime {
    const result: { _date: LocalDate; _time: LocalTime } = Object.create(LocalDateTime.prototype);
    result._date = date;
    result._time = time;
    return result as unknown as LocalDateTime;
  }

  /** Gets the calendar system associated with this local date and time. */
  get Calendar(): CalendarSystem {
    return this._date.Calendar;
  }

  /**
   * Gets the year of this local date and time.
   *
   * This returns the "absolute year", so, for the ISO calendar,
   * a value of 0 means 1 BC, for example.
   */
  get Year(): number {
    return this._date.Year;
  }

  /** Gets the year of this local date and time within its era. */
  get YearOfEra(): number {
    return this._date.YearOfEra;
  }

  /** Gets the era of this local date and time. */
  get Era(): Era {
    return this._date.Era;
  }

  /** Gets the month of this local date and time within the year. */
  get Month(): number {
    return this._date.Month;
  }

  /** Gets the day of this local date and time within the year. */
  get DayOfYear(): number {
    return this._date.DayOfYear;
  }

  /** Gets the day of this local date and time within the month. */
  get Day(): number {
    return this._date.Day;
  }

  /** Gets the week day of this local date and time expressed as an {@link IsoDayOfWeek} value. */
  get DayOfWeek(): IsoDayOfWeek {
    return this._date.DayOfWeek;
  }

  /** Gets the hour of day of this local date and time, in the range 0 to 23 inclusive. */
  get Hour(): number {
    return this._time.Hour;
  }

  /** Gets the hour of the half-day of this local date and time, in the range 1 to 12 inclusive. */
  get ClockHourOfHalfDay(): number {
    return this._time.ClockHourOfHalfDay;
  }

  /** Gets the minute of this local date and time, in the range 0 to 59 inclusive. */
  get Minute(): number {
    return this._time.Minute;
  }

  /** Gets the second of this local date and time within the minute, in the range 0 to 59 inclusive. */
  get Second(): number {
    return this._time.Second;
  }

  /** Gets the millisecond of this local date and time within the second, in the range 0 to 999 inclusive. */
  get Millisecond(): number {
    return this._time.Millisecond;
  }

  /** Gets the tick of this local time within the second, in the range 0 to 9,999,999 inclusive. */
  get TickOfSecond(): number {
    return this._time.TickOfSecond;
  }

  /** Gets the tick of this local date and time within the day, in the range 0 to 863,999,999,999 inclusive. */
  get TickOfDay(): number {
    return this._time.TickOfDay;
  }

  /** Gets the nanosecond of this local time within the second, in the range 0 to 999,999,999 inclusive. */
  get NanosecondOfSecond(): number {
    return this._time.NanosecondOfSecond;
  }

  /** Gets the nanosecond of this local date and time within the day, in the range 0 to 86,399,999,999,999 inclusive. */
  get NanosecondOfDay(): number {
    return this._time.NanosecondOfDay;
  }

  /** Gets the time portion of this local date and time as a {@link LocalTime}. */
  get TimeOfDay(): LocalTime {
    return this._time;
  }

  /** Gets the date portion of this local date and time as a {@link LocalDate} in the same calendar system as this value. */
  get Date(): LocalDate {
    return this._date;
  }

  // Not ported: ToDateTimeUnspecified (BCL interop)

  /** @internal */
  ToLocalInstant(): LocalInstant {
    return LocalInstant.NewDaysNanoOfDay(this._date.DaysSinceEpoch, this._time.NanosecondOfDay);
  }

  // Not ported: FromDateTime (BCL interop)

  // #region Implementation of IEquatable<LocalDateTime>
  /**
   * Indicates whether the current object is equal to another object of the same type.
   * See the type documentation for a description of equality semantics.
   * @param other An object to compare with this object.
   * @returns true if `other` is a local date/time equal to this one; otherwise, false.
   *
   * noda-js: covers both `IEquatable<LocalDateTime>.Equals(LocalDateTime)` and `object.Equals(object)`.
   */
  Equals(other: LocalDateTime): boolean;
  /** @inheritDoc */
  Equals(other: unknown): boolean;
  Equals(other: unknown): boolean {
    return other instanceof LocalDateTime && this._date.Equals(other._date) && this._time.Equals(other._time);
  }
  // #endregion

  // #region Operators
  /**
   * Indicates whether this date/time is earlier, later or the same as another one.
   * See the type documentation for a description of ordering semantics.
   *
   * noda-js: this also covers the non-generic IComparable.CompareTo: a null argument compares as less than this value.
   * @param other The other local date/time to compare with this value.
   * @throws {ArgumentError} The calendar system of `other` is not the
   * same as the calendar system of this value, or `other` is non-null but not a {@link LocalDateTime}.
   * @returns A value less than zero if this date/time is earlier than `other`;
   * zero if this date/time is the same as `other`; a value greater than zero if this date/time is
   * later than `other` (or `other` is null).
   */
  CompareTo(other: LocalDateTime | null): number;
  /** @inheritDoc */
  CompareTo(other: unknown): number;
  CompareTo(other: unknown): number {
    if (other === null || other === undefined) {
      return 1;
    }
    Preconditions.CheckArgument(other instanceof LocalDateTime, "obj", "Object must be of type NodaTime.LocalDateTime.");
    const that = other as LocalDateTime;
    // This will check calendars...
    const dateComparison = this._date.CompareTo(that._date);
    if (dateComparison !== 0) {
      return dateComparison;
    }
    return this._time.CompareTo(that._time);
  }

  /**
   * Add the specified period to the date and time.
   * Fields are added in descending order of significance (years first, then months, and so on).
   * Friendly alternative to `operator+()`.
   * @param localDateTime Initial local date and time
   * @param period Period to add
   * @returns The resulting local date and time
   */
  static Add(localDateTime: LocalDateTime, period: Period): LocalDateTime {
    return localDateTime.Plus(period);
  }

  /**
   * Adds a period to this local date/time.
   * Fields are added in descending order of significance (years first, then months, and so on).
   * @param period Period to add
   * @returns The resulting local date and time
   */
  Plus(period: Period): LocalDateTime {
    Preconditions.CheckNotNull(period, "period");
    const extraDays = { value: 0 };
    let time = this.TimeOfDay;
    // noda-js: the exact values of the long-valued properties, which may exceed 2^53.
    time = TimePeriodField.Hours.Add(time, period.ExactHours, extraDays);
    time = TimePeriodField.Minutes.Add(time, period.ExactMinutes, extraDays);
    time = TimePeriodField.Seconds.Add(time, period.ExactSeconds, extraDays);
    time = TimePeriodField.Milliseconds.Add(time, period.ExactMilliseconds, extraDays);
    time = TimePeriodField.Ticks.Add(time, period.ExactTicks, extraDays);
    time = TimePeriodField.Nanoseconds.Add(time, period.ExactNanoseconds, extraDays);
    const date = this.Date.PlusYears(period.Years)
      .PlusMonths(period.Months)
      .PlusWeeks(period.Weeks)
      .PlusDays(period.Days + extraDays.value);
    return LocalDateTime.NewDateTime(date, time);
  }

  /**
   * Subtracts the specified period from the date and time, or one date/time from another.
   * Friendly alternative to `operator-()`.
   *
   * When subtracting a date/time, this is simply a convenience method for calling
   * {@link Period.Between} with `rhs` and `lhs`; the calendar systems of the two date/times must be the same.
   * @param lhs Initial local date and time
   * @param rhs Period or date/time to subtract
   * @returns The resulting local date and time, or the period between the two date/times.
   */
  static Subtract(lhs: LocalDateTime, rhs: Period): LocalDateTime;
  static Subtract(lhs: LocalDateTime, rhs: LocalDateTime): Period;
  static Subtract(lhs: LocalDateTime, rhs: Period | LocalDateTime): LocalDateTime | Period {
    return rhs instanceof LocalDateTime ? Period.Between(rhs, lhs) : lhs.Minus(rhs);
  }

  /**
   * Subtracts a period from a local date/time.
   * Fields are subtracted in descending order of significance (years first, then months, and so on).
   * @param period Period to subtract
   * @returns The resulting local date and time
   */
  Minus(period: Period): LocalDateTime;
  /**
   * Subtracts the specified date/time from this date/time, returning the result as a {@link Period}.
   * Fluent alternative to `operator-()`.
   *
   * The specified date/time must be in the same calendar system as this.
   * @param localDateTime The date/time to subtract from this
   * @returns The difference between the specified date/time and this one
   */
  Minus(localDateTime: LocalDateTime): Period;
  Minus(periodOrLocalDateTime: Period | LocalDateTime): LocalDateTime | Period {
    if (periodOrLocalDateTime instanceof LocalDateTime) {
      return Period.Between(periodOrLocalDateTime, this);
    }
    const period = periodOrLocalDateTime;
    Preconditions.CheckNotNull(period, "period");
    const extraDays = { value: 0 };
    let time = this.TimeOfDay;
    // noda-js: the exact values of the long-valued properties, which may exceed 2^53.
    time = TimePeriodField.Hours.Add(time, Int64.Negate(period.ExactHours), extraDays);
    time = TimePeriodField.Minutes.Add(time, Int64.Negate(period.ExactMinutes), extraDays);
    time = TimePeriodField.Seconds.Add(time, Int64.Negate(period.ExactSeconds), extraDays);
    time = TimePeriodField.Milliseconds.Add(time, Int64.Negate(period.ExactMilliseconds), extraDays);
    time = TimePeriodField.Ticks.Add(time, Int64.Negate(period.ExactTicks), extraDays);
    time = TimePeriodField.Nanoseconds.Add(time, Int64.Negate(period.ExactNanoseconds), extraDays);
    const date = this.Date.PlusYears(-period.Years)
      .PlusMonths(-period.Months)
      .PlusWeeks(-period.Weeks)
      .PlusDays(extraDays.value - period.Days);
    return LocalDateTime.NewDateTime(date, time);
  }
  // #endregion

  // #region object overrides
  // Not ported: GetHashCode
  // #endregion

  /**
   * Returns this date/time, with the given date adjuster applied to it, maintaining the existing time of day.
   *
   * If the adjuster attempts to construct an
   * invalid date (such as by trying to set a day-of-month of 30 in February), any exception thrown by
   * that construction attempt will be propagated through this method.
   * @param adjuster The adjuster to apply.
   * @returns The adjusted date/time.
   */
  With(adjuster: (date: LocalDate) => LocalDate): LocalDateTime {
    return this._date.With(adjuster).At(this._time);
  }

  /**
   * Returns this date/time, with the given time adjuster applied to it, maintaining the existing date.
   *
   * noda-js: this is NodaTime's `With(Func<LocalTime, LocalTime>)` overload, renamed as it can't be distinguished
   * at runtime from the date adjuster overload ({@link With}).
   *
   * If the adjuster attempts to construct an invalid time, any exception thrown by
   * that construction attempt will be propagated through this method.
   * @param adjuster The adjuster to apply.
   * @returns The adjusted date/time.
   */
  WithTimeAdjuster(adjuster: (time: LocalTime) => LocalTime): LocalDateTime {
    return this._date.At(this._time.With(adjuster));
  }

  /**
   * Creates a new LocalDateTime representing the same physical date and time, but in a different calendar.
   * The returned LocalDateTime is likely to have different date field values to this one.
   * For example, January 1st 1970 in the Gregorian calendar was December 19th 1969 in the Julian calendar.
   * @param calendar The calendar system to convert this local date to.
   * @returns The converted LocalDateTime.
   */
  WithCalendar(calendar: CalendarSystem): LocalDateTime {
    Preconditions.CheckNotNull(calendar, "calendar");
    return LocalDateTime.NewDateTime(this._date.WithCalendar(calendar), this._time);
  }

  /**
   * Returns a new LocalDateTime representing the current value with the given number of years added.
   *
   * If the resulting date is invalid, lower fields (typically the day of month) are reduced to find a valid value.
   * For example, adding one year to February 29th 2012 will return February 28th 2013; subtracting one year from
   * February 29th 2012 will return February 28th 2011.
   * @param years The number of years to add
   * @returns The current value plus the given number of years.
   */
  PlusYears(years: number): LocalDateTime {
    return LocalDateTime.NewDateTime(this._date.PlusYears(years), this._time);
  }

  /**
   * Returns a new LocalDateTime representing the current value with the given number of months added.
   *
   * This method does not try to maintain the year of the current value, so adding four months to a value in
   * October will result in a value in the following February.
   *
   * If the resulting date is invalid, the day of month is reduced to find a valid value.
   * For example, adding one month to January 30th 2011 will return February 28th 2011; subtracting one month from
   * March 30th 2011 will return February 28th 2011.
   * @param months The number of months to add
   * @returns The current value plus the given number of months.
   */
  PlusMonths(months: number): LocalDateTime {
    return LocalDateTime.NewDateTime(this._date.PlusMonths(months), this._time);
  }

  /**
   * Returns a new LocalDateTime representing the current value with the given number of days added.
   *
   * This method does not try to maintain the month or year of the current value, so adding 3 days to a value on January 30th
   * will result in a value on February 2nd.
   * @param days The number of days to add
   * @returns The current value plus the given number of days.
   */
  PlusDays(days: number): LocalDateTime {
    return LocalDateTime.NewDateTime(this._date.PlusDays(days), this._time);
  }

  /**
   * Returns a new LocalDateTime representing the current value with the given number of weeks added.
   * @param weeks The number of weeks to add
   * @returns The current value plus the given number of weeks.
   */
  PlusWeeks(weeks: number): LocalDateTime {
    return LocalDateTime.NewDateTime(this._date.PlusWeeks(weeks), this._time);
  }

  /**
   * Returns a new LocalDateTime representing the current value with the given number of hours added.
   * @param hours The number of hours to add
   * @returns The current value plus the given number of hours.
   */
  PlusHours(hours: number | string): LocalDateTime {
    return TimePeriodField.Hours.Add(this, Int64.FromArgument(hours, "hours"));
  }

  /**
   * Returns a new LocalDateTime representing the current value with the given number of minutes added.
   * @param minutes The number of minutes to add
   * @returns The current value plus the given number of minutes.
   */
  PlusMinutes(minutes: number | string): LocalDateTime {
    return TimePeriodField.Minutes.Add(this, Int64.FromArgument(minutes, "minutes"));
  }

  /**
   * Returns a new LocalDateTime representing the current value with the given number of seconds added.
   * @param seconds The number of seconds to add
   * @returns The current value plus the given number of seconds.
   */
  PlusSeconds(seconds: number | string): LocalDateTime {
    return TimePeriodField.Seconds.Add(this, Int64.FromArgument(seconds, "seconds"));
  }

  /**
   * Returns a new LocalDateTime representing the current value with the given number of milliseconds added.
   * @param milliseconds The number of milliseconds to add
   * @returns The current value plus the given number of milliseconds.
   */
  PlusMilliseconds(milliseconds: number | string): LocalDateTime {
    return TimePeriodField.Milliseconds.Add(this, Int64.FromArgument(milliseconds, "milliseconds"));
  }

  /**
   * Returns a new LocalDateTime representing the current value with the given number of ticks added.
   * @param ticks The number of ticks to add
   * @returns The current value plus the given number of ticks.
   */
  PlusTicks(ticks: number | string): LocalDateTime {
    return TimePeriodField.Ticks.Add(this, Int64.FromArgument(ticks, "ticks"));
  }

  /**
   * Returns a new LocalDateTime representing the current value with the given number of nanoseconds added.
   * @param nanoseconds The number of nanoseconds to add
   * @returns The current value plus the given number of nanoseconds.
   */
  PlusNanoseconds(nanoseconds: number | string): LocalDateTime {
    return TimePeriodField.Nanoseconds.Add(this, Int64.FromArgument(nanoseconds, "nanoseconds"));
  }

  /**
   * Returns the next {@link LocalDateTime} falling on the specified {@link IsoDayOfWeek},
   * at the same time of day as this value.
   * This is a strict "next" - if this value on already falls on the target
   * day of the week, the returned value will be a week later.
   * @param targetDayOfWeek The ISO day of the week to return the next date of.
   * @returns The next {@link LocalDateTime} falling on the specified day of the week.
   * @throws {InvalidOperationError} The underlying calendar doesn't use ISO days of the week.
   * @throws {ArgumentOutOfRangeError} `targetDayOfWeek` is not a valid day of the
   * week (Monday to Sunday).
   */
  Next(targetDayOfWeek: IsoDayOfWeek): LocalDateTime {
    return LocalDateTime.NewDateTime(this._date.Next(targetDayOfWeek), this._time);
  }

  /**
   * Returns the previous {@link LocalDateTime} falling on the specified {@link IsoDayOfWeek},
   * at the same time of day as this value.
   * This is a strict "previous" - if this value on already falls on the target
   * day of the week, the returned value will be a week earlier.
   * @param targetDayOfWeek The ISO day of the week to return the previous date of.
   * @returns The previous {@link LocalDateTime} falling on the specified day of the week.
   * @throws {InvalidOperationError} The underlying calendar doesn't use ISO days of the week.
   * @throws {ArgumentOutOfRangeError} `targetDayOfWeek` is not a valid day of the
   * week (Monday to Sunday).
   */
  Previous(targetDayOfWeek: IsoDayOfWeek): LocalDateTime {
    return LocalDateTime.NewDateTime(this._date.Previous(targetDayOfWeek), this._time);
  }

  /**
   * Returns an {@link OffsetDateTime} for this local date/time with the given offset.
   *
   * This method is purely a convenient alternative to calling the {@link OffsetDateTime} constructor directly.
   * @param offset The offset to apply.
   * @returns The result of this local date/time offset by the given amount.
   */
  WithOffset(offset: Offset): OffsetDateTime {
    return OffsetDateTime.NewLocalDateOffsetTime(this._date, new OffsetTime(this._time, offset));
  }

  /**
   * Returns the mapping of this local date/time within {@link DateTimeZone.Utc}.
   *
   * As UTC is a fixed time zone, there is no chance that this local date/time is ambiguous or skipped.
   * @returns The result of mapping this local date/time in UTC.
   */
  InUtc(): ZonedDateTime {
    // Use the internal constructors to avoid validation. We know it will be fine.
    return ZonedDateTime.NewOffsetDateTimeZone(
      OffsetDateTime.NewLocalDateOffsetTime(this._date, OffsetTime.NewNanosecondOfDayZeroOffset(this._time.NanosecondOfDay)),
      DateTimeZone.Utc);
  }

  /**
   * Returns the mapping of this local date/time within the given {@link DateTimeZone},
   * with "strict" rules applied such that an exception is thrown if either the mapping is
   * ambiguous or the time is skipped.
   *
   * See {@link InZoneLeniently} and {@link InZone} for alternative ways to map a local time to a
   * specific instant.
   * This is solely a convenience method for calling {@link DateTimeZone.AtStrictly}.
   * @param zone The time zone in which to map this local date/time.
   * @throws {SkippedTimeError} This local date/time is skipped in the given time zone.
   * @throws {AmbiguousTimeError} This local date/time is ambiguous in the given time zone.
   * @returns The result of mapping this local date/time in the given time zone.
   */
  InZoneStrictly(zone: DateTimeZone): ZonedDateTime {
    Preconditions.CheckNotNull(zone, "zone");
    return zone.AtStrictly(this);
  }

  /**
   * Returns the mapping of this local date/time within the given {@link DateTimeZone},
   * with "lenient" rules applied such that ambiguous values map to the earlier of the alternatives, and
   * "skipped" values are shifted forward by the duration of the "gap".
   *
   * See {@link InZoneStrictly} and {@link InZone} for alternative ways to map a local time to a
   * specific instant.
   * This is solely a convenience method for calling {@link DateTimeZone.AtLeniently}.
   *
   * Note: The behavior of this method was changed in version 2.0 to fit the most commonly seen real-world
   * usage pattern.  Previous versions returned the later instance of ambiguous values, and returned the start of
   * the zone interval after the gap for skipped value.  The previous functionality can still be used if desired,
   * by using {@link InZone} and passing a resolver that combines the
   * {@link Resolvers.ReturnLater} and {@link Resolvers.ReturnStartOfIntervalAfter} resolvers.
   * @param zone The time zone in which to map this local date/time.
   * @returns The result of mapping this local date/time in the given time zone.
   */
  InZoneLeniently(zone: DateTimeZone): ZonedDateTime {
    Preconditions.CheckNotNull(zone, "zone");
    return zone.AtLeniently(this);
  }

  /**
   * Resolves this local date and time into a {@link ZonedDateTime} in the given time zone, following
   * the given {@link ZoneLocalMappingResolver} to handle ambiguity and skipped times.
   *
   * See {@link InZoneStrictly} and {@link InZoneLeniently} for alternative ways to map a local time
   * to a specific instant.
   * This is a convenience method for calling {@link DateTimeZone.ResolveLocal}.
   * @param zone The time zone to map this local date and time into
   * @param resolver The resolver to apply to the mapping.
   * @returns The result of resolving the mapping.
   */
  InZone(zone: DateTimeZone, resolver: ZoneLocalMappingResolver): ZonedDateTime {
    Preconditions.CheckNotNull(zone, "zone");
    Preconditions.CheckNotNull(resolver, "resolver");
    return zone.ResolveLocal(this, resolver);
  }

  // Not ported: Deconstruct

  /**
   * Returns the later date/time of the given two.
   * @param x The first date/time to compare.
   * @param y The second date/time to compare.
   * @throws {ArgumentError} The two date/times have different calendar systems.
   * @returns The later date/time of `x` or `y`.
   */
  static Max(x: LocalDateTime, y: LocalDateTime): LocalDateTime {
    Preconditions.CheckArgument(x.Calendar === y.Calendar, "y", "Only values with the same calendar system can be compared");
    return x.CompareTo(y) > 0 ? x : y;
  }

  /**
   * Returns the earlier date/time of the given two.
   * @param x The first date/time to compare.
   * @param y The second date/time to compare.
   * @throws {ArgumentError} The two date/times have different calendar systems.
   * @returns The earlier date/time of `x` or `y`.
   */
  static Min(x: LocalDateTime, y: LocalDateTime): LocalDateTime {
    Preconditions.CheckArgument(x.Calendar === y.Calendar, "y", "Only values with the same calendar system can be compared");
    return x.CompareTo(y) < 0 ? x : y;
  }

  // #region Formatting
  /**
   * Formats the value of the current instance using the specified pattern.
   *
   * noda-js: with no arguments, this uses the default format pattern ("G") and the invariant culture
   * (NodaTime uses the current thread's culture).
   * @param patternText The pattern to use, or null to use the default format pattern ("G").
   * @param formatProvider The format provider to use when formatting the value,
   * or null to use the invariant culture.
   * @returns The value of the current instance in the specified format.
   */
  toString(patternText: string | null = null, formatProvider: IFormatProvider | null = null): string {
    return LocalDateTimePattern.BclSupport.Format(this, patternText, formatProvider ?? NodaCultureInfo.InvariantCulture);
  }
  // #endregion Formatting

  // #region XML serialization
  // Not ported: AddSchema, IXmlSerializable members (XML serialization)
  // #endregion

  // #region JSON (noda-js)
  /** Formats this value with {@link LocalDateTimePattern.ExtendedIso}, as NodaTime.Serialization.SystemTextJson does. */
  toJSON(): string {
    return LocalDateTimePattern.ExtendedIso.Format(this);
  }

  /**
   * Parses a value written by {@link toJSON}.
   *
   * JSON doesn't record the calendar system: the date is read in `calendar` (the ISO calendar if omitted), as
   * NodaTime.Serialization.SystemTextJson reads it with a converter whose pattern uses that calendar.
   * @throws {UnparsableValueError} The text could not be parsed.
   */
  static fromJSON(json: string, calendar?: CalendarSystem): LocalDateTime {
    const pattern = LocalDateTimePattern.ExtendedIso;
    return (calendar === undefined ? pattern : pattern.WithCalendar(calendar)).Parse(json).Value;
  }
  // #endregion

  /** Throws a TypeError: use {@link CompareTo} or {@link Equals} instead of relational operators. */
  valueOf(): never {
    return ThrowValueOf("LocalDateTime");
  }
}
