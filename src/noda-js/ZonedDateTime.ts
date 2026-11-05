// Ported from NodaTime 3.3.7: src/NodaTime/ZonedDateTime.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import {
  NodaCultureInfo,
  Duration,
  Instant,
  LocalDateTime,
  Offset,
  OffsetDateTime,
  Preconditions,
  ZonedDateTimePattern,
  ThrowValueOf,
} from "./internal.ts";
import type {
  CalendarSystem, DateTimeZone, Era, IDateTimeZoneProvider, IEquatable, IFormatProvider, IsoDayOfWeek, LocalDate, LocalTime, ZoneInterval,
} from "./internal.ts";
import { NewArgumentException, type ArgumentException } from "./internal.ts";

// Do not nest type X.
// The rule is somewhat subjective, but more importantly these have been available
// publicly for a while, so we can't change them now anyway.

/** The pattern NodaTime.Serialization.SystemTextJson uses for ZonedDateTime values. */
const JsonPatternText = "uuuu'-'MM'-'dd'T'HH':'mm':'ss;FFFFFFFFFo<G> z";
let jsonFormatPattern: ZonedDateTimePattern | undefined;

// #region Comparers
/**
 * Base class for {@link ZonedDateTime} comparers.
 *
 * Use the static properties of this class to obtain instances. This type is exposed so that the
 * same value can be used for both equality and ordering comparisons.
 */
export abstract class ZonedDateTimeComparer {
  // TODO(feature): A comparer which compares instants, but in a calendar-sensitive manner?

  /**
   * Gets a comparer which compares {@link ZonedDateTime} values by their local date/time, without reference to
   * the time zone or offset. Comparisons between two values of different calendar systems will fail with {@link ArgumentException}.
   *
   * For example, this comparer considers 2013-03-04T20:21:00 (Europe/London) to be later than
   * 2013-03-04T19:21:00 (America/Los_Angeles) even though the second value represents a later instant in time.
   *
   * This property will return a reference to the same instance every time it is called.
   */
  static get Local(): ZonedDateTimeComparer {
    return ZonedDateTimeLocalComparer.Instance;
  }

  /**
   * Gets a comparer which compares {@link ZonedDateTime} values by the instants obtained by applying the offset to
   * the local date/time, ignoring the calendar system.
   *
   * For example, this comparer considers 2013-03-04T20:21:00 (Europe/London) to be earlier than
   * 2013-03-04T19:21:00 (America/Los_Angeles) even though the second value has a local time which is earlier; the time zones
   * mean that the first value occurred earlier in the universal time line.
   *
   * This property will return a reference to the same instance every time it is called.
   */
  static get Instant(): ZonedDateTimeComparer {
    return ZonedDateTimeInstantComparer.Instance;
  }

  /**
   * Internal constructor to prevent external classes from deriving from this.
   * (That means we can add more abstract members in the future.)
   * @internal
   */
  protected constructor() {
  }

  /**
   * Compares two {@link ZonedDateTime} values and returns a value indicating whether one is less than, equal to, or greater than the other.
   *
   * @param x The first value to compare.
   * @param y The second value to compare.
   * @returns A signed integer that indicates the relative values of `x` and `y`: less than zero if `x` is less
   * than `y`; zero if `x` equals `y`; greater than zero if `x` is greater than `y`.
   */
  abstract Compare(x: ZonedDateTime, y: ZonedDateTime): number;

  /**
   * Determines whether the specified `ZonedDateTime` values are equal.
   *
   * @param x The first `ZonedDateTime` to compare.
   * @param y The second `ZonedDateTime` to compare.
   * @returns `true` if the specified objects are equal; otherwise, `false`.
   */
  abstract Equals(x: ZonedDateTime, y: ZonedDateTime): boolean;

  // Not ported: GetHashCode(ZonedDateTime) (hash codes are omitted; see docs/porting-conventions.md)
}

let localComparer: ZonedDateTimeComparer | undefined;
let instantComparer: ZonedDateTimeComparer | undefined;

// noda-js: C# can't pass anything but a ZonedDateTime (it's a struct); check it here, so that a null or
// foreign value throws ArgumentException instead of a TypeError from deep inside the comparison.
function CheckComparerArguments(x: unknown, y: unknown): void {
  Preconditions.CheckArgument(x instanceof ZonedDateTime, "x", "Object must be of type NodaTime.ZonedDateTime.");
  Preconditions.CheckArgument(y instanceof ZonedDateTime, "y", "Object must be of type NodaTime.ZonedDateTime.");
}

/**
 * Implementation for {@link ZonedDateTimeComparer.Local}.
 */
class ZonedDateTimeLocalComparer extends ZonedDateTimeComparer {
  static get Instance(): ZonedDateTimeComparer {
    return (localComparer ??= new ZonedDateTimeLocalComparer());
  }

  private constructor() {
    super();
  }

  /** @inheritdoc */
  override Compare(x: ZonedDateTime, y: ZonedDateTime): number {
    CheckComparerArguments(x, y);
    return OffsetDateTime.Comparer.Local.Compare(x._offsetDateTime, y._offsetDateTime);
  }

  /** @inheritdoc */
  override Equals(x: ZonedDateTime, y: ZonedDateTime): boolean {
    if (!(x instanceof ZonedDateTime) || !(y instanceof ZonedDateTime)) {
      return false;
    }
    return OffsetDateTime.Comparer.Local.Equals(x._offsetDateTime, y._offsetDateTime);
  }
}

/**
 * Implementation for {@link ZonedDateTimeComparer.Instant}.
 */
class ZonedDateTimeInstantComparer extends ZonedDateTimeComparer {
  static get Instance(): ZonedDateTimeComparer {
    return (instantComparer ??= new ZonedDateTimeInstantComparer());
  }

  private constructor() {
    super();
  }

  /** @inheritdoc */
  override Compare(x: ZonedDateTime, y: ZonedDateTime): number {
    CheckComparerArguments(x, y);
    return OffsetDateTime.Comparer.Instant.Compare(x._offsetDateTime, y._offsetDateTime);
  }

  /** @inheritdoc */
  override Equals(x: ZonedDateTime, y: ZonedDateTime): boolean {
    if (!(x instanceof ZonedDateTime) || !(y instanceof ZonedDateTime)) {
      return false;
    }
    return OffsetDateTime.Comparer.Instant.Equals(x._offsetDateTime, y._offsetDateTime);
  }
}
// #endregion

// Note: documentation that refers to the LocalDateTime type within this class must use the fully-qualified
// reference to avoid being resolved to the LocalDateTime property instead.

/**
 * A {@link LocalDateTime} in a specific time zone and with a particular offset to distinguish
 * between otherwise-ambiguous instants. A {@link ZonedDateTime} is global, in that it maps to a single
 * {@link Instant}.
 *
 * Although {@link ZonedDateTime} includes both local and global concepts, it only supports
 * duration-based - and not calendar-based - arithmetic. This avoids ambiguities
 * and skipped date/time values becoming a problem within a series of calculations; instead,
 * these can be considered just once, at the point of conversion to a {@link ZonedDateTime}.
 *
 * `ZonedDateTime` does not implement ordered comparison operators, as there is no obvious natural ordering that works in all cases.
 * Equality is supported however, requiring equality of zone, calendar and date/time. If you want to sort `ZonedDateTime`
 * values, you should explicitly choose one of the orderings provided via the static properties in the
 * {@link ZonedDateTime.Comparer} nested class (or implement your own comparison).
 *
 * The default value of this type is 0001-01-01T00:00:00Z (midnight on January 1st, 1 C.E.) in the ISO calendar and the UTC time zone.
 *
 * This type is an immutable value type. See the thread safety section of the user guide for more information.
 */
export class ZonedDateTime implements IEquatable<ZonedDateTime> {
  /**
   * Base class for {@link ZonedDateTime} comparers. See {@link ZonedDateTimeComparer}.
   */
  static readonly Comparer = ZonedDateTimeComparer;

  // noda-js: private in NodaTime; readable here because the comparers (separate classes in TypeScript) use it.
  /** @internal */
  readonly _offsetDateTime: OffsetDateTime;

  // noda-js: NodaTime stores a nullable zone field (null only for default(ZonedDateTime)) behind the Zone
  // property, which substitutes DateTimeZone.Utc. Every noda-js value has a zone, so the property just returns the
  // field (named _zone, as a getter can't share the field's name).
  private readonly _zone: DateTimeZone;

  /**
   * Gets the time zone associated with this value.
   */
  get Zone(): DateTimeZone {
    return this._zone;
  }

  /**
   * Internal constructor from pre-validated values.
   * @internal
   */
  static NewOffsetDateTimeZone(offsetDateTime: OffsetDateTime, zone: DateTimeZone): ZonedDateTime {
    const value = Object.create(ZonedDateTime.prototype) as { _offsetDateTime: OffsetDateTime; _zone: DateTimeZone };
    value._offsetDateTime = offsetDateTime;
    value._zone = zone;
    return value as unknown as ZonedDateTime;
  }

  /**
   * Initializes a new instance of the {@link ZonedDateTime} struct.
   *
   * @param instant The instant.
   * @param zone The time zone.
   * @param calendar The calendar system. If omitted, the ISO calendar is used.
   */
  constructor(instant: Instant, zone: DateTimeZone, calendar?: CalendarSystem);
  /**
   * Initializes a new instance of the {@link ZonedDateTime} struct in the specified time zone
   * from a given local time and offset. The offset is validated to be correct as part of initialization.
   * In most cases a local time can only map to a single instant anyway, but the offset is included here for cases
   * where the local time is ambiguous, usually due to daylight saving transitions.
   *
   * @param localDateTime The local date and time.
   * @param zone The time zone.
   * @param offset The offset between UTC and local time at the desired instant.
   * @throws {ArgumentException} `offset` is not a valid offset at the given
   * local date and time.
   */
  constructor(localDateTime: LocalDateTime, zone: DateTimeZone, offset: Offset);
  constructor(instantOrLocalDateTime: Instant | LocalDateTime, zone: DateTimeZone, calendarOrOffset?: CalendarSystem | Offset) {
    if (instantOrLocalDateTime instanceof LocalDateTime) {
      const localDateTime = instantOrLocalDateTime;
      const offset = calendarOrOffset as Offset;
      this._zone = Preconditions.CheckNotNull(zone, "zone");
      const candidateInstant: Instant = localDateTime.ToLocalInstant().Minus(offset);
      const correctOffset: Offset = zone.GetUtcOffset(candidateInstant);
      // Not using Preconditions, to avoid building the string unnecessarily.
      if (!correctOffset.Equals(offset)) {
        throw NewArgumentException(`Offset ${offset} is invalid for local date and time ${localDateTime} in time zone ${zone.Id}`, "offset");
      }
      this._offsetDateTime = new OffsetDateTime(localDateTime, offset);
      return;
    }
    const instant = instantOrLocalDateTime;
    this._zone = Preconditions.CheckNotNull(zone, "zone");
    if (calendarOrOffset === undefined) {
      this._offsetDateTime = OffsetDateTime.NewInstantOffset(instant, zone.GetUtcOffset(instant));
    } else {
      this._offsetDateTime = OffsetDateTime.NewInstantOffsetCalendar(instant, zone.GetUtcOffset(instant),
        Preconditions.CheckNotNull(calendarOrOffset as CalendarSystem, "calendar"));
    }
  }

  /** Gets the offset of the local representation of this value from UTC. */
  get Offset(): Offset {
    return this._offsetDateTime.Offset;
  }

  /**
   * Gets the local date and time represented by this zoned date and time.
   *
   * The returned
   * {@link LocalDateTime} will have the same calendar system and return the same values for
   * each of the calendar properties (Year, MonthOfYear and so on), but will not be associated with any
   * particular time zone.
   */
  get LocalDateTime(): LocalDateTime {
    return this._offsetDateTime.LocalDateTime;
  }

  /** Gets the calendar system associated with this zoned date and time. */
  get Calendar(): CalendarSystem {
    return this._offsetDateTime.Calendar;
  }

  /**
   * Gets the local date represented by this zoned date and time.
   *
   * The returned {@link LocalDate}
   * will have the same calendar system and return the same values for each of the date-based calendar
   * properties (Year, MonthOfYear and so on), but will not be associated with any particular time zone.
   */
  get Date(): LocalDate {
    return this._offsetDateTime.Date;
  }

  /**
   * Gets the time portion of this zoned date and time.
   *
   * The returned {@link LocalTime} will
   * return the same values for each of the time-based properties (Hour, Minute and so on), but
   * will not be associated with any particular time zone.
   */
  get TimeOfDay(): LocalTime {
    return this._offsetDateTime.TimeOfDay;
  }

  /** Gets the era for this zoned date and time. */
  get Era(): Era {
    return this._offsetDateTime.Era;
  }

  /**
   * Gets the year of this zoned date and time.
   *
   * This returns the "absolute year", so, for the ISO calendar,
   * a value of 0 means 1 BC, for example.
   */
  get Year(): number {
    return this._offsetDateTime.Year;
  }

  /** Gets the year of this zoned date and time within its era. */
  get YearOfEra(): number {
    return this._offsetDateTime.YearOfEra;
  }

  /** Gets the month of this zoned date and time within the year. */
  get Month(): number {
    return this._offsetDateTime.Month;
  }

  /** Gets the day of this zoned date and time within the year. */
  get DayOfYear(): number {
    return this._offsetDateTime.DayOfYear;
  }

  /**
   * Gets the day of this zoned date and time within the month.
   */
  get Day(): number {
    return this._offsetDateTime.Day;
  }

  /**
   * Gets the week day of this zoned date and time expressed as an {@link IsoDayOfWeek} value.
   */
  get DayOfWeek(): IsoDayOfWeek {
    return this._offsetDateTime.DayOfWeek;
  }

  /**
   * Gets the hour of day of this zoned date and time, in the range 0 to 23 inclusive.
   */
  get Hour(): number {
    return this._offsetDateTime.Hour;
  }

  /**
   * Gets the hour of the half-day of this zoned date and time, in the range 1 to 12 inclusive.
   */
  get ClockHourOfHalfDay(): number {
    return this._offsetDateTime.ClockHourOfHalfDay;
  }

  /**
   * Gets the minute of this zoned date and time, in the range 0 to 59 inclusive.
   */
  get Minute(): number {
    return this._offsetDateTime.Minute;
  }

  /**
   * Gets the second of this zoned date and time within the minute, in the range 0 to 59 inclusive.
   */
  get Second(): number {
    return this._offsetDateTime.Second;
  }

  /**
   * Gets the millisecond of this zoned date and time within the second, in the range 0 to 999 inclusive.
   */
  get Millisecond(): number {
    return this._offsetDateTime.Millisecond;
  }

  /**
   * Gets the tick of this zoned date and time within the second, in the range 0 to 9,999,999 inclusive.
   */
  get TickOfSecond(): number {
    return this._offsetDateTime.TickOfSecond;
  }

  /**
   * Gets the tick of this zoned date and time within the day, in the range 0 to 863,999,999,999 inclusive.
   *
   * This is the TickOfDay portion of the contained {@link OffsetDateTime}.
   * On daylight saving time transition dates, it may not be the same as the number of ticks elapsed since the beginning of the day.
   */
  get TickOfDay(): number {
    return this._offsetDateTime.TickOfDay;
  }

  /**
   * Gets the nanosecond of this zoned date and time within the second, in the range 0 to 999,999,999 inclusive.
   */
  get NanosecondOfSecond(): number {
    return this._offsetDateTime.NanosecondOfSecond;
  }

  /**
   * Gets the nanosecond of this zoned date and time within the day, in the range 0 to 86,399,999,999,999 inclusive.
   *
   * This is the NanosecondOfDay portion of the contained {@link OffsetDateTime}.
   * On daylight saving time transition dates, it may not be the same as the number of nanoseconds elapsed since the beginning of the day.
   */
  get NanosecondOfDay(): number {
    return this._offsetDateTime.NanosecondOfDay;
  }

  /**
   * Converts this value to the instant it represents on the time line.
   *
   * This is always an unambiguous conversion. Any difficulties due to daylight saving
   * transitions or other changes in time zone are handled when converting from a
   * {@link LocalDateTime} to a {@link ZonedDateTime}; the `ZonedDateTime` remembers
   * the actual offset from UTC to local time, so it always knows the exact instant represented.
   *
   * @returns The instant corresponding to this value.
   */
  ToInstant(): Instant {
    return this._offsetDateTime.ToInstant();
  }

  /**
   * Creates a new {@link ZonedDateTime} representing the same instant in time, in the
   * same calendar but a different time zone.
   *
   * @param targetZone The target time zone to convert to.
   * @returns A new value in the target time zone.
   */
  WithZone(targetZone: DateTimeZone): ZonedDateTime {
    Preconditions.CheckNotNull(targetZone, "targetZone");
    return new ZonedDateTime(this.ToInstant(), targetZone, this.Calendar);
  }

  /**
   * Creates a new ZonedDateTime representing the same physical date, time and offset, but in a different calendar.
   * The returned ZonedDateTime is likely to have different date field values to this one.
   * For example, January 1st 1970 in the Gregorian calendar was December 19th 1969 in the Julian calendar.
   *
   * @param calendar The calendar system to convert this zoned date and time to.
   * @returns The converted ZonedDateTime.
   */
  WithCalendar(calendar: CalendarSystem): ZonedDateTime {
    return ZonedDateTime.NewOffsetDateTimeZone(this._offsetDateTime.WithCalendar(calendar), this.Zone);
  }

  // #region Equality
  /**
   * Indicates whether the current object is equal to another object of the same type.
   * See the type documentation for a description of equality semantics.
   * (Merges NodaTime's Equals(ZonedDateTime), Equals(object) and operator ==.)
   *
   * @param other An object to compare with this object.
   * @returns True if the specified value is the same instant in the same time zone; false otherwise.
   */
  Equals(other: ZonedDateTime): boolean;
  /** @inheritDoc */
  Equals(other: unknown): boolean;
  Equals(other: unknown): boolean {
    return other instanceof ZonedDateTime && this._offsetDateTime.Equals(other._offsetDateTime) && this.Zone.Equals(other.Zone);
  }
  // #endregion

  // #region Operators
  /**
   * Adds a duration to a zoned date and time.
   * (NodaTime's `operator +` and `Add`.)
   *
   * The returned value retains the calendar system and time zone of `zonedDateTime`.
   *
   * @param zonedDateTime The value to add the duration to.
   * @param duration The duration to add
   * @returns A new value with the time advanced by the given duration, in the same calendar system and time zone.
   */
  static Add(zonedDateTime: ZonedDateTime, duration: Duration): ZonedDateTime {
    return new ZonedDateTime(zonedDateTime.ToInstant().Plus(duration), zonedDateTime.Zone, zonedDateTime.Calendar);
  }

  /**
   * Returns the result of adding a duration to this zoned date and time.
   *
   * This is an alternative way of calling {@link ZonedDateTime.Add}.
   *
   * @param duration The duration to add
   * @returns A new {@link ZonedDateTime} representing the result of the addition.
   */
  Plus(duration: Duration): ZonedDateTime {
    return ZonedDateTime.Add(this, duration);
  }

  /**
   * Returns the result of adding a increment of hours to this zoned date and time
   *
   * @param hours The number of hours to add
   * @returns A new {@link ZonedDateTime} representing the result of the addition.
   */
  PlusHours(hours: number): ZonedDateTime {
    return ZonedDateTime.Add(this, Duration.FromHours(hours));
  }

  /**
   * Returns the result of adding an increment of minutes to this zoned date and time
   *
   * @param minutes The number of minutes to add
   * @returns A new {@link ZonedDateTime} representing the result of the addition.
   */
  PlusMinutes(minutes: number): ZonedDateTime {
    return ZonedDateTime.Add(this, Duration.FromMinutes(minutes));
  }

  /**
   * Returns the result of adding an increment of seconds to this zoned date and time
   *
   * @param seconds The number of seconds to add
   * @returns A new {@link ZonedDateTime} representing the result of the addition.
   */
  PlusSeconds(seconds: number): ZonedDateTime {
    return ZonedDateTime.Add(this, Duration.FromSeconds(seconds));
  }

  /**
   * Returns the result of adding an increment of milliseconds to this zoned date and time
   *
   * @param milliseconds The number of milliseconds to add
   * @returns A new {@link ZonedDateTime} representing the result of the addition.
   */
  PlusMilliseconds(milliseconds: number): ZonedDateTime {
    return ZonedDateTime.Add(this, Duration.FromMilliseconds(milliseconds));
  }

  /**
   * Returns the result of adding an increment of ticks to this zoned date and time
   *
   * @param ticks The number of ticks to add
   * @returns A new {@link ZonedDateTime} representing the result of the addition.
   */
  PlusTicks(ticks: number | string): ZonedDateTime {
    return ZonedDateTime.Add(this, Duration.FromTicks(ticks));
  }

  /**
   * Returns the result of adding an increment of nanoseconds to this zoned date and time
   *
   * @param nanoseconds The number of nanoseconds to add
   * @returns A new {@link ZonedDateTime} representing the result of the addition.
   */
  PlusNanoseconds(nanoseconds: number | string): ZonedDateTime {
    return ZonedDateTime.Add(this, Duration.FromNanoseconds(nanoseconds));
  }

  /**
   * Subtracts a duration from a zoned date and time.
   * (NodaTime's `operator -(ZonedDateTime, Duration)` and `Subtract(ZonedDateTime, Duration)`.)
   *
   * The returned value retains the calendar system and time zone of `zonedDateTime`.
   *
   * @param zonedDateTime The value to subtract the duration from.
   * @param duration The duration to subtract.
   * @returns A new value with the time "rewound" by the given duration, in the same calendar system and time zone.
   */
  static Subtract(zonedDateTime: ZonedDateTime, duration: Duration): ZonedDateTime;
  /**
   * Subtracts one zoned date and time from another, returning an elapsed duration.
   * (NodaTime's `operator -(ZonedDateTime, ZonedDateTime)` and `Subtract(ZonedDateTime, ZonedDateTime)`.)
   *
   * This is equivalent to `end.ToInstant().Minus(start.ToInstant())`; in particular:
   * - The two values can use different calendar systems
   * - The two values can be in different time zones
   * - The two values can have different UTC offsets
   *
   * @param end The zoned date and time value to subtract from; if this is later than `start`
   * then the result will be positive.
   * @param start The zoned date and time to subtract from `end`.
   * @returns The elapsed duration from `start` to `end`.
   */
  static Subtract(end: ZonedDateTime, start: ZonedDateTime): Duration;
  static Subtract(left: ZonedDateTime, right: Duration | ZonedDateTime): ZonedDateTime | Duration {
    if (right instanceof ZonedDateTime) {
      return left.ToInstant().Minus(right.ToInstant());
    }
    return new ZonedDateTime(left.ToInstant().Minus(right), left.Zone, left.Calendar);
  }

  /**
   * Returns the result of subtracting a duration from this zoned date and time, for a fluent alternative to
   * {@link ZonedDateTime.Subtract}.
   *
   * @param duration The duration to subtract
   * @returns A new {@link ZonedDateTime} representing the result of the subtraction.
   */
  Minus(duration: Duration): ZonedDateTime;
  /**
   * Returns the result of subtracting another zoned date and time from this one, resulting in the elapsed duration
   * between the two instants represented in the values.
   *
   * This is an alternative way of calling {@link ZonedDateTime.Subtract}.
   *
   * @param other The zoned date and time to subtract from this one.
   * @returns The elapsed duration from `other` to this value.
   */
  Minus(other: ZonedDateTime): Duration;
  Minus(other: Duration | ZonedDateTime): ZonedDateTime | Duration {
    return other instanceof ZonedDateTime ? ZonedDateTime.Subtract(this, other) : ZonedDateTime.Subtract(this, other);
  }
  // #endregion

  /**
   * Returns the {@link ZoneInterval} containing this value, in the time zone this
   * value refers to.
   *
   * This is simply a convenience method - it is logically equivalent to converting this
   * value to an {@link Instant} and then asking the appropriate {@link DateTimeZone}
   * for the `ZoneInterval` containing that instant.
   *
   * @returns The `ZoneInterval` containing this value.
   */
  GetZoneInterval(): ZoneInterval {
    return this.Zone.GetZoneInterval(this.ToInstant());
  }

  /**
   * Indicates whether or not this {@link ZonedDateTime} is in daylight saving time
   * for its time zone. This is determined by checking the {@link ZoneInterval.Savings} property
   * of the zone interval containing this value.
   *
   * @see GetZoneInterval
   * @returns `true` if the zone interval containing this value has a non-zero savings
   * component; `false` otherwise.
   */
  IsDaylightSavingTime(): boolean {
    return !this.GetZoneInterval().Savings.Equals(Offset.Zero);
  }

  // #region Formatting
  /**
   * Formats the value of the current instance using the specified pattern.
   *
   * With no arguments, this returns the value of the current instance in the default format pattern ("G"),
   * using the invariant culture. (NodaTime uses the current thread's culture.)
   *
   * @param patternText The pattern to use, or null to use the default format pattern ("G").
   * @param formatProvider The format provider to use when formatting the value,
   * or null to use the invariant culture.
   * @returns The value of the current instance in the specified format.
   */
  toString(patternText: string | null = null, formatProvider: IFormatProvider | null = null): string {
    return ZonedDateTimePattern.BclSupport.Format(this, patternText, formatProvider ?? NodaCultureInfo.InvariantCulture);
  }
  // #endregion Formatting

  // Not ported: ToDateTimeOffset() (BCL interop)

  // Not ported: FromDateTimeOffset(DateTimeOffset) (BCL interop)

  // Not ported: ToDateTimeUtc() (BCL interop)

  // Not ported: ToDateTimeUnspecified() (BCL interop)

  /**
   * Constructs an {@link OffsetDateTime} with the same local date and time, and the same offset
   * as this zoned date and time, effectively just "removing" the time zone itself.
   *
   * @returns An OffsetDateTime with the same local date/time and offset as this value.
   */
  ToOffsetDateTime(): OffsetDateTime {
    return this._offsetDateTime;
  }

  // Not ported: Deconstruct (JS destructuring works on getters)

  // Comparers: see ZonedDateTimeComparer above.

  // Not ported: AddSchema, IXmlSerializable.GetSchema/ReadXml/WriteXml (XML serialization)

  // #region JSON
  /**
   * Formats this value as NodaTime.Serialization.SystemTextJson does, with the invariant pattern
   * `uuuu'-'MM'-'dd'T'HH':'mm':'ss;FFFFFFFFFo<G> z`.
   */
  toJSON(): string {
    jsonFormatPattern ??= ZonedDateTimePattern.CreateWithInvariantCulture(JsonPatternText, null);
    return jsonFormatPattern.Format(this);
  }

  /**
   * Parses a value written by {@link toJSON}, resolving the time zone ID with the given provider.
   *
   * JSON doesn't record the calendar system: the date is read in `calendar` (the ISO calendar if omitted), as
   * NodaTime.Serialization.SystemTextJson reads it with a converter whose pattern uses that calendar.
   *
   * @throws {UnparsableValueException} The text could not be parsed.
   */
  static fromJSON(json: string, provider: IDateTimeZoneProvider, calendar?: CalendarSystem): ZonedDateTime {
    Preconditions.CheckNotNull(provider, "provider");
    const pattern = ZonedDateTimePattern.CreateWithInvariantCulture(JsonPatternText, provider);
    return (calendar === undefined ? pattern : pattern.WithCalendar(calendar)).Parse(json).Value;
  }
  // #endregion

  valueOf(): never {
    ThrowValueOf("ZonedDateTime");
  }
}
