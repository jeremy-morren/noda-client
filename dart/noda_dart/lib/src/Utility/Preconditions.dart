// Ported from NodaTime 6e024dde: src/NodaTime/Utility/Preconditions.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import 'StringFormat.dart';

/// noda_dart: whether the Debug* checks run (NodaTime compiles them out of release builds).
const bool _DebugChecksEnabled = false;

/// noda_dart: marks a [Preconditions.CheckArgument] call without message arguments (C#'s other overload).
const Object _NoMessageArgument = Object();

/// Helper static methods for argument/state validation.
@internal
abstract final class Preconditions {
  /// Returns the given argument after checking whether it's null. This is useful for putting
  /// nullity checks in parameters which are passed to base class constructors.
  static T CheckNotNull<T extends Object>(T? argument, String paramName) {
    if (argument == null) {
      throw ArgumentError.notNull(paramName);
    }
    return argument;
  }

  /// Like [CheckNotNull], but only checked in debug builds. (This means it can't return anything...)
  static void DebugCheckNotNull<T extends Object>(T? argument, String paramName) {
    if (_DebugChecksEnabled) {
      if (argument == null) {
        throw DebugPreconditionException.NewMessage('$paramName is null');
      }
    }
  }

  // Note: this overload exists for performance reasons. It would be reasonable to call the
  // version using "long" values, but we'd incur conversions on every call. This method
  // may well be called very often.
  // (noda_dart: C#'s int and long overloads are this one: both are Dart's int.)
  static void CheckArgumentRange(String paramName, int value, int minInclusive, int maxInclusive) {
    if (value < minInclusive || value > maxInclusive) {
      _ThrowArgumentOutOfRangeException(paramName, value, minInclusive, maxInclusive);
    }
  }

  /// C#'s `CheckArgumentRange(string, double, double, double)`.
  static void CheckArgumentRangeDouble(String paramName, double value, double minInclusive, double maxInclusive) {
    if (value < minInclusive || value > maxInclusive || value.isNaN) {
      _ThrowArgumentOutOfRangeException(paramName, value, minInclusive, maxInclusive);
    }
  }

  static Never _ThrowArgumentOutOfRangeException<T>(String paramName, T value, T minInclusive, T maxInclusive) {
    throw _NewArgumentOutOfRangeException(paramName, value,
        'Value should be in range [${StringFormat.FormatValue(minInclusive)}-${StringFormat.FormatValue(maxInclusive)}]');
  }

  // This method exists for cases where we know we want to throw an exception, but we need the compiler to think it
  // *could* return something. (Typically switch expressions.)
  static T ThrowArgumentOutOfRangeExceptionWithReturn<T>(String paramName, T value, T minInclusive, T maxInclusive) {
    throw _NewArgumentOutOfRangeException(paramName, value,
        'Value should be in range [${StringFormat.FormatValue(minInclusive)}-${StringFormat.FormatValue(maxInclusive)}]');
  }

  /// Range change to perform just within debug builds. This is typically for internal sanity checking, where we normally
  /// trusting the argument value to be valid, and adding a check just for the sake of documentation - and to help find
  /// internal bugs during development.
  ///
  /// (noda_dart: C#'s int and long overloads are this one: both are Dart's int.)
  static void DebugCheckArgumentRange(String paramName, int value, int minInclusive, int maxInclusive) {
    if (_DebugChecksEnabled) {
      if (value < minInclusive || value > maxInclusive) {
        throw DebugPreconditionException.NewMessage('Value $value for $paramName is out of range [$minInclusive-$maxInclusive]');
      }
    }
  }

  /// C#'s `params object[] messageArgs` is a list.
  static void DebugCheckArgument(bool expression, String parameter, String messageFormat,
      [List<Object?> messageArgs = const []]) {
    if (_DebugChecksEnabled) {
      if (!expression) {
        // (C# formats with the current culture; noda_dart with the invariant culture.)
        String message = StringFormat.Format(messageFormat, messageArgs);
        throw DebugPreconditionException.NewMessage('$message (parameter name: $parameter)');
      }
    }
  }

  /// NodaTime's three CheckArgument overloads (no message arguments, one, or two). Without message arguments,
  /// [messageFormat] is the message itself; otherwise it's formatted with them, as `string.Format` would.
  static void CheckArgument(bool expression, String parameter, String messageFormat,
      [Object? messageArg1 = _NoMessageArgument, Object? messageArg2 = _NoMessageArgument]) {
    if (!expression) {
      // (C# formats with the current culture; noda_dart with the invariant culture.)
      String message = identical(messageArg1, _NoMessageArgument)
          ? messageFormat
          : StringFormat.Format(messageFormat,
              identical(messageArg2, _NoMessageArgument) ? [messageArg1] : [messageArg1, messageArg2]);
      throw ArgumentError(message, parameter);
    }
  }

  static void CheckState(bool expression, String message) {
    if (!expression) {
      throw StateError(message);
    }
  }

  static void DebugCheckState(bool expression, String message) {
    if (_DebugChecksEnabled) {
      if (!expression) {
        throw DebugPreconditionException.NewMessage(message);
      }
    }
  }

  /// noda_dart: C#'s `new ArgumentOutOfRangeException(paramName, value, message)`.
  static RangeError _NewArgumentOutOfRangeException(String paramName, Object? value, String message) =>
      value is num ? RangeError.value(value, paramName, message) : RangeError('$message (Parameter \'$paramName\')');
}

/// Exception which occurs only for preconditions violated in debug mode. This is
/// thrown from the Preconditions.Debug* methods to avoid them throwing exceptions
/// which might cause tests to pass. The type doesn't even exist in non-debug configurations,
/// so even though the Preconditions.Debug* methods *do* exist, they can't actually do anything.
/// That's fine, as Preconditions is an internal class; we don't expect to be building
/// an assembly which might use this in debug configuration against a non-debug Noda Time or vice versa.
@internal
@visibleForTesting
final class DebugPreconditionException implements Exception {
  /// The message.
  final String message;

  DebugPreconditionException.NewMessage(this.message);

  @override
  String toString() => 'DebugPreconditionException: $message';
}
