// Ported from NodaTime 6e024dde: src/NodaTime/TimeZones/IO/DateTimeZoneReader.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'dart:convert';
import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../../Duration.dart';
import '../../Instant.dart';
import '../../NodaConstants.dart';
import '../../Offset.dart';
import '../../Utility/Int64.dart';
import '../../Utility/InvalidNodaDataException.dart';
import '../../Utility/Stream.dart';
import 'DateTimeZoneWriter.dart';
import 'IDateTimeZoneReader.dart';

/// Implementation of [IDateTimeZoneReader] for the most recent version
/// of the "blob" format of time zone data. If the format changes, this class will be
/// renamed (e.g. to DateTimeZoneReaderV0) and the new implementation will replace it.
@internal
final class DateTimeZoneReader implements IDateTimeZoneReader {
  /// Raw stream to read from. Be careful before reading from this - you need to take
  /// account of bufferedByte as well.
  final Stream _input;

  /// String pool to use, or null if no string pool is in use.
  final List<String>? _stringPool;

  /// Sometimes we need to buffer a byte in memory, e.g. to check if there is any
  /// more data. Anything reading directly from the stream should check here first.
  int? _bufferedByte;

  @internal
  DateTimeZoneReader.NewInputStringPool(Stream input, List<String>? stringPool)
      : _input = input,
        _stringPool = stringPool;

  @override
  bool get HasMoreData {
    if (_bufferedByte != null) {
      return true;
    }
    int nextByte = _input.ReadByte();
    if (nextByte == -1) {
      return false;
    }
    // Okay, we got a byte - remember it for the next call to ReadByte.
    _bufferedByte = nextByte & 0xff;
    return true;
  }

  /// Reads a non-negative integer value from the stream.
  ///
  /// The value must have been written by [DateTimeZoneWriter.WriteCount].
  ///
  /// Returns the integer value from the stream.
  @override
  int ReadCount() {
    int unsigned = _ReadVarint();
    if (unsigned > Int64.Int32MaxValue) {
      throw InvalidNodaDataException('Count value greater than Int32.MaxValue');
    }
    return unsigned;
  }

  /// Reads a (possibly-negative) integer value from the stream.
  ///
  /// The value must have been written by [DateTimeZoneWriter.WriteSignedCount].
  ///
  /// Returns the integer value from the stream.
  @override
  int ReadSignedCount() {
    int value = _ReadVarint();
    // Dart: toSigned(32) gives C#'s int result (dart2js's bitwise operators give unsigned 32-bit results).
    return ((value >> 1) ^ -(value & 1)).toSigned(32); // zigzag encoding
  }

  /// Reads a base-128 varint value from the stream.
  ///
  /// The value must have been written by DateTimeZoneWriter.WriteVarint, which
  /// documents the format.
  ///
  /// Returns the integer value from the stream (a C# `uint`).
  int _ReadVarint() {
    // unchecked uint arithmetic. (Dart: masked to 32 bits; C# masks a uint's shift count to 5 bits.)
    int ret = 0;
    int shift = 0;
    while (true) {
      int nextByte = ReadByte();
      ret = (ret + ((nextByte & 0x7f) << (shift & 31))) & 0xffffffff;
      shift += 7;
      if (nextByte < 0x80) {
        return ret;
      }
    }
  }

  /// Reads a number of milliseconds from the stream.
  ///
  /// The value must have been written by [DateTimeZoneWriter.WriteMilliseconds].
  ///
  /// Returns the offset value from the stream.
  @override
  int ReadMilliseconds() {
    // unchecked
    int firstByte = ReadByte();

    int millis;

    if ((firstByte & 0x80) == 0) {
      millis = firstByte * (30 * NodaConstants.MillisecondsPerMinute);
    } else {
      int flag = firstByte & 0xe0; // The flag parts of the first byte
      int firstData = firstByte & 0x1f; // The data parts of the first byte
      switch (flag) {
        case 0x80: // Minutes
          int minutes = (firstData << 8) + ReadByte();
          millis = minutes * NodaConstants.MillisecondsPerMinute;
          break;
        case 0xa0: // Seconds
          int seconds = (firstData << 16) + (_ReadInt16() & 0xffff);
          millis = seconds * NodaConstants.MillisecondsPerSecond;
          break;
        case 0xc0: // Milliseconds
          millis = (firstData << 24) + (ReadByte() << 16) + (_ReadInt16() & 0xffff);
          break;
        default:
          throw InvalidNodaDataException('Invalid flag in offset: ${flag.toRadixString(16).padLeft(2, '0')}');
      }
    }
    millis -= NodaConstants.MillisecondsPerDay;
    return millis;
  }

  /// Reads an offset value from the stream.
  ///
  /// The value must have been written by [DateTimeZoneWriter.WriteOffset].
  ///
  /// Returns the offset value from the stream.
  @override
  Offset ReadOffset() {
    int millis = ReadMilliseconds();
    return Offset.FromMilliseconds(millis);
  }

  /// Reads a string to string dictionary value from the stream.
  ///
  /// The value must have been written by [DateTimeZoneWriter.WriteDictionary].
  ///
  /// Returns the [Map] value from the stream.
  @override
  Map<String, String> ReadDictionary() {
    Map<String, String> results = <String, String>{};
    int count = ReadCount();
    for (int i = 0; i < count; i++) {
      String key = ReadString();
      String value = ReadString();
      // Dart: Dictionary.Add throws ArgumentException for a duplicate key.
      if (results.containsKey(key)) {
        throw ArgumentError('An item with the same key has already been added. Key: $key');
      }
      results[key] = value;
    }
    return results;
  }

  /// Reads an instant representing a zone interval transition from the stream.
  ///
  /// The value must have been written by [DateTimeZoneWriter.WriteZoneIntervalTransition].
  ///
  /// [previous]: The previous transition written (usually for a given timezone), or null if there is
  /// no previous transition.
  ///
  /// Returns the instant read from the stream
  @override
  Instant ReadZoneIntervalTransition(Instant? previous) {
    // unchecked
    int value = ReadCount();
    if (value < DateTimeZoneWriterZoneIntervalConstants.MinValueForHoursSincePrevious) {
      return switch (value) {
        DateTimeZoneWriterZoneIntervalConstants.MarkerMinValue => Instant.BeforeMinValue,
        DateTimeZoneWriterZoneIntervalConstants.MarkerMaxValue => Instant.AfterMaxValue,
        DateTimeZoneWriterZoneIntervalConstants.MarkerRaw => Instant.FromUnixTimeTicks(_ReadInt64()),
        _ => throw InvalidNodaDataException('Unrecognised marker value: $value')
      };
    }
    if (value < DateTimeZoneWriterZoneIntervalConstants.MinValueForMinutesSinceEpoch) {
      if (previous == null) {
        throw InvalidNodaDataException(
            "No previous value, so can't interpret value encoded as delta-since-previous: $value");
      }
      return previous + Duration.FromHours(value);
    }
    return DateTimeZoneWriterZoneIntervalConstants.EpochForMinutesSinceEpoch + Duration.FromMinutes(value);
  }

  /// Reads a string value from the stream.
  ///
  /// The value must have been written by [DateTimeZoneWriter.WriteString].
  ///
  /// Returns the string value from the stream.
  @override
  String ReadString() {
    final stringPool = _stringPool;
    if (stringPool == null) {
      // This will flush the buffered byte if there is one, so we don't need to worry about that
      // when reading the actual data.
      int length = ReadCount();
      var data = Uint8List(length);
      int offset = 0;
      while (offset < length) {
        int bytesRead = _input.Read(data, offset, length - offset);
        if (bytesRead <= 0) {
          throw InvalidNodaDataException('Unexpectedly reached end of data with ${length - offset} bytes still to read');
        }
        offset += bytesRead;
      }
      // Dart: Encoding.UTF8.GetString replaces invalid sequences with U+FFFD, as allowMalformed does.
      return utf8.decode(data, allowMalformed: true);
    } else {
      int index = ReadCount();
      return stringPool[index];
    }
  }

  /// Reads a signed 16 bit integer value from the stream and returns it as an int.
  ///
  /// Returns the 16 bit int value.
  int _ReadInt16() {
    // unchecked
    int high = ReadByte();
    int low = ReadByte();
    return (high << 8) | low;
  }

  /// Reads a signed 32 bit integer value from the stream and returns it as an int.
  ///
  /// Returns the 32 bit int value.
  int _ReadInt32() {
    // unchecked
    int high = _ReadInt16() & 0xffff;
    int low = _ReadInt16() & 0xffff;
    // Dart: toSigned(32) gives C#'s int result (dart2js's bitwise operators give unsigned 32-bit results).
    return ((high << 16) | low).toSigned(32);
  }

  /// Reads a signed 64 bit integer value from the stream and returns it as an long.
  ///
  /// Returns the 64 bit long value.
  int _ReadInt64() {
    // unchecked
    int high = _ReadInt32();
    int low = _ReadInt32() & 0xffffffff;
    // Dart: (high << 32) | low, computed arithmetically so that dart2js (whose bitwise operators are 32-bit) gets it
    // too, exactly while the value is within ±2^53. The result is in the long range, so this never wraps natively.
    return high * 0x100000000 + low;
  }

  /// Reads a signed 8 bit integer value from the stream and returns it as an int.
  ///
  /// Returns the 8 bit int value.
  ///
  /// Throws [InvalidNodaDataException] The data in the stream has been exhausted.
  @override
  int ReadByte() {
    final bufferedByte = _bufferedByte;
    if (bufferedByte != null) {
      int ret = bufferedByte;
      _bufferedByte = null;
      return ret;
    }
    int value = _input.ReadByte();
    if (value == -1) {
      throw InvalidNodaDataException('Unexpected end of data stream');
    }
    return value & 0xff;
  }
}
