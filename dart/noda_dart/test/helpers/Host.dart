// noda_dart: new code. Host services for the tzdb compiler's tests: compression independent of our inflate, files and
// an HTTP server. Where unavailable (files on the web) they throw UnsupportedValue and the test is skipped.

import 'dart:async';
import 'dart:typed_data';

import 'package:test/test.dart';

import 'Decode.dart';
import 'Fixtures.dart';
import 'Host_stub.dart' if (dart.library.io) 'Host_io.dart' if (dart.library.js_interop) 'Host_web.dart' as host;

export 'Host_stub.dart' if (dart.library.io) 'Host_io.dart' if (dart.library.js_interop) 'Host_web.dart';

/// [ReadFixture], or on Node.js via fs.
Future<Uint8List> ReadFixtureOrNode(String path) async {
  try {
    return await ReadFixture(path);
  } on UnsupportedValue {
    return host.ReadFixtureWithHost(path);
  }
}

/// Skips the test if the body throws [UnsupportedValue].
Future<void> RunOrSkip(FutureOr<void> Function() body) async {
  try {
    await body();
  } on UnsupportedValue catch (e) {
    markTestSkipped(e.message);
  }
}
