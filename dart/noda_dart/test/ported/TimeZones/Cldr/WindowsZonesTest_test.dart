// Ported from NodaTime 6e024dde: src/NodaTime.Test/TimeZones/Cldr/WindowsZonesTest.cs
// Copyright 2017 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:noda_dart/src/TimeZones/Cldr/MapZone.dart';
import 'package:noda_dart/src/TimeZones/Cldr/WindowsZones.dart';
import 'package:noda_dart/src/TimeZones/IO/DateTimeZoneReader.dart';
import 'package:noda_dart/src/TimeZones/IO/DateTimeZoneWriter.dart';
import 'package:noda_dart/src/Utility/Stream.dart';

import '../../../helpers/Assertions.dart';
import '../../../helpers/Scenarios.dart';
import '../../../scenarios/TimeZones/Cldr/WindowsZonesTest.generated.dart' as scenarios;

final MapZone MapZone1 = MapZone('windowsId1', 'territory1', ['id1.1', 'id1.2', 'id1.3']);
final MapZone MapZone2 = MapZone('windowsId2', MapZone.PrimaryTerritory, ['primaryId2']);
final MapZone MapZone3 = MapZone('windowsId3', MapZone.PrimaryTerritory, ['primaryId3']);

void main() {
  port(scenarios.fixture, {
    'Properties': (args) {
      var zones = WindowsZones.NewVersionTzdbVersionWindowsVersionMapZones(
          'version', 'tzdbVersion', 'windowsVersion', [MapZone1, MapZone2, MapZone3]);
      Assert.AreEqual('version', zones.Version);
      Assert.AreEqual('tzdbVersion', zones.TzdbVersion);
      Assert.AreEqual('windowsVersion', zones.WindowsVersion);
      Assert.AreEqual('primaryId2', zones.PrimaryMapping['windowsId2']);
      Assert.AreEqual('primaryId3', zones.PrimaryMapping['windowsId3']);
      Assert.AreEqual([MapZone1, MapZone2, MapZone3], zones.MapZones);
    },

    'ReadWrite': (args) {
      var zones = WindowsZones.NewVersionTzdbVersionWindowsVersionMapZones(
          'version', 'tzdbVersion', 'windowsVersion', [MapZone1, MapZone2, MapZone3]);

      var stream = MemoryStream();
      var writer = DateTimeZoneWriter.NewOutputStringPool(stream, null);
      zones.Write(writer);
      stream.Position = 0;

      var reader = DateTimeZoneReader.NewInputStringPool(stream, null);
      var zones2 = WindowsZones.Read(reader);

      Assert.AreEqual('version', zones2.Version);
      Assert.AreEqual('tzdbVersion', zones2.TzdbVersion);
      Assert.AreEqual('windowsVersion', zones2.WindowsVersion);
      Assert.AreEqual('primaryId2', zones2.PrimaryMapping['windowsId2']);
      Assert.AreEqual('primaryId3', zones2.PrimaryMapping['windowsId3']);
      Assert.AreEqual([MapZone1, MapZone2, MapZone3], zones2.MapZones);
    },
  });
}
