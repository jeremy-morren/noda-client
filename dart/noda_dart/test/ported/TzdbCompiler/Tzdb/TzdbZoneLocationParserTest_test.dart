// Ported from NodaTime 6e024dde: src/NodaTime.TzdbCompiler.Test/Tzdb/TzdbZoneLocationParserTest.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda_dart: TzdbZone1970Location.Country is TzdbZone1970LocationCountry; KeyNotFoundException is ArgumentError.

import 'package:noda_dart/src/TimeZones/TzdbZone1970Location.dart';
import 'package:noda_dart/src/TzdbCompiler/Tzdb/TzdbZoneLocationParser.dart';

import '../../../helpers/Assertions.dart';
import '../../../helpers/Scenarios.dart';
import '../../../scenarios/TzdbCompiler/Tzdb/TzdbZoneLocationParserTest.generated.dart' as scenarios;

final Map<String, String> SampleCountryMapping = <String, String>{
  'CA': 'Canada',
  'GB': 'Britain (UK)',
};

void main() {
  port(scenarios.fixture, {
    'ParseLocation_InvalidLength': (args) {
      final [String line] = args;
      Assert.Throws<ArgumentError>(() => TzdbZoneLocationParser.ParseLocation(line, SampleCountryMapping));
    },

    'ParseLocation_InvalidCountryCode': (args) {
      // Valid line, but not with our country code mapping...
      String line = 'FK\t-5142-05751\tAtlantic/Stanley';
      Assert.Throws<ArgumentError>(() => TzdbZoneLocationParser.ParseLocation(line, SampleCountryMapping));
    },

    'ParseLocation_Valid_NoComment': (args) {
      String line = 'GB\t+4000+03000\tEurope/London';
      var location = TzdbZoneLocationParser.ParseLocation(line, SampleCountryMapping);
      Assert.AreEqual('GB', location.CountryCode);
      Assert.AreEqual('Britain (UK)', location.CountryName);
      Assert.AreEqual(40, location.Latitude);
      Assert.AreEqual(30, location.Longitude);
      Assert.AreEqual('Europe/London', location.ZoneId);
      Assert.AreEqual('', location.Comment);
    },

    // Most of the code is just from ParseLocation; this is a smoke test, really.
    'ParseEnhancedLocation_Valid': (args) {
      var countries = <String, TzdbZone1970LocationCountry>{
        'CA': TzdbZone1970LocationCountry('Canada', 'CA'),
        'GB': TzdbZone1970LocationCountry('Britain (UK)', 'GB'),
        'US': TzdbZone1970LocationCountry('United States', 'US'),
      };
      String line = 'GB,CA\t+4000+03000\tEurope/London';
      var location = TzdbZoneLocationParser.ParseEnhancedLocation(line, countries);
      CollectionAssert.AreEqual([countries['GB'], countries['CA']], location.Countries);
      Assert.AreEqual(40, location.Latitude);
      Assert.AreEqual(30, location.Longitude);
      Assert.AreEqual('Europe/London', location.ZoneId);
      Assert.AreEqual('', location.Comment);
    },

    'ParseLocation_Valid_WithComment': (args) {
      String line = 'GB\t+4000+03000\tEurope/London\tSome comment';
      var location = TzdbZoneLocationParser.ParseLocation(line, SampleCountryMapping);
      Assert.AreEqual('GB', location.CountryCode);
      Assert.AreEqual('Britain (UK)', location.CountryName);
      Assert.AreEqual(40, location.Latitude);
      Assert.AreEqual(30, location.Longitude);
      Assert.AreEqual('Europe/London', location.ZoneId);
      Assert.AreEqual('Some comment', location.Comment);
    },

    'ParseCoordinates_InvalidLength': (args) {
      Assert.Throws<ArgumentError>(() => TzdbZoneLocationParser.ParseCoordinates('-77+166'));
    },

    'ParseCoordinates_Valid': (args) {
      final [String text, int expectedLatitude, int expectedLongitude] = args;
      List<int> actual = TzdbZoneLocationParser.ParseCoordinates(text);
      Assert.AreEqual(expectedLatitude, actual[0]);
      Assert.AreEqual(expectedLongitude, actual[1]);
    },
  });
}
