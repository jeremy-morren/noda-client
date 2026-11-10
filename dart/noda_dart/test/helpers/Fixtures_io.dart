// noda_dart: new code. Fixtures.dart with dart:io, found from package:noda_dart's location.

import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

Future<Uint8List> ReadFixture(String path) async {
  final lib = await Isolate.resolvePackageUri(Uri.parse('package:noda_dart/noda_dart.dart'));
  // dart/noda_dart/lib/noda_dart.dart → the repository root.
  final root = lib == null ? Directory.current.uri.resolve('../../') : lib.resolve('../../../');
  return File.fromUri(root.resolve('testdata/$path')).readAsBytes();
}
