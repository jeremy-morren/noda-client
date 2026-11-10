// Ported from NodaTime 6e024dde: src/NodaTime.Test/SystemClockTest.cs
// Copyright 2010 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda_dart: excluded by the generator (current time); plain [Test]s run with `runExcluded`.

import 'dart:core' as core;
import 'dart:core' hide Duration;

import 'package:noda_dart/src/Duration.dart';
import 'package:noda_dart/src/Instant.dart';
import 'package:noda_dart/src/NodaConstants.dart';
import 'package:noda_dart/src/SystemClock.dart';

import '../helpers/Assertions.dart';
import '../helpers/Scenarios.dart';
import '../scenarios/SystemClockTest.generated.dart' as scenarios;

void main() {
  port(scenarios.fixture, {
    'InstanceNow': (args) {
      int frameworkNowTicks = NodaConstants.BclEpoch.PlusTicks(BclTicks(core.DateTime.now().toUtc())).ToUnixTimeTicks();
      int nodaTicks = SystemClock.Instance.GetCurrentInstant().ToUnixTimeTicks();
      Assert.Less((nodaTicks - frameworkNowTicks).abs(), Duration.FromSeconds(1).BclCompatibleTicks);
    },

    'Sanity': (args) {
      // Previously all the conversions missed the SystemConversions.DateTimeEpochTicks,
      // so they were self-consistent but not consistent with sanity.
      Instant minimumExpected = Instant.FromUtc(2024, 8, 1, 0, 0);
      Instant maximumExpected = Instant.FromUtc(2030, 1, 1, 0, 0);
      Instant now = SystemClock.Instance.GetCurrentInstant();
      Assert.Less(minimumExpected.ToUnixTimeTicks(), now.ToUnixTimeTicks());
      Assert.Less(now.ToUnixTimeTicks(), maximumExpected.ToUnixTimeTicks());
    },
  }, runExcluded: true);
}

/// noda_dart: .NET's `DateTime.Ticks`: 100ns ticks since 0001-01-01T00:00:00.
int BclTicks(core.DateTime dateTime) =>
    (dateTime.microsecondsSinceEpoch - core.DateTime.utc(1).microsecondsSinceEpoch) * 10;
