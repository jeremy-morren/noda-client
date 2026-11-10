// Ported from NodaTime 6e024dde: src/NodaTime/TimeZones/InvalidDateTimeZoneSourceException.cs
// Copyright 2012 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

// Standard exception constructors.
// This exception is expected to be constructed within the library.
// There are never any inner exceptions, and we always *do* have a message.

/// Exception thrown to indicate that a time zone source has violated the contract of [IDateTimeZoneSource].
/// This exception is primarily intended to be thrown from [DateTimeZoneCache], and only in the face of a buggy
/// source; user code should not usually need to be aware of this or catch it.
// Exception itself is mutable
final class InvalidDateTimeZoneSourceException implements Exception {
  /// The message for the exception.
  final String message;

  /// Creates a new instance with the given message.
  ///
  /// [message]: The message for the exception.
  InvalidDateTimeZoneSourceException(this.message);

  @override
  String toString() => 'InvalidDateTimeZoneSourceException: $message';
}
