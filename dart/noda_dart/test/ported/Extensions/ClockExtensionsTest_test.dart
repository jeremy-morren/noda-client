// Ported from NodaTime 6e024dde: src/NodaTime.Test/Extensions/ClockExtensionsTest.cs
// Copyright 2017 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:noda_dart/src/CalendarSystem.dart';
import 'package:noda_dart/src/DateTimeZone.dart';
import 'package:noda_dart/src/DateTimeZoneProviders.dart';
import 'package:noda_dart/src/Extensions/ClockExtensions.dart';
import 'package:noda_dart/src/NodaConstants.dart';
import 'package:noda_dart/src/Testing/FakeClock.dart';

import '../../helpers/Assertions.dart';
import '../../helpers/Scenarios.dart';
import '../../scenarios/Extensions/ClockExtensionsTest.generated.dart' as scenarios;

final DateTimeZone NewYork = DateTimeZoneProviders.Tzdb['America/New_York'];

void main() {
  port(scenarios.fixture, {
    'InZone_NoCalendar': (args) {
      var clock = FakeClock(NodaConstants.UnixEpoch);
      var zoned = clock.InZone(NewYork);
      var zonedEpoch = NodaConstants.UnixEpoch.InZone(NewYork);
      Assert.AreEqual(zonedEpoch, zoned.GetCurrentZonedDateTime());
    },

    'InZone_WithCalendar': (args) {
      var clock = FakeClock(NodaConstants.UnixEpoch);
      var zoned = clock.InZone(NewYork, CalendarSystem.Julian);
      var zonedEpoch = NodaConstants.UnixEpoch.InZone(NewYork, CalendarSystem.Julian);
      Assert.AreEqual(zonedEpoch, zoned.GetCurrentZonedDateTime());
    },

    'InUtc': (args) {
      var clock = FakeClock(NodaConstants.UnixEpoch);
      var zoned = clock.InUtc();
      var zonedEpoch = NodaConstants.UnixEpoch.InUtc();
      Assert.AreEqual(zonedEpoch, zoned.GetCurrentZonedDateTime());
    },
  }, skip: {
    'InTzdbSystemDefaultZone': "Replaces TimeZoneInfo.Local (TimeZoneInfoReplacer): noda_dart reads the host's zone "
        "(TZ, the OS, Intl), which a test can't replace",
    'InBclSystemDefaultZone':
        "ClockExtensions.InBclSystemDefaultZone isn't ported (DateTimeZoneProviders.Bcl is noda_dart's system library)",
  });
}
