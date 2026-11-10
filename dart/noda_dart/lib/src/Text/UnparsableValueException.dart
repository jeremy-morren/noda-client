// Ported from NodaTime 6e024dde: src/NodaTime/Text/UnparsableValueException.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

// noda_dart: extends Dart's FormatException; [source] and [offset] are [Value] and [Index].

/// .NET's default `FormatException` message, used when no message is given.
const String _DefaultFormatMessage = 'One of the identified items was in an invalid format.';

/// Exception thrown to indicate that the specified value could not be parsed.
final class UnparsableValueException extends FormatException {
  /// Creates a new UnparsableValueException with no message, value or index (C#: the parameterless constructor),
  /// with the given message, but no value or index (C#: `UnparsableValueException(string message)`), or with the
  /// given message and base exception, but no value or index (C#: `UnparsableValueException(string message, Exception
  /// innerException)`).
  /// [Value] will be an empty string, and [Index] will have a value of -1.
  ///
  /// [message]: The failure message
  /// [innerException]: The inner exception
  @Deprecated('Use constructors accepting a value')
  UnparsableValueException.MessageInnerException([String? message, this.InnerException])
      : Value = '',
        Index = -1,
        super(message ?? _DefaultFormatMessage);

  /// Creates a new UnparsableValueException with the given message, value and index
  /// at which parsing failed, and optionally the inner exception.
  ///
  /// [message]: The failure message
  /// [source]: The value which could not be parsed (C#: `value`)
  /// [offset]: The index within the value where parsing failed (C#: `index`)
  /// [InnerException]: The inner exception
  UnparsableValueException(super.message, String super.source, int super.offset, [this.InnerException])
      : Value = source,
        Index = offset;

  /// The value which could not be parsed.
  final String Value;

  /// The index within the value where parsing failed.
  /// This will be -1 if parsing failed before examining any text,
  /// for example because parsing was requested on a format-only pattern, or
  /// the value to be parsed was empty.
  final int Index;

  /// noda_dart: .NET's `Exception.InnerException`: the exception that caused this one, if any.
  final Object? InnerException;

  /// noda_dart: the type name and the .NET message, as .NET's `Exception.ToString()` starts.
  @override
  String toString() => 'UnparsableValueException: $message';
}
