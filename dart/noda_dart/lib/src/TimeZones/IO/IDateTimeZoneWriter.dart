// Ported from NodaTime 6e024dde: src/NodaTime/TimeZones/IO/IDateTimeZoneWriter.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import '../../Instant.dart';
import '../../Offset.dart';

/// Interface for writing time-related data to a binary stream.
/// This is similar to `BinaryWriter`, but heavily
/// oriented towards our use cases.
///
/// It is expected that the code reading data written by an implementation
/// will be able to identify which implementation to use. As of Noda Time 2.0,
/// there is only one implementation - but the interface will allow us to
/// evolve the details of the binary structure independently of the code in the
/// time zone implementations which knows how to write/read in terms of this interface
/// and [IDateTimeZoneReader].
@internal
abstract interface class IDateTimeZoneWriter {
  /// Writes a non-negative integer to the stream. This is optimized towards
  /// cases where most values will be small.
  ///
  /// [count]: The integer to write to the stream.
  ///
  /// Throws [IOException] The value couldn't be written to the stream.
  /// Throws [RangeError] [count] is negative.
  void WriteCount(int count);

  /// Writes a possibly-negative integer to the stream. This is optimized for
  /// values of small magnitudes.
  ///
  /// [count]: The integer to write to the stream.
  ///
  /// Throws [IOException] The value couldn't be written to the stream.
  void WriteSignedCount(int count);

  /// Writes a string to the stream.
  ///
  /// Callers can reasonably expect that
  /// these values will be pooled in some fashion, so should not apply their own pooling.
  ///
  /// [value]: The string to write to the stream.
  ///
  /// Throws [IOException] The value couldn't be written to the stream.
  void WriteString(String value);

  /// Writes a number of milliseconds to the stream, where the number
  /// of milliseconds must be in the range (-1 day, +1 day).
  ///
  /// [millis]: The number of milliseconds to write to the stream.
  ///
  /// Throws [IOException] The value couldn't be written to the stream.
  /// Throws [RangeError] [millis] is out of range.
  void WriteMilliseconds(int millis);

  /// Writes an offset to the stream.
  ///
  /// [offset]: The offset to write to the stream.
  ///
  /// Throws [IOException] The value couldn't be written to the stream.
  void WriteOffset(Offset offset);

  /// Writes an instant representing a zone interval transition to the stream.
  ///
  /// This method takes a previously-written transition. Depending on the implementation, this value may be
  /// required by the reader in order to reconstruct the next transition, so it should be deterministic for any
  /// given value.
  ///
  /// [previous]: The previous transition written (usually for a given timezone), or null if there is
  /// no previous transition.
  /// [value]: The transition to write to the stream.
  ///
  /// Throws [IOException] The value couldn't be written to the stream.
  void WriteZoneIntervalTransition(Instant? previous, Instant value);

  /// Writes a string-to-string dictionary to the stream.
  ///
  /// [dictionary]:
  ///
  /// Throws [IOException] The value couldn't be written to the stream.
  void WriteDictionary(Map<String, String> dictionary);

  /// Writes the given 8 bit integer value to the stream.
  ///
  /// [value]: The value to write.
  void WriteByte(int value);
}
