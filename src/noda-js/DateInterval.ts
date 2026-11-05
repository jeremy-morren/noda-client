// Ported from NodaTime 3.3.0: src/NodaTime/DateInterval.cs
// Copyright 2014 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import {
  LocalDate,
  LocalDatePattern,
  Period,
  Preconditions,
  UnparsableValueError,
  ThrowValueOf,
  type CalendarSystem,
} from "./internal.ts";
import type { IEquatable } from "./internal.ts";

/**
 * An interval between two dates.
 *
 * Equality is defined in a component-wise fashion: two date intervals are considered equal if their start dates are
 * equal to each other and their end dates are equal to each other. Ordering between date intervals is not defined.
 *
 * The two dates must be in the same calendar, and the end date must not be earlier than the start date.
 *
 * The end date is deemed to be part of the range, as this matches many real life uses of
 * date ranges. For example, if someone says "I'm going to be on holiday from Monday to Friday," they
 * usually mean that Friday is part of their holiday.
 *
 * This type is immutable reference type. See the thread safety section of the user guide for more information.
 */
export class DateInterval implements IEquatable<DateInterval>, Iterable<LocalDate> {
  private readonly _start: LocalDate;

  /**
   * Gets the start date of the interval.
   */
  get Start(): LocalDate {
    return this._start;
  }

  private readonly _end: LocalDate;

  /**
   * Gets the end date of the interval.
   */
  get End(): LocalDate {
    return this._end;
  }

  /**
   * Constructs a date interval from a start date and an end date, both of which are included
   * in the interval.
   * @param start Start date of the interval
   * @param end End date of the interval
   * @throws {ArgumentError} `end` is earlier than `start`
   * or the two dates are in different calendars.
   */
  constructor(start: LocalDate, end: LocalDate) {
    Preconditions.CheckArgument(start.Calendar === end.Calendar, "end",
      "Calendars of start and end dates must be the same.");
    Preconditions.CheckArgument(!(end.CompareTo(start) < 0), "end", "End date must not be earlier than the start date");
    this._start = start;
    this._end = end;
  }

  // Not ported: GetHashCode() (omitted, as per the porting conventions)

  // Operators == and != are covered by equals().

  /**
   * Compares the given date interval for equality with this one.
   * See the type documentation for a description of equality semantics.
   * @param other The date interval to compare this one with.
   * @returns True if this date interval has the same same start and end date as the one specified.
   *
   * noda-js: covers both `IEquatable<DateInterval>.Equals(DateInterval)` and `object.Equals(object)`.
   */
  Equals(other: DateInterval): boolean;
  /** @inheritDoc */
  Equals(other: unknown): boolean;
  Equals(other: unknown): boolean {
    if (this === other) {
      return true;
    }
    if (!(other instanceof DateInterval)) {
      return false;
    }
    return this.Start.Equals(other.Start) && this.End.Equals(other.End);
  }

  /**
   * Checks whether the given date is within this date interval. This requires
   * that the date is not earlier than the start date, and not later than the end
   * date.
   * @param date The date to check for containment within this interval.
   * @throws {ArgumentError} `date` is not in the same
   * calendar as the start and end date of this interval.
   * @returns `true` if `date` is within this interval; `false` otherwise.
   */
  Contains(date: LocalDate): boolean;
  /**
   * Checks whether the given interval is within this interval. This requires that the start date of the specified
   * interval is not earlier than the start date of this interval, and the end date of the specified interval is not
   * later than the end date of this interval.
   *
   * An interval contains another interval with same start and end dates, or itself.
   *
   * @param interval The interval to check for containment within this interval.
   * @throws {ArgumentError} `interval` uses a different
   * calendar to this date interval.
   * @returns `true` if `interval` is within this interval; `false` otherwise.
   */
  Contains(interval: DateInterval): boolean;
  Contains(dateOrInterval: LocalDate | DateInterval): boolean {
    if (dateOrInterval instanceof LocalDate) {
      const date = dateOrInterval;
      Preconditions.CheckArgument(date.Calendar === this.Start.Calendar, "date",
        "The date to check must be in the same calendar as the start and end dates");
      return this.Start.CompareTo(date) <= 0 && date.CompareTo(this.End) <= 0;
    }
    const interval = dateOrInterval;
    this.ValidateInterval(interval);
    return this.Start.CompareTo(interval.Start) <= 0 && interval.End.CompareTo(this.End) <= 0;
  }

  /**
   * Gets the length of this date interval in days. This will always be at least 1.
   */
  get Length(): number {
    // Period.InternalDaysBetween will give us the exclusive result, so we need to add 1
    // to include the end date.
    return Period.InternalDaysBetween(this.Start, this.End) + 1;
  }

  /**
   * Gets the calendar system of the dates in this interval.
   */
  get Calendar(): CalendarSystem {
    return this.Start.Calendar;
  }

  /**
   * Returns a string representation of this interval.
   * @returns A string representation of this interval, as `[start, end]`,
   * where "start" and "end" are the dates formatted using an ISO-8601 compatible pattern.
   */
  toString(): string {
    const pattern = LocalDatePattern.Iso;
    return `[${pattern.Format(this.Start)}, ${pattern.Format(this.End)}]`;
  }

  // Not ported: Deconstruct (omitted, as per the porting conventions)

  /**
   * Returns the intersection between the given interval and this interval.
   * @param interval The specified interval to intersect with this one.
   * @returns A {@link DateInterval} corresponding to the intersection between the given interval and the current
   * instance. If there is no intersection, null is returned.
   * @throws {ArgumentError} `interval` uses a different
   * calendar to this date interval.
   */
  Intersection(interval: DateInterval): DateInterval | null {
    return this.Contains(interval) ? interval
      : interval.Contains(this) ? this
      : interval.Contains(this.Start) ? new DateInterval(this.Start, interval.End)
      : interval.Contains(this.End) ? new DateInterval(interval.Start, this.End)
      : null;
  }

  /**
   * Returns the union between the given interval and this interval, as long as they're overlapping or contiguous.
   * @param interval The specified interval from which to generate the union interval.
   * @returns A {@link DateInterval} corresponding to the union between the given interval and the current
   * instance, in the case the intervals overlap or are contiguous; null otherwise.
   * @throws {ArgumentError} `interval` uses a different calendar to this date interval.
   */
  Union(interval: DateInterval): DateInterval | null {
    this.ValidateInterval(interval);

    const start = LocalDate.Min(this.Start, interval.Start);
    const end = LocalDate.Max(this.End, interval.End);

    // Check whether the length of the interval we *would* construct is greater
    // than the sum of the lengths - if it is, there's a day in that candidate union
    // that isn't in either interval. Note the absence of "+ 1" and the use of >=
    // - it's equivalent to Period.InternalDaysBetween(...) + 1 > Length + interval.Length,
    // but with fewer operations.
    return Period.InternalDaysBetween(start, end) >= this.Length + interval.Length
      ? null
      : new DateInterval(start, end);
  }

  private ValidateInterval(interval: DateInterval): void {
    Preconditions.CheckNotNull(interval, "interval");
    Preconditions.CheckArgument(interval.Calendar === this.Start.Calendar, "interval",
      "The specified interval uses a different calendar system to this one");
  }

  /**
   * Returns an iterator for the dates in the interval, including both {@link Start} and {@link End}.
   * (C#: `GetEnumerator()`)
   * @returns An iterator for the interval.
   */
  *[Symbol.iterator](): Iterator<LocalDate> {
    // Stop when we know we've reach End, and then yield that.
    // We can't use a <= condition, as otherwise we'd try to create a date past End, which may be invalid.
    // We could use < but that's significantly less efficient than !=
    // We know that adding a day at a time we'll eventually reach End (because they're validated to be in the same calendar
    // system, with Start <= End), so that's the simplest way to go.
    for (let date = this.Start; !date.Equals(this.End); date = date.PlusDays(1)) {
      yield date;
    }
    yield this.End;
  }

  // #region JSON (noda-js)
  /**
   * Returns the JSON representation of this value, as written by NodaTime.Serialization.SystemTextJson:
   * an object with `start` and `end` properties holding ISO dates. (The property names are camelCase,
   * as with ASP.NET Core's default naming policy.)
   */
  toJSON(): { start: string; end: string } {
    return { start: this.Start.toJSON(), end: this.End.toJSON() };
  }

  /**
   * Parses the JSON representation of a value, as written by {@link toJSON}. The property names
   * are matched case-insensitively, so both `{ start, end }` and `{ Start, End }` are accepted.
   *
   * JSON doesn't record the calendar system: the dates are read in `calendar` (the ISO calendar if omitted), as
   * {@link LocalDate.fromJSON} reads them.
   * @throws {UnparsableValueError} The value isn't an object with both properties, or a date can't be parsed.
   */
  static fromJSON(json: unknown, calendar?: CalendarSystem): DateInterval {
    if (typeof json !== "object" || json === null) {
      throw new UnparsableValueError("Expected a date interval object with start and end properties.");
    }
    let start: LocalDate | undefined;
    let end: LocalDate | undefined;
    for (const key of Object.keys(json)) {
      const value: unknown = (json as Record<string, unknown>)[key];
      const lowerKey = key.toLowerCase();
      if (lowerKey === "start") {
        start = LocalDate.fromJSON(value as string, calendar);
      } else if (lowerKey === "end") {
        end = LocalDate.fromJSON(value as string, calendar);
      }
    }
    if (start === undefined || end === undefined) {
      throw new UnparsableValueError("Expected a date interval object with start and end properties.");
    }
    return new DateInterval(start, end);
  }
  // #endregion

  /** Throws a TypeError: date intervals have no ordering. Use {@link Equals} instead. */
  valueOf(): never {
    return ThrowValueOf("DateInterval");
  }
}
