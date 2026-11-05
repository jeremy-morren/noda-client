// Ported from NodaTime 3.3.7: src/NodaTime/Utility/Preconditions.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { FormatString } from "./StringFormat.ts";
import { Int64 } from "./Numbers.ts";
import type { Int64Value } from "./Numbers.ts";
import { NodaError } from "./NodaError.ts";
import { NewArgumentException, NewArgumentNullException, NewArgumentOutOfRangeException, NewInvalidOperationException } from "../internal.ts";

/**
 * Whether the Debug* checks run. NodaTime compiles them out of release builds
 * ([Conditional("DEBUG")]); we keep the calls and switch them off.
 */
const DebugChecksEnabled: boolean = false;

/** Whether value < minInclusive or value > maxInclusive, comparing numbers and Longs exactly. */
function OutOfRange(value: Int64Value, minInclusive: Int64Value, maxInclusive: Int64Value): boolean {
  if (typeof value === "number" && typeof minInclusive === "number" && typeof maxInclusive === "number") {
    return value < minInclusive || value > maxInclusive;
  }
  return Int64.Compare(value, minInclusive) < 0 || Int64.Compare(value, maxInclusive) > 0;
}

/**
 * Helper static methods for argument/state validation.
 * @internal
 */
export class Preconditions {
  private constructor() {}

  /**
   * Returns the given argument after checking whether it's null. This is useful for putting
   * nullity checks in parameters which are passed to base class constructors.
   */
  static CheckNotNull<T>(argument: T | null | undefined, paramName: string): T {
    if (argument === null || argument === undefined) {
      throw NewArgumentNullException(paramName);
    }
    return argument;
  }

  /**
   * Like {@link CheckNotNull}, but only checked in debug builds. (This means it can't return anything...)
   */
  static DebugCheckNotNull<T>(argument: T | null | undefined, paramName: string): void {
    if (DebugChecksEnabled && (argument === null || argument === undefined)) {
      throw new DebugPreconditionException(`${paramName} is null`);
    }
  }

  // Note: NodaTime has int, long and double overloads of this method; one implementation covers them all.
  // (noda-js: a C# long beyond 2^53 is an exact Int64Value; see Utility/Numbers.ts.)
  static CheckArgumentRange(paramName: string, value: Int64Value, minInclusive: Int64Value, maxInclusive: Int64Value): void {
    if (OutOfRange(value, minInclusive, maxInclusive) || (typeof value === "number" && Number.isNaN(value))) {
      Preconditions.ThrowArgumentOutOfRangeException(paramName, value, minInclusive, maxInclusive);
    }
  }

  private static ThrowArgumentOutOfRangeException(paramName: string, value: unknown, minInclusive: unknown, maxInclusive: unknown): never {
    throw NewArgumentOutOfRangeException(paramName, value, `Value should be in range [${minInclusive}-${maxInclusive}]`);
  }

  // This method exists for cases where we know we want to throw an exception, but we need the compiler to think it
  // *could* return something. (Typically switch expressions.)
  static ThrowArgumentOutOfRangeExceptionWithReturn<T>(paramName: string, value: T, minInclusive: T, maxInclusive: T): never {
    throw NewArgumentOutOfRangeException(paramName, value, `Value should be in range [${minInclusive}-${maxInclusive}]`);
  }

  /**
   * Range change to perform just within debug builds. This is typically for internal sanity checking, where we normally
   * trusting the argument value to be valid, and adding a check just for the sake of documentation - and to help find
   * internal bugs during development.
   */
  static DebugCheckArgumentRange(paramName: string, value: Int64Value, minInclusive: Int64Value, maxInclusive: Int64Value): void {
    if (DebugChecksEnabled && OutOfRange(value, minInclusive, maxInclusive)) {
      throw new DebugPreconditionException(`Value ${value} for ${paramName} is out of range [${minInclusive}-${maxInclusive}]`);
    }
  }

  static DebugCheckArgument(expression: boolean, parameter: string, messageFormat: string, ...messageArgs: unknown[]): void {
    if (DebugChecksEnabled && !expression) {
      const message = FormatString(messageFormat, ...messageArgs);
      throw new DebugPreconditionException(`${message} (parameter name: ${parameter})`);
    }
  }

  // Note: NodaTime has overloads taking zero, one or two message arguments; one implementation covers them all.
  static CheckArgument(expression: boolean, parameter: string, messageFormat: string, ...messageArgs: unknown[]): void {
    if (!expression) {
      const message = messageArgs.length === 0 ? messageFormat : FormatString(messageFormat, ...messageArgs);
      throw NewArgumentException(message, parameter);
    }
  }

  static CheckState(expression: boolean, message: string): void {
    if (!expression) {
      throw NewInvalidOperationException(message);
    }
  }

  static DebugCheckState(expression: boolean, message: string): void {
    if (DebugChecksEnabled && !expression) {
      throw new DebugPreconditionException(message);
    }
  }
}

/**
 * Exception which occurs only for preconditions violated in debug mode. This is
 * thrown from the Preconditions.Debug* methods to avoid them throwing exceptions
 * which might cause tests to pass.
 * @internal
 */
export class DebugPreconditionException extends NodaError<"DebugPreconditionException"> {
  constructor(message: string) {
    super("DebugPreconditionException", message);
  }
}
