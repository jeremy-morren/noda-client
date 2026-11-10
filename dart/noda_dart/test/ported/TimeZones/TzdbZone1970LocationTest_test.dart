// Ported from NodaTime 6e024dde: src/NodaTime.Test/TimeZones/TzdbZone1970LocationTest.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:noda_dart/src/TimeZones/IO/DateTimeZoneReader.dart';
import 'package:noda_dart/src/TimeZones/IO/DateTimeZoneWriter.dart';
import 'package:noda_dart/src/TimeZones/TzdbZone1970Location.dart';
import 'package:noda_dart/src/Utility/InvalidNodaDataException.dart';
import 'package:noda_dart/src/Utility/Stream.dart';

import '../../helpers/Assertions.dart';
import '../../helpers/Scenarios.dart';
import '../../helpers/TestHelper.dart';
import '../../scenarios/TimeZones/TzdbZone1970LocationTest.generated.dart' as scenarios;

final TzdbZone1970LocationCountry SampleCountry =
    TzdbZone1970LocationCountry('Country name', 'CO');

void main() {
  port(scenarios.fixture, {
    'Valid': (args) {
      var location = TzdbZone1970Location(
          60 * 3600 + 15 * 60 + 5,
          100 * 3600 + 30 * 60 + 10,
          [SampleCountry],
          'Etc/MadeUpZone',
          'Comment');
      Assert.AreEqual(60.25 + 5.0 / 3600, location.Latitude, 0.000001);
      Assert.AreEqual(100.5 + 10.0 / 3600, location.Longitude, 0.000001);
      Assert.AreEqual('Country name', location.Countries[0].Name);
      Assert.AreEqual('CO', location.Countries[0].Code);
      Assert.AreEqual('Etc/MadeUpZone', location.ZoneId);
      Assert.AreEqual('Comment', location.Comment);
    },

    'CountryToString': (args) => Assert.AreEqual('CO (Country name)', SampleCountry.toString()),

    'Serialization': (args) {
      var location = TzdbZone1970Location(
          60 * 3600 + 15 * 60 + 5,
          100 * 3600 + 30 * 60 + 10,
          [SampleCountry],
          'Etc/MadeUpZone',
          'Comment');
      var stream = MemoryStream();
      var writer = DateTimeZoneWriter.NewOutputStringPool(stream, null);
      location.Write(writer);
      stream.Position = 0;
      var reloaded = TzdbZone1970Location.Read(DateTimeZoneReader.NewInputStringPool(stream, null));
      Assert.AreEqual(location.Latitude, reloaded.Latitude);
      Assert.AreEqual(location.Longitude, reloaded.Longitude);
      CollectionAssert.AreEqual(location.Countries, reloaded.Countries);
      Assert.AreEqual(location.ZoneId, reloaded.ZoneId);
      Assert.AreEqual(location.Comment, reloaded.Comment);
    },

    'ReadInvalid': (args) {
      var stream = MemoryStream();
      var writer = DateTimeZoneWriter.NewOutputStringPool(stream, null);
      // Valid latitude/longitude
      writer.WriteSignedCount(0);
      writer.WriteSignedCount(0);
      // But no countries
      writer.WriteCount(0);
      writer.WriteString('Europe/Somewhere');
      writer.WriteString('');
      stream.Position = 0;
      var reader = DateTimeZoneReader.NewInputStringPool(stream, null);
      Assert.Throws<InvalidNodaDataException>(() => TzdbZone1970Location.Read(reader));
    },

    'LatitudeRange': (args) {
      Assert.Throws<RangeError>(() => TzdbZone1970Location(90 * 3600 + 1, 0, [SampleCountry], 'Zone', ''));
      Assert.Throws<RangeError>(() => TzdbZone1970Location(-90 * 3600 - 1, 0, [SampleCountry], 'Zone', ''));
      // We'll assume these are built correctly: we're just checking the constructor doesn't throw.
      TzdbZone1970Location(90 * 3600, 0, [SampleCountry], 'Zone', '');
      TzdbZone1970Location(-90 * 3600, 0, [SampleCountry], 'Zone', '');
    },

    'LongitudeRange': (args) {
      Assert.Throws<RangeError>(() => TzdbZone1970Location(0, 180 * 3600 + 1, [SampleCountry], 'Zone', ''));
      Assert.Throws<RangeError>(() => TzdbZone1970Location(0, -180 * 3600 - 1, [SampleCountry], 'Zone', ''));
      // We'll assume these are built correctly: we're just checking the constructor doesn't throw.
      TzdbZone1970Location(0, 180 * 3600, [SampleCountry], 'Zone', '');
      TzdbZone1970Location(0, -180 * 3600, [SampleCountry], 'Zone', '');
    },

    'Constructor_InvalidArguments': (args) {
      // Not ported: the null checks (null safety).
      // noda_dart: C# passes a null zone ID too; the empty countries check comes first there, so it's what throws.
      Assert.Throws<ArgumentError>(() => TzdbZone1970Location(0, 0, <TzdbZone1970LocationCountry>[], 'Zone', ''));
    },

    'CountryConstructor_InvalidArguments': (args) {
      // C# names the arguments: new Country(code: ..., name: ...); the constructor is Country(name, code).
      // Not ported: the two ArgumentNullException checks (null safety: name and code are non-nullable in Dart).
      Assert.Throws<ArgumentError>(() => TzdbZone1970LocationCountry('', 'CO'));
      Assert.Throws<ArgumentError>(() => TzdbZone1970LocationCountry('Name', 'Long code'));
      Assert.Throws<ArgumentError>(() => TzdbZone1970LocationCountry('Name', 'S'));
    },

    'CountryEquality': (args) {
      TestHelper.TestEqualsClass(TzdbZone1970LocationCountry('France', 'FR'), TzdbZone1970LocationCountry('France', 'FR'),
          [TzdbZone1970LocationCountry('Germany', 'DE')]);
    },
  });
}
