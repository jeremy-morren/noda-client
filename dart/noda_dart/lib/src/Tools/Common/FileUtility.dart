// Ported from NodaTime 6e024dde: src/NodaTime.Tools.Common/FileUtility.cs
// Copyright 2018 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../../TzdbCompiler/FileSystem.dart' as host;
import '../../TzdbCompiler/Inflate.dart' show Gunzip;
import '../../TzdbCompiler/Shims.dart' show HttpRequestException;

// noda_dart: a Stream is a Uint8List, read to the end and decompressed in memory.
abstract final class FileUtility {
  /// Loads the given file or URL, decompressing it if it's gzip-compressed.
  ///

  /// Throws [HttpRequestException] if the download fails with an unsuccessful HTTP status.
  static Future<Uint8List> LoadFileOrUrlAsync(String source) async {
    if (source.startsWith('http://') || source.startsWith('https://')) {
      // (HttpClientHandler with AllowAutoRedirect: the host follows redirects.)
      final response = await host.HttpGetAsync(source);
      // response.EnsureSuccessStatusCode()
      if (response.StatusCode < 200 || response.StatusCode > 299) {
        throw HttpRequestException(
            'Response status code does not indicate success: ${response.StatusCode} (${response.ReasonPhrase}).',
            response.StatusCode);
      }
      // HttpClient with ResponseContentRead returns a seekable MemoryStream
      final content = response.Content;
      return Decompress(content);
    }

    return Decompress(await host.ReadAllBytesAsync(source));
  }

  /// Returns [stream] decompressed if it starts with the gzip magic number.
  ///
  /// noda_dart: internal, for TzdbCompiler/Archive.dart.
  @internal
  static Uint8List Decompress(Uint8List stream) {
    // Dart: the bytes are always "seekable and positioned at the start" (NodaTime's Preconditions.CheckArgument).
    if (stream.length < 2) {
      // Stream cannot be a gzip file
      return stream;
    }

    final first = stream[0];
    final second = stream[1];
    return first == 0x1f && second == 0x8b ? Gunzip(stream) : stream;
  }
}
