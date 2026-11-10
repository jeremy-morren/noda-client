// noda_dart: new code (as noda-js's Tar.test.ts). Our minimal tar reader.

import 'dart:typed_data';

import 'package:noda_dart/src/TzdbCompiler/Tar.dart';
import 'package:noda_dart/src/Utility/SystemExceptions.dart';
import 'package:test/test.dart';

import 'TarBuilder.dart';

void expectInvalidData(void Function() action, String message) {
  expect(action, throwsA(isA<InvalidDataException>().having((e) => e.message, 'message', contains(message))));
}

void main() {
  group('ReadTar', () {
    test('reads regular files, by their names in the archive', () {
      final archive = Tar(const [
        TarEntry('africa', data: 'Zone\tAfrica/Abidjan'),
        TarEntry('tzdb-2026f/version', data: '2026f\n'),
        TarEntry('empty'),
      ]);
      expect(Texts(ReadTar(archive)), {'africa': 'Zone\tAfrica/Abidjan', 'tzdb-2026f/version': '2026f\n', 'empty': ''});
    });

    test('reads files of several blocks', () {
      final big = 'x' * 1500;
      expect(Texts(ReadTar(Tar([TarEntry('big', data: big), const TarEntry('after', data: 'a')]))),
          {'big': big, 'after': 'a'});
    });

    test('uses the ustar prefix field, only in POSIX ustar headers', () {
      expect(ReadTar(Tar(const [TarEntry('zone.tab', data: 'z', prefix: 'tzdb-2026f/data')])).keys,
          ['tzdb-2026f/data/zone.tab']);
      // GNU tar ("ustar  \0") uses the same bytes for other things; old (v7) archives have no magic.
      expect(ReadTar(Tar(const [TarEntry('a', prefix: 'x', magic: 'ustar  \u0000')])).keys, ['a']);
      expect(ReadTar(Tar(const [TarEntry('b', prefix: 'x', magic: '')])).keys, ['b']);
    });

    test('uses the path in a pax extended header for the next entry only', () {
      final longName = 'tzdb-2026f/${'d' * 120}/zone1970.tab';
      final archive = Tar([
        TarEntry('PaxHeaders/zone1970.tab',
            type: 'x', data: PaxRecord('mtime', '1700000000.5') + PaxRecord('path', longName)),
        const TarEntry('truncated-name', data: 'z'),
        TarEntry('PaxHeaders/other', type: 'x', data: PaxRecord('mtime', '1')),
        const TarEntry('plain', data: 'p'),
      ]);
      expect(Texts(ReadTar(archive)), {longName: 'z', 'plain': 'p'});
    });

    test('uses a GNU long name for the next entry', () {
      final longName = '${'n' * 150}/backward';
      final archive = Tar([
        TarEntry('././@LongLink', type: 'L', data: '$longName\u0000', magic: 'ustar  \u0000'),
        const TarEntry('short', data: 'b'),
      ]);
      expect(Texts(ReadTar(archive)), {longName: 'b'});
    });

    test("skips entries that aren't regular files", () {
      final archive = Tar([
        const TarEntry('dir/', type: '5'),
        const TarEntry('link', type: '1'),
        const TarEntry('symlink', type: '2'),
        TarEntry('PaxHeaders/global', type: 'g', data: PaxRecord('comment', 'hi')),
        const TarEntry('old-dir/', type: '\u0000'),
        const TarEntry('old-file', type: '\u0000', data: 'o'),
        const TarEntry('contiguous', type: '7', data: 'c'),
      ]);
      expect(Texts(ReadTar(archive)), {'old-file': 'o', 'contiguous': 'c'});
    });

    test('keeps the last of entries with the same name', () {
      expect(Texts(ReadTar(Tar(const [TarEntry('a', data: '1'), TarEntry('a', data: '2')]))), {'a': '2'});
    });

    test('stops at the first zero block, and accepts an archive without one', () {
      final archive = Tar(const [TarEntry('a', data: '1')]);
      expect(Texts(ReadTar(Uint8List.sublistView(archive, 0, 1024))), {'a': '1'});
      expect(ReadTar(Uint8List(0)), isEmpty);
    });

    test("rejects data that isn't a tar archive, or is truncated", () {
      final notTar = Uint8List(512)..fillRange(0, 512, 0x41);
      expectInvalidData(() => ReadTar(notTar), 'Not a tar archive (invalid header checksum at offset 0).');
      final archive = Tar([TarEntry('a', data: 'x' * 600)]);
      expectInvalidData(() => ReadTar(Uint8List.sublistView(archive, 0, 1000)), 'unexpected end of data');
      final corrupt = Uint8List.fromList(archive);
      corrupt[0] = 0x62;
      expectInvalidData(() => ReadTar(corrupt), 'invalid header checksum');
      expectInvalidData(
          () => ReadTar(Tar(const [TarEntry('p', type: 'x', data: '99 path=x\n'), TarEntry('a')])),
          'invalid pax extended header');
    });
  });
}
