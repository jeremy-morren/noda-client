// Ported from NodaTime 6e024dde: src/NodaTime.Test/NodaConstantsTest.cs
// Copyright 2015 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda_dart: .NET's DateTime.Ticks is BclTicks below.

import 'dart:core' as core;
import 'dart:core' hide Duration;

import 'package:noda_dart/src/CalendarSystem.dart';
import 'package:noda_dart/src/DateTimeZone.dart';
import 'package:noda_dart/src/LocalDateTime.dart';
import 'package:noda_dart/src/NodaConstants.dart';

import '../helpers/Assertions.dart';
import '../helpers/Scenarios.dart';
import '../scenarios/NodaConstantsTest.generated.dart' as scenarios;

void main() {
  port(scenarios.fixture, {
    'JulianEpoch': (args) {
      // Compute the Julian epoch using the Julian calendar, instead of the
      // Gregorian version.
      var localEpoch = LocalDateTime.YearMonthDayHourMinuteCalendar(-4712, 1, 1, 12, 0, CalendarSystem.Julian);
      var epoch = localEpoch.InZoneStrictly(DateTimeZone.Utc).ToInstant();
      Assert.AreEqual(epoch, NodaConstants.JulianEpoch);
    },

    'BclTicksAtEpoch': (args) {
      Assert.AreEqual(BclTicks(core.DateTime.utc(1970, 1, 1, 0, 0, 0)), NodaConstants.BclTicksAtUnixEpoch);
    },

    'BclDaysAtEpoch': (args) {
      Assert.AreEqual(BclTicks(core.DateTime.utc(1970, 1, 1, 0, 0, 0)),
          NodaConstants.TicksPerDay * NodaConstants.BclDaysAtUnixEpoch);
    },
  });
}

/// noda_dart: .NET's `DateTime.Ticks`: 100ns ticks since 0001-01-01T00:00:00.
int BclTicks(core.DateTime dateTime) =>
    (dateTime.microsecondsSinceEpoch - core.DateTime.utc(1).microsecondsSinceEpoch) * 10;
