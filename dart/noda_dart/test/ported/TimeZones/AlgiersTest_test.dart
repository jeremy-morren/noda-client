// Ported from NodaTime 6e024dde: src/NodaTime.Test/TimeZones/AlgiersTest.cs
// Copyright 2010 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:noda_dart/src/DateTimeZone.dart';
import 'package:noda_dart/src/DateTimeZoneProviders.dart';
import 'package:noda_dart/src/Instant.dart';
import 'package:noda_dart/src/LocalDateTime.dart';
import 'package:noda_dart/src/NodaConstants.dart';
import 'package:noda_dart/src/Offset.dart';
import 'package:noda_dart/src/TimeZones/ZoneInterval.dart';

import '../../helpers/Assertions.dart';
import '../../helpers/Scenarios.dart';
import '../../scenarios/TimeZones/AlgiersTest.generated.dart' as scenarios;

/// Algiers had DST until May 1st 1981, after which time it didn't have any - so
/// we use that to test a time zone whose transitions run out. (When Algiers
/// decided to stop using DST, it changed its standard offset to be what had previously
/// been its DST offset, i.e. +1.)
final DateTimeZone Algiers = DateTimeZoneProviders.Tzdb['Africa/Algiers'];

void main() {
  port(scenarios.fixture, {
    'GetPeriod_BeforeLast': (args) {
      Instant april1981 = Instant.FromUtc(1981, 4, 1, 0, 0);
      var actual = Algiers.GetZoneInterval(april1981);
      var expected = ZoneInterval('WET', Instant.FromUnixTimeTicks(3418020000000000),
          Instant.FromUnixTimeTicks(3575232000000000), Offset.Zero, Offset.Zero);
      Assert.AreEqual(expected, actual);
    },

    'GetPeriod_AfterLastTransition': (args) {
      var may1981 = DateTimeZone.Utc.AtStrictly(LocalDateTime(1981, 5, 1, 0, 0, 1)).ToInstant();
      var actual = Algiers.GetZoneInterval(may1981);
      var expected = ZoneInterval('CET', Instant.FromUnixTimeTicks(3575232000000000), null,
          Offset.FromSeconds(NodaConstants.SecondsPerHour), Offset.Zero);
      Assert.AreEqual(expected, actual);
    },
  });
}
