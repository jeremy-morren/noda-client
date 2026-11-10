// Ported from NodaTime 6e024dde: src/NodaTime.Test/Testing/TimeZones/FakeDateTimeZoneSourceTest.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda_dart: TimeZoneInfo.Local.Id is SystemDateTimeZoneSource().GetSystemDefaultId().

import 'package:noda_dart/src/DateTimeZone.dart';
import 'package:noda_dart/src/NodaConstants.dart';
import 'package:noda_dart/src/Offset.dart';
import 'package:noda_dart/src/Testing/TimeZones/FakeDateTimeZoneSource.dart';
import 'package:noda_dart/src/Testing/TimeZones/SingleTransitionDateTimeZone.dart';
import 'package:noda_dart/src/TimeZones/SystemDateTimeZoneSource.dart';

import '../../../helpers/Assertions.dart';
import '../../../helpers/Scenarios.dart';
import '../../../scenarios/Testing/TimeZones/FakeDateTimeZoneSourceTest.generated.dart' as scenarios;

void main() {
  port(scenarios.fixture, {
    'Ids': (args) {
      var source = (FakeDateTimeZoneSourceBuilder()
            ..Add(CreateZone('x'))
            ..Add(CreateZone('y'))
            ..Add(CreateZone('a'))
            ..Add(CreateZone('b')))
          .Build();
      CollectionAssert.AreEquivalent(source.GetIds(), ['x', 'y', 'a', 'b']);
    },

    'ForId_Present': (args) {
      var zone = CreateZone('x');
      var source = (FakeDateTimeZoneSourceBuilder()
            // The "right" one and some others
            ..Add(zone)
            ..Add(CreateZone('y'))
            ..Add(CreateZone('a'))
            ..Add(CreateZone('b')))
          .Build();
      Assert.AreSame(zone, source.ForId('x'));
    },

    'ForId_Missing': (args) {
      var source = (FakeDateTimeZoneSourceBuilder()
            ..Add(CreateZone('x'))
            ..Add(CreateZone('y')))
          .Build();
      Assert.Throws<ArgumentError>(() => source.ForId('missing'));
    },

    'DuplicateIds': (args) {
      var builder = FakeDateTimeZoneSourceBuilder()
        ..Add(CreateZone('x'))
        ..Add(CreateZone('y'))
        ..Add(CreateZone('x'));
      AssertBuildFails(builder);
    },

    'ValidWindowsMapping': (args) {
      String? localId = SystemDateTimeZoneSource().GetSystemDefaultId();
      if (localId == null) {
        Assert.Ignore('The host has no system default time zone ID');
      }
      var source = (FakeDateTimeZoneSourceBuilder()
            ..BclIdsToZoneIds.addAll({localId: 'x'})
            ..Zones.addAll([CreateZone('x'), CreateZone('y')]))
          .Build();
      Assert.AreEqual('x', source.GetSystemDefaultId());
    },

    'InvalidWindowsMapping_MissingZone': (args) {
      String? localId = SystemDateTimeZoneSource().GetSystemDefaultId();
      if (localId == null) {
        Assert.Ignore('The host has no system default time zone ID');
      }
      var source = FakeDateTimeZoneSourceBuilder()
        ..BclIdsToZoneIds.addAll({localId: 'z'})
        ..Zones.addAll([CreateZone('x'), CreateZone('y')]);
      AssertBuildFails(source);
    },

    'GetEnumerator': (args) {
      var x = CreateZone('x');
      var y = CreateZone('y');
      var source = FakeDateTimeZoneSourceBuilder()..Zones.addAll([x, y]);

      // Tests IEnumerable<T>
      CollectionAssert.AreEqual([x, y], source.toList());
      // Tests IEnumerable
      CollectionAssert.AreEqual([x, y], source.whereType<DateTimeZone>().toList());
    },
  }, skip: {
    'NullZoneViaCollectionInitializer': SkipReasons.NullSafety,
    'NullZoneViaProperty': "null safety: Dart's types don't allow a null zone in the builder's Zones list",
    'InvalidWindowsMapping_NullCanonicalId':
        "null safety: Dart's types don't allow a null canonical ID in the builder's BclIdsToZoneIds map",
  });
}

// We don't care about the details of the time zones, just the IDs
DateTimeZone CreateZone(String id) {
  return SingleTransitionDateTimeZone.TransitionPointOffsetBeforeOffsetAfter(
      NodaConstants.UnixEpoch, Offset.FromHours(1), Offset.FromHours(2), id);
}

// We don't really care how it fails - just that an exception is thrown.
// Unfortunately NUnit requires the exact exception type :(
void AssertBuildFails(FakeDateTimeZoneSourceBuilder builder) {
  bool success = false;
  try {
    builder.Build();
    success = true;
  } catch (_) {
    // Expected
  }
  Assert.IsFalse(success);
}
