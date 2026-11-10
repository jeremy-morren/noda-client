// Ported from NodaTime 6e024dde: src/NodaTime.Test/TimeZones/FixedDateTimeZoneTest.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:noda_dart/src/DateTimeZone.dart';
import 'package:noda_dart/src/Instant.dart';
import 'package:noda_dart/src/LocalDateTime.dart';
import 'package:noda_dart/src/NodaConstants.dart';
import 'package:noda_dart/src/Offset.dart';
import 'package:noda_dart/src/TimeZones/FixedDateTimeZone.dart';
import 'package:noda_dart/src/TimeZones/ZoneInterval.dart';

import '../../helpers/Assertions.dart';
import '../../helpers/Scenarios.dart';
import '../../helpers/TestHelper.dart';
import '../../scenarios/TimeZones/FixedDateTimeZoneTest.generated.dart' as scenarios;
import 'IO/DtzIoHelper.dart';

final Offset ZoneOffset = Offset.FromHours(-8);
final FixedDateTimeZone TestZone = FixedDateTimeZone.NewOffset(ZoneOffset);
final ZoneInterval FixedPeriod = ZoneInterval(TestZone.Id, Instant.BeforeMinValue, Instant.AfterMaxValue, ZoneOffset, Offset.Zero);

void main() {
  port(scenarios.fixture, {
    'IsFixed_ReturnsTrue': (args) {
      Assert.IsTrue(TestZone.IsFixed);
    },

    'GetZoneIntervalInstant_ZoneInterval': (args) {
      var actual = TestZone.GetZoneInterval(NodaConstants.UnixEpoch);
      Assert.AreEqual(FixedPeriod, actual);
    },

    'SimpleProperties_ReturnValuesFromConstructor': (args) {
      Assert.AreEqual('UTC-08', TestZone.Id, 'TestZone.Id');
      Assert.AreEqual('UTC-08', TestZone.GetZoneInterval(NodaConstants.UnixEpoch).Name);
      Assert.AreEqual(ZoneOffset, TestZone.GetUtcOffset(NodaConstants.UnixEpoch));
      Assert.AreEqual(ZoneOffset, TestZone.MinOffset);
      Assert.AreEqual(ZoneOffset, TestZone.MaxOffset);
    },

    'GetZoneIntervals_ReturnsSingleInterval': (args) {
      var mapping = TestZone.MapLocal(LocalDateTime(2001, 7, 1, 1, 0, 0));
      Assert.AreEqual(FixedPeriod, mapping.EarlyInterval);
      Assert.AreEqual(FixedPeriod, mapping.LateInterval);
      Assert.AreEqual(1, mapping.Count);
    },

    'For_Id_FixedOffset': (args) {
      String id = 'UTC+05:30';
      DateTimeZone zone = FixedDateTimeZone.GetFixedZoneOrNull(id)!;
      Assert.AreEqual(DateTimeZone.ForOffset(Offset.FromHoursAndMinutes(5, 30)), zone);
      Assert.AreEqual(id, zone.Id);
    },

    'For_Id_FixedOffset_NonCanonicalId': (args) {
      String id = 'UTC+05:00:00';
      DateTimeZone zone = FixedDateTimeZone.GetFixedZoneOrNull(id)!;
      Assert.AreEqual(zone, DateTimeZone.ForOffset(Offset.FromHours(5)));
      Assert.AreEqual('UTC+05', zone.Id);
    },

    'For_Id_InvalidFixedOffset': (args) {
      Assert.IsNull(FixedDateTimeZone.GetFixedZoneOrNull('UTC+5Months'));
    },

    'ExplicitNameAppearsInZoneInterval': (args) {
      var zone = FixedDateTimeZone.NewIdOffsetName('id', Offset.FromHours(5), 'name');
      var interval = zone.GetZoneInterval(NodaConstants.UnixEpoch);
      Assert.AreEqual('id', zone.Id); // Check we don't get this wrong...
      Assert.AreEqual('name', interval.Name);
      Assert.AreEqual('name', zone.Name);
    },

    'ZoneIntervalNameDefaultsToZoneId': (args) {
      var zone = FixedDateTimeZone.NewIdOffset('id', Offset.FromHours(5));
      var interval = zone.GetZoneInterval(NodaConstants.UnixEpoch);
      Assert.AreEqual('id', interval.Name);
      Assert.AreEqual('id', zone.Name);
    },

    'Read_NoNameInStream': (args) {
      var ioHelper = DtzIoHelper.CreateNoStringPool();
      var offset = Offset.FromHours(5);
      ioHelper.Writer.WriteOffset(offset);
      var zone = FixedDateTimeZone.Read(ioHelper.Reader, 'id') as FixedDateTimeZone;

      Assert.AreEqual('id', zone.Id);
      Assert.AreEqual(offset, zone.Offset);
      Assert.AreEqual('id', zone.Name);
    },

    'Read_WithNameInStream': (args) {
      var ioHelper = DtzIoHelper.CreateNoStringPool();
      var offset = Offset.FromHours(5);
      ioHelper.Writer.WriteOffset(offset);
      ioHelper.Writer.WriteString('name');
      var zone = FixedDateTimeZone.Read(ioHelper.Reader, 'id') as FixedDateTimeZone;

      Assert.AreEqual('id', zone.Id);
      Assert.AreEqual(offset, zone.Offset);
      Assert.AreEqual('name', zone.Name);
    },

    'Roundtrip': (args) {
      var ioHelper = DtzIoHelper.CreateNoStringPool();
      var oldZone = FixedDateTimeZone.NewIdOffsetName('id', Offset.FromHours(4), 'name');
      oldZone.Write(ioHelper.Writer);
      var newZone = FixedDateTimeZone.Read(ioHelper.Reader, 'id') as FixedDateTimeZone;

      Assert.AreEqual(oldZone.Id, newZone.Id);
      Assert.AreEqual(oldZone.Offset, newZone.Offset);
      Assert.AreEqual(oldZone.Name, newZone.Name);
    },

    'Equals': (args) {
      TestHelper.TestEqualsClass(FixedDateTimeZone.NewOffset(Offset.FromSeconds(300)),
          FixedDateTimeZone.NewOffset(Offset.FromSeconds(300)),
          [FixedDateTimeZone.NewOffset(Offset.FromSeconds(500))]);

      TestHelper.TestEqualsClass(FixedDateTimeZone.NewIdOffset('Foo', Offset.FromSeconds(300)),
          FixedDateTimeZone.NewIdOffset('Foo', Offset.FromSeconds(300)),
          [FixedDateTimeZone.NewIdOffset('Bar', Offset.FromSeconds(300))]);
    },
  });
}
