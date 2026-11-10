// Ported from NodaTime 6e024dde: src/NodaTime.Test/TimeZones/DateTimeZoneCacheTest.cs
// Copyright 2012 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda_dart: tests of sources returning null aren't ported (null safety).

import 'package:noda_dart/src/DateTimeZone.dart';
import 'package:noda_dart/src/DateTimeZoneProviders.dart';
import 'package:noda_dart/src/NodaConstants.dart';
import 'package:noda_dart/src/Offset.dart';
import 'package:noda_dart/src/Testing/TimeZones/SingleTransitionDateTimeZone.dart';
import 'package:noda_dart/src/TimeZones/DateTimeZoneCache.dart';
import 'package:noda_dart/src/TimeZones/DateTimeZoneNotFoundException.dart';
import 'package:noda_dart/src/TimeZones/IDateTimeZoneSource.dart';

import '../../helpers/Assertions.dart';
import '../../helpers/Scenarios.dart';
import '../../scenarios/TimeZones/DateTimeZoneCacheTest.generated.dart' as scenarios;

/// Tests for DateTimeZoneCache.
void main() {
  port(scenarios.fixture, {
    'CachingForPresentValues': (args) {
      var source = TestDateTimeZoneSource(['Test1', 'Test2']);
      var provider = DateTimeZoneCache(source);
      var zone1a = provider['Test1'];
      Assert.IsNotNull(zone1a);
      Assert.AreEqual('Test1', source.LastRequestedId);

      // Hit up the cache (and thus the source) for Test2
      Assert.IsNotNull(provider['Test2']);
      Assert.AreEqual('Test2', source.LastRequestedId);

      // Ask for Test1 again
      var zone1b = provider['Test1'];
      // We won't have consulted the source again
      Assert.AreEqual('Test2', source.LastRequestedId);

      Assert.AreSame(zone1a, zone1b);
    },

    'SourceIsNotAskedForUtcIfNotAdvertised': (args) {
      var source = TestDateTimeZoneSource(['Test1', 'Test2']);
      var provider = DateTimeZoneCache(source);
      var zone = provider[DateTimeZone.UtcId];
      Assert.IsNotNull(zone);
      Assert.IsNull(source.LastRequestedId);
    },

    'SourceIsAskedForUtcIfAdvertised': (args) {
      var source = TestDateTimeZoneSource(['Test1', 'Test2', 'UTC']);
      var provider = DateTimeZoneCache(source);
      var zone = provider[DateTimeZone.UtcId];
      Assert.IsNotNull(zone);
      Assert.AreEqual('UTC', source.LastRequestedId);
    },

    'SourceIsNotAskedForUnknownIds': (args) {
      var source = TestDateTimeZoneSource(['Test1', 'Test2']);
      var provider = DateTimeZoneCache(source);
      Assert.Throws<DateTimeZoneNotFoundException>(() => provider['Unknown']);
      Assert.IsNull(source.LastRequestedId);
    },

    'UtcIsReturnedInIdsIfAdvertisedByProvider': (args) {
      var source = TestDateTimeZoneSource(['Test1', 'Test2', 'UTC']);
      var provider = DateTimeZoneCache(source);
      Assert.True(provider.Ids.contains(DateTimeZone.UtcId));
    },

    'UtcIsNotReturnedInIdsIfNotAdvertisedByProvider': (args) {
      var source = TestDateTimeZoneSource(['Test1', 'Test2']);
      var provider = DateTimeZoneCache(source);
      Assert.False(provider.Ids.contains(DateTimeZone.UtcId));
    },

    'FixedOffsetSucceedsWhenNotAdvertised': (args) {
      var source = TestDateTimeZoneSource(['Test1', 'Test2']);
      var provider = DateTimeZoneCache(source);
      String id = 'UTC+05:30';
      DateTimeZone zone = provider[id];
      Assert.AreEqual(DateTimeZone.ForOffset(Offset.FromHoursAndMinutes(5, 30)), zone);
      Assert.AreEqual(id, zone.Id);
      Assert.IsNull(source.LastRequestedId);
    },

    'FixedOffsetConsultsSourceWhenAdvertised': (args) {
      String id = 'UTC+05:30';
      var source = TestDateTimeZoneSource(['Test1', 'Test2', id]);
      var provider = DateTimeZoneCache(source);
      DateTimeZone zone = provider[id];
      Assert.AreEqual(id, zone.Id);
      Assert.AreEqual(id, source.LastRequestedId);
    },

    'FixedOffsetUncached': (args) {
      String id = 'UTC+05:26';
      var source = TestDateTimeZoneSource(['Test1', 'Test2']);
      var provider = DateTimeZoneCache(source);
      DateTimeZone zone1 = provider[id];
      DateTimeZone zone2 = provider[id];
      Assert.AreNotSame(zone1, zone2);
      Assert.AreEqual(zone1, zone2);
    },

    'FixedOffsetZeroReturnsUtc': (args) {
      String id = 'UTC+00:00';
      var source = TestDateTimeZoneSource(['Test1', 'Test2']);
      var provider = DateTimeZoneCache(source);
      DateTimeZone zone = provider[id];
      Assert.AreEqual(DateTimeZone.Utc, zone);
      Assert.IsNull(source.LastRequestedId);
    },

    'Tzdb_Indexer_InvalidFixedOffset': (args) {
      Assert.Throws<DateTimeZoneNotFoundException>(() => DateTimeZoneProviders.Tzdb['UTC+5Months']);
    },

    'EmptyIdAccepted': (args) {
      var provider = DateTimeZoneCache(TestDateTimeZoneSource(['Test1', 'Test2']));
      Assert.Throws<DateTimeZoneNotFoundException>(() => provider['']);
    },

    'VersionIdPassThrough': (args) {
      var provider = DateTimeZoneCache(TestDateTimeZoneSource(['Test1', 'Test2'])..VersionId = 'foo');
      Assert.AreEqual('foo', provider.VersionId);
    },

    // Test for issue 7 in bug tracker
    'Tzdb_IterateOverIds': (args) {
      // According to bug, this would go bang
      int count = DateTimeZoneProviders.Tzdb.Ids.length;

      Assert.IsTrue(count > 1);
      int utcCount = DateTimeZoneProviders.Tzdb.Ids.where((id) => id == DateTimeZone.UtcId).length;
      Assert.AreEqual(1, utcCount);
    },

    'Tzdb_Indexer_UtcId': (args) {
      Assert.AreEqual(DateTimeZone.Utc, DateTimeZoneProviders.Tzdb[DateTimeZone.UtcId]);
    },

    'Tzdb_Indexer_AmericaLosAngeles': (args) {
      const String americaLosAngeles = 'America/Los_Angeles';
      var actual = DateTimeZoneProviders.Tzdb[americaLosAngeles];
      Assert.IsNotNull(actual);
      Assert.AreNotEqual(DateTimeZone.Utc, actual);
      Assert.AreEqual(americaLosAngeles, actual.Id);
    },

    'Tzdb_Ids_All': (args) {
      var actual = DateTimeZoneProviders.Tzdb.Ids;
      var actualCount = actual.length;
      Assert.IsTrue(actualCount > 1);
      var utc = actual.where((id) => id == DateTimeZone.UtcId).single;
      Assert.AreEqual(DateTimeZone.UtcId, utc);
    },

    /// Simply tests that every ID in the built-in database can be fetched. This is also
    /// helpful for diagnostic debugging when we want to check that some potential
    /// invariant holds for all time zones...
    'Tzdb_Indexer_AllIds': (args) {
      for (String id in DateTimeZoneProviders.Tzdb.Ids) {
        Assert.IsNotNull(DateTimeZoneProviders.Tzdb[id]);
      }
    },

    'GetSystemDefault_SourceReturnsNullId': (args) {
      var source = NullReturningTestDateTimeZoneSource(['foo', 'bar']);
      var cache = DateTimeZoneCache(source);
      Assert.Throws<DateTimeZoneNotFoundException>(() => cache.GetSystemDefault());
    },
  }, skip: {
    'Construction_NullProvider': SkipReasons.NullSafety,
    'InvalidSource_NullVersionId': "null safety: IDateTimeZoneSource.VersionId is a non-nullable String in Dart",
    'InvalidSource_NullIdSequence': "null safety: IDateTimeZoneSource.GetIds() returns a non-nullable Iterable<String> in Dart",
    'InvalidSource_ReturnsNullForAdvertisedId': "null safety: IDateTimeZoneSource.ForId returns a non-nullable DateTimeZone in Dart",
    'InvalidProvider_NullIdWithinSequence': "null safety: IDateTimeZoneSource.GetIds() returns an Iterable<String> (no null entries) in Dart",
    'NullIdRejected': SkipReasons.NullSafety,
  });
}

class TestDateTimeZoneSource implements IDateTimeZoneSource {
  String? LastRequestedId;
  final List<String> _ids;

  TestDateTimeZoneSource(List<String> ids)
      : _ids = ids,
        VersionId = 'test version';

  @override
  Iterable<String> GetIds() {
    return _ids;
  }

  @override
  DateTimeZone ForId(String id) {
    LastRequestedId = id;
    // noda_dart: C#'s string.GetHashCode() is Dart's String.hashCode; C#'s % is remainder.
    return SingleTransitionDateTimeZone.TransitionPointOffsetBeforeOffsetAfter(
        NodaConstants.UnixEpoch, Offset.Zero, Offset.FromHours(id.hashCode.remainder(18)), id);
  }

  @override
  String VersionId;

  @override
  String? GetSystemDefaultId() => 'map';
}

// A test source that returns null from ForId and GetSystemDefaultId()
class NullReturningTestDateTimeZoneSource extends TestDateTimeZoneSource {
  NullReturningTestDateTimeZoneSource(super.ids);

  @override
  DateTimeZone ForId(String id) {
    // Still remember what was requested.
    super.ForId(id);
        // noda_dart: C# returns null!, which Dart's type doesn't allow.
    throw UnsupportedError('ForId returns null in C#');
  }

  @override
  String? GetSystemDefaultId() => null;
}
