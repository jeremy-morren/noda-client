// Ported from NodaTime 6e024dde: src/NodaTime.Test/Extensions/DateTimeZoneProviderExtensionsTest.cs
// Copyright 2017 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda_dart: the C# class is DayOfWeekExtensionsTest, excluded by the generator; ported anyway.

import 'package:noda_dart/src/DateTimeZoneProviders.dart';
import 'package:noda_dart/src/Extensions/DateTimeZoneProviderExtensions.dart';
import 'package:noda_dart/src/Testing/TimeZones/FakeDateTimeZoneSource.dart';

import '../../helpers/Assertions.dart';
import '../../helpers/Scenarios.dart';
import '../../scenarios/Extensions/DayOfWeekExtensionsTest.generated.dart' as scenarios;

void main() {
  port(scenarios.fixture, {
    'GetAllZones': (args) {
      // Note: in ID order.
      var zone1 = DateTimeZoneProviders.Tzdb['America/New_York'];
      var zone2 = DateTimeZoneProviders.Tzdb['Europe/London'];
      var zone3 = DateTimeZoneProviders.Tzdb['Europe/Paris'];

      var provider = (FakeDateTimeZoneSourceBuilder()
            ..Add(zone1)
            ..Add(zone2)
            ..Add(zone3))
          .Build()
          .ToProvider();
      CollectionAssert.AreEqual([zone1, zone2, zone3], provider.GetAllZones());
    },
  });
}
