// Ported from NodaTime 6e024dde: src/NodaTime/Calendars/RegularYearMonthDayCalculator.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'dart:math' as math;

import 'package:meta/meta.dart';

import '../Utility/SystemExceptions.dart';
import '../YearMonthDay.dart';
import 'YearMonthDayCalculator.dart';

/// Subclass of YearMonthDayCalculator for calendars with the following attributes:
/// - A fixed number of months
/// - Occasional leap years which are always 1 day longer than non-leap years
/// - The year starting with month 1, day 1 (i.e. naive YearMonthDay comparisons work)
@internal
abstract class RegularYearMonthDayCalculator extends YearMonthDayCalculator {
  final int _monthsInYear;

  RegularYearMonthDayCalculator.NewMinYearMaxYearMonthsInYearAverageDaysPer10YearsDaysAtStartOfYear1(super.minYear,
      super.maxYear, int monthsInYear, super.averageDaysPer10Years, super.daysAtStartOfYear1)
      : _monthsInYear = monthsInYear,
        super.NewMinYearMaxYearAverageDaysPer10YearsDaysAtStartOfYear1();

  @override
  int GetMonthsInYear(int year) => _monthsInYear;

  /// Implements a simple year-setting policy, truncating the day
  /// if necessary.
  @override
  YearMonthDay SetYear(YearMonthDay yearMonthDay, int year) {
    // If this ever becomes a bottleneck due to GetDaysInMonth, it can be overridden
    // in subclasses.
    int currentMonth = yearMonthDay.Month;
    int currentDay = yearMonthDay.Day;
    int newDay = GetDaysInMonth(year, currentMonth);
    return YearMonthDay.NewYearMonthDay(year, currentMonth, math.min(currentDay, newDay));
  }

  @override
  YearMonthDay AddMonths(YearMonthDay yearMonthDay, int months) {
    if (months == 0) {
      return yearMonthDay;
    }
    // Get the year and month
    int thisYear = yearMonthDay.Year;
    int thisMonth = yearMonthDay.Month;

    // Do not refactor without careful consideration.
    // Order of calculation is important.

    int yearToUse;
    // Initially, monthToUse is zero-based
    int monthToUse = thisMonth - 1 + months;
    if (monthToUse >= 0) {
      yearToUse = thisYear + (monthToUse ~/ _monthsInYear);
      monthToUse = (monthToUse % _monthsInYear) + 1;
    } else {
      yearToUse = thisYear + (monthToUse ~/ _monthsInYear) - 1;
      monthToUse = monthToUse.abs();
      int remMonthToUse = monthToUse % _monthsInYear;
      // Take care of the boundary condition
      if (remMonthToUse == 0) {
        remMonthToUse = _monthsInYear;
      }
      monthToUse = _monthsInYear - remMonthToUse + 1;
      // Take care of the boundary condition
      if (monthToUse == 1) {
        yearToUse++;
      }
    }
    // End of do not refactor.

    // Quietly force DOM to nearest sane value.
    int dayToUse = yearMonthDay.Day;
    if (yearToUse < MinYear || yearToUse > MaxYear) {
      throw OverflowException('Date computation would overflow calendar bounds.');
    }
    int maxDay = GetDaysInMonth(yearToUse, monthToUse);
    dayToUse = math.min(dayToUse, maxDay);
    return YearMonthDay.NewYearMonthDay(yearToUse, monthToUse, dayToUse);
  }

  @override
  int MonthsBetween(YearMonthDay start, YearMonthDay end) {
    int startMonth = start.Month;
    int startYear = start.Year;
    int endMonth = end.Month;
    int endYear = end.Year;

    int diff = (endYear - startYear) * _monthsInYear + endMonth - startMonth;

    // If we just add the difference in months to start, what do we get?
    YearMonthDay simpleAddition = AddMonths(start, diff);

    // Note: this relies on naive comparison of year/month/date values.
    if (start <= end) {
      // Moving forward: if the result of the simple addition is before or equal to the end,
      // we're done. Otherwise, rewind a month because we've overshot.
      return simpleAddition <= end ? diff : diff - 1;
    } else {
      // Moving backward: if the result of the simple addition (of a non-positive number)
      // is after or equal to the end, we're done. Otherwise, increment by a month because
      // we've overshot backwards.
      return simpleAddition >= end ? diff : diff + 1;
    }
  }
}
