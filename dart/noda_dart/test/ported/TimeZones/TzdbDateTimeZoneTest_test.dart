// Ported from NodaTime 6e024dde: src/NodaTime.Test/TimeZones/TzdbDateTimeZoneTest.cs
// Copyright 2015 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda_dart: AllTzdbZones (the TestCaseSource, DateTimeZoneProviders.Tzdb.GetAllZones()) is the scenario's cases.

import 'package:noda_dart/src/DateTimeZone.dart';
import 'package:noda_dart/src/Instant.dart';

import '../../helpers/Assertions.dart';
import '../../helpers/Scenarios.dart';
import '../../scenarios/TimeZones/TzdbDateTimeZoneTest.generated.dart' as scenarios;

/// Tests for all TZDB time zones.
void main() {
  port(scenarios.fixture, {
    'AllZonesStartAndEndOfTime': (args) {
      final [DateTimeZone zone] = args;
      var firstInterval = zone.GetZoneInterval(Instant.MinValue);
      Assert.IsFalse(firstInterval.HasStart);
      var lastInterval = zone.GetZoneInterval(Instant.MaxValue);
      Assert.IsFalse(lastInterval.HasEnd);
    },
  });
}
