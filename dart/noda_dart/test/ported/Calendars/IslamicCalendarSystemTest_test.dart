// Ported from NodaTime 6e024dde: src/NodaTime.Test/Calendars/IslamicCalendarSystemTest.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda_dart: the generated enums have no list of values, so Epochs and LeapYearPatterns list them.

import 'dart:collection';
import 'dart:math' as math;

import 'package:noda_dart/src/CalendarSystem.dart';
import 'package:noda_dart/src/Calendars/Era.dart';
import 'package:noda_dart/src/Calendars/IslamicEpoch.generated.dart';
import 'package:noda_dart/src/Calendars/IslamicLeapYearPattern.generated.dart';
import 'package:noda_dart/src/Calendars/IslamicYearMonthDayCalculator.dart';
import 'package:noda_dart/src/IsoDayOfWeek.generated.dart';
import 'package:noda_dart/src/LocalDate.dart';
import 'package:noda_dart/src/LocalDateTime.dart';

import '../../helpers/Assertions.dart';
import '../../helpers/Scenarios.dart';
import '../../scenarios/Calendars/IslamicCalendarSystemTest.generated.dart' as scenarios;

final CalendarSystem SampleCalendar = CalendarSystem.GetIslamicCalendar(IslamicLeapYearPattern.Base16, IslamicEpoch.Civil);
// C#: Enum.GetValues(typeof(IslamicEpoch)).Cast<IslamicEpoch>()
const List<IslamicEpoch> Epochs = [IslamicEpoch.Astronomical, IslamicEpoch.Civil];
// C#: Enum.GetValues(typeof(IslamicLeapYearPattern)).Cast<IslamicLeapYearPattern>()
const List<IslamicLeapYearPattern> LeapYearPatterns = [
  IslamicLeapYearPattern.Base15,
  IslamicLeapYearPattern.Base16,
  IslamicLeapYearPattern.Indian,
  IslamicLeapYearPattern.HabashAlHasib,
];

void main() {
  port(scenarios.fixture, {
    'SampleDate1': (args) {
      // Note: field checks removed from the tests.
      LocalDateTime ldt = LocalDateTime(1945, 11, 12, 0, 0, 0, 0, CalendarSystem.Iso);

      ldt = ldt.WithCalendar(SampleCalendar);
      Assert.AreEqual(Era.AnnoHegirae, ldt.Era);
      Assert.AreEqual(1364, ldt.YearOfEra);

      Assert.AreEqual(1364, ldt.Year);
      Assert.AreEqual(12, ldt.Month);
      Assert.AreEqual(6, ldt.Day);
      Assert.AreEqual(IsoDayOfWeek.Monday, ldt.DayOfWeek);
      Assert.AreEqual(6 * 30 + 5 * 29 + 6, ldt.DayOfYear);

      Assert.AreEqual(0, ldt.Hour);
      Assert.AreEqual(0, ldt.Minute);
      Assert.AreEqual(0, ldt.Second);
      Assert.AreEqual(0, ldt.TickOfSecond);
    },

    'SampleDate2': (args) {
      LocalDateTime ldt = LocalDateTime(2005, 11, 26, 0, 0, 0, 0, CalendarSystem.Iso);
      ldt = ldt.WithCalendar(SampleCalendar);
      Assert.AreEqual(Era.AnnoHegirae, ldt.Era);
      Assert.AreEqual(1426, ldt.YearOfEra);

      Assert.AreEqual(1426, ldt.Year);
      Assert.AreEqual(10, ldt.Month);
      Assert.AreEqual(24, ldt.Day);
      Assert.AreEqual(IsoDayOfWeek.Saturday, ldt.DayOfWeek);
      Assert.AreEqual(5 * 30 + 4 * 29 + 24, ldt.DayOfYear);
      Assert.AreEqual(0, ldt.Hour);
      Assert.AreEqual(0, ldt.Minute);
      Assert.AreEqual(0, ldt.Second);
      Assert.AreEqual(0, ldt.TickOfSecond);
    },

    'SampleDate3': (args) {
      LocalDateTime ldt = LocalDateTime(1426, 12, 24, 0, 0, 0, 0, SampleCalendar);
      Assert.AreEqual(Era.AnnoHegirae, ldt.Era);

      Assert.AreEqual(1426, ldt.Year);
      Assert.AreEqual(12, ldt.Month);
      Assert.AreEqual(24, ldt.Day);
      Assert.AreEqual(IsoDayOfWeek.Tuesday, ldt.DayOfWeek);
      Assert.AreEqual(6 * 30 + 5 * 29 + 24, ldt.DayOfYear);
      Assert.AreEqual(0, ldt.Hour);
      Assert.AreEqual(0, ldt.Minute);
      Assert.AreEqual(0, ldt.Second);
      Assert.AreEqual(0, ldt.TickOfSecond);
    },

    'InternalConsistency': (args) {
      var calendar = CalendarSystem.GetIslamicCalendar(IslamicLeapYearPattern.Base15, IslamicEpoch.Civil);
      // Check construction and then deconstruction for every day of every year in one 30-year cycle.
      for (int year = 1; year <= 30; year++) {
        for (int month = 1; month <= 12; month++) {
          int monthLength = calendar.GetDaysInMonth(year, month);
          for (int day = 1; day < monthLength; day++) {
            LocalDate date = LocalDate(year, month, day, calendar);
            Assert.AreEqual(year, date.Year, 'Year of $year-$month-$day');
            Assert.AreEqual(month, date.Month, 'Month of $year-$month-$day');
            Assert.AreEqual(day, date.Day, 'Day of $year-$month-$day');
          }
        }
      }
    },

    'Base15LeapYear': (args) {
      CalendarSystem calendar = CalendarSystem.GetIslamicCalendar(IslamicLeapYearPattern.Base15, IslamicEpoch.Civil);

      Assert.AreEqual(false, calendar.IsLeapYear(1));
      Assert.AreEqual(true, calendar.IsLeapYear(2));
      Assert.AreEqual(false, calendar.IsLeapYear(3));
      Assert.AreEqual(false, calendar.IsLeapYear(4));
      Assert.AreEqual(true, calendar.IsLeapYear(5));
      Assert.AreEqual(false, calendar.IsLeapYear(6));
      Assert.AreEqual(true, calendar.IsLeapYear(7));
      Assert.AreEqual(false, calendar.IsLeapYear(8));
      Assert.AreEqual(false, calendar.IsLeapYear(9));
      Assert.AreEqual(true, calendar.IsLeapYear(10));
      Assert.AreEqual(false, calendar.IsLeapYear(11));
      Assert.AreEqual(false, calendar.IsLeapYear(12));
      Assert.AreEqual(true, calendar.IsLeapYear(13));
      Assert.AreEqual(false, calendar.IsLeapYear(14));
      Assert.AreEqual(true, calendar.IsLeapYear(15));
      Assert.AreEqual(false, calendar.IsLeapYear(16));
      Assert.AreEqual(false, calendar.IsLeapYear(17));
      Assert.AreEqual(true, calendar.IsLeapYear(18));
      Assert.AreEqual(false, calendar.IsLeapYear(19));
      Assert.AreEqual(false, calendar.IsLeapYear(20));
      Assert.AreEqual(true, calendar.IsLeapYear(21));
      Assert.AreEqual(false, calendar.IsLeapYear(22));
      Assert.AreEqual(false, calendar.IsLeapYear(23));
      Assert.AreEqual(true, calendar.IsLeapYear(24));
      Assert.AreEqual(false, calendar.IsLeapYear(25));
      Assert.AreEqual(true, calendar.IsLeapYear(26));
      Assert.AreEqual(false, calendar.IsLeapYear(27));
      Assert.AreEqual(false, calendar.IsLeapYear(28));
      Assert.AreEqual(true, calendar.IsLeapYear(29));
      Assert.AreEqual(false, calendar.IsLeapYear(30));
    },

    'Base16LeapYear': (args) {
      CalendarSystem calendar = CalendarSystem.GetIslamicCalendar(IslamicLeapYearPattern.Base16, IslamicEpoch.Civil);

      Assert.AreEqual(false, calendar.IsLeapYear(1));
      Assert.AreEqual(true, calendar.IsLeapYear(2));
      Assert.AreEqual(false, calendar.IsLeapYear(3));
      Assert.AreEqual(false, calendar.IsLeapYear(4));
      Assert.AreEqual(true, calendar.IsLeapYear(5));
      Assert.AreEqual(false, calendar.IsLeapYear(6));
      Assert.AreEqual(true, calendar.IsLeapYear(7));
      Assert.AreEqual(false, calendar.IsLeapYear(8));
      Assert.AreEqual(false, calendar.IsLeapYear(9));
      Assert.AreEqual(true, calendar.IsLeapYear(10));
      Assert.AreEqual(false, calendar.IsLeapYear(11));
      Assert.AreEqual(false, calendar.IsLeapYear(12));
      Assert.AreEqual(true, calendar.IsLeapYear(13));
      Assert.AreEqual(false, calendar.IsLeapYear(14));
      Assert.AreEqual(false, calendar.IsLeapYear(15));
      Assert.AreEqual(true, calendar.IsLeapYear(16));
      Assert.AreEqual(false, calendar.IsLeapYear(17));
      Assert.AreEqual(true, calendar.IsLeapYear(18));
      Assert.AreEqual(false, calendar.IsLeapYear(19));
      Assert.AreEqual(false, calendar.IsLeapYear(20));
      Assert.AreEqual(true, calendar.IsLeapYear(21));
      Assert.AreEqual(false, calendar.IsLeapYear(22));
      Assert.AreEqual(false, calendar.IsLeapYear(23));
      Assert.AreEqual(true, calendar.IsLeapYear(24));
      Assert.AreEqual(false, calendar.IsLeapYear(25));
      Assert.AreEqual(true, calendar.IsLeapYear(26));
      Assert.AreEqual(false, calendar.IsLeapYear(27));
      Assert.AreEqual(false, calendar.IsLeapYear(28));
      Assert.AreEqual(true, calendar.IsLeapYear(29));
      Assert.AreEqual(false, calendar.IsLeapYear(30));
    },

    'IndianBasedLeapYear': (args) {
      CalendarSystem calendar = CalendarSystem.GetIslamicCalendar(IslamicLeapYearPattern.Indian, IslamicEpoch.Civil);

      Assert.AreEqual(false, calendar.IsLeapYear(1));
      Assert.AreEqual(true, calendar.IsLeapYear(2));
      Assert.AreEqual(false, calendar.IsLeapYear(3));
      Assert.AreEqual(false, calendar.IsLeapYear(4));
      Assert.AreEqual(true, calendar.IsLeapYear(5));
      Assert.AreEqual(false, calendar.IsLeapYear(6));
      Assert.AreEqual(false, calendar.IsLeapYear(7));
      Assert.AreEqual(true, calendar.IsLeapYear(8));
      Assert.AreEqual(false, calendar.IsLeapYear(9));
      Assert.AreEqual(true, calendar.IsLeapYear(10));
      Assert.AreEqual(false, calendar.IsLeapYear(11));
      Assert.AreEqual(false, calendar.IsLeapYear(12));
      Assert.AreEqual(true, calendar.IsLeapYear(13));
      Assert.AreEqual(false, calendar.IsLeapYear(14));
      Assert.AreEqual(false, calendar.IsLeapYear(15));
      Assert.AreEqual(true, calendar.IsLeapYear(16));
      Assert.AreEqual(false, calendar.IsLeapYear(17));
      Assert.AreEqual(false, calendar.IsLeapYear(18));
      Assert.AreEqual(true, calendar.IsLeapYear(19));
      Assert.AreEqual(false, calendar.IsLeapYear(20));
      Assert.AreEqual(true, calendar.IsLeapYear(21));
      Assert.AreEqual(false, calendar.IsLeapYear(22));
      Assert.AreEqual(false, calendar.IsLeapYear(23));
      Assert.AreEqual(true, calendar.IsLeapYear(24));
      Assert.AreEqual(false, calendar.IsLeapYear(25));
      Assert.AreEqual(false, calendar.IsLeapYear(26));
      Assert.AreEqual(true, calendar.IsLeapYear(27));
      Assert.AreEqual(false, calendar.IsLeapYear(28));
      Assert.AreEqual(true, calendar.IsLeapYear(29));
      Assert.AreEqual(false, calendar.IsLeapYear(30));
    },

    'HabashAlHasibBasedLeapYear': (args) {
      CalendarSystem calendar = CalendarSystem.GetIslamicCalendar(IslamicLeapYearPattern.HabashAlHasib, IslamicEpoch.Civil);

      Assert.AreEqual(false, calendar.IsLeapYear(1));
      Assert.AreEqual(true, calendar.IsLeapYear(2));
      Assert.AreEqual(false, calendar.IsLeapYear(3));
      Assert.AreEqual(false, calendar.IsLeapYear(4));
      Assert.AreEqual(true, calendar.IsLeapYear(5));
      Assert.AreEqual(false, calendar.IsLeapYear(6));
      Assert.AreEqual(false, calendar.IsLeapYear(7));
      Assert.AreEqual(true, calendar.IsLeapYear(8));
      Assert.AreEqual(false, calendar.IsLeapYear(9));
      Assert.AreEqual(false, calendar.IsLeapYear(10));
      Assert.AreEqual(true, calendar.IsLeapYear(11));
      Assert.AreEqual(false, calendar.IsLeapYear(12));
      Assert.AreEqual(true, calendar.IsLeapYear(13));
      Assert.AreEqual(false, calendar.IsLeapYear(14));
      Assert.AreEqual(false, calendar.IsLeapYear(15));
      Assert.AreEqual(true, calendar.IsLeapYear(16));
      Assert.AreEqual(false, calendar.IsLeapYear(17));
      Assert.AreEqual(false, calendar.IsLeapYear(18));
      Assert.AreEqual(true, calendar.IsLeapYear(19));
      Assert.AreEqual(false, calendar.IsLeapYear(20));
      Assert.AreEqual(true, calendar.IsLeapYear(21));
      Assert.AreEqual(false, calendar.IsLeapYear(22));
      Assert.AreEqual(false, calendar.IsLeapYear(23));
      Assert.AreEqual(true, calendar.IsLeapYear(24));
      Assert.AreEqual(false, calendar.IsLeapYear(25));
      Assert.AreEqual(false, calendar.IsLeapYear(26));
      Assert.AreEqual(true, calendar.IsLeapYear(27));
      Assert.AreEqual(false, calendar.IsLeapYear(28));
      Assert.AreEqual(false, calendar.IsLeapYear(29));
      Assert.AreEqual(true, calendar.IsLeapYear(30));
    },

    'ThursdayEpoch': (args) {
      CalendarSystem thursdayEpochCalendar = CalendarSystem.IslamicBcl;
      CalendarSystem julianCalendar = CalendarSystem.Julian;

      LocalDate thursdayEpoch = LocalDate(1, 1, 1, thursdayEpochCalendar);
      LocalDate thursdayEpochJulian = LocalDate(622, 7, 15, julianCalendar);
      Assert.AreEqual(thursdayEpochJulian, thursdayEpoch.WithCalendar(julianCalendar));
    },

    'FridayEpoch': (args) {
      CalendarSystem fridayEpochCalendar = CalendarSystem.GetIslamicCalendar(IslamicLeapYearPattern.Base16, IslamicEpoch.Civil);
      CalendarSystem julianCalendar = CalendarSystem.Julian;

      LocalDate fridayEpoch = LocalDate(1, 1, 1, fridayEpochCalendar);
      LocalDate fridayEpochJulian = LocalDate(622, 7, 16, julianCalendar);
      Assert.AreEqual(fridayEpochJulian, fridayEpoch.WithCalendar(julianCalendar));
    },

    'GetDaysInMonth': (args) {
      // Just check that we've got the long/short the right way round...
      CalendarSystem calendar = CalendarSystem.GetIslamicCalendar(IslamicLeapYearPattern.HabashAlHasib, IslamicEpoch.Civil);
      Assert.AreEqual(30, calendar.GetDaysInMonth(7, 1));
      Assert.AreEqual(29, calendar.GetDaysInMonth(7, 2));
      Assert.AreEqual(30, calendar.GetDaysInMonth(7, 3));
      Assert.AreEqual(29, calendar.GetDaysInMonth(7, 4));
      Assert.AreEqual(30, calendar.GetDaysInMonth(7, 5));
      Assert.AreEqual(29, calendar.GetDaysInMonth(7, 6));
      Assert.AreEqual(30, calendar.GetDaysInMonth(7, 7));
      Assert.AreEqual(29, calendar.GetDaysInMonth(7, 8));
      Assert.AreEqual(30, calendar.GetDaysInMonth(7, 9));
      Assert.AreEqual(29, calendar.GetDaysInMonth(7, 10));
      Assert.AreEqual(30, calendar.GetDaysInMonth(7, 11));
      // As noted before, 7 isn't a leap year in this calendar
      Assert.AreEqual(29, calendar.GetDaysInMonth(7, 12));
      // As noted before, 8 is a leap year in this calendar
      Assert.AreEqual(30, calendar.GetDaysInMonth(8, 12));
    },

    'GetInstance_Caching': (args) {
      var queue = Queue<CalendarSystem>();
      var set = HashSet<CalendarSystem>();
      var ids = HashSet<String>();

      for (var leapYearPattern in LeapYearPatterns) {
        for (var epoch in Epochs) {
          var calendar = CalendarSystem.GetIslamicCalendar(leapYearPattern, epoch);
          queue.add(calendar);
          Assert.IsTrue(set.add(calendar)); // Check we haven't already seen it...
          Assert.IsTrue(ids.add(calendar.Id));
        }
      }

      // Now check we get the same references again...
      for (var leapYearPattern in LeapYearPatterns) {
        for (var epoch in Epochs) {
          var oldCalendar = queue.removeFirst();
          var newCalendar = CalendarSystem.GetIslamicCalendar(leapYearPattern, epoch);
          Assert.AreSame(oldCalendar, newCalendar);
        }
      }
    },

    'GetInstance_ArgumentValidation': (args) {
      Assert.Throws<RangeError>(() => CalendarSystem.GetIslamicCalendar(IslamicLeapYearPattern(Min(LeapYearPatterns.map((x) => x.value)) - 1), IslamicEpoch(Min(Epochs.map((x) => x.value)))));
      Assert.Throws<RangeError>(() => CalendarSystem.GetIslamicCalendar(IslamicLeapYearPattern(Min(LeapYearPatterns.map((x) => x.value))), IslamicEpoch(Min(Epochs.map((x) => x.value)) - 1)));
      Assert.Throws<RangeError>(() => CalendarSystem.GetIslamicCalendar(IslamicLeapYearPattern(Max(LeapYearPatterns.map((x) => x.value)) + 1), IslamicEpoch(Min(Epochs.map((x) => x.value)))));
      Assert.Throws<RangeError>(() => CalendarSystem.GetIslamicCalendar(IslamicLeapYearPattern(Min(LeapYearPatterns.map((x) => x.value))), IslamicEpoch(Max(Epochs.map((x) => x.value)) + 1)));
    },

    'PlusYears_Simple': (args) {
      var calendar = CalendarSystem.GetIslamicCalendar(IslamicLeapYearPattern.Base15, IslamicEpoch.Civil);
      LocalDateTime start = LocalDateTime.YearMonthDayHourMinuteCalendar(5, 8, 20, 2, 0, calendar);
      LocalDateTime expectedEnd = LocalDateTime.YearMonthDayHourMinuteCalendar(10, 8, 20, 2, 0, calendar);
      Assert.AreEqual(expectedEnd, start.PlusYears(5));
    },

    'PlusYears_TruncatesAtLeapYear': (args) {
      var calendar = CalendarSystem.GetIslamicCalendar(IslamicLeapYearPattern.Base15, IslamicEpoch.Civil);
      Assert.IsTrue(calendar.IsLeapYear(2));
      Assert.IsFalse(calendar.IsLeapYear(3));

      LocalDateTime start = LocalDateTime.YearMonthDayHourMinuteCalendar(2, 12, 30, 2, 0, calendar);
      LocalDateTime expectedEnd = LocalDateTime.YearMonthDayHourMinuteCalendar(3, 12, 29, 2, 0, calendar);

      Assert.AreEqual(expectedEnd, start.PlusYears(1));
    },

    'PlusYears_DoesNotTruncateFromOneLeapYearToAnother': (args) {
      var calendar = CalendarSystem.GetIslamicCalendar(IslamicLeapYearPattern.Base15, IslamicEpoch.Civil);
      Assert.IsTrue(calendar.IsLeapYear(2));
      Assert.IsTrue(calendar.IsLeapYear(5));

      LocalDateTime start = LocalDateTime.YearMonthDayHourMinuteCalendar(2, 12, 30, 2, 0, calendar);
      LocalDateTime expectedEnd = LocalDateTime.YearMonthDayHourMinuteCalendar(5, 12, 30, 2, 0, calendar);

      Assert.AreEqual(expectedEnd, start.PlusYears(3));
    },

    'PlusMonths_Simple': (args) {
      var calendar = CalendarSystem.GetIslamicCalendar(IslamicLeapYearPattern.Base15, IslamicEpoch.Civil);
      Assert.IsTrue(calendar.IsLeapYear(2));

      LocalDateTime start = LocalDateTime.YearMonthDayHourMinuteCalendar(2, 12, 30, 2, 0, calendar);
      LocalDateTime expectedEnd = LocalDateTime.YearMonthDayHourMinuteCalendar(3, 11, 30, 2, 0, calendar);
      Assert.AreEqual(11, expectedEnd.Month);
      Assert.AreEqual(30, expectedEnd.Day);
      Assert.AreEqual(expectedEnd, start.PlusMonths(11));
    },

    'Constructor_InvalidEnumsForCoverage': (args) {
      Assert.Throws<RangeError>(() => IslamicYearMonthDayCalculator.NewLeapYearPatternEpoch(IslamicLeapYearPattern(IslamicLeapYearPattern.Base15.value + 100), IslamicEpoch.Astronomical));
      Assert.Throws<RangeError>(() => IslamicYearMonthDayCalculator.NewLeapYearPatternEpoch(IslamicLeapYearPattern.Base15, IslamicEpoch(IslamicEpoch.Astronomical.value + 100)));
    },
  }, skip: {
    'BclUsesAstronomicalEpoch': SkipReasons.BclCalendar,
    'SampleDateBclCompatibility': SkipReasons.BclCalendar,
    'BclThroughHistory': SkipReasons.BclCalendar,
  });
}

/// noda_dart: LINQ's Min() over the enums' values.
int Min(Iterable<int> values) => values.reduce(math.min);

/// noda_dart: LINQ's Max() over the enums' values.
int Max(Iterable<int> values) => values.reduce(math.max);
