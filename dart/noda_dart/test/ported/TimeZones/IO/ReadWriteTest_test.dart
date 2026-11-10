// Ported from NodaTime 6e024dde: src/NodaTime.Test/TimeZones/IO/ReadWriteTest.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda_dart: Test_ZoneIntervalTransition is skipped on dart2js: its raw ticks exceed ±2^53.

import 'package:noda_dart/src/Duration.dart';
import 'package:noda_dart/src/Instant.dart';
import 'package:noda_dart/src/Offset.dart';
import 'package:noda_dart/src/TimeZones/IO/DateTimeZoneWriter.dart';
import 'package:noda_dart/src/Utility/Int64.dart';

import '../../../helpers/Assertions.dart';
import '../../../helpers/Scenarios.dart';
import '../../../scenarios/TimeZones/IO/ReadWriteTest.generated.dart' as scenarios;
import 'DtzIoHelper.dart';

void main() {
  port(scenarios.fixture, {
    'Count': (args) {
      var dio = DtzIoHelper.CreateNoStringPool();

      for (int i = 0; i < 16; i++) {
        dio.TestCount(i);
      }
      dio.TestCount(0x0f);
      dio.TestCount(0x10);
      dio.TestCount(0x7f);
      dio.TestCount(0x80);
      dio.TestCount(0x81);
      dio.TestCount(0x3fff);
      dio.TestCount(0x4000);
      dio.TestCount(0x4001);
      dio.TestCount(0x1fffff);
      dio.TestCount(0x200000);
      dio.TestCount(0x200001);
      dio.TestCount(Int64.Int32MaxValue);
      dio.TestCount(0, [0x00]);
      dio.TestCount(1, [0x01]);
      dio.TestCount(127, [0x7f]);
      dio.TestCount(128, [0x80, 0x01]);
      dio.TestCount(300, [0xac, 0x02]);
    },

    'SignedCount': (args) {
      var dio = DtzIoHelper.CreateNoStringPool();
      for (int i = -16; i < 16; i++) {
        dio.TestSignedCount(i);
      }
      dio.TestSignedCount(0x4000000);
      dio.TestSignedCount(-0x4000000);
      dio.TestSignedCount(Int64.Int32MinValue);
      dio.TestSignedCount(Int64.Int32MinValue + 1);
      dio.TestSignedCount(Int64.Int32MaxValue - 1);
      dio.TestSignedCount(Int64.Int32MaxValue);
      dio.TestSignedCount(0, [0x00]);
      dio.TestSignedCount(-1, [0x01]);
      dio.TestSignedCount(1, [0x02]);
      dio.TestSignedCount(-2, [0x03]);
      dio.TestSignedCount(64, [0x80, 0x01]);
      dio.TestSignedCount(-65, [0x81, 0x01]);
      dio.TestSignedCount(128, [0x80, 0x02]);
    },

    'Test_Dictionary': (args) {
      var dio = DtzIoHelper.CreateNoStringPool();
      var expected = <String, String>{};
      dio.TestDictionary(expected);

      expected['Able'] = 'able';
      dio.TestDictionary(expected);

      expected['Baker'] = 'baker';
      expected['Charlie'] = 'charlie';
      expected['Delta'] = 'delta';
      dio.TestDictionary(expected);
    },

    'Test_ZoneIntervalTransition': (args) {
      var dio = DtzIoHelper.CreateNoStringPool();
      dio.TestZoneIntervalTransition(null, Instant.BeforeMinValue);
      dio.TestZoneIntervalTransition(null, Instant.MinValue);
      // No test for Instant.MaxValue, as it's not on a tick boundary.
      dio.TestZoneIntervalTransition(null, Instant.AfterMaxValue);

      dio.TestZoneIntervalTransition(null, Instant.MinValue.PlusTicks(1));
      // The ZoneIntervalTransition has precision to the tick (with no real need to change that).
      // Round to the tick just lower than Instant.MaxValue...
      Instant tickBeforeMaxInstant = Instant.FromUnixTimeTicks(Instant.MaxValue.ToUnixTimeTicks());
      dio.TestZoneIntervalTransition(null, tickBeforeMaxInstant);

      // Encoding as hours-since-previous.
      Instant previous = Instant.FromUtc(1990, 1, 1, 11, 30); // arbitrary
      dio.TestZoneIntervalTransition(previous, previous);
      dio.TestZoneIntervalTransition(
          previous, previous + Duration.FromHours(DateTimeZoneWriterZoneIntervalConstants.MinValueForHoursSincePrevious));
      dio.TestZoneIntervalTransition(
          previous,
          previous +
              Duration.FromHours(DateTimeZoneWriterZoneIntervalConstants.MinValueForHoursSincePrevious - 1)); // too soon
      dio.TestZoneIntervalTransition(previous, previous + Duration.FromHours(1)); // too soon
      dio.TestZoneIntervalTransition(
          previous,
          previous +
              Duration.FromHours(DateTimeZoneWriterZoneIntervalConstants.MinValueForMinutesSinceEpoch - 1)); // maximum hours
      dio.TestZoneIntervalTransition(
          previous,
          previous +
              Duration.FromHours(DateTimeZoneWriterZoneIntervalConstants.MinValueForMinutesSinceEpoch)); // out of range
      // A large difference from the previous transition.
      dio.TestZoneIntervalTransition(Instant.MinValue.PlusTicks(1), tickBeforeMaxInstant);

      // Encoding as minutes-since-epoch.
      Instant epoch = DateTimeZoneWriterZoneIntervalConstants.EpochForMinutesSinceEpoch;
      dio.TestZoneIntervalTransition(null, epoch);
      dio.TestZoneIntervalTransition(
          null, epoch + Duration.FromMinutes(DateTimeZoneWriterZoneIntervalConstants.MinValueForMinutesSinceEpoch));
      dio.TestZoneIntervalTransition(null, epoch + Duration.FromMinutes(Int64.Int32MaxValue)); // maximum minutes

      // Out of range cases, or not a multiple of minutes since the epoch.
      dio.TestZoneIntervalTransition(null, epoch + Duration.FromHours(1)); // too soon
      dio.TestZoneIntervalTransition(null, epoch + Duration.FromMinutes(1)); // too soon
      dio.TestZoneIntervalTransition(null, epoch + Duration.FromSeconds(1));
      dio.TestZoneIntervalTransition(null, epoch + Duration.FromMilliseconds(1));
      dio.TestZoneIntervalTransition(null, epoch.MinusDuration(Duration.FromHours(1)));
      dio.TestZoneIntervalTransition(null, epoch + Duration.FromMinutes(Int64.Int32MaxValue + 1));

      // Example from Pacific/Auckland which failed at one time, and a similar one with seconds.
      dio.TestZoneIntervalTransition(null, Instant.FromUtc(1927, 11, 5, 14, 30));
      dio.TestZoneIntervalTransition(null, Instant.FromUtc(1927, 11, 5, 14, 30, 5));
    },

    'Test_Offset': (args) {
      var dio = DtzIoHelper.CreateNoStringPool();
      dio.TestOffset(Offset.MinValue);
      dio.TestOffset(Offset.MaxValue);
      dio.TestOffset(Offset.FromHours(0));
      dio.TestOffset(Offset.FromHours(5));
      dio.TestOffset(Offset.FromHours(-5));
      dio.TestOffset(Offset.FromHoursAndMinutes(5, 15));
      dio.TestOffset(Offset.FromHoursAndMinutes(5, 30));
      dio.TestOffset(Offset.FromHoursAndMinutes(5, 45));
      dio.TestOffset(Offset.FromHoursAndMinutes(-5, -15));
      dio.TestOffset(Offset.FromHoursAndMinutes(-5, -30));
      dio.TestOffset(Offset.FromHoursAndMinutes(-5, -45));
      dio.TestOffset(Offset.FromSeconds(1));
      dio.TestOffset(Offset.FromSeconds(-1));
      dio.TestOffset(Offset.FromSeconds(1000));
      dio.TestOffset(Offset.FromSeconds(-1000));
    },

    'String_NoPool': (args) {
      var dio = DtzIoHelper.CreateNoStringPool();
      dio.TestString('');
      dio.TestString('This is a test string');
    },

    'String_WithPool': (args) {
      var dio = DtzIoHelper.CreateWithStringPool();
      dio.TestString('');
      dio.TestString('This is a test string');
    },

    'ReadByte_AfterHasMoreData': (args) {
      var dio = DtzIoHelper.CreateNoStringPool();
      dio.Writer.WriteByte(5);

      Assert.IsTrue(dio.Reader.HasMoreData);
      Assert.AreEqual(5, dio.Reader.ReadByte());
    },

    'ReadString_AfterHasMoreData': (args) {
      var dio = DtzIoHelper.CreateNoStringPool();
      dio.Writer.WriteString('foo');

      Assert.IsTrue(dio.Reader.HasMoreData);
      Assert.AreEqual('foo', dio.Reader.ReadString());
    },
  }, skip: {
    if (isDart2js) 'Test_ZoneIntervalTransition': SkipReasons.Dart2jsInt,
  });
}
