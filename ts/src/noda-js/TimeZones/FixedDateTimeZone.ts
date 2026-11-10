// Ported from NodaTime 3.3.7: src/NodaTime/TimeZones/FixedDateTimeZone.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { DateTimeZone, Instant, Offset, OffsetPattern, Preconditions, ZoneInterval, ZoneLocalMapping, PadStart } from "../internal.ts";
import type { IDateTimeZoneReader, IDateTimeZoneWriter, IEquatable, LocalDateTime } from "../internal.ts";

// Implementation note: this implemented IEquatable<FixedDateTimeZone> for the sake of fitting in with our test infrastructure
// more than anything else...

/**
 * Basic {@link DateTimeZone} implementation that has a fixed name key and offset i.e.
 * no daylight savings.
 *
 * This type is immutable reference type. See the thread safety section of the user guide for more information.
 * @internal
 */
export class FixedDateTimeZone extends DateTimeZone implements IEquatable<FixedDateTimeZone> {
  private readonly _interval: ZoneInterval;

  // noda-js: NodaTime's three internal constructors.
  /**
   * Creates a new fixed time zone.
   *
   * The ID and name (for the {@link ZoneInterval}) are generated based on the offset.
   * @param offset The {@link Offset} from UTC.
   */
  constructor(offset: Offset);
  /**
   * Initializes a new instance of the {@link FixedDateTimeZone} class.
   *
   * The name (for the {@link ZoneInterval}) is deemed to be the same as the ID.
   * @param id The id.
   * @param offset The offset.
   */
  constructor(id: string, offset: Offset);
  /**
   * Initializes a new instance of the {@link FixedDateTimeZone} class.
   *
   * The name (for the {@link ZoneInterval}) is deemed to be the same as the ID.
   * @param id The id.
   * @param offset The offset.
   * @param name The name to use in the sole {@link ZoneInterval} in this zone.
   */
  constructor(id: string, offset: Offset, name: string);
  constructor(idOrOffset: string | Offset, offset?: Offset, name?: string) {
    const id = typeof idOrOffset === "string" ? idOrOffset : FixedDateTimeZone.MakeId(idOrOffset);
    const zoneOffset = typeof idOrOffset === "string" ? offset! : idOrOffset;
    super(id, true, zoneOffset, zoneOffset);
    this._interval = new ZoneInterval(name ?? id, Instant.BeforeMinValue, Instant.AfterMaxValue, zoneOffset, Offset.Zero);
  }

  /** @internal */
  static NewOffset(offset: Offset): FixedDateTimeZone {
    return new FixedDateTimeZone(offset);
  }

  /** @internal */
  static NewIdOffset(id: string, offset: Offset): FixedDateTimeZone {
    return new FixedDateTimeZone(id, offset);
  }

  /** @internal */
  static NewIdOffsetName(id: string, offset: Offset, name: string): FixedDateTimeZone {
    return new FixedDateTimeZone(id, offset, name);
  }

  /**
   * Makes the id for this time zone. The format is "UTC+/-Offset".
   *
   * @param offset The offset.
   * @returns The generated id string.
   */
  private static MakeId(offset: Offset): string {
    if (offset.Equals(Offset.Zero)) {
      return DateTimeZone.UtcId;
    }

    // This code is equivalent to
    // UtcId + OffsetPattern.GeneralInvariant.Format(offset)
    // but avoids using any code in NodaTime.Text, which can cause
    // issues during type initialization.
    const absSeconds = Math.abs(offset.Seconds);
    const hours = Math.trunc(absSeconds / 3600);
    const minutes = Math.trunc((absSeconds % 3600) / 60);
    const seconds = absSeconds % 60;

    const d2 = (value: number): string => PadStart(String(value), 2, "0");
    const absString = minutes === 0 && seconds === 0 ? d2(hours)
      : seconds === 0 ? `${d2(hours)}:${d2(minutes)}`
      : `${d2(hours)}:${d2(minutes)}:${d2(seconds)}`;

    const prefixAndSign = offset.Seconds < 0 ? (DateTimeZone.UtcId + "-") : (DateTimeZone.UtcId + "+");
    return prefixAndSign + absString;
  }

  /**
   * Returns a fixed time zone for the given ID, which must be "UTC" or "UTC[offset]" where "[offset]" can be parsed
   * using the "general" offset pattern.
   *
   * @param id ID
   * @returns The parsed time zone, or null if the ID doesn't match.
   */
  static GetFixedZoneOrNull(id: string): DateTimeZone | null {
    if (!id.startsWith(DateTimeZone.UtcId)) {
      return null;
    }
    if (id === DateTimeZone.UtcId) {
      return DateTimeZone.Utc;
    }
    const parseResult = OffsetPattern.GeneralInvariant.Parse(id.substring(DateTimeZone.UtcId.length));
    return parseResult.Success ? DateTimeZone.ForOffset(parseResult.Value) : null;
  }

  /**
   * Returns the fixed offset for this time zone.
   *
   * @returns The fixed offset for this time zone.
   */
  get Offset(): Offset {
    return this.MaxOffset;
  }

  /**
   * Returns the name used for the zone interval for this time zone.
   *
   * @returns The name used for the zone interval for this time zone.
   */
  get Name(): string {
    return this._interval.Name;
  }

  /**
   * Gets the zone interval for the given instant. This implementation always returns the same interval.
   */
  override GetZoneInterval(_instant: Instant): ZoneInterval {
    return this._interval;
  }

  /**
   * Override for efficiency: we know we'll always have an unambiguous mapping for any LocalDateTime.
   */
  override MapLocal(localDateTime: LocalDateTime): ZoneLocalMapping {
    return ZoneLocalMapping.NewZoneLocalDateTimeEarlyIntervalLateIntervalCount(this, localDateTime, this._interval, this._interval, 1);
  }

  /**
   * Returns the offset from UTC, where a positive duration indicates that local time is later
   * than UTC. In other words, local time = UTC + offset.
   *
   * @param instant The instant for which to calculate the offset.
   * @returns The offset from UTC at the specified instant.
   */
  override GetUtcOffset(_instant: Instant): Offset {
    return this.MaxOffset;
  }

  /**
   * Writes the time zone to the specified writer.
   * @param writer The writer.
   * @internal
   */
  Write(writer: IDateTimeZoneWriter): void {
    Preconditions.CheckNotNull(writer, "writer");
    writer.WriteOffset(this.Offset);
    writer.WriteString(this.Name);
  }

  /**
   * Reads a fixed time zone from the specified reader.
   *
   * @param reader The reader.
   * @param id The id.
   * @returns The fixed time zone.
   */
  static Read(reader: IDateTimeZoneReader, id: string): DateTimeZone {
    Preconditions.CheckNotNull(reader, "reader");
    Preconditions.CheckNotNull(id, "id");
    const offset = reader.ReadOffset();
    const name = reader.HasMoreData ? reader.ReadString() : id;
    return new FixedDateTimeZone(id, offset, name);
  }

  /**
   * Indicates whether this instance and a specified object are equal.
   * (Merges NodaTime's Equals(object) and Equals(FixedDateTimeZone).)
   *
   * @param obj Another object to compare to.
   * @returns True if the specified value is a {@link FixedDateTimeZone} with the same name, ID and offset; otherwise, false.
   */
  override Equals(obj: FixedDateTimeZone): boolean;
  /** @inheritDoc */
  override Equals(obj: unknown): boolean;
  override Equals(obj: unknown): boolean {
    return obj instanceof FixedDateTimeZone &&
      this.Offset.Equals(obj.Offset) &&
      this.Id === obj.Id &&
      this.Name === obj.Name;
  }

  /**
   * Returns a string that represents this instance.
   */
  override toString(): string {
    return this.Id;
  }
}
