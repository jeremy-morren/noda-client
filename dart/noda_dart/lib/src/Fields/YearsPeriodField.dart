// Ported from NodaTime 6e024dde: src/NodaTime/Fields/YearsPeriodField.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import '../LocalDate.dart';
import '../Utility/Preconditions.dart';
import '../YearMonthDay.dart';
import 'IDatePeriodField.dart';

/// Period field which uses a [YearMonthDayCalculator] to add/subtract years.
@internal
final class YearsPeriodField implements IDatePeriodField {
  YearsPeriodField.New();

  @override
  LocalDate Add(LocalDate localDate, int value) {
    if (value == 0) {
      return localDate;
    }
    YearMonthDay yearMonthDay = localDate.YearMonthDay;
    var calendar = localDate.Calendar;
    var calculator = calendar.YearMonthDayCalculator;
    int currentYear = yearMonthDay.Year;
    // Adjust argument range based on current year
    Preconditions.CheckArgumentRange('value', value, calculator.MinYear - currentYear, calculator.MaxYear - currentYear);
    return LocalDate.NewYearMonthDayCalendar(
        calculator.SetYear(yearMonthDay, currentYear + value).WithCalendarOrdinal(calendar.Ordinal));
  }

  @override
  int UnitsBetween(LocalDate start, LocalDate end) {
    int diff = end.Year - start.Year;

    // If we just add the difference in years to subtrahendInstant, what do we get?
    LocalDate simpleAddition = Add(start, diff);

    if (start <= end) {
      // Moving forward: if the result of the simple addition is before or equal to the end,
      // we're done. Otherwise, rewind a year because we've overshot.
      return simpleAddition <= end ? diff : diff - 1;
    } else {
      // Moving backward: if the result of the simple addition (of a non-positive number)
      // is after or equal to the end, we're done. Otherwise, increment by a year because
      // we've overshot backwards.
      return simpleAddition >= end ? diff : diff + 1;
    }
  }
}
