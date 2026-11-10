// Ported from NodaTime 6e024dde: src/NodaTime.Test/YearMonthDayTest.cs
// Copyright 2014 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:noda_dart/src/CalendarOrdinal.generated.dart';
import 'package:noda_dart/src/CalendarSystem.dart';
import 'package:noda_dart/src/YearMonthDay.dart';
import 'package:noda_dart/src/YearMonthDayCalendar.dart';

import '../helpers/Assertions.dart';
import '../helpers/Scenarios.dart';
import '../helpers/TestHelper.dart';
import '../scenarios/YearMonthDayTest.generated.dart' as scenarios;

void main() {
  port(scenarios.fixture, {
    'AllYears': (args) {
      // Range of years we actually care about. We support more, but that's okay.
      for (int year = -9999; year <= 9999; year++) {
        var ymd = YearMonthDay.NewYearMonthDay(year, 5, 20);
        Assert.AreEqual(year, ymd.Year);
        Assert.AreEqual(5, ymd.Month);
        Assert.AreEqual(20, ymd.Day);
      }
    },

    'AllMonths': (args) {
      // We'll never actually need 32 months, but we support that many...
      for (int month = 1; month < 32; month++) {
        var ymd = YearMonthDay.NewYearMonthDay(-123, month, 20);
        Assert.AreEqual(-123, ymd.Year);
        Assert.AreEqual(month, ymd.Month);
        Assert.AreEqual(20, ymd.Day);
      }
    },

    'AllDays': (args) {
      // We'll never actually need 64 days, but we support that many...
      for (int day = 1; day < 64; day++) {
        var ymd = YearMonthDay.NewYearMonthDay(-123, 30, day);
        Assert.AreEqual(-123, ymd.Year);
        Assert.AreEqual(30, ymd.Month);
        Assert.AreEqual(day, ymd.Day);
      }
    },

    'Comparisons': (args) {
      final [String smallerText, String greaterText] = args;
      var smaller = YearMonthDay.Parse(smallerText);
      var greater = YearMonthDay.Parse(greaterText);
      TestHelper.TestCompareToStruct(smaller, smaller, [greater]);
      TestHelper.TestOperatorComparisonEquality(smaller, smaller, [greater]);
      TestHelper.TestEqualsStruct(smaller, smaller, [greater]);
    },

    'YearMonthDayToString': (args) {
      var ymd = YearMonthDay.NewYearMonthDay(2017, 8, 25);
      Assert.AreEqual('2017-08-25', ymd.toString());
    },

    'WithCalendar': (args) {
      var ymd = YearMonthDay.NewYearMonthDay(2017, 8, 25);
      var ymdc = YearMonthDayCalendar.NewYearMonthDayCalendarOrdinal(2017, 8, 25, CalendarOrdinal.Julian);
      Assert.AreEqual(ymdc, ymd.WithCalendar(CalendarSystem.Julian));
    },

    'WithCalendar_Null': (args) {
      var ymd = YearMonthDay.NewYearMonthDay(2017, 8, 25);
      var ymdc = YearMonthDayCalendar.NewYearMonthDayCalendarOrdinal(2017, 8, 25, CalendarOrdinal.Iso);
      Assert.AreEqual(ymdc, ymd.WithCalendar(null));
    },
  });
}
