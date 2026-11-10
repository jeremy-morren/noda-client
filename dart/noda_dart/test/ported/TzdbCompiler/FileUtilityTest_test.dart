// Ported from NodaTime 6e024dde: src/NodaTime.TzdbCompiler.Test/FileUtilityTest.cs
// Copyright 2026 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda_dart: a Stream is a Uint8List; LoadFileAsync needs files, so it's skipped on the web.

import 'dart:convert';
import 'dart:typed_data';

import 'package:noda_dart/src/Tools/Common/FileUtility.dart';
import 'package:noda_dart/src/TzdbCompiler/Tar.dart';

import '../../helpers/Assertions.dart';
import '../../helpers/Host.dart';
import '../../helpers/Scenarios.dart';
import '../../scenarios/TzdbCompiler/FileUtilityTest.generated.dart' as scenarios;

void main() {
  port(scenarios.fixture, {
    'LoadFileAsync': (args) async {
      final [bool gzip] = args;
      var content = utf8.encode('Some file content');
      var path = await GetTempFileName();
      try {
        // (File.Create, through a GZipStream if gzip.)
        await WriteAllBytes(path, gzip ? await Compress(content, 'gzip') : content);

        var stream = await FileUtility.LoadFileOrUrlAsync(path);
        var actual = stream;
        Assert.AreEqual(content, actual);
      } finally {
        await DeleteFile(path);
      }
    },

    'LoadCompressedUrlAsync': (args) async {
      final [String url] = args;
      var stream = await FileUtility.LoadFileOrUrlAsync(url);
      AssertTar(stream);
    },

    'LoadUncompressedUrlAsync': (args) async {
      final [String url] = args;
      var stream = await FileUtility.LoadFileOrUrlAsync(url);
      AssertTar(stream);
    },
  });
}

void AssertTar(Uint8List stream) {
  var reader = ReadTar(stream);
  var entry = reader.entries.firstOrNull;
  Assert.IsNotNull(entry);
}
