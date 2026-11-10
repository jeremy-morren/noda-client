// Ported from NodaTime 3.3.7: src/NodaTime/Calendars/RegularYearMonthDayCalculator.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { YearMonthDay, YearMonthDayCalculator } from "../internal.ts";
import { NewOverflowException } from "../internal.ts";

/**
 * Subclass of YearMonthDayCalculator for calendars with the following attributes:
 * - A fixed number of months
 * - Occasional leap years which are always 1 day longer than non-leap years
 * - The year starting with month 1, day 1 (i.e. naive YearMonthDay comparisons work)
 * @internal
 */
export abstract class RegularYearMonthDayCalculator extends YearMonthDayCalculator {
  private readonly _monthsInYear: number;

  protected constructor(minYear: number, maxYear: number, monthsInYear: number,
    averageDaysPer10Years: number, daysAtStartOfYear1: number) {
    super(minYear, maxYear, averageDaysPer10Years, daysAtStartOfYear1);
    this._monthsInYear = monthsInYear;
  }

  override GetMonthsInYear(year: number): number {
    void year;
    return this._monthsInYear;
  }

  /**
   * Implements a simple year-setting policy, truncating the day
   * if necessary.
   */
  override SetYear(yearMonthDay: YearMonthDay, year: number): YearMonthDay {
    // If this ever becomes a bottleneck due to GetDaysInMonth, it can be overridden
    // in subclasses.
    const currentMonth = yearMonthDay.Month;
    const currentDay = yearMonthDay.Day;
    const newDay = this.GetDaysInMonth(year, currentMonth);
    return YearMonthDay.NewYearMonthDay(year, currentMonth, Math.min(currentDay, newDay));
  }

  override AddMonths(yearMonthDay: YearMonthDay, months: number): YearMonthDay {
    if (months === 0) {
      return yearMonthDay;
    }
    // Get the year and month
    const thisYear = yearMonthDay.Year;
    const thisMonth = yearMonthDay.Month;

    // Do not refactor without careful consideration.
    // Order of calculation is important.

    let yearToUse: number;
    // Initially, monthToUse is zero-based
    let monthToUse = thisMonth - 1 + months;
    if (monthToUse >= 0) {
      yearToUse = thisYear + Math.trunc(monthToUse / this._monthsInYear);
      monthToUse = (monthToUse % this._monthsInYear) + 1;
    } else {
      yearToUse = thisYear + Math.trunc(monthToUse / this._monthsInYear) - 1;
      monthToUse = Math.abs(monthToUse);
      let remMonthToUse = monthToUse % this._monthsInYear;
      // Take care of the boundary condition
      if (remMonthToUse === 0) {
        remMonthToUse = this._monthsInYear;
      }
      monthToUse = this._monthsInYear - remMonthToUse + 1;
      // Take care of the boundary condition
      if (monthToUse === 1) {
        yearToUse++;
      }
    }
    // End of do not refactor.

    // Quietly force DOM to nearest sane value.
    let dayToUse = yearMonthDay.Day;
    if (yearToUse < this.MinYear || yearToUse > this.MaxYear) {
      throw NewOverflowException("Date computation would overflow calendar bounds.");
    }
    const maxDay = this.GetDaysInMonth(yearToUse, monthToUse);
    dayToUse = Math.min(dayToUse, maxDay);
    return YearMonthDay.NewYearMonthDay(yearToUse, monthToUse, dayToUse);
  }

  /** @inheritDoc */
  override MonthsBetween(start: YearMonthDay, end: YearMonthDay): number {
    const startMonth = start.Month;
    const startYear = start.Year;
    const endMonth = end.Month;
    const endYear = end.Year;

    const diff = (endYear - startYear) * this._monthsInYear + endMonth - startMonth;

    // If we just add the difference in months to start, what do we get?
    const simpleAddition = this.AddMonths(start, diff);

    // Note: this relies on naive comparison of year/month/date values.
    if (start.CompareTo(end) <= 0) {
      // Moving forward: if the result of the simple addition is before or equal to the end,
      // we're done. Otherwise, rewind a month because we've overshot.
      return simpleAddition.CompareTo(end) <= 0 ? diff : diff - 1;
    } else {
      // Moving backward: if the result of the simple addition (of a non-positive number)
      // is after or equal to the end, we're done. Otherwise, increment by a month because
      // we've overshot backwards.
      return simpleAddition.CompareTo(end) >= 0 ? diff : diff + 1;
    }
  }
}
