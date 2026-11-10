// noda_dart: new code. The system source on Windows compared with NodaTime on .NET on this machine, from
// npm run test:export-system-zones in ts/'s export (NODA_SYSTEM_ZONES_JSON, or ../../testdata/system-zones.json).
// Skipped without it.
@Tags(['system'])
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:noda_dart/noda_dart.dart';
import 'package:noda_dart/src/System/TimeZoneInfo.TransitionTime.dart';
import 'package:noda_dart/src/System/WindowsIdMapping.dart';
import 'package:noda_dart/src/TimeZones/SystemDateTimeZone.dart';
import 'package:noda_dart/src/TimeZones/SystemDateTimeZoneSource.dart';
import 'package:test/test.dart';

Map<String, Object?>? _LoadExport() {
  if (!Platform.isWindows) {
    return null;
  }
  final configured = Platform.environment['NODA_SYSTEM_ZONES_JSON'];
  final file =
      File(configured != null && configured.isNotEmpty ? configured : '../../testdata/system-zones.json');
  return file.existsSync() ? jsonDecode(file.readAsStringSync()) as Map<String, Object?> : null;
}

List<Object?> DescribeInterval(ZoneInterval interval) {
  return [
    interval.HasStart ? interval.Start.ToUnixTimeMilliseconds() : null,
    interval.HasEnd ? interval.End.ToUnixTimeMilliseconds() : null,
    interval.WallOffset.Seconds,
    interval.Savings.Seconds,
    interval.Name,
  ];
}

List<int> DescribeTransition(TimeZoneInfoTransitionTime transition) {
  return [
    transition.IsFixedDateRule ? 1 : 0,
    transition.Month,
    transition.Week,
    transition.Day,
    transition.DayOfWeek,
    transition.TimeOfDay.TickOfDay ~/ 10000,
  ];
}

Map<String, Object?> DescribeZone(SystemDateTimeZone zone, int startYear, int endYear) {
  final info = zone.OriginalZone!;
  int minutes(int ticks) => ticks ~/ 600000000;
  return {
    'id': zone.Id,
    'displayName': zone.DisplayName,
    'standardName': info.StandardName,
    'daylightName': info.DaylightName,
    'baseUtcOffsetMinutes': minutes(info.BaseUtcOffset),
    'supportsDaylightSavingTime': info.SupportsDaylightSavingTime,
    'minOffsetSeconds': zone.MinOffset.Seconds,
    'maxOffsetSeconds': zone.MaxOffset.Seconds,
    'rules': [
      for (final rule in info.GetAdjustmentRules())
        {
          'dateStart': rule.DateStart.toString(),
          'dateEnd': rule.DateEnd.toString(),
          'daylightDeltaMinutes': minutes(rule.DaylightDelta),
          'baseUtcOffsetDeltaMinutes': minutes(rule.BaseUtcOffsetDelta),
          'start': DescribeTransition(rule.DaylightTransitionStart),
          'end': DescribeTransition(rule.DaylightTransitionEnd),
        }
    ],
    'intervals': zone.GetZoneIntervals(Instant.FromUtc(startYear, 1, 1, 0, 0), Instant.FromUtc(endYear, 1, 1, 0, 0))
        .map(DescribeInterval)
        .toList(),
  };
}

/// IANA IDs our bundled CLDR maps differently from .NET's older ICU (72.1).
const Set<String> CldrChanges = {
  'America/Chihuahua', 'America/Edmonton', 'America/Inuvik', 'America/Ojinaga', 'America/Rainy_River', //
  'America/Vancouver', 'America/Winnipeg', 'America/Yellowknife', 'Asia/Almaty', 'Asia/Qostanay', 'Canada/Central',
  'Canada/Mountain', 'Canada/Pacific', 'CST6CDT', 'EST5EDT', 'MST7MDT', 'PST8PDT',
};

/// IANA IDs (now links) our CLDR no longer lists but an older icu.dll still treats as canonical, so no Windows ID.
const Set<String> CanonicalInWindowsIcu = {
  'America/Montreal', 'America/Nipigon', 'America/Pangnirtung', 'America/Santa_Isabel', 'America/Thunder_Bay', //
  'Asia/Choibalsan', 'Australia/Currie', 'Europe/Uzhgorod', 'Europe/Zaporozhye', 'Pacific/Johnston',
};

void main() {
  final exported = _LoadExport();
  if (exported == null) {
    test('noda_dart compared with .NET', () {},
        skip: 'needs Windows and the export of NodaTime on .NET (npm run test:export-system-zones in ts/, or '
            'NODA_SYSTEM_ZONES_JSON)');
    return;
  }
  // The comparison is with the host's own zone and Windows' data through dart:ffi (with TZ set, the default differs).
  final source = SystemDateTimeZoneSource();
  final startYear = exported['startYear'] as int;
  final endYear = exported['endYear'] as int;
  final tz = Platform.environment['TZ'] ?? '';

  group("noda_dart's system source matches NodaTime's BclDateTimeZoneSource on .NET (${exported['generator']})", () {
    test('the same IDs, in the same order, and the same system default', () {
      expect(source.Backend, 'ffi');
      expect(source.GetIds().toList(), exported['ids']);
      if (tz.isEmpty) {
        expect(source.GetSystemDefaultId(), exported['systemDefaultId']);
      }
    });

    test('the same local zone (BclDateTimeZone.ForSystemDefault)', () {
      expect(DescribeZone(SystemDateTimeZone.ForSystemDefault(), startYear, endYear), exported['local']);
    }, skip: tz.isEmpty ? null : 'TZ is set (.NET on Windows ignores it)');

    for (final expected in (exported['zones'] as List).cast<Map<String, Object?>>()) {
      final id = expected['id'] as String;
      test('$id: the same names, rules and zone intervals', () {
        expect(DescribeZone(source.ForId(id), startYear, endYear), expected);
      });
    }

    test('IANA IDs map to the same Windows IDs, except where CLDR has changed since the ICU .NET uses', () {
      final differences = <String>[];
      final ianaToWindows = (exported['ianaToWindows'] as Map).cast<String, String>();
      for (final MapEntry(key: ianaId, value: windowsId) in ianaToWindows.entries) {
        final ours = TryConvertIanaIdToWindowsId(ianaId);
        if (ours != windowsId &&
            !CldrChanges.contains(ianaId) &&
            !(ours == null && CanonicalInWindowsIcu.contains(ianaId))) {
          differences.add('$ianaId: $ours (noda_dart) vs $windowsId (.NET)');
        }
      }
      expect(differences, isEmpty);
      // ForId accepts them, keeping the IANA ID, with the Windows zone's rules.
      final sydney = source.ForId('Australia/Sydney');
      expect(sydney.Id, 'Australia/Sydney');
      expect(sydney.GetZoneInterval(Instant.FromUtc(2024, 1, 1, 0, 0)).Name,
          source.ForId('AUS Eastern Standard Time').GetZoneInterval(Instant.FromUtc(2024, 1, 1, 0, 0)).Name);
    });
  });
}
