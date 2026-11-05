// Ported from NodaTime 3.3.0: src/NodaTime/Fields/FixedLengthDatePeriodField.cs
// Copyright 2014 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import {
  Int32,
  LocalDate,
  OverflowError,
  Period,
  YearMonthDayCalendar,
  type IDatePeriodField,
} from "../internal.ts";

/**
 * Date period field for fixed-length periods (weeks and days).
 * @internal
 */
export class FixedLengthDatePeriodField implements IDatePeriodField {
  private readonly _unitDays: number;

  private constructor(unitDays: number) {
    this._unitDays = unitDays;
  }

  /** C#: `internal FixedLengthDatePeriodField(int unitDays)` */
  static NewUnitDays(unitDays: number): FixedLengthDatePeriodField {
    return new FixedLengthDatePeriodField(unitDays);
  }

  /** @inheritDoc */
  Add(localDate: LocalDate, value: number): LocalDate {
    if (value === 0) {
      return localDate;
    }
    const daysToAdd = Int32.Checked(value * this._unitDays);
    const calendar = localDate.Calendar;
    // If we know it will be in this year, next year, or the previous year...
    if (daysToAdd < 300 && daysToAdd > -300) {
      const calculator = calendar.YearMonthDayCalculator;
      const yearMonthDay = localDate.YearMonthDay;
      let year = yearMonthDay.Year;
      const month = yearMonthDay.Month;
      const day = yearMonthDay.Day;
      const newDayOfMonth = day + daysToAdd;
      if (1 <= newDayOfMonth && newDayOfMonth <= calculator.GetDaysInMonth(year, month)) {
        return LocalDate.NewYearMonthDayCalendar(YearMonthDayCalendar.NewYearMonthDayCalendarOrdinal(year, month, newDayOfMonth, calendar.Ordinal));
      }
      const dayOfYear = calculator.GetDayOfYear(yearMonthDay);
      let newDayOfYear = dayOfYear + daysToAdd;

      if (newDayOfYear < 1) {
        newDayOfYear += calculator.GetDaysInYear(year - 1);
        year--;
        if (year < calculator.MinYear) {
          throw new OverflowError("Date computation would underflow the minimum year of the calendar");
        }
      } else {
        const daysInYear = calculator.GetDaysInYear(year);
        if (newDayOfYear > daysInYear) {
          newDayOfYear -= daysInYear;
          year++;
          if (year > calculator.MaxYear) {
            throw new OverflowError("Date computation would overflow the maximum year of the calendar");
          }
        }
      }
      return LocalDate.NewYearMonthDayCalendar(calculator.GetYearMonthDay(year, newDayOfYear).WithCalendarOrdinal(calendar.Ordinal));
    }
    // LocalDate constructor will validate.
    const days = Int32.Checked(localDate.DaysSinceEpoch + daysToAdd);
    return LocalDate.NewDaysSinceEpochCalendar(days, calendar);
  }

  /** @inheritDoc */
  UnitsBetween(start: LocalDate, end: LocalDate): number {
    return Math.trunc(Period.InternalDaysBetween(start, end) / this._unitDays);
  }
}
