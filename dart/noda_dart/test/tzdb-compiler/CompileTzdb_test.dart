// noda_dart: new code (as noda-js's CompileTzdb.test.ts). Compiling the bundled NZD's tzdata release gives exactly the
// bundled NZD, from every kind of input.

import 'dart:convert';
import 'dart:typed_data';

import 'package:noda_dart/src/Instant.dart';
import 'package:noda_dart/src/TimeZones/DateTimeZoneCache.dart';
import 'package:noda_dart/src/TimeZones/TzdbBundledData.generated.dart' show nzdBytes;
import 'package:noda_dart/src/TimeZones/TzdbDateTimeZoneSource.dart';
import 'package:noda_dart/src/TzdbCompiler/Tar.dart';
import 'package:noda_dart/tzdb_bundled.dart' show tzdbSource;
import 'package:noda_dart/tzdb_compiler.dart';
import 'package:test/test.dart';

import '../helpers/Host.dart';
import 'TarBuilder.dart';

// A full compile takes a second or two on the VM (much more with dart2js).
const Timeout timeout = Timeout(Duration(minutes: 5));

final Uint8List bundledNzd = nzdBytes;
final bundledSource = tzdbSource;

Future<Uint8List> TarGz() => ReadFixtureOrNode('tzdb/tzdata2026f.tar.gz');

/// Decompressed by the host, independently of the code under test.
Future<Uint8List> TarFile() async => Decompress(await TarGz(), 'gzip');

/// Reports the first difference (rather than diffing ~100 KB).
void expectSameBytes(Uint8List actual, Uint8List expected) {
  var index = 0;
  while (index < actual.length && index < expected.length && actual[index] == expected[index]) {
    index++;
  }
  expect({'length': actual.length, 'firstDifference': index},
      {'length': expected.length, 'firstDifference': expected.length});
}

Matcher throwsWithMessage<T>([String message = '']) =>
    throwsA(isA<T>().having((e) => '${(e as dynamic).message}', 'message', contains(message)));

void main() {
  group('CompileTzdbToNzd', () {
    test('compiles tzdata .tar.gz to the bundled NZD, byte for byte', () => RunOrSkip(() async {
          expectSameBytes(await CompileTzdbToNzd(await TarGz()), bundledNzd);
        }), timeout: timeout);

    test('compiles an uncompressed tzdata .tar to the bundled NZD', () => RunOrSkip(() async {
          expectSameBytes(await CompileTzdbToNzd(await TarFile()), bundledNzd);
        }), timeout: timeout);

    test('reads a stream, and a List<int> (the inputs are covered in Input_test.dart)', () => RunOrSkip(() async {
          final tarGz = await TarGz();
          final chunks = [for (var i = 0; i < tarGz.length; i += 65536) tarGz.sublist(i, i + 65536 > tarGz.length ? tarGz.length : i + 65536)];
          expectSameBytes(await CompileTzdbToNzd(Stream<List<int>>.fromIterable(chunks)), bundledNzd);
          expectSameBytes(await CompileTzdbToNzd(List<int>.of(tarGz)), bundledNzd);
        }), timeout: timeout);

    test('reads a local archive file, and a directory of tzdata files', () => RunOrSkip(() async {
          final tarGz = await TarGz();
          final parent = await CreateTempDirectory();
          try {
            final path = Combine(parent, 'tzdata2026f.tar.gz');
            await WriteAllBytes(path, tarGz);
            final log = <String>[];
            expectSameBytes(await CompileTzdbToNzd(path, CompileTzdbOptions(Log: log.add)), bundledNzd);
            expect(log, contains('Compiling from archive file $path'));

            // The files of the archive, without the version file: the version comes from the directory's name.
            final directory = Combine(parent, 'tzdata-2026f');
            await CreateDirectory(directory);
            for (final MapEntry(key: name, value: data) in ReadTar(await Decompress(tarGz, 'gzip')).entries) {
              if (name != 'version') {
                await WriteAllBytes(Combine(directory, name), data);
              }
            }
            log.clear();
            expectSameBytes(await CompileTzdbToNzd(directory, CompileTzdbOptions(Log: log.add)), bundledNzd);
            expect(log, contains('Compiling from directory $directory'));
            expect(log, contains('Inferred version 2026f from file/directory name tzdata-2026f'));
          } finally {
            await DeleteDirectory(parent);
          }
        }), timeout: timeout);

    test("downloads a directory's files (a URL ending with /), getting the version from its name without a version file",
        () => RunOrSkip(() async {
              const base = '/gh/eggert/tz@2026f/';
              final files = {
                for (final MapEntry(key: name, value: data) in ReadTar(await TarFile()).entries)
                  name.substring(name.lastIndexOf('/') + 1): data,
              }..remove('version');
              final server = await StartHttpServer((path) => path.startsWith(base) ? files[path.substring(base.length)] : null);
              try {
                final log = <String>[];
                expectSameBytes(await CompileTzdbToNzd('${server.Url}$base', CompileTzdbOptions(Log: log.add)), bundledNzd);
                expect(log, contains('Inferred version 2026f from file/directory name tz@2026f'));
              } finally {
                await server.Close();
              }
            }), timeout: timeout);

    test('downloads a URL', () => RunOrSkip(() async {
          final tarGz = await TarGz();
          final server = await StartHttpServer((path) => path == '/time-zones/tzdata-latest.tar.gz' ? tarGz : null);
          try {
            final log = <String>[];
            final url = '${server.Url}/time-zones/tzdata-latest.tar.gz';
            final nzd = await CompileTzdbToNzd(Uri.parse(url), CompileTzdbOptions(Log: log.add));
            expect(server.Requests, ['/time-zones/tzdata-latest.tar.gz']);
            expectSameBytes(nzd, bundledNzd);
            // The version comes from the archive's version file (the Makefile says "unknown", and so does this URL).
            expect(log, contains('Downloading $url'));
            expect(log, contains('Inferred version 2026f from file/directory name tzdata2026f.tar'));
            expect(log, contains('Reading generated data and validating...'));
          } finally {
            await server.Close();
          }
        }), timeout: timeout);
  });

  group('CompileTzdbToNzdSync', () {
    test('compiles tzdata .tar.gz to the bundled NZD, byte for byte', () => RunOrSkip(() async {
          expectSameBytes(CompileTzdbToNzdSync(await TarGz()), bundledNzd);
        }), timeout: timeout);

    test('compiles an uncompressed tzdata .tar to the bundled NZD', () => RunOrSkip(() async {
          expectSameBytes(CompileTzdbToNzdSync(await TarFile()), bundledNzd);
        }), timeout: timeout);

    test('compiles a data: URI', () => RunOrSkip(() async {
          final tarGz = await TarGz();
          expectSameBytes(CompileTzdbToNzdSync(Uri.dataFromBytes(tarGz)), bundledNzd);
        }), timeout: timeout);
  });

  group('CompileTzdbSync', () {
    test("gives a validated source with the bundled tzdb's version", () => RunOrSkip(() async {
          final source = CompileTzdbSync(await TarGz());
          expect(source, isA<TzdbDateTimeZoneSource>());
          expect(source.VersionId, bundledSource.VersionId);
          final zones = DateTimeZoneCache(source);
          expect(Instant.FromUtc(2024, 7, 1, 12, 0).InZone(zones['Australia/Sydney']).toString(),
              '2024-07-01T22:00:00 Australia/Sydney (+10)');
        }), timeout: timeout);
  });

  group('CompileTzdb', () {
    test("gives a validated source with the bundled tzdb's version and zones", () => RunOrSkip(() async {
          final source = await CompileTzdb(await TarGz());
          expect(source, isA<TzdbDateTimeZoneSource>());
          expect(source.VersionId, bundledSource.VersionId);
          expect(source.TzdbVersion, '2026f');
          expect(source.GetIds().toList(), bundledSource.GetIds().toList());
          expect(source.CanonicalIdMap, bundledSource.CanonicalIdMap);
          expect(source.ZoneLocations!.length, bundledSource.ZoneLocations!.length);
          expect(source.WindowsMapping.MapZones.length, bundledSource.WindowsMapping.MapZones.length);

          final zones = DateTimeZoneCache(source);
          expect(Instant.FromUtc(2024, 7, 1, 12, 0).InZone(zones['Europe/Madrid']).toString(),
              '2024-07-01T14:00:00 Europe/Madrid (+02)');
        }), timeout: timeout);
  });

  group('errors', () {
    test('an HTTP error', () => RunOrSkip(() async {
          final server = await StartHttpServer((path) => 404);
          try {
            await expectLater(
                CompileTzdb('${server.Url}/tzdata.tar.gz'),
                throwsA(isA<HttpRequestException>()
                    .having((e) => e.message, 'message', 'Response status code does not indicate success: 404 (Not Found).')
                    .having((e) => e.StatusCode, 'StatusCode', 404)));
          } finally {
            await server.Close();
          }
        }));

    test('an lzip archive', () async {
      final lzip = Uint8List.fromList([0x4c, 0x5a, 0x49, 0x50, 0x01, 0x0c, 0x00, 0x00]);
      await expectLater(CompileTzdbToNzd(lzip), throwsWithMessage<UnsupportedError>('tzdata-latest.tar.gz'));
      expect(() => CompileTzdbToNzdSync(lzip), throwsWithMessage<UnsupportedError>('tzdata-latest.tar.gz'));
    });

    test('data that is neither gzip nor tar', () async {
      final data = Uint8List(1024)..fillRange(0, 1024, 0x41);
      await expectLater(CompileTzdbToNzd(data), throwsA(isA<InvalidDataException>()));
      expect(() => CompileTzdbToNzdSync(data), throwsA(isA<InvalidDataException>()));
    });

    test('corrupt gzip data', () => RunOrSkip(() async {
          final corrupt = (await TarGz()).sublist(0, 2000);
          corrupt.fillRange(100, corrupt.length, 0xff);
          await expectLater(CompileTzdbToNzd(corrupt), throwsA(isA<InvalidDataException>()));
          expect(() => CompileTzdbToNzdSync(corrupt), throwsA(isA<InvalidDataException>()));
        }));

    test('an archive without a version (no version file, and nothing in the source\'s name)', () => RunOrSkip(() async {
          await expectLater(CompileTzdbToNzd(RemoveTarEntry(await TarFile(), 'version')),
              throwsA(isA<InvalidDataException>().having((e) => e.message, 'message', 'Unable to determine TZDB version from source')));
        }), timeout: timeout);

    test("a source that isn't a URL or bytes", () async {
      await expectLater(CompileTzdb(42), throwsWithMessage<ArgumentError>('or a URL or path'));
      expect(() => CompileTzdbSync(42), throwsWithMessage<ArgumentError>("must be the archive's bytes"));
    });

    test("a URL, path or stream can't be compiled synchronously", () {
      for (final source in <Object>['https://data.iana.org/time-zones/tzdata-latest.tar.gz', 'tzdata.tar.gz', const Stream<List<int>>.empty()]) {
        expect(() => CompileTzdbToNzdSync(source),
            throwsWithMessage<ArgumentError>('CompileTzdb and CompileTzdbToNzd also take a URL, path or stream'));
      }
    });

    test('a data: URI that is not a tzdata archive', () {
      expect(() => CompileTzdbSync('data:application/octet-stream;base64,${base64Encode(utf8.encode('not tar'))}'),
          throwsA(isA<InvalidDataException>()));
    });
  });
}
