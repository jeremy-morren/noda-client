// Ported from NodaTime 6e024dde: src/NodaTime/Calendars/FixedMonthYearMonthDayCalculator.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import '../YearMonthDay.dart';
import 'RegularYearMonthDayCalculator.dart';

/// Abstract implementation of a year/month/day calculator based around months which always have 30 days.
///
/// As the month length is fixed various calculations can be optimised.
/// This implementation assumes any additional days after twelve
/// months fall into a thirteenth month.
@internal
abstract class FixedMonthYearMonthDayCalculator extends RegularYearMonthDayCalculator {
  static const int _DaysInMonth = 30;

  static const int _AverageDaysPer10Years = 3653; // Ideally 365.25 days per year...

  FixedMonthYearMonthDayCalculator.NewMinYearMaxYearDaysAtStartOfYear1(int minYear, int maxYear, int daysAtStartOfYear1)
      : super.NewMinYearMaxYearMonthsInYearAverageDaysPer10YearsDaysAtStartOfYear1(
            minYear, maxYear, 13, _AverageDaysPer10Years, daysAtStartOfYear1);

  @override
  int GetDaysSinceEpoch(YearMonthDay yearMonthDay) =>
      // Just inline the arithmetic that would be done via various methods.
      GetStartOfYearInDays(yearMonthDay.Year) + (yearMonthDay.Month - 1) * _DaysInMonth + (yearMonthDay.Day - 1);

  @override
  int GetDaysFromStartOfYearToStartOfMonth(int year, int month) => (month - 1) * _DaysInMonth;

  @override
  bool IsLeapYear(int year) => (year & 3) == 3;

  @override
  int GetDaysInYear(int year) => IsLeapYear(year) ? 366 : 365;

  @override
  int GetDaysInMonth(int year, int month) => month != 13
      ? _DaysInMonth
      : IsLeapYear(year)
          ? 6
          : 5;

  @override
  YearMonthDay GetYearMonthDay(int year, int dayOfYear) {
    int zeroBasedDayOfYear = dayOfYear - 1;
    int month = zeroBasedDayOfYear ~/ _DaysInMonth + 1;
    int day = zeroBasedDayOfYear.remainder(_DaysInMonth) + 1;
    return YearMonthDay.NewYearMonthDay(year, month, day);
  }
}
