// Ported from NodaTime 6e024dde: src/NodaTime.Test/ZonedClockTest.cs
// Copyright 2014 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda_dart: LocalDateTime(..., int minute, CalendarSystem) is LocalDateTime.YearMonthDayHourMinuteCalendar.

import 'package:noda_dart/src/CalendarSystem.dart';
import 'package:noda_dart/src/DateTimeZone.dart';
import 'package:noda_dart/src/Extensions/ClockExtensions.dart';
import 'package:noda_dart/src/LocalDate.dart';
import 'package:noda_dart/src/LocalDateTime.dart';
import 'package:noda_dart/src/LocalTime.dart';
import 'package:noda_dart/src/NodaConstants.dart';
import 'package:noda_dart/src/Offset.dart';
import 'package:noda_dart/src/Testing/FakeClock.dart';
import 'package:noda_dart/src/Testing/TimeZones/SingleTransitionDateTimeZone.dart';
import 'package:noda_dart/src/ZonedClock.dart';
import 'package:noda_dart/src/ZonedDateTime.dart';

import '../helpers/Assertions.dart';
import '../helpers/Scenarios.dart';
import '../scenarios/ZonedClockTest.generated.dart' as scenarios;

final DateTimeZone SampleZone = SingleTransitionDateTimeZone(NodaConstants.UnixEpoch, 1, 2);

void main() {
  port(scenarios.fixture, {
    'GetCurrent': (args) {
      var julian = CalendarSystem.Julian;
      FakeClock underlyingClock = FakeClock(NodaConstants.UnixEpoch);
      ZonedClock zonedClock = underlyingClock.InZone(SampleZone, julian);
      Assert.AreEqual(NodaConstants.UnixEpoch, zonedClock.GetCurrentInstant());
      Assert.AreEqual(ZonedDateTime(underlyingClock.GetCurrentInstant(), SampleZone, julian),
          zonedClock.GetCurrentZonedDateTime());
      Assert.AreEqual(
          LocalDateTime.YearMonthDayHourMinuteCalendar(1969, 12, 19, 2, 0, julian), zonedClock.GetCurrentLocalDateTime());
      Assert.AreEqual(
          LocalDateTime.YearMonthDayHourMinuteCalendar(1969, 12, 19, 2, 0, julian).WithOffset(Offset.FromHours(2)),
          zonedClock.GetCurrentOffsetDateTime());
      Assert.AreEqual(LocalDate(1969, 12, 19, julian), zonedClock.GetCurrentDate());
      Assert.AreEqual(LocalTime(2, 0, 0), zonedClock.GetCurrentTimeOfDay());
    },

    'Properties': (args) {
      var calendar = CalendarSystem.Julian;
      var clock = FakeClock(NodaConstants.UnixEpoch);
      var zonedClock = clock.InZone(SampleZone, calendar);
      Assert.AreSame(clock, zonedClock.Clock);
      Assert.AreSame(calendar, zonedClock.Calendar);
      Assert.AreSame(SampleZone, zonedClock.Zone);
    },
  });
}
