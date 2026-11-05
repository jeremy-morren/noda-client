// Ported from NodaTime 3.3.7: src/NodaTime/Fields/DatePeriodFields.cs
// Copyright 2014 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import {
  FixedLengthDatePeriodField,
  MonthsPeriodField,
  YearsPeriodField,
  type IDatePeriodField,
} from "../internal.ts";

let daysField: IDatePeriodField | undefined;
let weeksField: IDatePeriodField | undefined;
let monthsField: IDatePeriodField | undefined;
let yearsField: IDatePeriodField | undefined;

/**
 * All the period fields.
 * @internal
 */
export class DatePeriodFields {
  private constructor() {}

  static get DaysField(): IDatePeriodField {
    return (daysField ??= FixedLengthDatePeriodField.NewUnitDays(1));
  }

  static get WeeksField(): IDatePeriodField {
    return (weeksField ??= FixedLengthDatePeriodField.NewUnitDays(7));
  }

  static get MonthsField(): IDatePeriodField {
    return (monthsField ??= MonthsPeriodField.New());
  }

  static get YearsField(): IDatePeriodField {
    return (yearsField ??= YearsPeriodField.New());
  }
}
