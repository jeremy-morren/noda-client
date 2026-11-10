// Ported from NodaTime 6e024dde: src/NodaTime.TzdbCompiler/Tzdb/IoExtensions.cs
// Copyright 2015 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'dart:convert';
import 'dart:typed_data';

import 'package:meta/meta.dart';

import 'FileSource.dart';

/// IO-related extension methods
///
/// noda_dart: a Stream is its bytes (a Uint8List, decoded as UTF-8 as StreamReader does); a TextReader is a String.
@internal
extension IoExtensions on Uint8List {
  /// `ReadLines(this Stream stream)`.
  Iterable<String> ReadLines() => IoExtensionsTextReader(DecodeStream(this)).ReadLines();
}

/// `IoExtensions.ReadLines(this TextReader reader)`: the TextReader is the text it reads.
@internal
extension IoExtensionsTextReader on String {
  Iterable<String> ReadLines() sync* {
    final text = this;
    var start = 0;
    while (start < text.length) {
      var end = start;
      while (end < text.length && text[end] != '\r' && text[end] != '\n') {
        end++;
      }
      yield text.substring(start, end);
      if (end < text.length && text[end] == '\r' && end + 1 < text.length && text[end + 1] == '\n') {
        end++;
      }
      start = end + 1;
    }
  }
}

// Not ported: ReadLines(Func<TextReader> readerProvider) (only used to implement the FileSource overload below; there
// is no reader to dispose)

/// `IoExtensions.ReadLines(this FileSource source, string name)`.
@internal
extension IoExtensionsFileSource on FileSource {
  Iterable<String> ReadLines(String name) => Open(name).ReadLines();
}

/// `new StreamReader(stream).ReadToEnd()` (and `new StreamReader(stream, true)`, as TzdbZoneInfoParser reads a file),
/// for a stream holding the given bytes: UTF-8, skipping a byte order mark.
@internal
String DecodeStream(Uint8List bytes) {
  final text = utf8.decode(bytes, allowMalformed: true);
  return text.isNotEmpty && text.codeUnitAt(0) == 0xFEFF ? text.substring(1) : text;
}
