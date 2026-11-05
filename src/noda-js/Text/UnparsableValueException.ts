// Ported from NodaTime 3.3.0: src/NodaTime/Text/UnparsableValueException.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { FormatError } from "../internal.ts";

/**
 * Exception thrown to indicate that the specified value could not be parsed.
 */
export class UnparsableValueError extends FormatError {
  override name = "UnparsableValueError";

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
   * Creates a new UnparsableValueError with no message, value or index.
   * {@link Value} will be an empty string, and {@link Index} will have a value of -1.
   * @deprecated Use constructors accepting a value
   */
  constructor();
  /**
   * Creates a new UnparsableValueError with the given message, but no value or index.
   * {@link Value} will be an empty string, and {@link Index} will have a value of -1.
   * @param message The failure message
   * @deprecated Use constructors accepting a value
   */
  constructor(message: string);
  /**
   * Creates a new UnparsableValueError with the given message and base exception, but no value or index.
   * {@link Value} will be an empty string, and {@link Index} will have a value of -1.
   * @param message The failure message
   * @param innerException The inner exception
   * @deprecated Use constructors accepting a value
   */
  constructor(message: string, innerException: unknown);
  /**
   * Creates a new UnparsableValueError with the given message, value and index
   * at which parsing failed.
   * @param message The failure message
   * @param value The value which could not be parsed
   * @param index The index within the value where parsing failed
   */
  constructor(message: string, value: string, index: number);
  /**
   * Creates a new UnparsableValueError with the given message, value, index and inner exception.
   * @param message The failure message
   * @param value The value which could not be parsed
   * @param index The index within the value where parsing failed
   * @param innerException The inner exception
   */
  constructor(message: string, value: string, index: number, innerException: unknown);
  constructor(...args: unknown[]) {
    super(args[0] as string | undefined);
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
