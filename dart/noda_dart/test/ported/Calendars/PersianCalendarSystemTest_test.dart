// Ported from NodaTime 6e024dde: src/NodaTime.Test/Calendars/PersianCalendarSystemTest.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda_dart: GenerateData (#if DEBUG, explicit) isn't in the scenarios.

import 'package:noda_dart/src/CalendarSystem.dart';
import 'package:noda_dart/src/LocalDate.dart';

import '../../helpers/Assertions.dart';
import '../../helpers/Scenarios.dart';
import '../../scenarios/Calendars/PersianCalendarSystemTest.generated.dart' as scenarios;

/// Tests for PersianYearMonthDayCalculator via the Persian CalendarSystem.
void main() {
  port(scenarios.fixture, {
    /// Use the examples in Calendrical Calculations for where the arithmetic calendar differs
    /// from the astronomical one.
    'ArithmeticExamples': (args) {
      final [int persianYear, int gregorianYear, int gregorianDayOfMarch] = args;
      var persian = LocalDate(persianYear, 1, 1, CalendarSystem.PersianArithmetic);
      var gregorian = persian.WithCalendar(CalendarSystem.Gregorian);
      Assert.AreEqual(gregorianYear, gregorian.Year);
      Assert.AreEqual(3, gregorian.Month);
      Assert.AreEqual(gregorianDayOfMarch, gregorian.Day);
    },

    /// The arithmetic calendar repeats every 2820 years, including the years before 474.
    /// A floored modulo puts year 24 in the same position in the cycle as year 2844.
    'ArithmeticLeapYearsRepeatEvery2820Years': (args) {
      var calendar = CalendarSystem.PersianArithmetic;
      for (var year = calendar.MinYear; year + 2820 <= calendar.MaxYear; year++) {
        Assert.AreEqual(calendar.IsLeapYear(year + 2820), calendar.IsLeapYear(year), 'Year $year');
      }
    },

    /// Leap years and new year's days before 474 use the same cycle as later years.
    'ArithmeticYearsBefore474': (args) {
      final [int persianYear, bool leap, int gregorianYear, int gregorianDayOfMarch] = args;
      Assert.AreEqual(leap, CalendarSystem.PersianArithmetic.IsLeapYear(persianYear));
      var gregorian = LocalDate(persianYear, 1, 1, CalendarSystem.PersianArithmetic).WithCalendar(CalendarSystem.Gregorian);
      Assert.AreEqual(LocalDate(gregorianYear, 3, gregorianDayOfMarch, CalendarSystem.Gregorian), gregorian);
    },

    'ArithmeticYearEndBefore474': (args) {
      var calendar = CalendarSystem.PersianArithmetic;
      var lastDayOfYear24 = LocalDate(24, 12, 29, calendar);
      Assert.AreEqual(LocalDate(25, 1, 1, calendar), lastDayOfYear24.PlusDays(1));
      Assert.Throws<RangeError>(() => LocalDate(24, 12, 30, calendar));

      var leapDayOfYear25 = LocalDate(25, 12, 30, calendar);
      Assert.AreEqual(LocalDate(26, 1, 1, calendar), leapDayOfYear25.PlusDays(1));
    },
  }, skip: {
    'BclThroughHistory': SkipReasons.BclCalendar,
  });
}
