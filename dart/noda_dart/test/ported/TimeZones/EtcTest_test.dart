// Ported from NodaTime 6e024dde: src/NodaTime.Test/TimeZones/EtcTest.cs
// Copyright 2012 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:noda_dart/src/DateTimeZoneProviders.dart';
import 'package:noda_dart/src/Offset.dart';
import 'package:noda_dart/src/TimeZones/FixedDateTimeZone.dart';

import '../../helpers/Assertions.dart';
import '../../helpers/Scenarios.dart';
import '../../scenarios/TimeZones/EtcTest.generated.dart' as scenarios;

/// Tests for fixed "Etc/GMT+x" zones. These just test that the time zones are built
/// appropriately; FixedDateTimeZoneTest takes care of the rest.
void main() {
  port(scenarios.fixture, {
    'FixedEasternZone': (args) {
      String id = 'Etc/GMT+5';
      var zone = DateTimeZoneProviders.Tzdb[id];
      Assert.AreEqual(id, zone.Id);
      Assert.IsInstanceOf<FixedDateTimeZone>(zone);
      FixedDateTimeZone fixedZone = zone as FixedDateTimeZone;
      Assert.AreEqual(Offset.FromHours(-5), fixedZone.Offset);
    },

    'FixedWesternZone': (args) {
      String id = 'Etc/GMT-4';
      var zone = DateTimeZoneProviders.Tzdb[id];
      Assert.AreEqual(id, zone.Id);
      Assert.IsInstanceOf<FixedDateTimeZone>(zone);
      FixedDateTimeZone fixedZone = zone as FixedDateTimeZone;
      Assert.AreEqual(Offset.FromHours(4), fixedZone.Offset);
    },
  });
}
