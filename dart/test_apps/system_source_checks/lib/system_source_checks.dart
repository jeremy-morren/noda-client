// Use of this source code is governed by the Apache License 2.0, as found in the LICENSE.txt file.

/// Platform-agnostic system time zone checks, shared by noda_dart's tests and the Flutter test app.
///
/// A package (Flutter's web compilers only see package files) with no test runner dependency.
library;

import 'package:matcher/expect.dart';
import 'package:noda_dart/noda_dart.dart';
import 'package:noda_dart/system.dart';
import 'package:noda_dart/tzdb_bundled.dart';

import 'src/platform_clock.dart';

/// Where the system time zones come from.
enum SystemSourceBackend {
  /// Windows' zones (Windows IDs).
  windows('TimeZoneInfo: Windows'),

  /// TZif files (IANA IDs).
  tzif('TZif: '),

  /// The web's Intl (IANA IDs).
  intl('Intl: ');

  /// The start of [SystemDateTimeZoneSource.VersionId].
  final String versionIdPrefix;

  const SystemSourceBackend(this.versionIdPrefix);
}

/// What the platform under test is expected to provide.
class SystemSourcePlatform {
  /// For failure messages.
  final String name;

  final SystemSourceBackend backend;

  /// The known system zone ID (Windows IDs on Windows), or null.
  final String? expectedSystemDefaultId;

  /// Why the platform clock can't be compared (e.g. Windows with TZ set, which Dart's DateTime ignores).
  final String? platformClockSkip;

  /// Why tzdb's system default can't be compared (e.g. Windows with automatic DST off).
  final String? tzdbComparisonSkip;

  const SystemSourcePlatform({
    required this.name,
    required this.backend,
    this.expectedSystemDefaultId,
    this.platformClockSkip,
    this.tzdbComparisonSkip,
  });

  bool get usesWindowsIds => backend == SystemSourceBackend.windows;

  /// IDs that every database of this kind has.
  List<String> get expectedIds => usesWindowsIds
      ? const [
          'GMT Standard Time',
          'W. Europe Standard Time',
          'Eastern Standard Time',
          'Tokyo Standard Time',
          'AUS Eastern Standard Time',
          'UTC',
        ]
      : const [
          'Europe/London',
          'Europe/Berlin',
          'America/New_York',
          'Asia/Tokyo',
          'Australia/Sydney',
        ];

  /// UK time: the same rules since 1996 in tzdb and Windows.
  String get londonId => usesWindowsIds ? 'GMT Standard Time' : 'Europe/London';

  String? get systemDefaultIdToExpect => expectedSystemDefaultId ?? (usesWindowsIds ? null : platformTimeZoneId());

  @override
  String toString() => name;
}

class SystemSourceCheck {
  final String name;
  final void Function() body;

  final String? skip;

  const SystemSourceCheck(this.name, this.body, {this.skip});
}

/// An ID no platform has.
const String unknownZoneId = 'Not/AZone';

/// The checks for [platform].
List<SystemSourceCheck> systemSourceChecks(SystemSourcePlatform platform) {
  // Lazy, so a throwing backend fails the checks, not the test file.
  late final source = SystemDateTimeZoneSource();
  final year = DateTime.now().toUtc().year;

  return [
    SystemSourceCheck('VersionId names the system data (${platform.backend.versionIdPrefix}...)', () {
      expect(source.VersionId, startsWith(platform.backend.versionIdPrefix),
          reason: '$platform should read its system time zones from ${platform.backend.name}');
      expect(SystemDateTimeZoneProvider.VersionId, source.VersionId);
      expect(SystemDateTimeZoneProvider.VersionId, isNot(tzdb.VersionId));
    }),
    SystemSourceCheck('GetIds is non-empty and has the expected IDs', () {
      final ids = source.GetIds().toList();
      expect(ids, isNotEmpty);
      expect(ids, containsAll(platform.expectedIds));
      expect(ids, isNot(contains(unknownZoneId)));
      expect(ids.toSet(), hasLength(ids.length), reason: 'IDs are unique');
      expect(SystemDateTimeZoneProvider.Ids, containsAll(platform.expectedIds));
    }),
    SystemSourceCheck('ForId loads the expected zones', () {
      for (final id in platform.expectedIds) {
        final zone = source.ForId(id);
        expect(zone, isA<SystemDateTimeZone>());
        expect(zone.Id, id);
        expect(SystemDateTimeZoneProvider[id].Id, id);
      }
    }),
    SystemSourceCheck("ForId accepts IANA IDs, with the Windows zone's rules (as .NET does)", () {
      final ids = source.GetIds().toSet();
      // Asia/Calcutta is a link (to Asia/Kolkata).
      const windowsIdsByIanaId = {
        'Europe/London': 'GMT Standard Time',
        'Australia/Sydney': 'AUS Eastern Standard Time',
        'Asia/Calcutta': 'India Standard Time',
      };
      for (final MapEntry(key: ianaId, value: windowsId) in windowsIdsByIanaId.entries) {
        expect(ids, isNot(contains(ianaId)), reason: 'GetIds lists only Windows IDs');
        final windowsZone = source.ForId(windowsId);
        final zone = source.ForId(ianaId);
        expect(zone.Id, ianaId);
        expect(zone.OriginalZone!.HasIanaId, isTrue);
        for (var month = 1; month <= 12; month++) {
          final instant = Instant.FromUtc(year, month, 15, 12, 0);
          expect(zone.GetUtcOffset(instant), windowsZone.GetUtcOffset(instant),
              reason: '$ianaId and $windowsId on $year-$month-15');
        }
        // The provider (NodaTime's DateTimeZoneCache) only knows the source's advertised IDs.
        expect(SystemDateTimeZoneProvider.GetZoneOrNull(ianaId), isNull);
      }
    }, skip: platform.usesWindowsIds ? null : 'Windows only: zone IDs are already IANA IDs here'),
    SystemSourceCheck('ForId throws ArgumentError for an unknown ID; the provider DateTimeZoneNotFoundException', () {
      expect(() => source.ForId(unknownZoneId), throwsA(isA<ArgumentError>()));
      expect(() => SystemDateTimeZoneProvider[unknownZoneId], throwsA(isA<DateTimeZoneNotFoundException>()));
      expect(SystemDateTimeZoneProvider.GetZoneOrNull(unknownZoneId), isNull);
    }),
    SystemSourceCheck('GetSystemDefaultId is one of GetIds, and every way of getting the system zone agrees', () {
      final id = source.GetSystemDefaultId();
      expect(id, isNotNull, reason: 'the system time zone should be known');
      expect(source.GetIds(), contains(id));
      expect(SystemDateTimeZoneProvider.GetSystemDefault().Id, id);
      expect(SystemDateTimeZone.ForSystemDefault().Id, id);
    }),
    SystemSourceCheck('GetSystemDefaultId is the configured system time zone', () {
      expect(source.GetSystemDefaultId(), platform.systemDefaultIdToExpect);
    },
        skip: platform.systemDefaultIdToExpect == null
            ? 'The system time zone ID is unknown on ${platform.name} '
                '(set NODA_EXPECT_SYSTEM_TIME_ZONE to check it)'
            : null),
    SystemSourceCheck('the system default zone matches $platformClockDescription now and across the year', () {
      final zone = SystemDateTimeZone.ForSystemDefault();
      final instants = <int>[
        DateTime.now().millisecondsSinceEpoch,
        for (var month = 1; month <= 12; month++) ...[
          DateTime.utc(year, month, 1, 12).millisecondsSinceEpoch,
          DateTime.utc(year, month, 15, 12).millisecondsSinceEpoch,
        ],
      ];
      final mismatches = <String>[];
      for (final ms in instants) {
        final expected = platformUtcOffsetSeconds(ms);
        final actual = zone.GetUtcOffset(Instant.FromUnixTimeMilliseconds(ms)).Seconds;
        if (actual != expected) {
          mismatches.add('${_utc(ms)}: ${zone.Id} has $actual s, $platformClockDescription has $expected s');
        }
      }
      expect(mismatches, isEmpty);
    }, skip: platform.platformClockSkip),
    SystemSourceCheck("the tzdb provider's system default has the system default zone's offset now", () {
      // Only now: the OS's history can differ from tzdb's.
      final now = SystemClock.Instance.GetCurrentInstant();
      final system = SystemDateTimeZone.ForSystemDefault();
      final tzdbZone = tzdb.GetSystemDefault();
      expect(tzdbZone.GetUtcOffset(now), system.GetUtcOffset(now),
          reason: '${tzdbZone.Id} (tzdb) and ${system.Id} (system) at $now');
    }, skip: platform.tzdbComparisonSkip),
    SystemSourceCheck('a DST zone has different offsets in January and July, and its zone intervals adjoin', () {
      final zone = source.ForId(platform.londonId);
      Instant at(DateTime utc) => Instant.FromUnixTimeMilliseconds(utc.millisecondsSinceEpoch);

      final january = zone.GetZoneInterval(at(DateTime.utc(year, 1, 15)));
      final july = zone.GetZoneInterval(at(DateTime.utc(year, 7, 15)));
      expect(january.WallOffset.Seconds, 0, reason: 'GMT in January');
      expect(july.WallOffset.Seconds, 3600, reason: 'BST in July');
      expect(january.Savings.Seconds, 0, reason: 'standard time in January');
      expect(july.Savings.Seconds, 3600, reason: 'summer time in July');

      // BST runs from 01:00 UTC on the last Sunday of March to 01:00 UTC on the last Sunday of October.
      expect(july.HasStart && july.HasEnd, isTrue);
      expect(_utc(july.Start.ToUnixTimeMilliseconds()), _utc(_lastSunday(year, 3, 1).millisecondsSinceEpoch));
      expect(_utc(july.End.ToUnixTimeMilliseconds()), _utc(_lastSunday(year, 10, 1).millisecondsSinceEpoch));

      final yearStart = at(DateTime.utc(year));
      final yearEnd = at(DateTime.utc(year + 1));
      final intervals = zone.GetZoneIntervals(yearStart, yearEnd).toList();
      expect(intervals.length, greaterThanOrEqualTo(3), reason: 'GMT, BST and GMT again');
      expect(!intervals.first.HasStart || intervals.first.Start <= yearStart, isTrue,
          reason: 'the intervals cover the start of the year');
      expect(!intervals.last.HasEnd || intervals.last.End >= yearEnd, isTrue,
          reason: 'the intervals cover the end of the year');
      for (var i = 0; i + 1 < intervals.length; i++) {
        final a = intervals[i], b = intervals[i + 1];
        expect(a.HasEnd && b.HasStart, isTrue);
        expect(b.Start, a.End, reason: 'interval ${i + 1} starts where interval $i ends');
        expect(zone.GetZoneInterval(b.Start), b);
      }
      expect(intervals.map((i) => i.WallOffset.Seconds).toSet(), {0, 3600});
    }),
  ];
}

DateTime _lastSunday(int year, int month, int hourUtc) {
  // Day 0 of the next month is the last day of this one.
  var day = DateTime.utc(year, month + 1, 0, hourUtc);
  while (day.weekday != DateTime.sunday) {
    day = DateTime.utc(day.year, day.month, day.day - 1, hourUtc);
  }
  return day;
}

String _utc(int epochMilliseconds) =>
    DateTime.fromMillisecondsSinceEpoch(epochMilliseconds, isUtc: true).toIso8601String();
