// Ported from NodaTime 6e024dde: src/NodaTime/Calendars/GregorianYearMonthDayCalculator.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import '../CalendarOrdinal.generated.dart';
import '../CalendarSystem.dart';
import '../Utility/Preconditions.dart';
import '../YearMonthDay.dart';
import '../YearMonthDayCalendar.dart';
import 'GJYearMonthDayCalculator.dart';

@internal
final class GregorianYearMonthDayCalculator extends GJYearMonthDayCalculator {
  static const int MinGregorianYear = -9998;
  static const int MaxGregorianYear = 9999;

  // We precompute useful values for each month between these years, as we anticipate most
  // dates will be in this range.
  static const int _FirstOptimizedYear = 1900;
  static const int _LastOptimizedYear = 2100;
  static const int _FirstOptimizedDay = -25567;
  static const int _LastOptimizedDay = 47846;
  // The 0-based days-since-unix-epoch for the start of each month
  static List<int> get _MonthStartDays => _StaticTables.$1;
  // The 1-based days-since-unix-epoch for the start of each year
  static List<int> get _YearStartDays => _StaticTables.$2;

  static const int _DaysFrom0000To1970 = 719527;
  static const int _AverageDaysPer10Years = 3652; // Ideally 365.2425 per year...

  // noda_dart: C#'s static constructor, run on first use of the tables.
  static final (List<int>, List<int>) _StaticTables = _StaticConstructor();

  static (List<int>, List<int>) _StaticConstructor() {
    final MonthStartDays = List<int>.filled((_LastOptimizedYear + 1 - _FirstOptimizedYear) * 12 + 1, 0);
    final YearStartDays = List<int>.filled(_LastOptimizedYear + 1 - _FirstOptimizedYear, 0);
    // It's generally a really bad idea to create an instance before the static initializer
    // has completed, but we know its safe because we're only using a very restricted set of methods.
    var instance = GregorianYearMonthDayCalculator.New();
    for (int year = _FirstOptimizedYear; year <= _LastOptimizedYear; year++) {
      int yearStart = instance.CalculateStartOfYearDays(year);
      YearStartDays[year - _FirstOptimizedYear] = yearStart;
      int monthStartDay = yearStart - 1; // See field description
      int yearMonthIndex = (year - _FirstOptimizedYear) * 12;
      for (int month = 1; month <= 12; month++) {
        yearMonthIndex++;
        int monthLength = instance.GetDaysInMonth(year, month);
        MonthStartDays[yearMonthIndex] = monthStartDay;
        monthStartDay += monthLength;
      }
    }
    return (MonthStartDays, YearStartDays);
  }

  /// Specifically Gregorian-optimized conversion from "days since epoch" to year/month/day.
  static YearMonthDayCalendar GetGregorianYearMonthDayCalendarFromDaysSinceEpoch(int daysSinceEpoch) {
    // unchecked
    if (daysSinceEpoch < _FirstOptimizedDay || daysSinceEpoch > _LastOptimizedDay) {
      return CalendarSystem.Iso.GetYearMonthDayCalendarFromDaysSinceEpoch(daysSinceEpoch);
    }
    // Divide by more than we need to, in order to guarantee that we only need to move forward.
    // We can still only be out by 1 year.
    int yearIndex = (daysSinceEpoch - _FirstOptimizedDay) ~/ 366;
    int indexValue = _YearStartDays[yearIndex];
    // Zero-based day of year
    int d = daysSinceEpoch - indexValue;
    int year = yearIndex + _FirstOptimizedYear;
    bool isLeap = _IsGregorianLeapYear(year);
    int daysInYear = isLeap ? 366 : 365;
    if (d >= daysInYear) {
      year++;
      d -= daysInYear;
      isLeap = _IsGregorianLeapYear(year);
    }

    // The remaining code is copied from GJYearMonthDayCalculator (and tweaked)

    int startOfMonth;
    // Perform a hard-coded binary search to get the month.
    if (isLeap) {
      startOfMonth = ((d < 182)
          ? ((d < 91) ? ((d < 31) ? -1 : (d < 60) ? 30 : 59) : ((d < 121) ? 90 : (d < 152) ? 120 : 151))
          : ((d < 274)
              ? ((d < 213) ? 181 : (d < 244) ? 212 : 243)
              : ((d < 305) ? 273 : (d < 335) ? 304 : 334)));
    } else {
      startOfMonth = ((d < 181)
          ? ((d < 90) ? ((d < 31) ? -1 : (d < 59) ? 30 : 58) : ((d < 120) ? 89 : (d < 151) ? 119 : 150))
          : ((d < 273)
              ? ((d < 212) ? 180 : (d < 243) ? 211 : 242)
              : ((d < 304) ? 272 : (d < 334) ? 303 : 333)));
    }
    int month = startOfMonth ~/ 29 + 1;
    int dayOfMonth = d - startOfMonth;
    return YearMonthDayCalendar.NewYearMonthDayCalendarOrdinal(year, month, dayOfMonth, CalendarOrdinal.Iso);
  }

  GregorianYearMonthDayCalculator.New()
      : super.NewMinYearMaxYearAverageDaysPer10YearsDaysAtStartOfYear1(
            MinGregorianYear, MaxGregorianYear, _AverageDaysPer10Years, -719162);

  @override
  int GetStartOfYearInDays(int year) {
    // 2014-06-28: Tried removing this entirely (optimized: 5ns => 8ns; unoptimized: 11ns => 8ns)
    // Decided to leave it in, as the optimized case is so much more common.
    if (year < _FirstOptimizedYear || year > _LastOptimizedYear) {
      return super.GetStartOfYearInDays(year);
    }
    return _YearStartDays[year - _FirstOptimizedYear];
  }

  @override
  int GetDaysSinceEpoch(YearMonthDay yearMonthDay) {
    // 2014-06-28: Tried removing this entirely (optimized: 8ns => 13ns; unoptimized: 23ns => 19ns)
    // Also tried computing everything lazily - it's a wash.
    // Removed validation, however - we assume that the parameter is already valid by now.
    // unchecked
    int year = yearMonthDay.Year;
    int monthOfYear = yearMonthDay.Month;
    int dayOfMonth = yearMonthDay.Day;
    if (year < _FirstOptimizedYear || year > _LastOptimizedYear - 1) {
      return super.GetDaysSinceEpoch(yearMonthDay);
    }
    int yearMonthIndex = (year - _FirstOptimizedYear) * 12 + monthOfYear;
    return _MonthStartDays[yearMonthIndex] + dayOfMonth;
  }

  @override
  void ValidateYearMonthDay(int year, int month, int day) => ValidateGregorianYearMonthDay(year, month, day);

  static void ValidateGregorianYearMonthDay(int year, int month, int day) {
    // Perform quick validation without calling Preconditions, then do it properly if we're going to throw
    // an exception. Avoiding the method call is pretty extreme, but it does help.
    if (year < MinGregorianYear || year > MaxGregorianYear || month < 1 || month > 12) {
      Preconditions.CheckArgumentRange('year', year, MinGregorianYear, MaxGregorianYear);
      Preconditions.CheckArgumentRange('month', month, 1, 12);
    }
    // If we've been asked for day 1-28, we're definitely okay regardless of month.
    if (day >= 1 && day <= 28) {
      return;
    }
    int daysInMonth = month == 2 && _IsGregorianLeapYear(year)
        ? GJYearMonthDayCalculator.LeapDaysPerMonth[month]
        : GJYearMonthDayCalculator.NonLeapDaysPerMonth[month];
    if (day < 1 || day > daysInMonth) {
      Preconditions.CheckArgumentRange('day', day, 1, daysInMonth);
    }
  }

  @override
  int CalculateStartOfYearDays(int year) {
    // Initial value is just temporary.
    int leapYears = year ~/ 100;
    if (year < 0) {
      // Add 3 before shifting right since /4 and >>2 behave differently
      // on negative numbers. When the expression is written as
      // (year / 4) - (year / 100) + (year / 400),
      // it works for both positive and negative values, except this optimization
      // eliminates two divisions.
      // noda_dart: toSigned(32) after >>, as dart2js's >> gives an unsigned 32-bit result for a negative value.
      leapYears = ((year + 3) >> 2).toSigned(32) - leapYears + ((leapYears + 3) >> 2).toSigned(32) - 1;
    } else {
      leapYears = (year >> 2) - leapYears + (leapYears >> 2);
      if (IsLeapYear(year)) {
        leapYears--;
      }
    }

    return year * 365 + (leapYears - _DaysFrom0000To1970);
  }

  // Override GetDaysInYear so we can avoid a pointless virtual method call.
  @override
  int GetDaysInYear(int year) => _IsGregorianLeapYear(year) ? 366 : 365;

  @override
  bool IsLeapYear(int year) => _IsGregorianLeapYear(year);

  static bool _IsGregorianLeapYear(int year) => ((year & 3) == 0) && (year.remainder(100) != 0 || year.remainder(400) == 0);
}
