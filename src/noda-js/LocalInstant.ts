// Ported from NodaTime 3.3.0: src/NodaTime/LocalInstant.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import {
  Duration,
  Instant,
  InstantPatternParser,
  LocalDate,
  LocalDateTime,
  LocalDateTimePattern,
  LocalTime,
  Offset,
  OverflowError,
  Preconditions,
  ThrowValueOf,
  type IEquatable,
} from "./internal.ts";
import type { IComparable } from "./internal.ts";

let beforeMinValue: LocalInstant | undefined;
let afterMaxValue: LocalInstant | undefined;

/**
 * Represents a local date and time without reference to a calendar system. Essentially
 * this is a duration since a Unix epoch shifted by an offset (but we don't store what that
 * offset is). This class has been slimmed down considerably over time - it's used much less
 * than it used to be... almost solely for time zones.
 * @internal
 */
export class LocalInstant implements IEquatable<LocalInstant> {
  /** @internal */
  static get BeforeMinValue(): LocalInstant {
    return (beforeMinValue ??= LocalInstant.NewDaysDeliberatelyInvalid(Instant.BeforeMinValue.DaysSinceEpoch, true));
  }

  /** @internal */
  static get AfterMaxValue(): LocalInstant {
    return (afterMaxValue ??= LocalInstant.NewDaysDeliberatelyInvalid(Instant.AfterMaxValue.DaysSinceEpoch, true));
  }

  /** Elapsed time since the local 1970-01-01T00:00:00. */
  private readonly _duration: Duration;

  private constructor(duration: Duration) {
    this._duration = duration;
  }

  /** Constructor which should *only* be used to construct the invalid instances. */
  private static NewDaysDeliberatelyInvalid(days: number, _deliberatelyInvalid: boolean): LocalInstant {
    return new LocalInstant(Duration.NewDaysNanoOfDay(days, 0));
  }

  /**
   * Initializes a new instance of the {@link LocalInstant} struct.
   * @internal
   */
  static NewNanoseconds(nanoseconds: Duration): LocalInstant {
    const days = nanoseconds.FloorDays;
    if (days < Instant.MinDays || days > Instant.MaxDays) {
      throw new OverflowError("Operation would overflow bounds of local date/time");
    }
    return new LocalInstant(nanoseconds);
  }

  /**
   * Initializes a new instance of the {@link LocalInstant} struct.
   * @param days Number of days since 1970-01-01, in a time zone neutral fashion.
   * @param nanoOfDay Nanosecond of the local day.
   * @internal
   */
  static NewDaysNanoOfDay(days: number, nanoOfDay: number): LocalInstant {
    return new LocalInstant(Duration.NewDaysNanoOfDay(days, nanoOfDay));
  }

  /**
   * Returns whether or not this is a valid instant. Returns true for all but
   * {@link BeforeMinValue} and {@link AfterMaxValue}.
   */
  get IsValid(): boolean {
    return this.DaysSinceEpoch >= Instant.MinDays && this.DaysSinceEpoch <= Instant.MaxDays;
  }

  /** Number of nanoseconds since the local unix epoch. */
  get TimeSinceLocalEpoch(): Duration {
    return this._duration;
  }

  /** Number of days since the local unix epoch. */
  get DaysSinceEpoch(): number {
    return this._duration.FloorDays;
  }

  /** Nanosecond within the day. */
  get NanosecondOfDay(): number {
    return this._duration.NanosecondOfFloorDay;
  }

  // #region Operators
  /**
   * Returns a new instant based on this local instant, as if we'd applied a zero offset.
   * This is just a slight optimization over calling `localInstant.minus(Offset.zero)`.
   */
  MinusZeroOffset(): Instant {
    return Instant.FromTrustedDuration(this._duration);
  }

  /**
   * Subtracts the given time zone offset from this local instant, to give an {@link Instant}.
   *
   * This would normally be implemented as an operator, but as the corresponding "plus" operation
   * on Instant cannot be written (as Instant is a public type and LocalInstant is an internal type)
   * it makes sense to keep them both as methods for consistency.
   * @param offset The offset between UTC and a time zone for this local instant
   * @returns A new {@link Instant} representing the difference of the given values.
   */
  Minus(offset: Offset): Instant {
    return Instant.FromUntrustedDuration(this._duration.MinusSmallNanoseconds(offset.Nanoseconds));
  }

  /** Equivalent to {@link Instant.SafePlus}, but in the opposite direction. */
  SafeMinus(offset: Offset): Instant {
    const days = this._duration.FloorDays;
    // If we can do the arithmetic safely, do so.
    if (days > Instant.MinDays && days < Instant.MaxDays) {
      return this.Minus(offset);
    }
    // Handle BeforeMinValue and BeforeMaxValue simply.
    if (days < Instant.MinDays) {
      return Instant.BeforeMinValue;
    }
    if (days > Instant.MaxDays) {
      return Instant.AfterMaxValue;
    }
    // Okay, do the arithmetic as a Duration, then check the result for overflow, effectively.
    const asDuration = this._duration.MinusSmallNanoseconds(offset.Nanoseconds);
    if (asDuration.FloorDays < Instant.MinDays) {
      return Instant.BeforeMinValue;
    }
    if (asDuration.FloorDays > Instant.MaxDays) {
      return Instant.AfterMaxValue;
    }
    // And now we don't need any more checks.
    return Instant.FromTrustedDuration(asDuration);
  }

  /**
   * Replaces the comparison operators (`<`, `<=`, `>`, `>=`).
   * @returns A value less than zero if this local instant is earlier than `other`; zero if they're equal;
   * a value greater than zero if this local instant is later than `other`.
   *
   * noda-js: C#'s LocalInstant isn't IComparable (it only has the operators), so this isn't an
   * {@link IComparable} implementation; it still checks its argument, throwing ArgumentError for anything
   * that isn't a {@link LocalInstant} (including null).
   */
  CompareTo(other: LocalInstant): number {
    Preconditions.CheckArgument(other instanceof LocalInstant, "other", "Object must be of type NodaTime.LocalInstant.");
    return this._duration.CompareTo(other._duration);
  }
  // #endregion // Operators

  // #region Object overrides
  /**
   * Determines whether the specified value is equal to this instance.
   * @param other The value to compare with this instance.
   * @returns `true` if `other` is a local instant equal to this instance; otherwise, `false`.
   *
   * noda-js: covers both `IEquatable<LocalInstant>.Equals(LocalInstant)` and `object.Equals(object)`.
   */
  Equals(other: LocalInstant): boolean;
  /** @inheritDoc */
  Equals(other: unknown): boolean;
  Equals(other: unknown): boolean {
    return other instanceof LocalInstant && this._duration.Equals(other._duration);
  }

  // Not ported: GetHashCode

  /**
   * Returns a string that represents this instance.
   * @returns A string that represents this instance.
   */
  toString(): string {
    if (this.Equals(LocalInstant.BeforeMinValue)) {
      return InstantPatternParser.BeforeMinValueText;
    }
    if (this.Equals(LocalInstant.AfterMaxValue)) {
      return InstantPatternParser.AfterMaxValueText;
    }
    const date = LocalDate.NewDaysSinceEpoch(this._duration.FloorDays);
    const pattern = LocalDateTimePattern.CreateWithInvariantCulture("uuuu-MM-ddTHH:mm:ss.FFFFFFFFF 'LOC'");
    const utc = LocalDateTime.NewDateTime(date, LocalTime.FromNanosecondsSinceMidnight(this._duration.NanosecondOfFloorDay));
    return pattern.Format(utc);
  }
  // #endregion  // Object overrides

  /** Throws a TypeError: use {@link CompareTo} or {@link Equals} instead of relational operators. */
  valueOf(): never {
    return ThrowValueOf("LocalInstant");
  }
}
