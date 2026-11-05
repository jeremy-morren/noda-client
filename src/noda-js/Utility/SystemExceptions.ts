// noda-js: JavaScript equivalents of the .NET exception types that NodaTime throws.
// See docs/porting-conventions.md ("Exceptions").

/** Equivalent of System.ArgumentException. */
export class ArgumentError extends TypeError {
  override name = "ArgumentError";
  readonly ParamName: string | null;
  constructor(message?: string, paramName?: string | null, options?: { cause?: unknown }) {
    super(message ?? "Value does not fall within the expected range.", options);
    this.ParamName = paramName ?? null;
  }
}

/** Equivalent of System.ArgumentNullException. */
export class ArgumentNullError extends ArgumentError {
  override name = "ArgumentNullError";
  constructor(paramName?: string | null, message?: string) {
    super(message ?? "Value cannot be null.", paramName);
  }
}

/** Equivalent of System.ArgumentOutOfRangeException. */
export class ArgumentOutOfRangeError extends RangeError {
  override name = "ArgumentOutOfRangeError";
  readonly ParamName: string | null;
  readonly ActualValue: unknown;
  constructor(paramName?: string | null, actualValue?: unknown, message?: string) {
    super(message ?? "Specified argument was out of the range of valid values.");
    this.ParamName = paramName ?? null;
    this.ActualValue = actualValue;
  }
}

/** Equivalent of System.InvalidOperationException. */
export class InvalidOperationError extends Error {
  override name = "InvalidOperationError";
  constructor(message?: string, options?: { cause?: unknown }) {
    super(message ?? "Operation is not valid due to the current state of the object.", options);
  }
}

/** Equivalent of System.OverflowException. */
export class OverflowError extends RangeError {
  override name = "OverflowError";
  constructor(message?: string) {
    super(message ?? "Arithmetic operation resulted in an overflow.");
  }
}

/** Equivalent of System.NotSupportedException. */
export class NotSupportedError extends Error {
  override name = "NotSupportedError";
  constructor(message?: string) {
    super(message ?? "Specified method is not supported.");
  }
}

/** Equivalent of System.FormatException. */
export class FormatError extends Error {
  override name = "FormatError";
  constructor(message?: string) {
    super(message ?? "One of the identified items was in an invalid format.");
  }
}

/** Equivalent of System.Collections.Generic.KeyNotFoundException. */
export class KeyNotFoundError extends Error {
  override name = "KeyNotFoundError";
  constructor(message?: string) {
    super(message ?? "The given key was not present in the dictionary.");
  }
}
