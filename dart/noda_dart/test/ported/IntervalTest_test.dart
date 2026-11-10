// Ported from NodaTime 6e024dde: src/NodaTime.Test/IntervalTest.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda_dart: Deconstruct is a getter returning a record; C#'s NodaTime.Duration is Duration.

import 'package:noda_dart/src/Duration.dart';
import 'package:noda_dart/src/Instant.dart';
import 'package:noda_dart/src/Interval.dart';
import 'package:noda_dart/src/LocalDateTime.dart';
import 'package:noda_dart/src/NodaConstants.dart';
import 'package:noda_dart/src/Text/InstantPattern.dart';

import '../helpers/Assertions.dart';
import '../helpers/Scenarios.dart';
import '../helpers/TestHelper.dart';
import '../scenarios/IntervalTest.generated.dart' as scenarios;

final Instant SampleStart = NodaConstants.UnixEpoch.PlusNanoseconds(-30001);
final Instant SampleEnd = NodaConstants.UnixEpoch.PlusNanoseconds(40001);

void main() {
  port(scenarios.fixture, {
    'Construction_Success': (args) {
      var interval = Interval(SampleStart, SampleEnd);
      Assert.AreEqual(SampleStart, interval.Start);
      Assert.AreEqual(SampleEnd, interval.End);
    },

    'Construction_EqualStartAndEnd': (args) {
      var interval = Interval(SampleStart, SampleStart);
      Assert.AreEqual(SampleStart, interval.Start);
      Assert.AreEqual(SampleStart, interval.End);
      Assert.AreEqual(Duration.Zero, interval.Duration);
    },

    'Construction_EndBeforeStart': (args) {
      Assert.Throws<RangeError>(() => Interval(SampleEnd, SampleStart));
      // noda_dart: C#'s (Instant?) casts: Dart has the one constructor, taking nullable instants.
      Instant? nullableEnd = SampleEnd;
      Instant? nullableStart = SampleStart;
      Assert.Throws<RangeError>(() => Interval(nullableEnd, nullableStart));
    },

    'Equals': (args) {
      TestHelper.TestEqualsStruct(
          Interval(SampleStart, SampleEnd),
          Interval(SampleStart, SampleEnd),
          [Interval(NodaConstants.UnixEpoch, SampleEnd)]);
      TestHelper.TestEqualsStruct(
          Interval(null, SampleEnd),
          Interval(null, SampleEnd),
          [Interval(NodaConstants.UnixEpoch, SampleEnd)]);
      TestHelper.TestEqualsStruct(
          Interval(SampleStart, SampleEnd),
          Interval(SampleStart, SampleEnd),
          [Interval(NodaConstants.UnixEpoch, SampleEnd)]);
      TestHelper.TestEqualsStruct(
          Interval(null, null),
          Interval(null, null),
          [Interval(NodaConstants.UnixEpoch, SampleEnd)]);
    },

    'Operators': (args) {
      TestHelper.TestOperatorEquality(
          Interval(SampleStart, SampleEnd),
          Interval(SampleStart, SampleEnd),
          Interval(NodaConstants.UnixEpoch, SampleEnd));
    },

    'Duration': (args) {
      var interval = Interval(SampleStart, SampleEnd);
      Assert.AreEqual(Duration.FromNanoseconds(70002), interval.Duration);
    },

    'ToStringUsesExtendedIsoFormat': (args) {
      var start = LocalDateTime(2013, 4, 12, 17, 53, 23).PlusNanoseconds(123456789).InUtc().ToInstant();
      var end = LocalDateTime(2013, 10, 12, 17, 1, 2, 120).InUtc().ToInstant();
      var value = Interval(start, end);
      Assert.AreEqual('2013-04-12T17:53:23.123456789Z/2013-10-12T17:01:02.12Z', value.toString());
    },

    'ToString_Infinite': (args) {
      var value = Interval(null, null);
      Assert.AreEqual('StartOfTime/EndOfTime', value.toString());
    },

    'Contains': (args) {
      final [String candidateText, bool expectedResult] = args;
      var start = Instant.FromUtc(2000, 1, 1, 0, 0);
      var end = Instant.FromUtc(2020, 1, 1, 0, 0);
      var interval = Interval(start, end);
      var candidate = InstantPattern.ExtendedIso.Parse(candidateText).Value;
      Assert.AreEqual(expectedResult, interval.Contains(candidate));
    },

    'Contains_Infinite': (args) {
      var interval = Interval(null, null);
      Assert.IsTrue(interval.Contains(Instant.MaxValue));
      Assert.IsTrue(interval.Contains(Instant.MinValue));
    },

    'HasStart': (args) {
      Assert.IsTrue(Interval(Instant.MinValue, null).HasStart);
      Assert.IsFalse(Interval(null, Instant.MinValue).HasStart);
    },

    'HasEnd': (args) {
      Assert.IsTrue(Interval(null, Instant.MaxValue).HasEnd);
      Assert.IsFalse(Interval(Instant.MaxValue, null).HasEnd);
    },

    'Start': (args) {
      Assert.AreEqual(NodaConstants.UnixEpoch, Interval(NodaConstants.UnixEpoch, null).Start);
      Interval noStart = Interval(null, NodaConstants.UnixEpoch);
      Assert.Throws<StateError>(() => noStart.Start.toString());
    },

    'End': (args) {
      Assert.AreEqual(NodaConstants.UnixEpoch, Interval(null, NodaConstants.UnixEpoch).End);
      Interval noEnd = Interval(NodaConstants.UnixEpoch, null);
      Assert.Throws<StateError>(() => noEnd.End.toString());
    },

    'Contains_EmptyInterval': (args) {
      var instant = NodaConstants.UnixEpoch;
      var interval = Interval(instant, instant);
      Assert.IsFalse(interval.Contains(instant));
    },

    'Contains_EmptyInterval_MaxValue': (args) {
      var instant = Instant.MaxValue;
      var interval = Interval(instant, instant);
      // This would have been true under Noda Time 1.x
      Assert.IsFalse(interval.Contains(instant));
    },

    'Deconstruction': (args) {
      // noda_dart: C#'s new Instant() (the default value) is the Unix epoch.
      var start = NodaConstants.UnixEpoch;
      var end = start.PlusTicks(1000000);
      var value = Interval(start, end);

      final (Instant? actualStart, Instant? actualEnd) = value.Deconstruct;

      Assert.Multiple(() {
        Assert.AreEqual(start, actualStart);
        Assert.AreEqual(end, actualEnd);
      });
    },

    'Deconstruction_IntervalWithoutStart': (args) {
      Instant? start = NullInstant();
      var end = Instant.NewDaysNanoOfDay(1500, 1000000);
      var value = Interval(start, end);

      final (Instant? actualStart, Instant? actualEnd) = value.Deconstruct;

      Assert.Multiple(() {
        Assert.AreEqual(start, actualStart);
        Assert.AreEqual(end, actualEnd);
      });
    },

    'Deconstruction_IntervalWithoutEnd': (args) {
      var start = Instant.NewDaysNanoOfDay(1500, 1000000);
      Instant? end = NullInstant();
      var value = Interval(start, end);

      final (Instant? actualStart, Instant? actualEnd) = value.Deconstruct;

      Assert.Multiple(() {
        Assert.AreEqual(start, actualStart);
        Assert.AreEqual(end, actualEnd);
      });
    },
  }, skip: {
    'DefaultConstructor': SkipReasons.DefaultConstructor,
    'XmlSerialization': SkipReasons.Xml,
    'XmlSerialization_Extremes': SkipReasons.Xml,
    'XmlSerialization_ExtraContent': SkipReasons.Xml,
    'XmlSerialization_SwapAttributeOrder': SkipReasons.Xml,
    'XmlSerialization_FromBeginningOfTime': SkipReasons.Xml,
    'XmlSerialization_ToEndOfTime': SkipReasons.Xml,
    'XmlSerialization_AllOfTime': SkipReasons.Xml,
    'XmlSerialization_Invalid': SkipReasons.Xml,
  });
}

// noda_dart: new code. C#'s `Instant? start = null;`, opaque to flow analysis.
Instant? NullInstant() => null;
