// Ported from NodaTime 6e024dde: src/NodaTime.TzdbCompiler.Test/ProgramTest.cs
// Copyright 2016 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda_dart: the internal WindowsZones constructor is WindowsZones.NewVersionTzdbVersionWindowsVersionMapZones.

import 'package:noda_dart/src/TimeZones/Cldr/MapZone.dart';
import 'package:noda_dart/src/TimeZones/Cldr/WindowsZones.dart';
import 'package:noda_dart/src/TzdbCompiler/Program.dart';

import '../../helpers/Assertions.dart';
import '../../helpers/Scenarios.dart';
import '../../scenarios/TzdbCompiler/ProgramTest.generated.dart' as scenarios;

void main() {
  port(scenarios.fixture, {
    'MergeWindowsZones': (args) {
      var originalZones = WindowsZones.NewVersionTzdbVersionWindowsVersionMapZones(
          'orig-version', 'orig-tzdb-version', 'orig-win-version', [
        MapZone('ID1', '001', ['A']),
        MapZone('ID1', 'T1-1', ['B', 'C']),
        MapZone('ID1', 'T1-2', ['D']),
        MapZone('ID2', '001', ['E']),
        MapZone('ID2', 'T2-1', ['F'])
      ]);

      var overrideZones = WindowsZones.NewVersionTzdbVersionWindowsVersionMapZones('override-version', '', '', [
        // Replace ID1 / 001
        MapZone('ID1', '001', ['A1']),
        // Delete ID1 / T1-1
        MapZone('ID1', 'T1-1', <String>[]),
        // (Leave ID1 / T1-2)
        // Add ID1 / T1-3
        MapZone('ID1', 'T1-3', ['B1', 'C1', 'G1']),
        // (Leave ID2 / 001)
        // Replace ID2 / T2-1
        MapZone('ID2', 'T2-1', ['H1']),
        // Add ID3 / 001
        MapZone('ID3', '001', ['I1'])
      ]);
      var actual = Program.MergeWindowsZones(originalZones, overrideZones);
      var expected = WindowsZones.NewVersionTzdbVersionWindowsVersionMapZones(
          'override-version', 'orig-tzdb-version', 'orig-win-version', [
        MapZone('ID1', '001', ['A1']),
        MapZone('ID1', 'T1-2', ['D']),
        MapZone('ID1', 'T1-3', ['B1', 'C1', 'G1']),
        MapZone('ID2', '001', ['E']),
        MapZone('ID2', 'T2-1', ['H1']),
        MapZone('ID3', '001', ['I1'])
      ]);

      // Could implement IEquatable<WindowsZones>, but it doesn't seem worth it right now.
      Assert.AreEqual(expected.Version, actual.Version);
      Assert.AreEqual(expected.TzdbVersion, actual.TzdbVersion);
      Assert.AreEqual(expected.WindowsVersion, actual.WindowsVersion);
      Assert.AreEqual(expected.MapZones, actual.MapZones);
    },
  });
}
