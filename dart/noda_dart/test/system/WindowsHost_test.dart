// noda_dart: new code. The system source on this Windows machine, checked against what Windows reports directly.
@Tags(['system'])
@TestOn('vm')
library;

import 'dart:io';

import 'package:noda_dart/noda_dart.dart';
import 'package:noda_dart/src/System/Windows/FfiWindowsTimeZoneApi.dart';
import 'package:noda_dart/src/TimeZones/SystemDateTimeZone.dart';
import 'package:noda_dart/src/TimeZones/SystemDateTimeZoneSource.dart';
import 'package:noda_dart/system.dart' show SystemDateTimeZoneProvider;
import 'package:noda_dart/tzdb_bundled.dart';
import 'package:test/test.dart';

const String _Hive = 'SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Time Zones';

void main() {
  if (!Platform.isWindows) {
    test('the system source on Windows', () {}, skip: 'Windows only');
    return;
  }
  final tzSet = (Platform.environment['TZ'] ?? '') != '';
  final localized = Platform.environment['NODA_EXPECT_LOCALIZED_WINDOWS'] == '1';
  final noTZ = tzSet ? 'TZ is set: the system zone is the one it names' : null;
  final api = FfiWindowsTimeZoneApi.TryCreate()!;
  final info = api.GetDynamicTimeZoneInformation()!;

  test('reads Windows\' own zones through dart:ffi', () {
    final source = SystemDateTimeZoneSource();
    expect(source.Backend, 'ffi');
    expect(source.VersionId, 'TimeZoneInfo: Windows (dart:ffi)');
    expect(SystemDateTimeZoneProvider.VersionId, source.VersionId);
    // Every registry key is a zone (or invalid data, which .NET leaves out too).
    final keys = api.GetRegistrySubKeyNames(_Hive)!;
    expect(source.GetIds().toSet().difference(keys.toSet()), isEmpty);
  });

  test("the system default is GetDynamicTimeZoneInformation's key name, and the tzdb provider maps it", () {
    expect(info.TimeZoneKeyName, isNotEmpty);
    final source = SystemDateTimeZoneSource();
    expect(source.GetSystemDefaultId(), info.TimeZoneKeyName);
    expect(SystemDateTimeZone.ForSystemDefault().Id, info.TimeZoneKeyName);
    // NodaTime's TzdbDateTimeZoneSource.MapTimeZoneInfoId: the primary mapping, as long as there is one.
    final mapped = tzdbSource.WindowsMapping.PrimaryMapping[info.TimeZoneKeyName];
    if (mapped != null) {
      expect(tzdb.GetSystemDefault().Id, mapped);
    }
  }, skip: noTZ);

  test('"Adjust for daylight saving time automatically" off: the local zone has no DST, other zones keep it', () {
    final local = SystemDateTimeZone.ForSystemDefault();
    expect(local.OriginalZone!.SupportsDaylightSavingTime, isFalse);
    expect(local.MinOffset, local.MaxOffset);
    expect(local.MinOffset, Offset.FromSeconds(-info.Bias * 60));
  }, skip: noTZ ?? (info.DynamicDaylightTimeDisabled ? null : 'DST adjustment is on'));

  test("the local zone's names: the registry's, in the user's UI language", () {
    final local = SystemDateTimeZone.ForSystemDefault();
    final std = api.GetRegistryValue('$_Hive\\${info.TimeZoneKeyName}', 'Std');
    if (localized) {
      // Only the current zone's names are localized; the registry (which .NET reads) stays English.
      expect(info.StandardName, isNot(std), reason: 'the localized names should be in effect');
      expect(info.StandardName.codeUnits.any((c) => c > 127), isTrue, reason: 'a non-English name');
      expect(local.Id, info.TimeZoneKeyName);
      expect(local.OriginalZone!.StandardName, isNot(info.StandardName));
    } else {
      // On Windows in an English UI language the MUI names are the registry's, which Windows reports too.
      expect(info.StandardName, std);
      expect(local.OriginalZone!.StandardName, info.StandardName);
      final names = local.GetZoneIntervals(Instant.FromUtc(2025, 1, 1, 0, 0), Instant.FromUtc(2026, 1, 1, 0, 0))
          .map((i) => i.Name);
      expect(names, contains(info.StandardName));
    }
  },
      skip: noTZ ??
          (localized || ['en', 'en-US', 'en-GB'].contains(api.GetUserPreferredUILanguages().first)
              ? null
              : 'The UI language is ${api.GetUserPreferredUILanguages().first}'));

  test('Pacific Standard Time: the US rules since 2007', () {
    final pacific = SystemDateTimeZoneProvider['Pacific Standard Time'];
    final winter = pacific.GetZoneInterval(Instant.FromUtc(2025, 1, 15, 0, 0));
    final summer = pacific.GetZoneInterval(Instant.FromUtc(2025, 7, 15, 0, 0));
    expect(winter.WallOffset, Offset.FromHours(-8));
    expect(summer.WallOffset, Offset.FromHours(-7));
    expect(summer.Savings, Offset.FromHours(1));
    expect(winter.Name, isNot(summer.Name));
    expect(winter.Start, Instant.FromUtc(2024, 11, 3, 9, 0));
    expect(winter.End, Instant.FromUtc(2025, 3, 9, 10, 0));
    // IANA IDs are accepted by the source (mapped as .NET maps them), but not listed, so not by the provider.
    expect(SystemDateTimeZoneSource().ForId('America/Los_Angeles').Id, 'America/Los_Angeles');
    expect(SystemDateTimeZoneProvider.Ids, isNot(contains('America/Los_Angeles')));
    expect(() => SystemDateTimeZoneProvider['Not/AZone'], throwsA(isA<DateTimeZoneNotFoundException>()));
  });
}
