// Ported from NodaTime 6e024dde: src/NodaTime.Test/YearMonthDayCalendarTest.cs
// Copyright 2014 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:noda_dart/src/CalendarOrdinal.generated.dart';
import 'package:noda_dart/src/YearMonthDayCalendar.dart';

import '../helpers/Assertions.dart';
import '../helpers/Scenarios.dart';
import '../helpers/TestHelper.dart';
import '../scenarios/YearMonthDayCalendarTest.generated.dart' as scenarios;

void main() {
  port(scenarios.fixture, {
    'AllYears': (args) {
      // Range of years we actually care about. We support more, but that's okay.
      for (int year = -9999; year <= 9999; year++) {
        var ymdc = YearMonthDayCalendar.NewYearMonthDayCalendarOrdinal(year, 5, 20, CalendarOrdinal(0));
        Assert.AreEqual(year, ymdc.Year);
        Assert.AreEqual(5, ymdc.Month);
        Assert.AreEqual(20, ymdc.Day);
        Assert.AreEqual(CalendarOrdinal.Iso, ymdc.CalendarOrdinal);
      }
    },

    'AllMonths': (args) {
      // We'll never actually need 32 months, but we support that many...
      for (int month = 1; month <= 32; month++) {
        var ymdc = YearMonthDayCalendar.NewYearMonthDayCalendarOrdinal(-123, month, 20, CalendarOrdinal.HebrewCivil);
        Assert.AreEqual(-123, ymdc.Year);
        Assert.AreEqual(month, ymdc.Month);
        Assert.AreEqual(20, ymdc.Day);
        Assert.AreEqual(CalendarOrdinal.HebrewCivil, ymdc.CalendarOrdinal);
      }
    },

    'AllDays': (args) {
      // We'll never actually need 64 days, but we support that many...
      for (int day = 1; day <= 64; day++) {
        var ymdc =
            YearMonthDayCalendar.NewYearMonthDayCalendarOrdinal(-123, 12, day, CalendarOrdinal.IslamicAstronomicalBase15);
        Assert.AreEqual(-123, ymdc.Year);
        Assert.AreEqual(12, ymdc.Month);
        Assert.AreEqual(day, ymdc.Day);
        Assert.AreEqual(CalendarOrdinal.IslamicAstronomicalBase15, ymdc.CalendarOrdinal);
      }
    },

    'AllCalendars': (args) {
      for (int ordinal = 0; ordinal < 64; ordinal++) {
        CalendarOrdinal calendar = CalendarOrdinal(ordinal);
        var ymdc = YearMonthDayCalendar.NewYearMonthDayCalendarOrdinal(-123, 30, 64, calendar);
        Assert.AreEqual(-123, ymdc.Year);
        Assert.AreEqual(30, ymdc.Month);
        Assert.AreEqual(64, ymdc.Day);
        Assert.AreEqual(calendar, ymdc.CalendarOrdinal);
      }
    },

    'Equality': (args) {
      var original = YearMonthDayCalendar.NewYearMonthDayCalendarOrdinal(1000, 12, 20, CalendarOrdinal.Coptic);
      TestHelper.TestEqualsStruct(original, YearMonthDayCalendar.NewYearMonthDayCalendarOrdinal(1000, 12, 20, CalendarOrdinal.Coptic), [
        YearMonthDayCalendar.NewYearMonthDayCalendarOrdinal(original.Year + 1, original.Month, original.Day, original.CalendarOrdinal),
        YearMonthDayCalendar.NewYearMonthDayCalendarOrdinal(original.Year, original.Month + 1, original.Day, original.CalendarOrdinal),
        YearMonthDayCalendar.NewYearMonthDayCalendarOrdinal(original.Year, original.Month, original.Day + 1, original.CalendarOrdinal),
        YearMonthDayCalendar.NewYearMonthDayCalendarOrdinal(original.Year, original.Month, original.Day, CalendarOrdinal.Gregorian),
      ]);
      // Just test the first one again with operators.
      TestHelper.TestOperatorEquality(original, original,
          YearMonthDayCalendar.NewYearMonthDayCalendarOrdinal(original.Year + 1, original.Month, original.Day, original.CalendarOrdinal));
    },

    'Parse': (args) {
      final [String text, int year, int month, int day, int calendar] = args;
      var value = YearMonthDayCalendar.Parse(text);
      Assert.AreEqual(year, value.Year);
      Assert.AreEqual(month, value.Month);
      Assert.AreEqual(day, value.Day);
      Assert.AreEqual(CalendarOrdinal(calendar), value.CalendarOrdinal);
      Assert.AreEqual(text, value.toString());
    },
  });
}
