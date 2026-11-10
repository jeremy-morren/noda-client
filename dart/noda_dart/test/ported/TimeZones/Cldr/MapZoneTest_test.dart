// Ported from NodaTime 6e024dde: src/NodaTime.Test/TimeZones/Cldr/MapZoneTest.cs
// Copyright 2017 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:noda_dart/src/TimeZones/Cldr/MapZone.dart';
import 'package:noda_dart/src/TimeZones/IO/DateTimeZoneReader.dart';
import 'package:noda_dart/src/TimeZones/IO/DateTimeZoneWriter.dart';
import 'package:noda_dart/src/Utility/Stream.dart';

import '../../../helpers/Assertions.dart';
import '../../../helpers/Scenarios.dart';
import '../../../helpers/TestHelper.dart';
import '../../../scenarios/TimeZones/Cldr/MapZoneTest.generated.dart' as scenarios;

void main() {
  port(scenarios.fixture, {
    'Equality': (args) {
      var zone1 = MapZone('windowsId', 'territory', ['id1', 'id2', 'id3']);
      var zone2 = MapZone('windowsId', 'territory', ['id1', 'id2', 'id3']);
      var zone3 = MapZone('otherWindowsId', 'territory', ['id1', 'id2', 'id3']);
      var zone4 = MapZone('windowsId', 'otherTerritory', ['id1', 'id2', 'id3']);
      var zone5 = MapZone('windowsId', 'territory', ['id1', 'id2']);
      var zone6 = MapZone('windowsId', 'territory', ['id1', 'id2', 'id4']);
      TestHelper.TestEqualsClass(zone1, zone2, [zone3]);
      TestHelper.TestEqualsClass(zone1, zone2, [zone4]);
      TestHelper.TestEqualsClass(zone1, zone2, [zone5]);
      TestHelper.TestEqualsClass(zone1, zone2, [zone6]);
    },

    'ToString': (args) {
      var zone = MapZone('windowsId', 'territory', ['id1', 'id2', 'id3']);
      var expected = 'Windows ID: windowsId; Territory: territory; TzdbIds: id1 id2 id3';
      Assert.AreEqual(expected, zone.toString());
    },

    'ReadWrite': (args) {
      var zone = MapZone('windowsId', 'territory', ['id1', 'id2', 'id3']);
      var stream = MemoryStream();
      var writer = DateTimeZoneWriter.NewOutputStringPool(stream, null);
      zone.Write(writer);
      stream.Position = 0;

      var reader = DateTimeZoneReader.NewInputStringPool(stream, null);
      var zone2 = MapZone.Read(reader);
      Assert.AreEqual(zone, zone2);
    },
  });
}
