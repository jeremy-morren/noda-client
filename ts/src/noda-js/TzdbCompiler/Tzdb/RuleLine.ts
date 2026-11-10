// Ported from NodaTime 3.3.7: src/NodaTime.TzdbCompiler/Tzdb/RuleLine.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { StringBuilder } from "../../internal.ts";
import type { IEquatable, ZoneRecurrence } from "../../internal.ts";
import type { ZoneLine } from "../internal.ts";

/**
 * Defines one "Rule" line from the tz data. (This may be applied to multiple zones.)
 *
 * Immutable, threadsafe.
 * @internal
 */
export class RuleLine implements IEquatable<RuleLine> {
  /**
   * The string to replace "%s" with (if any) when formatting the zone name key.
   *
   * This is always used to replace %s, whether or not the recurrence
   * actually includes savings; it is expected to be appropriate to the recurrence.
   */
  private readonly _daylightSavingsIndicator: string | null;

  /**
   * The recurrence pattern for the rule.
   */
  private readonly _recurrence: ZoneRecurrence;

  /**
   * Returns the name of the rule set this rule belongs to.
   */
  get Name(): string {
    return this._recurrence.Name;
  }

  /**
   * Initializes a new instance of the {@link RuleLine} class.
   * @param recurrence The recurrence definition of this rule.
   * @param daylightSavingsIndicator The daylight savings indicator letter for time zone names.
   */
  constructor(recurrence: ZoneRecurrence, daylightSavingsIndicator: string | null) {
    this._recurrence = recurrence;
    this._daylightSavingsIndicator = daylightSavingsIndicator;
  }

  // #region IEquatable<RuleLine> Members
  /**
   * Indicates whether the current object is equal to another object of the same type.
   * (Merges NodaTime's Equals(RuleLine), Equals(object) and operator ==.)
   * @param other An object to compare with this object.
   * @returns true if the current object is equal to the `other` parameter;
   * otherwise, false.
   */
  Equals(other: RuleLine): boolean;
  /** @inheritDoc */
  Equals(other: unknown): boolean;
  Equals(other: unknown): boolean {
    return other instanceof RuleLine && this._recurrence.Equals(other._recurrence) && this._daylightSavingsIndicator === other._daylightSavingsIndicator;
  }
  // #endregion

  // #region Operator overloads
  // operator == and operator != are merged into Equals above.
  // #endregion

  /**
   * Retrieves the recurrence, after applying the specified name format.
   *
   * Multiple zones may apply the same set of rules as to when they change into/out of
   * daylight saving time, but with different names.
   * @param zone The zone for which this rule is being considered.
   */
  GetRecurrence(zone: ZoneLine): ZoneRecurrence {
    const name = zone.FormatName(this._recurrence.Savings, this._daylightSavingsIndicator);
    return this._recurrence.WithName(name);
  }

  // #region Object overrides
  // Equals(object) is merged into Equals above; GetHashCode is omitted.

  /**
   * Returns a string that represents this instance.
   * @returns A string that represents this instance.
   */
  toString(): string {
    const builder = new StringBuilder();
    builder.Append(this._recurrence.toString());
    if (this._daylightSavingsIndicator !== null) {
      builder.Append(" \"").Append(this._daylightSavingsIndicator).Append("\"");
    }
    return builder.toString();
  }
  // #endregion Object overrides
}
