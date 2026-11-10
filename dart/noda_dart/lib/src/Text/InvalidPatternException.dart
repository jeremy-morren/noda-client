// Ported from NodaTime 6e024dde: src/NodaTime/Text/InvalidPatternException.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import '../Utility/StringFormat.dart';

// Standard exception constructors.
// This exception is expected to be constructed within the library, and there are never any
// inner exceptions.

/// .NET's default `FormatException` message, used when no message is given.
const String _DefaultFormatMessage = 'One of the identified items was in an invalid format.';

/// Exception thrown to indicate that the format pattern provided for either formatting or parsing is invalid.
final class InvalidPatternException extends FormatException {
  /// Creates a new InvalidPatternException with the default FormatException message (C#: the parameterless
  /// constructor), or with the given message.
  ///
  /// [message]: A message describing the nature of the failure
  InvalidPatternException([String? message]) : super(message ?? _DefaultFormatMessage);

  /// Creates a new InvalidPatternException by formatting the given format string with
  /// the specified parameters, in the current culture.
  ///
  /// [formatString]: Format string to use in order to create the final message
  /// [parameters]: Format string parameters
  @internal
  InvalidPatternException.NewFormatStringParameters(String formatString, List<Object?> parameters)
      : this(StringFormat.Format(formatString, parameters));

  /// noda_dart: the type name and the .NET message, as .NET's `Exception.ToString()` starts.
  @override
  String toString() => 'InvalidPatternException: $message';
}
