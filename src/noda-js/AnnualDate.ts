// Ported from NodaTime 3.3.7: src/NodaTime/AnnualDate.cs
// Copyright 2015 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import {
  AnnualDatePattern,
  CalendarSystem,
  NodaCultureInfo,
  GregorianYearMonthDayCalculator,
  LocalDate,
  Preconditions,
  YearMonthDay,
  ThrowValueOf,
  type IComparable,
  type IEquatable,
  type IFormatProvider,
} from "./internal.ts";
import type { ArgumentException, ArgumentOutOfRangeException } from "./internal.ts";

/**
 * Represents an annual date (month and day) in the ISO calendar but without a specific year,
 * typically for recurrent events such as birthdays, anniversaries, and deadlines.
 *
 * Equality and comparison order are defined in the natural way. Two values are equal if they
 * represent the same month and the same day-of-month. One value is earlier than another if it
 * has a smaller month, or the same month but an earlier day-of-month.
 *
 * In the future, this struct may be expanded to support other calendar systems,
 * but this does not generalize terribly cleanly, particularly to the Hebrew calendar system
 * with its leap month.
 *
 * The default value of this type is January 1st.
 */
export class AnnualDate implements IEquatable<AnnualDate>, IComparable<AnnualDate> {
  // The underlying value. We only care about the month and day, but for the sake of
  // compatibility with the default value, this ends up being in year 1. This would
  // be an invalid date, but we only actually use it as an argument to SetYear,
  // which we know ignores the year in the ISO calendar. If we ever allow other calendar
  // systems, we can have a YearMonthDayCalendar which would still be in year 1 for the
  // ISO calendar, but would probably be in a more suitable year for other calendars.
  private readonly _value: YearMonthDay;

  /**
   * Constructs an instance for the given month and day in the ISO calendar.
   * @param month The month of year.
   * @param day The day of month.
   * @throws {ArgumentOutOfRangeException} The parameters do not form a valid date.
   * (February 29th is considered valid.)
   */
  constructor(month: number, day: number) {
    // The year 2000 is a leap year, so this is fine for all valid dates.
    GregorianYearMonthDayCalculator.ValidateGregorianYearMonthDay(2000, month, day);
    // See comment above for why this is using year 1, and why that's okay even for February 29th.
    this._value = YearMonthDay.NewYearMonthDay(1, month, day);
  }

  /**
   * Gets the month of year.
   */
  get Month(): number {
    return this._value.Month;
  }

  /**
   * Gets the day of month.
   */
  get Day(): number {
    return this._value.Day;
  }

  /**
   * Returns this annual date in a particular year, as a {@link LocalDate}.
   *
   * If this value represents February 29th, and the specified year is not a leap
   * year, the returned value will be February 28th of that year. To see whether the
   * original month and day is valid without truncation in a particular year,
   * use {@link IsValidYear}
   *
   * @param year The year component of the required date.
   * @returns A date in the given year, suitable for this annual date.
   */
  InYear(year: number): LocalDate {
    Preconditions.CheckArgumentRange("year", year,
      GregorianYearMonthDayCalculator.MinGregorianYear,
      GregorianYearMonthDayCalculator.MaxGregorianYear);
    const ymd = CalendarSystem.Iso.YearMonthDayCalculator.SetYear(this._value, year);
    return LocalDate.NewYearMonthDayCalendar(ymd.WithCalendarOrdinal(0)); // ISO calendar
  }

  /**
   * Checks whether the specified year forms a valid date with the month/day in this
   * value, without any truncation. This will always return `true` except
   * for values representing February 29th, where the specified year is a non leap year.
   * @param year The year to test for validity
   * @returns `true` if the current value occurs within the given year;
   * `false` otherwise.
   */
  IsValidYear(year: number): boolean {
    return this.Month !== 2 || this.Day !== 29 || CalendarSystem.Iso.IsLeapYear(year);
  }

  // Not ported: GetHashCode() (omitted, as per the porting conventions)

  /**
   * Returns a string that represents this instance.
   *
   * With no arguments (or a null pattern), this is the value of the current instance in the default format
   * pattern ("G"), using the invariant culture (NodaTime uses the current thread's culture).
   *
   * @param patternText The string specifying the pattern to use,
   * or null to use the default format pattern ("G").
   * @param formatProvider The {@link IFormatProvider} to use when formatting the value,
   * or null to use the invariant culture.
   * @returns A string containing the value of the current instance in the specified format.
   */
  toString(patternText?: string | null, formatProvider?: IFormatProvider | null): string {
    return AnnualDatePattern.BclSupport.Format(this, patternText ?? null, formatProvider ?? NodaCultureInfo.InvariantCulture);
  }

  /**
   * Compares this annual date with the specified one for equality.
   * See the type documentation for a description of equality semantics.
   * @param other The other annual date to compare this one with
   * @returns True if the specified annual date is equal to this one; false otherwise
   *
   * noda-js: also covers `object.Equals(object)`: false for anything that isn't an {@link AnnualDate}.
   */
  Equals(other: AnnualDate): boolean;
  /** @inheritDoc */
  Equals(other: unknown): boolean;
  Equals(other: unknown): boolean {
    return other instanceof AnnualDate && this._value.Equals(other._value);
  }

  /**
   * Indicates whether this annual date is earlier, later or the same as another one.
   * See the type documentation for a description of ordering semantics.
   *
   * noda-js: also covers the non-generic `IComparable.CompareTo(object)`: if `other` is null, this method
   * returns a value greater than 0.
   *
   * @param other The other annual date to compare this one with
   * @throws {ArgumentException} `other` is non-null but does not refer to an instance of {@link AnnualDate}
   * @returns A value less than zero if this annual date is earlier than `other`;
   * zero if this time is the same as `other`; a value greater than zero if this annual date is
   * later than `other`.
   */
  CompareTo(other: AnnualDate | null): number;
  /** @inheritDoc */
  CompareTo(other: unknown): number;
  CompareTo(other: unknown): number {
    if (other === null || other === undefined) {
      return 1;
    }
    Preconditions.CheckArgument(other instanceof AnnualDate, "obj", "Object must be of type NodaTime.AnnualDate.");
    return this._value.CompareTo((other as AnnualDate)._value);
  }

  // Operators ==, !=, <, <=, > and >= are covered by Equals() and CompareTo().

  // #region XML serialization
  // Not ported: AddSchema, IXmlSerializable.GetSchema, ReadXml, WriteXml (XML serialization)
  // #endregion

  // #region JSON (noda-js)
  /**
   * Returns the JSON representation of this value, as written by NodaTime.Serialization.SystemTextJson:
   * the ISO pattern ({@link AnnualDatePattern.Iso}), e.g. "03-01".
   */
  toJSON(): string {
    return AnnualDatePattern.Iso.Format(this);
  }

  /**
   * Parses the JSON representation of a value, as written by {@link toJSON}.
   * @throws {UnparsableValueException} The value can't be parsed.
   */
  static fromJSON(json: string): AnnualDate {
    return AnnualDatePattern.Iso.Parse(json).Value;
  }
  // #endregion

  /** Throws a TypeError: use {@link CompareTo} or {@link Equals} instead of relational operators. */
  valueOf(): never {
    return ThrowValueOf("AnnualDate");
  }
}
