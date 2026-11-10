// Ported from NodaTime 6e024dde: src/NodaTime/TimeZones/IO/TzdbStreamField.cs
// Copyright 2012 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../../Utility/InvalidNodaDataException.dart';
import '../../Utility/Stream.dart';
import 'DateTimeZoneReader.dart';
import 'TzdbStreamFieldId.generated.dart';

/// An unparsed field within a stream.
@internal
final class TzdbStreamField {
  final Uint8List _data;

  @internal
  final TzdbStreamFieldId Id;

  @visibleForTesting
  @internal
  TzdbStreamField.NewIdData(TzdbStreamFieldId id, Uint8List data)
      : Id = id,
        _data = data;

  /// Creates a new read-only stream over the data for this field.
  ///
  /// (Dart: the stream can't be extended; as noda-js's, it isn't otherwise read-only.)
  @internal
  Stream CreateStream() => MemoryStream(_data);

  @internal
  T ExtractSingleValue<T>(T Function(DateTimeZoneReader) readerFunction, List<String>? stringPool) {
    // Dart: C#'s using is dropped (disposing a MemoryStream releases nothing).
    var stream = CreateStream();
    return readerFunction(DateTimeZoneReader.NewInputStringPool(stream, stringPool));
  }

  @internal
  static Iterable<TzdbStreamField> ReadFields(Stream input) sync* {
    while (true) {
      int fieldId = input.ReadByte();
      if (fieldId == -1) {
        return;
      }
      TzdbStreamFieldId id = TzdbStreamFieldId(fieldId & 0xff);
      // Read 7-bit-encoded length
      int length = DateTimeZoneReader.NewInputStringPool(input, null).ReadCount();
      Uint8List data = Uint8List(length);
      int offset = 0;
      while (offset < data.length) {
        int bytesRead = input.Read(data, offset, data.length - offset);
        if (bytesRead == 0) {
          throw InvalidNodaDataException('Stream ended after reading $offset bytes out of ${data.length}');
        }
        offset += bytesRead;
      }
      yield TzdbStreamField.NewIdData(id, data);
    }
  }
}
