// noda_dart: new code. Host.dart on the web: CompressionStream; no files or servers.

import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'Decode.dart';

UnsupportedValue _Unsupported(String what) =>
    UnsupportedValue("$what needs dart:io, which the web doesn't have");

@JS('Blob')
extension type _Blob._(JSObject _) implements JSObject {
  external factory _Blob(JSArray<JSAny> parts);
  external _ReadableStream stream();
}

extension type _ReadableStream._(JSObject _) implements JSObject {
  external _ReadableStream pipeThrough(JSObject transform);
}

@JS('CompressionStream')
extension type _CompressionStream._(JSObject _) implements JSObject {
  external factory _CompressionStream(JSString format);
}

@JS('DecompressionStream')
extension type _DecompressionStream._(JSObject _) implements JSObject {
  external factory _DecompressionStream(JSString format);
}

@JS('Response')
extension type _Response._(JSObject _) implements JSObject {
  external factory _Response(JSObject body);
  external JSPromise<JSArrayBuffer> arrayBuffer();
}

Future<Uint8List> _Pipe(Uint8List data, JSObject transform) async {
  final stream = _Blob([data.toJS].toJS).stream().pipeThrough(transform);
  return (await _Response(stream).arrayBuffer().toDart).toDart.asUint8List();
}

void _CheckHas(String name) {
  if (!globalContext.has(name)) {
    throw UnsupportedValue('The host has no $name');
  }
}

Future<Uint8List> Compress(Uint8List data, String format) {
  _CheckHas('CompressionStream');
  return _Pipe(data, _CompressionStream(format.toJS));
}

Future<Uint8List> Decompress(Uint8List data, String format) {
  _CheckHas('DecompressionStream');
  return _Pipe(data, _DecompressionStream(format.toJS));
}

@JS('process')
external _Process? get _process;

extension type _Process._(JSObject _) implements JSObject {
  external JSString cwd();
  external JSObject? getBuiltinModule(JSString id);
}

extension type _Fs._(JSObject _) implements JSObject {
  external JSUint8Array readFileSync(JSString path);
}

/// Node.js only (via fs, from dart/noda_dart); throws UnsupportedValue in a browser.
Future<Uint8List> ReadFixtureWithHost(String path) async {
  final fs = _process?.getBuiltinModule('fs'.toJS);
  if (fs == null) {
    throw UnsupportedValue("Test fixtures ($path) are read with dart:io, or Node.js's fs module");
  }
  final root = '${_process!.cwd().toDart}/../..';
  return (fs as _Fs).readFileSync('$root/testdata/$path'.toJS).toDart;
}

Future<String> GetTempFileName() => throw _Unsupported('A temporary file');

Future<String> CreateTempDirectory() => throw _Unsupported('A temporary directory');

Future<void> CreateDirectory(String path) => throw _Unsupported('Creating a directory');

Future<void> WriteAllBytes(String path, List<int> bytes) => throw _Unsupported('Writing a file');

Future<void> DeleteFile(String path) => throw _Unsupported('Deleting a file');

Future<void> DeleteDirectory(String path) => throw _Unsupported('Deleting a directory');

String Combine(String directory, String name) => throw _Unsupported('A file path');

Uri FileUri(String path) => throw _Unsupported('A file URI');

final class TestHttpServer {
  final List<String> Requests = [];

  String get Url => throw _Unsupported('An HTTP server');

  Future<void> Close() async {}
}

Future<TestHttpServer> StartHttpServer(Object? Function(String pathAndQuery) handler) =>
    throw _Unsupported('An HTTP server');
