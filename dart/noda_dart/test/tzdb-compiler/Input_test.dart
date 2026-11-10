// noda_dart: new code. The tzdb compiler's input sources (as noda-js's Input.test.ts); URLs are served by a local HTTP
// server, so URL, file and directory tests are skipped on the web.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:noda_dart/src/TzdbCompiler/Input.dart';
import 'package:noda_dart/src/TzdbCompiler/Shims.dart';
import 'package:noda_dart/src/TzdbCompiler/Tzdb/FileSource.dart';
import 'package:noda_dart/src/TzdbCompiler/Tzdb/TzdbZoneInfoCompiler.dart';
import 'package:noda_dart/src/Utility/SystemExceptions.dart';
import 'package:test/test.dart';

import '../helpers/Host.dart';
import 'TarBuilder.dart';

/// One file isn't ASCII (or UTF-8).
final Map<String, List<int>> files = {
  'africa': [1, 2, 3, 0x80, 0xff],
  'europe': utf8.encode('Zone\tEurope/London'),
};

/// In a directory, as `tzdb-<version>.tar.lz` archives have them.
final Uint8List archive = TarOfBytes({for (final MapEntry(:key, :value) in files.entries) 'tzdata/$key': value});

final Uint8List archiveWithVersion = TarOfBytes({...files, 'version': utf8.encode('2026f\n')});

/// A map, so `expect` compares it deeply.
Map<String, Object> Read(FileSource source) =>
    {'Files': {for (final name in source.Names) name: source.Open(name).toList()}, 'Origin': source.Origin};

Map<String, Object> Source(Map<String, List<int>> files, String origin) => {'Files': files, 'Origin': origin};

Map<String, Object> Expected([String origin = '']) => Source(files, origin);

Future<void> expectBoth(Object? source, [Map<String, Object>? expected]) async {
  expected ??= Expected();
  expect(Read(ReadTzdataSourceSync(source)), expected);
  expect(Read(await ReadTzdataSource(source, null)), expected);
}

Future<void> expectBothRejected(Object? source, [String message = '']) async {
  final matcher = isA<ArgumentError>().having((e) => '${e.message}', 'message', contains(message));
  expect(() => ReadTzdataSourceSync(source), throwsA(matcher), reason: '$source');
  await expectLater(ReadTzdataSource(source, null), throwsA(matcher), reason: '$source');
}

Matcher throwsWithMessage<T>(String message) =>
    throwsA(isA<T>().having((e) => (e as dynamic).message as String, 'message', contains(message)));

/// What a directory URL downloads.
final List<String> directoryFiles = [
  ...TzdbZoneInfoCompiler.ZoneFiles,
  TzdbZoneInfoCompiler.Iso3166TabFile,
  TzdbZoneInfoCompiler.ZoneTabFile,
  TzdbZoneInfoCompiler.Zone1970TabFile,
  'version',
];

void main() {
  group('bytes (sync and async)', () {
    test('a Uint8List, and a view of part of one', () async {
      await expectBoth(archive);
      final padded = Uint8List(archive.length + 2)..setAll(1, archive);
      await expectBoth(Uint8List.sublistView(padded, 1, archive.length + 1));
    });

    test('a List<int> of byte values, unsigned or signed, and other typed lists', () async {
      await expectBoth(List<int>.of(archive));
      final signed = [for (final b in archive) b >= 0x80 ? b - 0x100 : b];
      await expectBoth(signed);
      await expectBoth(Int8List.fromList(signed));
      await expectBoth(Uint8ClampedList.fromList(archive));
      await expectBoth(<int>[], Source({}, ''));
    });

    test('the version file sets the origin (the compiler takes the version from the origin)', () async {
      await expectBoth(archiveWithVersion, Source({...files, 'version': utf8.encode('2026f\n')}, 'tzdata2026f.tar'));
    });

    test("rejects numbers that aren't bytes, and values that aren't sources", () async {
      for (final source in <Object?>[
        [256],
        [-129],
        [1, 1000],
        42,
        null,
        true,
        1.5,
        <String, int>{},
        <Object>[1, '2'],
      ]) {
        await expectBothRejected(source);
      }
      await expectBothRejected([256], 'element 0 is 256');
    });

    test("a URL, path or stream can't be read synchronously", () {
      for (final source in <Object>[
        'https://example.com/tzdata.tar.gz',
        Uri.parse('https://example.com/tzdata.tar.gz'),
        'tzdata.tar.gz',
        Stream<List<int>>.value(archive),
      ]) {
        expect(() => ReadTzdataSourceSync(source),
            throwsWithMessage<ArgumentError>('CompileTzdb and CompileTzdbToNzd also take a URL, path or stream'));
      }
    });
  });

  group('data: URIs (sync and async)', () {
    test('a data: URI, as a String or a Uri', () async {
      final url = 'data:application/octet-stream;base64,${base64Encode(archive)}';
      await expectBoth(url);
      await expectBoth(Uri.parse(url));
      await expectBoth(Uri.dataFromBytes(archive));
    });
  });

  group('streams (async)', () {
    test('a Stream of chunks of any kind', () async {
      final chunks = <List<int>>[
        Uint8List.sublistView(archive, 0, 100),
        List<int>.of(archive.sublist(100, 700)),
        [for (final b in archive.sublist(700, 701)) b >= 0x80 ? b - 0x100 : b],
        Uint8List.fromList(archive.sublist(701)),
      ];
      expect(Read(await ReadTzdataSource(Stream<List<int>>.fromIterable(chunks), null)), Expected());
    });

    test("a stream of values that aren't bytes, and a stream's error", () async {
      await expectLater(ReadTzdataSource(Stream<List<int>>.value([256]), null),
          throwsWithMessage<ArgumentError>('The tzdata stream must be bytes'));
      await expectLater(
          ReadTzdataSource(Stream<List<int>>.error(StateError('broken')), null), throwsA(isA<StateError>()));
    });
  });

  group("URLs (async: dart:io's HttpClient, from a local server)", () {
    test('an archive: its file name (without the query) is the origin, and gzip is decompressed', () => RunOrSkip(() async {
          final gzip = await Compress(archive, 'gzip');
          final server = await StartHttpServer((path) => path.startsWith('/files/tzdata2026f.tar.gz') ? gzip : null);
          try {
            final log = <String>[];
            final url = '${server.Url}/files/tzdata2026f.tar.gz?x=1#y';
            expect(Read(await ReadTzdataSource(url, log.add)), Expected('tzdata2026f.tar.gz'));
            expect(Read(await ReadTzdataSource(Uri.parse('${server.Url}/files/tzdata2026f.tar.gz'), null)),
                Expected('tzdata2026f.tar.gz'));
            expect(server.Requests, ['/files/tzdata2026f.tar.gz?x=1', '/files/tzdata2026f.tar.gz']);
            expect(log, ['Downloading $url']);
          } finally {
            await server.Close();
          }
        }));

    test('follows redirects', () => RunOrSkip(() async {
          final server = await StartHttpServer((path) => switch (path) {
                '/latest.tar' => '/releases/tzdata2026f.tar',
                '/releases/tzdata2026f.tar' => archive,
                _ => null,
              });
          try {
            // The origin is the URL's file name, as in NodaTime.
            expect(Read(await ReadTzdataSource('${server.Url}/latest.tar', null)), Expected('latest.tar'));
            expect(server.Requests, ['/latest.tar', '/releases/tzdata2026f.tar']);
          } finally {
            await server.Close();
          }
        }));

    test('an unsuccessful status', () => RunOrSkip(() async {
          final server = await StartHttpServer((path) => null);
          try {
            await expectLater(
                ReadTzdataSource('${server.Url}/tzdata.tar.gz', null),
                throwsA(isA<HttpRequestException>()
                    .having((e) => e.message, 'message', 'Response status code does not indicate success: 404 (Not Found).')
                    .having((e) => e.StatusCode, 'StatusCode', 404)));
          } finally {
            await server.Close();
          }
        }));
  });

  group('directory URLs (a path ending with /): the compiler\'s files, one by one', () {
    const base = '/gh/eggert/tz@2026f/';
    // Every file but pacificnew and systemv (removed from tzdb in 2020b) and version (not in the tz repository).
    final served = {
      for (final (i, name) in directoryFiles.where((n) => !['pacificnew', 'systemv', 'version'].contains(n)).indexed)
        name: Uint8List.fromList([i, 0x80 + i]),
    };

    test('with HttpClient, skipping the files that are missing (404)', () => RunOrSkip(() async {
          final server = await StartHttpServer((path) => path.startsWith(base) ? served[path.substring(base.length)] : null);
          try {
            final log = <String>[];
            final directory = await ReadTzdataSource('${server.Url}$base', log.add);
            expect(server.Requests, unorderedEquals(directoryFiles.map((name) => '$base$name')));
            expect(log, unorderedEquals(directoryFiles.map((name) => 'Downloading ${server.Url}$base$name')));
            // The version comes from the directory's name (here "tz@2026f": the compiler finds 2026f in it).
            expect(Read(directory), Source(served, 'tz@2026f'));
          } finally {
            await server.Close();
          }
        }));

    test('a version file sets the origin', () => RunOrSkip(() async {
          final withVersion = {...served, 'version': utf8.encode('2026f\n')};
          final server = await StartHttpServer((path) => withVersion[path.substring('/tz/'.length)]);
          try {
            expect(Read(await ReadTzdataSource(Uri.parse('${server.Url}/tz/'), null)),
                Source(withVersion, 'tzdata2026f.tar'));
          } finally {
            await server.Close();
          }
        }));

    test("keeps the URL's query", () => RunOrSkip(() async {
          final server = await StartHttpServer((path) {
            final match = RegExp(r'^/gh/eggert/tz@2026f/([^?]*)\?token=1$').firstMatch(path);
            return match == null ? null : served[match[1]];
          });
          try {
            expect(Read(await ReadTzdataSource('${server.Url}$base?token=1', null))['Files'], served);
            expect(server.Requests, contains('${base}africa?token=1'));
          } finally {
            await server.Close();
          }
        }));

    test('errors: other HTTP errors, and a directory without tzdata files', () => RunOrSkip(() async {
          final server = await StartHttpServer((path) => path == '${base}europe' ? 500 : served[path.substring(base.length)]);
          final empty = await StartHttpServer((path) => null);
          try {
            await expectLater(
                ReadTzdataSource('${server.Url}$base', null),
                throwsA(isA<HttpRequestException>()
                    .having((e) => e.message, 'message',
                        'Downloading ${server.Url}${base}europe failed: HTTP 500 Internal Server Error')
                    .having((e) => e.StatusCode, 'StatusCode', 500)));
            await expectLater(ReadTzdataSource('${empty.Url}$base', null),
                throwsWithMessage<InvalidDataException>('has none of the tzdata files'));
          } finally {
            await server.Close();
            await empty.Close();
          }
        }));
  });

  group('local files and directories (async: dart:io)', () {
    test("an archive file: its file name is the origin, and gzip is decompressed", () => RunOrSkip(() async {
          final directory = await CreateTempDirectory();
          try {
            final path = Combine(directory, 'tzdata2026f.tar.gz');
            await WriteAllBytes(path, await Compress(archive, 'gzip'));
            final log = <String>[];
            expect(Read(await ReadTzdataSource(path, log.add)), Expected('tzdata2026f.tar.gz'));
            expect(log, ['Compiling from archive file $path']);
            // A file: URI is the file it names.
            expect(Read(await ReadTzdataSource(FileUri(path), null)), Expected('tzdata2026f.tar.gz'));
          } finally {
            await DeleteDirectory(directory);
          }
        }));

    test('a directory of tzdata files: its name is the origin', () => RunOrSkip(() async {
          final parent = await CreateTempDirectory();
          try {
            final directory = Combine(parent, 'tzdata-2026f');
            await CreateDirectory(directory);
            for (final MapEntry(key: name, value: data) in files.entries) {
              await WriteAllBytes(Combine(directory, name), data);
            }
            final log = <String>[];
            expect(Read(await ReadTzdataSource(directory, log.add)), Expected('tzdata-2026f'));
            expect(log, ['Compiling from directory $directory']);
          } finally {
            await DeleteDirectory(parent);
          }
        }));

    test('a directory without tzdata files', () => RunOrSkip(() async {
          final directory = await CreateTempDirectory();
          try {
            await WriteAllBytes(Combine(directory, 'readme'), [1]);
            await expectLater(
                ReadTzdataSource(directory, null), throwsWithMessage<InvalidDataException>('has none of the tzdata files'));
          } finally {
            await DeleteDirectory(directory);
          }
        }));
  });
}
