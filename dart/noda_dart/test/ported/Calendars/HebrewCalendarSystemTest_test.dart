// Ported from NodaTime 6e024dde: src/NodaTime.Test/Calendars/HebrewCalendarSystemTest.cs
// Copyright 2014 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda_dart: the data arrays aren't ported: their values are the scenario's cases.

import 'package:noda_dart/src/CalendarSystem.dart';
import 'package:noda_dart/src/Calendars/HebrewMonthNumbering.generated.dart';
import 'package:noda_dart/src/Calendars/HebrewScripturalCalculator.dart';
import 'package:noda_dart/src/Calendars/HebrewYearMonthDayCalculator.dart';
import 'package:noda_dart/src/LocalDate.dart';
import 'package:noda_dart/src/LocalDateTime.dart';
import 'package:noda_dart/src/Period.dart';
import 'package:noda_dart/src/PeriodUnits.generated.dart';
import 'package:noda_dart/src/Text/LocalDatePattern.dart';
import 'package:noda_dart/src/Utility/SystemExceptions.dart';
import 'package:noda_dart/src/YearMonthDay.dart';

import '../../helpers/Assertions.dart';
import '../../helpers/Scenarios.dart';
import '../../helpers/TestHelper.dart';
import '../../scenarios/Calendars/HebrewCalendarSystemTest.generated.dart' as scenarios;

/// Tests for HebrewYearMonthDayCalculator via the Hebrew CalendarSystem.
/// See https://blog.nodatime.org/2014/06/hebrew-calendar-cheat-sheet.html
/// for sample year information.
void main() {
  port(scenarios.fixture, {
    // Test cases are in scriptural month numbering, but we check both. This is
    // mostly testing the behaviour of SetYear, via LocalDate.PlusYears.
    'SetYear': (args) {
      final [String startText, int years, String expectedEndText] = args;
      var civil = CalendarSystem.HebrewCivil;
      var scriptural = CalendarSystem.HebrewScriptural;
      var pattern = LocalDatePattern.CreateWithInvariantCulture('uuuu-MM-dd')
          .WithTemplateValue(LocalDate(5774, 1, 1, scriptural)); // Sample value in 2014 ISO

      var start = pattern.Parse(startText).Value;
      var expectedEnd = pattern.Parse(expectedEndText).Value;
      Assert.AreEqual(expectedEnd, start.PlusYears(years));

      // Check civil as well... the date should be the same (year, month, day) even though
      // the numbering is different.
      Assert.AreEqual(expectedEnd.WithCalendar(civil), start.WithCalendar(civil).PlusYears(years));
    },

    'AddMonths_MonthsBetween': (args) {
      final [String startText, int months, String expectedEndText] = args;
      var civil = CalendarSystem.HebrewCivil;
      var pattern = LocalDatePattern.CreateWithInvariantCulture('uuuu-MM-dd')
          .WithTemplateValue(LocalDate(5774, 1, 1, civil)); // Sample value in 2014 ISO

      var start = pattern.Parse(startText).Value;
      var expectedEnd = pattern.Parse(expectedEndText).Value;
      Assert.AreEqual(expectedEnd, start.PlusMonths(months));
    },

    'MonthsBetween': (args) {
      final [String startText, int expectedMonths, String endText] = args;
      var civil = CalendarSystem.HebrewCivil;
      var pattern = LocalDatePattern.CreateWithInvariantCulture('uuuu-MM-dd')
          .WithTemplateValue(LocalDate(5774, 1, 1, civil)); // Sample value in 2014 ISO

      var start = pattern.Parse(startText).Value;
      var end = pattern.Parse(endText).Value;
      Assert.AreEqual(expectedMonths, Period.BetweenLocalDate(start, end, PeriodUnits.Months).Months);
    },

    'MonthsBetween_TimeOfDay': (args) {
      var civil = CalendarSystem.HebrewCivil;
      var start = LocalDateTime.YearMonthDayHourMinuteCalendar(5774, 5, 10, 15, 0, civil); // 3pm
      var end = LocalDateTime.YearMonthDayHourMinuteCalendar(5774, 7, 10, 5, 0, civil); // 5am
      // Would be 2, but the start time is later than the end time.
      Assert.AreEqual(1, Period.Between(start, end, PeriodUnits.Months).Months);
    },

    'DayOfYearAndReverse': (args) {
      final [HebrewMonthNumbering numbering] = args;
      var calculator = HebrewYearMonthDayCalculator.NewMonthNumbering(numbering);
      for (int year = 5400; year < 5419; year++) {
        int daysInYear = calculator.GetDaysInYear(year);
        for (int dayOfYear = 1; dayOfYear <= daysInYear; dayOfYear++) {
          YearMonthDay ymd = calculator.GetYearMonthDay(year, dayOfYear);
          Assert.AreEqual(dayOfYear, calculator.GetDayOfYear(ymd));
        }
      }
    },

    'GetDaysSinceEpoch': (args) {
      var calculator = HebrewYearMonthDayCalculator.NewMonthNumbering(HebrewMonthNumbering.Scriptural);
      var unixEpoch = YearMonthDay.NewYearMonthDay(5730, 10, 23);
      Assert.AreEqual(0, calculator.GetDaysSinceEpoch(unixEpoch));
    },

    'DaysAtStartOfYear': (args) {
      // These are somewhat random values used when diagnosing an issue.
      var calculator = HebrewYearMonthDayCalculator.NewMonthNumbering(HebrewMonthNumbering.Scriptural);
      Assert.AreEqual(-110, calculator.GetStartOfYearInDays(5730));
      Assert.AreEqual(273, calculator.GetStartOfYearInDays(5731));
      Assert.AreEqual(-140735, calculator.GetStartOfYearInDays(5345));
      Assert.AreEqual(YearMonthDay.NewYearMonthDay(5345, 1, 1), calculator.GetYearMonthDayDaysSinceEpoch(-140529));
    },

    'GetDaysInYearCrossCheck': (args) {
      var calculator = HebrewYearMonthDayCalculator.NewMonthNumbering(HebrewMonthNumbering.Civil);
      for (int year = calculator.MinYear; year <= calculator.MaxYear; year++) {
        int sum = Iterable<int>.generate(calculator.GetMonthsInYear(year), (i) => i + 1)
            .map((month) => calculator.GetDaysInMonth(year, month))
            .fold(0, (a, b) => a + b);
        Assert.AreEqual(sum, calculator.GetDaysInYear(year), 'Days in $year');
      }
    },

    'ScripturalCompare': (args) {
      final [String earlier, String later] = args;
      var pattern = LocalDatePattern.Iso.WithCalendar(CalendarSystem.HebrewScriptural);
      var earlierDate = pattern.Parse(earlier).Value;
      var laterDate = pattern.Parse(later).Value;
      TestHelper.TestCompareToStruct(earlierDate, earlierDate, [laterDate]);
    },

    'ScripturalGetDaysFromStartOfYearToStartOfMonth_InvalidForCoverage': (args) {
      Assert.Throws<RangeError>(() => HebrewScripturalCalculator.GetDaysFromStartOfYearToStartOfMonth(5502, 0));
    },

    'PlusMonths_Overflow': (args) {
      final [HebrewMonthNumbering monthNumbering] = args;
      var calendar = CalendarSystem.GetHebrewCalendar(monthNumbering);
      // TODO: It would be nice to have an easy way of getting the smallest/largest LocalDate for
      // a calendar. Or possibly FromDayOfYear as well... instead, we'll just add/subtract 8 months instead
      var earlyDate = LocalDate(calendar.MinYear, 1, 1, calendar);
      var lateDate = LocalDate(calendar.MaxYear, 12, 1, calendar);

      Assert.Throws<OverflowException>(() => earlyDate.PlusMonths(-7));
      Assert.Throws<OverflowException>(() => lateDate.PlusMonths(7));
    },
  }, skip: {
    'IsLeapYear': SkipReasons.BclCalendar,
    'BclThroughHistory_Civil': SkipReasons.BclCalendar,
    'BclThroughHistory_Scriptural': SkipReasons.BclCalendar,
  });
}
