// Ported from NodaTime 6e024dde: src/NodaTime.Test/TimeZones/TzdbDateTimeZoneSourceTest.cs
// Copyright 2012 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda_dart: Aliases is a Map (no empty groups); MapTimeZoneInfoId takes an IHostTimeZone, not a TimeZoneInfo.

import 'dart:typed_data';

import 'package:noda_dart/src/DateTimeZone.dart';
import 'package:noda_dart/src/DateTimeZoneProviders.dart';
import 'package:noda_dart/src/Instant.dart';
import 'package:noda_dart/src/LocalDateTime.dart';
import 'package:noda_dart/src/NodaConstants.dart';
import 'package:noda_dart/src/Offset.dart';
import 'package:noda_dart/src/TimeZones/Cldr/MapZone.dart';
import 'package:noda_dart/src/TimeZones/Cldr/WindowsZones.dart';
import 'package:noda_dart/src/TimeZones/HostTimeZone.dart';
import 'package:noda_dart/src/TimeZones/IO/TzdbStreamData.dart';
import 'package:noda_dart/src/TimeZones/IO/TzdbStreamField.dart';
import 'package:noda_dart/src/TimeZones/IO/TzdbStreamFieldId.generated.dart';
import 'package:noda_dart/src/TimeZones/TzdbDateTimeZoneSource.dart';
import 'package:noda_dart/src/TimeZones/TzdbZone1970Location.dart';
import 'package:noda_dart/src/TimeZones/TzdbZoneLocation.dart';
import 'package:noda_dart/src/Utility/InvalidNodaDataException.dart';
import 'package:noda_dart/src/ZonedDateTime.dart';

import '../../helpers/Assertions.dart';
import '../../helpers/Fixtures.dart';
import '../../helpers/Scenarios.dart';
import '../../scenarios/TimeZones/TzdbDateTimeZoneSourceTest.generated.dart' as scenarios;

// Not ported: SystemTimeZones, SystemTimeZonesWithoutKnownFailures (excluded host zones).

void main() {
  port(scenarios.fixture, {
    /// Tests that we can load (and exercise) the binary Tzdb resource file distributed with Noda Time 1.1.0.
    /// This is effectively a black-box regression test that ensures that the stream format has not changed in a
    /// way such that a custom tzdb compiled with ZoneInfoCompiler from 1.1 would become unreadable.
    'CanLoadNodaTimeResourceFromOnePointOneRelease': (args) async {
      TzdbDateTimeZoneSource source;
      Uint8List stream = await ReadFixture('Tzdb2013bFromNodaTime1.1.nzd');
      source = TzdbDateTimeZoneSource.FromBytes(stream);
      Assert.AreEqual('TZDB: 2013b (mapping: 8274)', source.VersionId);

      var utc = Instant.FromUtc(2007, 8, 24, 9, 30, 0);

      // Test a regular zone with rules.
      var london = source.ForId('Europe/London');
      var inLondon = ZonedDateTime(utc, london);
      var expectedLocal = LocalDateTime(2007, 8, 24, 10, 30);
      Assert.AreEqual(expectedLocal, inLondon.LocalDateTime);

      // Test a fixed-offset zone.
      var utcFixed = source.ForId('Etc/UTC');
      var inUtcFixed = ZonedDateTime(utc, utcFixed);
      expectedLocal = LocalDateTime(2007, 8, 24, 9, 30);
      Assert.AreEqual(expectedLocal, inUtcFixed.LocalDateTime);

      // Test an alias.
      var jersey = source.ForId('Japan'); // Asia/Tokyo
      var inJersey = ZonedDateTime(utc, jersey);
      expectedLocal = LocalDateTime(2007, 8, 24, 18, 30);
      Assert.AreEqual(expectedLocal, inJersey.LocalDateTime);

      // Test ZoneLocations.
      var france = source.ZoneLocations!.where((g) => g.CountryName == 'France').single;
      // Tolerance of about 2 seconds
      Assert.AreEqual(48.86666, france.Latitude, 0.00055);
      Assert.AreEqual(2.3333, france.Longitude, 0.00055);
      Assert.AreEqual('Europe/Paris', france.ZoneId);
      Assert.AreEqual('FR', france.CountryCode);
      Assert.AreEqual('', france.Comment);
    },

    /// Simply tests that every ID in the built-in database can be fetched. This is also
    /// helpful for diagnostic debugging when we want to check that some potential
    /// invariant holds for all time zones...
    'ForId_AllIds': (args) {
      var source = TzdbDateTimeZoneSource.Default;
      for (String id in source.GetIds()) {
        Assert.IsNotNull(source.ForId(id));
      }
    },

    'ForId_Unknown': (args) {
      Assert.Throws<ArgumentError>(() => TzdbDateTimeZoneSource.Default.ForId('unknown'));
    },

    'UtcEqualsBuiltIn': (args) {
      var zone = TzdbDateTimeZoneSource.Default.ForId('UTC');
      Assert.AreEqual(DateTimeZone.Utc, zone);
    },

    // The following tests all make assumptions about the built-in TZDB data.
    // This is simpler than constructing fake data, and validates that the creation
    // mechanism matches the reading mechanism, too.
    'Aliases': (args) {
      var aliases = TzdbDateTimeZoneSource.Default.Aliases;
      CollectionAssert.AreEqual(['Europe/Belfast', 'Europe/Guernsey', 'Europe/Isle_of_Man', 'Europe/Jersey', 'GB', 'GB-Eire'],
          aliases['Europe/London']!.toList()); // ToArray call makes diagnostics more useful
      CollectionAssert.IsOrdered(aliases['Europe/London']!);
      // noda_dart: an ID with no aliases has no entry (an ILookup gives an empty group).
      CollectionAssert.IsEmpty(aliases['Europe/Jersey'] ?? const <String>[]);
    },

    'CanonicalIdMap_Contents': (args) {
      var map = TzdbDateTimeZoneSource.Default.CanonicalIdMap;
      Assert.AreEqual('Europe/London', map['Europe/Jersey']);
      Assert.AreEqual('Europe/London', map['Europe/London']);
    },

    'CanonicalIdMap_IsReadOnly': (args) {
      var map = TzdbDateTimeZoneSource.Default.CanonicalIdMap;
      Assert.Throws<UnsupportedError>(() => map['Foo'] = 'Bar');
    },

    // Sample zone location checks to ensure we've serialized and deserialized correctly
    // Input line: FR	+4852+00220	Europe/Paris
    'ZoneLocations_ContainsFrance': (args) {
      var zoneLocations = TzdbDateTimeZoneSource.Default.ZoneLocations!;
      var france = zoneLocations.where((g) => g.CountryName == 'France').single;
      // Tolerance of about 2 seconds
      Assert.AreEqual(48.86666, france.Latitude, 0.00055);
      Assert.AreEqual(2.3333, france.Longitude, 0.00055);
      Assert.AreEqual('Europe/Paris', france.ZoneId);
      Assert.AreEqual('FR', france.CountryCode);
      Assert.AreEqual('', france.Comment);
    },

    // Sample zone location checks to ensure we've serialized and deserialized correctly
    // Input line: GB,GG,IM,JE	+513030-0000731	Europe/London
    'Zone1970Locations_ContainsBritain': (args) {
      var zoneLocations = TzdbDateTimeZoneSource.Default.Zone1970Locations!;
      var britain = zoneLocations.where((g) => g.ZoneId == 'Europe/London').single;
      // Tolerance of about 2 seconds
      Assert.AreEqual(51.5083, britain.Latitude, 0.00055);
      Assert.AreEqual(-0.1253, britain.Longitude, 0.00055);
      Assert.AreEqual('Europe/London', britain.ZoneId);
      CollectionAssert.AreEqual(
          [
            TzdbZone1970LocationCountry('Britain (UK)', 'GB'),
            TzdbZone1970LocationCountry('Guernsey', 'GG'),
            TzdbZone1970LocationCountry('Isle of Man', 'IM'),
            TzdbZone1970LocationCountry('Jersey', 'JE')
          ],
          britain.Countries.toList());
      Assert.AreEqual('', britain.Comment);
    },

    // Input line: CA	+744144-0944945	America/Resolute	Central - NU (Resolute)
    // (Note: prior to 2016b, this was "Central Time - Resolute, Nunavut".)
    // (Note: prior to 2014f, this was "Central Standard Time - Resolute, Nunavut".)
    'ZoneLocations_ContainsResolute': (args) {
      var zoneLocations = TzdbDateTimeZoneSource.Default.ZoneLocations!;
      var resolute = zoneLocations.where((g) => g.ZoneId == 'America/Resolute').single;
      // Tolerance of about 2 seconds
      Assert.AreEqual(74.69555, resolute.Latitude, 0.00055);
      Assert.AreEqual(-94.82916, resolute.Longitude, 0.00055);
      Assert.AreEqual('Canada', resolute.CountryName);
      Assert.AreEqual('CA', resolute.CountryCode);
      Assert.AreEqual('Central - NU (Resolute)', resolute.Comment);
    },

    'TzdbVersion': (args) {
      var source = TzdbDateTimeZoneSource.Default;
      StringAssert.StartsWith('20', source.TzdbVersion);
    },

    'FixedDateTimeZoneName': (args) {
      var zulu = DateTimeZoneProviders.Tzdb['Etc/Zulu'];
      Assert.AreEqual('UTC', zulu.GetZoneInterval(NodaConstants.UnixEpoch).Name);
    },

    'VersionId': (args) {
      var source = TzdbDateTimeZoneSource.Default;
      StringAssert.StartsWith('TZDB: ${source.TzdbVersion}', source.VersionId);
    },

    'ValidateDefault': (args) => TzdbDateTimeZoneSource.Default.Validate(),

    'LocalZoneIsNull': (args) {
      // noda_dart: the host zone can't be replaced, so this maps a null zone directly.
      // If we have no system time zone, we have no ID to map it to.
      Assert.Null(TzdbDateTimeZoneSource.Default.MapTimeZoneInfoId(null));
    },

    'MapTimeZoneInfoId': (args) {
      final [String timeZoneInfoId, int standardUtc, String expectedId] = args;
      // C#: TimeZoneInfo.CreateCustomTimeZone(timeZoneInfoId, TimeSpan.FromHours(standardUtc), ...): a fixed zone.
      var zoneInfo = _FixedHostTimeZone(timeZoneInfoId, Offset.FromHours(standardUtc));
      var mappedId = TzdbDateTimeZoneSource.Default.MapTimeZoneInfoId(zoneInfo);
      Assert.AreEqual(expectedId, mappedId);

      // Do it again, and expect to get the same result again.
      // In the case of the "Lilo and Stitch" zone, this means hitting the cache rather than guessing
      // via transitions again.
      Assert.AreEqual(mappedId, TzdbDateTimeZoneSource.Default.MapTimeZoneInfoId(zoneInfo));
    },

    'CanonicalIdMapValueIsNotAKey': (args) {
      var builder = CreateSampleBuilder();
      builder.tzdbIdMap!['zone3'] = 'missing-zone';
      AssertInvalid(builder);
    },

    'CanonicalIdMapValueIsNotCanonical': (args) {
      var builder = CreateSampleBuilder();
      builder.tzdbIdMap!['zone4'] = 'zone3'; // zone3 is an alias for zone1
      AssertInvalid(builder);
    },

    'WindowsMappingWithoutPrimaryTerritory': (args) {
      var builder = CreateSampleBuilder();
      builder.windowsMapping = WindowsZones.NewVersionTzdbVersionWindowsVersionMapZones('cldr-version', 'tzdb-version', 'windows-version',
          [MapZone('windows-id', 'nonprimary', ['zone1', 'zone2'])]);
      AssertInvalid(builder);
    },

    'WindowsMappingPrimaryTerritoryNotInNonPrimary': (args) {
      var builder = CreateSampleBuilder();
      builder.windowsMapping = WindowsZones.NewVersionTzdbVersionWindowsVersionMapZones('cldr-version', 'tzdb-version', 'windows-version',
          [
            MapZone('windows-id', MapZone.PrimaryTerritory, ['zone1']),
            MapZone('windows-id', 'UK', ['zone2'])
          ]);
      AssertInvalid(builder);
    },

    'WindowsMappingUsesMissingId': (args) {
      var builder = CreateSampleBuilder();
      builder.windowsMapping = WindowsZones.NewVersionTzdbVersionWindowsVersionMapZones('cldr-version', 'tzdb-version', 'windows-version',
          [
            MapZone('windows-id', MapZone.PrimaryTerritory, ['zone4']),
            MapZone('windows-id', 'UK', ['zone4'])
          ]);
      AssertInvalid(builder);
    },

    'WindowsMappingContainsDuplicateTzdbIds_SameTerritory': (args) {
      var builder = CreateSampleBuilder();
      builder.windowsMapping = WindowsZones.NewVersionTzdbVersionWindowsVersionMapZones('cldr-version', 'tzdb-version', 'windows-version',
          [
            MapZone('windows-id', MapZone.PrimaryTerritory, ['zone1']),
            MapZone('windows-id', 'UK', ['zone1']),
            MapZone('windows-id', 'CA', ['zone2', 'zone2'])
          ]);
      AssertInvalid(builder);
    },

    'WindowsMappingContainsDuplicateTzdbIds_SameWindowsIdDifferentTerritory': (args) {
      var builder = CreateSampleBuilder();
      builder.windowsMapping = WindowsZones.NewVersionTzdbVersionWindowsVersionMapZones('cldr-version', 'tzdb-version', 'windows-version',
          [
            MapZone('windows-id', MapZone.PrimaryTerritory, ['zone1']),
            MapZone('windows-id', 'UK', ['zone1']),
            MapZone('windows-id', 'CA', ['zone1'])
          ]);
      AssertInvalid(builder);
    },

    'WindowsMappingContainsDuplicateTzdbIds_DifferentTerritories': (args) {
      var builder = CreateSampleBuilder();
      builder.windowsMapping = WindowsZones.NewVersionTzdbVersionWindowsVersionMapZones('cldr-version', 'tzdb-version', 'windows-version',
          [
            MapZone('windows-id1', MapZone.PrimaryTerritory, ['zone1']),
            MapZone('windows-id1', 'CA', ['zone1']),
            MapZone('windows-id2', MapZone.PrimaryTerritory, ['zone1']),
            MapZone('windows-id2', 'UK', ['zone1']),
          ]);
      AssertInvalid(builder);
    },

    'WindowsMappingContainsWindowsIdWithNoPrimaryTerritory': (args) {
      var builder = CreateSampleBuilder();
      builder.windowsMapping = WindowsZones.NewVersionTzdbVersionWindowsVersionMapZones('cldr-version', 'tzdb-version', 'windows-version',
          [
            MapZone('windows-id1', 'CA', ['zone1']),
          ]);
      AssertInvalid(builder);
    },

    'WindowsMappingContainsWindowsIdWithDuplicateTerritories': (args) {
      var builder = CreateSampleBuilder();
      builder.windowsMapping = WindowsZones.NewVersionTzdbVersionWindowsVersionMapZones('cldr-version', 'tzdb-version', 'windows-version',
          [
            MapZone('windows-id1', MapZone.PrimaryTerritory, ['zone1']),
            MapZone('windows-id1', 'CA', ['zone2']),
            MapZone('windows-id1', 'CA', ['zone3']),
          ]);
      AssertInvalid(builder);
    },

    'ZoneLocationsContainsMissingId': (args) {
      var builder = CreateSampleBuilder();
      builder.zoneLocations = List<TzdbZoneLocation>.unmodifiable([
        TzdbZoneLocation(0, 0, 'country', 'xx', 'zone4', 'comment')
      ]);
      AssertInvalid(builder);
    },

    'Zone1970LocationsContainsMissingId': (args) {
      var builder = CreateSampleBuilder();
      var country = TzdbZone1970LocationCountry('country', 'xx');
      builder.zone1970Locations = List<TzdbZone1970Location>.unmodifiable([
        TzdbZone1970Location(0, 0, [country], 'zone4', 'comment')
      ]);
      AssertInvalid(builder);
    },

    'WindowsToTzdbIds': (args) {
      var source = CreateComplexMappingSource();
      var actual = source.WindowsToTzdbIds;
      var expected = <String, String>{
        'win1': 'zone1',
        'win2': 'zone2',
        'win3': 'zone3',
        'win4': 'zone4',
      };
      // noda_dart: CollectionAssert.AreEquivalent on dictionaries compares their key/value pairs.
      CollectionAssert.AreEquivalent(expected.entries.map((e) => [e.key, e.value]), actual.entries.map((e) => [e.key, e.value]));
    },

    'TzdbToWindowsIds': (args) {
      var source = CreateComplexMappingSource();
      var actual = source.TzdbToWindowsIds;
      var expected = <String, String>{
        'zone1': 'win1',
        'link1': 'win1',
        'zone2': 'win2',
        'link2': 'win2',
        // No explicit zone3 mapping; link3a and link3b map to win3 and win4 respectively;
        // link3a "wins" as it's earlier lexicographically.
        'zone3': 'win3',
        'link3a': 'win3',
        // Explicit mapping to win4 from link3b.
        // This is unusual, but we handle it
        'link3b': 'win4',
        // link3c isn't mentioned at all, so we use the canonical ID
        'link3c': 'win3',
        'zone4': 'win4',
        'zone5': 'win4'
        // zone6 isn't mapped at all
      };
      CollectionAssert.AreEquivalent(expected.entries.map((e) => [e.key, e.value]), actual.entries.map((e) => [e.key, e.value]));
    },

    // We'll need to adjust the documentation if either of these tests starts to fail.
    'TzdbToWindowsIdDocumentationExamples': (args) {
      var source = TzdbDateTimeZoneSource.Default;
      String kolkata = 'Asia/Kolkata';
      String calcutta = 'Asia/Calcutta';
      String indiaStandardTime = 'India Standard Time';

      String asmara = 'Africa/Asmara';
      String eastAfricaStandardTime = 'E. Africa Standard Time';
      String nairobi = 'Africa/Nairobi';

      // Validate the claims about the source data
      Assert.AreEqual(kolkata, source.CanonicalIdMap[calcutta]);
      Assert.IsFalse(source.WindowsMapping.MapZones.expand((mz) => mz.TzdbIds).contains(kolkata));

      Assert.AreEqual(nairobi, source.CanonicalIdMap[asmara]);
      Assert.IsFalse(source.WindowsMapping.MapZones.expand((mz) => mz.TzdbIds).contains(asmara));

      // And the mappings
      var mapping = source.TzdbToWindowsIds;
      Assert.AreEqual(indiaStandardTime, mapping[kolkata]);
      Assert.AreEqual(eastAfricaStandardTime, mapping[asmara]);
    },

    // Asserts that my commentary is correct in https://github.com/nodatime/nodatime/pull/1393
    'UtcMappings': (args) {
      var source = TzdbDateTimeZoneSource.Default;
      // Note: was Etc/GMT before CLDR v39.
      Assert.AreEqual('Etc/UTC', source.WindowsToTzdbIds['UTC']);

      Assert.AreEqual('UTC', source.TzdbToWindowsIds['Etc/UTC']);
      // We follow the link
      Assert.AreEqual('UTC', source.TzdbToWindowsIds['Etc/GMT+0']);
    },

    'WindowsToTzdbIdDocumentationExamples': (args) {
      var source = TzdbDateTimeZoneSource.Default;
      String kolkata = 'Asia/Kolkata';
      String calcutta = 'Asia/Calcutta';
      String indiaStandardTime = 'India Standard Time';

      // Validate the claims about the source data
      Assert.AreEqual(kolkata, source.CanonicalIdMap[calcutta]);
      Assert.IsFalse(source.WindowsMapping.MapZones.expand((mz) => mz.TzdbIds).contains(kolkata));

      // And the mapping
      var mapping = source.WindowsToTzdbIds;
      Assert.AreEqual(kolkata, mapping[indiaStandardTime]);
    },
  }, skip: {
    'ForId_Null': SkipReasons.NullSafety,
  });
}

/// noda_dart: TimeZoneInfo.CreateCustomTimeZone as a fixed-offset IHostTimeZone.
final class _FixedHostTimeZone implements IHostTimeZone {
  @override
  final String Id;
  final Offset _offset;

  _FixedHostTimeZone(this.Id, this._offset);

  @override
  bool get FromEnvironment => false;

  @override
  Offset GetUtcOffset(Instant instant) => _offset;
}

/// Creates a sample builder with two canonical zones (zone1 and zone2), and a link from zone3 to zone1.
/// There's a single Windows mapping territory, but no zone locations.
TzdbStreamDataBuilder CreateSampleBuilder() {
  var builder = TzdbStreamDataBuilder()
    ..stringPool = <String>[]
    ..tzdbIdMap = <String, String>{'zone3': 'zone1'}
    ..tzdbVersion = 'tzdb-version'
    ..windowsMapping = WindowsZones.NewVersionTzdbVersionWindowsVersionMapZones('cldr-version', 'tzdb-version', 'windows-version',
        [
          MapZone('windows-id', MapZone.PrimaryTerritory, ['zone1']),
          MapZone('windows-id', 'UK', ['zone1'])
        ]);
  PopulateZoneFields(builder, ['zone1', 'zone2']);
  return builder;
}

void PopulateZoneFields(TzdbStreamDataBuilder builder, List<String> zoneIds) {
  for (var id in zoneIds) {
    builder.zoneFields[id] = TzdbStreamField.NewIdData(TzdbStreamFieldId.TimeZone, Uint8List(0));
  }
}

void AssertInvalid(TzdbStreamDataBuilder builder) {
  var streamData = TzdbStreamData.NewBuilder(builder);
  var source = TzdbDateTimeZoneSource.NewSource(streamData);
  Assert.Throws<InvalidNodaDataException>(source.Validate);
}

/// Creates a time zone source with everything required to test the maps between
/// Windows and TZDB IDs. Details (not in XML) in the source...
TzdbDateTimeZoneSource CreateComplexMappingSource() {
  // Canonical IDs: zone1, zone2, zone3, zone4, zone5, zone6
  // Aliases, linked to the obvious corresponding IDs: link1, link2, link3a, link3b, link3c
  // Windows mappings:
  // win1: zone1 (primary, UK)
  // win2: link2 (primary, UK)
  // win3: link3a (primary, UK)
  // win4: zone4 (primary, UK), zone5 (FR), link3b (CA)
  var builder = TzdbStreamDataBuilder()
    ..stringPool = <String>[]
    ..tzdbIdMap = <String, String>{
      'link1': 'zone1',
      'link2': 'zone2',
      'link3a': 'zone3',
      'link3b': 'zone3',
      'link3c': 'zone3'
    }
    ..tzdbVersion = 'tzdb-version'
    ..windowsMapping = WindowsZones.NewVersionTzdbVersionWindowsVersionMapZones('cldr-version', 'tzdb-version', 'windows-version',
        [
          MapZone('win1', MapZone.PrimaryTerritory, ['zone1']),
          MapZone('win1', 'UK', ['zone1']),
          MapZone('win2', MapZone.PrimaryTerritory, ['link2']),
          MapZone('win2', 'UK', ['link2']),
          MapZone('win3', MapZone.PrimaryTerritory, ['link3a']),
          MapZone('win3', 'UK', ['link3a']),
          MapZone('win4', MapZone.PrimaryTerritory, ['zone4']),
          MapZone('win4', 'UK', ['zone4']),
          MapZone('win4', 'FR', ['zone5']),
          MapZone('win4', 'CA', ['link3b']),
        ]);
  PopulateZoneFields(builder, ['zone1', 'zone2', 'zone3', 'zone4', 'zone5', 'zone6']);
  var source = TzdbDateTimeZoneSource.NewSource(TzdbStreamData.NewBuilder(builder));
  source.Validate();
  return source;
}
