// noda_dart: port of dotnet/runtime's System/InvalidTimeZoneException.cs.
// Copyright (c) .NET Foundation and Contributors. Licensed under the MIT license (see NOTICE.txt).

/// The exception thrown when time zone information is invalid.
class InvalidTimeZoneException implements Exception {
  /// The message, as .NET gives it.
  final String message;

  /// The exception that caused this one (.NET's InnerException), or null.
  final Object? innerException;

  InvalidTimeZoneException([this.message = 'Exception of type \'System.InvalidTimeZoneException\' was thrown.', this.innerException]);

  @override
  String toString() => 'InvalidTimeZoneException: $message';
}
