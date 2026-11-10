// Ported from NodaTime 6e024dde: src/NodaTime.Test/TimeZones/TzdbZoneLocationTest.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:noda_dart/src/TimeZones/IO/DateTimeZoneReader.dart';
import 'package:noda_dart/src/TimeZones/IO/DateTimeZoneWriter.dart';
import 'package:noda_dart/src/TimeZones/TzdbZoneLocation.dart';
import 'package:noda_dart/src/Utility/InvalidNodaDataException.dart';
import 'package:noda_dart/src/Utility/Stream.dart';

import '../../helpers/Assertions.dart';
import '../../helpers/Scenarios.dart';
import '../../scenarios/TimeZones/TzdbZoneLocationTest.generated.dart' as scenarios;

void main() {
  port(scenarios.fixture, {
    'Valid': (args) {
      var location = TzdbZoneLocation(
          60 * 3600 + 15 * 60 + 5,
          100 * 3600 + 30 * 60 + 10,
          'Country name',
          'CO',
          'Etc/MadeUpZone',
          'Comment');
      Assert.AreEqual(60.25 + 5.0 / 3600, location.Latitude, 0.000001);
      Assert.AreEqual(100.5 + 10.0 / 3600, location.Longitude, 0.000001);
      Assert.AreEqual('Country name', location.CountryName);
      Assert.AreEqual('CO', location.CountryCode);
      Assert.AreEqual('Etc/MadeUpZone', location.ZoneId);
      Assert.AreEqual('Comment', location.Comment);
    },

    'LatitudeRange': (args) {
      Assert.Throws<RangeError>(() => TzdbZoneLocation(90 * 3600 + 1, 0, 'Name', 'CO', 'Zone', ''));
      Assert.Throws<RangeError>(() => TzdbZoneLocation(-90 * 3600 - 1, 0, 'Name', 'CO', 'Zone', ''));
      // We'll assume these are built correctly: we're just checking the constructor doesn't throw.
      TzdbZoneLocation(90 * 3600, 0, 'Name', 'CO', 'Zone', '');
      TzdbZoneLocation(-90 * 3600, 0, 'Name', 'CO', 'Zone', '');
    },

    'LongitudeRange': (args) {
      Assert.Throws<RangeError>(() => TzdbZoneLocation(0, 180 * 3600 + 1, 'Name', 'CO', 'Zone', ''));
      Assert.Throws<RangeError>(() => TzdbZoneLocation(0, -180 * 3600 - 1, 'Name', 'CO', 'Zone', ''));
      // We'll assume these are built correctly: we're just checking the constructor doesn't throw.
      TzdbZoneLocation(0, 180 * 3600, 'Name', 'CO', 'Zone', '');
      TzdbZoneLocation(0, -180 * 3600, 'Name', 'CO', 'Zone', '');
    },

    'Constructor_InvalidArguments': (args) {
      // Not ported: the four ArgumentNullException checks (null safety: the parameters are non-nullable in Dart).
      Assert.Throws<ArgumentError>(() => TzdbZoneLocation(0, 0, '', 'CO', 'Zone', ''));
      Assert.Throws<ArgumentError>(() => TzdbZoneLocation(0, 0, 'Name', 'Long code', 'Zone', ''));
      Assert.Throws<ArgumentError>(() => TzdbZoneLocation(0, 0, 'Name', 'S', 'Zone', ''));
    },

    'Serialization': (args) {
      var location = TzdbZoneLocation(
          60 * 3600 + 15 * 60 + 5,
          100 * 3600 + 30 * 60 + 10,
          'Country name',
          'CO',
          'Etc/MadeUpZone',
          'Comment');

      var stream = MemoryStream();
      var writer = DateTimeZoneWriter.NewOutputStringPool(stream, null);
      location.Write(writer);
      stream.Position = 0;

      var reader = DateTimeZoneReader.NewInputStringPool(stream, null);
      var location2 = TzdbZoneLocation.Read(reader);

      Assert.AreEqual(60.25 + 5.0 / 3600, location2.Latitude, 0.000001);
      Assert.AreEqual(100.5 + 10.0 / 3600, location2.Longitude, 0.000001);
      Assert.AreEqual('Country name', location2.CountryName);
      Assert.AreEqual('CO', location2.CountryCode);
      Assert.AreEqual('Etc/MadeUpZone', location2.ZoneId);
      Assert.AreEqual('Comment', location2.Comment);
    },

    'ReadInvalid': (args) {
      var stream = MemoryStream();
      var writer = DateTimeZoneWriter.NewOutputStringPool(stream, null);
      // This is invalid
      writer.WriteSignedCount(90 * 3600 + 1);
      writer.WriteSignedCount(0);
      writer.WriteString('name');
      writer.WriteString('co');
      writer.WriteString('Europe/Somewhere');
      writer.WriteString('');
      stream.Position = 0;
      var reader = DateTimeZoneReader.NewInputStringPool(stream, null);
      Assert.Throws<InvalidNodaDataException>(() => TzdbZoneLocation.Read(reader));
    },
  });
}
