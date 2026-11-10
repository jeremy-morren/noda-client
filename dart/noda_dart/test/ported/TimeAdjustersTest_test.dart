// Ported from NodaTime 6e024dde: src/NodaTime.Test/TimeAdjustersTest.cs
// Copyright 2014 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:noda_dart/src/LocalTime.dart';
import 'package:noda_dart/src/TimeAdjusters.dart';

import '../helpers/Assertions.dart';
import '../helpers/Scenarios.dart';
import '../scenarios/TimeAdjustersTest.generated.dart' as scenarios;

void main() {
  port(scenarios.fixture, {
    'TruncateToSecond': (args) {
      var start = LocalTime.FromHourMinuteSecondMillisecondTick(7, 4, 30, 123, 4567);
      var end = LocalTime(7, 4, 30);
      Assert.AreEqual(end, TimeAdjusters.TruncateToSecond(start));
    },

    'TruncateToMinute': (args) {
      var start = LocalTime.FromHourMinuteSecondMillisecondTick(7, 4, 30, 123, 4567);
      var end = LocalTime(7, 4, 0);
      Assert.AreEqual(end, TimeAdjusters.TruncateToMinute(start));
    },

    'TruncateToHour': (args) {
      var start = LocalTime.FromHourMinuteSecondMillisecondTick(7, 4, 30, 123, 4567);
      var end = LocalTime(7, 0, 0);
      Assert.AreEqual(end, TimeAdjusters.TruncateToHour(start));
    },
  });
}
