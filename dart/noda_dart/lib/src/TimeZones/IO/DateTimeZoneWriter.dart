// Ported from NodaTime 6e024dde: src/NodaTime/TimeZones/IO/DateTimeZoneWriter.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'dart:convert';
import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../../Instant.dart';
import '../../NodaConstants.dart';
import '../../Offset.dart';
import '../../Utility/Int64.dart';
import '../../Utility/Preconditions.dart';
import '../../Utility/Stream.dart';
import 'IDateTimeZoneWriter.dart';

// Nested enum DateTimeZoneWriter.DateTimeZoneType: generated, as DateTimeZoneWriterDateTimeZoneType
// (DateTimeZoneWriter.DateTimeZoneType.generated.dart).

/// NodaTime's nested `DateTimeZoneWriter.ZoneIntervalConstants` static class.
@internal
abstract final class DateTimeZoneWriterZoneIntervalConstants {
  /// The instant to use as an 'epoch' when writing out a number of minutes-since-epoch.
  static final Instant EpochForMinutesSinceEpoch = Instant.FromUtc(1800, 1, 1, 0, 0);

  /// The marker value representing the beginning of time.
  static const int MarkerMinValue = 0;

  /// The marker value representing the end of time.
  static const int MarkerMaxValue = 1;

  /// The marker value representing an instant as a fixed 64-bit number of ticks.
  static const int MarkerRaw = 2;

  /// The minimum varint value that represents an number of hours-since-previous.
  ///
  /// Values below this are reserved for markers.
  static const int MinValueForHoursSincePrevious = 1 << 7;

  /// The minimum varint value that represents an number of minutes since an epoch.
  ///
  /// Values below this are interpreted as hours-since-previous (for a range of about 240 years),
  /// rather than minutes-since-epoch (for a range of about 4000 years)
  /// This choice is somewhat arbitrary, though it results in hour values always taking 2 (or
  /// occasionally 3) bytes when encoded as a varint, while minute values take 4 (or conceivably 5).
  static const int MinValueForMinutesSinceEpoch = 1 << 21;
}

/// Implementation of [IDateTimeZoneWriter] for the most recent version
/// of the "blob" format of time zone data. If the format changes, this class will be
/// renamed (e.g. to DateTimeZoneWriterV0) and the new implementation will replace it.
@internal
final class DateTimeZoneWriter implements IDateTimeZoneWriter {
  final Stream _output;
  final List<String>? _stringPool;

  /// Constructs a DateTimeZoneWriter.
  ///
  /// [output]: Where to send the serialized output.
  /// [stringPool]: String pool to add strings to, or null for no pool
  @internal
  DateTimeZoneWriter.NewOutputStringPool(Stream output, List<String>? stringPool)
      : _output = output,
        _stringPool = stringPool;

  /// Writes the given non-negative integer value to the stream.
  ///
  /// [value]: The value to write.
  @override
  void WriteCount(int value) {
    Preconditions.CheckArgumentRange('value', value, 0, Int64.Int32MaxValue);
    _WriteVarint(value);
  }

  /// Writes the given (possibly-negative) integer value to the stream.
  ///
  /// Unlike [WriteCount], this can encode negative numbers. It does, however, use a slightly less
  /// efficient encoding for positive numbers.
  ///
  /// [count]: The value to write.
  @override
  void WriteSignedCount(int count) {
    // unchecked
    // Dart: (uint) of the 32-bit result.
    _WriteVarint(((count >> 31) ^ (count << 1)) & 0xffffffff); // zigzag encoding
  }

  /// Writes the given integer value to the stream as a base-128 varint.
  ///
  /// The format is a simple 7-bit encoding: while the value is greater than 127 (i.e.
  /// has more than 7 significant bits) we repeatedly write the least-significant 7 bits
  /// with the top bit of the byte set as a continuation bit, then shift the value right
  /// 7 bits.
  ///
  /// [value]: The value to write (a C# `uint`).
  void _WriteVarint(int value) {
    // unchecked
    while (value > 0x7f) {
      _output.WriteByte(0x80 | (value & 0x7f));
      value = value >> 7;
    }
    _output.WriteByte(value & 0x7f);
  }

  @override
  void WriteMilliseconds(int millis) {
    Preconditions.CheckArgumentRange('millis', millis,
        -NodaConstants.MillisecondsPerDay + 1,
        NodaConstants.MillisecondsPerDay - 1);
    millis += NodaConstants.MillisecondsPerDay;
    /*
     * First, add 24 hours to the number of milliseconds, to get a value in the range (0, 172800000).
     * (It's exclusive at both ends, but that's insignificant.)
     * Check whether it's an exact multiple of half-hours or minutes, and encode
     * appropriately. In every case, if it's an exact multiple, we know that we'll be able to fit
     * the value into the number of bits available.
     *
     * first byte      units       max data value (+1)   field length
     * --------------------------------------------------------------
     * 0xxxxxxx        30 minutes  96                    1 byte  (7 data bits)
     * 100xxxxx        minutes     2880                  2 bytes (14 data bits)
     * 101xxxxx        seconds     172800                3 bytes (21 data bits)
     * 110xxxxx        millis      172800000             4 bytes (29 data bits)
     */
    // unchecked
    if (millis.remainder(30 * NodaConstants.MillisecondsPerMinute) == 0) {
      int units = millis ~/ (30 * NodaConstants.MillisecondsPerMinute);
      WriteByte(units & 0xff);
    } else if (millis.remainder(NodaConstants.MillisecondsPerMinute) == 0) {
      int minutes = millis ~/ NodaConstants.MillisecondsPerMinute;
      WriteByte((0x80 | (minutes >> 8)) & 0xff);
      WriteByte(minutes & 0xff);
    } else if (millis.remainder(NodaConstants.MillisecondsPerSecond) == 0) {
      int seconds = millis ~/ NodaConstants.MillisecondsPerSecond;
      WriteByte((0xa0 | ((seconds >> 16) & 0xff)) & 0xff);
      _WriteInt16((seconds & 0xffff).toSigned(16));
    } else {
      _WriteInt32((0xc0000000 | millis).toSigned(32));
    }
  }

  /// Writes the offset value to the stream.
  ///
  /// [offset]: The value to write.
  @override
  void WriteOffset(Offset offset) {
    WriteMilliseconds(offset.Milliseconds);
  }

  /// Writes the given dictionary of string to string to the stream.
  ///
  /// [dictionary]: The [Map] to write.
  @override
  void WriteDictionary(Map<String, String> dictionary) {
    // Dart: null safety checks dictionary.
    WriteCount(dictionary.length);
    for (var entry in dictionary.entries) {
      WriteString(entry.key);
      WriteString(entry.value);
    }
  }

  @override
  void WriteZoneIntervalTransition(Instant? previous, Instant value) {
    if (previous != null) {
      Preconditions.CheckArgument(value >= previous, 'value', 'Transition must move forward in time');
    }

    // unchecked
    if (value == Instant.BeforeMinValue) {
      WriteCount(DateTimeZoneWriterZoneIntervalConstants.MarkerMinValue);
      return;
    }
    if (value == Instant.AfterMaxValue) {
      WriteCount(DateTimeZoneWriterZoneIntervalConstants.MarkerMaxValue);
      return;
    }

    // In practice, most zone interval transitions will occur within 4000-6000 hours of the previous one
    // (i.e. about 5-8 months), and at an integral number of hours difference. We therefore gain a
    // significant reduction in output size by encoding transitions as the whole number of hours since the
    // previous, if possible.
    // If the previous value was "the start of time" then there's no point in trying to use it.
    if (previous != null && previous != Instant.BeforeMinValue) {
      // Note that the difference might exceed the range of a long, so we can't use a Duration here.
      // (Dart: the difference is non-negative, and within the range of a long for any two valid instants, so the
      // ulong arithmetic is plain int arithmetic.)
      int ticks = value.ToUnixTimeTicks() - previous.ToUnixTimeTicks();
      if (ticks % NodaConstants.TicksPerHour == 0) {
        int hours = ticks ~/ NodaConstants.TicksPerHour;
        // As noted above, this will generally fall within the 4000-6000 range, although values up to
        // ~700,000 exist in TZDB.
        if (DateTimeZoneWriterZoneIntervalConstants.MinValueForHoursSincePrevious <= hours &&
            hours < DateTimeZoneWriterZoneIntervalConstants.MinValueForMinutesSinceEpoch) {
          WriteCount(hours);
          return;
        }
      }
    }

    // We can't write the transition out relative to the previous transition, so let's next try writing it
    // out as a whole number of minutes since an (arbitrary, known) epoch.
    if (value >= DateTimeZoneWriterZoneIntervalConstants.EpochForMinutesSinceEpoch) {
      int ticks = value.ToUnixTimeTicks() - DateTimeZoneWriterZoneIntervalConstants.EpochForMinutesSinceEpoch.ToUnixTimeTicks();
      if (ticks % NodaConstants.TicksPerMinute == 0) {
        int minutes = ticks ~/ NodaConstants.TicksPerMinute;
        // We typically have a count on the order of 80M here.
        if (DateTimeZoneWriterZoneIntervalConstants.MinValueForMinutesSinceEpoch < minutes && minutes <= Int64.Int32MaxValue) {
          WriteCount(minutes);
          return;
        }
      }
    }
    // Otherwise, just write out a marker followed by the instant as a 64-bit number of ticks.  Note that
    // while most of the values we write here are actually whole numbers of _seconds_, optimising for that
    // case will save around 2KB (with tzdb 2012j), so doesn't seem worthwhile.
    WriteCount(DateTimeZoneWriterZoneIntervalConstants.MarkerRaw);
    _WriteInt64(value.ToUnixTimeTicks());
  }

  /// Writes the string value to the stream.
  ///
  /// [value]: The value to write.
  @override
  void WriteString(String value) {
    final stringPool = _stringPool;
    if (stringPool == null) {
      Uint8List data = utf8.encode(value);
      int length = data.length;
      WriteCount(length);
      _output.Write(data, 0, data.length);
    } else {
      int index = stringPool.indexOf(value);
      if (index == -1) {
        index = stringPool.length;
        stringPool.add(value);
      }
      WriteCount(index);
    }
  }

  /// Writes the given 16 bit integer value to the stream.
  ///
  /// [value]: The value to write.
  void _WriteInt16(int value) {
    // unchecked
    WriteByte((value >> 8) & 0xff);
    WriteByte(value & 0xff);
  }

  /// Writes the given 32 bit integer value to the stream.
  ///
  /// [value]: The value to write.
  void _WriteInt32(int value) {
    // unchecked
    _WriteInt16(value >> 16);
    _WriteInt16(value);
  }

  /// Writes the given 64 bit integer value to the stream.
  ///
  /// [value]: The value to write.
  void _WriteInt64(int value) {
    // unchecked
    // Dart: (int) (value >> 32) and (int) value, computed arithmetically so that dart2js (whose bitwise operators are
    // 32-bit) gets them too, exactly while the value is within ±2^53. (Dart's % is Euclidean: low is in [0, 2^32).)
    int low = value % 0x100000000;
    int high = (value - low) ~/ 0x100000000;
    _WriteInt32(high);
    _WriteInt32(low);
  }

  /// Writes the given 8 bit integer value to the stream.
  @override
  void WriteByte(int value) {
    // unchecked
    _output.WriteByte(value);
  }
}
