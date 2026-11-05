// Ported from NodaTime 3.3.0: src/NodaTime/YearMonthDay.cs
// Copyright 2014 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import {
  Preconditions,
  YearMonthDayCalendar,
  PadStart,
  ThrowValueOf,
  type CalendarOrdinal,
  type CalendarSystem,
  type IComparable,
  type IEquatable,
} from "./internal.ts";

// Values of YearMonthDayCalendar.dayBits and YearMonthDayCalendar.monthBits; repeated here as they're used
// at module evaluation time.
const DayBits = 6;
const MonthBits = 5;
const DayMask = (1 << DayBits) - 1;
const MonthMask = ((1 << MonthBits) - 1) << DayBits;

/**
 * A compact representation of a year, month and day in a single 32-bit integer.
 *
 * See {@link YearMonthDayCalendar} for the number of bits per component,
 * but this doesn't have the calendar component, so bit 0 is part of the day value.
 * This type is naive: comparisons are performed assuming that a larger month number
 * always comes after a smaller month number, etc.
 * This is suitable for most, but not all, calendar systems.
 *
 * The internal representation actually uses 0 for 1 (etc) for each component.
 * That means the default value is 0001-01-01, which is reasonable for all
 * supported calendars.
 * @internal
 */
export class YearMonthDay implements IComparable<YearMonthDay>, IEquatable<YearMonthDay> {
  private readonly _value: number;

  private constructor(value: number) {
    this._value = value;
  }

  /** C#: `internal YearMonthDay(int rawValue)` */
  static NewRawValue(rawValue: number): YearMonthDay {
    return new YearMonthDay(rawValue);
  }

  /**
   * Constructs a new value for the given year, month and day. No validation is performed.
   * (C#: `internal YearMonthDay(int year, int month, int day)`)
   */
  static NewYearMonthDay(year: number, month: number, day: number): YearMonthDay {
    // unchecked
    return new YearMonthDay(((year - 1) << (DayBits + MonthBits)) |
      ((month - 1) << DayBits) |
      (day - 1));
  }

  get Year(): number {
    return (this._value >> (DayBits + MonthBits)) + 1;
  }

  get Month(): number {
    return ((this._value & MonthMask) >> DayBits) + 1;
  }

  get Day(): number {
    return (this._value & DayMask) + 1;
  }

  // Just for testing purposes... note that this does not perform clean validation.
  static Parse(text: string): YearMonthDay {
    // Handle a leading - to negate the year
    if (text[0] === "-") {
      const ymd = YearMonthDay.Parse(text.substring(1));
      return YearMonthDay.NewYearMonthDay(-ymd.Year, ymd.Month, ymd.Day);
    }

    const bits = text.split("-");
    return YearMonthDay.NewYearMonthDay(
      Number.parseInt(bits[0]!, 10),
      Number.parseInt(bits[1]!, 10),
      Number.parseInt(bits[2]!, 10));
  }

  toString(): string {
    return `${FormatPadded(this.Year, 4)}-${FormatPadded(this.Month, 2)}-${FormatPadded(this.Day, 2)}`;
  }

  WithCalendar(calendar: CalendarSystem | null): YearMonthDayCalendar {
    return YearMonthDayCalendar.NewYearMonthDayCalendarOrdinal(this._value, calendar?.Ordinal ?? 0);
  }

  WithCalendarOrdinal(calendarOrdinal: CalendarOrdinal): YearMonthDayCalendar {
    return YearMonthDayCalendar.NewYearMonthDayCalendarOrdinal(this._value, calendarOrdinal);
  }

  /**
   * noda-js: C# only has `IComparable<YearMonthDay>` here (no non-generic `CompareTo(object)`), but this
   * follows the same contract as the other comparable types: null compares less than any value, and
   * anything else that isn't a {@link YearMonthDay} throws ArgumentError.
   */
  CompareTo(other: YearMonthDay | null): number;
  /** @inheritDoc */
  CompareTo(other: unknown): number;
  CompareTo(other: unknown): number {
    if (other === null || other === undefined) {
      return 1;
    }
    Preconditions.CheckArgument(other instanceof YearMonthDay, "obj", "Object must be of type NodaTime.YearMonthDay.");
    const that = other as YearMonthDay;
    return this._value < that._value ? -1 : this._value > that._value ? 1 : 0;
  }

  /** noda-js: covers both `IEquatable<YearMonthDay>.Equals(YearMonthDay)` and `object.Equals(object)`. */
  Equals(other: YearMonthDay): boolean;
  /** @inheritDoc */
  Equals(other: unknown): boolean;
  Equals(other: unknown): boolean {
    return other instanceof YearMonthDay && this._value === other._value;
  }

  // Not ported: GetHashCode (omitted, as per the porting conventions)
  // Operators ==, !=, <, <=, >, >= are covered by equals() and compareTo().

  valueOf(): never {
    return ThrowValueOf("YearMonthDay");
  }
}

/**
 * Equivalent of formatting with a .NET custom numeric format of `width` zeroes ("0000"):
 * at least `width` digits, with a leading "-" for negative values.
 */
function FormatPadded(value: number, width: number): string {
  return (value < 0 ? "-" : "") + PadStart(Math.abs(value).toString(), width, "0");
}
