// Ported from NodaTime 3.3.7: src/NodaTime/Text/UnparsableValueException.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { NodaError } from "../internal.ts";
import type { FormatException } from "../internal.ts";

/** FormatException\'s default message (.NET\'s), for the constructor without a message. */
const DefaultFormatMessage = "One of the identified items was in an invalid format.";

/**
 * Exception thrown to indicate that the specified value could not be parsed.
 */
export class UnparsableValueException extends NodaError<"UnparsableValueException"> {

  private readonly _value: string;

  /** The value which could not be parsed. */
  get Value(): string {
    return this._value;
  }

  private readonly _index: number;

  /**
   * The index within the value where parsing failed.
   * This will be -1 if parsing failed before examining any text,
   * for example because parsing was requested on a format-only pattern, or
   * the value to be parsed was empty.
   */
  get Index(): number {
    return this._index;
  }

  /**
   * Creates a new UnparsableValueException with no message, value or index.
   * {@link Value} will be an empty string, and {@link Index} will have a value of -1.
   * @deprecated Use constructors accepting a value
   */
  constructor();
  /**
   * Creates a new UnparsableValueException with the given message, but no value or index.
   * {@link Value} will be an empty string, and {@link Index} will have a value of -1.
   * @param message The failure message
   * @deprecated Use constructors accepting a value
   */
  constructor(message: string);
  /**
   * Creates a new UnparsableValueException with the given message and base exception, but no value or index.
   * {@link Value} will be an empty string, and {@link Index} will have a value of -1.
   * @param message The failure message
   * @param innerException The inner exception
   * @deprecated Use constructors accepting a value
   */
  constructor(message: string, innerException: unknown);
  /**
   * Creates a new UnparsableValueException with the given message, value and index
   * at which parsing failed.
   * @param message The failure message
   * @param value The value which could not be parsed
   * @param index The index within the value where parsing failed
   */
  constructor(message: string, value: string, index: number);
  /**
   * Creates a new UnparsableValueException with the given message, value, index and inner exception.
   * @param message The failure message
   * @param value The value which could not be parsed
   * @param index The index within the value where parsing failed
   * @param innerException The inner exception
   */
  constructor(message: string, value: string, index: number, innerException: unknown);
  constructor(...args: unknown[]) {
    super("UnparsableValueException", (args[0] as string | undefined) ?? DefaultFormatMessage);
    if (args.length >= 3) {
      this._value = args[1] as string;
      this._index = args[2] as number;
      if (args.length >= 4) {
        this.cause = args[3];
      }
    } else {
      this._value = "";
      this._index = -1;
      if (args.length === 2) {
        this.cause = args[1];
      }
    }
  }
}
