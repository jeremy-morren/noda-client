// Ported from NodaTime 3.3.7: src/NodaTime/TimeZones/TzdbZone1970Location.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { InvalidNodaDataException, Preconditions } from "../internal.ts";
import type { IDateTimeZoneReader, IDateTimeZoneWriter, IEquatable } from "../internal.ts";
import type { TzdbDateTimeZoneSource, TzdbZoneLocation } from "../internal.ts";
import { IsNodaError, type ArgumentException, type ArgumentOutOfRangeException } from "../internal.ts";

/**
 * A country represented within an entry in the "zone1970.tab" file, with the English name
 * mapped from the "iso3166.tab" file.
 * (C#: TzdbZone1970Location.Country)
 *
 * Equality is defined component-wise: two values are considered equal if their country names are equal to
 * each other, and their country codes are equal to each other.
 */
export class TzdbZone1970LocationCountry implements IEquatable<TzdbZone1970LocationCountry> {
  private readonly _name: string;

  /**
   * Gets the English name of the country.
   */
  get Name(): string {
    return this._name;
  }

  private readonly _code: string;

  /**
   * Gets the ISO-3166 2-letter country code for the country.
   */
  get Code(): string {
    return this._code;
  }

  /**
   * Constructs a new country from its name and ISO-3166 2-letter code.
   * @param name Country name; must not be empty.
   * @param code 2-letter code
   */
  constructor(name: string, code: string) {
    this._name = Preconditions.CheckNotNull(name, "name");
    this._code = Preconditions.CheckNotNull(code, "code");
    Preconditions.CheckArgument(this.Name.length > 0, "name", "Country name cannot be empty");
    Preconditions.CheckArgument(this.Code.length === 2, "code", "Country code must be two characters");
  }

  /**
   * Compares countries for equality.
   * See the type documentation for a description of equality semantics.
   * (Merges NodaTime's Equals(Country) and Equals(object).)
   * @param other The country to compare with this one.
   * @returns `true` if the given country has the same name and code as this one; `false` otherwise.
   */
  Equals(other: TzdbZone1970LocationCountry): boolean;
  /** @inheritDoc */
  Equals(other: unknown): boolean;
  Equals(other: unknown): boolean {
    return other instanceof TzdbZone1970LocationCountry && other.Code === this.Code && other.Name === this.Name;
  }

  // Not ported: GetHashCode (see docs/porting-conventions.md)

  /**
   * Returns a string representation of this country, including the code and name.
   * @returns A string representation of this country.
   */
  toString(): string {
    return `${this.Code} (${this.Name})`;
  }
}

/**
 * A location entry generated from the "zone1970.tab" file in a TZDB release. This can be used to provide
 * users with a choice of time zone, although it is not internationalized. This is equivalent to
 * {@link TzdbZoneLocation}, except that multiple countries may be represented.
 *
 * This type is immutable reference type. See the thread safety section of the user guide for more information.
 */
export class TzdbZone1970Location {
  /** Nested type: TzdbZone1970Location.Country */
  static readonly Country = TzdbZone1970LocationCountry;

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

  private readonly _countries: readonly TzdbZone1970LocationCountry[];

  /**
   * Gets the list of countries associated with this location.
   *
   * The list is immutable, and will always contain at least one entry. The list is
   * in the order specified in "zone1970.tab", so the first entry is always the
   * country containing the position indicated by the latitude and longitude, and
   * is the most populous country in the list. No entry in this list is ever null.
   */
  get Countries(): readonly TzdbZone1970LocationCountry[] {
    return this._countries;
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
   * @param countries Countries associated with this location. Must not be null, must have at least
   * one entry, and all entries must be non-null.
   * @param zoneId Time zone identifier of the location. Must not be null.
   * @param comment Optional comment. Must not be null, but may be empty.
   * @throws {ArgumentOutOfRangeException} The latitude or longitude is invalid.
   */
  constructor(
    latitudeSeconds: number,
    longitudeSeconds: number,
    countries: Iterable<TzdbZone1970LocationCountry>,
    zoneId: string,
    comment: string,
  ) {
    Preconditions.CheckArgumentRange("latitudeSeconds", latitudeSeconds, -90 * 3600, 90 * 3600);
    Preconditions.CheckArgumentRange("longitudeSeconds", longitudeSeconds, -180 * 3600, 180 * 3600);
    this._latitudeSeconds = latitudeSeconds;
    this._longitudeSeconds = longitudeSeconds;
    this._countries = [...Preconditions.CheckNotNull(countries, "countries")];
    Preconditions.CheckArgument(this.Countries.length > 0, "countries", "Collection must contain at least one entry");
    for (const entry of this.Countries) {
      Preconditions.CheckArgument(entry !== null && entry !== undefined, "countries", "Collection must not contain null entries");
    }
    this._zoneId = Preconditions.CheckNotNull(zoneId, "zoneId");
    this._comment = Preconditions.CheckNotNull(comment, "comment");
  }

  /** @internal */
  Write(writer: IDateTimeZoneWriter): void {
    writer.WriteSignedCount(this._latitudeSeconds);
    writer.WriteSignedCount(this._longitudeSeconds);
    writer.WriteCount(this.Countries.length);
    // We considered writing out the ISO-3166 file as a separate field,
    // so we can reuse objects, but we don't actually waste very much space this way,
    // due to the string pool... and the increased code complexity isn't worth it.
    for (const country of this.Countries) {
      writer.WriteString(country.Name);
      writer.WriteString(country.Code);
    }
    writer.WriteString(this.ZoneId);
    writer.WriteString(this.Comment);
  }

  /** @internal */
  static Read(reader: IDateTimeZoneReader): TzdbZone1970Location {
    const latitudeSeconds = reader.ReadSignedCount();
    const longitudeSeconds = reader.ReadSignedCount();
    const countryCount = reader.ReadCount();
    const countries: TzdbZone1970LocationCountry[] = [];
    for (let i = 0; i < countryCount; i++) {
      const countryName = reader.ReadString();
      const countryCode = reader.ReadString();
      countries.push(new TzdbZone1970LocationCountry(countryName, countryCode));
    }
    const zoneId = reader.ReadString();
    const comment = reader.ReadString();
    // We could duplicate the validation, but there's no good reason to. It's odd
    // to catch ArgumentException, but we're in pretty tight control of what's going on here.
    try {
      return new TzdbZone1970Location(latitudeSeconds, longitudeSeconds, countries, zoneId, comment);
    } catch (e) {
      // (In .NET, ArgumentOutOfRangeException derives from ArgumentException.)
      if (IsNodaError(e, "ArgumentException") || IsNodaError(e, "ArgumentOutOfRangeException")) {
        throw new InvalidNodaDataException("Invalid zone location data in stream", e);
      }
      throw e;
    }
  }
}
