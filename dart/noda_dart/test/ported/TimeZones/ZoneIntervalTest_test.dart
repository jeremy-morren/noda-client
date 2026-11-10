// Ported from NodaTime 6e024dde: src/NodaTime.Test/TimeZones/ZoneIntervalTest.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:noda_dart/src/Duration.dart';
import 'package:noda_dart/src/Instant.dart';
import 'package:noda_dart/src/LocalDateTime.dart';
import 'package:noda_dart/src/Offset.dart';
import 'package:noda_dart/src/TimeZones/ZoneInterval.dart';
import 'package:noda_dart/src/Utility/SystemExceptions.dart';

import '../../helpers/Assertions.dart';
import '../../helpers/Scenarios.dart';
import '../../helpers/TestHelper.dart';
import '../../scenarios/TimeZones/ZoneIntervalTest.generated.dart' as scenarios;

final Instant SampleStart = Instant.FromUtc(2011, 6, 3, 10, 15);
final Instant SampleEnd = Instant.FromUtc(2011, 8, 2, 13, 45);

final ZoneInterval SampleInterval =
    ZoneInterval('TestTime', SampleStart, SampleEnd,
        Offset.FromHours(9), Offset.FromHours(1));

void main() {
  port(scenarios.fixture, {
    'PassthroughProperties': (args) {
      Assert.AreEqual('TestTime', SampleInterval.Name);
      Assert.AreEqual(Offset.FromHours(8), SampleInterval.StandardOffset);
      Assert.AreEqual(Offset.FromHours(1), SampleInterval.Savings);
      Assert.AreEqual(Offset.FromHours(9), SampleInterval.WallOffset);
      Assert.AreEqual(SampleStart, SampleInterval.Start);
      Assert.AreEqual(SampleEnd, SampleInterval.End);
    },

    // Having one test per property feels like a waste of time to me (Jon)...
    // If any of them fail, I'm going to be looking here anyway, and they're
    // fairly interrelated anyway.
    'ComputedProperties': (args) {
      LocalDateTime start = LocalDateTime(2011, 6, 3, 19, 15);
      LocalDateTime end = LocalDateTime(2011, 8, 2, 22, 45);
      Assert.AreEqual(start, SampleInterval.IsoLocalStart);
      Assert.AreEqual(end, SampleInterval.IsoLocalEnd);
      Assert.AreEqual(SampleEnd - SampleStart, SampleInterval.Duration);
    },

    'Contains_Instant_Normal': (args) {
      Assert.IsTrue(SampleInterval.Contains(SampleStart));
      Assert.IsFalse(SampleInterval.Contains(SampleEnd));
      Assert.IsFalse(SampleInterval.Contains(Instant.MinValue));
      Assert.IsFalse(SampleInterval.Contains(Instant.MaxValue));
    },

    'Contains_Instant_WholeOfTime_ViaNullity': (args) {
      ZoneInterval interval = ZoneInterval('All Time', null, null,
          Offset.FromHours(9), Offset.FromHours(1));
      Assert.IsTrue(interval.Contains(SampleStart));
      Assert.IsTrue(interval.Contains(Instant.MinValue));
      Assert.IsTrue(interval.Contains(Instant.MaxValue));
    },

    'Contains_Instant_WholeOfTime_ViaSpecialInstants': (args) {
      ZoneInterval interval = ZoneInterval('All Time', Instant.BeforeMinValue, Instant.AfterMaxValue,
          Offset.FromHours(9), Offset.FromHours(1));
      Assert.IsTrue(interval.Contains(SampleStart));
      Assert.IsTrue(interval.Contains(Instant.MinValue));
      Assert.IsTrue(interval.Contains(Instant.MaxValue));
    },

    'Contains_LocalInstant_WholeOfTime': (args) {
      ZoneInterval interval = ZoneInterval('All Time', Instant.BeforeMinValue, Instant.AfterMaxValue,
          Offset.FromHours(9), Offset.FromHours(1));
      Assert.IsTrue(interval.ContainsLocalInstant(SampleStart.PlusOffset(Offset.Zero)));
      Assert.IsTrue(interval.ContainsLocalInstant(Instant.MinValue.PlusOffset(Offset.Zero)));
      Assert.IsTrue(interval.ContainsLocalInstant(Instant.MaxValue.PlusOffset(Offset.Zero)));
    },

    'Contains_OutsideLocalInstantange': (args) {
      ZoneInterval veryEarly = ZoneInterval('Very early', Instant.BeforeMinValue, Instant.MinValue + Duration.FromHours(8), Offset.FromHours(-9), Offset.Zero);
      ZoneInterval veryLate = ZoneInterval('Very late', Instant.MaxValue.MinusDuration(Duration.FromHours(8)), Instant.AfterMaxValue, Offset.FromHours(9), Offset.Zero);
      // The instants are contained...
      Assert.IsTrue(veryEarly.Contains(Instant.MinValue + Duration.FromHours(4)));
      Assert.IsTrue(veryLate.Contains(Instant.MaxValue.MinusDuration(Duration.FromHours(4))));
      // But there are no valid local instants
      Assert.IsFalse(veryEarly.ContainsLocalInstant(Instant.MinValue.PlusOffset(Offset.Zero)));
      Assert.IsFalse(veryLate.ContainsLocalInstant(Instant.MaxValue.PlusOffset(Offset.Zero)));
    },

    'IsoLocalStartAndEnd_Infinite': (args) {
      var interval = ZoneInterval('All time', null, null, Offset.Zero, Offset.Zero);
      Assert.Throws<StateError>(() => interval.IsoLocalStart.toString());
      Assert.Throws<StateError>(() => interval.IsoLocalEnd.toString());
    },

    'IsoLocalStartAndEnd_OutOfRange': (args) {
      var interval = ZoneInterval('All time', Instant.MinValue, null, Offset.FromHours(-1), Offset.Zero);
      Assert.Throws<OverflowException>(() => interval.IsoLocalStart.toString());
      interval = ZoneInterval('All time', null, Instant.MaxValue, Offset.FromHours(11), Offset.Zero);
      Assert.Throws<OverflowException>(() => interval.IsoLocalEnd.toString());
    },

    'Equality': (args) {
      TestHelper.TestEqualsClass(
          // Equal values
          ZoneInterval('name', SampleStart, SampleEnd, Offset.FromHours(1), Offset.FromHours(2)),
          ZoneInterval('name', SampleStart, SampleEnd, Offset.FromHours(1), Offset.FromHours(2)),
          // Unequal values
          [
            ZoneInterval('name2', SampleStart, SampleEnd, Offset.FromHours(1), Offset.FromHours(2)),
            ZoneInterval('name', SampleStart.PlusNanoseconds(1), SampleEnd, Offset.FromHours(1), Offset.FromHours(2)),
            ZoneInterval('name', SampleStart, SampleEnd.PlusNanoseconds(1), Offset.FromHours(1), Offset.FromHours(2)),
            ZoneInterval('name', SampleStart, SampleEnd, Offset.FromHours(2), Offset.FromHours(2)),
            ZoneInterval('name', SampleStart, SampleEnd, Offset.FromHours(1), Offset.FromHours(3)),
          ]);
    },

    'EqualityOperators': (args) {
      ZoneInterval val1 = ZoneInterval('name', SampleStart, SampleEnd, Offset.FromHours(1), Offset.FromHours(2));
      ZoneInterval val2 = ZoneInterval('name', SampleStart, SampleEnd, Offset.FromHours(1), Offset.FromHours(2));
      ZoneInterval val3 = ZoneInterval('name2', SampleStart, SampleEnd, Offset.FromHours(1), Offset.FromHours(2));
      ZoneInterval? val4 = _Null();

      Assert.IsTrue(val1 == val2);
      Assert.IsFalse(val1 == val3);
      Assert.IsFalse(val1 == val4);
      Assert.IsFalse(val4 == val1);
      Assert.IsTrue(val4 == null);
      Assert.IsTrue(null == val4);

      Assert.IsFalse(val1 != val2);
      Assert.IsTrue(val1 != val3);
      Assert.IsTrue(val1 != val4);
      Assert.IsTrue(val4 != val1);
      Assert.IsFalse(val4 != null);
      Assert.IsFalse(null != val4);
    },

    'ZoneIntervalToString': (args) {
      // noda_dart: toString() always uses the invariant culture (C#: CultureSaver.SetCultures(CultureInfo.InvariantCulture)).
      Assert.AreEqual('TestTime: [2011-06-03T10:15:00Z, 2011-08-02T13:45:00Z) +09 (+01)', SampleInterval.toString());
    },
  });
}

// noda_dart: C#'s `ZoneInterval? val4 = null;`, opaque to flow analysis.
ZoneInterval? _Null() => null;
