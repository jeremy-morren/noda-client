// Ported from NodaTime 3.3.0: src/NodaTime/Fields/YearsPeriodField.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { LocalDate, Preconditions, type IDatePeriodField } from "../internal.ts";
import type { YearMonthDayCalculator } from "../internal.ts";

/**
 * Period field which uses a {@link YearMonthDayCalculator} to add/subtract years.
 * @internal
 */
export class YearsPeriodField implements IDatePeriodField {
  private constructor() {}

  /** C#: `internal YearsPeriodField()` */
  static New(): YearsPeriodField {
    return new YearsPeriodField();
  }

  /** @inheritDoc */
  Add(localDate: LocalDate, value: number): LocalDate {
    if (value === 0) {
      return localDate;
    }
    const yearMonthDay = localDate.YearMonthDay;
    const calendar = localDate.Calendar;
    const calculator = calendar.YearMonthDayCalculator;
    const currentYear = yearMonthDay.Year;
    // Adjust argument range based on current year
    Preconditions.CheckArgumentRange("value", value, calculator.MinYear - currentYear, calculator.MaxYear - currentYear);
    return LocalDate.NewYearMonthDayCalendar(calculator.SetYear(yearMonthDay, currentYear + value).WithCalendarOrdinal(calendar.Ordinal));
  }

  /** @inheritDoc */
  UnitsBetween(start: LocalDate, end: LocalDate): number {
    const diff = end.Year - start.Year;

    // If we just add the difference in years to subtrahendInstant, what do we get?
    const simpleAddition = this.Add(start, diff);

    if (start.CompareTo(end) <= 0) {
      // Moving forward: if the result of the simple addition is before or equal to the end,
      // we're done. Otherwise, rewind a year because we've overshot.
      return simpleAddition.CompareTo(end) <= 0 ? diff : diff - 1;
    } else {
      // Moving backward: if the result of the simple addition (of a non-positive number)
      // is after or equal to the end, we're done. Otherwise, increment by a year because
      // we've overshot backwards.
      return simpleAddition.CompareTo(end) >= 0 ? diff : diff + 1;
    }
  }
}
