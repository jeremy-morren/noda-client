// Ported from NodaTime 3.3.0: src/NodaTime/Utility/InvalidNodaDataException.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

/**
 * Exception thrown when data read by Noda Time (such as serialized time zone data) is invalid. This includes
 * data which is truncated, i.e. we expect more data than we can read.
 */
export class InvalidNodaDataError extends Error {
  override name = "InvalidNodaDataError";
  /**
   * Creates an instance with the given message.
   * @param message The message for the exception.
   * @param innerException Underlying cause of the error.
   */
  constructor(message: string, innerException?: unknown) {
    super(message, innerException === undefined ? undefined : { cause: innerException });
  }
}
