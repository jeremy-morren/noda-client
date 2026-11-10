// Ported from NodaTime 6e024dde: src/NodaTime.Test/Calendars/SimpleWeekYearRuleTest.cs
// Copyright 2016 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda_dart: the calendar-less extension methods are hidden by the interface's own members: called as
// WeekYearRuleExtensions(rule).X. CalendarBoundaryRules' cases (unencodable) run in a group at the end of main().

import 'package:noda_dart/src/CalendarSystem.dart';
import 'package:noda_dart/src/Calendars/IWeekYearRule.dart';
import 'package:noda_dart/src/Calendars/WeekYearRules.dart';
import 'package:noda_dart/src/IsoDayOfWeek.generated.dart';
import 'package:noda_dart/src/LocalDate.dart';
import 'package:test/test.dart' show group, test;

import '../../helpers/Assertions.dart';
import '../../helpers/Scenarios.dart';
import '../../scenarios/Calendars/SimpleWeekYearRuleTest.generated.dart' as scenarios;

// C#: (DayOfWeek[])Enum.GetValues(typeof(DayOfWeek)), as names and numeric values.
const List<(String, int)> BclDaysOfWeek = [
  ('Sunday', 0), ('Monday', 1), ('Tuesday', 2), ('Wednesday', 3), ('Thursday', 4), ('Friday', 5), ('Saturday', 6),
];
// C#: (CalendarWeekRule[])Enum.GetValues(typeof(CalendarWeekRule)).
const List<(String, int)> CalendarWeekRules = [('FirstDay', 0), ('FirstFullWeek', 1), ('FirstFourDayWeek', 2)];

void main() {
  final Map<String, TestBody> bodies = {
    'RoundtripFirstDay_Iso7': (args) {
      // In the Gregorian calendar with a minimum of 7 days in the first
      // week, Tuesday January 1st -9998 is in week year -9999. We should be able to
      // round-trip.
      var rule = WeekYearRules.ForMinDaysInFirstWeek(7);
      var date = LocalDate(-9998, 1, 1);
      Assert.AreEqual(date, WeekYearRuleExtensions(rule).GetLocalDate(
          rule.GetWeekYear(date),
          rule.GetWeekOfWeekYear(date),
          date.DayOfWeek));
    },

    'RoundtripLastDay_Iso1': (args) {
      // In the Gregorian calendar with a minimum of 1 day in the first
      // week, Friday December 31st 9999 is in week year 10000. We should be able to
      // round-trip.
      var rule = WeekYearRules.ForMinDaysInFirstWeek(1);
      var date = LocalDate(9999, 12, 31);
      Assert.AreEqual(date, WeekYearRuleExtensions(rule).GetLocalDate(
          rule.GetWeekYear(date),
          rule.GetWeekOfWeekYear(date),
          date.DayOfWeek));
    },

    /// As RoundtripFirstDay_Iso7 and RoundtripLastDay_Iso1, for every calendar and rule:
    /// the first and last days of a calendar may be in the week-year before its first year or after its last year, which
    /// [IWeekYearRule.GetLocalDate] documents as valid.
    'RoundtripFirstAndLastDays_AllCalendars': (args) {
      final [String calendarId, IWeekYearRule rule] = args;
      var calendar = CalendarSystem.ForId(calendarId);
      var firstDay = LocalDate(calendar.MinYear, 1, 1, calendar);
      var lastMonth = calendar.GetMonthsInYear(calendar.MaxYear);
      var lastDay = LocalDate(calendar.MaxYear, lastMonth, calendar.GetDaysInMonth(calendar.MaxYear, lastMonth), calendar);

      for (var date in [firstDay, lastDay]) {
        var weekYear = rule.GetWeekYear(date);
        var weekOfWeekYear = rule.GetWeekOfWeekYear(date);
        Assert.That(weekOfWeekYear, Is.InRange(1, rule.GetWeeksInWeekYear(weekYear, calendar)), '${date.Year}-${date.Month}-${date.Day}');
        Assert.AreEqual(date, rule.GetLocalDate(weekYear, weekOfWeekYear, date.DayOfWeek, calendar), '${date.Year}-${date.Month}-${date.Day}');
      }
    },

    'FirstDayInWeekYearBeforeFirstYear_Badi': (args) {
      // 1 Bahá 1 BE is Thursday March 21st 1844. With weeks starting on Monday and at least 5 days in the first
      // week, its week (Monday March 18th to Sunday March 24th 1844) has only 4 days in year 1, so it's the last
      // week of week-year 0. Year 0 starts on Tuesday March 21st 1843, so week 1 of week-year 0 starts on Monday
      // March 20th 1843, and the week of 1 Bahá 1 is week 53.
      var rule = WeekYearRules.ForMinDaysInFirstWeek(5, IsoDayOfWeek.Monday);
      var date = LocalDate(1, 1, 1, CalendarSystem.Badi);
      Assert.AreEqual(LocalDate(1844, 3, 21), date.WithCalendar(CalendarSystem.Iso));
      Assert.AreEqual(0, rule.GetWeekYear(date));
      Assert.AreEqual(53, rule.GetWeekOfWeekYear(date));
      Assert.AreEqual(53, rule.GetWeeksInWeekYear(0, CalendarSystem.Badi));
      Assert.AreEqual(date, rule.GetLocalDate(0, 53, IsoDayOfWeek.Thursday, CalendarSystem.Badi));
    },

    'OutOfRange_ValidWeekYearAndWeek_TooEarly': (args) {
      // Gregorian 4: Week year 1 starts on Monday December 31st -9999,
      // and is therefore out of range, even though the week-year
      // and week-of-week-year are valid.
      Assert.Throws<RangeError>(
          () => WeekYearRuleExtensions(WeekYearRules.Iso).GetLocalDate(-9998, 1, IsoDayOfWeek.Monday));

      // Sanity check: no exception for January 1st
      WeekYearRuleExtensions(WeekYearRules.Iso).GetLocalDate(-9998, 1, IsoDayOfWeek.Tuesday);
    },

    'OutOfRange_ValidWeekYearAndWeek_TooLate': (args) {
      // Gregorian 4: December 31st 9999 is a Friday, so the Saturday of the
      // same week is therefore out of range, even though the week-year
      // and week-of-week-year are valid.
      Assert.Throws<RangeError>(
          () => WeekYearRuleExtensions(WeekYearRules.Iso).GetLocalDate(9999, 52, IsoDayOfWeek.Saturday));

      // Sanity check: no exception for December 31st
      WeekYearRuleExtensions(WeekYearRules.Iso).GetLocalDate(9999, 52, IsoDayOfWeek.Friday);
    },

    // Tests ported from IsoCalendarSystemTest and LocalDateTest.Construction
    'WeekYearDifferentToYear': (args) {
      final [int year, int month, int day, int weekYear, int weekOfWeekYear, IsoDayOfWeek dayOfWeek] = args;
      var date = LocalDate(year, month, day);
      Assert.AreEqual(weekYear, WeekYearRules.Iso.GetWeekYear(date));
      Assert.AreEqual(weekOfWeekYear, WeekYearRules.Iso.GetWeekOfWeekYear(date));
      Assert.AreEqual(dayOfWeek, date.DayOfWeek);
      Assert.AreEqual(date, WeekYearRuleExtensions(WeekYearRules.Iso).GetLocalDate(weekYear, weekOfWeekYear, dayOfWeek));
    },

    // Ported from CalendarSystemTest.Validation
    'GetWeeksInWeekYear(int, int)': (args) {
      final [int weekYear, int expectedResult] = args;
      Assert.AreEqual(expectedResult, WeekYearRuleExtensions(WeekYearRules.Iso).GetWeeksInWeekYear(weekYear));
    },

    // Ported from LocalDateTest.BasicProperties
    // See https://stackoverflow.com/questions/8010125
    'WeekOfWeekYear_ComparisonWithOracle': (args) {
      final [int year, int month, int day, int weekOfWeekYear] = args;
      var date = LocalDate(year, month, day);
      Assert.AreEqual(weekOfWeekYear, WeekYearRules.Iso.GetWeekOfWeekYear(date));
    },

    'Gregorian': (args) {
      final [int year, IsoDayOfWeek firstDayOfYear, int maxMinDaysInFirstWeekForSameWeekYear] = args;
      var startOfCalendarYear = LocalDate(year, 1, 1);
      Assert.AreEqual(firstDayOfYear, startOfCalendarYear.DayOfWeek);

      // Rules which put the first day of the calendar year into the same week year
      for (int i = 1; i <= maxMinDaysInFirstWeekForSameWeekYear; i++) {
        var rule = WeekYearRules.ForMinDaysInFirstWeek(i);
        Assert.AreEqual(year, rule.GetWeekYear(startOfCalendarYear));
        Assert.AreEqual(1, rule.GetWeekOfWeekYear(startOfCalendarYear));
      }
      // Rules which put the first day of the calendar year into the previous week year
      for (int i = maxMinDaysInFirstWeekForSameWeekYear + 1; i <= 7; i++) {
        var rule = WeekYearRules.ForMinDaysInFirstWeek(i);
        Assert.AreEqual(year - 1, rule.GetWeekYear(startOfCalendarYear));
        Assert.AreEqual(WeekYearRuleExtensions(rule).GetWeeksInWeekYear(year - 1), rule.GetWeekOfWeekYear(startOfCalendarYear));
      }
    },

    // Test cases from https://blogs.msdn.microsoft.com/shawnste/2006/01/24/iso-8601-week-of-year-format-in-microsoft-net/
    // which distinguish our ISO option from the BCL. When we implement the BCL equivalents, we should have similar
    // tests there...
    'Iso': (args) {
      final [int year, int month, int day, int weekYear, int weekOfWeekYear, IsoDayOfWeek dayOfWeek] = args;
      var viaCalendar = LocalDate(year, month, day);
      var rule = WeekYearRules.Iso;
      Assert.AreEqual(weekYear, rule.GetWeekYear(viaCalendar));
      Assert.AreEqual(weekOfWeekYear, rule.GetWeekOfWeekYear(viaCalendar));
      Assert.AreEqual(dayOfWeek, viaCalendar.DayOfWeek);
      var viaRule = WeekYearRuleExtensions(rule).GetLocalDate(weekYear, weekOfWeekYear, dayOfWeek);
      Assert.AreEqual(viaCalendar, viaRule);
    },

    /// Just a sample test of not using the Gregorian/ISO calendar system.
    'HebrewCalendar': (args) {
      final [
        int year, IsoDayOfWeek expectedFirstDay,
        int isoYear, int isoMonth, int isoDay, // Mostly for documentation
        int expectedWeeks, int expectedWeekYearOfFirstDay, int expectedWeekOfWeekYearOfFirstDay,
      ] = args;
      var civilDate = LocalDate(year, 1, 1, CalendarSystem.HebrewCivil);
      var rule = WeekYearRules.Iso;
      Assert.AreEqual(expectedFirstDay, civilDate.DayOfWeek);
      Assert.AreEqual(civilDate.WithCalendar(CalendarSystem.Iso), LocalDate(isoYear, isoMonth, isoDay));
      Assert.AreEqual(expectedWeeks, rule.GetWeeksInWeekYear(year, CalendarSystem.HebrewCivil));
      Assert.AreEqual(expectedWeekYearOfFirstDay, rule.GetWeekYear(civilDate));
      Assert.AreEqual(expectedWeekOfWeekYearOfFirstDay, rule.GetWeekOfWeekYear(civilDate));
      Assert.AreEqual(civilDate,
          rule.GetLocalDate(expectedWeekYearOfFirstDay, expectedWeekOfWeekYearOfFirstDay, expectedFirstDay, CalendarSystem.HebrewCivil));

      // The scriptural month numbering system should have the same week-year and week-of-week-year.
      var scripturalDate = civilDate.WithCalendar(CalendarSystem.HebrewScriptural);
      Assert.AreEqual(expectedWeeks, rule.GetWeeksInWeekYear(year, CalendarSystem.HebrewScriptural));
      Assert.AreEqual(expectedWeekYearOfFirstDay, rule.GetWeekYear(scripturalDate));
      Assert.AreEqual(expectedWeekOfWeekYearOfFirstDay, rule.GetWeekOfWeekYear(scripturalDate));
      Assert.AreEqual(scripturalDate,
          rule.GetLocalDate(expectedWeekYearOfFirstDay, expectedWeekOfWeekYearOfFirstDay, expectedFirstDay, CalendarSystem.HebrewScriptural));
    },

    // Jan 1st 2015 = Thursday
    // Jan 1st 2016 = Friday
    // Jan 1st 2017 = Sunday
    'NonMondayFirstDayOfWeek': (args) {
      final [
        int minDaysInFirstWeek, IsoDayOfWeek firstDayOfWeek,
        int weekYear, int week, IsoDayOfWeek dayOfWeek,
        int expectedYear, int expectedMonth, int expectedDay,
      ] = args;
      var rule = WeekYearRules.ForMinDaysInFirstWeek(minDaysInFirstWeek, firstDayOfWeek);
      var actual = WeekYearRuleExtensions(rule).GetLocalDate(weekYear, week, dayOfWeek);
      var expected = LocalDate(expectedYear, expectedMonth, expectedDay);
      Assert.AreEqual(expected, actual);
      Assert.AreEqual(weekYear, rule.GetWeekYear(actual));
      Assert.AreEqual(week, rule.GetWeekOfWeekYear(actual));
    },

    // Tests for BCL rules...

    // Tests where we ask for an invalid combination of week-year/week/day-of-week due to a week being "short"
    // in BCL rules.
    // Jan 1st 2016 = Friday
    'GetLocalDate_Invalid': (args) {
      final [int bclRule, int firstDayOfWeek, int weekYear, int week, IsoDayOfWeek dayOfWeek] = args;
      var nodaRule = WeekYearRules.FromCalendarWeekRule(bclRule, firstDayOfWeek);
      Assert.Throws<RangeError>(() => WeekYearRuleExtensions(nodaRule).GetLocalDate(weekYear, week, dayOfWeek));
    },

    'RoundtripFirstDayBcl': (args) {
      final [int bclRule, int firstDayOfWeek] = args;
      var rule = WeekYearRules.FromCalendarWeekRule(bclRule, firstDayOfWeek);
      var date = LocalDate(-9998, 1, 1);
      Assert.AreEqual(date, WeekYearRuleExtensions(rule).GetLocalDate(
          rule.GetWeekYear(date),
          rule.GetWeekOfWeekYear(date),
          date.DayOfWeek));
    },

    'RoundtripLastDayBcl': (args) {
      final [int bclRule, int firstDayOfWeek] = args;
      var rule = WeekYearRules.FromCalendarWeekRule(bclRule, firstDayOfWeek);
      var date = LocalDate(9999, 12, 31);
      Assert.AreEqual(date, WeekYearRuleExtensions(rule).GetLocalDate(
          rule.GetWeekYear(date),
          rule.GetWeekOfWeekYear(date),
          date.DayOfWeek));
    },

    // TODO: Test the difference in ValidateWeekYear for 9999 between regular and non-regular rules.
  };

  port(scenarios.fixture, bodies, skip: {
    /// For each calendar and rule combination, check everything we can about every date
    /// from mid December to mid January around each year between 2016 and 2046.
    'BclEquivalence': "Uses .NET's System.Globalization.Calendar.GetWeekOfYear as the oracle",
    /// The number of weeks in the year is equal to the week-of-week-year for the last
    /// day of the year.
    'GetWeeksInWeekYear(Calendar, CalendarWeekRule, DayOfWeek)':
        "Uses .NET's System.Globalization.Calendar.GetWeekOfYear as the oracle",
  });

      // noda_dart: RoundtripFirstAndLastDays_AllCalendars' CalendarBoundaryRules cases.
  group('${scenarios.fixture.name} CalendarBoundaryRules', () {
    for (var (calendarId, name, rule) in CalendarBoundaryRules()) {
      test(name, () => bodies['RoundtripFirstAndLastDays_AllCalendars']!([calendarId, rule]));
    }
  });
}

/// noda_dart: each case is (calendarId, the NUnit test name C# sets, rule).
Iterable<(String, String, IWeekYearRule)> CalendarBoundaryRules() sync* {
  var rules = <(String, IWeekYearRule)>[];
  for (var minDays = 1; minDays <= 7; minDays++) {
    // C#: Enum.GetValues(typeof(IsoDayOfWeek)).Cast<IsoDayOfWeek>().Where(firstDayOfWeek => firstDayOfWeek != None)
    rules.addAll([for (var day = IsoDayOfWeek.Monday.value; day <= IsoDayOfWeek.Sunday.value; day++) IsoDayOfWeek(day)]
        .map((firstDayOfWeek) => (
              'ForMinDaysInFirstWeek($minDays, ${firstDayOfWeek.Name})',
              WeekYearRules.ForMinDaysInFirstWeek(minDays, firstDayOfWeek))));
  }
  for (var (calendarWeekRuleName, calendarWeekRule) in CalendarWeekRules) {
    rules.addAll(BclDaysOfWeek
        .map((bclDayOfWeek) => (
              'FromCalendarWeekRule($calendarWeekRuleName, ${bclDayOfWeek.$1})',
              WeekYearRules.FromCalendarWeekRule(calendarWeekRule, bclDayOfWeek.$2))));
  }

  for (var calendarId in CalendarSystem.Ids) {
    for (var (name, rule) in rules) {
      yield (calendarId, 'RoundtripFirstAndLastDays_AllCalendars($calendarId, $name)', rule);
    }
  }
}
