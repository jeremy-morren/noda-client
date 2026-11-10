// Ported from NodaTime 6e024dde: src/NodaTime.TzdbCompiler.Test/Tzdb/RuleLineTest.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda_dart: the internal ZoneYearOffset constructor is ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay.

import 'package:noda_dart/src/IsoDayOfWeek.generated.dart';
import 'package:noda_dart/src/LocalTime.dart';
import 'package:noda_dart/src/Offset.dart';
import 'package:noda_dart/src/TimeZones/TransitionMode.generated.dart';
import 'package:noda_dart/src/TimeZones/ZoneRecurrence.dart';
import 'package:noda_dart/src/TimeZones/ZoneYearOffset.dart';
import 'package:noda_dart/src/TzdbCompiler/Tzdb/RuleLine.dart';

import '../../../helpers/Assertions.dart';
import '../../../helpers/Scenarios.dart';
import '../../../scenarios/TzdbCompiler/Tzdb/RuleLineTest.generated.dart' as scenarios;

void main() {
  port(scenarios.fixture, {
    'Equality': (args) {
      var yearOffset = ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(
          TransitionMode.Utc, 10, 31, IsoDayOfWeek.Wednesday.value, true, LocalTime.Midnight);
      var recurrence = ZoneRecurrence('bob', Offset.Zero, yearOffset, 1971, 2009);
      var actual = RuleLine(recurrence, 'D');
      var expected = RuleLine(recurrence, 'D');
      Assert.AreEqual(expected, actual);
    },
  });
}
