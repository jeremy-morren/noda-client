// Ported from NodaTime 6e024dde: src/NodaTime/Calendars/HebrewYearMonthDayCalculator.cs
// Copyright 2014 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'dart:math' as math;

import 'package:meta/meta.dart';

import '../Utility/Checked.dart';
import '../Utility/SystemExceptions.dart';
import '../YearMonthDay.dart';
import 'HebrewMonthConverter.dart';
import 'HebrewMonthNumbering.generated.dart';
import 'HebrewScripturalCalculator.dart';
import 'YearMonthDayCalculator.dart';

/// See [CalendarSystem.GetHebrewCalendar] for details. This is effectively
/// an adapter around [HebrewScripturalCalculator].
@internal
final class HebrewYearMonthDayCalculator extends YearMonthDayCalculator {
  static const int _UnixEpochDayAtStartOfYear1 = -2092590;
  static const int _MonthsPerLeapCycle = 235;
  static const int _YearsPerLeapCycle = 19;
  final HebrewMonthNumbering _monthNumbering;

  HebrewYearMonthDayCalculator.NewMonthNumbering(HebrewMonthNumbering monthNumbering)
      : _monthNumbering = monthNumbering,
        super.NewMinYearMaxYearAverageDaysPer10YearsDaysAtStartOfYear1(
            HebrewScripturalCalculator.MinYear,
            HebrewScripturalCalculator.MaxYear,
            3654, // Average length of 10 years
            _UnixEpochDayAtStartOfYear1);

  int _CalendarToCivilMonth(int year, int month) =>
      _monthNumbering == HebrewMonthNumbering.Civil ? month : HebrewMonthConverter.ScripturalToCivil(year, month);

  int _CalendarToScripturalMonth(int year, int month) =>
      _monthNumbering == HebrewMonthNumbering.Scriptural ? month : HebrewMonthConverter.CivilToScriptural(year, month);

  int _CivilToCalendarMonth(int year, int month) =>
      _monthNumbering == HebrewMonthNumbering.Civil ? month : HebrewMonthConverter.CivilToScriptural(year, month);

  int _ScripturalToCalendarMonth(int year, int month) =>
      _monthNumbering == HebrewMonthNumbering.Scriptural ? month : HebrewMonthConverter.ScripturalToCivil(year, month);

  /// Returns whether or not the given year is a leap year - that is, one with 13 months. This is
  /// not quite the same as a leap year in (say) the Gregorian calendar system...
  @override
  bool IsLeapYear(int year) => HebrewScripturalCalculator.IsLeapYear(year);

  @override
  int GetDaysFromStartOfYearToStartOfMonth(int year, int month) {
    int scripturalMonth = _CalendarToScripturalMonth(year, month);
    return HebrewScripturalCalculator.GetDaysFromStartOfYearToStartOfMonth(year, scripturalMonth);
  }

  @override
  int CalculateStartOfYearDays(int year) {
    // Note that we might get called with a year of 0 here. I think that will still be okay,
    // given how HebrewScripturalCalculator works.
    int daysSinceHebrewEpoch = HebrewScripturalCalculator.ElapsedDays(year) - 1; // ElapsedDays returns 1 for year 1.
    return daysSinceHebrewEpoch + _UnixEpochDayAtStartOfYear1;
  }

  @override
  YearMonthDay GetYearMonthDay(int year, int dayOfYear) {
    YearMonthDay scriptural = HebrewScripturalCalculator.GetYearMonthDay(year, dayOfYear);
    return _monthNumbering == HebrewMonthNumbering.Scriptural
        ? scriptural
        : YearMonthDay.NewYearMonthDay(year, HebrewMonthConverter.ScripturalToCivil(year, scriptural.Month), scriptural.Day);
  }

  @override
  int GetDaysInYear(int year) => HebrewScripturalCalculator.DaysInYear(year);

  @override
  int GetMonthsInYear(int year) => IsLeapYear(year) ? 13 : 12;

  /// Change the year, maintaining month and day as well as possible. This doesn't
  /// work in the same way as other calendars; see https://judaism.stackexchange.com/questions/39053
  /// for the reasoning behind the rules.
  @override
  YearMonthDay SetYear(YearMonthDay yearMonthDay, int year) {
    int currentYear = yearMonthDay.Year;
    int currentMonth = yearMonthDay.Month;
    int targetDay = yearMonthDay.Day;
    int targetScripturalMonth = _CalendarToScripturalMonth(currentYear, currentMonth);
    if (targetScripturalMonth == 13 && !IsLeapYear(year)) {
      // If we were in Adar II and the target year is not a leap year, map to Adar.
      targetScripturalMonth = 12;
    } else if (targetScripturalMonth == 12 && IsLeapYear(year) && !IsLeapYear(currentYear)) {
      // If we were in Adar (non-leap year), go to Adar II rather than Adar I in a leap year.
      targetScripturalMonth = 13;
    }
    // If we're aiming for the 30th day of Heshvan, Kislev or an Adar, it's possible that the change in year
    // has meant the day becomes invalid. In that case, roll over to the 1st of the subsequent month.
    if (targetDay == 30 && (targetScripturalMonth == 8 || targetScripturalMonth == 9 || targetScripturalMonth == 12)) {
      if (HebrewScripturalCalculator.DaysInMonth(year, targetScripturalMonth) != 30) {
        targetDay = 1;
        targetScripturalMonth++;
        // From Adar, roll to Nisan.
        if (targetScripturalMonth == 13) {
          targetScripturalMonth = 1;
        }
      }
    }
    int targetCalendarMonth = _ScripturalToCalendarMonth(year, targetScripturalMonth);
    return YearMonthDay.NewYearMonthDay(year, targetCalendarMonth, targetDay);
  }

  @override
  int GetDaysInMonth(int year, int month) =>
      HebrewScripturalCalculator.DaysInMonth(year, _CalendarToScripturalMonth(year, month));

  @override
  YearMonthDay AddMonths(YearMonthDay yearMonthDay, int months) {
    // Note: this method gives the same result regardless of the month numbering used
    // by the instance. The method works in terms of civil month numbers for most of
    // the time in order to simplify the logic.
    if (months == 0) {
      return yearMonthDay;
    }
    int year = yearMonthDay.Year;
    int month = _CalendarToCivilMonth(year, yearMonthDay.Month);
    // This arithmetic works the same both backwards and forwards.
    year += (months ~/ _MonthsPerLeapCycle) * _YearsPerLeapCycle;
    months = months.remainder(_MonthsPerLeapCycle);
    if (months > 0) {
      // Add as many months as we need to in order to act as if we'd begun at the start
      // of the year, for simplicity.
      months += month - 1;
      // Add a year at a time
      while (months >= GetMonthsInYear(year)) {
        months -= GetMonthsInYear(year);
        year++;
      }
      // However many months we've got left to add tells us the final month.
      month = months + 1;
    } else {
      // Pretend we were given the month at the end of the years.
      months -= GetMonthsInYear(year) - month;
      // Subtract a year at a time
      while (months + GetMonthsInYear(year) <= 0) {
        months += GetMonthsInYear(year);
        year--;
      }
      // However many months we've got left to add (which will still be negative...)
      // tells us the final month.
      month = GetMonthsInYear(year) + months;
    }

    // Convert back to calendar month
    month = _CivilToCalendarMonth(year, month);
    int day = math.min(GetDaysInMonth(year, month), yearMonthDay.Day);
    if (year < MinYear || year > MaxYear) {
      throw OverflowException('Date computation would overflow calendar bounds.');
    }

    return YearMonthDay.NewYearMonthDay(year, month, day);
  }

  @override
  int MonthsBetween(YearMonthDay start, YearMonthDay end) {
    // First (quite rough) guess... we could probably be more efficient than this, but it's unlikely to be very far off.
    int startCivilMonth = _CalendarToCivilMonth(start.Year, start.Month);
    double startTotalMonths = startCivilMonth + (start.Year * _MonthsPerLeapCycle) / _YearsPerLeapCycle.toDouble();
    int endCivilMonth = _CalendarToCivilMonth(end.Year, end.Month);
    double endTotalMonths = endCivilMonth + (end.Year * _MonthsPerLeapCycle) / _YearsPerLeapCycle.toDouble();
    int diff = Checked.DoubleToInt32(endTotalMonths - startTotalMonths);

    if (Compare(start, end) <= 0) {
      // Go backwards until we've got a tight upper bound...
      while (Compare(AddMonths(start, diff), end) > 0) {
        diff--;
      }
      // Go forwards until we've overshot
      while (Compare(AddMonths(start, diff), end) <= 0) {
        diff++;
      }
      // Take account of the overshoot
      return diff - 1;
    } else {
      // Moving backwards, so we need to end up with a result greater than or equal to end...
      // Go forwards until we've got a tight upper bound...
      while (Compare(AddMonths(start, diff), end) < 0) {
        diff++;
      }
      // Go backwards until we've overshot
      while (Compare(AddMonths(start, diff), end) >= 0) {
        diff--;
      }
      // Take account of the overshoot
      return diff + 1;
    }
  }

  @override
  int Compare(YearMonthDay lhs, YearMonthDay rhs) {
    // The civil month numbering system allows a naive comparison.
    if (_monthNumbering == HebrewMonthNumbering.Civil) {
      return lhs.compareTo(rhs);
    }
    // Otherwise, try one component at a time. (We could benchmark this
    // against creating a new pair of YearMonthDay values in the civil month numbering,
    // and comparing them...)
    int yearComparison = lhs.Year.compareTo(rhs.Year);
    if (yearComparison != 0) {
      return yearComparison;
    }
    int lhsCivilMonth = _CalendarToCivilMonth(lhs.Year, lhs.Month);
    int rhsCivilMonth = _CalendarToCivilMonth(rhs.Year, rhs.Month);
    int monthComparison = lhsCivilMonth.compareTo(rhsCivilMonth);
    if (monthComparison != 0) {
      return monthComparison;
    }
    return lhs.Day.compareTo(rhs.Day);
  }
}
