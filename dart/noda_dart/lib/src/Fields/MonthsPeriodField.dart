// Ported from NodaTime 6e024dde: src/NodaTime/Fields/MonthsPeriodField.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import '../LocalDate.dart';
import 'IDatePeriodField.dart';

/// Period field which uses a [YearMonthDayCalculator] to add/subtract months.
@internal
final class MonthsPeriodField implements IDatePeriodField {
  MonthsPeriodField.New();

  @override
  LocalDate Add(LocalDate localDate, int value) {
    var calendar = localDate.Calendar;
    var calculator = calendar.YearMonthDayCalculator;
    var yearMonthDay = calculator.AddMonths(localDate.YearMonthDay, value);
    return LocalDate.NewYearMonthDayCalendar(yearMonthDay.WithCalendar(calendar));
  }

  @override
  int UnitsBetween(LocalDate start, LocalDate end) =>
      start.Calendar.YearMonthDayCalculator.MonthsBetween(start.YearMonthDay, end.YearMonthDay);
}
