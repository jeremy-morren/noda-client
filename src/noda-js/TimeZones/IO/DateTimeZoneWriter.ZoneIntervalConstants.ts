// Ported from NodaTime 3.3.7: src/NodaTime/TimeZones/IO/DateTimeZoneWriter.cs (the nested ZoneIntervalConstants class)
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda-js: in a module of its own (like DateTimeZoneWriter.DateTimeZoneType.generated.ts), because DateTimeZoneReader
// uses these constants too: a bundle that only reads NZD data (e.g. noda-js/tzdb/bundled) then doesn't include the
// writer. DateTimeZoneWriter.ZoneIntervalConstants refers to this class.

import { Instant } from "../../internal.ts";

let epochForMinutesSinceEpoch: Instant | undefined;

/**
 * Constants for the encoding of zone interval transitions (NodaTime's nested `DateTimeZoneWriter.ZoneIntervalConstants`
 * static class).
 * @internal
 */
export class DateTimeZoneWriterZoneIntervalConstants {
  /** The instant to use as an 'epoch' when writing out a number of minutes-since-epoch. */
  static get EpochForMinutesSinceEpoch(): Instant {
    return (epochForMinutesSinceEpoch ??= Instant.FromUtc(1800, 1, 1, 0, 0));
  }

  /** The marker value representing the beginning of time. */
  static readonly MarkerMinValue = 0;
  /** The marker value representing the end of time. */
  static readonly MarkerMaxValue = 1;
  /** The marker value representing an instant as a fixed 64-bit number of ticks. */
  static readonly MarkerRaw = 2;
  /**
   * The minimum varint value that represents an number of hours-since-previous.
   *
   * Values below this are reserved for markers.
   */
  static readonly MinValueForHoursSincePrevious = 1 << 7;
  /**
   * The minimum varint value that represents an number of minutes since an epoch.
   *
   * Values below this are interpreted as hours-since-previous (for a range of about 240 years),
   * rather than minutes-since-epoch (for a range of about 4000 years)
   * This choice is somewhat arbitrary, though it results in hour values always taking 2 (or
   * occasionally 3) bytes when encoded as a varint, while minute values take 4 (or conceivably 5).
   */
  static readonly MinValueForMinutesSinceEpoch = 1 << 21;
}
