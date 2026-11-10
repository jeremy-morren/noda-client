// Ported from NodaTime 6e024dde: src/NodaTime.Test/Calendars/CopticCalendarSystemTest.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:noda_dart/src/CalendarSystem.dart';
import 'package:noda_dart/src/Calendars/Era.dart';
import 'package:noda_dart/src/DateTimeZone.dart';
import 'package:noda_dart/src/IsoDayOfWeek.generated.dart';
import 'package:noda_dart/src/LocalDateTime.dart';
import 'package:noda_dart/src/NodaConstants.dart';

import '../../helpers/Assertions.dart';
import '../../helpers/Scenarios.dart';
import '../../scenarios/Calendars/CopticCalendarSystemTest.generated.dart' as scenarios;

/// Tests for the Coptic calendar system.
void main() {
  port(scenarios.fixture, {
    'CopticEpoch': (args) {
      CalendarSystem coptic = CalendarSystem.Coptic;
      LocalDateTime copticEpoch = LocalDateTime.YearMonthDayHourMinuteCalendar(1, 1, 1, 0, 0, coptic);

      CalendarSystem julian = CalendarSystem.Julian;
      LocalDateTime converted = copticEpoch.WithCalendar(julian);

      LocalDateTime expected = LocalDateTime.YearMonthDayHourMinuteCalendar(284, 8, 29, 0, 0, julian);
      Assert.AreEqual(expected, converted);
    },

    'UnixEpoch': (args) {
      CalendarSystem coptic = CalendarSystem.Coptic;
      LocalDateTime unixEpochInCopticCalendar = NodaConstants.UnixEpoch.InZone(DateTimeZone.Utc, coptic).LocalDateTime;
      LocalDateTime expected = LocalDateTime.YearMonthDayHourMinuteCalendar(1686, 4, 23, 0, 0, coptic);
      Assert.AreEqual(expected, unixEpochInCopticCalendar);
    },

    'SampleDate': (args) {
      CalendarSystem copticCalendar = CalendarSystem.Coptic;
      LocalDateTime iso = LocalDateTime(2004, 6, 9, 0, 0, 0, 0);
      LocalDateTime coptic = iso.WithCalendar(copticCalendar);

      Assert.AreEqual(Era.AnnoMartyrum, coptic.Era);
      Assert.AreEqual(1720, coptic.YearOfEra);

      Assert.AreEqual(1720, coptic.Year);
      Assert.IsFalse(copticCalendar.IsLeapYear(1720));

      Assert.AreEqual(10, coptic.Month);
      Assert.AreEqual(2, coptic.Day);

      Assert.AreEqual(IsoDayOfWeek.Wednesday, coptic.DayOfWeek);

      Assert.AreEqual(9 * 30 + 2, coptic.DayOfYear);

      Assert.AreEqual(0, coptic.Hour);
      Assert.AreEqual(0, coptic.Minute);
      Assert.AreEqual(0, coptic.Second);
      Assert.AreEqual(0, coptic.Millisecond);
    },

    // Really testing SingleEraCalculator...
    'InvalidEra': (args) {
      // Not ported: the null era check (null safety).
      Assert.Throws<ArgumentError>(() => CalendarSystem.Coptic.GetAbsoluteYear(1720, Era.AnnoHegirae));
    },
  });
}
