// Ported from NodaTime 6e024dde: src/NodaTime/Calendars/IslamicYearMonthDayCalculator.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import '../YearMonthDay.dart';
import 'IslamicEpoch.generated.dart';
import 'IslamicLeapYearPattern.generated.dart';
import 'RegularYearMonthDayCalculator.dart';

@internal
final class IslamicYearMonthDayCalculator extends RegularYearMonthDayCalculator {
  /// Days in a pair of months, in days.
  static const int _MonthPairLength = 59;

  /// The length of a long month, in days.
  static const int _LongMonthLength = 30;

  /// The length of a short month, in days.
  static const int _ShortMonthLength = 29;

  /// The typical number of days in 10 years.
  static const int _AverageDaysPer10Years = 3544; // Ideally 354.36667 per year

  /// The number of days in a non-leap year.
  static const int _DaysPerNonLeapYear = 354;

  /// The number of days in a leap year.
  static const int _DaysPerLeapYear = 355;

  /// The days for the civil (Friday) epoch of July 16th 622CE.
  static const int _DaysAtCivilEpoch = -492148;

  /// The days for the civil (Thursday) epoch of July 15th 622CE.
  static const int _DaysAtAstronomicalEpoch = _DaysAtCivilEpoch - 1;

  /// The length of the cycle of leap years.
  static const int _LeapYearCycleLength = 30;

  /// The number of days in leap cycle.
  static const int _DaysPerLeapCycle = 19 * _DaysPerNonLeapYear + 11 * _DaysPerLeapYear;

  /// The pattern of leap years within a cycle, one bit per year, for this calendar.
  final int _leapYearPatternBits;

  /// The number of days preceding the 1-indexed month - so [0, 0, 30, 59, ...]
  static final List<int> _TotalDaysByMonth = _GenerateTotalDaysByMonth();

  static List<int> _GenerateTotalDaysByMonth() {
    int days = 0;
    List<int> ret = List<int>.filled(13, 0);
    for (int i = 1; i <= 12; i++) {
      ret[i] = days;
      // Here, the month number is 1-based, so odd months are long
      int daysInMonth = (i & 1) == 1 ? _LongMonthLength : _ShortMonthLength;
      // This doesn't take account of leap years, but that doesn't matter - because
      // it's not used on the last iteration, and leap years only affect the final month
      // in the Islamic calendar.
      days += daysInMonth;
    }
    return ret;
  }

  IslamicYearMonthDayCalculator.NewLeapYearPatternEpoch(IslamicLeapYearPattern leapYearPattern, IslamicEpoch epoch)
      : _leapYearPatternBits = _GetLeapYearPatternBits(leapYearPattern),
        super.NewMinYearMaxYearMonthsInYearAverageDaysPer10YearsDaysAtStartOfYear1(
            1, 9665, 12, _AverageDaysPer10Years, _GetYear1Days(epoch));

  // The number of days at the *start* of a month isn't affected by
  // the year as the only month length which varies by year is the last one.
  @override
  int GetDaysFromStartOfYearToStartOfMonth(int year, int month) => _TotalDaysByMonth[month];

  @override
  YearMonthDay GetYearMonthDay(int year, int dayOfYear) {
    int month, day;
    // Special case the last day in a leap year
    if (dayOfYear == _DaysPerLeapYear) {
      month = 12;
      day = 30;
    } else {
      int dayOfYearZeroBased = dayOfYear - 1;
      month = ((dayOfYearZeroBased * 2) ~/ _MonthPairLength) + 1;
      day = ((dayOfYearZeroBased.remainder(_MonthPairLength)).remainder(_LongMonthLength)) + 1;
    }
    return YearMonthDay.NewYearMonthDay(year, month, day);
  }

  @override
  bool IsLeapYear(int year) {
    // Handle negative years in order to make calculations near the start of the calendar work cleanly.
    int yearOfCycle = year >= 0
        ? year.remainder(_LeapYearCycleLength)
        : (year.remainder(_LeapYearCycleLength)) + _LeapYearCycleLength;
    int key = 1 << yearOfCycle;
    return (_leapYearPatternBits & key) > 0;
  }

  @override
  int GetDaysInYear(int year) => IsLeapYear(year) ? _DaysPerLeapYear : _DaysPerNonLeapYear;

  @override
  int GetDaysInMonth(int year, int month) {
    if (month == 12 && IsLeapYear(year)) {
      return _LongMonthLength;
    }
    // Note: month is 1-based here, so even months are the short ones
    return (month & 1) == 0 ? _ShortMonthLength : _LongMonthLength;
  }

  @override
  int CalculateStartOfYearDays(int year) {
    // The first cycle starts in year 1, not year 0.
    // We try to cope with years outside the normal range, in order to allow arithmetic at the boundaries.
    int cycle = year > 0 ? (year - 1) ~/ _LeapYearCycleLength : (year - _LeapYearCycleLength) ~/ _LeapYearCycleLength;
    int yearAtStartOfCycle = (cycle * _LeapYearCycleLength) + 1;

    int days = DaysAtStartOfYear1 + cycle * _DaysPerLeapCycle;

    // We've got the days at the start of the cycle (e.g. at the start of year 1, 31, 61 etc).
    // Now go from that year to (but not including) the year we're looking for, adding the right
    // number of days in each year. So if we're trying to find the start of year 34, we would
    // find the days at the start of year 31, then add the days *in* year 31, the days in year 32,
    // and the days in year 33.
    // If this ever proves to be a bottleneck, we could create an array for each IslamicLeapYearPattern
    // with "the number of days for the first n years in a cycle".
    for (int i = yearAtStartOfCycle; i < year; i++) {
      days += GetDaysInYear(i);
    }
    return days;
  }

  /// Returns the pattern of leap years within a cycle, one bit per year, for the specified pattern.
  /// Note that although cycle years are usually numbered 1-30, the bit pattern is for 0-29; cycle year
  /// 30 is represented by bit 0.
  static int _GetLeapYearPatternBits(IslamicLeapYearPattern leapYearPattern) => switch (leapYearPattern) {
        // When reading bit patterns, don't forget to read right to left...
        IslamicLeapYearPattern.Base15 => 623158436, // 0b100101001001001010010010100100
        IslamicLeapYearPattern.Base16 => 623191204, // 0b100101001001010010010010100100
        IslamicLeapYearPattern.Indian => 690562340, // 0b101001001010010010010100100100
        IslamicLeapYearPattern.HabashAlHasib => 153692453, // 0b001001001010010010100100100101
        _ => throw RangeError.value(
            leapYearPattern.value, 'leapYearPattern', 'Specified argument was out of the range of valid values.')
      };

  /// Returns the days since the Unix epoch at the specified epoch.
  static int _GetYear1Days(IslamicEpoch epoch) => switch (epoch) {
        // Epoch 1970-01-01 ISO = 1389-10-22 Islamic (civil) or 1389-10-23 Islamic (astronomical)
        IslamicEpoch.Astronomical => _DaysAtAstronomicalEpoch,
        IslamicEpoch.Civil => _DaysAtCivilEpoch,
        _ => throw RangeError.value(epoch.value, 'epoch', 'Specified argument was out of the range of valid values.')
      };
}
