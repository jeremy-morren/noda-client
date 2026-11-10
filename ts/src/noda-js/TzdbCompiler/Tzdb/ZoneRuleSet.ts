// Ported from NodaTime 3.3.7: src/NodaTime.TzdbCompiler/Tzdb/ZoneRuleSet.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { Instant, Int32, Offset, Preconditions, ZoneInterval } from "../../internal.ts";
import type { ZoneRecurrence, ZoneYearOffset } from "../../internal.ts";

/**
 * A rule set associated with a single Zone line, after any rules
 * associated with it have been resolved to a collection of ZoneRecurrences.
 * It may have an upper bound, or extend to infinity: lower bounds aren't known.
 * Likewise it may have rules associated with it, or just a fixed offset and savings.
 * @internal
 */
export class ZoneRuleSet {
  // Either rules or name+fixedSavings is specified.
  private readonly _rules: readonly ZoneRecurrence[];
  private readonly _name: string | null;
  private readonly _fixedSavings: Offset;
  private readonly _upperYear: number;
  private readonly _upperYearOffset: ZoneYearOffset | null;
  readonly StandardOffset: Offset;

  // noda-js: NodaTime's private constructor, plus the fields the internal constructors set.
  private constructor(
    standardOffset: Offset,
    upperYear: number,
    upperYearOffset: ZoneYearOffset | null,
    rules: readonly ZoneRecurrence[],
    name: string | null,
    fixedSavings: Offset,
  ) {
    this.StandardOffset = standardOffset;
    this._upperYear = upperYear;
    this._upperYearOffset = upperYearOffset;
    Preconditions.CheckArgument(
      upperYear === Int32.MaxValue || upperYearOffset !== null,
      "upperYearOffset",
      "Must specify an upperYearOffset unless creating an infinite rule",
    );
    this._rules = rules;
    this._name = name;
    this._fixedSavings = fixedSavings;
  }

  /** @internal */
  static NewRulesStandardOffsetUpperYearUpperYearOffset(
    rules: readonly ZoneRecurrence[],
    standardOffset: Offset,
    upperYear: number,
    upperYearOffset: ZoneYearOffset | null,
  ): ZoneRuleSet {
    return new ZoneRuleSet(standardOffset, upperYear, upperYearOffset, rules, null, Offset.Zero);
  }

  /** @internal */
  static NewNameStandardOffsetSavingsUpperYearUpperYearOffset(
    name: string,
    standardOffset: Offset,
    savings: Offset,
    upperYear: number,
    upperYearOffset: ZoneYearOffset | null,
  ): ZoneRuleSet {
    return new ZoneRuleSet(standardOffset, upperYear, upperYearOffset, [], name, savings);
  }

  /**
   * Returns `true` if this rule set extends to the end of time, or
   * `false` if it has a finite end point.
   */
  get IsInfinite(): boolean {
    return this._upperYear === Int32.MaxValue;
  }

  get IsFixed(): boolean {
    return this._name !== null;
  }

  get Rules(): Iterable<ZoneRecurrence> {
    return this._rules;
  }

  CreateFixedInterval(start: Instant): ZoneInterval {
    Preconditions.CheckState(this.IsFixed, "Rule set is not fixed");
    const limit = this.GetUpperLimit(this._fixedSavings);
    return ZoneInterval.NewNameStartEndWallOffsetSavings(this._name!, start, limit, this.StandardOffset.Plus(this._fixedSavings), this._fixedSavings);
  }

  /**
   * Gets the inclusive upper limit of time that this rule set applies to.
   * @param savings The daylight savings value during the final zone interval.
   * @returns The `LocalInstant` of the upper limit for this rule set.
   */
  GetUpperLimit(savings: Offset): Instant {
    if (this.IsInfinite) {
      return Instant.AfterMaxValue;
    }
    const localInstant = this._upperYearOffset!.GetOccurrenceForYear(this._upperYear);
    const offset = this._upperYearOffset!.GetRuleOffset(this.StandardOffset, savings);
    return localInstant.SafeMinus(offset);
  }
}
