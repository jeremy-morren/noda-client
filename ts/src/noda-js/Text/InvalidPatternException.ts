// Ported from NodaTime 3.3.7: src/NodaTime/Text/InvalidPatternException.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { FormatString } from "../internal.ts";
import { NodaError } from "../internal.ts";
import type { FormatException } from "../internal.ts";

/** FormatException\'s default message (.NET\'s), for the constructor without a message. */
const DefaultFormatMessage = "One of the identified items was in an invalid format.";

// Standard exception constructors.
// This exception is expected to be constructed within the library, and there are never any
// inner exceptions.

/**
 * Exception thrown to indicate that the format pattern provided for either formatting or parsing is invalid.
 */
export class InvalidPatternException extends NodaError<"InvalidPatternException"> {

  /** Creates a new InvalidPatternException with the default FormatException message. */
  constructor();
  /**
   * Creates a new InvalidPatternException with the given message.
   * @param message A message describing the nature of the failure
   */
  constructor(message: string);
  /**
   * Creates a new InvalidPatternException by formatting the given format string with
   * the specified parameters.
   * @param formatString Format string to use in order to create the final message
   * @param parameters Format string parameters
   * @internal
   */
  constructor(formatString: string, ...parameters: unknown[]);
  constructor(message?: string, ...parameters: unknown[]) {
    // noda-js: as C# overload resolution does, format the message only when there are parameters.
    super("InvalidPatternException", message === undefined ? DefaultFormatMessage : parameters.length === 0 ? message : FormatString(message, ...parameters));
  }

  /**
   * Creates a new InvalidPatternException by formatting the given format string with
   * the specified parameters, in the current culture.
   * @param formatString Format string to use in order to create the final message
   * @param parameters Format string parameters
   * @internal
   */
  static NewFormatStringParameters(formatString: string, ...parameters: unknown[]): InvalidPatternException {
    return new InvalidPatternException(formatString, ...parameters);
  }
}
