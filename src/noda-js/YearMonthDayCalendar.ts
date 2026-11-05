// Ported from NodaTime 3.3.7: src/NodaTime/YearMonthDayCalendar.cs
// Copyright 2014 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { CalendarOrdinal, YearMonthDay, PadStart, ThrowValueOf, type IEquatable } from "./internal.ts";
import { NewArgumentException } from "./internal.ts";

// These constants are internal so they can be used in YearMonthDay
const CalendarBits = 6; // Up to 64 calendars.
const DayBits = 6;   // Up to 64 days in a month.
const MonthBits = 5; // Up to 32 months per year.
const YearBits = 15; // 32K range; only need -10K to +10K.

// Just handy constants to use for shifting and masking.
const CalendarDayBits = CalendarBits + DayBits;
const CalendarDayMonthBits = CalendarDayBits + MonthBits;

const CalendarMask = (1 << CalendarBits) - 1;
const DayMask = ((1 << DayBits) - 1) << CalendarBits;
const MonthMask = ((1 << MonthBits) - 1) << CalendarDayBits;
const YearMask = ((1 << YearBits) - 1) << CalendarDayMonthBits;

/**
 * A compact representation of a year, month and day and calendar ordinal (integer ID) in a single 32-bit integer.
 *
 * The calendar is represented in bits 0-5.
 * The day is represented in bits 6-11.
 * The month is represented in bits 12-16.
 * The year is represented in bits 17-31. (It's convenient to put this at the top as it can be negative.)
 *
 * This type does not implement IComparable[YearMonthDayCalendar] as it turns out it doesn't need to:
 * comparisons are always done through the calendar system, which uses YearMonthDay instead. We could potentially
 * optimize by bypassing the calendar and embedding knowledge of calendars which have "odd" month numberings
 * in here, but it would be a bit of a design smell.
 *
 * Equality is easily tested, however, as it can check for calendar equality.
 *
 * The internal representation actually uses 0 for 1 (etc) for each component.
 * That means the default value is 0001-01-01, which is reasonable for all
 * supported calendars.
 * @internal
 */
export class YearMonthDayCalendar implements IEquatable<YearMonthDayCalendar> {
  // These constants are internal so they can be used in YearMonthDay
  static readonly CalendarBits = CalendarBits;
  static readonly DayBits = DayBits;
  static readonly MonthBits = MonthBits;
  static readonly YearBits = YearBits;

  private readonly _value: number;

  private constructor(value: number) {
    this._value = value;
  }

  /**
   * C#: `internal YearMonthDayCalendar(int yearMonthDay, CalendarOrdinal calendarOrdinal)` and
   * `internal YearMonthDayCalendar(int year, int month, int day, CalendarOrdinal calendarOrdinal)`
   * (which constructs a new value for the given year, month, day and calendar; no validation is performed).
   * Both C# constructors map to this name, so they're told apart by the number of arguments.
   */
  static NewYearMonthDayCalendarOrdinal(yearMonthDay: number, calendarOrdinal: CalendarOrdinal): YearMonthDayCalendar;
  static NewYearMonthDayCalendarOrdinal(year: number, month: number, day: number, calendarOrdinal: CalendarOrdinal): YearMonthDayCalendar;
  static NewYearMonthDayCalendarOrdinal(a: number, b: number, day?: number, calendarOrdinal?: CalendarOrdinal): YearMonthDayCalendar {
    if (day === undefined) {
      return new YearMonthDayCalendar((a << CalendarBits) | b);
    }
    // unchecked
    return new YearMonthDayCalendar(((a - 1) << CalendarDayMonthBits) |
      ((b - 1) << CalendarDayBits) |
      ((day - 1) << CalendarBits) |
      calendarOrdinal!);
  }

  get CalendarOrdinal(): CalendarOrdinal {
    return (this._value & CalendarMask) as CalendarOrdinal;
  }

  get Year(): number {
    return ((this._value & YearMask) >> CalendarDayMonthBits) + 1;
  }

  get Month(): number {
    return ((this._value & MonthMask) >> CalendarDayBits) + 1;
  }

  get Day(): number {
    return ((this._value & DayMask) >> CalendarBits) + 1;
  }

  // Just for testing purposes... note that this does not perform clean validation.
  static Parse(text: string): YearMonthDayCalendar {
    // Handle a leading - to negate the year
    if (text[0] === "-") {
      const ymdc = YearMonthDayCalendar.Parse(text.substring(1));
      return YearMonthDayCalendar.NewYearMonthDayCalendarOrdinal(-ymdc.Year, ymdc.Month, ymdc.Day, ymdc.CalendarOrdinal);
    }

    const bits = text.split("-");
    const ordinal = CalendarOrdinal[bits[3] as keyof typeof CalendarOrdinal];
    if (ordinal === undefined) {
      throw NewArgumentException(`Requested value '${bits[3]}' was not found.`);
    }
    return YearMonthDayCalendar.NewYearMonthDayCalendarOrdinal(
      Number.parseInt(bits[0]!, 10),
      Number.parseInt(bits[1]!, 10),
      Number.parseInt(bits[2]!, 10),
      ordinal);
  }

  ToYearMonthDay(): YearMonthDay {
    return YearMonthDay.NewRawValue(this._value >> CalendarBits);
  }

  toString(): string {
    return `${FormatPadded(this.Year, 4)}-${FormatPadded(this.Month, 2)}-${FormatPadded(this.Day, 2)}-${CalendarOrdinal[this.CalendarOrdinal]}`;
  }

  /** noda-js: covers both `IEquatable<YearMonthDayCalendar>.Equals(YearMonthDayCalendar)` and `object.Equals(object)`. */
  Equals(other: YearMonthDayCalendar): boolean;
  /** @inheritDoc */
  Equals(other: unknown): boolean;
  Equals(other: unknown): boolean {
    return other instanceof YearMonthDayCalendar && this._value === other._value;
  }

  // Not ported: GetHashCode (omitted, as per the porting conventions)
  // Operators == and != are covered by Equals().

  valueOf(): never {
    return ThrowValueOf("YearMonthDayCalendar");
  }
}

/**
 * Equivalent of formatting with a .NET custom numeric format of `width` zeroes ("0000"):
 * at least `width` digits, with a leading "-" for negative values.
 */
function FormatPadded(value: number, width: number): string {
  return (value < 0 ? "-" : "") + PadStart(Math.abs(value).toString(), width, "0");
}
