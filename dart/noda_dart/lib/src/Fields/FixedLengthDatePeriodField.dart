// Ported from NodaTime 6e024dde: src/NodaTime/Fields/FixedLengthDatePeriodField.cs
// Copyright 2014 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import '../Calendars/YearMonthDayCalculator.dart';
import '../LocalDate.dart';
import '../Period.dart';
import '../Utility/Checked.dart';
import '../Utility/SystemExceptions.dart';
import '../YearMonthDay.dart';
import '../YearMonthDayCalendar.dart';
import 'IDatePeriodField.dart';

/// Date period field for fixed-length periods (weeks and days).
@internal
final class FixedLengthDatePeriodField implements IDatePeriodField {
  final int _unitDays;

  FixedLengthDatePeriodField.NewUnitDays(int unitDays) : _unitDays = unitDays;

  @override
  LocalDate Add(LocalDate localDate, int value) {
    if (value == 0) {
      return localDate;
    }
    int daysToAdd = Checked.MultiplyInt32(value, _unitDays);
    var calendar = localDate.Calendar;
    // If we know it will be in this year, next year, or the previous year...
    if (daysToAdd < 300 && daysToAdd > -300) {
      YearMonthDayCalculator calculator = calendar.YearMonthDayCalculator;
      YearMonthDay yearMonthDay = localDate.YearMonthDay;
      int year = yearMonthDay.Year;
      int month = yearMonthDay.Month;
      int day = yearMonthDay.Day;
      int newDayOfMonth = day + daysToAdd;
      if (1 <= newDayOfMonth && newDayOfMonth <= calculator.GetDaysInMonth(year, month)) {
        return LocalDate.NewYearMonthDayCalendar(
            YearMonthDayCalendar.NewYearMonthDayCalendarOrdinal(year, month, newDayOfMonth, calendar.Ordinal));
      }
      int dayOfYear = calculator.GetDayOfYear(yearMonthDay);
      int newDayOfYear = dayOfYear + daysToAdd;

      if (newDayOfYear < 1) {
        newDayOfYear += calculator.GetDaysInYear(year - 1);
        year--;
        if (year < calculator.MinYear) {
          throw OverflowException('Date computation would underflow the minimum year of the calendar');
        }
      } else {
        int daysInYear = calculator.GetDaysInYear(year);
        if (newDayOfYear > daysInYear) {
          newDayOfYear -= daysInYear;
          year++;
          if (year > calculator.MaxYear) {
            throw OverflowException('Date computation would overflow the maximum year of the calendar');
          }
        }
      }
      return LocalDate.NewYearMonthDayCalendar(calculator.GetYearMonthDay(year, newDayOfYear).WithCalendarOrdinal(calendar.Ordinal));
    }
    // LocalDate constructor will validate.
    int days = Checked.AddInt32(localDate.DaysSinceEpoch, daysToAdd);
    return LocalDate.NewDaysSinceEpochCalendar(days, calendar);
  }

  @override
  int UnitsBetween(LocalDate start, LocalDate end) => Period.InternalDaysBetween(start, end) ~/ _unitDays;
}
