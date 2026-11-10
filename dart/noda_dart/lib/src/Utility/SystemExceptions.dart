// noda_dart: new code. The .NET exceptions NodaTime throws that Dart has no type for.

/// .NET's `ArithmeticException`: the base of [OverflowException] and [DivideByZeroException].
class ArithmeticException implements Exception {
  final String message;

  ArithmeticException([this.message = 'Overflow or underflow in the arithmetic operation.']);

  @override
  String toString() => '$runtimeType: $message';
}

/// .NET's `OverflowException`.
class OverflowException extends ArithmeticException {
  OverflowException([super.message = 'Arithmetic operation resulted in an overflow.']);
}

/// .NET's `DivideByZeroException`.
class DivideByZeroException extends ArithmeticException {
  DivideByZeroException([super.message = 'Attempted to divide by zero.']);
}

/// .NET's `IOException` (`dart:io`'s isn't available on the web).
class IOException implements Exception {
  final String message;

  IOException([this.message = 'I/O error occurred.']);

  @override
  String toString() => '$runtimeType: $message';
}

/// .NET's `EndOfStreamException`.
class EndOfStreamException extends IOException {
  EndOfStreamException([super.message = 'Unable to read beyond the end of the stream.']);
}

/// .NET's `InvalidDataException` (System.IO.Compression's, thrown for corrupt compressed data).
class InvalidDataException implements Exception {
  final String message;

  InvalidDataException([this.message = 'Found invalid data while decoding.']);

  @override
  String toString() => '$runtimeType: $message';
}
