// Ported from NodaTime 6e024dde: src/NodaTime.Test/TimeZones/IO/DtzIoHelper.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda_dart: each pair of overloads is one method, the expected bytes optional.

import 'package:noda_dart/src/Instant.dart';
import 'package:noda_dart/src/Offset.dart';
import 'package:noda_dart/src/TimeZones/IO/DateTimeZoneReader.dart';
import 'package:noda_dart/src/TimeZones/IO/DateTimeZoneWriter.dart';
import 'package:noda_dart/src/TimeZones/IO/IDateTimeZoneReader.dart';
import 'package:noda_dart/src/TimeZones/IO/IDateTimeZoneWriter.dart';
import 'package:noda_dart/src/TimeZones/ZoneRecurrence.dart';
import 'package:noda_dart/src/TimeZones/ZoneYearOffset.dart';

import '../../../helpers/Assertions.dart';
import 'IoStream.dart';

/// Wrapper around a DateTimeZoneWriter/DateTimeZoneReader pair that reads whatever is
/// written to it.
class DtzIoHelper {
  final IoStream _ioStream;
  final List<String>? _stringPool;

  /// Initializes a new instance of the [DtzIoHelper] class.
  DtzIoHelper._(List<String>? stringPool)
      : _ioStream = IoStream(),
        _stringPool = stringPool {
    Reader = DateTimeZoneReader.NewInputStringPool(_ioStream.GetReadStream(), stringPool);
    Writer = DateTimeZoneWriter.NewOutputStringPool(_ioStream.GetWriteStream(), stringPool);
  }

  static DtzIoHelper CreateNoStringPool() {
    return DtzIoHelper._(null);
  }

  static DtzIoHelper CreateWithStringPool() {
    return DtzIoHelper._(<String>[]);
  }

  /// Gets the reader.
  late IDateTimeZoneReader Reader;

  /// Gets the writer.
  late IDateTimeZoneWriter Writer;

  void Reset() {
    _ioStream.Reset();
    if (_stringPool != null) {
      _stringPool.clear();
    }
  }

  /// TestCount(int expected) and TestCount(int value, byte[] expected).
  void TestCount(int value, [List<int>? expected]) {
    Reset();
    Writer.WriteCount(value);
    if (expected == null) {
      var actual = Reader.ReadCount();
      Assert.AreEqual(value, actual);
    } else {
      _ioStream.AssertUnreadContents(expected);
    }
    _ioStream.AssertEndOfStream();
  }

  /// TestSignedCount(int expected) and TestSignedCount(int value, byte[] expected).
  void TestSignedCount(int value, [List<int>? expected]) {
    Reset();
    Writer.WriteSignedCount(value);
    if (expected == null) {
      var actual = Reader.ReadSignedCount();
      Assert.AreEqual(value, actual);
    } else {
      _ioStream.AssertUnreadContents(expected);
    }
    _ioStream.AssertEndOfStream();
  }

  void TestDictionary(Map<String, String> expected) {
    Reset();
    Writer.WriteDictionary(expected);
    var actual = Reader.ReadDictionary();
    Assert.AreEqual(expected, actual);
    _ioStream.AssertEndOfStream();
  }

  void TestZoneIntervalTransition(Instant? previous, Instant expected) {
    Reset();
    Writer.WriteZoneIntervalTransition(previous, expected);
    var actual = Reader.ReadZoneIntervalTransition(previous);
    Assert.AreEqual(expected, actual);
    _ioStream.AssertEndOfStream();
  }

  void TestOffset(Offset offset) {
    Reset();
    Writer.WriteOffset(offset);
    var actual = Reader.ReadOffset();
    Assert.AreEqual(offset, actual);
    _ioStream.AssertEndOfStream();
  }

  void TestString(String expected) {
    Reset();
    Writer.WriteString(expected);
    var actual = Reader.ReadString();
    Assert.AreEqual(expected, actual);
    _ioStream.AssertEndOfStream();
  }

  void TestZoneRecurrence(ZoneRecurrence expected) {
    Reset();
    expected.Write(Writer);
    var actual = ZoneRecurrence.Read(Reader);
    Assert.AreEqual(expected, actual);
    _ioStream.AssertEndOfStream();
  }

  void TestZoneYearOffset(ZoneYearOffset expected) {
    Reset();
    expected.Write(Writer);
    var actual = ZoneYearOffset.Read(Reader);
    Assert.AreEqual(expected, actual);
    _ioStream.AssertEndOfStream();
  }
}
