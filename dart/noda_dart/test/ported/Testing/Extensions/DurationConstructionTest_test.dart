// Ported from NodaTime 6e024dde: src/NodaTime.Test/Testing/Extensions/DurationConstructionTest.cs
// Copyright 2016 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda_dart: the int and long overloads are DurationConstruction, the double ones DurationConstructionDouble.

import 'package:noda_dart/src/Duration.dart';
import 'package:noda_dart/src/Testing/Extensions/DurationConstruction.dart';

import '../../../helpers/Assertions.dart';
import '../../../helpers/Scenarios.dart';
import '../../../scenarios/Testing/Extensions/DurationConstructionTest.generated.dart' as scenarios;

void main() {
  port(scenarios.fixture, {
    'Days': (args) {
      Assert.AreEqual(Duration.FromDays(2), 2.Days());
      Assert.AreEqual(Duration.FromDaysDouble(2.5), 2.5.Days());
    },

    'Hours': (args) {
      Assert.AreEqual(Duration.FromHours(2), 2.Hours());
      Assert.AreEqual(Duration.FromHoursDouble(2.5), 2.5.Hours());
    },

    'Minutes': (args) {
      Assert.AreEqual(Duration.FromMinutes(2), 2.Minutes());
      Assert.AreEqual(Duration.FromMinutes(2), 2.Minutes()); // C#: 2L
      Assert.AreEqual(Duration.FromMinutesDouble(2.5), 2.5.Minutes());
    },

    'Seconds': (args) {
      Assert.AreEqual(Duration.FromSeconds(2), 2.Seconds());
      Assert.AreEqual(Duration.FromSeconds(2), 2.Seconds()); // C#: 2L
      Assert.AreEqual(Duration.FromSecondsDouble(2.5), 2.5.Seconds());
    },

    'Milliseconds': (args) {
      Assert.AreEqual(Duration.FromMilliseconds(2), 2.Milliseconds());
      Assert.AreEqual(Duration.FromMilliseconds(2), 2.Milliseconds()); // C#: 2L
      Assert.AreEqual(Duration.FromMillisecondsDouble(2.5), 2.5.Milliseconds());
    },

    'Ticks': (args) {
      Assert.AreEqual(Duration.FromTicks(2), 2.Ticks());
      Assert.AreEqual(Duration.FromTicks(2), 2.Ticks()); // C#: 2L
      Assert.AreEqual(Duration.FromTicksDouble(2.5), 2.5.Ticks());
    },

    'Nanoseconds': (args) {
      Assert.AreEqual(Duration.FromNanoseconds(2), 2.Nanoseconds());
      Assert.AreEqual(Duration.FromNanoseconds(2), 2.Nanoseconds()); // C#: 2L
      Assert.AreEqual(Duration.FromNanosecondsDouble(2.5), 2.5.Nanoseconds());
    },
  });
}
