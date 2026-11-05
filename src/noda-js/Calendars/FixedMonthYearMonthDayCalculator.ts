// Ported from NodaTime 3.3.0: src/NodaTime/Calendars/FixedMonthYearMonthDayCalculator.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { RegularYearMonthDayCalculator, YearMonthDay } from "../internal.ts";

const DaysInMonth = 30;

const AverageDaysPer10Years = 3653; // Ideally 365.25 days per year...

/**
 * Abstract implementation of a year/month/day calculator based around months which always have 30 days.
 *
 * As the month length is fixed various calculations can be optimised.
 * This implementation assumes any additional days after twelve
 * months fall into a thirteenth month.
 * @internal
 */
export abstract class FixedMonthYearMonthDayCalculator extends RegularYearMonthDayCalculator {
  protected constructor(minYear: number, maxYear: number, daysAtStartOfYear1: number) {
    super(minYear, maxYear, 13, AverageDaysPer10Years, daysAtStartOfYear1);
  }

  /** @inheritDoc */
  override GetDaysSinceEpoch(yearMonthDay: YearMonthDay): number {
    // Just inline the arithmetic that would be done via various methods.
    return this.GetStartOfYearInDays(yearMonthDay.Year)
      + (yearMonthDay.Month - 1) * DaysInMonth
      + (yearMonthDay.Day - 1);
  }

  /** @inheritDoc */
  protected override GetDaysFromStartOfYearToStartOfMonth(year: number, month: number): number {
    void year;
    return (month - 1) * DaysInMonth;
  }

  override IsLeapYear(year: number): boolean {
    return (year & 3) === 3;
  }

  /** @inheritDoc */
  override GetDaysInYear(year: number): number {
    return this.IsLeapYear(year) ? 366 : 365;
  }

  override GetDaysInMonth(year: number, month: number): number {
    return month !== 13 ? DaysInMonth : this.IsLeapYear(year) ? 6 : 5;
  }

  /** @inheritDoc */
  protected override GetYearMonthDayFromYearAndDayOfYear(year: number, dayOfYear: number): YearMonthDay {
    const zeroBasedDayOfYear = dayOfYear - 1;
    const month = Math.trunc(zeroBasedDayOfYear / DaysInMonth) + 1;
    const day = (zeroBasedDayOfYear % DaysInMonth) + 1;
    return YearMonthDay.NewYearMonthDay(year, month, day);
  }
}
