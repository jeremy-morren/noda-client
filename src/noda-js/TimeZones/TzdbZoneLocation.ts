// Ported from NodaTime 3.3.0: src/NodaTime/TimeZones/TzdbZoneLocation.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { ArgumentError, ArgumentOutOfRangeError, InvalidNodaDataError, Preconditions } from "../internal.ts";
import type { IDateTimeZoneReader } from "../internal.ts";
import type { TzdbDateTimeZoneSource } from "../internal.ts";

/**
 * A location entry generated from the "zone.tab" file in a TZDB release. This can be used to provide
 * users with a choice of time zone, although it is not internationalized.
 *
 * This type is immutable reference type. See the thread safety section of the user guide for more information.
 */
export class TzdbZoneLocation {
  private readonly _latitudeSeconds: number;
  private readonly _longitudeSeconds: number;

  /**
   * Gets the latitude in degrees; positive for North, negative for South.
   *
   * The value will be in the range [-90, 90].
   */
  get Latitude(): number {
    return this._latitudeSeconds / 3600.0;
  }

  /**
   * Gets the longitude in degrees; positive for East, negative for West.
   *
   * The value will be in the range [-180, 180].
   */
  get Longitude(): number {
    return this._longitudeSeconds / 3600.0;
  }

  private readonly _countryName: string;

  /**
   * Gets the English name of the country containing the location, which is never empty.
   */
  get CountryName(): string {
    return this._countryName;
  }

  private readonly _countryCode: string;

  /**
   * Gets the ISO-3166 2-letter country code for the country containing the location.
   */
  get CountryCode(): string {
    return this._countryCode;
  }

  private readonly _zoneId: string;

  /**
   * The ID of the time zone for this location.
   *
   * If this mapping was fetched from a {@link TzdbDateTimeZoneSource}, it will always be a valid ID within that source.
   */
  get ZoneId(): string {
    return this._zoneId;
  }

  private readonly _comment: string;

  /**
   * Gets the comment (in English) for the mapping, if any.
   *
   * This is usually used to differentiate between locations in the same country.
   * This will return an empty string if no comment was provided in the original data.
   */
  get Comment(): string {
    return this._comment;
  }

  /**
   * Creates a new location.
   *
   * This constructor is only public for the sake of testability. Non-test code should
   * usually obtain locations from a {@link TzdbDateTimeZoneSource}.
   * @param latitudeSeconds Latitude of the location, in seconds.
   * @param longitudeSeconds Longitude of the location, in seconds.
   * @param countryName English country name of the location, in degrees. Must not be null.
   * @param countryCode ISO-3166 country code of the location. Must not be null.
   * @param zoneId Time zone identifier of the location. Must not be null.
   * @param comment Optional comment. Must not be null, but may be empty.
   * @throws {ArgumentOutOfRangeError} The latitude or longitude is invalid.
   */
  constructor(latitudeSeconds: number, longitudeSeconds: number, countryName: string, countryCode: string, zoneId: string, comment: string) {
    Preconditions.CheckArgumentRange("latitudeSeconds", latitudeSeconds, -90 * 3600, 90 * 3600);
    Preconditions.CheckArgumentRange("longitudeSeconds", longitudeSeconds, -180 * 3600, 180 * 3600);
    this._latitudeSeconds = latitudeSeconds;
    this._longitudeSeconds = longitudeSeconds;
    this._countryName = Preconditions.CheckNotNull(countryName, "countryName");
    this._countryCode = Preconditions.CheckNotNull(countryCode, "countryCode");
    Preconditions.CheckArgument(this.CountryName.length > 0, "countryName", "Country name cannot be empty");
    Preconditions.CheckArgument(this.CountryCode.length === 2, "countryCode", "Country code must be two characters");
    this._zoneId = Preconditions.CheckNotNull(zoneId, "zoneId");
    this._comment = Preconditions.CheckNotNull(comment, "comment");
  }

  // Not ported: Write(IDateTimeZoneWriter) (DateTimeZoneWriter is not ported)

  /** @internal */
  static Read(reader: IDateTimeZoneReader): TzdbZoneLocation {
    const latitudeSeconds = reader.ReadSignedCount();
    const longitudeSeconds = reader.ReadSignedCount();
    const countryName = reader.ReadString();
    const countryCode = reader.ReadString();
    const zoneId = reader.ReadString();
    const comment = reader.ReadString();
    // We could duplicate the validation, but there's no good reason to. It's odd
    // to catch ArgumentException, but we're in pretty tight control of what's going on here.
    try {
      return new TzdbZoneLocation(latitudeSeconds, longitudeSeconds, countryName, countryCode, zoneId, comment);
    } catch (e) {
      // (In .NET, ArgumentOutOfRangeException derives from ArgumentException.)
      if (e instanceof ArgumentError || e instanceof ArgumentOutOfRangeError) {
        throw new InvalidNodaDataError("Invalid zone location data in stream", e);
      }
      throw e;
    }
  }
}
