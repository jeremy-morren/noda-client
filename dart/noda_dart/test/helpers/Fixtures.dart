// noda_dart: new code. Binary test resources from the repository's testdata/ (shared with noda-js); read with dart:io, so skipped
// on the web.

import 'dart:typed_data';

import 'Fixtures_stub.dart' if (dart.library.io) 'Fixtures_io.dart' as impl;

/// [path] is relative to the repository's testdata/.
Future<Uint8List> ReadFixture(String path) => impl.ReadFixture(path);
