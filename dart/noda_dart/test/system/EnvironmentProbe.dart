// noda_dart: new code. Run by Environment_test.dart with TZ set (or not); prints the system defaults as JSON.

import 'dart:convert';
import 'dart:io';

import 'package:noda_dart/noda_dart.dart';
import 'package:noda_dart/system.dart';
import 'package:noda_dart/tzdb_bundled.dart';

final Instant _january = Instant.FromUtc(2026, 1, 15, 12, 0);
final Instant _july = Instant.FromUtc(2026, 7, 15, 12, 0);

Map<String, Object?> _Describe(DateTimeZone Function() get) {
  try {
    final zone = get();
    return {'id': zone.Id, 'january': zone.GetUtcOffset(_january).Seconds, 'july': zone.GetUtcOffset(_july).Seconds};
  } catch (e) {
    return {'error': e.runtimeType.toString()};
  }
}

void main() {
  final source = SystemDateTimeZoneSource();
  final result = {
    'versionId': source.VersionId,
    'systemDefaultId': source.GetSystemDefaultId(),
    'ids': source.GetIds().length,
    'provider': _Describe(() => SystemDateTimeZoneProvider.GetSystemDefault()),
    'forSystemDefault': _Describe(() => SystemDateTimeZone.ForSystemDefault()),
    'tzdb': _Describe(() => tzdb.GetSystemDefault()),
  };
  stdout.write(jsonEncode(result));
}
