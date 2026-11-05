// Ported from NodaTime 3.3.0: src/NodaTime/OffsetDate.cs
// Copyright 2017 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import {
  CalendarSystem,
  NodaCultureInfo,
  Era,
  IsoDayOfWeek,
  LocalDate,
  LocalTime,
  Offset,
  OffsetDatePattern,
  OffsetDateTime,
  ThrowValueOf,
} from "./internal.ts";
import type { IEquatable, IFormatProvider } from "./internal.ts";

/**
 * A combination of a {@link LocalDate} and an {@link Offset}, to represent
 * a date at a specific offset from UTC but without any time-of-day information.
 *
 * Equality is defined in a component-wise fashion: two values are the same if they represent equal dates
 * (including being in the same calendar) and equal offsets from UTC.
 * Ordering between offset dates is not defined.
 *
 * The default value of this type is 0001-01-01 (January 1st, 1 C.E.) in the ISO calendar with a UTC offset of zero.
 *
 * This type is an immutable value type. See the thread safety section of the user guide for more information.
 */
export class OffsetDate implements IEquatable<OffsetDate> {
  // noda-js: NodaTime's "date" and "offset" fields; renamed as they would clash with the Date and Offset properties.
  private readonly _date: LocalDate;
  private readonly _offset: Offset;

  /**
   * Constructs an instance of the specified date and offset.
   * @param date The date part of the value.
   * @param offset The offset part of the value.
   */
  constructor(date: LocalDate, offset: Offset) {
    this._date = date;
    this._offset = offset;
  }

  /** Gets the local date represented by this value. */
  get Date(): LocalDate {
    return this._date;
  }

  /** Gets the offset from UTC of this value. */
  get Offset(): Offset {
    return this._offset;
  }

  /** Gets the calendar system associated with this offset date. */
  get Calendar(): CalendarSystem {
    return this._date.Calendar;
  }

  /**
   * Gets the year of this offset date.
   *
   * This returns the "absolute year", so, for the ISO calendar,
   * a value of 0 means 1 BC, for example.
   */
  get Year(): number {
    return this._date.Year;
  }

  /** Gets the month of this offset date within the year. */
  get Month(): number {
    return this._date.Month;
  }

  /** Gets the day of this offset date within the month. */
  get Day(): number {
    return this._date.Day;
  }

  /** Gets the week day of this offset date expressed as an {@link IsoDayOfWeek} value. */
  get DayOfWeek(): IsoDayOfWeek {
    return this._date.DayOfWeek;
  }

  /** Gets the year of this offset date within the era. */
  get YearOfEra(): number {
    return this._date.YearOfEra;
  }

  /** Gets the era of this offset date. */
  get Era(): Era {
    return this._date.Era;
  }

  /** Gets the day of this offset date within the year. */
  get DayOfYear(): number {
    return this._date.DayOfYear;
  }

  /**
   * Creates a new {@link OffsetDate} for the same date, but with the specified UTC offset.
   * @param offset The new UTC offset.
   * @returns A new `OffsetDate` for the same date, but with the specified UTC offset.
   */
  WithOffset(offset: Offset): OffsetDate {
    return new OffsetDate(this._date, offset);
  }

  /**
   * Returns this offset date, with the given date adjuster applied to it, maintaining the existing offset.
   *
   * If the adjuster attempts to construct an
   * invalid date (such as by trying to set a day-of-month of 30 in February), any exception thrown by
   * that construction attempt will be propagated through this method.
   * @param adjuster The adjuster to apply.
   * @returns The adjusted offset date.
   */
  With(adjuster: (date: LocalDate) => LocalDate): OffsetDate {
    return new OffsetDate(this._date.With(adjuster), this._offset);
  }

  /**
   * Creates a new {@link OffsetDate} representing the same physical date and offset, but in a different calendar.
   * The returned value is likely to have different date field values to this one.
   * For example, January 1st 1970 in the Gregorian calendar was December 19th 1969 in the Julian calendar.
   * @param calendar The calendar system to convert this offset date to.
   * @returns The converted `OffsetDate`.
   */
  WithCalendar(calendar: CalendarSystem): OffsetDate {
    return new OffsetDate(this._date.WithCalendar(calendar), this._offset);
  }

  /**
   * Combines this {@link OffsetDate} with the given {@link LocalTime}
   * into an {@link OffsetDateTime}.
   * @param time The time to combine with this date.
   * @returns The {@link OffsetDateTime} representation of the given time on this date.
   */
  At(time: LocalTime): OffsetDateTime {
    return new OffsetDateTime(this._date.At(time), this._offset);
  }

  // Not ported: GetHashCode

  /**
   * Compares two {@link OffsetDate} values for equality.
   * See the type documentation for a description of equality semantics.
   * @param other The value to compare this offset date with.
   * @returns True if the given value is another offset date equal to this one; false otherwise.
   *
   * noda-js: covers both `IEquatable<OffsetDate>.Equals(OffsetDate)` and `object.Equals(object)`.
   */
  Equals(other: OffsetDate): boolean;
  /** @inheritDoc */
  Equals(other: unknown): boolean;
  Equals(other: unknown): boolean {
    return other instanceof OffsetDate && this._date.Equals(other._date) && this._offset.Equals(other._offset);
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
    return OffsetDatePattern.Patterns.BclSupport.Format(this, patternText, formatProvider ?? NodaCultureInfo.InvariantCulture);
  }

  // Not ported: Deconstruct

  // #region XML serialization
  // Not ported: AddSchema, IXmlSerializable members (XML serialization)
  // #endregion

  // #region JSON (noda-js)
  /** Formats this value with {@link OffsetDatePattern.GeneralIso}, as NodaTime.Serialization.SystemTextJson does. */
  toJSON(): string {
    return OffsetDatePattern.GeneralIso.Format(this);
  }

  /**
   * Parses a value written by {@link toJSON}.
   *
   * JSON doesn't record the calendar system: the date is read in `calendar` (the ISO calendar if omitted), as
   * NodaTime.Serialization.SystemTextJson reads it with a converter whose pattern uses that calendar.
   * @throws {UnparsableValueError} The text could not be parsed.
   */
  static fromJSON(json: string, calendar?: CalendarSystem): OffsetDate {
    const pattern = OffsetDatePattern.GeneralIso;
    return (calendar === undefined ? pattern : pattern.WithCalendar(calendar)).Parse(json).Value;
  }
  // #endregion

  /** Throws a TypeError: use {@link Equals} instead of relational operators. */
  valueOf(): never {
    return ThrowValueOf("OffsetDate");
  }
}
