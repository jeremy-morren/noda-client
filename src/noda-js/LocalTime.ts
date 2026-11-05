// Ported from NodaTime 3.3.7: src/NodaTime/LocalTime.cs
// Copyright 2010 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import {
  NodaCultureInfo,
  Int64,
  LocalDate,
  LocalDateTime,
  LocalTimePattern,
  Offset,
  OffsetTime,
  Period,
  Preconditions,
  TimePeriodField,
  ThrowValueOf,
} from "./internal.ts";
import type { IComparable, IEquatable, IFormatProvider } from "./internal.ts";
import {
  HoursPerDay,
  MillisecondsPerDay,
  MillisecondsPerSecond,
  MinutesPerDay,
  MinutesPerHour,
  NanosecondsPerDay,
  NanosecondsPerHour,
  NanosecondsPerMillisecond,
  NanosecondsPerMinute,
  NanosecondsPerSecond,
  NanosecondsPerTick,
  SecondsPerDay,
  SecondsPerMinute,
  TicksPerDay,
  TicksPerMillisecond,
  TicksPerSecond,
} from "./NodaConstants.generated.ts";
import type { ArgumentException, ArgumentOutOfRangeException } from "./internal.ts";

// Note: documentation that refers to the LocalDateTime type within this class must use the fully-qualified
// reference to avoid being resolved to the LocalDateTime property instead.

let midnight: LocalTime | undefined;
let noon: LocalTime | undefined;
let maxValue: LocalTime | undefined;

/**
 * LocalTime is an immutable struct representing a time of day, with no reference
 * to a particular calendar, time zone or date.
 *
 * Ordering and equality are defined in the natural way, simply comparing the number of "nanoseconds since midnight".
 *
 * The default value of this type is {@link LocalTime.Midnight}.
 *
 * This type is an immutable value type. See the thread safety section of the user guide for more information.
 */
export class LocalTime implements IEquatable<LocalTime>, IComparable<LocalTime> {
  /** Local time at midnight, i.e. 0 hours, 0 minutes, 0 seconds. */
  static get Midnight(): LocalTime {
    return (midnight ??= new LocalTime(0, 0, 0));
  }

  /** The minimum value of this type; equivalent to {@link Midnight}. */
  static get MinValue(): LocalTime {
    return LocalTime.Midnight;
  }

  /** Local time at noon, i.e. 12 hours, 0 minutes, 0 seconds. */
  static get Noon(): LocalTime {
    return (noon ??= new LocalTime(12, 0, 0));
  }

  /**
   * The maximum value of this type, one nanosecond before midnight.
   *
   * This is useful if you have to use an inclusive upper bound for some reason.
   * In general, it's better to use an exclusive upper bound, in which case use midnight of
   * the following day.
   */
  static get MaxValue(): LocalTime {
    return (maxValue ??= LocalTime.NewNanoseconds(NanosecondsPerDay - 1));
  }

  /** Nanoseconds since midnight, in the range [0, 86,400,000,000,000). */
  private readonly _nanoseconds: number;

  /**
   * Creates a local time at the given hour and minute, with second, millisecond-of-second
   * and tick-of-millisecond values of zero.
   * @param hour The hour of day.
   * @param minute The minute of the hour.
   * @throws {ArgumentOutOfRangeException} The parameters do not form a valid time.
   */
  constructor(hour: number, minute: number);
  /**
   * Creates a local time at the given hour, minute and second,
   * with millisecond-of-second and tick-of-millisecond values of zero.
   * @param hour The hour of day.
   * @param minute The minute of the hour.
   * @param second The second of the minute.
   * @throws {ArgumentOutOfRangeException} The parameters do not form a valid time.
   */
  constructor(hour: number, minute: number, second: number);
  /**
   * Creates a local time at the given hour, minute, second and millisecond,
   * with a tick-of-millisecond value of zero.
   * @param hour The hour of day.
   * @param minute The minute of the hour.
   * @param second The second of the minute.
   * @param millisecond The millisecond of the second.
   * @throws {ArgumentOutOfRangeException} The parameters do not form a valid time.
   */
  constructor(hour: number, minute: number, second: number, millisecond: number);
  constructor(hour: number, minute: number, second: number = 0, millisecond: number = 0) {
    // noda-js: one implementation covers all three constructors; the omitted values are 0, which is always valid.
    // Avoid the method calls which give a decent exception unless we're actually going to fail.
    if (hour < 0 || hour > HoursPerDay - 1 ||
      minute < 0 || minute > MinutesPerHour - 1 ||
      second < 0 || second > SecondsPerMinute - 1 ||
      millisecond < 0 || millisecond > MillisecondsPerSecond - 1) {
      Preconditions.CheckArgumentRange("hour", hour, 0, HoursPerDay - 1);
      Preconditions.CheckArgumentRange("minute", minute, 0, MinutesPerHour - 1);
      Preconditions.CheckArgumentRange("second", second, 0, SecondsPerMinute - 1);
      Preconditions.CheckArgumentRange("millisecond", millisecond, 0, MillisecondsPerSecond - 1);
    }
    this._nanoseconds =
      hour * NanosecondsPerHour +
      minute * NanosecondsPerMinute +
      second * NanosecondsPerSecond +
      millisecond * NanosecondsPerMillisecond;
  }

  /**
   * Factory method to create a local time at the given hour, minute, second, millisecond and tick within millisecond.
   * @param hour The hour of day.
   * @param minute The minute of the hour.
   * @param second The second of the minute.
   * @param millisecond The millisecond of the second.
   * @param tickWithinMillisecond The tick within the millisecond.
   * @throws {ArgumentOutOfRangeException} The parameters do not form a valid time.
   * @returns The resulting time.
   */
  static FromHourMinuteSecondMillisecondTick(hour: number, minute: number, second: number, millisecond: number, tickWithinMillisecond: number): LocalTime {
    // Avoid the method calls which give a decent exception unless we're actually going to fail.
    if (hour < 0 || hour > HoursPerDay - 1 ||
      minute < 0 || minute > MinutesPerHour - 1 ||
      second < 0 || second > SecondsPerMinute - 1 ||
      millisecond < 0 || millisecond > MillisecondsPerSecond - 1 ||
      tickWithinMillisecond < 0 || tickWithinMillisecond > TicksPerMillisecond - 1) {
      Preconditions.CheckArgumentRange("hour", hour, 0, HoursPerDay - 1);
      Preconditions.CheckArgumentRange("minute", minute, 0, MinutesPerHour - 1);
      Preconditions.CheckArgumentRange("second", second, 0, SecondsPerMinute - 1);
      Preconditions.CheckArgumentRange("millisecond", millisecond, 0, MillisecondsPerSecond - 1);
      Preconditions.CheckArgumentRange("tickWithinMillisecond", tickWithinMillisecond, 0, TicksPerMillisecond - 1);
    }
    const nanoseconds =
      hour * NanosecondsPerHour +
      minute * NanosecondsPerMinute +
      second * NanosecondsPerSecond +
      millisecond * NanosecondsPerMillisecond +
      tickWithinMillisecond * NanosecondsPerTick;
    return LocalTime.NewNanoseconds(nanoseconds);
  }

  /**
   * Factory method for creating a local time from the hour of day, minute of hour, second of minute, and tick of second.
   *
   * This is not a constructor overload as it would have the same signature as the one taking millisecond of second.
   * @param hour The hour of day in the desired time, in the range [0, 23].
   * @param minute The minute of hour in the desired time, in the range [0, 59].
   * @param second The second of minute in the desired time, in the range [0, 59].
   * @param tickWithinSecond The tick within the second in the desired time, in the range [0, 9999999].
   * @throws {ArgumentOutOfRangeException} The parameters do not form a valid time.
   * @returns The resulting time.
   */
  static FromHourMinuteSecondTick(hour: number, minute: number, second: number, tickWithinSecond: number): LocalTime {
    // Avoid the method calls which give a decent exception unless we're actually going to fail.
    if (hour < 0 || hour > HoursPerDay - 1 ||
      minute < 0 || minute > MinutesPerHour - 1 ||
      second < 0 || second > SecondsPerMinute - 1 ||
      tickWithinSecond < 0 || tickWithinSecond > TicksPerSecond - 1) {
      Preconditions.CheckArgumentRange("hour", hour, 0, HoursPerDay - 1);
      Preconditions.CheckArgumentRange("minute", minute, 0, MinutesPerHour - 1);
      Preconditions.CheckArgumentRange("second", second, 0, SecondsPerMinute - 1);
      Preconditions.CheckArgumentRange("tickWithinSecond", tickWithinSecond, 0, TicksPerSecond - 1);
    }
    return LocalTime.NewNanoseconds(
      hour * NanosecondsPerHour +
      minute * NanosecondsPerMinute +
      second * NanosecondsPerSecond +
      tickWithinSecond * NanosecondsPerTick);
  }

  /**
   * Factory method for creating a local time from the hour of day, minute of hour, second of minute, and nanosecond of second.
   *
   * This is not a constructor overload as it would have the same signature as the one taking millisecond of second.
   * @param hour The hour of day in the desired time, in the range [0, 23].
   * @param minute The minute of hour in the desired time, in the range [0, 59].
   * @param second The second of minute in the desired time, in the range [0, 59].
   * @param nanosecondWithinSecond The nanosecond within the second in the desired time, in the range [0, 999999999].
   * @throws {ArgumentOutOfRangeException} The parameters do not form a valid time.
   * @returns The resulting time.
   */
  static FromHourMinuteSecondNanosecond(hour: number, minute: number, second: number, nanosecondWithinSecond: number): LocalTime {
    // Avoid the method calls which give a decent exception unless we're actually going to fail.
    if (hour < 0 || hour > HoursPerDay - 1 ||
      minute < 0 || minute > MinutesPerHour - 1 ||
      second < 0 || second > SecondsPerMinute - 1 ||
      nanosecondWithinSecond < 0 || nanosecondWithinSecond > NanosecondsPerSecond - 1) {
      Preconditions.CheckArgumentRange("hour", hour, 0, HoursPerDay - 1);
      Preconditions.CheckArgumentRange("minute", minute, 0, MinutesPerHour - 1);
      Preconditions.CheckArgumentRange("second", second, 0, SecondsPerMinute - 1);
      Preconditions.CheckArgumentRange("nanosecondWithinSecond", nanosecondWithinSecond, 0, NanosecondsPerSecond - 1);
    }
    return LocalTime.FromHourMinuteSecondNanosecondTrusted(hour, minute, second, nanosecondWithinSecond);
  }

  /**
   * Factory method for creating a local time from the hour of day, minute of hour, second of minute, and nanosecond of second
   * where the values have already been validated.
   * @internal
   */
  static FromHourMinuteSecondNanosecondTrusted(hour: number, minute: number, second: number, nanosecondWithinSecond: number): LocalTime {
    return LocalTime.NewNanoseconds(
      hour * NanosecondsPerHour +
      minute * NanosecondsPerMinute +
      second * NanosecondsPerSecond +
      nanosecondWithinSecond);
  }

  /**
   * Constructor only called from other parts of Noda Time - trusted to be the range [0, NanosecondsPerDay).
   * @internal
   */
  static NewNanoseconds(nanoseconds: number): LocalTime {
    Preconditions.DebugCheckArgumentRange("nanoseconds", nanoseconds, 0, NanosecondsPerDay - 1);
    const result: { _nanoseconds: number } = Object.create(LocalTime.prototype);
    result._nanoseconds = nanoseconds;
    return result as unknown as LocalTime;
  }

  /**
   * Factory method for creating a local time from the number of nanoseconds which have elapsed since midnight.
   * @param nanoseconds The number of nanoseconds, in the range [0, 86,399,999,999,999]
   * @returns The resulting time.
   */
  static FromNanosecondsSinceMidnight(nanoseconds: number | string): LocalTime {
    // noda-js: the C# long argument, exactly.
    const longNanoseconds = Int64.FromArgument(nanoseconds, "nanoseconds");
    // Avoid the method calls which give a decent exception unless we're actually going to fail.
    if (typeof longNanoseconds !== "number" || longNanoseconds < 0 || longNanoseconds > NanosecondsPerDay - 1) {
      Preconditions.CheckArgumentRange("nanoseconds", longNanoseconds, 0, NanosecondsPerDay - 1);
    }
    return LocalTime.NewNanoseconds(longNanoseconds as number);
  }

  /**
   * Factory method for creating a local time from the number of ticks which have elapsed since midnight.
   * @param ticks The number of ticks, in the range [0, 863,999,999,999]
   * @returns The resulting time.
   */
  static FromTicksSinceMidnight(ticks: number | string): LocalTime {
    // noda-js: the C# long argument, exactly.
    const longTicks = Int64.FromArgument(ticks, "ticks");
    // Avoid the method calls which give a decent exception unless we're actually going to fail.
    if (typeof longTicks !== "number" || longTicks < 0 || longTicks > TicksPerDay - 1) {
      Preconditions.CheckArgumentRange("ticks", longTicks, 0, TicksPerDay - 1);
    }
    return LocalTime.NewNanoseconds((longTicks as number) * NanosecondsPerTick);
  }

  /**
   * Factory method for creating a local time from the number of milliseconds which have elapsed since midnight.
   * @param milliseconds The number of milliseconds, in the range [0, 86,399,999]
   * @returns The resulting time.
   */
  static FromMillisecondsSinceMidnight(milliseconds: number): LocalTime {
    // Avoid the method calls which give a decent exception unless we're actually going to fail.
    if (milliseconds < 0 || milliseconds > MillisecondsPerDay - 1) {
      Preconditions.CheckArgumentRange("milliseconds", milliseconds, 0, MillisecondsPerDay - 1);
    }
    return LocalTime.NewNanoseconds(milliseconds * NanosecondsPerMillisecond);
  }

  /**
   * Factory method for creating a local time from the number of seconds which have elapsed since midnight.
   * @param seconds The number of seconds, in the range [0, 86,399]
   * @returns The resulting time.
   */
  static FromSecondsSinceMidnight(seconds: number): LocalTime {
    // Avoid the method calls which give a decent exception unless we're actually going to fail.
    if (seconds < 0 || seconds > SecondsPerDay - 1) {
      Preconditions.CheckArgumentRange("seconds", seconds, 0, SecondsPerDay - 1);
    }
    return LocalTime.NewNanoseconds(seconds * NanosecondsPerSecond);
  }

  /**
   * Factory method for creating a local time from the number of minutes which have elapsed since midnight.
   * @param minutes The number of minutes, in the range [0, 1439]
   * @returns The resulting time.
   */
  static FromMinutesSinceMidnight(minutes: number): LocalTime {
    // Avoid the method calls which give a decent exception unless we're actually going to fail.
    if (minutes < 0 || minutes > MinutesPerDay - 1) {
      Preconditions.CheckArgumentRange("minutes", minutes, 0, MinutesPerDay - 1);
    }
    return LocalTime.NewNanoseconds(minutes * NanosecondsPerMinute);
  }

  /**
   * Factory method for creating a local time from the number of hours which have elapsed since midnight.
   * @param hours The number of hours, in the range [0, 23]
   * @returns The resulting time.
   */
  static FromHoursSinceMidnight(hours: number): LocalTime {
    // Avoid the method calls which give a decent exception unless we're actually going to fail.
    if (hours < 0 || hours > HoursPerDay - 1) {
      Preconditions.CheckArgumentRange("hours", hours, 0, HoursPerDay - 1);
    }
    return LocalTime.NewNanoseconds(hours * NanosecondsPerHour);
  }

  /** Gets the hour of day of this local time, in the range 0 to 23 inclusive. */
  get Hour(): number {
    // noda-js: NodaTime computes this with a shift and division for efficiency; the result is the same.
    return Math.trunc(this._nanoseconds / NanosecondsPerHour);
  }

  /** Gets the hour of the half-day of this local time, in the range 1 to 12 inclusive. */
  get ClockHourOfHalfDay(): number {
    const hourOfHalfDay = this.Hour % 12;
    return hourOfHalfDay === 0 ? 12 : hourOfHalfDay;
  }

  /** Gets the minute of this local time, in the range 0 to 59 inclusive. */
  get Minute(): number {
    // noda-js: NodaTime computes this with a shift and division for efficiency; the result is the same.
    const minuteOfDay = Math.trunc(this._nanoseconds / NanosecondsPerMinute);
    return minuteOfDay % MinutesPerHour;
  }

  /** Gets the second of this local time within the minute, in the range 0 to 59 inclusive. */
  get Second(): number {
    const secondOfDay = Math.trunc(this._nanoseconds / NanosecondsPerSecond);
    return secondOfDay % SecondsPerMinute;
  }

  /** Gets the millisecond of this local time within the second, in the range 0 to 999 inclusive. */
  get Millisecond(): number {
    const milliSecondOfDay = Math.trunc(this._nanoseconds / NanosecondsPerMillisecond);
    return milliSecondOfDay % MillisecondsPerSecond;
  }

  // TODO(optimization): Rewrite for performance?
  /** Gets the tick of this local time within the second, in the range 0 to 9,999,999 inclusive. */
  get TickOfSecond(): number {
    return this.TickOfDay % TicksPerSecond;
  }

  /**
   * Gets the tick of this local time within the day, in the range 0 to 863,999,999,999 inclusive.
   *
   * If the value does not fall on a tick boundary, it will be truncated towards zero.
   */
  get TickOfDay(): number {
    return Math.trunc(this._nanoseconds / NanosecondsPerTick);
  }

  /** Gets the nanosecond of this local time within the second, in the range 0 to 999,999,999 inclusive. */
  get NanosecondOfSecond(): number {
    return this._nanoseconds % NanosecondsPerSecond;
  }

  /** Gets the nanosecond of this local time within the day, in the range 0 to 86,399,999,999,999 inclusive. */
  get NanosecondOfDay(): number {
    return this._nanoseconds;
  }

  /**
   * Adds the specified period to the time. Friendly alternative to `operator+()`.
   * @param time The time to add the period to
   * @param period The period to add. Must not contain any (non-zero) date units.
   * @returns The sum of the given time and period
   */
  static Add(time: LocalTime, period: Period): LocalTime {
    Preconditions.CheckNotNull(period, "period");
    Preconditions.CheckArgument(!period.HasDateComponent, "period", "Cannot add a period with a date component to a time");
    // noda-js: C# calls time.PlusHours(period.Hours) and so on, which call TimePeriodField.Hours.Add(...). That's
    // done directly here, with the exact values of the long-valued properties (which may exceed 2^53).
    let result = TimePeriodField.Hours.Add(time, period.ExactHours);
    result = TimePeriodField.Minutes.Add(result, period.ExactMinutes);
    result = TimePeriodField.Seconds.Add(result, period.ExactSeconds);
    result = TimePeriodField.Milliseconds.Add(result, period.ExactMilliseconds);
    result = TimePeriodField.Ticks.Add(result, period.ExactTicks);
    return TimePeriodField.Nanoseconds.Add(result, period.ExactNanoseconds);
  }

  /**
   * Adds the specified period to this time. Fluent alternative to `operator+()`.
   * @param period The period to add. Must not contain any (non-zero) date units.
   * @returns The sum of this time and the given period
   */
  Plus(period: Period): LocalTime {
    return LocalTime.Add(this, period);
  }

  /**
   * Subtracts the specified period from the time, or one time from another. Friendly alternative to `operator-()`.
   *
   * When subtracting a period, the period must not contain any date-related units (days etc) with non-zero values,
   * and the result wraps via midnight if necessary.
   *
   * When subtracting a time, the result is a {@link Period}; this is simply a convenience method for calling
   * {@link Period.Between} with `rhs` and `lhs`.
   * @param lhs The time to subtract from
   * @param rhs The period or time to subtract.
   * @returns The result of the subtraction.
   */
  static Subtract(lhs: LocalTime, rhs: Period): LocalTime;
  static Subtract(lhs: LocalTime, rhs: LocalTime): Period;
  static Subtract(lhs: LocalTime, rhs: Period | LocalTime): LocalTime | Period {
    if (rhs instanceof LocalTime) {
      return Period.Between(rhs, lhs);
    }
    const period = rhs;
    Preconditions.CheckNotNull(period, "period");
    Preconditions.CheckArgument(!period.HasDateComponent, "period", "Cannot subtract a period with a date component from a time");
    // noda-js: C# calls lhs.PlusHours(-period.Hours) and so on, which call TimePeriodField.Hours.Add(...). That's
    // done directly here, with the exact values of the long-valued properties (which may exceed 2^53).
    let result = TimePeriodField.Hours.Add(lhs, Int64.Negate(period.ExactHours));
    result = TimePeriodField.Minutes.Add(result, Int64.Negate(period.ExactMinutes));
    result = TimePeriodField.Seconds.Add(result, Int64.Negate(period.ExactSeconds));
    result = TimePeriodField.Milliseconds.Add(result, Int64.Negate(period.ExactMilliseconds));
    result = TimePeriodField.Ticks.Add(result, Int64.Negate(period.ExactTicks));
    return TimePeriodField.Nanoseconds.Add(result, Int64.Negate(period.ExactNanoseconds));
  }

  /**
   * Subtracts the specified period from this time. Fluent alternative to `operator-()`.
   * @param period The period to subtract. Must not contain any (non-zero) date units.
   * @returns The result of subtracting the given period from this time.
   */
  Minus(period: Period): LocalTime;
  /**
   * Subtracts the specified time from this time, returning the result as a {@link Period}.
   * Fluent alternative to `operator-()`.
   * @param time The time to subtract from this
   * @returns The difference between the specified time and this one
   */
  Minus(time: LocalTime): Period;
  Minus(periodOrTime: Period | LocalTime): LocalTime | Period {
    return periodOrTime instanceof LocalTime ? LocalTime.Subtract(this, periodOrTime) : LocalTime.Subtract(this, periodOrTime);
  }

  /**
   * Indicates whether this time is earlier, later or the same as another one.
   * See the type documentation for a description of ordering semantics.
   *
   * noda-js: this also covers the non-generic IComparable.CompareTo: a null argument compares as less than this value.
   * @param other The other date/time to compare this one with
   * @returns A value less than zero if this time is earlier than `other`;
   * zero if this time is the same as `other`; a value greater than zero if this time is
   * later than `other` (or `other` is null).
   * @throws {ArgumentException} `other` is non-null but is not a {@link LocalTime}.
   */
  CompareTo(other: LocalTime | null): number;
  /** @inheritDoc */
  CompareTo(other: unknown): number;
  CompareTo(other: unknown): number {
    if (other === null || other === undefined) {
      return 1;
    }
    Preconditions.CheckArgument(other instanceof LocalTime, "obj", "Object must be of type NodaTime.LocalTime.");
    const that = other as LocalTime;
    return this._nanoseconds < that._nanoseconds ? -1 : this._nanoseconds > that._nanoseconds ? 1 : 0;
  }

  // Not ported: GetHashCode

  /**
   * Compares this local time with the specified value for equality.
   * See the type documentation for a description of equality semantics.
   * @param other The value to compare this one with
   * @returns True if the specified value is a local time which is equal to this one; false otherwise
   *
   * noda-js: covers both `IEquatable<LocalTime>.Equals(LocalTime)` and `object.Equals(object)`.
   */
  Equals(other: LocalTime): boolean;
  /** @inheritDoc */
  Equals(other: unknown): boolean;
  Equals(other: unknown): boolean {
    return other instanceof LocalTime && this._nanoseconds === other._nanoseconds;
  }

  /**
   * Returns a new LocalTime representing the current value with the given number of hours added.
   *
   * If the value goes past the start or end of the day, it wraps - so 11pm plus two hours is 1am, for example.
   * @param hours The number of hours to add
   * @returns The current value plus the given number of hours.
   */
  PlusHours(hours: number | string): LocalTime {
    return TimePeriodField.Hours.Add(this, Int64.FromArgument(hours, "hours"));
  }

  /**
   * Returns a new LocalTime representing the current value with the given number of minutes added.
   *
   * If the value goes past the start or end of the day, it wraps - so 11pm plus 120 minutes is 1am, for example.
   * @param minutes The number of minutes to add
   * @returns The current value plus the given number of minutes.
   */
  PlusMinutes(minutes: number | string): LocalTime {
    return TimePeriodField.Minutes.Add(this, Int64.FromArgument(minutes, "minutes"));
  }

  /**
   * Returns a new LocalTime representing the current value with the given number of seconds added.
   *
   * If the value goes past the start or end of the day, it wraps - so 11:59pm plus 120 seconds is 12:01am, for example.
   * @param seconds The number of seconds to add
   * @returns The current value plus the given number of seconds.
   */
  PlusSeconds(seconds: number | string): LocalTime {
    return TimePeriodField.Seconds.Add(this, Int64.FromArgument(seconds, "seconds"));
  }

  /**
   * Returns a new LocalTime representing the current value with the given number of milliseconds added.
   * @param milliseconds The number of milliseconds to add
   * @returns The current value plus the given number of milliseconds.
   */
  PlusMilliseconds(milliseconds: number | string): LocalTime {
    return TimePeriodField.Milliseconds.Add(this, Int64.FromArgument(milliseconds, "milliseconds"));
  }

  /**
   * Returns a new LocalTime representing the current value with the given number of ticks added.
   * @param ticks The number of ticks to add
   * @returns The current value plus the given number of ticks.
   */
  PlusTicks(ticks: number | string): LocalTime {
    return TimePeriodField.Ticks.Add(this, Int64.FromArgument(ticks, "ticks"));
  }

  /**
   * Returns a new LocalTime representing the current value with the given number of nanoseconds added.
   * @param nanoseconds The number of nanoseconds to add
   * @returns The current value plus the given number of ticks.
   */
  PlusNanoseconds(nanoseconds: number | string): LocalTime {
    return TimePeriodField.Nanoseconds.Add(this, Int64.FromArgument(nanoseconds, "nanoseconds"));
  }

  /**
   * Returns this time, with the given adjuster applied to it.
   *
   * If the adjuster attempts to construct an invalid time, any exception thrown by
   * that construction attempt will be propagated through this method.
   * @param adjuster The adjuster to apply.
   * @returns The adjusted time.
   */
  With(adjuster: (time: LocalTime) => LocalTime): LocalTime {
    return Preconditions.CheckNotNull(adjuster, "adjuster")(this);
  }

  /**
   * Returns an {@link OffsetTime} for this time-of-day with the given offset.
   *
   * This method is purely a convenient alternative to calling the {@link OffsetTime} constructor directly.
   * @param offset The offset to apply.
   * @returns The result of this time-of-day offset by the given amount.
   */
  WithOffset(offset: Offset): OffsetTime {
    return new OffsetTime(this, offset);
  }

  /**
   * Combines this {@link LocalTime} with the given {@link LocalDate}
   * into a single {@link LocalDateTime}.
   * Fluent alternative to `operator+()`.
   * @param date The date to combine with this time
   * @returns The {@link LocalDateTime} representation of the given time on this date
   */
  On(date: LocalDate): LocalDateTime {
    return date.At(this);
  }

  // Not ported: Deconstruct

  /**
   * Returns the later time of the given two.
   * @param x The first time to compare.
   * @param y The second time to compare.
   * @returns The later instant of `x` or `y`.
   */
  static Max(x: LocalTime, y: LocalTime): LocalTime {
    return x.CompareTo(y) > 0 ? x : y;
  }

  /**
   * Returns the earlier time of the given two.
   * @param x The first time to compare.
   * @param y The second time to compare.
   * @returns The earlier time of `x` or `y`.
   */
  static Min(x: LocalTime, y: LocalTime): LocalTime {
    return x.CompareTo(y) < 0 ? x : y;
  }

  // #region Formatting
  /**
   * Formats the value of the current instance using the specified pattern.
   *
   * noda-js: with no arguments, this uses the default format pattern ("T") and the invariant culture
   * (NodaTime uses the current thread's culture).
   * @param patternText The pattern to use, or null to use the default format pattern ("T").
   * @param formatProvider The format provider to use when formatting the value,
   * or null to use the invariant culture.
   * @returns The value of the current instance in the specified format.
   */
  toString(patternText: string | null = null, formatProvider: IFormatProvider | null = null): string {
    return LocalTimePattern.BclSupport.Format(this, patternText, formatProvider ?? NodaCultureInfo.InvariantCulture);
  }
  // #endregion Formatting

  // #region XML serialization
  // Not ported: AddSchema, IXmlSerializable members (XML serialization)
  // #endregion

  // #region TimeOnly conversions (.NET 6 only)
  // Not ported: ToTimeOnly, FromTimeOnly (BCL interop)
  // #endregion

  // #region JSON (noda-js)
  /** Formats this value with {@link LocalTimePattern.ExtendedIso}, as NodaTime.Serialization.SystemTextJson does. */
  toJSON(): string {
    return LocalTimePattern.ExtendedIso.Format(this);
  }

  /**
   * Parses a value written by {@link toJSON}.
   * @throws {UnparsableValueException} The text could not be parsed.
   */
  static fromJSON(json: string): LocalTime {
    return LocalTimePattern.ExtendedIso.Parse(json).Value;
  }
  // #endregion

  /** Throws a TypeError: use {@link CompareTo} or {@link Equals} instead of relational operators. */
  valueOf(): never {
    return ThrowValueOf("LocalTime");
  }
}
