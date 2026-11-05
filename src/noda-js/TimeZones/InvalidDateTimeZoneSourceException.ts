// Ported from NodaTime 3.3.0: src/NodaTime/TimeZones/InvalidDateTimeZoneSourceException.cs
// Copyright 2012 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
import type { DateTimeZoneCache, IDateTimeZoneSource } from "../internal.ts";

/**
 * Exception thrown to indicate that a time zone source has violated the contract of {@link IDateTimeZoneSource}.
 * This exception is primarily intended to be thrown from {@link DateTimeZoneCache}, and only in the face of a buggy
 * source; user code should not usually need to be aware of this or catch it.
 */
export class InvalidDateTimeZoneSourceError extends Error {
  override name = "InvalidDateTimeZoneSourceError";

  /**
   * Creates a new instance with the given message.
   * @param message The message for the exception.
   */
  constructor(message: string) {
    super(message);
  }
}
