// Ported from NodaTime 3.3.7: src/NodaTime/Instant.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import {
  CalendarSystem,
  NodaCultureInfo,
  DateTimeZone,
  Duration,
  InstantPattern,
  Int64,
  Long,
  LocalDate,
  LocalInstant,
  LocalTime,
  NodaConstants,
  Offset,
  OffsetDateTime,
  OffsetTime,
  Preconditions,
  TickArithmetic,
  ZonedDateTime,
  ThrowValueOf,
} from "./internal.ts";
import type { IComparable, IEquatable, IFormatProvider, Int64Value } from "./internal.ts";
import {
  MillisecondsPerDay,
  NanosecondsPerDay,
  NanosecondsPerMillisecond,
  NanosecondsPerSecond,
  NanosecondsPerTick,
  SecondsPerDay,
  TicksPerDay,
} from "./NodaConstants.generated.ts";
import { NewOverflowException, type ArgumentException, type ArgumentOutOfRangeException } from "./internal.ts";

// These correspond to -9998-01-01 and 9999-12-31 respectively.
const MinDays = -4371222;
const MaxDays = 2932896;

// noda-js: MinTicks and MaxTicks are beyond 2^53, so they are exact Longs (created on first use).
let minTicks: Long | undefined;
let maxTicks: Long | undefined;
const MinMilliseconds = MinDays * MillisecondsPerDay;
const MaxMilliseconds = (MaxDays + 1) * MillisecondsPerDay - 1;
const MinSeconds = MinDays * SecondsPerDay;
const MaxSeconds = (MaxDays + 1) * SecondsPerDay - 1;

let minValue: Instant | undefined;
let maxValue: Instant | undefined;
let beforeMinValue: Instant | undefined;
let afterMaxValue: Instant | undefined;

/**
 * Represents an instant on the global timeline, with nanosecond resolution.
 *
 * An {@link Instant} has no concept of a particular time zone or calendar: it simply represents a point in
 * time that can be globally agreed-upon.
 *
 * Equality and ordering comparisons are defined in the natural way, with earlier points on the timeline
 * being considered "less than" later points.
 *
 * The default value of this type is {@link NodaConstants.UnixEpoch}, i.e. the instant
 * which can be represented as 1970-01-01T00:00:00Z in the ISO calendar.
 *
 * This type is an immutable value type. See the thread safety section of the user guide for more information.
 */
export class Instant implements IEquatable<Instant>, IComparable<Instant> {
  /** @internal */
  static readonly MinDays = MinDays;
  /** @internal */
  static readonly MaxDays = MaxDays;

  /**
   * Represents the smallest possible {@link Instant}.
   *
   * This value is equivalent to -9998-01-01T00:00:00Z
   */
  static get MinValue(): Instant {
    return (minValue ??= Instant.NewDaysNanoOfDay(MinDays, 0));
  }

  /**
   * Represents the largest possible {@link Instant}.
   *
   * This value is equivalent to 9999-12-31T23:59:59.999999999Z
   */
  static get MaxValue(): Instant {
    return (maxValue ??= Instant.NewDaysNanoOfDay(MaxDays, NanosecondsPerDay - 1));
  }

  /**
   * Instant which is invalid *except* for comparison purposes; it is earlier than any valid value.
   * This must never be exposed.
   * @internal
   */
  static get BeforeMinValue(): Instant {
    return (beforeMinValue ??= Instant.NewDaysDeliberatelyInvalid(Duration.MinDays, true));
  }

  /**
   * Instant which is invalid *except* for comparison purposes; it is later than any valid value.
   * This must never be exposed.
   * @internal
   */
  static get AfterMaxValue(): Instant {
    return (afterMaxValue ??= Instant.NewDaysDeliberatelyInvalid(Duration.MaxDays, true));
  }

  /** Time elapsed since the Unix epoch. */
  private readonly _duration: Duration;

  /**
   * Constructor which constructs a new instance with the given duration, which
   * is trusted to be valid. Should only be called from FromTrustedDuration and
   * FromUntrustedDuration.
   */
  private constructor(duration: Duration) {
    this._duration = duration;
  }

  /** Constructor which should *only* be used to construct the invalid instances. */
  private static NewDaysDeliberatelyInvalid(days: number, _deliberatelyInvalid: boolean): Instant {
    return new Instant(Duration.NewDaysNanoOfDay(days, 0));
  }

  /** @internal */
  static NewDaysNanoOfDay(days: number, nanoOfDay: number): Instant {
    Preconditions.DebugCheckArgumentRange("days", days, MinDays, MaxDays);
    Preconditions.DebugCheckArgumentRange("nanoOfDay", nanoOfDay, 0, NanosecondsPerDay - 1);
    return new Instant(Duration.NewDaysNanoOfDay(days, nanoOfDay));
  }

  /**
   * Creates an Instant with the given duration, with no validation (in release mode).
   * @internal
   */
  static FromTrustedDuration(duration: Duration): Instant {
    Preconditions.DebugCheckArgumentRange("duration", duration.FloorDays, MinDays, MaxDays);
    return new Instant(duration);
  }

  /**
   * Creates an Instant with the given duration, validating that it has a suitable
   * "day" part. (It is assumed that the nanoOfDay is okay.)
   * @internal
   */
  static FromUntrustedDuration(duration: Duration): Instant {
    const days = duration.FloorDays;
    if (days < MinDays || days > MaxDays) {
      throw NewOverflowException("Operation would overflow range of Instant");
    }
    return new Instant(duration);
  }

  /**
   * Returns whether or not this is a valid instant. Returns true for all but
   * {@link BeforeMinValue} and {@link AfterMaxValue}.
   * @internal
   */
  get IsValid(): boolean {
    return this.DaysSinceEpoch >= MinDays && this.DaysSinceEpoch <= MaxDays;
  }

  /**
   * Get the elapsed time since the Unix epoch, to nanosecond resolution.
   * @internal
   */
  get TimeSinceEpoch(): Duration {
    return this._duration;
  }

  /**
   * Number of days since the local unix epoch.
   * @internal
   */
  get DaysSinceEpoch(): number {
    return this._duration.FloorDays;
  }

  /**
   * Nanosecond within the day.
   * @internal
   */
  get NanosecondOfDay(): number {
    return this._duration.NanosecondOfFloorDay;
  }

  // #region IComparable<Instant> and IComparable Members
  /**
   * Compares the current object with another object of the same type.
   * See the type documentation for a description of ordering semantics.
   *
   * noda-js: this also covers the non-generic IComparable.CompareTo: a null argument compares as less than this value.
   * @param other An object to compare with this object.
   * @returns A value less than zero if this instant is earlier than `other`; zero if they're equal;
   * a value greater than zero if this instant is later than `other` (or `other` is null).
   * @throws {ArgumentException} `other` is non-null but is not an {@link Instant}.
   */
  CompareTo(other: Instant | null): number;
  /** @inheritDoc */
  CompareTo(other: unknown): number;
  CompareTo(other: unknown): number {
    if (other === null || other === undefined) {
      return 1;
    }
    Preconditions.CheckArgument(other instanceof Instant, "obj", "Object must be of type NodaTime.Instant.");
    return this._duration.CompareTo((other as Instant)._duration);
  }
  // #endregion

  // #region Object overrides
  /**
   * Determines whether the specified value is equal to this instance.
   * See the type documentation for a description of equality semantics.
   * @param other The value to compare with this instance.
   * @returns `true` if `other` is an instant equal to this instance; otherwise, `false`.
   *
   * noda-js: covers both `IEquatable<Instant>.Equals(Instant)` and `object.Equals(object)`.
   */
  Equals(other: Instant): boolean;
  /** @inheritDoc */
  Equals(other: unknown): boolean;
  Equals(other: unknown): boolean {
    return other instanceof Instant && this._duration.Equals(other._duration);
  }

  // Not ported: GetHashCode
  // #endregion  // Object overrides

  /**
   * Returns a new value of this instant with the given number of ticks added to it.
   * @param ticks The ticks to add to this instant to create the return value.
   * @returns The result of adding the given number of ticks to this instant.
   */
  PlusTicks(ticks: number | string): Instant {
    return Instant.FromUntrustedDuration(this._duration.Plus(Duration.FromInt64Ticks(Int64.FromArgument(ticks, "ticks"))));
  }

  /**
   * Returns a new value of this instant with the given number of nanoseconds added to it.
   * @param nanoseconds The nanoseconds to add to this instant to create the return value.
   * @returns The result of adding the given number of ticks to this instant.
   */
  PlusNanoseconds(nanoseconds: number | string): Instant {
    return Instant.FromUntrustedDuration(this._duration.Plus(Duration.FromInt64Nanoseconds(Int64.FromArgument(nanoseconds, "nanoseconds"))));
  }

  // #region Operators
  /**
   * Adds the given offset to this instant, either returning a normal LocalInstant,
   * or {@link LocalInstant.BeforeMinValue} or {@link LocalInstant.AfterMaxValue}
   * if the value would overflow.
   * @internal
   */
  SafePlus(offset: Offset): LocalInstant {
    const days = this._duration.FloorDays;
    // If we can do the arithmetic safely, do so.
    if (days > MinDays && days < MaxDays) {
      return this.Plus(offset);
    }
    // Handle BeforeMinValue and BeforeMaxValue simply.
    if (days < MinDays) {
      return LocalInstant.BeforeMinValue;
    }
    if (days > MaxDays) {
      return LocalInstant.AfterMaxValue;
    }
    // Okay, do the arithmetic as a Duration, then check the result for overflow, effectively.
    const asDuration = this._duration.PlusSmallNanoseconds(offset.Nanoseconds);
    if (asDuration.FloorDays < MinDays) {
      return LocalInstant.BeforeMinValue;
    }
    if (asDuration.FloorDays > MaxDays) {
      return LocalInstant.AfterMaxValue;
    }
    return LocalInstant.NewNanoseconds(asDuration);
  }

  /**
   * Adds a duration to an instant. Friendly alternative to `operator+()`.
   * @param left The left hand side of the operator.
   * @param right The right hand side of the operator.
   * @returns A new {@link Instant} representing the sum of the given values.
   */
  static Add(left: Instant, right: Duration): Instant {
    return Instant.FromUntrustedDuration(left._duration.Plus(right));
  }

  /**
   * Returns the result of adding a duration to this instant, for a fluent alternative to `operator+()`.
   * @param duration The duration to add
   * @returns A new {@link Instant} representing the result of the addition.
   */
  Plus(duration: Duration): Instant;
  /**
   * Adds the given offset to this instant, to return a {@link LocalInstant}.
   * A positive offset indicates that the local instant represents a "later local time" than the UTC
   * representation of this instant.
   *
   * This was previously an operator+ implementation, but operators can't be internal.
   * @param offset The right hand side of the operator.
   * @returns A new {@link LocalInstant} representing the sum of the given values.
   * @internal
   */
  Plus(offset: Offset): LocalInstant;
  Plus(durationOrOffset: Duration | Offset): Instant | LocalInstant {
    if (durationOrOffset instanceof Offset) {
      return LocalInstant.NewNanoseconds(this._duration.PlusSmallNanoseconds(durationOrOffset.Nanoseconds));
    }
    return Instant.Add(this, durationOrOffset);
  }

  /**
   * Subtracts one instant from another, or a duration from an instant. Friendly alternative to `operator-()`.
   * @param left The left hand side of the operator.
   * @param right The right hand side of the operator.
   * @returns A new {@link Duration} representing the difference of the given instants, or a new {@link Instant}
   * representing the difference of the instant and the duration.
   */
  static Subtract(left: Instant, right: Instant): Duration;
  static Subtract(left: Instant, right: Duration): Instant;
  static Subtract(left: Instant, right: Instant | Duration): Duration | Instant {
    if (right instanceof Instant) {
      return left._duration.Minus(right._duration);
    }
    return Instant.FromUntrustedDuration(left._duration.Minus(right));
  }

  /**
   * Returns the result of subtracting another instant from this one, for a fluent alternative to `operator-()`.
   * @param other The other instant to subtract
   * @returns A new {@link Duration} representing the result of the subtraction.
   */
  Minus(other: Instant): Duration;
  /**
   * Returns the result of subtracting a duration from this instant, for a fluent alternative to `operator-()`.
   * @param duration The duration to subtract
   * @returns A new {@link Instant} representing the result of the subtraction.
   */
  Minus(duration: Duration): Instant;
  Minus(other: Instant | Duration): Duration | Instant {
    return other instanceof Instant ? Instant.Subtract(this, other) : Instant.Subtract(this, other);
  }
  // #endregion // Operators

  // #region Convenience methods
  /**
   * Returns a new instant corresponding to the given UTC date and time in the ISO calendar.
   * In most cases applications should use {@link ZonedDateTime} to represent a date
   * and time, but this method is useful in some situations where an {@link Instant} is
   * required, such as time zone testing.
   * @param year The year. This is the "absolute year",
   * so a value of 0 means 1 BC, for example.
   * @param monthOfYear The month of year.
   * @param dayOfMonth The day of month.
   * @param hourOfDay The hour.
   * @param minuteOfHour The minute.
   * @param secondOfMinute The second. (Optional.)
   * @returns An {@link Instant} value representing the given date and time in UTC and the ISO calendar.
   */
  static FromUtc(year: number, monthOfYear: number, dayOfMonth: number, hourOfDay: number, minuteOfHour: number, secondOfMinute?: number): Instant {
    const days = new LocalDate(year, monthOfYear, dayOfMonth).DaysSinceEpoch;
    const nanoOfDay = (secondOfMinute === undefined
      ? new LocalTime(hourOfDay, minuteOfHour)
      : new LocalTime(hourOfDay, minuteOfHour, secondOfMinute)).NanosecondOfDay;
    return Instant.NewDaysNanoOfDay(days, nanoOfDay);
  }

  /**
   * Returns the later instant of the given two.
   * @param x The first instant to compare.
   * @param y The second instant to compare.
   * @returns The later instant of `x` or `y`.
   */
  static Max(x: Instant, y: Instant): Instant {
    return x.CompareTo(y) > 0 ? x : y;
  }

  /**
   * Returns the earlier instant of the given two.
   * @param x The first instant to compare.
   * @param y The second instant to compare.
   * @returns The earlier instant of `x` or `y`.
   */
  static Min(x: Instant, y: Instant): Instant {
    return x.CompareTo(y) < 0 ? x : y;
  }
  // #endregion

  // #region Formatting
  /**
   * Formats the value of the current instance using the specified pattern.
   *
   * noda-js: with no arguments, this uses the default format pattern ("g") and the invariant culture
   * (NodaTime uses the current thread's culture).
   * @param patternText The pattern to use, or null to use the default format pattern ("g").
   * @param formatProvider The format provider to use when formatting the value,
   * or null to use the invariant culture.
   * @returns The value of the current instance in the specified format.
   */
  toString(patternText: string | null = null, formatProvider: IFormatProvider | null = null): string {
    return InstantPattern.BclSupport.Format(this, patternText, formatProvider ?? NodaCultureInfo.InvariantCulture);
  }
  // #endregion Formatting

  /**
   * Returns the Julian Date of this instance - the number of days since
   * {@link NodaConstants.JulianEpoch} (noon on January 1st, 4713 BCE in the Julian calendar).
   * @returns The number of days (including fractional days) since the Julian Epoch.
   */
  ToJulianDate(): number {
    return this.Minus(NodaConstants.JulianEpoch).TotalDays;
  }

  // Not ported: ToDateTimeUtc, ToDateTimeOffset, FromDateTimeOffset (BCL interop; see ToJsDate / FromJsDate)

  /**
   * Converts a Julian Date representing the given number of days
   * since {@link NodaConstants.JulianEpoch} (noon on January 1st, 4713 BCE in the Julian calendar)
   * into an {@link Instant}.
   * @param julianDate The number of days since the Julian Epoch to convert into an {@link Instant}.
   * @returns An {@link Instant} value which is `julianDate` days after the Julian Epoch.
   */
  static FromJulianDate(julianDate: number): Instant {
    return Instant.Add(NodaConstants.JulianEpoch, Duration.FromDays(julianDate));
  }

  // Not ported: FromDateTimeUtc (BCL interop; see FromJsDate)

  /**
   * Converts a JavaScript `Date` into a new Instant representing the same instant in time.
   *
   * noda-js: replaces NodaTime's DateTime / DateTimeOffset conversions.
   * @param date The date to convert. It must represent a valid time (not `Invalid Date`).
   * @returns An {@link Instant} value representing the same instant in time as the given `Date`.
   * @throws {ArgumentException} `date` is an invalid date.
   * @throws {ArgumentOutOfRangeException} `date` is outside the range of {@link Instant}.
   */
  static FromJsDate(date: Date): Instant {
    Preconditions.CheckNotNull(date, "date");
    const milliseconds = date.getTime();
    Preconditions.CheckArgument(!Number.isNaN(milliseconds), "date", "Invalid Date");
    return Instant.FromUnixTimeMilliseconds(milliseconds);
  }

  /**
   * Constructs a JavaScript `Date` representing the same instant in time as this value.
   *
   * noda-js: replaces NodaTime's DateTime / DateTimeOffset conversions.
   * If the instant is not on a millisecond boundary (the unit of granularity of `Date`) the value will be truncated
   * towards the start of time. Every {@link Instant} is within the range of `Date`.
   * @returns A `Date` representing the same instant in time as this value.
   */
  ToJsDate(): Date {
    return new Date(this.ToUnixTimeMilliseconds());
  }

  /**
   * Initializes a new instance of the {@link Instant} struct based
   * on a number of seconds since the Unix epoch of (ISO) January 1st 1970, midnight, UTC.
   * @param seconds Number of seconds since the Unix epoch. May be negative (for instants before the epoch).
   * @returns An {@link Instant} at exactly the given number of seconds since the Unix epoch.
   * @throws {ArgumentOutOfRangeException} The constructed instant would be out of the range representable in Noda Time.
   */
  static FromUnixTimeSeconds(seconds: number): Instant {
    Preconditions.CheckArgumentRange("seconds", seconds, MinSeconds, MaxSeconds);
    return Instant.FromTrustedDuration(Duration.FromSeconds(seconds));
  }

  /**
   * Initializes a new instance of the {@link Instant} struct based
   * on a number of milliseconds since the Unix epoch of (ISO) January 1st 1970, midnight, UTC.
   * @param milliseconds Number of milliseconds since the Unix epoch. May be negative (for instants before the epoch).
   * @returns An {@link Instant} at exactly the given number of milliseconds since the Unix epoch.
   * @throws {ArgumentOutOfRangeException} The constructed instant would be out of the range representable in Noda Time.
   */
  static FromUnixTimeMilliseconds(milliseconds: number): Instant {
    Preconditions.CheckArgumentRange("milliseconds", milliseconds, MinMilliseconds, MaxMilliseconds);
    return Instant.FromTrustedDuration(Duration.FromMilliseconds(milliseconds));
  }

  /**
   * Initializes a new instance of the {@link Instant} struct based
   * on a number of ticks since the Unix epoch of (ISO) January 1st 1970, midnight, UTC.
   * @param ticks Number of ticks since the Unix epoch. May be negative (for instants before the epoch).
   * @returns An {@link Instant} at exactly the given number of ticks since the Unix epoch.
   */
  static FromUnixTimeTicks(ticks: number | string): Instant;
  /**
   * noda-js: internal callers (the NZD reader) may also pass an exact Long.
   * @internal
   */
  static FromUnixTimeTicks(ticks: number | string | Long): Instant;
  static FromUnixTimeTicks(ticks: number | string | Long): Instant {
    const longTicks: Int64Value = Int64.FromArgument(ticks, "ticks");
    Preconditions.CheckArgumentRange("ticks", longTicks,
      (minTicks ??= Long.fromNumber(MinDays * TicksPerDay)),
      (maxTicks ??= Long.fromNumber((MaxDays + 1) * TicksPerDay).sub(1)));
    return Instant.FromTrustedDuration(Duration.FromInt64Ticks(longTicks));
  }

  /**
   * Gets the number of seconds since the Unix epoch. Negative values represent instants before the Unix epoch.
   *
   * If the number of nanoseconds in this instant is not an exact number of seconds, the value is truncated towards the start of time.
   * @returns The number of seconds since the Unix epoch.
   */
  ToUnixTimeSeconds(): number {
    return this._duration.FloorDays * SecondsPerDay + Math.trunc(this._duration.NanosecondOfFloorDay / NanosecondsPerSecond);
  }

  /**
   * Gets the number of seconds since the Unix epoch, along with remaining nanoseconds.
   * Negative values for seconds represent instants before the Unix epoch.
   *
   * If the number of nanoseconds in this instant is not an exact number of seconds
   * the seconds part of the returned value is truncated towards the start of time, ensuring that
   * the nanoseconds part is always non-negative. The seconds part of the returned value is always
   * the same as would be returned by {@link ToUnixTimeSeconds}.
   *
   * The inverse of this operation is to first call {@link Instant.FromUnixTimeSeconds} and then
   * call {@link PlusNanoseconds} on the returned {@link Instant}.
   *
   * noda-js: NodaTime returns a `(long seconds, int nanoseconds)` tuple; this returns an object with the same names.
   * @returns The number of seconds and remaining nanoseconds since the Unix epoch.
   */
  ToUnixTimeSecondsAndNanoseconds(): { seconds: number; nanoseconds: number } {
    const nanosecondOfDay = this._duration.NanosecondOfFloorDay;
    const secondOfDay = Math.trunc(nanosecondOfDay / NanosecondsPerSecond);
    const nanosecondOfSecond = nanosecondOfDay % NanosecondsPerSecond;
    return { seconds: (SecondsPerDay * this._duration.FloorDays) + secondOfDay, nanoseconds: nanosecondOfSecond };
  }

  /**
   * Gets the number of milliseconds since the Unix epoch. Negative values represent instants before the Unix epoch.
   *
   * If the number of nanoseconds in this instant is not an exact number of milliseconds, the value is truncated towards the start of time.
   * @returns The number of milliseconds since the Unix epoch.
   */
  ToUnixTimeMilliseconds(): number {
    return this._duration.FloorDays * MillisecondsPerDay + Math.trunc(this._duration.NanosecondOfFloorDay / NanosecondsPerMillisecond);
  }

  /**
   * Gets the number of ticks since the Unix epoch. Negative values represent instants before the Unix epoch.
   *
   * A tick is equal to 100 nanoseconds. There are 10,000 ticks in a millisecond. If the number of nanoseconds
   * in this instant is not an exact number of ticks, the value is truncated towards the start of time.
   *
   * noda-js: the value is computed exactly as a C# `long`, and returned as the nearest `number` (ticks since the
   * epoch exceed 2^53 for instants more than about 28 years from it).
   * @returns The number of ticks since the Unix epoch.
   */
  ToUnixTimeTicks(): number {
    return Int64.ToNumber(this.ToUnixTimeTicksExact());
  }

  /**
   * noda-js: {@link Instant.ToUnixTimeTicks} as an exact C# `long` (for writing NZD data).
   * @internal
   */
  ToUnixTimeTicksExact(): Int64Value {
    return TickArithmetic.BoundedDaysAndTickOfDayToTicks(
      this._duration.FloorDays, Math.trunc(this._duration.NanosecondOfFloorDay / NanosecondsPerTick));
  }

  /**
   * Returns the {@link ZonedDateTime} representing the same point in time as this instant, in the UTC time
   * zone and ISO-8601 calendar. This is a shortcut for calling {@link InZone} with an
   * argument of {@link DateTimeZone.Utc}.
   * @returns A {@link ZonedDateTime} for the same instant, in the UTC time zone
   * and the ISO-8601 calendar
   */
  InUtc(): ZonedDateTime {
    // Bypass any determination of offset and arithmetic, as we know the offset is zero.
    const offsetDateTime = OffsetDateTime.NewLocalDateOffsetTime(
      LocalDate.NewDaysSinceEpoch(this._duration.FloorDays),
      OffsetTime.NewNanosecondOfDayZeroOffset(this._duration.NanosecondOfFloorDay));
    return ZonedDateTime.NewOffsetDateTimeZone(offsetDateTime, DateTimeZone.Utc);
  }

  /**
   * Returns the {@link ZonedDateTime} representing the same point in time as this instant, in the
   * specified time zone and calendar system (ISO-8601 by default).
   * @param zone The time zone in which to represent this instant.
   * @param calendar The calendar system in which to represent this instant.
   * @returns A {@link ZonedDateTime} for the same instant, in the given time zone
   * and calendar
   */
  InZone(zone: DateTimeZone, calendar?: CalendarSystem): ZonedDateTime {
    if (calendar === undefined) {
      // zone is checked for nullity by the constructor.
      return new ZonedDateTime(this, zone);
    }
    Preconditions.CheckNotNull(zone, "zone");
    Preconditions.CheckNotNull(calendar, "calendar");
    return new ZonedDateTime(this, zone, calendar);
  }

  /**
   * Returns the {@link OffsetDateTime} representing the same point in time as this instant, with
   * the specified UTC offset and calendar system (the ISO calendar system by default).
   * @param offset The offset from UTC with which to represent this instant.
   * @param calendar The calendar system in which to represent this instant.
   * @returns An {@link OffsetDateTime} for the same instant, with the given offset
   * and calendar
   */
  WithOffset(offset: Offset, calendar?: CalendarSystem): OffsetDateTime {
    if (calendar === undefined) {
      return OffsetDateTime.NewInstantOffset(this, offset);
    }
    Preconditions.CheckNotNull(calendar, "calendar");
    return OffsetDateTime.NewInstantOffsetCalendar(this, offset, calendar);
  }

  // #region XML serialization
  // Not ported: AddSchema, IXmlSerializable members (XML serialization)
  // #endregion

  // #region JSON (noda-js)
  /** Formats this value with {@link InstantPattern.ExtendedIso}, as NodaTime.Serialization.SystemTextJson does. */
  toJSON(): string {
    return InstantPattern.ExtendedIso.Format(this);
  }

  /**
   * Parses a value written by {@link toJSON}.
   * @throws {UnparsableValueException} The text could not be parsed.
   */
  static fromJSON(json: string): Instant {
    return InstantPattern.ExtendedIso.Parse(json).Value;
  }
  // #endregion

  /** Throws a TypeError: use {@link CompareTo} or {@link Equals} instead of relational operators. */
  valueOf(): never {
    return ThrowValueOf("Instant");
  }
}
