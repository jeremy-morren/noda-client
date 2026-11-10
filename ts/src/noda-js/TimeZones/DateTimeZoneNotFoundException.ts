// Ported from NodaTime 3.3.7: src/NodaTime/TimeZones/DateTimeZoneNotFoundException.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
import type { IDateTimeZoneProvider } from "../internal.ts";
import type { TimeZoneNotFoundException } from "../internal.ts";
import { NodaError } from "../internal.ts";

/**
 * Exception thrown when time zone is requested from an {@link IDateTimeZoneProvider},
 * but the specified ID is invalid for that provider.
 */
// noda-js: extends NodaError, with TimeZoneNotFoundException in its Codes.
export class DateTimeZoneNotFoundException extends NodaError<"DateTimeZoneNotFoundException"> {

  /**
   * Creates an instance with the given message.
   * @param message The message for the exception.
   */
  constructor(message: string) {
    super("DateTimeZoneNotFoundException", message);
  }
}
