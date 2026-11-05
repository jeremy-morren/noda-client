// Ported from NodaTime 3.3.7: src/NodaTime/LocalDate.cs
// Copyright 2010 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import {
  CalendarOrdinal,
  CalendarSystem,
  NodaCultureInfo,
  DatePeriodFields,
  Era,
  GregorianYearMonthDayCalculator,
  Int32,
  IsoDayOfWeek,
  LocalDateTime,
  LocalDatePattern,
  LocalTime,
  OffsetDate,
  Period,
  Preconditions,
  WeekYearRules,
  YearMonth,
  YearMonthDayCalendar,
  ThrowValueOf,
  type DateTimeZone,
  type IComparable,
  type IEquatable,
  type IFormatProvider,
  type Offset,
  type YearMonthDay,
  type ZonedDateTime,
} from "./internal.ts";
import { NewArgumentOutOfRangeException, type ArgumentException, type ArgumentOutOfRangeException, type InvalidOperationException } from "./internal.ts";

// TODO(feature): Calendar-neutral comparer.

/**
 * LocalDate is an immutable struct representing a date within the calendar,
 * with no reference to a particular time zone or time of day.
 *
 * Values can freely be compared for equality: a value in a different calendar system is not equal to
 * a value in a different calendar system. However, ordering comparisons (either via the {@link CompareTo} method
 * or via operators) fail with {@link ArgumentException}; attempting to compare values in different calendars
 * almost always indicates a bug in the calling code.
 *
 * The default value of this type is 0001-01-01 (January 1st, 1 C.E.) in the ISO calendar.
 *
 * This type is an immutable value type. See the thread safety section of the user guide for more information.
 */
export class LocalDate implements IEquatable<LocalDate>, IComparable<LocalDate> {
  private readonly _yearMonthDayCalendar: YearMonthDayCalendar;

  /**
   * The maximum (latest) date representable in the ISO calendar system.
   */
  static get MaxIsoValue(): LocalDate {
    return LocalDate.NewYearMonthDayCalendar(YearMonthDayCalendar.NewYearMonthDayCalendarOrdinal(GregorianYearMonthDayCalculator.MaxGregorianYear, 12, 31, CalendarOrdinal.Iso));
  }

  /**
   * The minimum (earliest) date representable in the ISO calendar system.
   */
  static get MinIsoValue(): LocalDate {
    return LocalDate.NewYearMonthDayCalendar(YearMonthDayCalendar.NewYearMonthDayCalendarOrdinal(GregorianYearMonthDayCalculator.MinGregorianYear, 1, 1, CalendarOrdinal.Iso));
  }

  /**
   * Constructs an instance from values which are assumed to already have been validated.
   * (C#: `internal LocalDate(YearMonthDayCalendar yearMonthDayCalendar)`)
   * @internal
   */
  static NewYearMonthDayCalendar(yearMonthDayCalendar: YearMonthDayCalendar): LocalDate {
    const date = Object.create(LocalDate.prototype) as LocalDate;
    (date as unknown as { _yearMonthDayCalendar: YearMonthDayCalendar })._yearMonthDayCalendar = yearMonthDayCalendar;
    return date;
  }

  /**
   * Constructs an instance from the number of days since the unix epoch, in the ISO
   * calendar system.
   * (C#: `internal LocalDate(int daysSinceEpoch)`)
   * @internal
   */
  static NewDaysSinceEpoch(daysSinceEpoch: number): LocalDate {
    Preconditions.DebugCheckArgumentRange("daysSinceEpoch", daysSinceEpoch, CalendarSystem.Iso.MinDays, CalendarSystem.Iso.MaxDays);
    return LocalDate.NewYearMonthDayCalendar(GregorianYearMonthDayCalculator.GetGregorianYearMonthDayCalendarFromDaysSinceEpoch(daysSinceEpoch));
  }

  /**
   * Constructs an instance from the number of days since the unix epoch, and a calendar
   * system. The calendar system is assumed to be non-null, but the days since the epoch are
   * validated.
   * (C#: `internal LocalDate(int daysSinceEpoch, CalendarSystem calendar)`)
   * @internal
   */
  static NewDaysSinceEpochCalendar(daysSinceEpoch: number, calendar: CalendarSystem): LocalDate {
    Preconditions.DebugCheckNotNull(calendar, "calendar");
    return LocalDate.NewYearMonthDayCalendar(calendar.GetYearMonthDayCalendarFromDaysSinceEpoch(daysSinceEpoch));
  }

  /**
   * Constructs an instance for the given year, month and day in the ISO calendar.
   * @param year The year. This is the "absolute year", so a value of 0 means 1 BC, for example.
   * @param month The month of year.
   * @param day The day of month.
   * @throws {ArgumentOutOfRangeException} The parameters do not form a valid date.
   */
  constructor(year: number, month: number, day: number);
  /**
   * Constructs an instance for the given year, month and day in the specified calendar.
   * @param year The year. This is the "absolute year", so, for
   * the ISO calendar, a value of 0 means 1 BC, for example.
   * @param month The month of year.
   * @param day The day of month.
   * @param calendar Calendar system in which to create the date.
   * @throws {ArgumentOutOfRangeException} The parameters do not form a valid date.
   */
  constructor(year: number, month: number, day: number, calendar: CalendarSystem);
  /**
   * Constructs an instance for the given era, year of era, month and day in the ISO calendar.
   * @param era The era within which to create a date. Must be a valid era within the ISO calendar.
   * @param yearOfEra The year of era.
   * @param month The month of year.
   * @param day The day of month.
   * @throws {ArgumentOutOfRangeException} The parameters do not form a valid date.
   */
  constructor(era: Era, yearOfEra: number, month: number, day: number);
  /**
   * Constructs an instance for the given era, year of era, month and day in the specified calendar.
   * @param era The era within which to create a date. Must be a valid era within the specified calendar.
   * @param yearOfEra The year of era.
   * @param month The month of year.
   * @param day The day of month.
   * @param calendar Calendar system in which to create the date.
   * @throws {ArgumentOutOfRangeException} The parameters do not form a valid date.
   */
  constructor(era: Era, yearOfEra: number, month: number, day: number, calendar: CalendarSystem);
  constructor(a: number | Era, b: number, c: number, d?: number | CalendarSystem, e?: CalendarSystem) {
    if (a instanceof Era) {
      // C#: this(era, yearOfEra, month, day, CalendarSystem.Iso) and
      // this(Preconditions.CheckNotNull(calendar, nameof(calendar)).GetAbsoluteYear(yearOfEra, era), month, day, calendar)
      const calendar = arguments.length === 4 ? CalendarSystem.Iso : Preconditions.CheckNotNull(e, "calendar");
      const year = calendar.GetAbsoluteYear(b, a);
      calendar.ValidateYearMonthDay(year, c, d as number);
      this._yearMonthDayCalendar = YearMonthDayCalendar.NewYearMonthDayCalendarOrdinal(year, c, d as number, calendar.Ordinal);
    } else if (arguments.length === 3) {
      GregorianYearMonthDayCalculator.ValidateGregorianYearMonthDay(a, b, c);
      this._yearMonthDayCalendar = YearMonthDayCalendar.NewYearMonthDayCalendarOrdinal(a, b, c, CalendarOrdinal.Iso);
    } else {
      const calendar = Preconditions.CheckNotNull(d as CalendarSystem | null | undefined, "calendar");
      calendar.ValidateYearMonthDay(a, b, c);
      this._yearMonthDayCalendar = YearMonthDayCalendar.NewYearMonthDayCalendarOrdinal(a, b, c, calendar.Ordinal);
    }
  }

  /** Gets the calendar system associated with this local date. */
  get Calendar(): CalendarSystem {
    return CalendarSystem.ForOrdinal(this.CalendarOrdinal);
  }

  private get CalendarOrdinal(): CalendarOrdinal {
    return this._yearMonthDayCalendar.CalendarOrdinal;
  }

  /**
   * Gets the year of this local date.
   *
   * This returns the "absolute year", so, for the ISO calendar,
   * a value of 0 means 1 BC, for example.
   */
  get Year(): number {
    return this._yearMonthDayCalendar.Year;
  }

  /** Gets the month of this local date within the year. */
  get Month(): number {
    return this._yearMonthDayCalendar.Month;
  }

  /** Gets the day of this local date within the month. */
  get Day(): number {
    return this._yearMonthDayCalendar.Day;
  }

  /**
   * Gets the number of days since the Unix epoch for this date.
   * @internal
   */
  get DaysSinceEpoch(): number {
    return this.Calendar.GetDaysSinceEpoch(this._yearMonthDayCalendar.ToYearMonthDay());
  }

  /**
   * Gets the week day of this local date expressed as an {@link IsoDayOfWeek} value.
   */
  get DayOfWeek(): IsoDayOfWeek {
    return this.Calendar.GetDayOfWeek(this._yearMonthDayCalendar.ToYearMonthDay());
  }

  /** Gets the year of this local date within the era. */
  get YearOfEra(): number {
    return this.Calendar.GetYearOfEra(this._yearMonthDayCalendar.Year);
  }

  /** Gets the era of this local date. */
  get Era(): Era {
    return this.Calendar.GetEra(this._yearMonthDayCalendar.Year);
  }

  /** Gets the day of this local date within the year. */
  get DayOfYear(): number {
    return this.Calendar.GetDayOfYear(this._yearMonthDayCalendar.ToYearMonthDay());
  }

  /** @internal */
  get YearMonthDay(): YearMonthDay {
    return this._yearMonthDayCalendar.ToYearMonthDay();
  }

  /**
   * Gets a {@link LocalDateTime} at midnight on the date represented by this local date.
   * @returns The {@link LocalDateTime} representing midnight on this local date, in the same calendar
   * system.
   */
  AtMidnight(): LocalDateTime {
    return LocalDateTime.NewDateTime(this, LocalTime.Midnight);
  }

  // Not ported: ToDateTimeUnspecified() (BCL interop)

  // Not ported: NonNegativeTicksToDays(long) (helper for the BCL interop methods)

  // Not ported: FromDateTime(DateTime) (BCL interop)

  // Not ported: FromDateTime(DateTime, CalendarSystem) (BCL interop)

  /**
   * Returns the local date corresponding to the given "week year", "week of week year", and "day of week"
   * in the ISO calendar system, using the ISO week-year rules.
   * @param weekYear ISO-8601 week year of value to return
   * @param weekOfWeekYear ISO-8601 week of week year of value to return
   * @param dayOfWeek ISO-8601 day of week to return
   * @returns The date corresponding to the given week year / week of week year / day of week.
   */
  static FromWeekYearWeekAndDay(weekYear: number, weekOfWeekYear: number, dayOfWeek: IsoDayOfWeek): LocalDate {
    return WeekYearRules.Iso.GetLocalDate(weekYear, weekOfWeekYear, dayOfWeek, CalendarSystem.Iso);
  }

  /**
   * Returns the local date corresponding to a particular occurrence of a day-of-week
   * within a year and month. For example, this method can be used to ask for "the third Monday in April 2012".
   *
   * The returned date is always in the ISO calendar. This method is unrelated to week-years and any rules for
   * "business weeks" and the like - if a month begins on a Friday, then asking for the first Friday will give
   * that day, for example.
   *
   * @param year The year of the value to return.
   * @param month The month of the value to return.
   * @param occurrence The occurrence of the value to return, which must be in the range [1, 5]. The value 5 can
   * be used to always return the last occurrence of the specified day-of-week, even if there are only 4
   * occurrences of that day-of-week in the month.
   * @param dayOfWeek The day-of-week of the value to return.
   * @returns The date corresponding to the given year and month, on the given occurrence of the
   * given day of week.
   */
  static FromYearMonthWeekAndDay(year: number, month: number, occurrence: number, dayOfWeek: IsoDayOfWeek): LocalDate {
    // This validates year and month as well as getting us a useful date.
    const startOfMonth = new LocalDate(year, month, 1);
    Preconditions.CheckArgumentRange("occurrence", occurrence, 1, 5);
    Preconditions.CheckArgumentRange("dayOfWeek", dayOfWeek, 1, 7);

    // Correct day of week, 1st week of month.
    let week1Day = dayOfWeek - startOfMonth.DayOfWeek + 1;
    if (week1Day <= 0) {
      week1Day += 7;
    }
    let targetDay = week1Day + (occurrence - 1) * 7;
    if (targetDay > CalendarSystem.Iso.GetDaysInMonth(year, month)) {
      targetDay -= 7;
    }
    return new LocalDate(year, month, targetDay);
  }

  /**
   * Creates a {@link YearMonth} value for the month containing this date.
   * @returns A year/month value containing this date.
   */
  ToYearMonth(): YearMonth {
    return new YearMonth(this.Year, this.Month, this.Calendar);
  }

  /**
   * Adds the specified period to the date (C# `operator +(LocalDate, Period)` and `Add(LocalDate, Period)`),
   * or combines the given {@link LocalDate} and {@link LocalTime} components
   * into a single {@link LocalDateTime} (C# `operator +(LocalDate, LocalTime)`).
   * Fields are added in descending order of significance (years first, then months, and so on).
   * Friendly alternative to `operator+()`.
   * @param date The date to add the period (or time) to
   * @param period The period to add. Must not contain any (non-zero) time units.
   * @returns The sum of the given date and period
   */
  static Add(date: LocalDate, period: Period): LocalDate;
  /**
   * Combines the given {@link LocalDate} and {@link LocalTime} components
   * into a single {@link LocalDateTime}.
   * @param date The date to add the time to
   * @param time The time to add
   * @returns The sum of the given date and time
   */
  static Add(date: LocalDate, time: LocalTime): LocalDateTime;
  static Add(date: LocalDate, periodOrTime: Period | LocalTime): LocalDate | LocalDateTime {
    if (periodOrTime instanceof LocalTime) {
      return LocalDateTime.NewDateTime(date, periodOrTime);
    }
    const period = periodOrTime;
    Preconditions.CheckNotNull(period, "period");
    Preconditions.CheckArgument(!period.HasTimeComponent, "period", "Cannot add a period with a time component to a date");
    return date.PlusYears(period.Years)
      .PlusMonths(period.Months)
      .PlusWeeks(period.Weeks)
      .PlusDays(period.Days);
  }

  /**
   * Adds the specified period to this date.
   * Fields are added in descending order of significance (years first, then months, and so on).
   * Fluent alternative to `operator+()`.
   * @param period The period to add. Must not contain any (non-zero) time units.
   * @returns The sum of this date and the given period
   */
  Plus(period: Period): LocalDate {
    return LocalDate.Add(this, period);
  }

  /**
   * Subtracts the specified period from the date (C# `operator -(LocalDate, Period)`).
   * Fields are subtracted in descending order of significance (years first, then months, and so on).
   * Friendly alternative to `operator-()`.
   * @param date The date to subtract the period from
   * @param period The period to subtract. Must not contain any (non-zero) time units.
   * @returns The result of subtracting the given period from the date.
   */
  static Subtract(date: LocalDate, period: Period): LocalDate;
  /**
   * Subtracts one date from another, returning the result as a {@link Period} with units of years, months and days
   * (C# `operator -(LocalDate, LocalDate)`).
   *
   * This is simply a convenience method for calling {@link Period.Between}.
   * The calendar systems of the two dates must be the same.
   *
   * @param lhs The date to subtract from
   * @param rhs The date to subtract
   * @returns The result of subtracting one date from another.
   * @throws {ArgumentException} `lhs` and `rhs` are not in the same calendar system.
   */
  static Subtract(lhs: LocalDate, rhs: LocalDate): Period;
  static Subtract(date: LocalDate, periodOrDate: Period | LocalDate): LocalDate | Period {
    if (periodOrDate instanceof LocalDate) {
      return Period.Between(periodOrDate, date);
    }
    const period = periodOrDate;
    Preconditions.CheckNotNull(period, "period");
    Preconditions.CheckArgument(!period.HasTimeComponent, "period", "Cannot subtract a period with a time component from a date");
    return date.PlusYears(Int32.Checked(-period.Years))
      .PlusMonths(Int32.Checked(-period.Months))
      .PlusWeeks(Int32.Checked(-period.Weeks))
      .PlusDays(Int32.Checked(-period.Days));
  }

  /**
   * Subtracts the specified period from this date.
   * Fields are subtracted in descending order of significance (years first, then months, and so on).
   * Fluent alternative to `operator-()`.
   * @param period The period to subtract. Must not contain any (non-zero) time units.
   * @returns The result of subtracting the given period from this date.
   */
  Minus(period: Period): LocalDate;
  /**
   * Subtracts the specified date from this date, returning the result as a {@link Period} with units of years, months and days.
   * Fluent alternative to `operator-()`.
   *
   * The specified date must be in the same calendar system as this.
   * @param date The date to subtract from this
   * @returns The difference between the specified date and this one
   */
  Minus(date: LocalDate): Period;
  Minus(periodOrDate: Period | LocalDate): LocalDate | Period {
    return periodOrDate instanceof LocalDate
      ? LocalDate.Subtract(this, periodOrDate)
      : LocalDate.Subtract(this, periodOrDate);
  }

  // Operators == and != are covered by Equals().

  // Comparison operators: note that we can't use YearMonthDayCalendar.Compare, as only the calendar knows whether it can use
  // naive comparisons.
  // Operators <, <=, > and >= are covered by CompareTo().

  /**
   * Indicates whether this date is earlier, later or the same as another one.
   * See the type documentation for a description of ordering semantics.
   *
   * noda-js: this also covers the explicit `IComparable.CompareTo(object)` implementation: if `other` is null,
   * this method returns a value greater than 0.
   *
   * @param other The other date to compare this one with
   * @throws {ArgumentException} The calendar system of `other` is not the
   * same as the calendar system of this value, or `other` is non-null but is not a {@link LocalDate}.
   * @returns A value less than zero if this date is earlier than `other`;
   * zero if this date is the same as `other`; a value greater than zero if this date is
   * later than `other`.
   */
  CompareTo(other: LocalDate | null): number;
  /** @inheritDoc */
  CompareTo(other: unknown): number;
  CompareTo(other: unknown): number {
    if (other === null || other === undefined) {
      return 1;
    }
    Preconditions.CheckArgument(other instanceof LocalDate, "obj", "Object must be of type NodaTime.LocalDate.");
    const that = other as LocalDate;
    Preconditions.CheckArgument(this.CalendarOrdinal === that.CalendarOrdinal, "other", "Only values with the same calendar system can be compared");
    return this.TrustedCompareTo(that);
  }

  /**
   * Performs a comparison with another date, trusting that the calendar of the other date is already correct.
   * This avoids duplicate calendar checks.
   */
  private TrustedCompareTo(other: LocalDate): number {
    return this.Calendar.Compare(this.YearMonthDay, other.YearMonthDay);
  }

  /**
   * Returns the later date of the given two.
   * @param x The first date to compare.
   * @param y The second date to compare.
   * @throws {ArgumentException} The two dates have different calendar systems.
   * @returns The later date of `x` or `y`.
   */
  static Max(x: LocalDate, y: LocalDate): LocalDate {
    Preconditions.CheckArgument(x.Calendar === y.Calendar, "y", "Only values with the same calendar system can be compared");
    return x.TrustedCompareTo(y) > 0 ? x : y;
  }

  /**
   * Returns the earlier date of the given two.
   * @param x The first date to compare.
   * @param y The second date to compare.
   * @throws {ArgumentException} The two dates have different calendar systems.
   * @returns The earlier date of `x` or `y`.
   */
  static Min(x: LocalDate, y: LocalDate): LocalDate {
    Preconditions.CheckArgument(x.Calendar === y.Calendar, "y", "Only values with the same calendar system can be compared");
    return x.TrustedCompareTo(y) < 0 ? x : y;
  }

  // Not ported: GetHashCode() (omitted, as per the porting conventions)

  /**
   * Compares two {@link LocalDate} values for equality.
   * See the type documentation for a description of equality semantics.
   * @param other The value to compare this date with.
   * @returns True if the given value is another local date equal to this one; false otherwise.
   *
   * noda-js: covers both `IEquatable<LocalDate>.Equals(LocalDate)` and `object.Equals(object)`.
   */
  Equals(other: LocalDate): boolean;
  /** @inheritDoc */
  Equals(other: unknown): boolean;
  Equals(other: unknown): boolean {
    return other instanceof LocalDate && this._yearMonthDayCalendar.Equals(other._yearMonthDayCalendar);
  }

  /**
   * Resolves this local date into a {@link ZonedDateTime} in the given time zone representing the
   * start of this date in the given zone.
   *
   * This is a convenience method for calling {@link DateTimeZone.AtStartOfDay}.
   *
   * @param zone The time zone to map this local date into
   * @throws {SkippedTimeException} The entire day was skipped due to a very large time zone transition.
   * (This is extremely rare.)
   * @returns The {@link ZonedDateTime} representing the earliest time on this date, in the given time zone.
   */
  AtStartOfDayInZone(zone: DateTimeZone): ZonedDateTime {
    Preconditions.CheckNotNull(zone, "zone");
    return zone.AtStartOfDay(this);
  }

  /**
   * Creates a new LocalDate representing the same physical date, but in a different calendar.
   * The returned LocalDate is likely to have different field values to this one.
   * For example, January 1st 1970 in the Gregorian calendar was December 19th 1969 in the Julian calendar.
   * @param calendar The calendar system to convert this local date to.
   * @returns The converted LocalDate
   */
  WithCalendar(calendar: CalendarSystem): LocalDate {
    Preconditions.CheckNotNull(calendar, "calendar");
    return calendar.Ordinal === this.CalendarOrdinal
      ? this
      : LocalDate.NewDaysSinceEpochCalendar(this.DaysSinceEpoch, calendar);
  }

  /**
   * Returns a new LocalDate representing the current value with the given number of years added.
   *
   * If the resulting date is invalid, lower fields (typically the day of month) are reduced to find a valid value.
   * For example, adding one year to February 29th 2012 will return February 28th 2013; subtracting one year from
   * February 29th 2012 will return February 28th 2011.
   *
   * @param years The number of years to add
   * @returns The current value plus the given number of years.
   */
  PlusYears(years: number): LocalDate {
    return DatePeriodFields.YearsField.Add(this, years);
  }

  /**
   * Returns a new LocalDate representing the current value with the given number of months added.
   *
   * This method does not try to maintain the year of the current value, so adding four months to a value in
   * October will result in a value in the following February.
   *
   * If the resulting date is invalid, the day of month is reduced to find a valid value.
   * For example, adding one month to January 30th 2011 will return February 28th 2011; subtracting one month from
   * March 30th 2011 will return February 28th 2011.
   *
   * @param months The number of months to add
   * @returns The current date plus the given number of months
   */
  PlusMonths(months: number): LocalDate {
    return DatePeriodFields.MonthsField.Add(this, months);
  }

  /**
   * Returns a new LocalDate representing the current value with the given number of days added.
   *
   * This method does not try to maintain the month or year of the current value, so adding 3 days to a value of January 30th
   * will result in a value of February 2nd.
   *
   * @param days The number of days to add
   * @returns The current value plus the given number of days.
   */
  PlusDays(days: number): LocalDate {
    return DatePeriodFields.DaysField.Add(this, days);
  }

  /**
   * Returns a new LocalDate representing the current value with the given number of weeks added.
   * @param weeks The number of weeks to add
   * @returns The current value plus the given number of weeks.
   */
  PlusWeeks(weeks: number): LocalDate {
    return DatePeriodFields.WeeksField.Add(this, weeks);
  }

  /**
   * Returns the next {@link LocalDate} falling on the specified {@link IsoDayOfWeek}.
   * This is a strict "next" - if this date on already falls on the target
   * day of the week, the returned value will be a week later.
   * @param targetDayOfWeek The ISO day of the week to return the next date of.
   * @returns The next {@link LocalDate} falling on the specified day of the week.
   * @throws {InvalidOperationException} The underlying calendar doesn't use ISO days of the week.
   * @throws {ArgumentOutOfRangeException} `targetDayOfWeek` is not a valid day of the
   * week (Monday to Sunday).
   */
  Next(targetDayOfWeek: IsoDayOfWeek): LocalDate {
    // Avoids boxing...
    if (!(targetDayOfWeek >= IsoDayOfWeek.Monday && targetDayOfWeek <= IsoDayOfWeek.Sunday)) {
      throw NewArgumentOutOfRangeException("targetDayOfWeek");
    }
    // This will throw the desired exception for calendars with different week systems.
    const thisDay = this.DayOfWeek;
    let difference = targetDayOfWeek - thisDay;
    if (difference <= 0) {
      difference += 7;
    }
    return this.PlusDays(difference);
  }

  /**
   * Returns the previous {@link LocalDate} falling on the specified {@link IsoDayOfWeek}.
   * This is a strict "previous" - if this date on already falls on the target
   * day of the week, the returned value will be a week earlier.
   * @param targetDayOfWeek The ISO day of the week to return the previous date of.
   * @returns The previous {@link LocalDate} falling on the specified day of the week.
   * @throws {InvalidOperationException} The underlying calendar doesn't use ISO days of the week.
   * @throws {ArgumentOutOfRangeException} `targetDayOfWeek` is not a valid day of the
   * week (Monday to Sunday).
   */
  Previous(targetDayOfWeek: IsoDayOfWeek): LocalDate {
    // Avoids boxing...
    if (!(targetDayOfWeek >= IsoDayOfWeek.Monday && targetDayOfWeek <= IsoDayOfWeek.Sunday)) {
      throw NewArgumentOutOfRangeException("targetDayOfWeek");
    }
    // This will throw the desired exception for calendars with different week systems.
    const thisDay = this.DayOfWeek;
    let difference = targetDayOfWeek - thisDay;
    if (difference >= 0) {
      difference -= 7;
    }
    return this.PlusDays(difference);
  }

  /**
   * Returns an {@link OffsetDate} for this local date with the given offset.
   *
   * This method is purely a convenient alternative to calling the {@link OffsetDate} constructor directly.
   * @param offset The offset to apply.
   * @returns The result of this date offset by the given amount.
   */
  WithOffset(offset: Offset): OffsetDate {
    return new OffsetDate(this, offset);
  }

  /**
   * Combines this {@link LocalDate} with the given {@link LocalTime}
   * into a single {@link LocalDateTime}.
   * Fluent alternative to `operator+()`.
   * @param time The time to combine with this date.
   * @returns The {@link LocalDateTime} representation of the given time on this date
   */
  At(time: LocalTime): LocalDateTime {
    return LocalDate.Add(this, time);
  }

  /**
   * Returns this date, with the given adjuster applied to it.
   *
   * If the adjuster attempts to construct an invalid date (such as by trying
   * to set a day-of-month of 30 in February), any exception thrown by
   * that construction attempt will be propagated through this method.
   * @param adjuster The adjuster to apply.
   * @returns The adjusted date.
   */
  With(adjuster: (date: LocalDate) => LocalDate): LocalDate {
    return Preconditions.CheckNotNull(adjuster, "adjuster")(this);
  }

  // Not ported: Deconstruct (omitted, as per the porting conventions)

  // #region Formatting
  /**
   * Returns a string that represents this instance.
   *
   * With no arguments, this is the value of the current instance in the default format pattern ("D"), using the
   * invariant culture (NodaTime uses the current thread's culture).
   *
   * @param patternText The string specifying the pattern to use,
   * or null to use the default format pattern ("D").
   * @param formatProvider The {@link IFormatProvider} to use when formatting the value,
   * or null to use the invariant culture.
   * @returns A string containing the value of the current instance in the specified format.
   */
  toString(patternText?: string | null, formatProvider?: IFormatProvider | null): string {
    return LocalDatePattern.BclSupport.Format(this, patternText ?? null, formatProvider ?? NodaCultureInfo.InvariantCulture);
  }
  // #endregion Formatting

  // #region XML serialization
  // Not ported: AddSchema, IXmlSerializable.GetSchema, ReadXml, WriteXml (XML serialization)
  // #endregion

  // #region DateOnly conversions (.NET 6 only)
  // Not ported: ToDateOnly(), FromDateOnly(DateOnly) (BCL interop)
  // #endregion

  // #region JSON (noda-js)
  /**
   * Returns the JSON representation of this value, as written by NodaTime.Serialization.SystemTextJson:
   * the ISO pattern ({@link LocalDatePattern.Iso}), e.g. "2024-03-01".
   */
  toJSON(): string {
    return LocalDatePattern.Iso.Format(this);
  }

  /**
   * Parses the JSON representation of a value, as written by {@link toJSON}.
   *
   * JSON doesn't record the calendar system: the date is read in `calendar` (the ISO calendar if omitted), as
   * NodaTime.Serialization.SystemTextJson reads it with a converter whose pattern uses that calendar.
   * @throws {UnparsableValueException} The value can't be parsed.
   */
  static fromJSON(json: string, calendar?: CalendarSystem): LocalDate {
    return (calendar === undefined ? LocalDatePattern.Iso : LocalDatePattern.Iso.WithCalendar(calendar)).Parse(json).Value;
  }
  // #endregion

  /** Throws a TypeError: use {@link CompareTo} or {@link Equals} instead of relational operators. */
  valueOf(): never {
    return ThrowValueOf("LocalDate");
  }
}
