// noda_dart: new code. Checks tzdb.GetSystemDefault() is the expected zone and has the system's offset now.
//   dart run tool/check_local_zone.dart "<expected tzdb ID>"
// On Windows the system offset is read through dart:ffi: Dart's DateTime there ignores TZ and sub-hour DST.
import 'dart:io';

import 'package:noda_dart/noda_dart.dart';
import 'package:noda_dart/system.dart';
import 'package:noda_dart/tzdb_bundled.dart';

void main(List<String> args) {
  final local = tzdb.GetSystemDefault();
  final now = SystemClock.Instance.GetCurrentInstant();
  final offset = local.GetUtcOffset(now);
  final dartNow = DateTime.now();

  print('System:        ${dartNow.timeZoneName} (Dart DateTime UTC offset ${dartNow.timeZoneOffset})');
  final system = _SystemDefault();
  print('System source: ${system == null ? '<none>' : '${system.Id} (UTC offset ${system.GetUtcOffset(now)})'} '
      '[${_SystemVersionId()}]');
  print('tzdb:          ${local.Id} (UTC offset $offset) [${tzdb.VersionId}]');
  print('TZ:            ${Platform.environment['TZ'] ?? '<unset>'}');
  final localtime = Link('/etc/localtime');
  if (!Platform.isWindows && localtime.existsSync()) {
    print('/etc/localtime -> ${localtime.targetSync()}');
  }

  var failed = false;
  final expected = args.isEmpty ? '' : args.first.trim();
  if (expected.isNotEmpty && local.Id != expected) {
    stderr.writeln('FAIL: expected $expected, detected ${local.Id}');
    failed = true;
  }
  final Offset systemOffset;
  final String systemOffsetSource;
  final fromEnvironment = int.tryParse(Platform.environment['SYSTEM_OFFSET_SECONDS'] ?? '');
  if (fromEnvironment != null) {
    systemOffset = Offset.FromSeconds(fromEnvironment);
    systemOffsetSource = 'SYSTEM_OFFSET_SECONDS';
  } else if (Platform.isWindows && system != null) {
    systemOffset = system.GetUtcOffset(now);
    systemOffsetSource = "Windows' TimeZoneInfo.Local";
  } else {
    systemOffset = Offset.FromSeconds(dartNow.timeZoneOffset.inSeconds);
    systemOffsetSource = "Dart's DateTime";
  }
  print('System offset: $systemOffset (from $systemOffsetSource)');
  final knownDifference = Platform.environment['KNOWN_OFFSET_DIFFERENCE'] ?? '';
  // OFFSET_MAY_DIFFER: a known difference (e.g. DST adjustment off), reported, not failed.
  final mayDiffer = Platform.environment['OFFSET_MAY_DIFFER'] ?? '';
  if (mayDiffer.isNotEmpty) {
    print(offset == systemOffset
        ? 'Offsets agree ($offset); they may differ: $mayDiffer'
        : 'Offsets differ ($offset, system $systemOffset), as they may: $mayDiffer');
  } else if (offset != systemOffset) {
    if (knownDifference.isNotEmpty) {
      print('KNOWN DIFFERENCE: detected zone offset $offset != system offset $systemOffset: $knownDifference');
    } else {
      stderr.writeln('FAIL: detected zone offset $offset != system offset $systemOffset');
      failed = true;
    }
  } else if (knownDifference.isNotEmpty) {
    stderr.writeln('FAIL: expected a difference ($knownDifference), but the offsets agree ($offset); '
        'remove KNOWN_OFFSET_DIFFERENCE');
    failed = true;
  }
  exit(failed ? 1 : 0);
}

DateTimeZone? _SystemDefault() {
  try {
    return SystemDateTimeZone.ForSystemDefault();
  } catch (error) {
    print('SystemDateTimeZone.ForSystemDefault() failed: $error');
    return null;
  }
}

String _SystemVersionId() {
  try {
    return SystemDateTimeZoneProvider.VersionId;
  } catch (error) {
    return 'unavailable: $error';
  }
}
