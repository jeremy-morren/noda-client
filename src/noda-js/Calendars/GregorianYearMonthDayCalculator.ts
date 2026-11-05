// Ported from NodaTime 3.3.7: src/NodaTime/Calendars/GregorianYearMonthDayCalculator.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import {
  CalendarOrdinal,
  CalendarSystem,
  GJYearMonthDayCalculator,
  Preconditions,
  YearMonthDayCalendar,
  type YearMonthDay,
} from "../internal.ts";

const MinGregorianYear = -9998;
const MaxGregorianYear = 9999;

// We precompute useful values for each month between these years, as we anticipate most
// dates will be in this range.
const FirstOptimizedYear = 1900;
const LastOptimizedYear = 2100;
const FirstOptimizedDay = -25567;
const LastOptimizedDay = 47846;
// The 0-based days-since-unix-epoch for the start of each month
let MonthStartDays: number[] | undefined;
// The 1-based days-since-unix-epoch for the start of each year
let YearStartDays: number[] | undefined;

const DaysFrom0000To1970 = 719527;
const AverageDaysPer10Years = 3652; // Ideally 365.2425 per year...

/** @internal */
export class GregorianYearMonthDayCalculator extends GJYearMonthDayCalculator {
  static readonly MinGregorianYear = MinGregorianYear;
  static readonly MaxGregorianYear = MaxGregorianYear;

  // C#: static constructor. Run lazily (on first use of the tables), as module evaluation mustn't
  // depend on other modules.
  private static InitializeTables(): void {
    MonthStartDays = new Array<number>((LastOptimizedYear + 1 - FirstOptimizedYear) * 12 + 1).fill(0);
    YearStartDays = new Array<number>(LastOptimizedYear + 1 - FirstOptimizedYear).fill(0);
    // It's generally a really bad idea to create an instance before the static initializer
    // has completed, but we know its safe because we're only using a very restricted set of methods.
    const instance = new GregorianYearMonthDayCalculator();
    for (let year = FirstOptimizedYear; year <= LastOptimizedYear; year++) {
      const yearStart = instance.CalculateStartOfYearDays(year);
      YearStartDays[year - FirstOptimizedYear] = yearStart;
      let monthStartDay = yearStart - 1; // See field description
      let yearMonthIndex = (year - FirstOptimizedYear) * 12;
      for (let month = 1; month <= 12; month++) {
        yearMonthIndex++;
        const monthLength = instance.GetDaysInMonth(year, month);
        MonthStartDays[yearMonthIndex] = monthStartDay;
        monthStartDay += monthLength;
      }
    }
  }

  private static get YearStartDays(): number[] {
    if (YearStartDays === undefined) {
      GregorianYearMonthDayCalculator.InitializeTables();
    }
    return YearStartDays!;
  }

  private static get MonthStartDays(): number[] {
    if (MonthStartDays === undefined) {
      GregorianYearMonthDayCalculator.InitializeTables();
    }
    return MonthStartDays!;
  }

  /**
   * Specifically Gregorian-optimized conversion from "days since epoch" to year/month/day.
   */
  static GetGregorianYearMonthDayCalendarFromDaysSinceEpoch(daysSinceEpoch: number): YearMonthDayCalendar {
    // unchecked
    if (daysSinceEpoch < FirstOptimizedDay || daysSinceEpoch > LastOptimizedDay) {
      return CalendarSystem.Iso.GetYearMonthDayCalendarFromDaysSinceEpoch(daysSinceEpoch);
    }
    // Divide by more than we need to, in order to guarantee that we only need to move forward.
    // We can still only be out by 1 year.
    const yearIndex = Math.trunc((daysSinceEpoch - FirstOptimizedDay) / 366);
    const indexValue = GregorianYearMonthDayCalculator.YearStartDays[yearIndex]!;
    // Zero-based day of year
    let d = daysSinceEpoch - indexValue;
    let year = yearIndex + FirstOptimizedYear;
    let isLeap = IsGregorianLeapYear(year);
    const daysInYear = isLeap ? 366 : 365;
    if (d >= daysInYear) {
      year++;
      d -= daysInYear;
      isLeap = IsGregorianLeapYear(year);
    }

    // The remaining code is copied from GJYearMonthDayCalculator (and tweaked)

    let startOfMonth: number;
    // Perform a hard-coded binary search to get the month.
    if (isLeap) {
      startOfMonth = ((d < 182)
        ? ((d < 91) ? ((d < 31) ? -1 : (d < 60) ? 30 : 59) : ((d < 121) ? 90 : (d < 152) ? 120 : 151))
        : ((d < 274)
          ? ((d < 213) ? 181 : (d < 244) ? 212 : 243)
          : ((d < 305) ? 273 : (d < 335) ? 304 : 334)));
    } else {
      startOfMonth = ((d < 181)
        ? ((d < 90) ? ((d < 31) ? -1 : (d < 59) ? 30 : 58) : ((d < 120) ? 89 : (d < 151) ? 119 : 150))
        : ((d < 273)
          ? ((d < 212) ? 180 : (d < 243) ? 211 : 242)
          : ((d < 304) ? 272 : (d < 334) ? 303 : 333)));
    }
    const month = Math.trunc(startOfMonth / 29) + 1;
    const dayOfMonth = d - startOfMonth;
    return YearMonthDayCalendar.NewYearMonthDayCalendarOrdinal(year, month, dayOfMonth, CalendarOrdinal.Iso);
  }

  private constructor() {
    super(MinGregorianYear, MaxGregorianYear, AverageDaysPer10Years, -719162);
  }

  /** C#: `internal GregorianYearMonthDayCalculator()` */
  static New(): GregorianYearMonthDayCalculator {
    return new GregorianYearMonthDayCalculator();
  }

  /** @inheritDoc */
  override GetStartOfYearInDays(year: number): number {
    // 2014-06-28: Tried removing this entirely (optimized: 5ns => 8ns; unoptimized: 11ns => 8ns)
    // Decided to leave it in, as the optimized case is so much more common.
    if (year < FirstOptimizedYear || year > LastOptimizedYear) {
      return super.GetStartOfYearInDays(year);
    }
    return GregorianYearMonthDayCalculator.YearStartDays[year - FirstOptimizedYear]!;
  }

  /** @inheritDoc */
  override GetDaysSinceEpoch(yearMonthDay: YearMonthDay): number {
    // 2014-06-28: Tried removing this entirely (optimized: 8ns => 13ns; unoptimized: 23ns => 19ns)
    // Also tried computing everything lazily - it's a wash.
    // Removed validation, however - we assume that the parameter is already valid by now.
    // unchecked
    const year = yearMonthDay.Year;
    const monthOfYear = yearMonthDay.Month;
    const dayOfMonth = yearMonthDay.Day;
    if (year < FirstOptimizedYear || year > LastOptimizedYear - 1) {
      return super.GetDaysSinceEpoch(yearMonthDay);
    }
    const yearMonthIndex = (year - FirstOptimizedYear) * 12 + monthOfYear;
    return GregorianYearMonthDayCalculator.MonthStartDays[yearMonthIndex]! + dayOfMonth;
  }

  override ValidateYearMonthDay(year: number, month: number, day: number): void {
    GregorianYearMonthDayCalculator.ValidateGregorianYearMonthDay(year, month, day);
  }

  static ValidateGregorianYearMonthDay(year: number, month: number, day: number): void {
    // Perform quick validation without calling Preconditions, then do it properly if we're going to throw
    // an exception. Avoiding the method call is pretty extreme, but it does help.
    if (year < MinGregorianYear || year > MaxGregorianYear || month < 1 || month > 12) {
      Preconditions.CheckArgumentRange("year", year, MinGregorianYear, MaxGregorianYear);
      Preconditions.CheckArgumentRange("month", month, 1, 12);
    }
    // If we've been asked for day 1-28, we're definitely okay regardless of month.
    if (day >= 1 && day <= 28) {
      return;
    }
    const daysInMonth = month === 2 && IsGregorianLeapYear(year)
      ? GJYearMonthDayCalculator.LeapDaysPerMonth[month]!
      : GJYearMonthDayCalculator.NonLeapDaysPerMonth[month]!;
    if (day < 1 || day > daysInMonth) {
      Preconditions.CheckArgumentRange("day", day, 1, daysInMonth);
    }
  }

  /** @inheritDoc */
  protected override CalculateStartOfYearDays(year: number): number {
    // Initial value is just temporary.
    let leapYears = Math.trunc(year / 100);
    if (year < 0) {
      // Add 3 before shifting right since /4 and >>2 behave differently
      // on negative numbers. When the expression is written as
      // (year / 4) - (year / 100) + (year / 400),
      // it works for both positive and negative values, except this optimization
      // eliminates two divisions.
      leapYears = ((year + 3) >> 2) - leapYears + ((leapYears + 3) >> 2) - 1;
    } else {
      leapYears = (year >> 2) - leapYears + (leapYears >> 2);
      if (this.IsLeapYear(year)) {
        leapYears--;
      }
    }

    return year * 365 + (leapYears - DaysFrom0000To1970);
  }

  // Override GetDaysInYear so we can avoid a pointless virtual method call.
  /** @inheritDoc */
  override GetDaysInYear(year: number): number {
    return IsGregorianLeapYear(year) ? 366 : 365;
  }

  override IsLeapYear(year: number): boolean {
    return IsGregorianLeapYear(year);
  }
}

// C#: private static bool IsGregorianLeapYear(int year)
function IsGregorianLeapYear(year: number): boolean {
  return ((year & 3) === 0) && ((year % 100) !== 0 || (year % 400) === 0);
}
