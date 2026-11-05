// Ported from NodaTime 3.3.7: src/NodaTime/OffsetTime.cs
// Copyright 2017 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import {
  NodaCultureInfo,
  LocalDate,
  LocalTime,
  Offset,
  OffsetDateTime,
  OffsetTimePattern,
  Preconditions,
  ThrowValueOf,
} from "./internal.ts";
import type { IEquatable, IFormatProvider } from "./internal.ts";
import {
  MillisecondsPerSecond,
  MinutesPerHour,
  NanosecondsPerHour,
  NanosecondsPerMillisecond,
  NanosecondsPerMinute,
  NanosecondsPerSecond,
  NanosecondsPerTick,
  SecondsPerMinute,
  TicksPerSecond,
} from "./NodaConstants.generated.ts";

/**
 * A combination of a {@link LocalTime} and an {@link Offset}, to represent
 * a time-of-day at a specific offset from UTC but without any date information.
 *
 * Equality is defined in a component-wise fashion: two values are the same if they represent equal time-of-day values
 * and equal offsets from UTC. Ordering between offset time values is not defined.
 *
 * The default value of this type is midnight with a UTC offset of zero.
 *
 * This type is an immutable value type. See the thread safety section of the user guide for more information.
 */
export class OffsetTime implements IEquatable<OffsetTime> {
  // noda-js: NodaTime packs the nanosecond-of-day (bottom 47 bits) and the offset in seconds (top 17 bits) into a
  // single long field, nanosecondsAndOffset. We store the two values separately.
  private readonly _nanosecondOfDay: number;
  private readonly _offsetSeconds: number;

  /**
   * Constructs an instance of the specified time and offset.
   * @param time The time part of the value.
   * @param offset The offset part of the value.
   */
  constructor(time: LocalTime, offset: Offset) {
    this._nanosecondOfDay = time.NanosecondOfDay;
    this._offsetSeconds = offset.Seconds;
  }

  /**
   * Constructor only used in specialist cases where we know the offset will be 0.
   * @internal
   */
  static NewNanosecondOfDayZeroOffset(nanosecondOfDayZeroOffset: number): OffsetTime {
    Preconditions.DebugCheckArgument(nanosecondOfDayZeroOffset >= 0 && nanosecondOfDayZeroOffset < 2 ** 47, "nanosecondsAndOffset",
      "Constructor with zero offset called with non-zero offset");
    return OffsetTime.NewNanosecondOfDayOffsetSeconds(nanosecondOfDayZeroOffset, 0);
  }

  /** @internal */
  static NewNanosecondOfDayOffsetSeconds(nanosecondOfDay: number, offsetSeconds: number): OffsetTime {
    const result: { _nanosecondOfDay: number; _offsetSeconds: number } = Object.create(OffsetTime.prototype);
    result._nanosecondOfDay = nanosecondOfDay;
    result._offsetSeconds = offsetSeconds;
    return result as unknown as OffsetTime;
  }

  /** Gets the time-of-day represented by this value. */
  get TimeOfDay(): LocalTime {
    return LocalTime.NewNanoseconds(this.NanosecondOfDay);
  }

  /** Gets the offset from UTC of this value. */
  get Offset(): Offset {
    return Offset.NewSeconds(this._offsetSeconds);
  }

  /**
   * Returns the number of seconds in the offset, without going via an Offset.
   * @internal
   */
  get OffsetSeconds(): number {
    return this._offsetSeconds;
  }

  /**
   * Returns the number of nanoseconds in the offset, without going via an Offset.
   * @internal
   */
  get OffsetNanoseconds(): number {
    return this._offsetSeconds * NanosecondsPerSecond;
  }

  /** Gets the hour of day of this offset time, in the range 0 to 23 inclusive. */
  get Hour(): number {
    // noda-js: NodaTime computes this with a shift and division for efficiency; the result is the same.
    return Math.trunc(this.NanosecondOfDay / NanosecondsPerHour);
  }

  /** Gets the hour of the half-day of this offset time, in the range 1 to 12 inclusive. */
  get ClockHourOfHalfDay(): number {
    const hourOfHalfDay = this.Hour % 12;
    return hourOfHalfDay === 0 ? 12 : hourOfHalfDay;
  }

  /** Gets the minute of this offset time, in the range 0 to 59 inclusive. */
  get Minute(): number {
    // noda-js: NodaTime computes this with a shift and division for efficiency; the result is the same.
    const minuteOfDay = Math.trunc(this.NanosecondOfDay / NanosecondsPerMinute);
    return minuteOfDay % MinutesPerHour;
  }

  /** Gets the second of this offset time within the minute, in the range 0 to 59 inclusive. */
  get Second(): number {
    const secondOfDay = Math.trunc(this.NanosecondOfDay / NanosecondsPerSecond);
    return secondOfDay % SecondsPerMinute;
  }

  /** Gets the millisecond of this offset time within the second, in the range 0 to 999 inclusive. */
  get Millisecond(): number {
    const milliSecondOfDay = Math.trunc(this.NanosecondOfDay / NanosecondsPerMillisecond);
    return milliSecondOfDay % MillisecondsPerSecond;
  }

  /** Gets the tick of this offset time within the second, in the range 0 to 9,999,999 inclusive. */
  get TickOfSecond(): number {
    return this.TickOfDay % TicksPerSecond;
  }

  /**
   * Gets the tick of this offset time within the day, in the range 0 to 863,999,999,999 inclusive.
   *
   * If the value does not fall on a tick boundary, it will be truncated towards zero.
   */
  get TickOfDay(): number {
    return Math.trunc(this.NanosecondOfDay / NanosecondsPerTick);
  }

  /** Gets the nanosecond of this offset time within the second, in the range 0 to 999,999,999 inclusive. */
  get NanosecondOfSecond(): number {
    return this.NanosecondOfDay % NanosecondsPerSecond;
  }

  /** Gets the nanosecond of this offset time within the day, in the range 0 to 86,399,999,999,999 inclusive. */
  get NanosecondOfDay(): number {
    return this._nanosecondOfDay;
  }

  /**
   * Creates a new {@link OffsetTime} for the same time-of-day, but with the specified UTC offset.
   * @param offset The new UTC offset.
   * @returns A new `OffsetTime` for the same date, but with the specified UTC offset.
   */
  WithOffset(offset: Offset): OffsetTime {
    return new OffsetTime(this.TimeOfDay, offset); // TODO: Consider using bitmasking for nanos instead.
  }

  /**
   * Returns this offset time-of-day, with the given date adjuster applied to it, maintaining the existing offset.
   *
   * If the adjuster attempts to construct an invalid time-of-day, any exception thrown by
   * that construction attempt will be propagated through this method.
   * @param adjuster The adjuster to apply.
   * @returns The adjusted offset date.
   */
  With(adjuster: (time: LocalTime) => LocalTime): OffsetTime {
    return new OffsetTime(this.TimeOfDay.With(adjuster), this.Offset);
  }

  /**
   * Combines this {@link OffsetTime} with the given {@link LocalDate}
   * into an {@link OffsetDateTime}.
   * @param date The date to combine with this time-of-day.
   * @returns The {@link OffsetDateTime} representation of this time-of-day on the given date.
   */
  On(date: LocalDate): OffsetDateTime {
    return new OffsetDateTime(date.At(this.TimeOfDay), this.Offset);
  }

  // Not ported: GetHashCode

  /**
   * Compares two {@link OffsetTime} values for equality.
   * See the type documentation for a description of equality semantics.
   * @param other The value to compare this offset time with.
   * @returns True if the given value is another offset time equal to this one; false otherwise.
   *
   * noda-js: covers both `IEquatable<OffsetTime>.Equals(OffsetTime)` and `object.Equals(object)`.
   */
  Equals(other: OffsetTime): boolean;
  /** @inheritDoc */
  Equals(other: unknown): boolean;
  Equals(other: unknown): boolean {
    return other instanceof OffsetTime &&
      this._nanosecondOfDay === other._nanosecondOfDay && this._offsetSeconds === other._offsetSeconds;
  }

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
    return OffsetTimePattern.Patterns.BclSupport.Format(this, patternText, formatProvider ?? NodaCultureInfo.InvariantCulture);
  }

  // Not ported: Deconstruct

  // #region XML serialization
  // Not ported: AddSchema, IXmlSerializable members (XML serialization)
  // #endregion

  // #region JSON (noda-js)
  /** Formats this value with {@link OffsetTimePattern.ExtendedIso}, as NodaTime.Serialization.SystemTextJson does. */
  toJSON(): string {
    return OffsetTimePattern.ExtendedIso.Format(this);
  }

  /**
   * Parses a value written by {@link toJSON}.
   * @throws {UnparsableValueException} The text could not be parsed.
   */
  static fromJSON(json: string): OffsetTime {
    return OffsetTimePattern.ExtendedIso.Parse(json).Value;
  }
  // #endregion

  /** Throws a TypeError: use {@link Equals} instead of relational operators. */
  valueOf(): never {
    return ThrowValueOf("OffsetTime");
  }
}
