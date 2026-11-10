// Ported from NodaTime 6e024dde: src/NodaTime.Test/Testing/FakeClockTest.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:noda_dart/src/Duration.dart';
import 'package:noda_dart/src/Instant.dart';
import 'package:noda_dart/src/NodaConstants.dart';
import 'package:noda_dart/src/Testing/FakeClock.dart';

import '../../helpers/Assertions.dart';
import '../../helpers/Scenarios.dart';
import '../../scenarios/Testing/FakeClockTest.generated.dart' as scenarios;

/// Tests for the FakeClock class in the Testing assembly.
void main() {
  port(scenarios.fixture, {
    'DirectConstruction': (args) {
      Instant instant = Instant.FromUnixTimeTicks(100);
      FakeClock clock = FakeClock(instant);
      Assert.AreEqual(instant, clock.GetCurrentInstant());
    },

    'ConstructionWithAdvance': (args) {
      Instant instant = Instant.FromUnixTimeTicks(100);
      Duration advance = Duration.FromTicks(5);
      FakeClock clock = FakeClock(instant, advance);
      Assert.AreEqual(advance, clock.AutoAdvance);
      Assert.AreEqual(instant, clock.GetCurrentInstant());
      Assert.AreEqual(instant + advance, clock.GetCurrentInstant());
      Assert.AreEqual(instant + advance + advance, clock.GetCurrentInstant());
    },

    'ConstructionThenAdvance': (args) {
      Instant instant = Instant.FromUnixTimeTicks(100);
      FakeClock clock = FakeClock(instant);
      Assert.AreEqual(instant, clock.GetCurrentInstant());
      Assert.AreEqual(instant, clock.GetCurrentInstant());
      Duration advance = Duration.FromTicks(5);
      clock.AutoAdvance = advance;
      // Setting auto-advance doesn't actually change the clock...
      // but this call will.
      Assert.AreEqual(instant, clock.GetCurrentInstant());
      Assert.AreEqual(instant + advance, clock.GetCurrentInstant());
      Assert.AreEqual(instant + advance + advance, clock.GetCurrentInstant());
    },

    'UtcDateConstruction': (args) {
      Instant instant = Instant.FromUtc(2010, 1, 1, 0, 0);
      FakeClock clock = FakeClock.FromUtc(2010, 1, 1);
      Assert.AreEqual(instant, clock.GetCurrentInstant());
    },

    'UtcDateTimeConstruction': (args) {
      Instant instant = Instant.FromUtc(2010, 1, 1, 10, 30, 25);
      FakeClock clock = FakeClock.FromUtc(2010, 1, 1, 10, 30, 25);
      Assert.AreEqual(instant, clock.GetCurrentInstant());
    },

    'Advance': (args) {
      FakeClock clock = FakeClock(Instant.FromUnixTimeTicks(100));
      Duration d = Duration.FromTicks(25);
      clock.Advance(d);
      Assert.AreEqual(125, clock.GetCurrentInstant().ToUnixTimeTicks());
    },

    'AdvanceNanoseconds': (args) {
      FakeClock clock = FakeClock(Instant.FromUnixTimeSeconds(1));
      clock.AdvanceNanoseconds(3);
      Assert.AreEqual(1000000003, clock.GetCurrentInstant().TimeSinceEpoch.ToInt64Nanoseconds());
    },

    'AdvanceTicks': (args) {
      FakeClock clock = FakeClock(Instant.FromUnixTimeTicks(100));
      clock.AdvanceTicks(3);
      Assert.AreEqual(103, clock.GetCurrentInstant().ToUnixTimeTicks());
    },

    'AdvanceMilliseconds': (args) {
      FakeClock clock = FakeClock(Instant.FromUnixTimeTicks(100));
      clock.AdvanceMilliseconds(3);
      Assert.AreEqual(100 + 3 * NodaConstants.TicksPerMillisecond, clock.GetCurrentInstant().ToUnixTimeTicks());
    },

    'AdvanceSeconds': (args) {
      FakeClock clock = FakeClock(Instant.FromUnixTimeTicks(100));
      clock.AdvanceSeconds(3);
      Assert.AreEqual(100 + 3 * NodaConstants.TicksPerSecond, clock.GetCurrentInstant().ToUnixTimeTicks());
    },

    'AdvanceMinutes': (args) {
      FakeClock clock = FakeClock(Instant.FromUnixTimeTicks(100));
      clock.AdvanceMinutes(3);
      Assert.AreEqual(100 + 3 * NodaConstants.TicksPerMinute, clock.GetCurrentInstant().ToUnixTimeTicks());
    },

    'AdvanceHours': (args) {
      FakeClock clock = FakeClock(Instant.FromUnixTimeTicks(100));
      clock.AdvanceHours(3);
      Assert.AreEqual(100 + 3 * NodaConstants.TicksPerHour, clock.GetCurrentInstant().ToUnixTimeTicks());
    },

    'AdvanceDays': (args) {
      FakeClock clock = FakeClock(Instant.FromUnixTimeTicks(100));
      clock.AdvanceDays(3);
      Assert.AreEqual(100 + 3 * NodaConstants.TicksPerDay, clock.GetCurrentInstant().ToUnixTimeTicks());
    },

    'Reset': (args) {
      Instant instant1 = Instant.FromUnixTimeTicks(100);
      Instant instant2 = Instant.FromUnixTimeTicks(500);
      FakeClock clock = FakeClock(instant1);
      Assert.AreEqual(instant1, clock.GetCurrentInstant());
      clock.Reset(instant2);
      Assert.AreEqual(instant2, clock.GetCurrentInstant());
    },
  });
}
