// noda_dart: new code. Host.dart without dart:io or JS: everything throws UnsupportedValue.

import 'dart:typed_data';

import 'Decode.dart';

UnsupportedValue _Unsupported(String what) => UnsupportedValue('$what needs dart:io or JavaScript');

Future<Uint8List> Compress(Uint8List data, String format) => throw _Unsupported('Compressing data');

Future<Uint8List> Decompress(Uint8List data, String format) => throw _Unsupported('Decompressing data');

Future<Uint8List> ReadFixtureWithHost(String path) => throw _Unsupported('Reading a test fixture');

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
