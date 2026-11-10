// noda_dart: new code. Fixtures.dart without dart:io.

import 'dart:typed_data';

import 'Decode.dart';

Future<Uint8List> ReadFixture(String path) =>
    throw UnsupportedValue('Test fixtures ($path) are read with dart:io, which the web doesn\'t have');
