// Ported from NodaTime 6e024dde: src/NodaTime.Test/Calendars/GregorianCalendarSystemTest.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:noda_dart/src/CalendarSystem.dart';
import 'package:noda_dart/src/Calendars/Era.dart';
import 'package:noda_dart/src/LocalDate.dart';
import 'package:noda_dart/src/LocalDateTime.dart';

import '../../helpers/Assertions.dart';
import '../../helpers/Scenarios.dart';
import '../../scenarios/Calendars/GregorianCalendarSystemTest.generated.dart' as scenarios;

void main() {
  port(scenarios.fixture, {
    'LeapYears': (args) {
      var calendar = CalendarSystem.Gregorian;
      Assert.IsFalse(calendar.IsLeapYear(1900));
      Assert.IsFalse(calendar.IsLeapYear(1901));
      Assert.IsTrue(calendar.IsLeapYear(1904));
      Assert.IsTrue(calendar.IsLeapYear(1996));
      Assert.IsTrue(calendar.IsLeapYear(2000));
      Assert.IsFalse(calendar.IsLeapYear(2100));
      Assert.IsTrue(calendar.IsLeapYear(2400));
    },

    'EraProperty': (args) {
      CalendarSystem calendar = CalendarSystem.Gregorian;
      LocalDateTime startOfEra = LocalDateTime.YearMonthDayHourMinuteSecondCalendar(1, 1, 1, 0, 0, 0, calendar);
      Assert.AreEqual(Era.Common, startOfEra.Era);
      Assert.AreEqual(Era.BeforeCommon, startOfEra.PlusTicks(-1).Era);
    },

    'AddMonths_BoundaryCondition': (args) {
      var start = LocalDate(2017, 8, 20);
      var end = start.PlusMonths(-19);
      var expected = LocalDate(2016, 1, 20);
      Assert.AreEqual(expected, end);
    },
  });
}
