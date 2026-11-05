// Ported from NodaTime 3.3.7: src/NodaTime/Period.cs
// Copyright 2010 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import {
  DatePeriodFields,
  Duration,
  Int32,
  Int64,
  LocalDate,
  LocalDateTime,
  LocalTime,
  PeriodBuilder,
  PeriodPattern,
  PeriodUnits,
  Preconditions,
  TimePeriodField,
  YearMonth,
} from "./internal.ts";
import type { IDatePeriodField, IEquatable, Int64Value } from "./internal.ts";
import {
  HoursPerDay, MillisecondsPerSecond, MinutesPerHour, NanosecondsPerDay, NanosecondsPerHour, NanosecondsPerMillisecond,
  NanosecondsPerMinute, NanosecondsPerSecond, NanosecondsPerTick, NanosecondsPerWeek, SecondsPerMinute,
} from "./NodaConstants.generated.ts";
import type { ZonedDateTime } from "./internal.ts";
import { NewInvalidOperationException, type ArgumentException, type InvalidOperationException, type OverflowException } from "./internal.ts";

// noda-js: Period's C# long fields (hours to nanoseconds) are stored exactly, as an Int64Value (Utility/Numbers.ts): a
// number when the value is a safe integer (the common case, with no allocation), otherwise an exact Long. The public
// getters return numbers (the nearest number beyond 2^53); internal code uses the exact accessors (ExactHours etc.).
// Arithmetic on these fields is exact and checked against the long range, as C# checked arithmetic is. Public methods
// taking a C# long accept a number or a decimal string (exact beyond 2^53).

let zero: Period | undefined;
let maxValue: Period | undefined;
let minValue: Period | undefined;

/**
 * Equality comparer which simply normalizes periods before comparing them.
 *
 * Not part of the public API (no entry point exports it), but deliberately not tagged internal: public declarations refer to it,
 * so it must stay in the published type declarations.
 */
export class PeriodNormalizingPeriodEqualityComparer {
  private static _instanceValue: PeriodNormalizingPeriodEqualityComparer | undefined;

  static get Instance(): PeriodNormalizingPeriodEqualityComparer {
    return (PeriodNormalizingPeriodEqualityComparer._instanceValue ??= new PeriodNormalizingPeriodEqualityComparer());
  }

  private constructor() {
  }

  Equals(x: Period | null, y: Period | null): boolean {
    if (x === y) {
      return true;
    }
    // noda-js: also false (rather than a TypeError) for anything that isn't a Period.
    if (!(x instanceof Period) || !(y instanceof Period)) {
      return false;
    }
    return x.Normalize().Equals(y.Normalize());
  }

  // Not ported: GetHashCode(Period) (hash codes are omitted; see docs/porting-conventions.md)
}

/**
 * The comparer returned by Period.CreateComparer.
 *
 * Not part of the public API (no entry point exports it), but deliberately not tagged internal: public declarations refer to it,
 * so it must stay in the published type declarations.
 */
export class PeriodPeriodComparer {
  private readonly _baseDateTime: LocalDateTime;

  constructor(baseDateTime: LocalDateTime) {
    this._baseDateTime = baseDateTime;
  }

  Compare(x: Period | null, y: Period | null): number {
    if (x === y) {
      return 0;
    }
    if (x === null || x === undefined) {
      return -1;
    }
    if (y === null || y === undefined) {
      return 1;
    }
    // noda-js: C#'s parameters can only be periods (or null); check, so anything else throws ArgumentException.
    Preconditions.CheckArgument(x instanceof Period, "x", "Object must be of type NodaTime.Period.");
    Preconditions.CheckArgument(y instanceof Period, "y", "Object must be of type NodaTime.Period.");
    if (x.Months === 0 && y.Months === 0 &&
      x.Years === 0 && y.Years === 0) {
      // Note: this *could* throw an OverflowException when the normal approach
      // wouldn't, but it's highly unlikely
      return x.ToDuration().CompareTo(y.ToDuration());
    }
    return this._baseDateTime.Plus(x).CompareTo(this._baseDateTime.Plus(y));
  }
}

/**
 * Represents a period of time expressed in human chronological terms: hours, days,
 * weeks, months and so on.
 *
 * A {@link Period} contains a set of properties such as {@link Years}, {@link Months}, and so on
 * that return the number of each unit contained within this period. Note that these properties are not normalized in
 * any way by default, and so a {@link Period} may contain values such as "2 hours and 90 minutes". The
 * {@link Normalize} method will convert equivalent periods into a standard representation.
 *
 * Periods can contain negative units as well as positive units ("+2 hours, -43 minutes, +10 seconds"), but do not
 * differentiate between properties that are zero and those that are absent (i.e. a period created as "10 years"
 * and one created as "10 years, zero months" are equal periods; the {@link Months} property returns zero in
 * both cases).
 *
 * {@link Period} equality is implemented by comparing each property's values individually, without any normalization.
 * (For example, a period of "24 hours" is not considered equal to a period of "1 day".) The static
 * {@link Period.NormalizingEqualityComparer} comparer provides an equality comparer which performs normalization before comparisons.
 *
 * There is no natural ordering for periods, but {@link Period.CreateComparer} can be used to create a
 * comparer which orders periods according to a reference date, by adding each period to that date and comparing the results.
 *
 * Periods operate on calendar-related types such as
 * {@link LocalDateTime} whereas {@link Duration} operates on instants
 * on the time line. (Note that although {@link ZonedDateTime} includes both concepts, it only supports
 * duration-based arithmetic.)
 *
 * The complexity of each method in this type is hard to document precisely, and often depends on the calendar system
 * involved in performing the actual calculations. Operations do not depend on the magnitude of the units in the period,
 * other than for optimizations for values of zero or occasionally for particularly small values. For example,
 * adding 10,000 days to a date does not require greater algorithmic complexity than adding 1,000 days to the same date.
 *
 * This type is immutable reference type. See the thread safety section of the user guide for more information.
 */
export class Period implements IEquatable<Period> {
  // General implementation note: operations such as normalization work out the total number of nanoseconds as an Int64
  // value. This can handle +/- 106,751 days, or 292 years. We could move to using BigInteger if we feel that's required,
  // but it's unlikely to be an issue. Ideally, we'd switch to use BigInteger after detecting that it could be a problem,
  // but without the hit of having to catch the exception...

  /** @internal */
  static readonly NormalizingPeriodEqualityComparer = PeriodNormalizingPeriodEqualityComparer;
  /** @internal */
  static readonly PeriodComparer = PeriodPeriodComparer;

  /**
   * A period containing only zero-valued properties.
   */
  static get Zero(): Period {
    return (zero ??= Period.NewYearsMonthsWeeksDays(0, 0, 0, 0));
  }

  /**
   * A period containing the maximum value for all properties.
   *
   * noda-js: the long-valued properties return 2^63, the JS number nearest to long.MaxValue (the exact value is held
   * internally, so formatting and equality are exact).
   */
  static get MaxValue(): Period {
    return (maxValue ??= new Period(Int32.MaxValue, Int32.MaxValue, Int32.MaxValue, Int32.MaxValue,
      Int64.MaxValue, Int64.MaxValue, Int64.MaxValue, Int64.MaxValue, Int64.MaxValue, Int64.MaxValue));
  }

  /**
   * A period containing the minimum value for all properties.
   */
  static get MinValue(): Period {
    return (minValue ??= new Period(Int32.MinValue, Int32.MinValue, Int32.MinValue, Int32.MinValue,
      Int64.MinValue, Int64.MinValue, Int64.MinValue, Int64.MinValue, Int64.MinValue, Int64.MinValue));
  }

  /**
   * Gets the additive identity.
   */
  static get AdditiveIdentity(): Period {
    return Period.Zero;
  }

  /**
   * Returns an equality comparer which compares periods by first normalizing them - so 24 hours is deemed equal to 1 day, and so on.
   * Note that as per the {@link Normalize} method, years and months are unchanged by normalization - so 12 months does not
   * equal 1 year.
   */
  static get NormalizingEqualityComparer(): PeriodNormalizingPeriodEqualityComparer {
    return PeriodNormalizingPeriodEqualityComparer.Instance;
  }

  // The fields that make up this period.
  // noda-js: NodaTime uses auto-properties; the values are held in these private fields. The long-valued ones
  // are exact Int64Values (see the note at the top of this file).
  private readonly _nanoseconds: Int64Value;
  private readonly _ticks: Int64Value;
  private readonly _milliseconds: Int64Value;
  private readonly _seconds: Int64Value;
  private readonly _minutes: Int64Value;
  private readonly _hours: Int64Value;
  private readonly _days: number;
  private readonly _weeks: number;
  private readonly _months: number;
  private readonly _years: number;

  /**
   * Gets the number of nanoseconds within this period.
   *
   * This property returns zero both when the property has been explicitly set to zero and when the period does not
   * contain this property.
   */
  get Nanoseconds(): number {
    return Int64.ToNumber(this._nanoseconds);
  }

  /**
   * Gets the number of ticks within this period.
   *
   * This property returns zero both when the property has been explicitly set to zero and when the period does not
   * contain this property.
   */
  get Ticks(): number {
    return Int64.ToNumber(this._ticks);
  }

  /**
   * Gets the number of milliseconds within this period.
   *
   * This property returns zero both when the property has been explicitly set to zero and when the period does not
   * contain this property.
   */
  get Milliseconds(): number {
    return Int64.ToNumber(this._milliseconds);
  }

  /**
   * Gets the number of seconds within this period.
   *
   * This property returns zero both when the property has been explicitly set to zero and when the period does not
   * contain this property.
   */
  get Seconds(): number {
    return Int64.ToNumber(this._seconds);
  }

  /**
   * Gets the number of minutes within this period.
   *
   * This property returns zero both when the property has been explicitly set to zero and when the period does not
   * contain this property.
   */
  get Minutes(): number {
    return Int64.ToNumber(this._minutes);
  }

  /**
   * Gets the number of hours within this period.
   *
   * This property returns zero both when the property has been explicitly set to zero and when the period does not
   * contain this property.
   */
  get Hours(): number {
    return Int64.ToNumber(this._hours);
  }

  /**
   * Gets the number of days within this period.
   *
   * This property returns zero both when the property has been explicitly set to zero and when the period does not
   * contain this property.
   */
  get Days(): number {
    return this._days;
  }

  /**
   * Gets the number of weeks within this period.
   *
   * This property returns zero both when the property has been explicitly set to zero and when the period does not
   * contain this property.
   */
  get Weeks(): number {
    return this._weeks;
  }

  /**
   * Gets the number of months within this period.
   *
   * This property returns zero both when the property has been explicitly set to zero and when the period does not
   * contain this property.
   */
  get Months(): number {
    return this._months;
  }

  /**
   * Gets the number of years within this period.
   *
   * This property returns zero both when the property has been explicitly set to zero and when the period does not
   * contain this property.
   */
  get Years(): number {
    return this._years;
  }

  /**
   * The exact value of {@link Nanoseconds}: a number when it is a safe integer, otherwise a Long.
   * @internal
   */
  get ExactNanoseconds(): Int64Value {
    return this._nanoseconds;
  }

  /**
   * The exact value of {@link Ticks}: a number when it is a safe integer, otherwise a Long.
   * @internal
   */
  get ExactTicks(): Int64Value {
    return this._ticks;
  }

  /**
   * The exact value of {@link Milliseconds}: a number when it is a safe integer, otherwise a Long.
   * @internal
   */
  get ExactMilliseconds(): Int64Value {
    return this._milliseconds;
  }

  /**
   * The exact value of {@link Seconds}: a number when it is a safe integer, otherwise a Long.
   * @internal
   */
  get ExactSeconds(): Int64Value {
    return this._seconds;
  }

  /**
   * The exact value of {@link Minutes}: a number when it is a safe integer, otherwise a Long.
   * @internal
   */
  get ExactMinutes(): Int64Value {
    return this._minutes;
  }

  /**
   * The exact value of {@link Hours}: a number when it is a safe integer, otherwise a Long.
   * @internal
   */
  get ExactHours(): Int64Value {
    return this._hours;
  }

  // noda-js: the single constructor behind NodaTime's three private/internal constructors (see the factories below).
  private constructor(years: number, months: number, weeks: number, days: number, hours: Int64Value, minutes: Int64Value,
    seconds: Int64Value, milliseconds: Int64Value, ticks: Int64Value, nanoseconds: Int64Value) {
    this._years = years;
    this._months = months;
    this._weeks = weeks;
    this._days = days;
    this._hours = hours;
    this._minutes = minutes;
    this._seconds = seconds;
    this._milliseconds = milliseconds;
    this._ticks = ticks;
    this._nanoseconds = nanoseconds;
  }

  /**
   * Creates a period with the given date values.
   * @internal
   */
  static NewYearsMonthsWeeksDays(years: number, months: number, weeks: number, days: number): Period {
    return new Period(years, months, weeks, days, 0, 0, 0, 0, 0, 0);
  }

  /**
   * Creates a period with the given time values.
   * @internal
   */
  static NewHoursMinutesSecondsMillisecondsTicksNanoseconds(hours: Int64Value, minutes: Int64Value, seconds: Int64Value,
    milliseconds: Int64Value, ticks: Int64Value, nanoseconds: Int64Value): Period {
    return new Period(0, 0, 0, 0, hours, minutes, seconds, milliseconds, ticks, nanoseconds);
  }

  /**
   * Creates a new period from the given values.
   * @internal
   */
  static NewYearsMonthsWeeksDaysHoursMinutesSecondsMillisecondsTicksNanoseconds(years: number, months: number, weeks: number,
    days: number, hours: Int64Value, minutes: Int64Value, seconds: Int64Value, milliseconds: Int64Value,
    ticks: Int64Value, nanoseconds: Int64Value): Period {
    return new Period(years, months, weeks, days, hours, minutes, seconds, milliseconds, ticks, nanoseconds);
  }

  /**
   * Creates a period representing the specified number of years.
   *
   * @param years The number of years in the new period
   * @returns A period consisting of the given number of years.
   */
  static FromYears(years: number): Period {
    return Period.NewYearsMonthsWeeksDays(years, 0, 0, 0);
  }

  /**
   * Creates a period representing the specified number of months.
   *
   * @param months The number of months in the new period
   * @returns A period consisting of the given number of months.
   */
  static FromMonths(months: number): Period {
    return Period.NewYearsMonthsWeeksDays(0, months, 0, 0);
  }

  /**
   * Creates a period representing the specified number of weeks.
   *
   * @param weeks The number of weeks in the new period
   * @returns A period consisting of the given number of weeks.
   */
  static FromWeeks(weeks: number): Period {
    return Period.NewYearsMonthsWeeksDays(0, 0, weeks, 0);
  }

  /**
   * Creates a period representing the specified number of days.
   *
   * @param days The number of days in the new period
   * @returns A period consisting of the given number of days.
   */
  static FromDays(days: number): Period {
    return Period.NewYearsMonthsWeeksDays(0, 0, 0, days);
  }

  /**
   * Creates a period representing the specified number of hours.
   *
   * @param hours The number of hours in the new period
   * @returns A period consisting of the given number of hours.
   */
  static FromHours(hours: number | string): Period {
    return Period.NewHoursMinutesSecondsMillisecondsTicksNanoseconds(Int64.FromArgument(hours, "hours"), 0, 0, 0, 0, 0);
  }

  /**
   * Creates a period representing the specified number of minutes.
   *
   * @param minutes The number of minutes in the new period
   * @returns A period consisting of the given number of minutes.
   */
  static FromMinutes(minutes: number | string): Period {
    return Period.NewHoursMinutesSecondsMillisecondsTicksNanoseconds(0, Int64.FromArgument(minutes, "minutes"), 0, 0, 0, 0);
  }

  /**
   * Creates a period representing the specified number of seconds.
   *
   * @param seconds The number of seconds in the new period
   * @returns A period consisting of the given number of seconds.
   */
  static FromSeconds(seconds: number | string): Period {
    return Period.NewHoursMinutesSecondsMillisecondsTicksNanoseconds(0, 0, Int64.FromArgument(seconds, "seconds"), 0, 0, 0);
  }

  /**
   * Creates a period representing the specified number of milliseconds.
   *
   * @param milliseconds The number of milliseconds in the new period
   * @returns A period consisting of the given number of milliseconds.
   */
  static FromMilliseconds(milliseconds: number | string): Period {
    return Period.NewHoursMinutesSecondsMillisecondsTicksNanoseconds(0, 0, 0, Int64.FromArgument(milliseconds, "milliseconds"), 0, 0);
  }

  /**
   * Creates a period representing the specified number of ticks.
   *
   * @param ticks The number of ticks in the new period
   * @returns A period consisting of the given number of ticks.
   */
  static FromTicks(ticks: number | string): Period {
    return Period.NewHoursMinutesSecondsMillisecondsTicksNanoseconds(0, 0, 0, 0, Int64.FromArgument(ticks, "ticks"), 0);
  }

  /**
   * Creates a period representing the specified number of nanoseconds.
   *
   * @param nanoseconds The number of nanoseconds in the new period
   * @returns A period consisting of the given number of nanoseconds.
   */
  static FromNanoseconds(nanoseconds: number | string): Period {
    return Period.NewHoursMinutesSecondsMillisecondsTicksNanoseconds(0, 0, 0, 0, 0, Int64.FromArgument(nanoseconds, "nanoseconds"));
  }

  /**
   * Adds two periods together, by simply adding the values for each property.
   * (NodaTime's `operator +` and `Add`.)
   *
   * @param left The first period to add
   * @param right The second period to add
   * @returns The sum of the two periods. The units of the result will be the union of those in both
   * periods.
   */
  static Add(left: Period, right: Period): Period {
    Preconditions.CheckNotNull(left, "left");
    Preconditions.CheckNotNull(right, "right");
    return new Period(
      Int32.Checked(left.Years + right.Years),
      Int32.Checked(left.Months + right.Months),
      Int32.Checked(left.Weeks + right.Weeks),
      Int32.Checked(left.Days + right.Days),
      Int64.Add(left.ExactHours, right.ExactHours),
      Int64.Add(left.ExactMinutes, right.ExactMinutes),
      Int64.Add(left.ExactSeconds, right.ExactSeconds),
      Int64.Add(left.ExactMilliseconds, right.ExactMilliseconds),
      Int64.Add(left.ExactTicks, right.ExactTicks),
      Int64.Add(left.ExactNanoseconds, right.ExactNanoseconds));
  }

  /**
   * Creates a comparer for periods, using the given "base" local date/time.
   *
   * Certain periods can't naturally be compared without more context - how "one month" compares to
   * "30 days" depends on where you start. In order to compare two periods, the returned comparer
   * effectively adds both periods to the "base" specified by `baseDateTime` and compares
   * the results. In some cases this arithmetic isn't actually required - when two periods can be
   * converted to durations, the comparer uses that conversion for efficiency.
   *
   * @param baseDateTime The base local date/time to use for comparisons.
   * @returns The new comparer.
   */
  static CreateComparer(baseDateTime: LocalDateTime): PeriodPeriodComparer {
    return new PeriodPeriodComparer(baseDateTime);
  }

  /**
   * Subtracts one period from another, by simply subtracting each property value.
   * (NodaTime's binary `operator -` and `Subtract`.)
   *
   * @param minuend The period to subtract the second operand from
   * @param subtrahend The period to subtract the first operand from
   * @returns The result of subtracting all the values in the second operand from the values in the first. The
   * units of the result will be the union of both periods, even if the subtraction caused some properties to
   * become zero (so "2 weeks, 1 days" minus "2 weeks" is "zero weeks, 1 days", not "1 days").
   */
  static Subtract(minuend: Period, subtrahend: Period): Period {
    Preconditions.CheckNotNull(minuend, "minuend");
    Preconditions.CheckNotNull(subtrahend, "subtrahend");
    return new Period(
      Int32.Checked(minuend.Years - subtrahend.Years),
      Int32.Checked(minuend.Months - subtrahend.Months),
      Int32.Checked(minuend.Weeks - subtrahend.Weeks),
      Int32.Checked(minuend.Days - subtrahend.Days),
      Int64.Subtract(minuend.ExactHours, subtrahend.ExactHours),
      Int64.Subtract(minuend.ExactMinutes, subtrahend.ExactMinutes),
      Int64.Subtract(minuend.ExactSeconds, subtrahend.ExactSeconds),
      Int64.Subtract(minuend.ExactMilliseconds, subtrahend.ExactMilliseconds),
      Int64.Subtract(minuend.ExactTicks, subtrahend.ExactTicks),
      Int64.Subtract(minuend.ExactNanoseconds, subtrahend.ExactNanoseconds));
  }

  /**
   * Implements the unary negation operator.
   *
   * @param period Period to negate
   * @returns The negative value of this period
   */
  static Negate(period: Period): Period {
    return Period.Subtract(Period.Zero, period);
  }

  /**
   * Returns the number of days between two {@link LocalDate} values.
   *
   * @param start Start date
   * @param end End date
   * @throws {ArgumentException} `start` and `end` use different calendars.
   * @returns The number of days between the given dates.
   */
  static DaysBetween(start: LocalDate, end: LocalDate): number {
    Preconditions.CheckArgument(
      start.Calendar === end.Calendar,
      "end",
      "start and end must use the same calendar system");

    return Period.InternalDaysBetween(start, end);
  }

  /**
   * Returns the number of nanoseconds between two {@link LocalTime} values.
   *
   * If `end` is before `start`, the returned value will be negative.
   *
   * @param start Start time
   * @param end End time
   * @returns The number of nanoseconds between the given times.
   */
  static NanosecondsBetween(start: LocalTime, end: LocalTime): number {
    return end.NanosecondOfDay - start.NanosecondOfDay;
  }

  /**
   * Returns the period between a start and an end date/time, using only the given units.
   *
   * If `end` is before `start`, each property in the returned period
   * will be negative. If the given set of units cannot exactly reach the end point (e.g. finding
   * the difference between 1am and 3:15am in hours) the result will be such that adding it to `start`
   * will give a value between `start` and `end`. In other words,
   * any rounding is "towards start"; this is true whether the resulting period is negative or positive.
   *
   * If `units` is omitted, this returns the exact difference between two date/times, using all units
   * ({@link PeriodUnits.DateAndTime}).
   *
   * @param start Start date/time
   * @param end End date/time
   * @param units Units to use for calculations
   * @throws {ArgumentException} `units` is empty or contained unknown values.
   * @throws {ArgumentException} `start` and `end` use different calendars.
   * @returns The period between the given date/times, using the given units.
   */
  static Between(start: LocalDateTime, end: LocalDateTime, units?: PeriodUnits): Period;
  /**
   * Returns the period between a start and an end date, using only the given units.
   *
   * If `end` is before `start`, each property in the returned period
   * will be negative. If the given set of units cannot exactly reach the end point (e.g. finding
   * the difference between 12th February and 15th March in months) the result will be such that adding it to `start`
   * will give a value between `start` and `end`. In other words,
   * any rounding is "towards start"; this is true whether the resulting period is negative or positive.
   *
   * If `units` is omitted, this returns the exact difference between two dates, using year, month and day units.
   * The calendar systems of the two dates must be the same; an exception will be thrown otherwise.
   *
   * @param start Start date
   * @param end End date
   * @param units Units to use for calculations
   * @throws {ArgumentException} `units` contains time units, is empty or contains unknown values.
   * @throws {ArgumentException} `start` and `end` use different calendars.
   * @returns The period between the given dates, using the given units.
   */
  static Between(start: LocalDate, end: LocalDate, units?: PeriodUnits): Period;
  /**
   * Returns the period between a start and an end time, using only the given units.
   *
   * If `end` is before `start`, each property in the returned period
   * will be negative. If the given set of units cannot exactly reach the end point (e.g. finding
   * the difference between 3am and 4.30am in hours) the result will be such that adding it to `start`
   * will give a value between `start` and `end`. In other words,
   * any rounding is "towards start"; this is true whether the resulting period is negative or positive.
   *
   * If `units` is omitted, this returns the exact difference between two times, using the time period units.
   *
   * @param start Start time
   * @param end End time
   * @param units Units to use for calculations
   * @throws {ArgumentException} `units` contains date units, is empty or contains unknown values.
   * @returns The period between the given times, using the given units.
   */
  static Between(start: LocalTime, end: LocalTime, units?: PeriodUnits): Period;
  /**
   * Returns the period between a start and an end {@link YearMonth}, using only the given units.
   *
   * If `end` is before `start`, each property in the returned period
   * will be negative. If the given set of units cannot exactly reach the end point (e.g. finding
   * the difference between February 2010 and March 2012 in years) the result will be such that adding it to `start`
   * will give a value between `start` and `end`. In other words,
   * any rounding is "towards start"; this is true whether the resulting period is negative or positive.
   *
   * If `units` is omitted, this returns the exact difference between two {@link YearMonth} values, using year and month units.
   * The calendar systems of the two values must be the same; an exception will be thrown otherwise.
   *
   * @param start Start year and month
   * @param end End year and month
   * @param units Units to use for calculations
   * @throws {ArgumentException} `units` is empty or contains anything other than than PeriodUnits.Years
   * and/or PeriodUnits.Months.
   * @throws {ArgumentException} `start` and `end` use different calendars.
   * @returns The period between the given YearMonths, using the given units.
   */
  static Between(start: YearMonth, end: YearMonth, units?: PeriodUnits): Period;
  static Between(start: LocalDateTime | LocalDate | LocalTime | YearMonth, end: LocalDateTime | LocalDate | LocalTime | YearMonth,
    units?: PeriodUnits): Period {
    if (start instanceof LocalDateTime) {
      return Period.BetweenLocalDateTimes(start, end as LocalDateTime, units ?? PeriodUnits.DateAndTime);
    }
    if (start instanceof LocalDate) {
      return Period.BetweenLocalDates(start, end as LocalDate, units ?? PeriodUnits.YearMonthDay);
    }
    if (start instanceof LocalTime) {
      return Period.BetweenLocalTimes(start, end as LocalTime, units ?? PeriodUnits.AllTimeUnits);
    }
    if (start instanceof YearMonth) {
      return Period.BetweenYearMonths(start, end as YearMonth, units ?? (PeriodUnits.Years | PeriodUnits.Months));
    }
    throw new TypeError("Period.Between requires LocalDateTime, LocalDate, LocalTime or YearMonth values");
  }

  // Between(LocalDateTime, LocalDateTime, PeriodUnits)
  private static BetweenLocalDateTimes(start: LocalDateTime, end: LocalDateTime, units: PeriodUnits): Period {
    Preconditions.CheckArgument(units !== 0, "units", "Units must not be empty");
    Preconditions.CheckArgument((units & ~PeriodUnits.AllUnits) === 0, "units", "Units contains an unknown value: {0}", units);
    const calendar = start.Calendar;
    Preconditions.CheckArgument(calendar === end.Calendar, "end", "start and end must use the same calendar system");

    if (start.Equals(end)) {
      return Period.Zero;
    }

    // Adjust for situations like "days between 5th January 10am and 7th January 5am" which should be one
    // day, because if we actually reach 7th January with date fields, we've overshot.
    // The date adjustment will always be valid, because it's just moving it towards start.
    // We need this for all date-based period fields. We could potentially optimize by not doing this
    // in cases where we've only got time fields...
    let endDate: LocalDate = end.Date;
    if (start.CompareTo(end) < 0) {
      if (start.TimeOfDay.CompareTo(end.TimeOfDay) > 0) {
        endDate = endDate.PlusDays(-1);
      }
    } else if (start.CompareTo(end) > 0 && start.TimeOfDay.CompareTo(end.TimeOfDay) < 0) {
      endDate = endDate.PlusDays(1);
    }

    // Optimization for single field
    switch (units) {
      case PeriodUnits.Years: return Period.FromYears(DatePeriodFields.YearsField.UnitsBetween(start.Date, endDate));
      case PeriodUnits.Months: return Period.FromMonths(DatePeriodFields.MonthsField.UnitsBetween(start.Date, endDate));
      case PeriodUnits.Weeks: return Period.FromWeeks(DatePeriodFields.WeeksField.UnitsBetween(start.Date, endDate));
      case PeriodUnits.Days: return Period.FromDays(Period.InternalDaysBetween(start.Date, endDate));
      // (noda-js: the internal factory, as the exact values may be Longs.)
      case PeriodUnits.Hours: return Period.NewHoursMinutesSecondsMillisecondsTicksNanoseconds(TimePeriodField.Hours.UnitsBetween(start, end), 0, 0, 0, 0, 0);
      case PeriodUnits.Minutes: return Period.NewHoursMinutesSecondsMillisecondsTicksNanoseconds(0, TimePeriodField.Minutes.UnitsBetween(start, end), 0, 0, 0, 0);
      case PeriodUnits.Seconds: return Period.NewHoursMinutesSecondsMillisecondsTicksNanoseconds(0, 0, TimePeriodField.Seconds.UnitsBetween(start, end), 0, 0, 0);
      case PeriodUnits.Milliseconds: return Period.NewHoursMinutesSecondsMillisecondsTicksNanoseconds(0, 0, 0, TimePeriodField.Milliseconds.UnitsBetween(start, end), 0, 0);
      case PeriodUnits.Ticks: return Period.NewHoursMinutesSecondsMillisecondsTicksNanoseconds(0, 0, 0, 0, TimePeriodField.Ticks.UnitsBetween(start, end), 0);
      case PeriodUnits.Nanoseconds: return Period.NewHoursMinutesSecondsMillisecondsTicksNanoseconds(0, 0, 0, 0, 0, TimePeriodField.Nanoseconds.UnitsBetween(start, end));
    }

    // Multiple fields
    let remaining: LocalDateTime = start;
    let years = 0, months = 0, weeks = 0, days = 0;
    if ((units & PeriodUnits.AllDateUnits) !== 0) {
      let remainingDate: LocalDate;
      ({ date: remainingDate, years, months, weeks, days } = Period.DateComponentsBetween(start.Date, endDate, units));
      remaining = LocalDateTime.NewDateTime(remainingDate, start.TimeOfDay);
    }
    if ((units & PeriodUnits.AllTimeUnits) === 0) {
      return Period.NewYearsMonthsWeeksDays(years, months, weeks, days);
    }

    // The remainder of the computation is with fixed-length units, so we can do it all with
    // Duration instead of Local* values. We don't know for sure that this is small though - we *could*
    // be trying to find the difference between 9998 BC and 9999 CE in nanoseconds...
    // Where we can optimize, do everything with long arithmetic (as we do for Between(LocalTime, LocalTime)).
    // Otherwise (rare case), use duration arithmetic.
    let hours: Int64Value, minutes: Int64Value, seconds: Int64Value, milliseconds: Int64Value,
      ticks: Int64Value, nanoseconds: Int64Value;
    let duration: Duration = end.ToLocalInstant().TimeSinceLocalEpoch.Minus(remaining.ToLocalInstant().TimeSinceLocalEpoch);
    if (duration.IsInt64Representable) {
      ({ hours, minutes, seconds, milliseconds, ticks, nanoseconds } = Period.TimeComponentsBetween(duration.ToInt64NanosecondsExact(), units));
    } else {
      const unitsBetween = (mask: PeriodUnits, timeField: TimePeriodField): Int64Value => {
        if ((mask & units) === 0) {
          return 0;
        }
        const value = timeField.GetUnitsInDuration(duration);
        duration = duration.Minus(timeField.ToDuration(value));
        return value;
      };
      hours = unitsBetween(PeriodUnits.Hours, TimePeriodField.Hours);
      minutes = unitsBetween(PeriodUnits.Minutes, TimePeriodField.Minutes);
      seconds = unitsBetween(PeriodUnits.Seconds, TimePeriodField.Seconds);
      milliseconds = unitsBetween(PeriodUnits.Milliseconds, TimePeriodField.Milliseconds);
      ticks = unitsBetween(PeriodUnits.Ticks, TimePeriodField.Ticks);
      nanoseconds = unitsBetween(PeriodUnits.Ticks, TimePeriodField.Nanoseconds);
    }
    return new Period(years, months, weeks, days, hours, minutes, seconds, milliseconds, ticks, nanoseconds);
  }

  /**
   * Common code to perform the date parts of the Between methods.
   *
   * @param start Start date
   * @param end End date
   * @param units Units to compute
   * @returns The resulting date after adding the result components to `start` (to
   * allow further computations to be made), and the year, month, week and day components of the result
   * (C# out parameters).
   */
  private static DateComponentsBetween(start: LocalDate, end: LocalDate, units: PeriodUnits):
    { date: LocalDate; years: number; months: number; weeks: number; days: number } {
    let result: LocalDate = start;

    const unitsBetween = (maskedUnits: PeriodUnits, endDate: LocalDate, dateField: IDatePeriodField): number => {
      if (maskedUnits === 0) {
        return 0;
      }
      const value = dateField.UnitsBetween(result, endDate);
      result = dateField.Add(result, value);
      return value;
    };

    const years = unitsBetween(units & PeriodUnits.Years, end, DatePeriodFields.YearsField);
    const months = unitsBetween(units & PeriodUnits.Months, end, DatePeriodFields.MonthsField);
    const weeks = unitsBetween(units & PeriodUnits.Weeks, end, DatePeriodFields.WeeksField);
    const days = unitsBetween(units & PeriodUnits.Days, end, DatePeriodFields.DaysField);
    return { date: result, years, months, weeks, days };
  }

  /**
   * Common code to perform the time parts of the Between methods for long-representable nanos.
   *
   * @param totalNanoseconds Number of nanoseconds to compute the units of
   * @param units Units to compute
   * @returns The hours, minutes, seconds, milliseconds, ticks and nanoseconds components of the result
   * (C# out parameters).
   */
  private static TimeComponentsBetween(totalNanoseconds: Int64Value, units: PeriodUnits):
    { hours: Int64Value; minutes: Int64Value; seconds: Int64Value; milliseconds: Int64Value;
      ticks: Int64Value; nanoseconds: Int64Value } {
    const unitsBetween = (mask: PeriodUnits, nanosecondsPerUnit: number): Int64Value => {
      if ((mask & units) === 0) {
        return 0;
      }
      const quotient = Int64.Divide(totalNanoseconds, nanosecondsPerUnit);
      totalNanoseconds = Int64.Remainder(totalNanoseconds, nanosecondsPerUnit);
      return quotient;
    };

    const hours = unitsBetween(PeriodUnits.Hours, NanosecondsPerHour);
    const minutes = unitsBetween(PeriodUnits.Minutes, NanosecondsPerMinute);
    const seconds = unitsBetween(PeriodUnits.Seconds, NanosecondsPerSecond);
    const milliseconds = unitsBetween(PeriodUnits.Milliseconds, NanosecondsPerMillisecond);
    const ticks = unitsBetween(PeriodUnits.Ticks, NanosecondsPerTick);
    const nanoseconds = unitsBetween(PeriodUnits.Nanoseconds, 1);
    return { hours, minutes, seconds, milliseconds, ticks, nanoseconds };
  }

  // Between(LocalDate, LocalDate, PeriodUnits)
  private static BetweenLocalDates(start: LocalDate, end: LocalDate, units: PeriodUnits): Period {
    Preconditions.CheckArgument((units & PeriodUnits.AllTimeUnits) === 0, "units", "Units contains time units: {0}", units);
    Preconditions.CheckArgument(units !== 0, "units", "Units must not be empty");
    Preconditions.CheckArgument((units & ~PeriodUnits.AllUnits) === 0, "units", "Units contains an unknown value: {0}", units);
    const calendar = start.Calendar;
    Preconditions.CheckArgument(calendar === end.Calendar, "end", "start and end must use the same calendar system");

    if (start.Equals(end)) {
      return Period.Zero;
    }

    // Optimization for single field
    switch (units) {
      case PeriodUnits.Years: return Period.FromYears(DatePeriodFields.YearsField.UnitsBetween(start, end));
      case PeriodUnits.Months: return Period.FromMonths(DatePeriodFields.MonthsField.UnitsBetween(start, end));
      case PeriodUnits.Weeks: return Period.FromWeeks(DatePeriodFields.WeeksField.UnitsBetween(start, end));
      case PeriodUnits.Days: return Period.FromDays(Period.InternalDaysBetween(start, end));
    }

    // Multiple fields
    const { years, months, weeks, days } = Period.DateComponentsBetween(start, end, units);
    return Period.NewYearsMonthsWeeksDays(years, months, weeks, days);
  }

  // Between(LocalTime, LocalTime, PeriodUnits)
  private static BetweenLocalTimes(start: LocalTime, end: LocalTime, units: PeriodUnits): Period {
    Preconditions.CheckArgument((units & PeriodUnits.AllDateUnits) === 0, "units", "Units contains date units: {0}", units);
    Preconditions.CheckArgument(units !== 0, "units", "Units must not be empty");
    Preconditions.CheckArgument((units & ~PeriodUnits.AllUnits) === 0, "units", "Units contains an unknown value: {0}", units);

    // We know that the difference is in the range of +/- 1 day, which is a relatively small
    // number of nanoseconds. All the operations can be done with simple long division/remainder ops,
    // so we don't need to delegate to TimePeriodField.

    const remaining = Period.NanosecondsBetween(start, end);

    // Optimization for a single unit
    switch (units) {
      case PeriodUnits.Hours: return Period.FromHours(Math.trunc(remaining / NanosecondsPerHour));
      case PeriodUnits.Minutes: return Period.FromMinutes(Math.trunc(remaining / NanosecondsPerMinute));
      case PeriodUnits.Seconds: return Period.FromSeconds(Math.trunc(remaining / NanosecondsPerSecond));
      case PeriodUnits.Milliseconds: return Period.FromMilliseconds(Math.trunc(remaining / NanosecondsPerMillisecond));
      case PeriodUnits.Ticks: return Period.FromTicks(Math.trunc(remaining / NanosecondsPerTick));
      case PeriodUnits.Nanoseconds: return Period.FromNanoseconds(remaining);
    }

    const { hours, minutes, seconds, milliseconds, ticks, nanoseconds } = Period.TimeComponentsBetween(remaining, units);
    return Period.NewHoursMinutesSecondsMillisecondsTicksNanoseconds(hours, minutes, seconds, milliseconds, ticks, nanoseconds);
  }

  /**
   * Returns the number of days between two dates. This allows optimizations in DateInterval,
   * and for date calculations which just use days - we don't need state or a virtual method invocation.
   * @internal
   */
  static InternalDaysBetween(start: LocalDate, end: LocalDate): number {
    // We already assume the calendars are the same.
    if (start.YearMonthDay.Equals(end.YearMonthDay)) {
      return 0;
    }
    // Note: I've experimented with checking for the dates being in the same year and optimizing that.
    // It helps a little if they're in the same month, but just that test has a cost for other situations.
    // Being able to find the day of year if they're in the same year but different months doesn't help,
    // somewhat surprisingly.
    const startDays = start.DaysSinceEpoch;
    const endDays = end.DaysSinceEpoch;
    return endDays - startDays;
  }

  // Between(YearMonth, YearMonth, PeriodUnits)
  private static BetweenYearMonths(start: YearMonth, end: YearMonth, units: PeriodUnits): Period {
    Preconditions.CheckArgument((units & (PeriodUnits.AllUnits ^ PeriodUnits.Years ^ PeriodUnits.Months)) === 0,
      "units", "Units can only contain year and month units: {0}", units);
    Preconditions.CheckArgument(units !== 0, "units", "Units must not be empty");
    Preconditions.CheckArgument((units & ~PeriodUnits.AllUnits) === 0, "units", "Units contains an unknown value: {0}", units);
    const calendar = start.Calendar;
    Preconditions.CheckArgument(calendar === end.Calendar, "end", "start and end must use the same calendar system");

    if (start.Equals(end)) {
      return Period.Zero;
    }

    const startDate: LocalDate = start.StartDate;
    const endDate: LocalDate = end.StartDate;

    // Optimization for single field
    switch (units) {
      case PeriodUnits.Years: return Period.FromYears(DatePeriodFields.YearsField.UnitsBetween(startDate, endDate));
      case PeriodUnits.Months: return Period.FromMonths(DatePeriodFields.MonthsField.UnitsBetween(startDate, endDate));
    }

    // Multiple fields
    const { years, months } = Period.DateComponentsBetween(startDate, endDate, units);
    return Period.NewYearsMonthsWeeksDays(years, months, 0, 0);
  }

  /**
   * Returns whether or not this period contains any non-zero-valued time-based properties (hours or lower).
   */
  get HasTimeComponent(): boolean {
    // (A stored long field is zero only as the number 0; see Int64Value.)
    return this._hours !== 0 || this._minutes !== 0 || this._seconds !== 0 || this._milliseconds !== 0 || this._ticks !== 0 || this._nanoseconds !== 0;
  }

  /**
   * Returns whether or not this period contains any non-zero date-based properties (days or higher).
   */
  get HasDateComponent(): boolean {
    return this._years !== 0 || this._months !== 0 || this._weeks !== 0 || this._days !== 0;
  }

  /**
   * For periods that do not contain a non-zero number of years or months, returns a duration for this period
   * assuming a standard 7-day week, 24-hour day, 60-minute hour etc.
   *
   * @throws {InvalidOperationException} The month or year property in the period is non-zero.
   * @throws {OverflowException} The period doesn't have years or months, but the calculation
   * overflows the bounds of {@link Duration}. In some cases this may occur even though the theoretical
   * result would be valid due to balancing positive and negative values, but for simplicity there is
   * no attempt to work around this - in realistic periods, it shouldn't be a problem.
   * @returns The duration of the period.
   */
  ToDuration(): Duration {
    if (this.Months !== 0 || this.Years !== 0) {
      throw NewInvalidOperationException("Cannot construct duration of period with non-zero months or years.");
    }
    return Duration.FromInt64Nanoseconds(this.TotalNanoseconds);
  }

  /**
   * Gets the total number of nanoseconds duration for the 'standard' properties (all bar years and months).
   * (Computed with checked 64-bit arithmetic, as in NodaTime.)
   */
  private get TotalNanoseconds(): Int64Value {
    const add = Int64.Add, multiply = Int64.Multiply;
    return add(add(add(add(add(add(add(
      this._nanoseconds,
      multiply(this._ticks, NanosecondsPerTick)),
      multiply(this._milliseconds, NanosecondsPerMillisecond)),
      multiply(this._seconds, NanosecondsPerSecond)),
      multiply(this._minutes, NanosecondsPerMinute)),
      multiply(this._hours, NanosecondsPerHour)),
      multiply(this._days, NanosecondsPerDay)),
      multiply(this._weeks, NanosecondsPerWeek));
  }

  /**
   * Creates a {@link PeriodBuilder} from this instance. The new builder
   * is populated with the values from this period, but is then detached from it:
   * changes made to the builder are not reflected in this period.
   *
   * @returns A builder with the same values and units as this period.
   */
  ToBuilder(): PeriodBuilder {
    return new PeriodBuilder(this);
  }

  /**
   * Returns a normalized version of this period, such that equivalent (but potentially non-equal) periods are
   * changed to the same representation.
   *
   * Months and years are unchanged
   * (as they can vary in length), but weeks are multiplied by 7 and added to the
   * Days property, and all time properties are normalized to their natural range.
   * Subsecond values are normalized to millisecond and "nanosecond within millisecond" values.
   * So for example, a period of 25 hours becomes a period of 1 day
   * and 1 hour. A period of 1,500,750,000 nanoseconds becomes 1 second, 500 milliseconds and
   * 750,000 nanoseconds. Aside from months and years, either all the properties
   * end up positive, or they all end up negative. "Week" and "tick" units in the returned period are always 0.
   *
   * @throws {OverflowException} The period doesn't have years or months, but it contains more than
   * long.MaxValue nanoseconds when the combined weeks/days/time portions are considered. This is
   * over 292 years, so unlikely to be a problem in normal usage.
   * In some cases this may occur even though the theoretical result would be valid due to balancing positive and
   * negative values, but for simplicity there is no attempt to work around this.
   * @returns The normalized period.
   * @see Period.NormalizingEqualityComparer
   */
  Normalize(): Period {
    // Simplest way to normalize: grab all the fields up to "week" and
    // sum them.
    const totalNanoseconds = this.TotalNanoseconds;
    const { Divide, Remainder, ToNumber } = Int64;
    const days = Int32.Checked(ToNumber(Divide(totalNanoseconds, NanosecondsPerDay)));
    const hours = ToNumber(Remainder(Divide(totalNanoseconds, NanosecondsPerHour), HoursPerDay));
    const minutes = ToNumber(Remainder(Divide(totalNanoseconds, NanosecondsPerMinute), MinutesPerHour));
    const seconds = ToNumber(Remainder(Divide(totalNanoseconds, NanosecondsPerSecond), SecondsPerMinute));
    const milliseconds = ToNumber(Remainder(Divide(totalNanoseconds, NanosecondsPerMillisecond), MillisecondsPerSecond));
    const nanoseconds = ToNumber(Remainder(totalNanoseconds, NanosecondsPerMillisecond));

    return new Period(this._years, this._months, 0 /* weeks */, days, hours, minutes, seconds, milliseconds, 0 /* ticks */, nanoseconds);
  }

  // #region Object overrides

  /**
   * Returns this string formatted according to the {@link PeriodPattern.Roundtrip}.
   *
   * @returns A formatted representation of this period.
   */
  toString(): string {
    return PeriodPattern.Roundtrip.Format(this);
  }

  // Not ported: unary operator + (dropped; see docs/porting-conventions.md)

  /**
   * Compares the given period for equality with this one.
   * See the type documentation for a description of equality semantics.
   * (Merges NodaTime's Equals(object), Equals(Period) and operator ==.)
   *
   * @param other The period to compare this one with.
   * @returns True if this period has the same values for the same properties as the one specified.
   */
  Equals(other: Period): boolean;
  /** @inheritDoc */
  Equals(other: unknown): boolean;
  Equals(other: unknown): boolean {
    return other instanceof Period &&
      this._years === other._years &&
      this._months === other._months &&
      this._weeks === other._weeks &&
      this._days === other._days &&
      Int64.Equals(this._hours, other._hours) &&
      Int64.Equals(this._minutes, other._minutes) &&
      Int64.Equals(this._seconds, other._seconds) &&
      Int64.Equals(this._milliseconds, other._milliseconds) &&
      Int64.Equals(this._ticks, other._ticks) &&
      Int64.Equals(this._nanoseconds, other._nanoseconds);
  }
  // #endregion

  // #region JSON
  /**
   * Formats this period with {@link PeriodPattern.Roundtrip}, as NodaTime.Serialization.SystemTextJson does.
   */
  toJSON(): string {
    return PeriodPattern.Roundtrip.Format(this);
  }

  /**
   * Parses a period written by {@link toJSON}, using {@link PeriodPattern.Roundtrip}.
   *
   * @throws {UnparsableValueException} The text could not be parsed.
   */
  static fromJSON(json: string): Period {
    return PeriodPattern.Roundtrip.Parse(json).Value;
  }
  // #endregion
}
