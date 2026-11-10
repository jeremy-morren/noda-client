// Ported from NodaTime 3.3.7: src/NodaTime/YearMonth.cs
// Copyright 2019 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import {
  CalendarOrdinal,
  CalendarSystem,
  NodaCultureInfo,
  DateInterval,
  Era,
  GregorianYearMonthDayCalculator,
  LocalDate,
  Preconditions,
  YearMonthDayCalendar,
  YearMonthPattern,
  ThrowValueOf,
  type IComparable,
  type IEquatable,
  type IFormatProvider,
  type YearMonthDay,
} from "./internal.ts";
import type { ArgumentException, ArgumentOutOfRangeException } from "./internal.ts";

/**
 * A year and month in a particular calendar. This is effectively
 * {@link LocalDate} without the day-of-month component.
 *
 * Values can freely be compared for equality: a value in a different calendar system is not equal to
 * a value in a different calendar system. However, ordering comparisons
 * fail with {@link ArgumentException}; attempting to compare values in different calendars
 * almost always indicates a bug in the calling code.
 *
 * This type is an immutable value type. See the thread safety section of the user guide for more information.
 */
export class YearMonth implements IEquatable<YearMonth>, IComparable<YearMonth> {
  /**
   * The start of month. This is used as our base representation as we already have
   * plenty of other code that integrates it, and it implements a compact representation
   * without us having to duplicate any of the logic.
   */
  private readonly _startOfMonth: YearMonthDayCalendar;

  /** Gets the calendar system associated with this year/month. */
  get Calendar(): CalendarSystem {
    return CalendarSystem.ForOrdinal(this.CalendarOrdinal);
  }

  private get CalendarOrdinal(): CalendarOrdinal {
    return this._startOfMonth.CalendarOrdinal;
  }

  /**
   * Gets the year of this year/month.
   *
   * This returns the "absolute year", so, for the ISO calendar,
   * a value of 0 means 1 BC, for example.
   */
  get Year(): number {
    return this._startOfMonth.Year;
  }

  /** Gets the month of this year/month within the year. */
  get Month(): number {
    return this._startOfMonth.Month;
  }

  /** Gets the year of this value within the era. */
  get YearOfEra(): number {
    return this.Calendar.GetYearOfEra(this._startOfMonth.Year);
  }

  /** Gets the era of this year/month. */
  get Era(): Era {
    return this.Calendar.GetEra(this._startOfMonth.Year);
  }

  // Note: we could easily make these properties public later if we wanted.
  /**
   * Returns the date of the start of this year/month.
   * @internal
   */
  get StartDate(): LocalDate {
    return LocalDate.NewYearMonthDayCalendar(this._startOfMonth);
  }

  /**
   * Returns the date of the end of this year/month.
   * @internal
   */
  get EndDate(): LocalDate {
    return new LocalDate(this.Year, this.Month, this.Calendar.GetDaysInMonth(this.Year, this.Month), this.Calendar);
  }

  private get YearMonthDay(): YearMonthDay {
    return this._startOfMonth.ToYearMonthDay();
  }

  /**
   * Constructs an instance for the given year and month in the ISO calendar.
   * @param year The year. This is the "absolute year", so a value of 0 means 1 BC, for example.
   * @param month The month of year.
   * @throws {ArgumentOutOfRangeException} The parameters do not form a valid year/month.
   */
  constructor(year: number, month: number);
  /**
   * Constructs an instance for the given year and month in the specified calendar.
   * @param year The year. This is the "absolute year", so, for
   * the ISO calendar, a value of 0 means 1 BC, for example.
   * @param month The month of year.
   * @param calendar Calendar system in which to create the year/month.
   * @throws {ArgumentOutOfRangeException} The parameters do not form a valid year/month.
   */
  constructor(year: number, month: number, calendar: CalendarSystem);
  /**
   * Constructs an instance for the given era, year of era and month in the ISO calendar.
   * @param era The era within which to create a year/month. Must be a valid era within the ISO calendar.
   * @param yearOfEra The year of era.
   * @param month The month of year.
   * @throws {ArgumentOutOfRangeException} The parameters do not form a valid year/month.
   */
  constructor(era: Era, yearOfEra: number, month: number);
  /**
   * Constructs an instance for the given era, year of era and month in the specified calendar.
   * @param era The era within which to create a year/month. Must be a valid era within the specified calendar.
   * @param yearOfEra The year of era.
   * @param month The month of year.
   * @param calendar Calendar system in which to create the year/month.
   * @throws {ArgumentOutOfRangeException} The parameters do not form a valid year/month.
   */
  constructor(era: Era, yearOfEra: number, month: number, calendar: CalendarSystem);
  constructor(a: number | Era, b: number, c?: number | CalendarSystem, d?: CalendarSystem) {
    if (a instanceof Era) {
      // C#: this(era, yearOfEra, month, CalendarSystem.Iso) and
      // this(Preconditions.CheckNotNull(calendar, nameof(calendar)).GetAbsoluteYear(yearOfEra, era), month, calendar)
      const calendar = arguments.length === 3 ? CalendarSystem.Iso : Preconditions.CheckNotNull(d, "calendar");
      const year = calendar.GetAbsoluteYear(b, a);
      const month = c as number;
      calendar.ValidateYearMonthDay(year, month, 1);
      this._startOfMonth = YearMonthDayCalendar.NewYearMonthDayCalendarOrdinal(year, month, 1, calendar.Ordinal);
    } else if (arguments.length === 2) {
      const year = a;
      const month = b;
      // Note: not delegating to (year, month, calendar) to optimize performance.
      if (year < GregorianYearMonthDayCalculator.MinGregorianYear || year > GregorianYearMonthDayCalculator.MaxGregorianYear || month < 1 || month > 12) {
        Preconditions.CheckArgumentRange("year", year, GregorianYearMonthDayCalculator.MinGregorianYear, GregorianYearMonthDayCalculator.MaxGregorianYear);
        Preconditions.CheckArgumentRange("month", month, 1, 12);
      }
      this._startOfMonth = YearMonthDayCalendar.NewYearMonthDayCalendarOrdinal(year, month, 1, CalendarOrdinal.Iso);
    } else {
      const calendar = Preconditions.CheckNotNull(c as CalendarSystem | null | undefined, "calendar");
      calendar.ValidateYearMonthDay(a, b, 1);
      this._startOfMonth = YearMonthDayCalendar.NewYearMonthDayCalendarOrdinal(a, b, 1, calendar.Ordinal);
    }
  }

  /**
   * Returns a {@link DateInterval} covering the month represented by this value.
   * @returns A {@link DateInterval} covering the month represented by this value.
   */
  ToDateInterval(): DateInterval {
    return new DateInterval(this.StartDate, this.EndDate);
  }

  /**
   * Returns a {@link YearMonth} object which is the result of adding the specified number
   * of months to this object.
   * @param months The number of months to add to this object.
   * @returns The resulting {@link YearMonth} after adding the specified number of months.
   */
  PlusMonths(months: number): YearMonth {
    return this.OnDayOfMonth(1).PlusMonths(months).ToYearMonth();
  }

  /**
   * Returns a {@link LocalDate} with the year/month of this value, and the given day of month.
   * @param day The day within the month.
   * @throws {ArgumentOutOfRangeException} `day` does not fall within the
   * month represented by this value.
   * @returns The result of combining this year and month with `day`.
   */
  OnDayOfMonth(day: number): LocalDate {
    Preconditions.CheckArgumentRange("day", day, 1, this.Calendar.GetDaysInMonth(this.Year, this.Month));
    return new LocalDate(this.Year, this.Month, day, this.Calendar);
  }

  /**
   * Indicates whether this year/month is earlier, later or the same as another one.
   * See the type documentation for a description of ordering semantics.
   * @param other The other year/month to compare this one with
   * @throws {ArgumentException} The calendar system of `other` is not the
   * same as the calendar system of this value, or `other` is non-null but is not a {@link YearMonth}.
   * @returns A value less than zero if this year/month is earlier than `other`;
   * zero if this year/month is the same as `other`; a value greater than zero if this date is
   * later than `other`.
   */
  CompareTo(other: YearMonth | null): number;
  /** @inheritDoc */
  CompareTo(other: unknown): number;
  CompareTo(other: unknown): number {
    if (other === null || other === undefined) {
      return 1;
    }
    Preconditions.CheckArgument(other instanceof YearMonth, "obj", "Object must be of type NodaTime.YearMonth.");
    const that = other as YearMonth;
    Preconditions.CheckArgument(this.CalendarOrdinal === that.CalendarOrdinal, "other", "Only values with the same calendar system can be compared");
    return this.TrustedCompareTo(that);
  }

  /**
   * Performs a comparison with another YearMonth, trusting that the calendar of the other date is already correct.
   * This avoids duplicate calendar checks.
   */
  private TrustedCompareTo(other: YearMonth): number {
    return this.Calendar.Compare(this.YearMonthDay, other.YearMonthDay);
  }

  // Operators <, <=, > and >= are covered by CompareTo().

  // Not ported: GetHashCode() (omitted, as per the porting conventions)

  /**
   * Compares two {@link YearMonth} values for equality.
   * See the type documentation for a description of equality semantics.
   * @param other The value to compare this year/month with.
   * @returns True if the given value is another year/month equal to this one; false otherwise.
   */
  Equals(other: YearMonth): boolean;
  /** @inheritDoc */
  Equals(other: unknown): boolean;
  Equals(other: unknown): boolean {
    return other instanceof YearMonth && this._startOfMonth.Equals(other._startOfMonth);
  }

  // Operators == and != are covered by Equals().

  /**
   * Formats the value of the current instance using the specified pattern.
   *
   * With no arguments, this returns the value of the current instance in the culture-specific default format
   * pattern ("G"), using the invariant culture (NodaTime uses the current thread's culture).
   *
   * Unlike most `IFormattable` implementations, a `patternText` of null
   * does not yield the same result as the parameterless `toString()`
   * overload, for backward-compatibility reasons. (It uses the ISO format, which is culture-insensitive.)
   *
   * @param patternText The string specifying the pattern to use,
   * or null to use the ISO format pattern ("g").
   * @param formatProvider The {@link IFormatProvider} to use when formatting the value,
   * or null to use the invariant culture.
   * @returns A string containing the value of the current instance in the specified format.
   */
  toString(patternText?: string | null, formatProvider?: IFormatProvider | null): string {
    if (patternText === undefined && formatProvider === undefined) {
      return YearMonthPattern.BclSupport.Format(this, YearMonthPattern.CultureDefaultFormatPattern, NodaCultureInfo.InvariantCulture);
    }
    return YearMonthPattern.BclSupport.Format(this, patternText ?? null, formatProvider ?? NodaCultureInfo.InvariantCulture);
  }

  // #region XML serialization
  // Not ported: AddSchema, IXmlSerializable.GetSchema, ReadXml, WriteXml (XML serialization)
  // #endregion

  // #region JSON (noda-js)
  /**
   * Returns the JSON representation of this value, as written by NodaTime.Serialization.SystemTextJson:
   * the ISO pattern ({@link YearMonthPattern.Iso}), e.g. "2024-03".
   */
  toJSON(): string {
    return YearMonthPattern.Iso.Format(this);
  }

  /**
   * Parses the JSON representation of a value, as written by {@link toJSON}.
   *
   * JSON doesn't record the calendar system: the year and month is read in `calendar` (the ISO calendar if omitted), as
   * NodaTime.Serialization.SystemTextJson reads it with a converter whose pattern uses that calendar.
   * (YearMonthPattern has no WithCalendar: the calendar comes from the template value, as in NodaTime: the month
   * containing 1 January 2000 (ISO) in `calendar`, a date every calendar's range includes.)
   * @throws {UnparsableValueException} The value can't be parsed.
   */
  static fromJSON(json: string, calendar?: CalendarSystem): YearMonth {
    const pattern = YearMonthPattern.Iso;
    return (calendar === undefined ? pattern : pattern.WithTemplateValue(new LocalDate(2000, 1, 1).WithCalendar(calendar).ToYearMonth())).Parse(json).Value;
  }
  // #endregion

  /** Throws a TypeError: use {@link CompareTo} or {@link Equals} instead of relational operators. */
  valueOf(): never {
    return ThrowValueOf("YearMonth");
  }
}
