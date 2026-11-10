// Ported from NodaTime 6e024dde: src/NodaTime/TimeZones/DateTimeZoneNotFoundException.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

// Standard exception constructors.
// This exception is expected to be constructed within the library.
// There are never any inner exceptions, and we always *do* have a message.

/// Exception thrown when time zone is requested from an [IDateTimeZoneProvider],
/// but the specified ID is invalid for that provider.
///
/// This type originally existed as `TimeZoneNotFoundException` doesn't exist in framework versions
/// targeted by earlier versions of Noda Time. It is present now solely to avoid unnecessary
/// backward incompatibility. While it could be used to distinguish between exceptions thrown by
/// Noda Time and those thrown by `TimeZoneInfo`, we recommend that you don't use it that way.
///
/// noda_dart: implements [Exception] (Dart has no `TimeZoneNotFoundException` base).
// Exception itself is mutable
final class DateTimeZoneNotFoundException implements Exception {
  /// The message for the exception.
  final String message;

  /// Creates an instance with the given message.
  ///
  /// [message]: The message for the exception.
  DateTimeZoneNotFoundException(this.message);

  @override
  String toString() => 'DateTimeZoneNotFoundException: $message';
}
