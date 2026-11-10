// noda_dart: port of dotnet/runtime's System/TimeZoneNotFoundException.cs.
// Copyright (c) .NET Foundation and Contributors. Licensed under the MIT license (see NOTICE.txt).

/// The exception thrown when a time zone cannot be found.
class TimeZoneNotFoundException implements Exception {
  /// The message, as .NET gives it.
  final String message;

  /// The exception that caused this one (.NET's InnerException), or null.
  final Object? innerException;

  TimeZoneNotFoundException([this.message = 'Exception of type \'System.TimeZoneNotFoundException\' was thrown.', this.innerException]);

  @override
  String toString() => 'TimeZoneNotFoundException: $message';
}
