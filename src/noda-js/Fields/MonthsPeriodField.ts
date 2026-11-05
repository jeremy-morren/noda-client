// Ported from NodaTime 3.3.0: src/NodaTime/Fields/MonthsPeriodField.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { LocalDate, type IDatePeriodField } from "../internal.ts";
import type { YearMonthDayCalculator } from "../internal.ts";

/**
 * Period field which uses a {@link YearMonthDayCalculator} to add/subtract months.
 * @internal
 */
export class MonthsPeriodField implements IDatePeriodField {
  private constructor() {}

  /** C#: `internal MonthsPeriodField()` */
  static New(): MonthsPeriodField {
    return new MonthsPeriodField();
  }

  /** @inheritDoc */
  Add(localDate: LocalDate, value: number): LocalDate {
    const calendar = localDate.Calendar;
    const calculator = calendar.YearMonthDayCalculator;
    const yearMonthDay = calculator.AddMonths(localDate.YearMonthDay, value);
    return LocalDate.NewYearMonthDayCalendar(yearMonthDay.WithCalendar(calendar));
  }

  /** @inheritDoc */
  UnitsBetween(start: LocalDate, end: LocalDate): number {
    return start.Calendar.YearMonthDayCalculator.MonthsBetween(start.YearMonthDay, end.YearMonthDay);
  }
}
