// Ported from NodaTime 6e024dde: src/NodaTime.Test/DateTimeZoneProvidersTest.cs
// Copyright 2012 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda_dart: excluded by the generator; ported anyway. DateTimeZoneProviders.Bcl and .Serialization aren't ported.

import 'package:noda_dart/src/DateTimeZoneProviders.dart';

import '../helpers/Assertions.dart';
import '../helpers/Scenarios.dart';
import '../scenarios/DateTimeZoneProvidersTest.generated.dart' as scenarios;

void main() {
  port(scenarios.fixture, {
    'TzdbProviderUsesTzdbSource': (args) {
      Assert.IsTrue(DateTimeZoneProviders.Tzdb.VersionId.startsWith('TZDB: '));
    },

    'AllTzdbTimeZonesLoad': (args) {
      var allZones = DateTimeZoneProviders.Tzdb.Ids.map((id) => DateTimeZoneProviders.Tzdb[id]).toList();
      // Just to stop the variable from being lonely. In reality, it's likely there'll be a breakpoint here to inspect a particular zone...
      Assert.IsTrue(allZones.length > 50);
    },
  }, skip: {
    'BclProviderUsesTimeZoneInfoSource':
        "DateTimeZoneProviders.Bcl isn't ported (the system's own zones are noda_dart's system library)",
    'SerializationDelegatesToXmlSerializerSettings': SkipReasons.Xml,
  });
}
