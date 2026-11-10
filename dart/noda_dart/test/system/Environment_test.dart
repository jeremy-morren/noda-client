// noda_dart: new code (as noda-js's environment.test.ts). The system default zone in child processes with TZ set to a
// Windows ID, an IANA ID, an unknown ID, or unset.
@Tags(['system'])
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

final bool isWindows = Platform.isWindows;

/// Compiled once, so each process starts quickly.
Future<String>? _probe;
Directory? _directory;

Future<String> _CompileProbe() async {
  final directory = _directory = Directory.systemTemp.createTempSync('noda_dart_system_');
  final exe = '${directory.path}${Platform.pathSeparator}probe${isWindows ? '.exe' : ''}';
  final result = await Process.run(
      Platform.resolvedExecutable, ['compile', 'exe', 'test/system/EnvironmentProbe.dart', '-o', exe]);
  if (result.exitCode != 0) {
    throw StateError('Compiling the probe failed: ${result.stdout}\n${result.stderr}');
  }
  return exe;
}

Future<Map<String, Object?>> run(String? tz) async {
  final exe = await (_probe ??= _CompileProbe());
  final environment = Map.of(Platform.environment)..removeWhere((key, _) => key.toUpperCase() == 'TZ');
  if (tz != null) {
    environment['TZ'] = tz;
  }
  final result = await Process.run(exe, const [],
      environment: environment, includeParentEnvironment: false, stdoutEncoding: utf8, stderrEncoding: utf8);
  if (result.exitCode != 0) {
    throw StateError('The probe failed (TZ=$tz): ${result.stderr}');
  }
  return jsonDecode(result.stdout as String) as Map<String, Object?>;
}

Map<String, Object?> zone(Map<String, Object?> probe, String name) => probe[name] as Map<String, Object?>;

/// The tzdb zone is checked by its offsets (its IDs are IANA IDs).
void ExpectAgreement(Map<String, Object?> probe) {
  expect(zone(probe, 'provider')['id'], probe['systemDefaultId']);
  expect(zone(probe, 'forSystemDefault')['id'], probe['systemDefaultId']);
}

Matcher offsets(int january, int july) => allOf(containsPair('january', january), containsPair('july', july));

void main() {
  tearDownAll(() {
    try {
      _directory?.deleteSync(recursive: true);
    } on FileSystemException {
      // Left for the OS to clean up.
    }
  });

  group('the system default zone in a process, by TZ environment variable', () {
    test('TZ not set: the host zone', () async {
      final probe = await run(null);
      expect(probe['versionId'], startsWith(isWindows ? 'TimeZoneInfo: Windows (dart:ffi)' : 'TZif: '));
      expect(probe['systemDefaultId'], isNotNull);
      ExpectAgreement(probe);
      expect(zone(probe, 'tzdb')['error'], isNull);
      // The host's zone, by tzdb and by the system: they agree now (if not always on history).
      expect(zone(probe, 'tzdb')['january'], zone(probe, 'provider')['january']);
      expect(zone(probe, 'tzdb')['july'], zone(probe, 'provider')['july']);
    });

    test('TZ=America/La_Paz', () async {
      final probe = await run('America/La_Paz');
      expect(probe['systemDefaultId'], isWindows ? 'SA Western Standard Time' : 'America/La_Paz');
      ExpectAgreement(probe);
      expect(zone(probe, 'provider'), offsets(-4 * 3600, -4 * 3600));
      expect(zone(probe, 'tzdb'), {'id': 'America/La_Paz', 'january': -4 * 3600, 'july': -4 * 3600});
    });

    test('TZ=Asia/Tokyo', () async {
      final probe = await run('Asia/Tokyo');
      expect(probe['systemDefaultId'], isWindows ? 'Tokyo Standard Time' : 'Asia/Tokyo');
      ExpectAgreement(probe);
      expect(zone(probe, 'forSystemDefault'), offsets(9 * 3600, 9 * 3600));
      expect(zone(probe, 'tzdb'), {'id': 'Asia/Tokyo', 'january': 9 * 3600, 'july': 9 * 3600});
    });

    test("TZ=:Asia/Tokyo (a leading ':' is ignored)", () async {
      final probe = await run(':Asia/Tokyo');
      expect(probe['systemDefaultId'], isWindows ? 'Tokyo Standard Time' : 'Asia/Tokyo');
      expect(zone(probe, 'tzdb')['id'], 'Asia/Tokyo');
    });

    test(
        'TZ=SA Western Standard Time: a Windows ID (on Windows; the tzdb provider maps it everywhere; elsewhere the '
        "system provider doesn't know it, so it's UTC)", () async {
      final probe = await run('SA Western Standard Time');
      expect(zone(probe, 'tzdb'), {'id': 'America/La_Paz', 'january': -4 * 3600, 'july': -4 * 3600});
      if (isWindows) {
        expect(probe['systemDefaultId'], 'SA Western Standard Time');
        ExpectAgreement(probe);
        expect(zone(probe, 'provider'), offsets(-4 * 3600, -4 * 3600));
      } else {
        // Not a zone elsewhere (IANA IDs only): UTC.
        expect(probe['systemDefaultId'], 'Etc/UTC');
        ExpectAgreement(probe);
      }
    });

    test('TZ in another case: IDs match ignoring case (the tzdb provider everywhere; the system provider on Windows)',
        () async {
      final windowsId = await run('sa western standard time');
      expect(zone(windowsId, 'tzdb')['id'], 'America/La_Paz');
      final ianaId = await run('asia/tokyo');
      expect(zone(ianaId, 'tzdb')['id'], 'Asia/Tokyo');
      if (isWindows) {
        expect(windowsId['systemDefaultId'], 'SA Western Standard Time');
        ExpectAgreement(windowsId);
        expect(ianaId['systemDefaultId'], 'Tokyo Standard Time');
        ExpectAgreement(ianaId);
      }
    });

    test('TZ=an unknown ID: UTC, as for Node, Python, glibc and .NET on Unix', () async {
      for (final tz in ['Mars/Olympus_Mons', 'AEST-10AEDT,M10.1.0,M4.1.0/3']) {
        final probe = await run(tz);
        expect(probe['systemDefaultId'], isWindows ? 'UTC' : 'Etc/UTC', reason: 'TZ=$tz');
        ExpectAgreement(probe);
        expect(zone(probe, 'provider'), offsets(0, 0));
        expect(zone(probe, 'forSystemDefault'), offsets(0, 0));
        expect(zone(probe, 'tzdb'), {'id': 'Etc/UTC', 'january': 0, 'july': 0});
      }
    });

    test('TZ empty: the host zone, as when it is not set', () async {
      final empty = await run('');
      final unset = await run(null);
      expect(empty['systemDefaultId'], unset['systemDefaultId']);
      expect(zone(empty, 'tzdb'), zone(unset, 'tzdb'));
    });
  }, timeout: const Timeout(Duration(minutes: 3)));
}
