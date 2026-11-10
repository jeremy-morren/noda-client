// Ported from NodaTime 6e024dde: src/NodaTime/Calendars/BadiYearMonthDayCalculator.cs
// Copyright 2017 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'dart:math' as math;

import 'package:meta/meta.dart';

import '../CalendarSystem.dart';
import '../LocalDate.dart';
import '../Utility/Preconditions.dart';
import '../Utility/SystemExceptions.dart';
import '../YearMonthDay.dart';
// C#: YearInfoRaw = Convert.FromBase64String("..."). tools/ generates the decoded bytes.
import 'BadiYearMonthDayCalculatorData.generated.dart';
import 'YearMonthDayCalculator.dart';

/// See [CalendarSystem.Badi] for details about the Badíʿ calendar.
@internal
final class BadiYearMonthDayCalculator extends YearMonthDayCalculator {
  // named constants to avoid use of raw numbers in the code
  static const int _AverageDaysPer10Years = 3652; // Ideally 365.2425 per year...
  static const int _DaysInAyyamiHaInLeapYear = 5;
  static const int _DaysInAyyamiHaInNormalYear = 4;

  static const int DaysInMonth = 19;
  static const int _FirstYearOfStandardizedCalendar = 172;
  static const int _GregorianYearOfFirstBadiYear = 1844;

  /// There are 19 months in a year. Between the 18th and 19th month are the "days of Ha" (Ayyam-i-Ha).
  /// In order to make everything else in Noda Time work appropriately, Ayyam-i-Ha are counted as
  /// extra days at the end of month 18.
  static const int Month18 = 18;
  static const int _Month19 = 19;
  static const int _MonthsInYear = 19;

  static const int _UnixEpochDayAtStartOfYear1 = -45941;
  static const int _BadiMaxYear = 1000; // current lookup tables are pre-calculated for a thousand years
  static const int _BadiMinYear = 1;

  // C#: static byte[] YearInfoRaw (generated: see the imports).
  //
  // This is the base64 representation of information for years 172 to 1000.
  // NazRuzDate falls on March 19, 20, 21, or 22.
  // DaysInAyymiHa can be 4,5.
  // For each year, the value in the array is (NawRuzDate - 19) + 10 * (DaysInAyyamiHa - 4)

  // noda_dart: C#'s static constructor, run by the first instance.
  static final bool _StaticConstructor = () {
    Preconditions.DebugCheckState(
        _FirstYearOfStandardizedCalendar + YearInfoRaw.length == _BadiMaxYear + 1,
        'Invalid compressed data. Length: ${YearInfoRaw.length}');
    return true;
  }();

  BadiYearMonthDayCalculator.New()
      : assert(_StaticConstructor),
        super.NewMinYearMaxYearAverageDaysPer10YearsDaysAtStartOfYear1(
            _BadiMinYear, _BadiMaxYear - 1, _AverageDaysPer10Years, _UnixEpochDayAtStartOfYear1);

  static int GetDaysInAyyamiHa(int year) {
    // Year 0 is valid here, for the length of the week-year before the first year: see CalculateStartOfYearDays.
    Preconditions.CheckArgumentRange('year', year, _BadiMinYear - 1, _BadiMaxYear);
    if (year < _FirstYearOfStandardizedCalendar) {
      return CalendarSystem.Iso.YearMonthDayCalculator.IsLeapYear(year + _GregorianYearOfFirstBadiYear)
          ? _DaysInAyyamiHaInLeapYear
          : _DaysInAyyamiHaInNormalYear;
    }
    int num = YearInfoRaw[year - _FirstYearOfStandardizedCalendar];
    return num >= 10 ? _DaysInAyyamiHaInLeapYear : _DaysInAyyamiHaInNormalYear;
  }

  static int _GetNawRuzDayInMarch(int year) {
    // Year 0 is valid here: see CalculateStartOfYearDays.
    Preconditions.CheckArgumentRange('year', year, _BadiMinYear - 1, _BadiMaxYear);
    if (year < _FirstYearOfStandardizedCalendar) {
      return 21;
    }
    const int dayInMarchForOffsetToNawRuz = 19;
    int num = YearInfoRaw[year - _FirstYearOfStandardizedCalendar];
    return dayInMarchForOffsetToNawRuz + (num % 10);
  }

  @override
  int CalculateStartOfYearDays(int year) {
    // As documented in YearMonthDayCalculator, the year may be one outside the calendar's range: week-year
    // rules need the start of the year before the first year (year 0, which starts on March 21st 1843 like
    // every year before the standardized calendar) and after the last year (BadiMaxYear, one more than MaxYear).
    Preconditions.CheckArgumentRange('year', year, _BadiMinYear - 1, _BadiMaxYear);

    // The epoch is the same regardless of calendar system, so if we work out when the
    // start of the Badíʿ year is in terms of the Gregorian year, we can just use that
    // date's days-since-epoch value.
    var gregorianYear = year + _GregorianYearOfFirstBadiYear - 1;
    var nawRuz = LocalDate(gregorianYear, 3, _GetNawRuzDayInMarch(year));
    return nawRuz.DaysSinceEpoch;
  }

  @override
  int GetDaysFromStartOfYearToStartOfMonth(int year, int month) {
    var daysFromStartOfYearToStartOfMonth = DaysInMonth * (month - 1);

    if (month == _Month19) {
      daysFromStartOfYearToStartOfMonth += GetDaysInAyyamiHa(year);
    }

    return daysFromStartOfYearToStartOfMonth;
  }

  @override
  YearMonthDay AddMonths(YearMonthDay start, int months) {
    if (months == 0) {
      return start;
    }

    var movingBackwards = months < 0;

    var thisMonth = start.Month;
    var thisYear = start.Year;
    var thisDay = start.Day;

    var nextDay = thisDay;

    // TODO: It's not clear that this is correct. If we add 19 months,
    // it's probably okay to stay in Ayyam-i-Ha.
    if (IsInAyyamiHa(start)) {
      nextDay = thisDay - DaysInMonth;

      if (movingBackwards) {
        thisMonth++;
      }
    }

    var nextYear = thisYear;
    var nextMonthNum = thisMonth + months;

    if (nextMonthNum > _MonthsInYear) {
      nextYear = thisYear + (nextMonthNum - 1) ~/ _MonthsInYear;
      nextMonthNum = (nextMonthNum - 1) % _MonthsInYear + 1;
    } else if (nextMonthNum < 1) {
      nextMonthNum = _MonthsInYear - nextMonthNum;
      nextYear = thisYear - nextMonthNum ~/ _MonthsInYear;
      nextMonthNum = _MonthsInYear - nextMonthNum % _MonthsInYear;
    }

    if (nextYear < MinYear || nextYear > MaxYear) {
      throw OverflowException('Date computation would overflow calendar bounds.');
    }

    var result = YearMonthDay.NewYearMonthDay(nextYear, nextMonthNum, nextDay);

    return result;
  }

  @override
  int GetDaysInMonth(int year, int month) {
    Preconditions.CheckArgumentRange('year', year, _BadiMinYear, _BadiMaxYear);
    return month == Month18 ? DaysInMonth + GetDaysInAyyamiHa(year) : DaysInMonth;
  }

  @override
  int GetDaysInYear(int year) => 361 + GetDaysInAyyamiHa(year);

  @override
  // C# names the parameter `target`, unlike the method it overrides.
  // ignore: avoid_renaming_method_parameters
  int GetDaysSinceEpoch(YearMonthDay target) {
    var month = target.Month;
    var year = target.Year;

    var firstDay0OfYear = CalculateStartOfYearDays(year) - 1;

    var daysSinceEpoch = firstDay0OfYear + (month - 1) * DaysInMonth + target.Day;

    if (month == _Month19) {
      daysSinceEpoch += GetDaysInAyyamiHa(year);
    }

    return daysSinceEpoch;
  }

  @override
  int GetMonthsInYear(int year) => _MonthsInYear;

  @override
  YearMonthDay GetYearMonthDay(int year, int dayOfYear) {
    Preconditions.CheckArgumentRange('dayOfYear', dayOfYear, 1, GetDaysInYear(year));

    var firstOfLoftiness = 1 + DaysInMonth * Month18 + GetDaysInAyyamiHa(year);

    if (dayOfYear >= firstOfLoftiness) {
      return YearMonthDay.NewYearMonthDay(year, _Month19, dayOfYear - firstOfLoftiness + 1);
    }

    var month = math.min(1 + (dayOfYear - 1) ~/ DaysInMonth, Month18);
    var day = dayOfYear - (month - 1) * DaysInMonth;

    return YearMonthDay.NewYearMonthDay(year, month, day);
  }

  static bool IsInAyyamiHa(YearMonthDay ymd) => ymd.Month == Month18 && ymd.Day > DaysInMonth;

  @override
  bool IsLeapYear(int year) => GetDaysInAyyamiHa(year) != _DaysInAyyamiHaInNormalYear;

  @override
  int MonthsBetween(YearMonthDay start, YearMonthDay end) {
    int startMonth = start.Month;
    int startYear = start.Year;

    int endMonth = end.Month;
    int endYear = end.Year;

    int diff = (endYear - startYear) * _MonthsInYear + endMonth - startMonth;

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

  @override
  YearMonthDay SetYear(YearMonthDay start, int newYear) {
    Preconditions.CheckArgumentRange('newYear', newYear, _BadiMinYear, _BadiMaxYear);

    var month = start.Month;
    var day = start.Day;

    if (IsInAyyamiHa(start)) {
      // Moving a year while within Ayyam-i-Ha is not well defined.
      // In this implementation, if starting on day 5, end on day 4 (stay in Ayyam-i-Ha)
      var daysInThisAyyamiHa = GetDaysInAyyamiHa(newYear);
      return YearMonthDay.NewYearMonthDay(newYear, month, math.min(day, DaysInMonth + daysInThisAyyamiHa));
    }

    return YearMonthDay.NewYearMonthDay(newYear, month, day);
  }

  @override
  void ValidateYearMonthDay(int year, int month, int day) {
    Preconditions.CheckArgumentRange('year', year, _BadiMinYear, _BadiMaxYear);
    Preconditions.CheckArgumentRange('month', month, 1, _MonthsInYear);

    int daysInMonth = month == Month18 ? DaysInMonth + GetDaysInAyyamiHa(year) : DaysInMonth;
    Preconditions.CheckArgumentRange('day', day, 1, daysInMonth);
  }
}
