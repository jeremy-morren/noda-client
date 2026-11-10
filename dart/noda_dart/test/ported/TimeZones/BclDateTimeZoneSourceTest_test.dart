// Ported from NodaTime 6e024dde: src/NodaTime.Test/TimeZones/BclDateTimeZoneSourceTest.cs
// Copyright 2012 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda_dart: BclDateTimeZoneSource is SystemDateTimeZoneSource, over the host's own zones.

import 'package:noda_dart/src/DateTimeZone.dart';
import 'package:noda_dart/src/NodaConstants.dart';
import 'package:noda_dart/src/Offset.dart';
import 'package:noda_dart/src/System/DateTime.dart';
import 'package:noda_dart/src/System/TimeZoneInfo.dart';
import 'package:noda_dart/src/System/TimeZoneNotFoundException.dart';
import 'package:noda_dart/src/TimeZones/DateTimeZoneCache.dart';
import 'package:noda_dart/src/TimeZones/SystemDateTimeZone.dart';
import 'package:noda_dart/src/TimeZones/SystemDateTimeZoneSource.dart';
import 'package:noda_dart/src/TimeZones/TimeZoneInfoInterceptor.dart';

import '../../helpers/Assertions.dart';
import '../../helpers/Scenarios.dart';
import '../../scenarios/TimeZones/BclDateTimeZoneSourceTest.generated.dart' as scenarios;
import 'TimeZoneInfoReplacer.dart';

void main() {
  port(scenarios.fixture, {
    'UtcDoesNotEqualBuiltIn': (args) {
      var zone = SystemDateTimeZoneSource().ForId('UTC');
      Assert.AreNotEqual(DateTimeZone.Utc, zone);
    },

    'FixedOffsetDoesNotEqualBuiltIn': (args) {
      // Only a few fixed zones are advertised by Windows. We happen to know this one
      // is wherever we run tests :)
      // Unfortunately, it doesn't always exist on Mono (at least not on the Raspberry Pi...)
      // noda_dart: nor with IANA IDs (TZif files, Intl).
      String id = 'UTC-02';
      var source = SystemDateTimeZoneSource();
      if (!source.GetIds().contains(id)) Assert.Ignore('Test assumes existence of BCL zone with ID: $id');

      var zone = source.ForId(id);
      Assert.AreNotEqual(DateTimeZone.ForOffset(Offset.FromHours(-2)), zone);
      Assert.AreEqual(id, zone.Id);
      Assert.AreEqual(Offset.FromHours(-2), zone.GetZoneInterval(NodaConstants.UnixEpoch).WallOffset);
    },

    'ForId_Invalid': (args) {
      Assert.Throws<ArgumentError>(() => SystemDateTimeZoneSource().ForId('This will never be a valid ID'));
    },

    'CanLookupLocalTimeZoneById': (args) {
      // Note that this test can fail legitimately, as there are valid situations where TimeZoneInfo.Local returns
      // a time zone that is not one of the system time zones.  These are unlikely to be cases that we encounter
      // in practice, though.

      // However, there _are_ cases where we can't fetch the local timezone at all (sigh, Mono), so we'll have to
      // skip this test then.
      // noda_dart: without TimeZoneInfo (TZif files, Intl), the source's default zone ID stands for TimeZoneInfo.Local.
      Object? local;
      try {
        local = TimeZoneInfoInterceptor.Shim == null
            ? SystemDateTimeZoneSource().GetSystemDefaultId()
            : TimeZoneInfoInterceptor.Local;
      } on TimeZoneNotFoundException {
        // See https://bugzilla.xamarin.com/show_bug.cgi?id=11817
        Assert.Ignore('Test requires ability to fetch BCL local time zone');
      }
      if (local == null) {
        // https://github.com/nodatime/nodatime/issues/235#issuecomment-80932079
        Assert.Ignore('Test requires ability to fetch BCL local time zone (was null)');
      }

      // Now that we have our BCL local time zone, we should be able to look it up in the source.

      var source = SystemDateTimeZoneSource();
      String? id = source.GetSystemDefaultId();
      Assert.IsNotNull(id);

      // These lines replicate how DateTimeZoneCache implements GetSystemDefault().
      Assert.Contains(id, source.GetIds().toList(), 'BCL local time zone ID should be included in the source ID list');
      var zone = source.ForId(id!);

      Assert.IsNotNull(zone); // though really we only need to test that the call above didn't throw.
    },

    // This is effectively a test for DateTimeZoneCache, but is particularly
    // important for the BclDateTimeZoneSource. See
    // https://github.com/nodatime/nodatime/issues/332
    'ProviderReturnsBclDateTimeZoneForAllAdvertisedIds': (args) {
      var source = SystemDateTimeZoneSource();
      var provider = DateTimeZoneCache(source);
      var nonBclZones = provider.Ids.map((id) => provider[id]).where((zone) => zone is! SystemDateTimeZone);
      Assert.IsEmpty(nonBclZones);
    },

    'LocalZoneIsNotSystemZone': (args) {
      var systemZone = TimeZoneInfo.CreateCustomTimeZone('Normal zone', 0, 'Display', 'Standard');
      var localZone =
          TimeZoneInfo.CreateCustomTimeZone('Local zone not in system zones', 5 * TimeSpanTicks.PerHour, 'Foo', 'Bar');
      var replacer = TimeZoneInfoReplacer.Replace(localZone, [systemZone]);
      try {
        var source = SystemDateTimeZoneSource();
        CollectionAssert.AreEqual([systemZone.Id], source.GetIds().toList());

        // We can't look it up later, but we can still find it...
        Assert.AreEqual(localZone.Id, source.GetSystemDefaultId());
      } finally {
        replacer.Dispose();
      }
    },

    'LocalZoneIsNull': (args) {
      var systemZone = TimeZoneInfo.CreateCustomTimeZone('Normal zone', 0, 'Display', 'Standard');
      var replacer = TimeZoneInfoReplacer.Replace(null, [systemZone]);
      try {
        var source = SystemDateTimeZoneSource();
        Assert.Null(source.GetSystemDefaultId());
        CollectionAssert.AreEqual([systemZone.Id], source.GetIds().toList());
      } finally {
        replacer.Dispose();
      }
    },
  });
}
