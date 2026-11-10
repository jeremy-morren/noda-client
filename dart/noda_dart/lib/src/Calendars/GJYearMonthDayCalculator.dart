// Ported from NodaTime 6e024dde: src/NodaTime/Calendars/GJYearMonthDayCalculator.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import '../YearMonthDay.dart';
import 'RegularYearMonthDayCalculator.dart';

@internal
abstract class GJYearMonthDayCalculator extends RegularYearMonthDayCalculator {
  // These arrays are NOT public. We trust ourselves not to alter the array.
  // They are protected so that GregorianYearMonthDayCalculator can read them.
  // The arrays are 1-based (so "days in January" are accessed via array[1]); the index should be validated before
  // use.
  static const List<int> NonLeapDaysPerMonth = [0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
  static const List<int> LeapDaysPerMonth = [0, 31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];

  // Note: these fields must be declared after NonLeapDaysPerMonth and LeapDaysPerMonth so that the initialization
  // is correct. This behavior (textual order for initialization) is guaranteed by the spec. We'd normally
  // try to avoid relying on it, but that's quite hard here.
  static final List<int> _NonLeapTotalDaysByMonth = _GenerateTotalDaysByMonth(NonLeapDaysPerMonth);
  static final List<int> _LeapTotalDaysByMonth = _GenerateTotalDaysByMonth(LeapDaysPerMonth);

  /// Produces an array with "the sum of the elements of [monthLengths] before the corresponding index".
  /// So for an input of [0, 1, 2, 3, 4, 5] this would produce [0, 0, 1, 3, 6, 10].
  static List<int> _GenerateTotalDaysByMonth(List<int> monthLengths) {
    List<int> ret = List<int>.filled(monthLengths.length, 0);
    for (int i = 0; i < ret.length - 1; i++) {
      ret[i + 1] = ret[i] + monthLengths[i];
    }
    return ret;
  }

  GJYearMonthDayCalculator.NewMinYearMaxYearAverageDaysPer10YearsDaysAtStartOfYear1(int minYear, int maxYear,
      int averageDaysPer10Years, int daysAtStartOfYear1)
      : super.NewMinYearMaxYearMonthsInYearAverageDaysPer10YearsDaysAtStartOfYear1(
            minYear, maxYear, 12, averageDaysPer10Years, daysAtStartOfYear1);

  // Note: parameter is renamed to d for brevity. It's still the 1-based day-of-year
  @override
  YearMonthDay GetYearMonthDay(int year, int d) {
    bool isLeap = IsLeapYear(year);

    int startOfMonth;
    // Perform a hard-coded binary search to get the 0-based start day of the month. We can
    // then use that to work out the month... without ever hitting the heap. The values
    // are still MinTotalDaysPerMonth and MaxTotalDaysPerMonth (-1 for convenience), just hard-coded.
    if (isLeap) {
      startOfMonth = ((d < 183)
          ? ((d < 92) ? ((d < 32) ? 0 : (d < 61) ? 31 : 60) : ((d < 122) ? 91 : (d < 153) ? 121 : 152))
          : ((d < 275)
              ? ((d < 214) ? 182 : (d < 245) ? 213 : 244)
              : ((d < 306) ? 274 : (d < 336) ? 305 : 335)));
    } else {
      startOfMonth = ((d < 182)
          ? ((d < 91) ? ((d < 32) ? 0 : (d < 60) ? 31 : 59) : ((d < 121) ? 90 : (d < 152) ? 120 : 151))
          : ((d < 274)
              ? ((d < 213) ? 181 : (d < 244) ? 212 : 243)
              : ((d < 305) ? 273 : (d < 335) ? 304 : 334)));
    }

    int dayOfMonth = d - startOfMonth;
    return YearMonthDay.NewYearMonthDay(year, (startOfMonth ~/ 29) + 1, dayOfMonth);
  }

  @override
  int GetDaysInYear(int year) => IsLeapYear(year) ? 366 : 365;

  // C#: sealed override.
  @override
  int GetDaysInMonth(int year, int month) =>
      // February is awkward
      month == 2
          ? IsLeapYear(year)
              ? 29
              : 28
          // The lengths of months alternate between 30 and 31, but skip a beat for August.
          // By dividing the month by 8, we effectively handle that skip.
          : 30 + ((month + (month >> 3)) & 1);

  @override
  int GetDaysFromStartOfYearToStartOfMonth(int year, int month) =>
      IsLeapYear(year) ? _LeapTotalDaysByMonth[month] : _NonLeapTotalDaysByMonth[month];
}
