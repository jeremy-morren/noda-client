// Ported from NodaTime 3.3.0: src/NodaTime/Duration.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import {
  ArgumentOutOfRangeError,
  NodaCultureInfo,
  DurationPattern,
  Int32,
  Int64,
  Long,
  OverflowError,
  Preconditions,
  TickArithmetic,
  WideInteger,
  ThrowValueOf,
} from "./internal.ts";
import type { IComparable, IEquatable, IFormatProvider, Int64Value } from "./internal.ts";
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
  TicksPerSecond,
} from "./NodaConstants.generated.ts";
import type { Instant, LocalDateTime, Period, ZonedDateTime } from "./internal.ts";

// Implementation note:
// Although we use BigInteger in the public API as it's a better fit for "this could be a large integer"
// we use decimal for computations where we have to. It's more efficient in CPU (and space) than BigInteger,
// and still has plenty of range/precision. The FromNanoseconds(BigInteger) and ToBigIntegerNanoseconds() methods
// should not be called within Noda Time, except for in FromNanoseconds(double), as the double to decimal conversion
// loses information whereas double to BigInteger doesn't.
//
// noda-js: there is no BigInt (noda-js targets ES2015). A C# long is an Int64Value (a number when it's a safe integer,
// otherwise an exact Long; see Utility/Numbers.ts), and the rare decimal / BigInteger computations use the exact
// WideInteger helper (Utility/WideInteger.ts). Where NodaTime relies on decimal semantics (overflow beyond 96 bits,
// rounding of a division result) those semantics are reproduced explicitly; see decimalMax and fromDecimalQuotient
// below. FromNanoseconds(BigInteger), FromNanoseconds(Int128), ToBigIntegerNanoseconds and ToInt128Nanoseconds are not
// ported.

/**
 * Equivalent of System.DivideByZeroException, thrown when dividing a duration by zero.
 * noda-js: defined here as Duration is the only NodaTime type which throws it.
 */
export class DivideByZeroError extends RangeError {
  override name = "DivideByZeroError";
  constructor(message?: string) {
    super(message ?? "Attempted to divide by zero.");
  }
}

// This is one more bit than we really need, but it allows Instant.BeforeMinValue and Instant.AfterMaxValue
// to be easily constructed with valid durations, even though the result is a deliberately-invalid instant.
const MaxDays = (1 << 24) - 1;
const MinDays = ~MaxDays;
// noda-js: MinNanoseconds and MaxNanoseconds (BigInteger in NodaTime) as text, for error messages; see minNanoseconds() and
// maxNanoseconds() for the exact values.
const MinNanosecondsText = "-1449551462400000000000";
const MaxNanosecondsText = "1449551462399999999999";
// (double) MinNanoseconds and (double) MaxNanoseconds. MinDays * NanosecondsPerDay is exact (2^40 * 1318359375); the
// double nearest to MaxNanoseconds is (MaxDays + 1) * NanosecondsPerDay.
const MinDoubleNanoseconds = MinDays * NanosecondsPerDay;
const MaxDoubleNanoseconds = (MaxDays + 1) * NanosecondsPerDay;

// The -1 here is to allow for the addition of nearly a whole day in the nanoOfDay field.
// (long.MaxValue / NanosecondsPerDay is 106751, and long.MinValue / NanosecondsPerDay is -106751, truncated.)
const MaxDaysForLongNanos = 106751 - 1;
const MinDaysForLongNanos = -106751;

let zero: Duration | undefined;
let minNanosecondsValue: WideInteger | undefined;
let maxNanosecondsValue: WideInteger | undefined;
let decimalMaxValue: WideInteger | undefined;
let nanosecondsPerDayValue: WideInteger | undefined;

/** Duration.MinNanoseconds, exactly. */
function MinNanoseconds(): WideInteger {
  return (minNanosecondsValue ??= WideInteger.FromNumber(MinDays * NanosecondsPerDay));
}

/** Duration.MaxNanoseconds, exactly. */
function MaxNanoseconds(): WideInteger {
  return (maxNanosecondsValue ??= MinNanoseconds().Negate().Subtract(WideInteger.FromNumber(1)));
}

/** noda-js: decimal.MaxValue (2^96 - 1); decimal arithmetic producing a larger magnitude throws OverflowException. */
function DecimalMax(): WideInteger {
  return (decimalMaxValue ??= WideInteger.FromNumber(2 ** 96).Subtract(WideInteger.FromNumber(1)));
}

function NanosecondsPerDayWide(): WideInteger {
  return (nanosecondsPerDayValue ??= WideInteger.FromNumber(NanosecondsPerDay));
}

/**
 * Represents a fixed (and calendar-independent) length of time.
 *
 * A duration is a length of time defined by an integral number of nanoseconds.
 * Although durations are usually used with a positive number of nanoseconds, negative durations are valid, and may occur
 * naturally when e.g. subtracting a later {@link Instant} from an earlier one.
 *
 * Equality and ordering are defined in the natural way, simply comparing the number of nanoseconds contained.
 *
 * A duration represents a fixed length of elapsed time along the time line that occupies the same amount of
 * time regardless of when it is applied. In contrast, {@link Period} represents a period of time in
 * calendrical terms (years, months, days, and so on) that may vary in elapsed time when applied.
 *
 * In general, use {@link Duration} to represent durations applied to global types like {@link Instant}
 * and {@link ZonedDateTime}; use `Period` to represent a period applied to local types like
 * {@link LocalDateTime}.
 *
 * The range of valid values of a `Duration` is greater than the span of time supported by Noda Time - so for
 * example, subtracting one {@link Instant} from another will always give a valid `Duration`. The range
 * is also greater than that of TimeSpan (long.MinValue ticks to long.MaxValue ticks).
 * See the user guide for more details of the exact range, but it is not expected that this will ever be exceeded in normal code.
 *
 * Various operations accept or return a double (`number`), in-keeping with durations often being natural lengths
 * of time which are imprecisely measured anyway. The implementation of these operations should never result in a not-a-number
 * or infinite value, nor do any operations accept not-a-number or infinite values. Additionally, operations involving
 * doubles have initially been implemented fairly naively; it's possible that future releases will improve the accuracy
 * or performance (or both) of various operations.
 *
 * The default value of this type is {@link Duration.Zero}.
 *
 * This type is an immutable value type. See the thread safety section of the user guide for more information.
 */
export class Duration implements IEquatable<Duration>, IComparable<Duration> {
  /** @internal */
  static readonly MaxDays = MaxDays;
  /** @internal */
  static readonly MinDays = MinDays;
  // noda-js: MinNanoseconds, MaxNanoseconds, MinDecimalNanoseconds and MaxDecimalNanoseconds are the module functions
  // minNanoseconds() and maxNanoseconds() (WideInteger); MinInt128Nanoseconds and MaxInt128Nanoseconds aren't needed.

  // #region Readonly static properties

  /** Gets a zero {@link Duration} of 0 nanoseconds. */
  static get Zero(): Duration {
    return (zero ??= new Duration(0, 0));
  }

  /** Gets the additive identity. */
  static get AdditiveIdentity(): Duration {
    return Duration.Zero;
  }

  /** Gets a {@link Duration} value equal to 1 nanosecond; the smallest amount by which an instant can vary. */
  static get Epsilon(): Duration {
    return new Duration(0, 1);
  }

  /** Gets the maximum value supported by {@link Duration}. */
  static get MaxValue(): Duration {
    return new Duration(MaxDays, NanosecondsPerDay - 1);
  }

  /** Gets the minimum (largest negative) value supported by {@link Duration}. */
  static get MinValue(): Duration {
    return new Duration(MinDays, 0);
  }

  /**
   * Represents the {@link Duration} value equal to the number of nanoseconds in 1 standard week (7 days).
   *
   * The value of this property is 604,800,000,000,000 nanoseconds.
   * @internal
   */
  static get OneWeek(): Duration {
    return new Duration(7, 0);
  }

  /**
   * Represents the {@link Duration} value equal to the number of nanoseconds in 1 day.
   *
   * The value of this property is 86.4 trillion nanoseconds; that is, 86,400,000,000,000 nanoseconds.
   * @internal
   */
  static get OneDay(): Duration {
    return new Duration(1, 0);
  }
  // #endregion

  // This is effectively a 25 bit value. (It can't be 24 bits, or we can't represent every TimeSpan value.)
  // noda-js: NodaTime's "days" field; renamed as it would clash with the Days property.
  private readonly _days: number;
  // Always non-negative; a negative duration will have a negative number of days, but may have a
  // positive nanoOfDay. (A duration of -1ns will have a days value of -1 and a nanoOfDay of
  // NanosecondsPerDay - 1, for example.)
  private readonly _nanoOfDay: number;

  // Trusted constructor with no validation.
  private constructor(days: number, nanoOfDay: number) {
    this._days = days;
    this._nanoOfDay = nanoOfDay;
  }

  /**
   * Trusted constructor with no validation. (NodaTime's noValidation parameter is ignored completely;
   * its name is just to be suggestive.)
   * @internal
   */
  static NewDaysNanoOfDayNoValidation(days: number, nanoOfDay: number, _noValidation?: boolean): Duration {
    return new Duration(days, nanoOfDay);
  }

  // Implementation note: I've tried making this internal and calling it directly from Instant.FromUnixTimeSeconds etc?
  // That reduces the number of range checks, but doesn't seem to affect the performance in a significant way.
  // Leaving it as it is leaves a cleaner API - this constructor doesn't feel like something that *should*
  // be exposed to other classes.

  /**
   * Constructs an instance from a given number of units. This was previously a method (FromUnits) but making it a
   * constructor avoids calling the other constructor which validates its "days" parameter.
   * Note that we could compute various parameters from nanosPerUnit, but we know them as compile-time constants, so
   * there's no point in recomputing them on each call.
   * @param units Number of units
   * @param paramName Name of the parameter, e.g. "hours"
   * @param minValue Minimum number of units for a valid duration.
   * @param maxValue Maximum number of units for a valid duration.
   * @param unitsPerDay Number of units in a day.
   * @param nanosPerUnit Number of nanoseconds per unit.
   */
  private static NewUnitsParamNameMinValueMaxValueUnitsPerDayNanosPerUnit(
    units: number, paramName: string, minValue: number, maxValue: number, unitsPerDay: number, nanosPerUnit: number): Duration {
    Preconditions.CheckArgumentRange(paramName, units, minValue, maxValue);
    // Note: DivRem appears to make this (significantly) slower, despite helping in Period.
    let days = Math.trunc(units / unitsPerDay);
    let unitOfDay = units - (unitsPerDay * days);
    if (unitOfDay < 0) {
      days--;
      unitOfDay += unitsPerDay;
    }
    return new Duration(days, unitOfDay * nanosPerUnit);
  }

  /** @internal */
  static NewDaysNanoOfDay(days: number, nanoOfDay: number): Duration {
    // Heavily used: avoid the method call unless it's going to throw.
    // (Benchmarking Duration.FromDays, unconditionally calling CheckArgumentRange
    // raises the call time from ~2ns to ~15ns.)
    if (days < MinDays || days > MaxDays) {
      Preconditions.CheckArgumentRange("days", days, MinDays, MaxDays);
    }
    Preconditions.DebugCheckArgumentRange("nanoOfDay", nanoOfDay, 0, NanosecondsPerDay - 1);
    return new Duration(days, nanoOfDay);
  }

  /**
   * Days portion of this duration. The {@link NanosecondOfFloorDay} is added to this
   * value, so this effectively Math.Floor(TotalDays).
   * @internal
   */
  get FloorDays(): number {
    return this._days;
  }

  /**
   * Nanosecond within the "floor day". This is *always* non-negative, even for
   * negative durations.
   * @internal
   */
  get NanosecondOfFloorDay(): number {
    return this._nanoOfDay;
  }

  /**
   * Gets the whole number of standard (24 hour) days within this duration. This is truncated towards zero;
   * for example, "-1.75 days" and "1.75 days" would have results of -1 and 1 respectively.
   */
  get Days(): number {
    return this._days >= 0 || this._nanoOfDay === 0 ? this._days : this._days + 1;
  }

  /**
   * Gets the number of nanoseconds within the day of this duration. For negative durations, this
   * will be negative (or zero).
   */
  get NanosecondOfDay(): number {
    return this._days >= 0 ? this._nanoOfDay
      : this._nanoOfDay === 0 ? 0
      : this._nanoOfDay - NanosecondsPerDay;
  }

  /** The hour component of this duration, in the range [-23, 23], truncated towards zero. */
  get Hours(): number {
    return Math.trunc(this.NanosecondOfDay / NanosecondsPerHour);
  }

  /** The minute component of this duration, in the range [-59, 59], truncated towards zero. */
  get Minutes(): number {
    return Math.trunc(this.NanosecondOfDay / NanosecondsPerMinute) % MinutesPerHour;
  }

  /** Gets the second component of this duration, in the range [-59, 59], truncated towards zero. */
  get Seconds(): number {
    return Math.trunc(this.NanosecondOfDay / NanosecondsPerSecond) % SecondsPerMinute;
  }

  /** Gets the subsecond component of this duration, expressed in milliseconds, in the range [-999, 999] and truncated towards zero. */
  get Milliseconds(): number {
    return Math.trunc(this.NanosecondOfDay / NanosecondsPerMillisecond) % MillisecondsPerSecond;
  }

  /** Gets the subsecond component of this duration, expressed in ticks, in the range [-9999999, 9999999] and truncated towards zero. */
  get SubsecondTicks(): number {
    return Math.trunc(this.NanosecondOfDay / NanosecondsPerTick) % TicksPerSecond;
  }

  /** Gets the subsecond component of this duration, expressed in nanoseconds, in the range [-999999999, 999999999]. */
  get SubsecondNanoseconds(): number {
    return this.NanosecondOfDay % NanosecondsPerSecond;
  }

  /**
   * Gets the total number of ticks in the duration as a 64-bit integer, truncating towards zero where necessary.
   *
   * Within the constraints specified below, this property is intended to be equivalent to TimeSpan.Ticks.
   *
   * If the number of nanoseconds in a duration is not a whole number of ticks, it is truncated towards zero.
   * For example, durations in the range [-99ns, 99ns] would all count as 0 ticks.
   *
   * Although this method can overflow, it will only do so in very exceptional cases, with durations
   * with a magnitude of more than 29000 Gregorian years or so.
   * @throws {OverflowError} The number of ticks cannot be represented a signed 64-bit integer.
   * @see {@link TotalTicks}
   */
  get BclCompatibleTicks(): number {
    // noda-js: computed exactly (and checked) as a C# long, then returned as the nearest number.
    let ticks = TickArithmetic.DaysAndTickOfDayToTicks(this._days, Math.trunc(this._nanoOfDay / NanosecondsPerTick));
    if (this._days < 0 && this._nanoOfDay % NanosecondsPerTick !== 0) {
      ticks = Int64.Add(ticks, 1);
    }
    return Int64.ToNumber(ticks);
  }

  // TODO(optimization): Reimplement all of these using TotalNanoseconds?

  /**
   * Gets the total number of days in this duration, as a double.
   *
   * This property is the `Duration` equivalent of TimeSpan.TotalDays.
   * It represents the complete duration in days, rather than only the whole number of
   * days. For example, for a duration of 36 hours, this property would return 1.5.
   */
  get TotalDays(): number {
    return this._days + this._nanoOfDay / NanosecondsPerDay;
  }

  /**
   * Gets the total number of hours in this duration, as a double.
   *
   * This property is the `Duration` equivalent of TimeSpan.TotalHours.
   * Unlike {@link Hours}, it represents the complete duration in hours rather than the
   * whole number of hours as part of the day. So for a duration
   * of 1 day, 2 hours and 30 minutes, the `hours` property will return 2, but `totalHours`
   * will return 26.5.
   */
  get TotalHours(): number {
    return this._days * 24.0 + this._nanoOfDay / NanosecondsPerHour;
  }

  /**
   * Gets the total number of minutes in this duration, as a double.
   *
   * This property is the `Duration` equivalent of TimeSpan.TotalMinutes.
   * Unlike {@link Minutes}, it represents the complete duration in minutes rather than
   * the whole number of minutes within the hour. So for a duration
   * of 2 hours, 30 minutes and 45 seconds, the `minutes` property will return 30, but `totalMinutes`
   * will return 150.75.
   */
  get TotalMinutes(): number {
    return this._days * MinutesPerDay + this._nanoOfDay / NanosecondsPerMinute;
  }

  /**
   * Gets the total number of seconds in this duration, as a double.
   *
   * This property is the `Duration` equivalent of TimeSpan.TotalSeconds.
   * Unlike {@link Seconds}, it represents the complete duration in seconds rather than
   * the whole number of seconds within the minute. So for a duration
   * of 10 minutes, 20 seconds and 250 milliseconds, the `seconds` property will return 20, but `totalSeconds`
   * will return 620.25.
   */
  get TotalSeconds(): number {
    return this._days * SecondsPerDay + this._nanoOfDay / NanosecondsPerSecond;
  }

  /**
   * Gets the total number of milliseconds in this duration, as a double.
   *
   * This property is the `Duration` equivalent of TimeSpan.TotalMilliseconds.
   * Unlike {@link Milliseconds}, it represents the complete duration in milliseconds rather than
   * the whole number of milliseconds within the second. So for a duration
   * of 10 minutes, 20 seconds and 250 milliseconds, the `milliseconds` property will return 250, but `totalMilliseconds`
   * will return 620250.
   */
  get TotalMilliseconds(): number {
    return this._days * MillisecondsPerDay + this._nanoOfDay / NanosecondsPerMillisecond;
  }

  /**
   * Gets the total number of ticks in this duration, as a double.
   *
   * This property is the `Duration` equivalent of TimeSpan.Ticks,
   * except represented as double-precision floating point number instead of a 64-bit integer. This
   * is because {@link Duration} has a precision of nanoseconds, and also because the range
   * of 64-bit integers doesn't cover the number of possible ticks in a {@link Duration}. (The
   * latter is only an issue in durations outside the range of TimeSpan - in other words,
   * with magnitudes of over 29,000 years.)
   * @see {@link BclCompatibleTicks}
   */
  get TotalTicks(): number {
    return this._days * TicksPerDay + this._nanoOfDay / NanosecondsPerTick;
  }

  /**
   * Gets the total number of nanoseconds in this duration, as a double.
   *
   * The result is always an integer, but may not be precise due to the limitations
   * of the double type. In other works, `Duration.fromNanoseconds(duration.totalNanoseconds)`
   * is not guaranteed to round-trip. (noda-js: NodaTime's ToBigIntegerNanoseconds and FromNanoseconds(BigInteger),
   * which guarantee that, aren't ported; {@link ToInt64Nanoseconds} and {@link Duration.FromNanoseconds} with a decimal
   * string round-trip exactly within the range of a C# long.)
   */
  get TotalNanoseconds(): number {
    return this._days * NanosecondsPerDay + this._nanoOfDay;
  }

  /**
   * Adds a "small" number of nanoseconds to this duration: it is trusted to be less or equal to than 24 hours
   * in magnitude.
   * @internal
   */
  PlusSmallNanoseconds(smallNanos: number): Duration {
    Preconditions.DebugCheckArgumentRange("smallNanos", smallNanos, -NanosecondsPerDay, NanosecondsPerDay);
    let newDays = this._days;
    let newNanos = this._nanoOfDay + smallNanos;
    if (newNanos >= NanosecondsPerDay) {
      newDays++;
      newNanos -= NanosecondsPerDay;
    } else if (newNanos < 0) {
      newDays--;
      newNanos += NanosecondsPerDay;
    }
    return Duration.NewDaysNanoOfDay(newDays, newNanos);
  }

  /**
   * Subtracts a "small" number of nanoseconds from this duration: it is trusted to be less than 24 hours
   * in magnitude.
   * @internal
   */
  MinusSmallNanoseconds(smallNanos: number): Duration {
    Preconditions.DebugCheckArgumentRange("smallNanos", smallNanos, -NanosecondsPerDay, NanosecondsPerDay);
    let newDays = this._days;
    let newNanos = this._nanoOfDay - smallNanos;
    if (newNanos >= NanosecondsPerDay) {
      newDays++;
      newNanos -= NanosecondsPerDay;
    } else if (newNanos < 0) {
      newDays--;
      newNanos += NanosecondsPerDay;
    }
    return Duration.NewDaysNanoOfDay(newDays, newNanos);
  }

  // #region Object overrides
  /**
   * Determines whether the specified value is equal to this instance.
   * See the type documentation for a description of equality semantics.
   * @param other The value to compare with this instance.
   * @returns `true` if the specified value is a duration equal to this instance; otherwise, `false`.
   *
   * noda-js: covers both `IEquatable<Duration>.Equals(Duration)` and `object.Equals(object)`.
   */
  Equals(other: Duration): boolean;
  /** @inheritDoc */
  Equals(other: unknown): boolean;
  Equals(other: unknown): boolean {
    return other instanceof Duration && this._days === other._days && this._nanoOfDay === other._nanoOfDay;
  }

  // Not ported: GetHashCode
  // #endregion

  // #region Formatting
  /**
   * Formats the value of the current instance using the specified pattern.
   *
   * noda-js: with no arguments, this uses the default format pattern ("o") and the invariant culture
   * (NodaTime uses the current thread's culture).
   * @param patternText The pattern to use, or null to use the default format pattern ("o").
   * @param formatProvider The format provider to use when formatting the value,
   * or null to use the invariant culture.
   * @returns The value of the current instance in the specified format.
   */
  toString(patternText: string | null = null, formatProvider: IFormatProvider | null = null): string {
    return DurationPattern.BclSupport.Format(this, patternText, formatProvider ?? NodaCultureInfo.InvariantCulture);
  }
  // #endregion Formatting

  // #region Operators
  /**
   * Adds one duration to another. Friendly alternative to `operator+()`.
   * @param left The left hand side of the operator.
   * @param right The right hand side of the operator.
   * @returns A new {@link Duration} representing the sum of the given values.
   */
  static Add(left: Duration, right: Duration): Duration {
    let newDays = left._days + right._days;
    let newNanos = left._nanoOfDay + right._nanoOfDay;
    if (newNanos >= NanosecondsPerDay) {
      newDays++;
      newNanos -= NanosecondsPerDay;
    }
    // nanoOfDay is always non-negative (and much less than half of long.MaxValue), so adding two
    // of them together will never produce a negative result.
    return Duration.NewDaysNanoOfDay(newDays, newNanos);
  }

  /**
   * Returns the result of adding another duration to this one, for a fluent alternative to `operator+()`.
   * @param other The duration to add
   * @returns A new {@link Duration} representing the result of the addition.
   */
  Plus(other: Duration): Duration {
    return Duration.Add(this, other);
  }

  /**
   * Subtracts one duration from another. Friendly alternative to `operator-()`.
   * @param left The left hand side of the operator.
   * @param right The right hand side of the operator.
   * @returns A new {@link Duration} representing the difference of the given values.
   */
  static Subtract(left: Duration, right: Duration): Duration {
    let newDays = left._days - right._days;
    let newNanos = left._nanoOfDay - right._nanoOfDay;
    if (newNanos < 0) {
      newDays--;
      newNanos += NanosecondsPerDay;
    }
    return Duration.NewDaysNanoOfDay(newDays, newNanos);
  }

  /**
   * Returns the result of subtracting another duration from this one, for a fluent alternative to `operator-()`.
   * @param other The duration to subtract
   * @returns A new {@link Duration} representing the result of the subtraction.
   */
  Minus(other: Duration): Duration {
    return Duration.Subtract(this, other);
  }

  /**
   * Divides a duration by an integer (C# `long`), a double, or another duration. Friendly alternative to `operator/()`.
   *
   * noda-js: NodaTime's Divide(Duration, long) and Divide(Duration, double) overloads are distinguished at runtime:
   * a safe integer `number` or a decimal string (exact over the whole C# `long` range) uses the integer overload
   * (whose result is truncated towards zero to a whole number of nanoseconds); any other `number` uses the double
   * overload.
   * @param left The left hand side of the operator.
   * @param right The right hand side of the operator.
   * @returns A new {@link Duration} representing the result of dividing `left` by `right`, or,
   * if `right` is a duration, the double result of dividing one duration by the other.
   * @throws {DivideByZeroError} `right` is zero.
   */
  static Divide(left: Duration, right: number | string): Duration;
  static Divide(left: Duration, right: Duration): number;
  static Divide(left: Duration, right: number | string | Duration): Duration | number {
    if (right instanceof Duration) {
      // operator /(Duration, Duration)
      const rightNanos = right.TotalNanoseconds;
      if (rightNanos === 0) {
        throw new DivideByZeroError("Attempt to divide by a zero duration.");
      }
      return left.TotalNanoseconds / rightNanos;
    }
    if (typeof right === "number" && !Number.isSafeInteger(right)) {
      // operator /(Duration, double)
      // Exclude infinity and NaN
      Preconditions.CheckArgumentRange("right", right, -Number.MAX_VALUE, Number.MAX_VALUE);
      if (right === 0) {
        throw new DivideByZeroError("Attempt to divide a duration by zero.");
      }
      return Duration.FromNanoseconds(left.TotalNanoseconds / right);
    }
    // operator /(Duration, long)
    const longRight = Int64.FromArgument(right, "right");
    const days = left._days;
    // Simplest scenario to handle
    if (days === 0 && Int64.Compare(longRight, 0) > 0) {
      return Duration.NewDaysNanoOfDay(0, Int64.ToNumber(Int64.Divide(left._nanoOfDay, longRight)));
    }
    if (longRight === 0) {
      throw new DivideByZeroError();
    }
    // Now for the ~[-250, +250] year range, where we can do it all as a long.
    if (days >= MinDaysForLongNanos && days <= MaxDaysForLongNanos) {
      const nanos = Int64.Divide(left.ToInt64NanosecondsExact(), longRight);
      return Duration.FromInt64Nanoseconds(nanos);
    }
    // Fall back to decimal arithmetic.
    const x = left.ToDecimalNanoseconds();
    return FromDecimalQuotient(x, WideInteger.FromInt64(longRight));
  }

  /**
   * Multiplies a duration by a number. Friendly alternative to `operator*()`.
   *
   * noda-js: NodaTime's long and double overloads are distinguished at runtime: a safe integer `number` or a decimal
   * string (exact over the whole C# `long` range) uses the (exact) integer overload; any other `number` uses the
   * double overload. Either argument may be the duration.
   * @param left The left hand side of the operator.
   * @param right The right hand side of the operator.
   * @returns A new {@link Duration} representing the product of the given values.
   */
  static Multiply(left: Duration, right: number | string): Duration;
  static Multiply(left: number | string, right: Duration): Duration;
  static Multiply(left: Duration | number | string, right: Duration | number | string): Duration {
    // operator *(long, Duration) and operator *(double, Duration) => right * left
    if (!(left instanceof Duration)) {
      return Duration.Multiply(right as Duration, left);
    }
    if (right instanceof Duration) {
      throw new TypeError("Cannot multiply a duration by a duration");
    }
    if (typeof right === "number" && !Number.isSafeInteger(right)) {
      // operator *(Duration, double)
      // Exclude infinity and NaN
      Preconditions.CheckArgumentRange("right", right, -Number.MAX_VALUE, Number.MAX_VALUE);
      return Duration.FromNanoseconds(left.TotalNanoseconds * right);
    }
    // operator *(Duration, long)
    const longRight = Int64.FromArgument(right, "right");
    // Optimize very simple cases that require no arithmetic.
    if (longRight === 0 || left.Equals(Duration.Zero)) {
      return Duration.Zero;
    }
    if (longRight === 1) {
      return left;
    }
    // noda-js: NodaTime uses long arithmetic for a "sweet spot" of small durations and multipliers, falling back to
    // decimal arithmetic. Both are exact for integers, so we compute the exact product: with numbers when it's a safe
    // integer, otherwise with WideInteger. Decimal multiplication throws OverflowException if the product doesn't
    // fit in a decimal.
    if (typeof longRight === "number") {
      const nanos = left.TotalNanoseconds;
      if (Number.isSafeInteger(nanos)) {
        const product = nanos * longRight;
        if (Number.isSafeInteger(product)) {
          return Duration.FromInt64Nanoseconds(product + 0);
        }
      }
    }
    const product = left.ToDecimalNanoseconds().Multiply(WideInteger.FromInt64(longRight));
    if (product.CompareMagnitudeTo(DecimalMax()) > 0) {
      throw new OverflowError("Value was either too large or too small for a Decimal.");
    }
    return Duration.FromDecimalNanoseconds(product);
  }

  /**
   * Implements a friendly alternative to the unary negation operator.
   * @param duration Duration to negate
   * @returns The negative value of this duration
   */
  static Negate(duration: Duration): Duration {
    const oldDays = duration._days;
    const oldNanoOfDay = duration._nanoOfDay;
    if (oldNanoOfDay === 0) {
      return Duration.NewDaysNanoOfDay(-oldDays, 0);
    }
    const newNanoOfDay = NanosecondsPerDay - oldNanoOfDay;
    return Duration.NewDaysNanoOfDay(-oldDays - 1, newNanoOfDay);
  }
  // #endregion // Operators

  // #region IComparable<Duration> Members
  /**
   * Implementation of IComparable<Duration>.CompareTo to compare two durations.
   * See the type documentation for a description of ordering semantics.
   *
   * noda-js: this also covers the non-generic IComparable.CompareTo: a null argument compares as less than this value.
   * @param other An object to compare with this object.
   * @returns A value less than zero if this duration is less than `other`; zero if they're equal;
   * a value greater than zero if this duration is greater than `other` (or `other` is null).
   * @throws {ArgumentError} `other` is non-null but is not a {@link Duration}.
   */
  CompareTo(other: Duration | null): number;
  /** @inheritDoc */
  CompareTo(other: unknown): number;
  CompareTo(other: unknown): number {
    if (other === null || other === undefined) {
      return 1;
    }
    Preconditions.CheckArgument(other instanceof Duration, "obj", "Object must be of type NodaTime.Duration.");
    const that = other as Duration;
    const dayComparison = CompareNumbers(this._days, that._days);
    return dayComparison !== 0 ? dayComparison : CompareNumbers(this._nanoOfDay, that._nanoOfDay);
  }
  // #endregion

  /**
   * Returns a {@link Duration} that represents the given number of days, assuming a 'standard' 24-hour
   * day.
   *
   * noda-js: an integer in the C# `int` range uses NodaTime's FromDays(int) overload; other values use FromDays(double).
   * @param days The number of days.
   * @returns A {@link Duration} representing the given number of days.
   */
  static FromDays(days: number): Duration {
    if (IsInt32(days)) {
      return Duration.NewDaysNanoOfDay(days, 0);
    }
    Preconditions.CheckArgumentRange("days", days, MinDays, MaxDays);
    return Duration.FromNanoseconds(days * NanosecondsPerDay);
  }

  /**
   * Returns a {@link Duration} that represents the given number of hours.
   *
   * noda-js: an integer in the C# `int` range uses NodaTime's FromHours(int) overload; other values use FromHours(double).
   * @param hours The number of hours.
   * @returns A {@link Duration} representing the given number of hours.
   */
  static FromHours(hours: number): Duration {
    if (IsInt32(hours)) {
      return Duration.NewUnitsParamNameMinValueMaxValueUnitsPerDayNanosPerUnit(
        hours, "hours", MinDays * HoursPerDay, ((MaxDays + 1) * HoursPerDay) - 1, HoursPerDay, NanosecondsPerHour);
    }
    Preconditions.CheckArgumentRange("hours", hours, MinDays * HoursPerDay, (MaxDays + 1) * HoursPerDay - 1);
    return Duration.FromNanoseconds(hours * NanosecondsPerHour);
  }

  /**
   * Returns a {@link Duration} that represents the given number of minutes.
   *
   * noda-js: a safe integer uses NodaTime's FromMinutes(long) overload; other values use FromMinutes(double).
   * @param minutes The number of minutes.
   * @returns A {@link Duration} representing the given number of minutes.
   */
  static FromMinutes(minutes: number): Duration {
    if (Number.isSafeInteger(minutes)) {
      return Duration.NewUnitsParamNameMinValueMaxValueUnitsPerDayNanosPerUnit(
        minutes, "minutes", MinDays * MinutesPerDay, ((MaxDays + 1) * MinutesPerDay) - 1, MinutesPerDay, NanosecondsPerMinute);
    }
    Preconditions.CheckArgumentRange("minutes", minutes, MinDays * MinutesPerDay, (MaxDays + 1) * MinutesPerDay - 1);
    return Duration.FromNanoseconds(minutes * NanosecondsPerMinute);
  }

  /**
   * Returns a {@link Duration} that represents the given number of seconds.
   *
   * noda-js: a safe integer uses NodaTime's FromSeconds(long) overload; other values use FromSeconds(double).
   * @param seconds The number of seconds.
   * @returns A {@link Duration} representing the given number of seconds.
   */
  static FromSeconds(seconds: number): Duration {
    if (Number.isSafeInteger(seconds)) {
      return Duration.NewUnitsParamNameMinValueMaxValueUnitsPerDayNanosPerUnit(
        seconds, "seconds", MinDays * SecondsPerDay, ((MaxDays + 1) * SecondsPerDay) - 1, SecondsPerDay, NanosecondsPerSecond);
    }
    Preconditions.CheckArgumentRange("seconds", seconds, MinDays * SecondsPerDay, (MaxDays + 1) * SecondsPerDay - 1);
    return Duration.FromNanoseconds(seconds * NanosecondsPerSecond);
  }

  /**
   * Returns a {@link Duration} that represents the given number of milliseconds.
   *
   * noda-js: a safe integer uses NodaTime's FromMilliseconds(long) overload; other values use FromMilliseconds(double).
   * @param milliseconds The number of milliseconds.
   * @returns A {@link Duration} representing the given number of milliseconds.
   */
  static FromMilliseconds(milliseconds: number): Duration {
    if (Number.isSafeInteger(milliseconds)) {
      return Duration.NewUnitsParamNameMinValueMaxValueUnitsPerDayNanosPerUnit(
        milliseconds, "milliseconds", MinDays * MillisecondsPerDay, ((MaxDays + 1) * MillisecondsPerDay) - 1,
        MillisecondsPerDay, NanosecondsPerMillisecond);
    }
    Preconditions.CheckArgumentRange("milliseconds", milliseconds, MinDays * MillisecondsPerDay, (MaxDays + 1) * MillisecondsPerDay - 1);
    return Duration.FromNanoseconds(milliseconds * NanosecondsPerMillisecond);
  }

  /**
   * Returns a {@link Duration} that represents the given number of ticks.
   *
   * noda-js: a safe integer or a decimal string (exact over the whole C# `long` range) uses NodaTime's
   * FromTicks(long) overload; other numbers use FromTicks(double).
   * @param ticks The number of ticks.
   * @returns A {@link Duration} representing the given number of ticks.
   */
  static FromTicks(ticks: number | string): Duration {
    if (typeof ticks === "number" && !Number.isSafeInteger(ticks)) {
      Preconditions.CheckArgumentRange("ticks", ticks, MinDays * TicksPerDay, (MaxDays + 1) * TicksPerDay - 1);
      return Duration.FromNanoseconds(ticks * NanosecondsPerTick);
    }
    return Duration.FromInt64Ticks(Int64.FromArgument(ticks, "ticks"));
  }

  /**
   * FromTicks(long), for an exact C# long.
   * @internal
   */
  static FromInt64Ticks(ticks: Int64Value): Duration {
    // No precondition here, as we cover a wider range than Int64 ticks can handle...
    const [days, tickOfDay] = TickArithmetic.TicksToDaysAndTickOfDay(ticks);
    return new Duration(days, tickOfDay * NanosecondsPerTick);
  }

  /**
   * Returns a {@link Duration} that represents the given number of nanoseconds.
   *
   * noda-js: this covers NodaTime's FromNanoseconds(long) and FromNanoseconds(double) overloads. A safe integer or a
   * decimal string (exact over the whole C# `long` range) uses FromNanoseconds(long); any other `number` uses
   * FromNanoseconds(double), which truncates any fractional part towards zero. (FromNanoseconds(BigInteger) and
   * FromNanoseconds(Int128) aren't ported.)
   * @param nanoseconds The number of nanoseconds.
   * @returns A {@link Duration} representing the given number of nanoseconds.
   * @throws {ArgumentOutOfRangeError} The value is outside the range of {@link Duration}.
   */
  static FromNanoseconds(nanoseconds: number | string): Duration {
    if (typeof nanoseconds === "string") {
      return Duration.FromInt64Nanoseconds(Int64.FromArgument(nanoseconds, "nanoseconds"));
    }
    if (Number.isSafeInteger(nanoseconds)) {
      return Duration.FromInt64Nanoseconds(nanoseconds + 0);
    }
    // FromNanoseconds(double)
    Preconditions.CheckArgumentRange("nanoseconds", nanoseconds, MinDoubleNanoseconds, MaxDoubleNanoseconds);
    // noda-js: NodaTime casts to long when nanoseconds is within [long.MinValue, long.MaxValue] as doubles; the cast
    // overflows (with overflow checking on) for 2^63, which is (double) long.MaxValue.
    if (nanoseconds === 2 ** 63) {
      throw new OverflowError();
    }
    const truncated = Math.trunc(nanoseconds);
    return truncated >= -(2 ** 63) && truncated < 2 ** 63
      ? Duration.FromInt64Nanoseconds(Int64.Compact(Long.fromNumber(truncated)))
      // FromNanoseconds((BigInteger) nanoseconds)
      : Duration.FromDecimalNanoseconds(WideInteger.FromNumber(truncated));
  }

  /**
   * FromNanoseconds(long), for an exact C# long.
   * @internal
   */
  static FromInt64Nanoseconds(nanoseconds: Int64Value): Duration {
    // Note: both branches call the private constructor overload that performs no validation,
    // as the value is always valid.
    // unchecked
    if (typeof nanoseconds === "number") {
      // noda-js: a safe integer: floor division with doubles, corrected in case the quotient was rounded.
      let days = Math.floor(nanoseconds / NanosecondsPerDay);
      let nanoOfDay = nanoseconds - days * NanosecondsPerDay;
      if (nanoOfDay < 0) {
        days--;
        nanoOfDay += NanosecondsPerDay;
      } else if (nanoOfDay >= NanosecondsPerDay) {
        days++;
        nanoOfDay -= NanosecondsPerDay;
      }
      return new Duration(days, nanoOfDay);
    }
    if (!nanoseconds.isNegative()) {
      const days = nanoseconds.div(NanosecondsPerDay);
      return new Duration(days.toInt(), nanoseconds.sub(days.mul(NanosecondsPerDay)).toNumber());
    } else {
      // Work out the "floor days"; division truncates towards zero and
      // nanoseconds is definitely negative by now, hence the addition and subtraction here.
      const days = nanoseconds.add(1).div(NanosecondsPerDay).toInt() - 1;
      const nanoOfDay = nanoseconds.gte(Long.MIN_VALUE.add(NanosecondsPerDay))
        ? nanoseconds.sub(Long.fromInt(days).mul(NanosecondsPerDay))
        : nanoseconds.sub(Long.fromInt(days + 1).mul(NanosecondsPerDay)).add(NanosecondsPerDay); // Avoid multiplication overflow
      return new Duration(days, nanoOfDay.toNumber());
    }
  }

  /**
   * Equivalent of NodaTime's internal FromNanoseconds(decimal) for integral values (and of FromNanoseconds(BigInteger)).
   * @internal
   */
  static FromDecimalNanoseconds(nanoseconds: WideInteger): Duration {
    if (nanoseconds.CompareTo(MinNanoseconds()) < 0 || nanoseconds.CompareTo(MaxNanoseconds()) > 0) {
      // Note: use the BigInteger value rather than decimal to avoid decimal points in the message. They're the same values.
      throw new ArgumentOutOfRangeError("nanoseconds", undefined, `Value should be in range [${MinNanosecondsText}-${MaxNanosecondsText}]`);
    }
    // Floor division by NanosecondsPerDay (NodaTime's two branches for non-negative and negative values).
    const [quotient, remainder] = nanoseconds.DivRem(NanosecondsPerDayWide());
    let days = quotient.ToNumber();
    let nanoOfDay = remainder.ToNumber();
    if (nanoOfDay < 0) {
      days--;
      nanoOfDay += NanosecondsPerDay;
    }
    return Duration.NewDaysNanoOfDayNoValidation(days, nanoOfDay, true);
  }

  // Not ported: FromTimeSpan, ToTimeSpan (BCL interop)

  // #region XML serialization
  // Not ported: AddSchema, IXmlSerializable members (XML serialization)
  // #endregion

  /**
   * Conversion to an Int64 number of nanoseconds. This will fail if the number of nanoseconds is
   * out of the range of `Int64`, which is approximately 292 years (positive or negative).
   *
   * noda-js: the value is computed exactly as a C# `long`, and returned as the nearest `number` (exact up to 2^53, or
   * about 104 days).
   * @throws {OverflowError} The number of nanoseconds is outside the representable range.
   * @returns This duration as a number of nanoseconds.
   */
  ToInt64Nanoseconds(): number {
    return Int64.ToNumber(this.ToInt64NanosecondsExact());
  }

  /**
   * NodaTime's ToInt64Nanoseconds, returning the exact C# long.
   * @throws {OverflowError} The number of nanoseconds is outside the representable range.
   * @internal
   */
  ToInt64NanosecondsExact(): Int64Value {
    // Fast path (common case)
    return this.IsInt64Representable ? this.ToInt64NanosecondsUnchecked()
      // Need to be careful to avoid overflow in a case where it's actually representable
      : this._days < 0 ? Int64.Subtract(Int64.Add(Int64.Multiply(this._days + 1, NanosecondsPerDay), this._nanoOfDay), NanosecondsPerDay)
      // Either the multiplication or the addition could overflow, so we do it in a checked context.
      : Int64.Add(Int64.Multiply(this._days, NanosecondsPerDay), this._nanoOfDay);
  }

  /**
   * A quick check to tell whether this duration is within the range of an Int64 value of nanoseconds
   * (roughly +/- 292 years). This is conservative as it only checks the days field -
   * there may be values just within Int64 range for which this property returns true, but they're
   * unlikely to come up... this property should *only* be used for optimization purposes.
   * @internal
   */
  get IsInt64Representable(): boolean {
    return this._days >= MinDaysForLongNanos && this._days <= MaxDaysForLongNanos;
  }

  /**
   * Performs an unchecked conversion from this duration to an Int64 value of nanoseconds.
   * This should only be called if IsInt64Representable returns true.
   */
  private ToInt64NanosecondsUnchecked(): Int64Value {
    // (noda-js: exact, as the result is trusted to be in the long range.)
    return Int64.Add(Int64.Multiply(this._days, NanosecondsPerDay), this._nanoOfDay);
  }

  // Not ported: ToBigIntegerNanoseconds, ToInt128Nanoseconds (no BigInt in ES2015; use toInt64Nanoseconds within the
  // long range, or totalNanoseconds)

  /**
   * NodaTime's ToDecimalNanoseconds: the exact number of nanoseconds.
   * @internal
   */
  ToDecimalNanoseconds(): WideInteger {
    return WideInteger.FromNumber(this._days).Multiply(NanosecondsPerDayWide()).Add(WideInteger.FromNumber(this._nanoOfDay));
  }

  /**
   * Returns the larger duration of the given two.
   *
   * A "larger" duration is one that advances time by more than a "smaller" one. This means
   * that a positive duration is always larger than a negative one, for example. (This is the same
   * comparison used by the binary comparison operators.)
   * @param x The first duration to compare.
   * @param y The second duration to compare.
   * @returns The larger duration of `x` or `y`.
   */
  static Max(x: Duration, y: Duration): Duration {
    return x.CompareTo(y) > 0 ? x : y;
  }

  /**
   * Returns the smaller duration of the given two.
   *
   * A "larger" duration is one that advances time by more than a "smaller" one. This means
   * that a positive duration is always larger than a negative one, for example. (This is the same
   * comparison used by the binary comparison operators.)
   * @param x The first duration to compare.
   * @param y The second duration to compare.
   * @returns The smaller duration of `x` or `y`.
   */
  static Min(x: Duration, y: Duration): Duration {
    return x.CompareTo(y) < 0 ? x : y;
  }

  // #region JSON (noda-js)
  /** Formats this value with {@link DurationPattern.JsonRoundtrip}, as NodaTime.Serialization.SystemTextJson does. */
  toJSON(): string {
    return DurationPattern.JsonRoundtrip.Format(this);
  }

  /**
   * Parses a value written by {@link toJSON}.
   * @throws {UnparsableValueError} The text could not be parsed.
   */
  static fromJSON(json: string): Duration {
    return DurationPattern.JsonRoundtrip.Parse(json).Value;
  }
  // #endregion

  /** Throws a TypeError: use {@link CompareTo} or {@link Equals} instead of relational operators. */
  valueOf(): never {
    return ThrowValueOf("Duration");
  }
}

/**
 * noda-js: equivalent of `FromNanoseconds(x / right)` with decimal arithmetic, as used by the division operator: the
 * quotient is rounded as decimal division rounds it (to the largest scale, at most 28, whose mantissa fits in 96 bits,
 * rounding half to even), range-checked, then floored (FromNanoseconds(decimal) floors fractional values).
 */
function FromDecimalQuotient(x: WideInteger, right: WideInteger): Duration {
  if (right.Negative) {
    x = x.Negate();
    right = right.Negate();
  }
  // Start from a scale no lower than the result: a quotient with d integer digits needs a mantissa of at least
  // d + scale digits, and the 96-bit limit has 29. The estimate of d may be one too high, hence 30 rather than 29.
  const approximateQuotient = Math.abs(x.ToNumber() / right.ToNumber());
  const estimatedDigits = approximateQuotient >= 1 ? Math.floor(Math.log(approximateQuotient) / Math.LN10) + 1 : 0;
  let scale = Math.min(28, 30 - estimatedDigits);
  let mantissa = WideInteger.Zero;
  for (; scale >= 0; scale--) {
    mantissa = RoundHalfEvenDiv(x.Multiply(WideInteger.PowerOfTen(scale)), right);
    if (mantissa.CompareMagnitudeTo(DecimalMax()) <= 0) {
      break;
    }
  }
  if (scale < 0) {
    throw new OverflowError("Value was either too large or too small for a Decimal.");
  }
  const divisor = WideInteger.PowerOfTen(scale);
  if (mantissa.CompareTo(MinNanoseconds().Multiply(divisor)) < 0 || mantissa.CompareTo(MaxNanoseconds().Multiply(divisor)) > 0) {
    throw new ArgumentOutOfRangeError("nanoseconds", undefined, `Value should be in range [${MinNanosecondsText}-${MaxNanosecondsText}]`);
  }
  // Floor division.
  let [quotient, remainder] = mantissa.DivRem(divisor);
  if (remainder.Negative) {
    quotient = quotient.Subtract(WideInteger.FromNumber(1));
  }
  return Duration.FromDecimalNanoseconds(quotient);
}

function IsInt32(value: number): boolean {
  return Number.isInteger(value) && value >= Int32.MinValue && value <= Int32.MaxValue;
}

function CompareNumbers(x: number, y: number): number {
  return x < y ? -1 : x > y ? 1 : 0;
}

/** Divides by a positive divisor, rounding half to even (as decimal division does). */
function RoundHalfEvenDiv(numerator: WideInteger, divisor: WideInteger): WideInteger {
  let [quotient, remainder] = numerator.DivRem(divisor);
  const twice = remainder.Abs().Multiply(WideInteger.FromNumber(2));
  const comparison = twice.CompareTo(divisor);
  if (comparison > 0 || (comparison === 0 && quotient.IsOdd)) {
    quotient = quotient.Add(WideInteger.FromNumber(numerator.Negative ? -1 : 1));
  }
  return quotient;
}
