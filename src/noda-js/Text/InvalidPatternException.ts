// Ported from NodaTime 3.3.0: src/NodaTime/Text/InvalidPatternException.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { FormatError, FormatString } from "../internal.ts";

// Standard exception constructors.
// This exception is expected to be constructed within the library, and there are never any
// inner exceptions.

/**
 * Exception thrown to indicate that the format pattern provided for either formatting or parsing is invalid.
 */
export class InvalidPatternError extends FormatError {
  override name = "InvalidPatternError";

  /** Creates a new InvalidPatternError with the default FormatError message. */
  constructor();
  /**
   * Creates a new InvalidPatternError with the given message.
   * @param message A message describing the nature of the failure
   */
  constructor(message: string);
  /**
   * Creates a new InvalidPatternError by formatting the given format string with
   * the specified parameters.
   * @param formatString Format string to use in order to create the final message
   * @param parameters Format string parameters
   * @internal
   */
  constructor(formatString: string, ...parameters: unknown[]);
  constructor(message?: string, ...parameters: unknown[]) {
    // noda-js: C# overload resolution picks the (string message) constructor when there are no parameters,
    // so the message is only formatted when parameters are given.
    super(message === undefined ? undefined : parameters.length === 0 ? message : FormatString(message, ...parameters));
  }

  /**
   * Creates a new InvalidPatternError by formatting the given format string with
   * the specified parameters, in the current culture.
   * @param formatString Format string to use in order to create the final message
   * @param parameters Format string parameters
   * @internal
   */
  static NewFormatStringParameters(formatString: string, ...parameters: unknown[]): InvalidPatternError {
    return new InvalidPatternError(formatString, ...parameters);
  }
}
