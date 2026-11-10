// Ported from NodaTime 6e024dde: src/NodaTime/Utility/InvalidNodaDataException.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

// Standard exception constructors.
// This exception is expected to be constructed within the library.
// We always have a message, and we don't want to accidentally be able
// to construct an instance of this exception without a message.

/// Exception thrown when data read by Noda Time (such as serialized time zone data) is invalid. This includes
/// data which is truncated, i.e. we expect more data than we can read.
///
/// This type only exists as `InvalidDataException` didn't exist in Portable Class Libraries.
/// That does exist in netstandard1.3, but as we shipped 2.0 without realizing this, we're stuck with the
/// new exception type.
/// Unfortunately, `InvalidDataException` itself is sealed, so we can't derive from it for the sake
/// of backward compatibility.
final class InvalidNodaDataException implements Exception {
  /// The message for the exception.
  final String message;

  /// Underlying cause of the error, if any.
  final Object? innerException;

  /// Creates an instance with the given message, and optionally the underlying cause.
  ///
  /// [message]: The message for the exception.
  /// [innerException]: Underlying cause of the error.
  InvalidNodaDataException(this.message, [this.innerException]);

  @override
  String toString() => 'InvalidNodaDataException: $message';
}
