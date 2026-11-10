// Ported from NodaTime 6e024dde: src/NodaTime/TimeZones/IO/IDateTimeZoneReader.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import '../../Instant.dart';
import '../../Offset.dart';

/// Interface for reading time-related data from a binary stream.
/// This is similar to `BinaryReader`, but heavily
/// oriented towards our use cases.
@internal
abstract interface class IDateTimeZoneReader {
  /// Returns whether or not there is more data in this stream.
  ///
  /// Returns whether or not there is more data in the stream.
  bool get HasMoreData;

  /// Reads a non-negative integer from the stream, which must have been written
  /// by a call to [IDateTimeZoneWriter.WriteCount].
  ///
  /// Returns the integer read from the stream
  ///
  /// Throws [InvalidNodaDataException] The data was invalid.
  /// Throws [IOException] The stream could not be read.
  int ReadCount();

  /// Reads a non-negative integer from the stream, which must have been written
  /// by a call to [IDateTimeZoneWriter.WriteSignedCount].
  ///
  /// Returns the integer read from the stream
  ///
  /// Throws [InvalidNodaDataException] The data was invalid.
  /// Throws [IOException] The stream could not be read.
  int ReadSignedCount();

  /// Reads a string from the stream.
  ///
  /// Returns the string read from the stream; will not be null
  ///
  /// Throws [InvalidNodaDataException] The data was invalid.
  /// Throws [IOException] The stream could not be read.
  String ReadString();

  /// Reads a signed 8 bit integer value from the stream and returns it as an int.
  ///
  /// Returns the 8 bit int value.
  ///
  /// Throws [InvalidNodaDataException] The data in the stream has been exhausted.
  int ReadByte();

  /// Reads a number of milliseconds from the stream.
  ///
  /// Returns the number of milliseconds read from the stream
  ///
  /// Throws [InvalidNodaDataException] The data was invalid.
  /// Throws [IOException] The stream could not be read.
  int ReadMilliseconds();

  /// Reads an offset from the stream.
  ///
  /// Returns the offset read from the stream
  ///
  /// Throws [InvalidNodaDataException] The data was invalid.
  /// Throws [IOException] The stream could not be read.
  Offset ReadOffset();

  /// Reads an instant representing a zone interval transition from the stream.
  ///
  /// [previous]: The previous transition written (usually for a given timezone), or null if there is
  /// no previous transition.
  ///
  /// Returns the instant read from the stream
  ///
  /// Throws [InvalidNodaDataException] The data was invalid.
  /// Throws [IOException] The stream could not be read.
  Instant ReadZoneIntervalTransition(Instant? previous);

  /// Reads a string-to-string dictionary from the stream.
  ///
  /// Returns the dictionary read from the stream
  ///
  /// Throws [InvalidNodaDataException] The data was invalid.
  /// Throws [IOException] The stream could not be read.
  Map<String, String> ReadDictionary();
}
