// Ported from NodaTime 3.3.7: src/NodaTime.TzdbCompiler/Tzdb/ZoneLine.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { Int32, Offset, OffsetPattern, PadStart, StringBuilder } from "../../internal.ts";
import type { IEquatable, ZoneYearOffset } from "../../internal.ts";
import { ParserHelper, ZoneRuleSet } from "../internal.ts";
import type { RuleLine } from "../internal.ts";
import { IsNodaError, NewArgumentException } from "../../internal.ts";

let percentZPattern: OffsetPattern | undefined;

/**
 * Contains the parsed information from one "Zone" line of the TZDB zone database.
 *
 * Immutable, thread-safe
 * @internal
 */
export class ZoneLine implements IEquatable<ZoneLine> {
  private static get PercentZPattern(): OffsetPattern {
    return (percentZPattern ??= OffsetPattern.CreateWithInvariantCulture("i"));
  }

  /**
   * Initializes a new instance of the {@link ZoneLine} class.
   */
  constructor(name: string, offset: Offset, rules: string | null, format: string, untilYear: number, untilYearOffset: ZoneYearOffset) {
    this.Name = name;
    this.StandardOffset = offset;
    this.Rules = rules;
    this.Format = format;
    this.UntilYear = untilYear;
    this.UntilYearOffset = untilYearOffset;
  }

  readonly UntilYearOffset: ZoneYearOffset;

  readonly UntilYear: number;

  /**
   * Returns the format for generating the label for this time zone. May contain "%s" to
   * be replaced by a daylight savings indicator, or "%z" to be replaced by an offset indicator.
   */
  readonly Format: string;

  /**
   * Returns the name of the time zone.
   */
  readonly Name: string;

  /**
   * Returns the offset to add to UTC for this time zone's standard time.
   */
  readonly StandardOffset: Offset;

  /**
   * The name of the set of rules applicable to this zone line, or
   * null for just standard time, or an offset for a "fixed savings" rule.
   */
  readonly Rules: string | null;

  // #region IEquatable<Zone> Members
  /**
   * Indicates whether the current object is equal to another object of the same type.
   * (Merges NodaTime's Equals(ZoneLine) and Equals(object).)
   * @param other An object to compare with this object.
   * @returns true if the current object is equal to the `other` parameter;
   * otherwise, false.
   */
  Equals(other: ZoneLine): boolean;
  /** @inheritDoc */
  Equals(other: unknown): boolean;
  Equals(other: unknown): boolean {
    if (!(other instanceof ZoneLine)) {
      return false;
    }
    if (this === other) {
      return true;
    }
    let result =
      this.Name === other.Name &&
      this.StandardOffset.Equals(other.StandardOffset) &&
      this.Rules === other.Rules &&
      this.Format === other.Format &&
      this.UntilYear === other.UntilYear;
    if (this.UntilYear !== Int32.MaxValue) {
      result = result && this.UntilYearOffset.Equals(other.UntilYearOffset);
    }
    return result;
  }
  // #endregion

  // Equals(object) is merged into Equals above; GetHashCode is omitted.

  /**
   * Returns a string that represents this instance.
   * @returns A string that represents this instance.
   */
  toString(): string {
    const builder = new StringBuilder();
    builder.Append(this.Name).Append(" ");
    builder.Append(this.StandardOffset.toString()).Append(" ");
    builder.Append(ParserHelper.FormatOptional(this.Rules)).Append(" ");
    builder.Append(this.Format);
    if (this.UntilYear !== Int32.MaxValue) {
      // UntilYear.ToString("D4", CultureInfo.InvariantCulture)
      const year = this.UntilYear < 0 ? "-" + PadStart(String(-this.UntilYear), 4, "0") : PadStart(String(this.UntilYear), 4, "0");
      builder.Append(" ").Append(year).Append(" ").Append(this.UntilYearOffset.toString());
    }
    return builder.toString();
  }

  ResolveRules(allRules: ReadonlyMap<string, readonly RuleLine[]>): ZoneRuleSet {
    if (this.Rules === null) {
      const name = this.FormatName(Offset.Zero, "");
      return ZoneRuleSet.NewNameStandardOffsetSavingsUpperYearUpperYearOffset(name, this.StandardOffset, Offset.Zero, this.UntilYear, this.UntilYearOffset);
    }
    const ruleSet = allRules.get(this.Rules);
    if (ruleSet !== undefined) {
      const rules = ruleSet.map(x => x.GetRecurrence(this));
      return ZoneRuleSet.NewRulesStandardOffsetUpperYearUpperYearOffset(rules, this.StandardOffset, this.UntilYear, this.UntilYearOffset);
    } else {
      try {
        // Check if Rules actually just refers to a savings.
        const savings = ParserHelper.ParseOffset(this.Rules);
        const name = this.FormatName(savings, "");
        return ZoneRuleSet.NewNameStandardOffsetSavingsUpperYearUpperYearOffset(name, this.StandardOffset, savings, this.UntilYear, this.UntilYearOffset);
      } catch (e) {
        if (IsNodaError(e, "FormatException")) {
          throw NewArgumentException(
            `Daylight savings rule name '${this.Rules}' for zone ${this.Name} is neither a known ruleset nor a fixed offset`,
          );
        }
        throw e;
      }
    }
  }

  FormatName(savings: Offset, daylightSavingsIndicator: string | null): string {
    let index = this.Format.indexOf("/");
    if (index >= 0) {
      return savings.Equals(Offset.Zero) ? this.Format.substring(0, index) : this.Format.substring(index + 1);
    }
    index = this.Format.indexOf("%s");
    if (index >= 0) {
      const left = this.Format.substring(0, index);
      const right = this.Format.substring(index + 2);
      // C# string concatenation treats null as "".
      return left + (daylightSavingsIndicator ?? "") + right;
    }
    index = this.Format.indexOf("%z");
    if (index >= 0) {
      const left = this.Format.substring(0, index);
      const right = this.Format.substring(index + 2);
      return left + ZoneLine.PercentZPattern.Format(this.StandardOffset.Plus(savings)) + right;
    }
    return this.Format;
  }
}
