// Ported from NodaTime 6e024dde: src/NodaTime.Test/TimeZones/IO/DateTimeZoneReaderTest.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'dart:typed_data';

import 'package:noda_dart/src/NodaConstants.dart';
import 'package:noda_dart/src/TimeZones/IO/DateTimeZoneReader.dart';
import 'package:noda_dart/src/Utility/InvalidNodaDataException.dart';
import 'package:noda_dart/src/Utility/Stream.dart';

import '../../../helpers/Assertions.dart';
import '../../../helpers/Scenarios.dart';
import '../../../scenarios/TimeZones/IO/DateTimeZoneReaderTest.generated.dart' as scenarios;

// Tests for DateTimeZoneReader behaviour that isn't already covered by ReadWriteTest.
void main() {
  port(scenarios.fixture, {
    'HasMoreData_Buffers': (args) {
      var stream = MemoryStream(Uint8List.fromList([1, 2]));
      var reader = DateTimeZoneReader.NewInputStringPool(stream, null);

      // HasMoreData reads a byte and buffers it
      Assert.AreEqual(0, stream.Position);
      Assert.IsTrue(reader.HasMoreData);
      Assert.AreEqual(1, stream.Position);
      Assert.IsTrue(reader.HasMoreData);
      Assert.AreEqual(1, stream.Position);

      // Consume the buffered byte
      Assert.AreEqual(1, reader.ReadByte());
      Assert.AreEqual(1, stream.Position);

      // HasMoreData reads the next byte
      Assert.IsTrue(reader.HasMoreData);
      Assert.AreEqual(2, stream.Position);
      Assert.IsTrue(reader.HasMoreData);
      Assert.AreEqual(2, stream.Position);

      // Consume the buffered byte
      Assert.AreEqual(2, reader.ReadByte());
      Assert.AreEqual(2, stream.Position);

      // No more data
      Assert.IsFalse(reader.HasMoreData);
    },

    'ReadCount_OutOfRange': (args) {
      // Int32.MaxValue + 1 (as a uint) is 10000000_00000000_00000000_00000000
      // So only bit 31 is set.
      // Divided into 7 bit chunks (reverse order), with top bit set for continuation, this is:
      // 10000000 - bits 0-6
      // 10000000 - bits 7-13
      // 10000000 - bits 14-20
      // 10000000 - bits 21-27
      // 00001000 - bits 28-34
      Uint8List data = Uint8List.fromList([0x80, 0x80, 0x80, 0x80, 0x08]); // C#: 0b0000_1000 (Dart has no binary literals)
      var stream = MemoryStream(data);
      var reader = DateTimeZoneReader.NewInputStringPool(stream, null);
      Assert.Throws<InvalidNodaDataException>(() => reader.ReadCount());
    },

    'ReadMilliseconds_InvalidFlag': (args) {
      // Top 3 bits are the flag. Valid flag values are 0b100 (minutes), 0b101 (seconds)  and 0b110 (milliseconds)
      Uint8List data = Uint8List.fromList([0xe0, 0, 0, 0, 0, 0]); // Invalid flag (followed by 0s to check that it's not just out of data)
      var stream = MemoryStream(data);
      var reader = DateTimeZoneReader.NewInputStringPool(stream, null);
      Assert.Throws<InvalidNodaDataException>(() => reader.ReadMilliseconds());
    },

    'ReadZoneIntervalTransition_InvalidMarkerValue': (args) {
      Uint8List data = Uint8List.fromList([4, 0, 0, 0, 0, 0]); // Marker value of 4 (followed by 0s to check that it's not just out of data)
      var stream = MemoryStream(data);
      var reader = DateTimeZoneReader.NewInputStringPool(stream, null);
      Assert.Throws<InvalidNodaDataException>(() => reader.ReadZoneIntervalTransition(NodaConstants.UnixEpoch));
    },

    'ReadZoneIntervalTransition_NoPreviousValue': (args) {
      // Count value between 1 << 7 and 1 << 21 (followed by 0s to check that it's not just out of data)
      Uint8List data = Uint8List.fromList([0xff, 0x7f, 0, 0, 0, 0]);
      var stream = MemoryStream(data);
      var reader = DateTimeZoneReader.NewInputStringPool(stream, null);
      Assert.Throws<InvalidNodaDataException>(() => reader.ReadZoneIntervalTransition(null));

      // Validate that when we *do* provide a previous value, it doesn't throw
      stream.Position = 0;
      reader = DateTimeZoneReader.NewInputStringPool(stream, null);
      reader.ReadZoneIntervalTransition(NodaConstants.UnixEpoch);
    },

    'ReadString_NotEnoughData': (args) {
      // We say there are 5 bytes, but there are only 4 left...
      Uint8List data = Uint8List.fromList([0x05, 0x40, 0x40, 0x40, 0x40]);
      var stream = MemoryStream(data);
      var reader = DateTimeZoneReader.NewInputStringPool(stream, null);
      Assert.Throws<InvalidNodaDataException>(() => reader.ReadString());
    },

    'ReadByte_NotEnoughData': (args) {
      Uint8List data = Uint8List.fromList([0x05]);
      var stream = MemoryStream(data);
      var reader = DateTimeZoneReader.NewInputStringPool(stream, null);
      // Just check we can read the first byte, then fail on the second
      Assert.AreEqual(5, reader.ReadByte());
      Assert.Throws<InvalidNodaDataException>(() => reader.ReadByte());
    },
  });
}
