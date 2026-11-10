// noda_dart: new code. Host.dart with dart:io.

import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';

/// [format] is "gzip" or "deflate-raw", as CompressionStream names them.
Future<Uint8List> Compress(Uint8List data, String format) async =>
    Uint8List.fromList(_Codec(format).encode(data));

Future<Uint8List> Decompress(Uint8List data, String format) async =>
    Uint8List.fromList(_Codec(format).decode(data));

Codec<List<int>, List<int>> _Codec(String format) => switch (format) {
      'gzip' => io.GZipCodec(),
      'deflate-raw' => io.ZLibCodec(raw: true),
      _ => throw ArgumentError.value(format, 'format'),
    };

/// Unused here: Fixtures.dart reads fixtures with dart:io.
Future<Uint8List> ReadFixtureWithHost(String path) => throw UnsupportedError('Use ReadFixture');

Future<String> GetTempFileName() async {
  final directory = await io.Directory.systemTemp.createTemp('noda_dart_test_');
  final file = io.File('${directory.path}${io.Platform.pathSeparator}tmp.tmp');
  await file.create();
  return file.path;
}

Future<String> CreateTempDirectory() async => (await io.Directory.systemTemp.createTemp('noda_dart_test_')).path;

Future<void> CreateDirectory(String path) => io.Directory(path).create(recursive: true);

Future<void> WriteAllBytes(String path, List<int> bytes) => io.File(path).writeAsBytes(bytes, flush: true);

/// Also deletes the directory [GetTempFileName] made for it, if now empty.
Future<void> DeleteFile(String path) async {
  final file = io.File(path);
  if (await file.exists()) {
    await file.delete();
  }
  try {
    await file.parent.delete();
  } on io.FileSystemException {
    // Not empty, or not ours.
  }
}

Future<void> DeleteDirectory(String path) => io.Directory(path).delete(recursive: true);

String Combine(String directory, String name) => '$directory${io.Platform.pathSeparator}$name';

Uri FileUri(String path) => Uri.file(path);

final class TestHttpServer {
  final io.HttpServer _server;

  /// Path and query of each request, in order.
  final List<String> Requests = [];

  TestHttpServer._(this._server);

  /// No trailing slash.
  String get Url => 'http://127.0.0.1:${_server.port}';

  Future<void> Close() => _server.close(force: true);
}

/// [handler] returns bytes (200), a status code, a String (302 redirect to it) or null (404).
Future<TestHttpServer> StartHttpServer(Object? Function(String pathAndQuery) handler) async {
  final server = TestHttpServer._(await io.HttpServer.bind(io.InternetAddress.loopbackIPv4, 0));
  server._server.listen((request) async {
    final pathAndQuery = request.uri.toString();
    server.Requests.add(pathAndQuery);
    final response = request.response;
    final result = handler(pathAndQuery);
    switch (result) {
      case List<int> bytes:
        response.statusCode = 200;
        response.add(bytes);
      case int status:
        response.statusCode = status;
      case String location:
        response.statusCode = 302;
        response.headers.set('location', location);
      default:
        response.statusCode = 404;
    }
    await response.close();
  });
  return server;
}
