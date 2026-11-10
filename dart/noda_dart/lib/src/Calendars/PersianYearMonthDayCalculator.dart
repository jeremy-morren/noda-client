// Ported from NodaTime 6e024dde: src/NodaTime/Calendars/PersianYearMonthDayCalculator.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import '../Utility/Preconditions.dart';
import '../YearMonthDay.dart';
// C#: Astronomical.AstronomicalLeapYearBits = Convert.FromBase64String("..."). tools/ generates the decoded bytes.
import 'PersianYearMonthDayCalculatorAstronomicalData.generated.dart';
import 'RegularYearMonthDayCalculator.dart';

/// Base class for the three variants of the Persian (Solar Hijri) calendar.
/// Concrete subclasses are nested to allow different start dates and leap year calculations.
///
/// The constructor uses IsLeapYear to precompute lots of data; it is therefore important that
/// the implementation of IsLeapYear in subclasses uses no instance fields.
@internal
abstract class PersianYearMonthDayCalculator extends RegularYearMonthDayCalculator {
  static const int _DaysPerNonLeapYear = (31 * 6) + (30 * 5) + 29;
  static const int _DaysPerLeapYear = _DaysPerNonLeapYear + 1;
  // Approximation; it'll be pretty close in all variants.
  static const int _AverageDaysPer10Years = (_DaysPerNonLeapYear * 25 + _DaysPerLeapYear * 8) * 10 ~/ 33;
  static const int MaxPersianYear = 9377;

  /// The number of days preceding the 1-indexed month - so [0, 0, 31, 62, 93, ...]
  static final List<int> _TotalDaysByMonth = _GenerateTotalDaysByMonth();

  late final List<int> _startOfYearInDaysCache;

  static List<int> _GenerateTotalDaysByMonth() {
    int days = 0;
    List<int> ret = List<int>.filled(13, 0);
    for (int i = 1; i <= 12; i++) {
      ret[i] = days;
      int daysInMonth = i <= 6 ? 31 : 30;
      // This doesn't take account of leap years, but that doesn't matter - because
      // it's not used on the last iteration, and leap years only affect the final month
      // in the Persian calendar.
      days += daysInMonth;
    }
    return ret;
  }

  PersianYearMonthDayCalculator._NewDaysAtStartOfYear1(int daysAtStartOfYear1)
      : super.NewMinYearMaxYearMonthsInYearAverageDaysPer10YearsDaysAtStartOfYear1(
            1, MaxPersianYear, 12, _AverageDaysPer10Years, daysAtStartOfYear1) {
    _startOfYearInDaysCache = List<int>.filled(MaxYear + 2, 0);
    int startOfYear = DaysAtStartOfYear1 - GetDaysInYear(0);
    for (int year = 0; year <= MaxYear + 1; year++) {
      _startOfYearInDaysCache[year] = startOfYear;
      startOfYear += GetDaysInYear(year);
    }
  }

  // C#: sealed override.
  @override
  int GetDaysFromStartOfYearToStartOfMonth(int year, int month) => _TotalDaysByMonth[month];

  // C#: sealed override.
  @override
  int GetStartOfYearInDays(int year) {
    Preconditions.DebugCheckArgumentRange('year', year, MinYear - 1, MaxYear + 1);
    return _startOfYearInDaysCache[year];
  }

  // C#: [ExcludeFromCodeCoverage], sealed override.
  @override
  int CalculateStartOfYearDays(int year) {
    // This would only be called from GetStartOfYearInDays, which is overridden.
    throw UnimplementedError();
  }

  // C#: sealed override.
  @override
  YearMonthDay GetYearMonthDay(int year, int dayOfYear) {
    int dayOfYearZeroBased = dayOfYear - 1;
    int month;
    int day;
    if (dayOfYear == _DaysPerLeapYear) {
      // Last day of a leap year.
      month = 12;
      day = 30;
    } else if (dayOfYearZeroBased < 6 * 31) {
      // In the first 6 months, all of which are 31 days long.
      month = dayOfYearZeroBased ~/ 31 + 1;
      day = (dayOfYearZeroBased.remainder(31)) + 1;
    } else {
      // Last 6 months (other than last day of leap year).
      // Work out where we are within that 6 month block, then use simple arithmetic.
      int dayOfSecondHalf = dayOfYearZeroBased - 6 * 31;
      month = dayOfSecondHalf ~/ 30 + 7;
      day = (dayOfSecondHalf.remainder(30)) + 1;
    }
    return YearMonthDay.NewYearMonthDay(year, month, day);
  }

  // C#: sealed override.
  @override
  int GetDaysInMonth(int year, int month) => month < 7
      ? 31
      : month < 12
          ? 30
          : IsLeapYear(year)
              ? 30
              : 29;

  // C#: sealed override.
  @override
  int GetDaysInYear(int year) => IsLeapYear(year) ? _DaysPerLeapYear : _DaysPerNonLeapYear;
}

/// Persian calendar using the simple 33-year cycle of 1, 5, 9, 13, 17, 22, 26, or 30.
/// This corresponds to System.Globalization.PersianCalendar before .NET 4.6.
///
/// (C#: the nested class `PersianYearMonthDayCalculator.Simple`.)
@internal
class PersianYearMonthDayCalculatorSimple extends PersianYearMonthDayCalculator {
  // This is a long because we're notionally handling 33 bits. The top bit is
  // false anyway, but IsLeapYear shifts a long for simplicity, so let's be consistent with that.
  static const int _LeapYearPatternBits =
      (1 << 1) | (1 << 5) | (1 << 9) | (1 << 13) | (1 << 17) | (1 << 22) | (1 << 26) | (1 << 30);
  static const int _LeapYearCycleLength = 33;

  /// The ticks for the epoch of March 21st 622CE.
  static const int _DaysAtStartOfYear1Constant = -492268;

  PersianYearMonthDayCalculatorSimple.New() : super._NewDaysAtStartOfYear1(_DaysAtStartOfYear1Constant);

  /// Leap year condition using the simple 33-year cycle of 1, 5, 9, 13, 17, 22, 26, or 30.
  /// This corresponds to System.Globalization.PersianCalendar before .NET 4.6.
  @override
  bool IsLeapYear(int year) {
    // Handle negative years in order to make calculations near the start of the calendar work cleanly.
    int yearOfCycle = year >= 0
        ? year.remainder(_LeapYearCycleLength)
        : (year.remainder(_LeapYearCycleLength)) + _LeapYearCycleLength;
    // Note the shift of 1L rather than 1, to avoid issues where shifting by 32
    // would get us back to 1.
    // noda_dart: yearOfCycle can be 32, which dart2js's 32-bit shifts can't do (its bit is never set anyway).
    int key = yearOfCycle < 32 ? 1 << yearOfCycle : 0;
    return (_LeapYearPatternBits & key) > 0;
  }
}

/// Persian calendar based on Birashk's subcycle/cycle/grand cycle scheme.
///
/// (C#: the nested class `PersianYearMonthDayCalculator.Arithmetic`.)
@internal
class PersianYearMonthDayCalculatorArithmetic extends PersianYearMonthDayCalculator {
  PersianYearMonthDayCalculatorArithmetic.New() : super._NewDaysAtStartOfYear1(-492267);

  @override
  bool IsLeapYear(int year) {
    // Offset the cycles for easier arithmetic. The offset year is negative before 474, so take a floored
    // modulo: C#'s % truncates towards zero, which would put years 1-473 outside the cycle (474-3293)
    // that the leap year formula is defined for.
    int offsetYear = year > 0 ? year - 474 : year - 473;
    int cycleYear = ((offsetYear + 2820).remainder(2820)) + 474;
    return (((cycleYear + 38) * 31).remainder(128)) < 31;
  }
}

/// Persian calendar based on stored BCL 4.6 information (avoids complex arithmetic for
/// midday in Tehran).
///
/// (C#: the nested class `PersianYearMonthDayCalculator.Astronomical`.)
@internal
class PersianYearMonthDayCalculatorAstronomical extends PersianYearMonthDayCalculator {
  // Ugly, but the simplest way of embedding a big chunk of binary data...
  // C#: private static readonly byte[] AstronomicalLeapYearBits = Convert.FromBase64String("..."); generated as
  // AstronomicalLeapYearBits in PersianYearMonthDayCalculatorAstronomicalData.generated.dart (imported above).

  PersianYearMonthDayCalculatorAstronomical.New() : super._NewDaysAtStartOfYear1(-492267);

  // 8 years per byte.
  @override
  bool IsLeapYear(int year) => (AstronomicalLeapYearBits[year >> 3] & (1 << (year & 7))) != 0;
}
