// Ported from NodaTime 6e024dde: src/NodaTime.Test/OffsetTimeTest.cs
// Copyright 2017 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda_dart: no reflection: LocalTimeProperties lists the common properties by hand.

import 'package:noda_dart/src/CalendarSystem.dart';
import 'package:noda_dart/src/Globalization/NodaCultureInfo.dart';
import 'package:noda_dart/src/LocalDate.dart';
import 'package:noda_dart/src/LocalTime.dart';
import 'package:noda_dart/src/Offset.dart';
import 'package:noda_dart/src/OffsetTime.dart';
import 'package:noda_dart/src/TimeAdjusters.dart';

import '../helpers/Assertions.dart';
import '../helpers/Scenarios.dart';
import '../helpers/TestHelper.dart';
import '../scenarios/OffsetTimeTest.generated.dart' as scenarios;

void main() {
  port(scenarios.fixture, {
    'LocalTimeProperties': (args) {
      LocalTime local = LocalTime(5, 23, 45).PlusNanoseconds(987654321);
      Offset offset = Offset.FromHours(5);

      OffsetTime od = OffsetTime(local, offset);

      // noda_dart: the properties OffsetTime declares that LocalTime declares too (C# finds them by reflection).
      final commonProperties = <String, (Object? Function(LocalTime), Object? Function(OffsetTime))>{
        'Hour': ((x) => x.Hour, (x) => x.Hour),
        'ClockHourOfHalfDay': ((x) => x.ClockHourOfHalfDay, (x) => x.ClockHourOfHalfDay),
        'Minute': ((x) => x.Minute, (x) => x.Minute),
        'Second': ((x) => x.Second, (x) => x.Second),
        'Millisecond': ((x) => x.Millisecond, (x) => x.Millisecond),
        'TickOfSecond': ((x) => x.TickOfSecond, (x) => x.TickOfSecond),
        'TickOfDay': ((x) => x.TickOfDay, (x) => x.TickOfDay),
        'NanosecondOfSecond': ((x) => x.NanosecondOfSecond, (x) => x.NanosecondOfSecond),
        'NanosecondOfDay': ((x) => x.NanosecondOfDay, (x) => x.NanosecondOfDay),
      };
      for (final property in commonProperties.entries) {
        Assert.AreEqual(property.value.$1(local), property.value.$2(od), property.key);
      }
    },

    'ComponentProperties': (args) {
      var time = LocalTime(12, 34, 15);
      var offset = Offset.FromHours(5);

      var offsetDate = OffsetTime(time, offset);
      Assert.AreEqual(offset, offsetDate.Offset);
      Assert.AreEqual(time, offsetDate.TimeOfDay);
    },

    'Equality': (args) {
      LocalTime time1 = LocalTime(4, 56, 23, 123);
      LocalTime time2 = LocalTime(6, 23, 12, 987);
      Offset offset1 = Offset.FromHours(1);
      Offset offset2 = Offset.FromHours(2);

      OffsetTime equal1 = OffsetTime(time1, offset1);
      OffsetTime equal2 = OffsetTime(time1, offset1);
      OffsetTime unequalByOffset = OffsetTime(time1, offset2);
      OffsetTime unequalByLocal = OffsetTime(time2, offset1);

      TestHelper.TestEqualsStruct(equal1, equal2, [unequalByOffset]);
      TestHelper.TestEqualsStruct(equal1, equal2, [unequalByLocal]);

      TestHelper.TestOperatorEquality(equal1, equal2, unequalByOffset);
      TestHelper.TestOperatorEquality(equal1, equal2, unequalByLocal);
    },

    'On': (args) {
      var time = LocalTime(14, 15, 12).PlusNanoseconds(123456789);
      var date = LocalDate(2012, 6, 19, CalendarSystem.Julian);
      var offset = Offset.FromHours(5);

      Assert.AreEqual(OffsetTime(time, offset).On(date), time.On(date).WithOffset(offset));
    },

    'WithOffset': (args) {
      var time = LocalTime(14, 15, 12).PlusNanoseconds(123456789);
      var initial = OffsetTime(time, Offset.FromHours(2));
      var actual = initial.WithOffset(Offset.FromHours(5));
      var expected = OffsetTime(time, Offset.FromHours(5));
      Assert.AreEqual(expected, actual);
    },

    'WithAdjuster': (args) {
      var initial = OffsetTime(LocalTime(14, 15, 12), Offset.FromHours(-5));
      var actual = initial.With(TimeAdjusters.TruncateToHour);
      var expected = OffsetTime(LocalTime(14, 0), Offset.FromHours(-5));
      Assert.AreEqual(expected, actual);
    },

    'ToString_WithFormat': (args) {
      LocalTime time = LocalTime(14, 15, 12, 123);
      Offset offset = Offset.FromHours(1);
      OffsetTime offsetDate = OffsetTime(time, offset);
      Assert.AreEqual('14:15:12.123 01', offsetDate.ToStringPattern('HH:mm:ss.fff o<-HH>', NodaCultureInfo.InvariantCulture));
    },

    'ToString_WithNullFormat': (args) {
      LocalTime time = LocalTime(14, 15, 12, 123);
      Offset offset = Offset.FromHours(1);
      OffsetTime offsetDate = OffsetTime(time, offset);
      Assert.AreEqual('14:15:12+01', offsetDate.ToStringPattern(null, NodaCultureInfo.InvariantCulture));
    },

    'ToString_NoFormat': (args) {
      LocalTime time = LocalTime(14, 15, 12, 123);
      Offset offset = Offset.FromHours(1);
      OffsetTime offsetDate = OffsetTime(time, offset);
      // noda_dart: toString() always uses the invariant culture (no CultureSaver needed).
      Assert.AreEqual('14:15:12+01', offsetDate.toString());
    },

    'Deconstruction': (args) {
      var time = LocalTime(15, 33);
      var offset = Offset.FromHours(-2);
      var offsetTime = OffsetTime(time, offset);

      var (actualTime, actualOffset) = offsetTime.Deconstruct;

      Assert.Multiple(() {
        Assert.AreEqual(time, actualTime);
        Assert.AreEqual(offset, actualOffset);
      });
    },
  }, skip: {
    'XmlSerialization': SkipReasons.Xml,
    'XmlSerialization_Invalid': SkipReasons.Xml,
  });
}
