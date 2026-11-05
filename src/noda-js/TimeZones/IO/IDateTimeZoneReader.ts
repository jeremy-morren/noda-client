// Ported from NodaTime 3.3.0: src/NodaTime/TimeZones/IO/IDateTimeZoneReader.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import type { Instant, Offset } from "../../internal.ts";

/**
 * Interface for reading time-related data from a binary stream.
 * This is similar to `BinaryReader`, but heavily
 * oriented towards our use cases.
 * @internal
 */
export interface IDateTimeZoneReader {
  /**
   * Returns whether or not there is more data in this stream.
   */
  readonly HasMoreData: boolean;

  /**
   * Reads a non-negative integer from the stream, which must have been written
   * by a call to `IDateTimeZoneWriter.WriteCount`.
   * @returns The integer read from the stream
   * @throws {InvalidNodaDataError} The data was invalid.
   */
  ReadCount(): number;

  /**
   * Reads a non-negative integer from the stream, which must have been written
   * by a call to `IDateTimeZoneWriter.WriteSignedCount`.
   * @returns The integer read from the stream
   * @throws {InvalidNodaDataError} The data was invalid.
   */
  ReadSignedCount(): number;

  /**
   * Reads a string from the stream.
   * @returns The string read from the stream; will not be null
   * @throws {InvalidNodaDataError} The data was invalid.
   */
  ReadString(): string;

  /**
   * Reads a signed 8 bit integer value from the stream and returns it as an int.
   * @returns The 8 bit int value.
   * @throws {InvalidNodaDataError} The data in the stream has been exhausted.
   */
  ReadByte(): number;

  /**
   * Reads a number of milliseconds from the stream.
   * @returns The number of milliseconds read from the stream
   * @throws {InvalidNodaDataError} The data was invalid.
   */
  ReadMilliseconds(): number;

  /**
   * Reads an offset from the stream.
   * @returns The offset read from the stream
   * @throws {InvalidNodaDataError} The data was invalid.
   */
  ReadOffset(): Offset;

  /**
   * Reads an instant representing a zone interval transition from the stream.
   * @param previous The previous transition written (usually for a given timezone), or null if there is
   * no previous transition.
   * @returns The instant read from the stream
   * @throws {InvalidNodaDataError} The data was invalid.
   */
  ReadZoneIntervalTransition(previous: Instant | null): Instant;

  /**
   * Reads a string-to-string dictionary from the stream.
   * @returns The dictionary read from the stream
   * @throws {InvalidNodaDataError} The data was invalid.
   */
  ReadDictionary(): Map<string, string>;
}
