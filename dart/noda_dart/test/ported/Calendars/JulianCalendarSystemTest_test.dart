// Ported from NodaTime 6e024dde: src/NodaTime.Test/Calendars/JulianCalendarSystemTest.cs
// (+ JulianCalendarSystemTest.Era.cs)
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:noda_dart/src/CalendarSystem.dart';
import 'package:noda_dart/src/Calendars/Era.dart';
import 'package:noda_dart/src/DateTimeZone.dart';
import 'package:noda_dart/src/LocalDate.dart';
import 'package:noda_dart/src/LocalDateTime.dart';
import 'package:noda_dart/src/NodaConstants.dart';

import '../../helpers/Assertions.dart';
import '../../helpers/Scenarios.dart';
import '../../scenarios/Calendars/JulianCalendarSystemTest.generated.dart' as scenarios;

final CalendarSystem Julian = CalendarSystem.Julian;

/// Tests for the Julian calendar system via JulianYearMonthDayCalculator.
void main() {
  port(scenarios.fixture, {
    // #region JulianCalendarSystemTest.cs
    /// The Unix epoch is equivalent to December 19th 1969 in the Julian calendar.
    'Epoch': (args) {
      LocalDateTime julianEpoch = NodaConstants.UnixEpoch.InZone(DateTimeZone.Utc, Julian).LocalDateTime;
      Assert.AreEqual(1969, julianEpoch.Year);
      Assert.AreEqual(12, julianEpoch.Month);
      Assert.AreEqual(19, julianEpoch.Day);
    },

    'LeapYears': (args) {
      Assert.IsTrue(Julian.IsLeapYear(1900)); // No 100 year rule...
      Assert.IsFalse(Julian.IsLeapYear(1901));
      Assert.IsTrue(Julian.IsLeapYear(1904));
      Assert.IsTrue(Julian.IsLeapYear(2000));
      Assert.IsTrue(Julian.IsLeapYear(2100)); // No 100 year rule...
      Assert.IsTrue(Julian.IsLeapYear(2400));
      // Check 1BC, 5BC etc...
      Assert.IsTrue(Julian.IsLeapYear(0));
      Assert.IsTrue(Julian.IsLeapYear(-4));
    },
    // #endregion

    // #region JulianCalendarSystemTest.Era.cs
    'GetMaxYearOfEra': (args) {
      LocalDate date = LocalDate(Julian.MaxYear, 1, 1, Julian);
      Assert.AreEqual(date.YearOfEra, Julian.GetMaxYearOfEra(Era.Common));
      Assert.AreEqual(Era.Common, date.Era);
      date = LocalDate(Julian.MinYear, 1, 1, Julian);
      Assert.AreEqual(Julian.MinYear, date.Year);
      Assert.AreEqual(date.YearOfEra, Julian.GetMaxYearOfEra(Era.BeforeCommon));
      Assert.AreEqual(Era.BeforeCommon, date.Era);
    },

    'GetMinYearOfEra': (args) {
      LocalDate date = LocalDate(1, 1, 1, Julian);
      Assert.AreEqual(date.YearOfEra, Julian.GetMinYearOfEra(Era.Common));
      Assert.AreEqual(Era.Common, date.Era);
      date = LocalDate(0, 1, 1, Julian);
      Assert.AreEqual(date.YearOfEra, Julian.GetMinYearOfEra(Era.BeforeCommon));
      Assert.AreEqual(Era.BeforeCommon, date.Era);
    },

    'GetAbsoluteYear': (args) {
      Assert.AreEqual(1, Julian.GetAbsoluteYear(1, Era.Common));
      Assert.AreEqual(0, Julian.GetAbsoluteYear(1, Era.BeforeCommon));
      Assert.AreEqual(-1, Julian.GetAbsoluteYear(2, Era.BeforeCommon));
      Assert.AreEqual(Julian.MaxYear, Julian.GetAbsoluteYear(Julian.GetMaxYearOfEra(Era.Common), Era.Common));
      Assert.AreEqual(Julian.MinYear, Julian.GetAbsoluteYear(Julian.GetMaxYearOfEra(Era.BeforeCommon), Era.BeforeCommon));
    },

    'EraProperty': (args) {
      CalendarSystem calendar = CalendarSystem.Julian;
      LocalDateTime startOfEra = LocalDateTime.YearMonthDayHourMinuteSecondCalendar(1, 1, 1, 0, 0, 0, calendar);
      Assert.AreEqual(Era.Common, startOfEra.Era);
      Assert.AreEqual(Era.BeforeCommon, startOfEra.PlusTicks(-1).Era);
    },
    // #endregion
  });
}
