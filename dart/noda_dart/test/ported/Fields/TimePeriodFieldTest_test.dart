// Ported from NodaTime 6e024dde: src/NodaTime.Test/Fields/TimePeriodFieldTest.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda_dart: the `ref int extraDays` overload returns a record (time, extraDays).

import 'package:noda_dart/src/Duration.dart';
import 'package:noda_dart/src/Fields/TimePeriodField.dart';
import 'package:noda_dart/src/LocalTime.dart';
import 'package:noda_dart/src/Text/LocalTimePattern.dart';

import '../../helpers/Assertions.dart';
import '../../helpers/Scenarios.dart';
import '../../scenarios/Fields/TimePeriodFieldTest.generated.dart' as scenarios;

// Just a sample really.
final TimePeriodField SampleField = TimePeriodField.Milliseconds;

void main() {
  port(scenarios.fixture, {
    'Add': (args) {
      final [String start, int units, String expectedEnd, int expectedExtraDays] = args;
      var startTime = LocalTimePattern.ExtendedIso.Parse(start).Value;
      var expectedEndTime = LocalTimePattern.ExtendedIso.Parse(expectedEnd).Value;

      int extraDays = 0;
      LocalTime actual;
      (actual, extraDays) = SampleField.AddLocalTimeExtraDays(startTime, units, extraDays);
      Assert.AreEqual(expectedEndTime, actual);
      Assert.AreEqual(expectedExtraDays, extraDays);
    },

    'GetUnitsInDuration': (args) {
      final [int hours] = args;
      var duration = Duration.FromHours(hours) + Duration.FromMinutes(30 * hours.sign);
      Assert.AreEqual(hours, TimePeriodField.Hours.GetUnitsInDuration(duration));
    },

    'ToDuration': (args) {
      final [int hours] = args;
      var actual = TimePeriodField.Hours.ToDuration(hours);
      Assert.AreEqual(Duration.FromHours(hours), actual);
    },
  });
}
