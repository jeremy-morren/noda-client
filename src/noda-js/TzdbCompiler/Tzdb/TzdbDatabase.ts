// Ported from NodaTime 3.3.7: src/NodaTime.TzdbCompiler/Tzdb/TzdbDatabase.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { TzdbDateTimeZoneSource, WindowsZones } from "../../internal.ts";
import type { DateTimeZone, TzdbZone1970Location, TzdbZoneLocation } from "../../internal.ts";
import { AddValue, CompareOrdinal, DateTimeZoneBuilder, GetValue, TzdbStreamWriter } from "../internal.ts";
import type { RuleLine, ZoneLine } from "../internal.ts";

/**
 * Provides a container for the definitions parsed from the TZDB zone info files.
 */
export class TzdbDatabase {
  /**
   * Returns the zone lists. This is only available for the sake of testing.
   * @internal
   */
  readonly Zones: Map<string, ZoneLine[]>;

  /**
   * Returns the version of the TZDB data represented.
   */
  readonly Version: string;

  /**
   * Returns the (mutable) map of links from alias to canonical ID.
   */
  readonly Aliases: Map<string, string>;

  /**
   * Mapping from rule name to the zone rules for that name. This is only available for the sake of testing.
   * @internal
   */
  readonly Rules: Map<string, RuleLine[]>;

  /**
   * A list of the zone locations known to this database from zone.tab.
   * @internal
   */
  ZoneLocations: TzdbZoneLocation[] | null = null;

  /**
   * A list of the zone locations known to this database from zone1970.tab.
   * @internal
   */
  Zone1970Locations: TzdbZone1970Location[] | null = null;

  /**
   * Initializes a new instance of the {@link TzdbDatabase} class.
   */
  constructor(version: string) {
    this.Zones = new Map<string, ZoneLine[]>();
    this.Rules = new Map<string, RuleLine[]>();
    this.Aliases = new Map<string, string>();
    this.Version = version;
  }

  /**
   * Returns the data in this database as a {@link TzdbDateTimeZoneSource} with no
   * Windows mappings.
   */
  ToTzdbDateTimeZoneSource(): TzdbDateTimeZoneSource {
    const writer = new TzdbStreamWriter();
    // noda-js: TzdbStreamWriter.Write returns the NZD bytes instead of writing to a MemoryStream.
    const bytes = writer.Write(
      this,
      WindowsZones.NewVersionTzdbVersionWindowsVersionMapZones("n/a", this.Version, "n/a", []), // No Windows mappings,
      new Map<string, string>(), // No additional name-to-id mappings
    );
    return TzdbDateTimeZoneSource.FromBytes(bytes);
  }

  /**
   * Adds the given zone alias to the database.
   * @param existing The existing zone ID to map the alias to.
   * @param alias The zone alias to add.
   * @internal
   */
  AddAlias(existing: string, alias: string): void {
    AddValue(this.Aliases, alias, existing);
  }

  /**
   * Adds the given rule to the appropriate rule set. If there is no existing
   * rule set, one is created and added to the database.
   * @param rule The rule to add.
   * @internal
   */
  AddRule(rule: RuleLine): void {
    let ruleSet = this.Rules.get(rule.Name);
    if (ruleSet === undefined) {
      ruleSet = [];
      this.Rules.set(rule.Name, ruleSet);
    }
    ruleSet.push(rule);
  }

  /**
   * Adds the given zone line to the database, creating a new list for
   * that zone ID if necessary.
   * @param zone The zone to add.
   * @internal
   */
  AddZone(zone: ZoneLine): void {
    let zoneSet = this.Zones.get(zone.Name);
    if (zoneSet === undefined) {
      zoneSet = [];
      this.Zones.set(zone.Name, zoneSet);
    }
    zoneSet.push(zone);
  }

  /**
   * Converts a single zone into a DateTimeZone. As well as for testing purposes,
   * this can be used to resolve aliases.
   * @param zoneId The ID of the zone to convert.
   */
  GenerateDateTimeZone(zoneId: string): DateTimeZone {
    let zoneListKey = zoneId;
    // Recursively resolve aliases
    while (this.Aliases.has(zoneListKey)) {
      zoneListKey = this.Aliases.get(zoneListKey)!;
    }
    return this.CreateTimeZone(zoneId, GetValue(this.Zones, zoneListKey));
  }

  /**
   * Converts each zone in the database into a DateTimeZone.
   */
  *GenerateDateTimeZones(): Iterable<DateTimeZone> {
    const keys = [...this.Zones.keys()].sort(CompareOrdinal);
    for (const key of keys) {
      yield this.CreateTimeZone(key, this.Zones.get(key)!);
    }
  }

  /**
   * Returns a newly created {@link DateTimeZone} built from the given time zone data.
   * @param zoneList The time zone definition parts to add.
   */
  private CreateTimeZone(id: string, zoneList: readonly ZoneLine[]): DateTimeZone {
    const ruleSets = zoneList.map(zone => zone.ResolveRules(this.Rules));
    return DateTimeZoneBuilder.Build(id, ruleSets);
  }

  /**
   * Writes various informational counts to the log.
   *
   * noda-js: NodaTime writes to the console; this writes each line to `log`.
   * @internal
   */
  LogCounts(log: (line: string) => void): void {
    log("=======================================");
    log(`Rule sets:    ${this.Rules.size}`);
    log(`Zones:        ${this.Zones.size}`);
    log(`Aliases:      ${this.Aliases.size}`);
    log(`Zone locations: ${this.ZoneLocations?.length ?? 0}`);
    log(`Zone1970 locations: ${this.Zone1970Locations?.length ?? 0}`);
    log("=======================================");
  }
}
