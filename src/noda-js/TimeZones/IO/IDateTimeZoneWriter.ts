// Ported from NodaTime 3.3.7: src/NodaTime/TimeZones/IO/IDateTimeZoneWriter.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import type { IDateTimeZoneReader, Instant, Offset } from "../../internal.ts";
import type { ArgumentOutOfRangeException } from "../../internal.ts";

/**
 * Interface for writing time-related data to a binary stream.
 * This is similar to `BinaryWriter`, but heavily
 * oriented towards our use cases.
 *
 * It is expected that the code reading data written by an implementation
 * will be able to identify which implementation to use. As of Noda Time 2.0,
 * there is only one implementation - but the interface will allow us to
 * evolve the details of the binary structure independently of the code in the
 * time zone implementations which knows how to write/read in terms of this interface
 * and {@link IDateTimeZoneReader}.
 * @internal
 */
export interface IDateTimeZoneWriter {
  /**
   * Writes a non-negative integer to the stream. This is optimized towards
   * cases where most values will be small.
   * @param count The integer to write to the stream.
   * @throws {ArgumentOutOfRangeException} `count` is negative.
   */
  WriteCount(count: number): void;

  /**
   * Writes a possibly-negative integer to the stream. This is optimized for
   * values of small magnitudes.
   * @param count The integer to write to the stream.
   */
  WriteSignedCount(count: number): void;

  /**
   * Writes a string to the stream.
   *
   * Callers can reasonably expect that
   * these values will be pooled in some fashion, so should not apply their own pooling.
   * @param value The string to write to the stream.
   */
  WriteString(value: string): void;

  /**
   * Writes a number of milliseconds to the stream, where the number
   * of milliseconds must be in the range (-1 day, +1 day).
   * @param millis The number of milliseconds to write to the stream.
   * @throws {ArgumentOutOfRangeException} `millis` is out of range.
   */
  WriteMilliseconds(millis: number): void;

  /**
   * Writes an offset to the stream.
   * @param offset The offset to write to the stream.
   */
  WriteOffset(offset: Offset): void;

  /**
   * Writes an instant representing a zone interval transition to the stream.
   *
   * This method takes a previously-written transition. Depending on the implementation, this value may be
   * required by the reader in order to reconstruct the next transition, so it should be deterministic for any
   * given value.
   * @param previous The previous transition written (usually for a given timezone), or null if there is
   * no previous transition.
   * @param value The transition to write to the stream.
   */
  WriteZoneIntervalTransition(previous: Instant | null, value: Instant): void;

  /**
   * Writes a string-to-string dictionary to the stream.
   * @param dictionary
   */
  WriteDictionary(dictionary: ReadonlyMap<string, string>): void;

  /**
   * Writes the given 8 bit integer value to the stream.
   * @param value The value to write.
   */
  WriteByte(value: number): void;
}
