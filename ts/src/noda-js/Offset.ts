// Ported from NodaTime 3.3.7: src/NodaTime/Offset.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { NodaCultureInfo, Int32, Int64, OffsetPattern, Preconditions, ThrowValueOf } from "./internal.ts";
import type { IComparable, IEquatable, IFormatProvider } from "./internal.ts";
import {
  MillisecondsPerHour,
  MillisecondsPerSecond,
  NanosecondsPerHour,
  NanosecondsPerSecond,
  SecondsPerHour,
  SecondsPerMinute,
  TicksPerHour,
  TicksPerSecond,
} from "./NodaConstants.generated.ts";
import type { ArgumentException, ArgumentOutOfRangeException } from "./internal.ts";

const MinHours = -18;
const MaxHours = 18;
const MinSeconds = -18 * SecondsPerHour;
const MaxSeconds = 18 * SecondsPerHour;
const MinMilliseconds = -18 * MillisecondsPerHour;
const MaxMilliseconds = 18 * MillisecondsPerHour;
const MinTicks = -18 * TicksPerHour;
const MaxTicks = 18 * TicksPerHour;
const MinNanoseconds = -18 * NanosecondsPerHour;
const MaxNanoseconds = 18 * NanosecondsPerHour;

let zero: Offset | undefined;
let minValue: Offset | undefined;
let maxValue: Offset | undefined;

/**
 * An offset from UTC in seconds. A positive value means that the local time is
 * ahead of UTC (e.g. for Europe); a negative value means that the local time is behind
 * UTC (e.g. for America).
 *
 * Offsets are always in the range of [-18, +18] hours. (Note that the ends are inclusive,
 * so an offset of 18 hours can be represented, but an offset of 18 hours and one second cannot.)
 * This allows all offsets within TZDB to be represented. The BCL DateTimeOffset type
 * only allows offsets up to 14 hours, which means some historical data within TZDB could not be
 * represented.
 *
 * Offsets are represented with a granularity of one second. This allows all offsets within TZDB
 * to be represented. It is possible that it could present issues to some other time zone data sources,
 * but only in very rare historical cases (or fictional ones).
 *
 * Equality and ordering are defined in the natural way by comparing the underlying number
 * of seconds. For example, this means that offsets for America are ordered before offsets in Europe.
 *
 * The default value of this type is {@link Offset.Zero}.
 *
 * This type is an immutable value type. See the thread safety section of the user guide for more information.
 */
export class Offset implements IEquatable<Offset>, IComparable<Offset> {
  // Note: these public fields are unfortunate; they really should be properties, like all other public constants.
  // Unfortunately that would now be a breaking change.

  /** An offset of zero seconds - effectively the permanent offset for UTC. */
  static get Zero(): Offset {
    return (zero ??= Offset.FromSeconds(0));
  }

  /** The minimum permitted offset; 18 hours before UTC. */
  static get MinValue(): Offset {
    return (minValue ??= Offset.FromHours(-18));
  }

  /** The maximum permitted offset; 18 hours after UTC. */
  static get MaxValue(): Offset {
    return (maxValue ??= Offset.FromHours(18));
  }

  /** Gets the additive identity. */
  static get AdditiveIdentity(): Offset {
    return Offset.Zero;
  }

  /** @internal */
  static readonly MinSeconds = MinSeconds;
  /** @internal */
  static readonly MaxSeconds = MaxSeconds;

  private readonly _seconds: number;

  private constructor(seconds: number) {
    Preconditions.DebugCheckArgumentRange("seconds", seconds, MinSeconds, MaxSeconds);
    this._seconds = seconds;
  }

  /**
   * Initializes a new instance of the {@link Offset} struct.
   * @param seconds The number of seconds in the offset.
   * @internal
   */
  static NewSeconds(seconds: number): Offset {
    return new Offset(seconds);
  }

  /** Gets the number of seconds represented by this offset, which may be negative. */
  get Seconds(): number {
    return this._seconds;
  }

  /**
   * Gets the number of milliseconds represented by this offset, which may be negative.
   *
   * Offsets are only accurate to second precision; the number of seconds is simply multiplied
   * by 1,000 to give the number of milliseconds.
   */
  get Milliseconds(): number {
    return this._seconds * MillisecondsPerSecond;
  }

  /**
   * Gets the number of ticks represented by this offset, which may be negative.
   *
   * Offsets are only accurate to second precision; the number of seconds is simply multiplied
   * by 10,000,000 to give the number of ticks.
   */
  get Ticks(): number {
    return this._seconds * TicksPerSecond;
  }

  /**
   * Gets the number of nanoseconds represented by this offset, which may be negative.
   *
   * Offsets are only accurate to second precision; the number of seconds is simply multiplied
   * by 1,000,000,000 to give the number of nanoseconds.
   */
  get Nanoseconds(): number {
    return this._seconds * NanosecondsPerSecond;
  }

  /**
   * Returns the greater offset of the given two, i.e. the one which will give a later local
   * time when added to an instant.
   * @param x The first offset
   * @param y The second offset
   * @returns The greater offset of `x` and `y`.
   */
  static Max(x: Offset, y: Offset): Offset {
    return x.CompareTo(y) > 0 ? x : y;
  }

  /**
   * Returns the lower offset of the given two, i.e. the one which will give an earlier local
   * time when added to an instant.
   * @param x The first offset
   * @param y The second offset
   * @returns The lower offset of `x` and `y`.
   */
  static Min(x: Offset, y: Offset): Offset {
    return x.CompareTo(y) < 0 ? x : y;
  }

  // #region Operators
  /**
   * Returns the negation of the specified offset. This is the method form of the unary minus operator.
   * @param offset The offset to negate.
   * @returns The negation of the specified offset.
   */
  static Negate(offset: Offset): Offset {
    // Guaranteed to still be in range.
    return new Offset(-offset.Seconds);
  }

  /**
   * Adds one Offset to another. Friendly alternative to `operator+()`.
   * @param left The left hand side of the operator.
   * @param right The right hand side of the operator.
   * @throws {ArgumentOutOfRangeException} The result of the operation is outside the range of Offset.
   * @returns A new {@link Offset} representing the sum of the given values.
   */
  static Add(left: Offset, right: Offset): Offset {
    return Offset.FromSeconds(left.Seconds + right.Seconds);
  }

  /**
   * Returns the result of adding another Offset to this one, for a fluent alternative to `operator+()`.
   * @param other The offset to add
   * @throws {ArgumentOutOfRangeException} The result of the operation is outside the range of Offset.
   * @returns The result of adding the other offset to this one.
   */
  Plus(other: Offset): Offset {
    return Offset.Add(this, other);
  }

  /**
   * Subtracts one Offset from another. Friendly alternative to `operator-()`.
   * @param minuend The left hand side of the operator.
   * @param subtrahend The right hand side of the operator.
   * @throws {ArgumentOutOfRangeException} The result of the operation is outside the range of Offset.
   * @returns A new {@link Offset} representing the difference of the given values.
   */
  static Subtract(minuend: Offset, subtrahend: Offset): Offset {
    return Offset.FromSeconds(minuend.Seconds - subtrahend.Seconds);
  }

  /**
   * Returns the result of subtracting another Offset from this one, for a fluent alternative to `operator-()`.
   * @param other The offset to subtract
   * @throws {ArgumentOutOfRangeException} The result of the operation is outside the range of Offset.
   * @returns The result of subtracting the other offset from this one.
   */
  Minus(other: Offset): Offset {
    return Offset.Subtract(this, other);
  }
  // #endregion // Operators

  // #region IComparable<Offset> Members
  /**
   * Compares the current object with another object of the same type.
   * See the type documentation for a description of ordering semantics.
   * @param other An object to compare with this object.
   * @returns A value less than zero if this offset is less than `other`; zero if they're equal;
   * a value greater than zero if this offset is greater than `other` (or `other` is null).
   * @throws {ArgumentException} `other` is non-null but is not an {@link Offset}.
   */
  CompareTo(other: Offset | null): number;
  /** @inheritDoc */
  CompareTo(other: unknown): number;
  CompareTo(other: unknown): number {
    if (other === null || other === undefined) {
      return 1;
    }
    Preconditions.CheckArgument(other instanceof Offset, "obj", "Object must be of type NodaTime.Offset.");
    const that = other as Offset;
    return this._seconds < that._seconds ? -1 : this._seconds > that._seconds ? 1 : 0;
  }
  // #endregion

  // #region IEquatable<Offset> Members
  /**
   * Indicates whether the current object is equal to another object of the same type.
   * See the type documentation for a description of equality semantics.
   * @param other An object to compare with this object.
   * @returns true if `other` is an offset equal to this one; otherwise, false.
   */
  Equals(other: Offset): boolean;
  /** @inheritDoc */
  Equals(other: unknown): boolean;
  Equals(other: unknown): boolean {
    return other instanceof Offset && this._seconds === other._seconds;
  }
  // #endregion

  // Not ported: GetHashCode

  // #region Formatting
  /**
   * Formats the value of the current instance using the specified pattern.
   *
   * noda-js: the default culture is the invariant culture (NodaTime uses the current culture).
   * @param patternText The pattern to use, or null to use the default format pattern ("g").
   * @param formatProvider The format provider to use when formatting the value,
   * or null to use the invariant culture.
   * @returns The value of the current instance in the specified format.
   */
  toString(patternText: string | null = null, formatProvider: IFormatProvider | null = null): string {
    return OffsetPattern.BclSupport.Format(this, patternText, formatProvider ?? NodaCultureInfo.InvariantCulture);
  }
  // #endregion Formatting

  // #region Construction
  /**
   * Returns an offset for the given seconds value, which may be negative.
   * @param seconds The int seconds value.
   * @returns An offset representing the given number of seconds.
   * @throws {ArgumentOutOfRangeException} The specified number of seconds is outside the range of
   * [-18, +18] hours.
   */
  static FromSeconds(seconds: number): Offset {
    Preconditions.CheckArgumentRange("seconds", seconds, MinSeconds, MaxSeconds);
    return new Offset(seconds);
  }

  /**
   * Returns an offset for the given milliseconds value, which may be negative.
   *
   * Offsets are only accurate to second precision; the given number of milliseconds is simply divided
   * by 1,000 to give the number of seconds - any remainder is truncated.
   * @param milliseconds The int milliseconds value.
   * @returns An offset representing the given number of milliseconds, to the (truncated) second.
   * @throws {ArgumentOutOfRangeException} The specified number of milliseconds is outside the range of
   * [-18, +18] hours.
   */
  static FromMilliseconds(milliseconds: number): Offset {
    Preconditions.CheckArgumentRange("milliseconds", milliseconds, MinMilliseconds, MaxMilliseconds);
    return new Offset(Math.trunc(milliseconds / MillisecondsPerSecond));
  }

  /**
   * Returns an offset for the given number of ticks, which may be negative.
   *
   * Offsets are only accurate to second precision; the given number of ticks is simply divided
   * by 10,000,000 to give the number of seconds - any remainder is truncated.
   * @param ticks The number of ticks specifying the length of the new offset.
   * @returns An offset representing the given number of ticks, to the (truncated) second.
   * @throws {ArgumentOutOfRangeException} The specified number of ticks is outside the range of
   * [-18, +18] hours.
   */
  static FromTicks(ticks: number | string): Offset {
    const longTicks = Int64.FromArgument(ticks, "ticks");
    Preconditions.CheckArgumentRange("ticks", longTicks, MinTicks, MaxTicks);
    return new Offset(Math.trunc((longTicks as number) / TicksPerSecond));
  }

  /**
   * Returns an offset for the given number of nanoseconds, which may be negative.
   *
   * Offsets are only accurate to second precision; the given number of nanoseconds is simply divided
   * by 1,000,000,000 to give the number of seconds - any remainder is truncated towards zero.
   * @param nanoseconds The number of nanoseconds specifying the length of the new offset.
   * @returns An offset representing the given number of nanoseconds, to the (truncated) second.
   * @throws {ArgumentOutOfRangeException} The specified number of nanoseconds is outside the range of
   * [-18, +18] hours.
   */
  static FromNanoseconds(nanoseconds: number | string): Offset {
    const longNanoseconds = Int64.FromArgument(nanoseconds, "nanoseconds");
    Preconditions.CheckArgumentRange("nanoseconds", longNanoseconds, MinNanoseconds, MaxNanoseconds);
    return new Offset(Math.trunc((longNanoseconds as number) / NanosecondsPerSecond));
  }

  /**
   * Returns an offset for the specified number of hours, which may be negative.
   * @param hours The number of hours to represent in the new offset.
   * @returns An offset representing the given value.
   * @throws {ArgumentOutOfRangeException} The specified number of hours is outside the range of
   * [-18, +18].
   */
  static FromHours(hours: number): Offset {
    Preconditions.CheckArgumentRange("hours", hours, MinHours, MaxHours);
    return new Offset(hours * SecondsPerHour);
  }

  /**
   * Returns an offset for the specified number of hours and minutes.
   *
   * The result simply takes the hours and minutes and converts each component into milliseconds
   * separately. As a result, a negative offset should usually be obtained by making both arguments
   * negative. For example, to obtain "three hours and ten minutes behind UTC" you might call
   * `Offset.FromHoursAndMinutes(-3, -10)`.
   * @param hours The number of hours to represent in the new offset.
   * @param minutes The number of minutes to represent in the new offset.
   * @returns An offset representing the given value.
   * @throws {ArgumentOutOfRangeException} The result of the operation is outside the range of Offset.
   */
  static FromHoursAndMinutes(hours: number, minutes: number): Offset {
    // (int arithmetic with overflow checking, as in NodaTime.)
    return Offset.FromSeconds(Int32.Checked(Int32.Checked(hours * SecondsPerHour) + Int32.Checked(minutes * SecondsPerMinute)));
  }
  // #endregion

  // #region Conversion
  // Not ported: ToTimeSpan, FromTimeSpan (BCL interop)
  // #endregion

  // #region XML serialization
  // Not ported: AddSchema, IXmlSerializable members (XML serialization)
  // #endregion

  // #region JSON (noda-js)
  /** Formats this value with {@link OffsetPattern.GeneralInvariant}, as NodaTime.Serialization.SystemTextJson does. */
  toJSON(): string {
    return OffsetPattern.GeneralInvariant.Format(this);
  }

  /**
   * Parses a value written by {@link toJSON}.
   * @throws {UnparsableValueException} The text could not be parsed.
   */
  static fromJSON(json: string): Offset {
    return OffsetPattern.GeneralInvariant.Parse(json).Value;
  }
  // #endregion

  /** Throws a TypeError: use {@link CompareTo} or {@link Equals} instead of relational operators. */
  valueOf(): never {
    return ThrowValueOf("Offset");
  }
}
