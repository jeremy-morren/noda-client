// Ported from NodaTime 3.3.7: src/NodaTime/Fields/TimePeriodField.cs
// Copyright 2014 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import {
  Duration,
  Int32,
  Int64,
  WideInteger,
  LocalDateTime,
  LocalTime,
  NanosecondsPerDay,
  NanosecondsPerHour,
  NanosecondsPerMillisecond,
  NanosecondsPerMinute,
  NanosecondsPerSecond,
  NanosecondsPerTick,
} from "../internal.ts";
import type { Int64Value } from "../internal.ts";
import type { Period } from "../internal.ts";
import { NewOverflowException, type OverflowException } from "../internal.ts";

let nanoseconds: TimePeriodField | undefined;
let ticks: TimePeriodField | undefined;
let milliseconds: TimePeriodField | undefined;
let seconds: TimePeriodField | undefined;
let minutes: TimePeriodField | undefined;
let hours: TimePeriodField | undefined;

/**
 * Period field class representing a field with a fixed duration regardless of when it occurs.
 *
 * 2014-06-29: Tried optimizing time period calculations by making these static methods accepting
 * the number of ticks. I'd expected that to be really significant, given that it would avoid
 * finding the object etc. It turned out to make about 10% difference, at the cost of quite a bit
 * of code elegance.
 *
 * noda-js: `long` unit counts are exact Int64Values, as in {@link Period}; NodaTime's decimal arithmetic uses WideInteger.
 * @internal
 */
export class TimePeriodField {
  static get Nanoseconds(): TimePeriodField {
    return (nanoseconds ??= new TimePeriodField(1));
  }
  static get Ticks(): TimePeriodField {
    return (ticks ??= new TimePeriodField(NanosecondsPerTick));
  }
  static get Milliseconds(): TimePeriodField {
    return (milliseconds ??= new TimePeriodField(NanosecondsPerMillisecond));
  }
  static get Seconds(): TimePeriodField {
    return (seconds ??= new TimePeriodField(NanosecondsPerSecond));
  }
  static get Minutes(): TimePeriodField {
    return (minutes ??= new TimePeriodField(NanosecondsPerMinute));
  }
  static get Hours(): TimePeriodField {
    return (hours ??= new TimePeriodField(NanosecondsPerHour));
  }

  private readonly _unitNanoseconds: number;
  // The largest number of units (positive or negative) we can multiply unitNanoseconds by without overflowing a long.
  private readonly _maxLongUnits: Int64Value;
  private readonly _unitsPerDay: number;

  private constructor(unitNanoseconds: number) {
    this._unitNanoseconds = unitNanoseconds;
    this._maxLongUnits = Int64.Divide(Int64.MaxValue, unitNanoseconds);
    this._unitsPerDay = NanosecondsPerDay / unitNanoseconds;
  }

  /**
   * C# has three overloads, told apart here at runtime:
   * - `Add(LocalDateTime start, long units)`
   * - `Add(LocalTime localTime, long value)`
   * - `Add(LocalTime localTime, long value, ref int extraDays)`: `extraDays` is a mutable holder.
   */
  Add(start: LocalDateTime, units: Int64Value): LocalDateTime;
  Add(localTime: LocalTime, value: Int64Value): LocalTime;
  Add(localTime: LocalTime, value: Int64Value, extraDays: { value: number }): LocalTime;
  Add(start: LocalDateTime | LocalTime, value: Int64Value, extraDays?: { value: number }): LocalDateTime | LocalTime {
    if (start instanceof LocalDateTime) {
      return this.AddToLocalDateTime(start, value);
    }
    return extraDays === undefined
      ? this.AddToLocalTime(start, value)
      : this.AddToLocalTimeWithExtraDays(start, value, extraDays);
  }

  // C#: Add(LocalDateTime start, long units)
  private AddToLocalDateTime(start: LocalDateTime, units: Int64Value): LocalDateTime {
    const extraDays = { value: 0 };
    const time = this.AddToLocalTimeWithExtraDays(start.TimeOfDay, units, extraDays);
    // Even though PlusDays optimizes for "value == 0", it's still quicker not to call it.
    const date = extraDays.value === 0 ? start.Date : start.Date.PlusDays(extraDays.value);
    return date.At(time);
  }

  // C#: Add(LocalTime localTime, long value)
  private AddToLocalTime(localTime: LocalTime, longValue: Int64Value): LocalTime {
    // unchecked
    // noda-js: a Long value (beyond 2^53) is first reduced exactly to less than a day.
    let value = typeof longValue === "number" ? longValue : Int64.ToNumber(Int64.Remainder(longValue, this._unitsPerDay));
    // Arithmetic with a LocalTime wraps round, and every unit divides exactly
    // into a day, so we can make sure we add a value which is less than a day.
    if (value >= 0) {
      if (value >= this._unitsPerDay) {
        value = value % this._unitsPerDay;
      }
      const nanosToAdd = value * this._unitNanoseconds;
      let newNanos = localTime.NanosecondOfDay + nanosToAdd;
      if (newNanos >= NanosecondsPerDay) {
        newNanos -= NanosecondsPerDay;
      }
      return LocalTime.NewNanoseconds(newNanos);
    } else {
      if (value <= -this._unitsPerDay) {
        value = value % this._unitsPerDay;
      }
      const nanosToAdd = value * this._unitNanoseconds;
      let newNanos = localTime.NanosecondOfDay + nanosToAdd;
      if (newNanos < 0) {
        newNanos += NanosecondsPerDay;
      }
      return LocalTime.NewNanoseconds(newNanos);
    }
  }

  // C#: Add(LocalTime localTime, long value, ref int extraDays)
  private AddToLocalTimeWithExtraDays(localTime: LocalTime, longValue: Int64Value, extraDays: { value: number }): LocalTime {
    // unchecked
    if (longValue === 0) {
      return localTime;
    }
    let days = 0;
    // noda-js: a Long value (beyond 2^53) is first split exactly into whole days and the rest.
    let value: number;
    if (typeof longValue !== "number") {
      // If this overflows, that's fine. (An OverflowException is a reasonable outcome.)
      days = Int32.Checked(Int64.ToNumber(Int64.Divide(longValue, this._unitsPerDay)));
      value = Int64.ToNumber(Int64.Remainder(longValue, this._unitsPerDay));
    } else {
      value = longValue;
    }
    // It's possible that there are better ways to do this, but this at least feels simple.
    if (value >= 0) {
      if (value >= this._unitsPerDay) {
        const longDays = Math.trunc(value / this._unitsPerDay);
        // If this overflows, that's fine. (An OverflowException is a reasonable outcome.)
        days = Int32.Checked(longDays);
        value = value % this._unitsPerDay;
      }
      const nanosToAdd = value * this._unitNanoseconds;
      let newNanos = localTime.NanosecondOfDay + nanosToAdd;
      if (newNanos >= NanosecondsPerDay) {
        newNanos -= NanosecondsPerDay;
        days = Int32.Checked(days + 1);
      }
      extraDays.value = Int32.Checked(extraDays.value + days);
      return LocalTime.NewNanoseconds(newNanos);
    } else {
      if (value <= -this._unitsPerDay) {
        const longDays = Math.trunc(value / this._unitsPerDay);
        // If this overflows, that's fine. (An OverflowException is a reasonable outcome.)
        days = Int32.Checked(longDays);
        value = value % this._unitsPerDay;
      }
      const nanosToAdd = value * this._unitNanoseconds;
      let newNanos = localTime.NanosecondOfDay + nanosToAdd;
      if (newNanos < 0) {
        newNanos += NanosecondsPerDay;
        days = Int32.Checked(days - 1);
      }
      extraDays.value = Int32.Checked(days + extraDays.value);
      return LocalTime.NewNanoseconds(newNanos);
    }
  }

  UnitsBetween(start: LocalDateTime, end: LocalDateTime): Int64Value {
    const startLocalInstant = start.ToLocalInstant();
    const endLocalInstant = end.ToLocalInstant();
    const duration = Duration.Subtract(endLocalInstant.TimeSinceLocalEpoch, startLocalInstant.TimeSinceLocalEpoch);
    return this.GetUnitsInDuration(duration);
  }

  /**
   * Returns the number of units in the given duration, rounding towards zero.
   */
  GetUnitsInDuration(duration: Duration): Int64Value {
    return duration.IsInt64Representable
      ? Int64.Divide(duration.ToInt64NanosecondsExact(), this._unitNanoseconds)
      // C#: (long) (duration.ToDecimalNanoseconds() / unitNanoseconds): the decimal quotient never rounds up to
      // the next integer, so this is the truncated quotient; the conversion to long throws on overflow.
      : duration.ToDecimalNanoseconds().DivRem(WideInteger.FromNumber(this._unitNanoseconds))[0].ToInt64();
  }

  /**
   * Returns a {@link Duration} representing the given number of units.
   */
  ToDuration(units: Int64Value): Duration {
    if (Int64.Compare(units, Int64.Negate(this._maxLongUnits)) >= 0 && Int64.Compare(units, this._maxLongUnits) <= 0) {
      return Duration.FromInt64Nanoseconds(Int64.Multiply(units, this._unitNanoseconds));
    }
    // C#: Duration.FromNanoseconds(units * (decimal) unitNanoseconds); decimal multiplication throws OverflowException
    // if the product doesn't fit in a decimal (96 bits).
    const product = WideInteger.FromInt64(units).Multiply(WideInteger.FromNumber(this._unitNanoseconds));
    if (product.CompareMagnitudeTo(WideInteger.FromNumber(2 ** 96)) >= 0) {
      throw NewOverflowException("Value was either too large or too small for a Decimal.");
    }
    return Duration.FromDecimalNanoseconds(product);
  }
}
